require "http2"

module NGHTTP
  class HTTP2BodyIO < IO
    def initialize(@stream : HTTP2::Stream, @response : Response)
      @body = @stream.data
      @trailers_merged = false
    end

    def read(slice : Bytes) : Int32
      bytes_read = @body.read(slice)
      merge_trailers if bytes_read == 0
      bytes_read
    end

    def write(slice : Bytes) : Nil
      raise IO::Error.new("HTTP/2 response bodies are not writable")
    end

    def close : Nil
      @body.close
      merge_trailers
    end

    private def merge_trailers : Nil
      return if @trailers_merged

      if trailers = @stream.trailers?
        trailers.each do |key, values|
          values.each { |value| @response.trailers.add(key, value) }
        end
      end
      @trailers_merged = true
    end
  end

  class HTTP2Error < FatalError
  end

  class HTTP2GoawayError < HTTP2Error
  end

  class HTTP2StreamResetError < HTTP2Error
  end

  class HTTP2RefusedStreamError < HTTP2StreamResetError
  end

  class HTTP2Protocol < Protocol
    def name : String
      "h2"
    end

    def alpn_id : String
      "h2"
    end

    def alpn_ids : Array(String)
      ["h2", HTTP1Protocol.default.alpn_id]
    end

    def uses_host_header? : Bool
      false
    end

    def uses_connection_header? : Bool
      false
    end

    def uses_transfer_encoding? : Bool
      false
    end

    def multiplexed? : Bool
      true
    end

    def new_connection_protocol : Protocol
      HTTP2Protocol.new
    end

    def handle_request(env, full_url = false)
      connection = http2_connection(env)
      stream = connection.streams.create
      @streams[env.object_id] = stream
      @requests[stream] = Channel(Exception?).new(1)
      stream.send_headers(request_headers(env))

      if env.request.body_io?
        buffer = Bytes.new(16384)
        while (size = env.request.body_io.read(buffer)) > 0
          stream.send_data(buffer[0, size])
        end
        stream.send_data("", flags: HTTP2::Frame::Flags::END_STREAM)
      else
        stream.send_data("", flags: HTTP2::Frame::Flags::END_STREAM)
      end
    end

    def handle_response(env : HTTPEnv)
      stream = @streams.delete(env.object_id).not_nil!
      if error = @requests[stream].receive
        raise error
      end

      env.response.http_version = "2"
      env.response.status_code = stream.headers[":status"]
      stream.headers.each do |key, values|
        next if key.starts_with?(":")
        values.each { |value| env.response.headers.add(key, value) }
      end
      env.response.body_io = TransparentIO.new HTTP2BodyIO.new(stream, env.response), close_underlying_io: false
      env.connection.release
    ensure
      @requests.delete(stream) if stream
    end

    def request_to_http_io(env, full_url = false, io = nil)
      raise UnsupportedProtocolError.new("HTTP/2 does not use HTTP/1 request serialization")
    end

    def http_io_to_response(env : HTTPEnv, io = nil)
      raise UnsupportedProtocolError.new("HTTP/2 does not use HTTP/1 response parsing")
    end

    @connection : HTTP2::Connection? = nil
    @requests = {} of HTTP2::Stream => Channel(Exception?)
    @streams = {} of UInt64 => HTTP2::Stream

    private def http2_connection(env)
      @connection ||= begin
        connection = HTTP2::Connection.new(env.connection.socket, HTTP2::Connection::Type::CLIENT)
        connection.disable_huffman_encoding
        connection.write_client_preface
        connection.write_settings

        frame = connection.receive
        unless frame.try(&.type) == HTTP2::Frame::Type::SETTINGS
          raise UnsupportedProtocolError.new("Expected HTTP/2 SETTINGS frame")
        end

        spawn receive_frames(connection)
        connection
      end
    end

    private def receive_frames(connection)
      while frame = connection.receive
        case frame.type
        when HTTP2::Frame::Type::HEADERS
          signal_request(frame.stream, nil)
        when HTTP2::Frame::Type::RST_STREAM
          signal_request(frame.stream, stream_reset_error(frame))
        when HTTP2::Frame::Type::GOAWAY
          signal_all_requests(HTTP2GoawayError.new("HTTP/2 connection received GOAWAY"))
          return
        end
      end
      signal_all_requests(HTTP2Error.new("HTTP/2 connection closed"))
    rescue ex : IO::Error | IO::EOFError | HTTP2::Error
      message = ex.message || ex.class.name
      signal_all_requests(HTTP2Error.new("HTTP/2 connection failed: #{message}"))
    end

    private def signal_request(stream, error : Exception?) : Nil
      @requests[stream]?.try(&.send(error))
    rescue Channel::ClosedError
    end

    private def signal_all_requests(error : Exception) : Nil
      @requests.each_value do |channel|
        channel.send(error)
      rescue Channel::ClosedError
      end
    end

    private def stream_reset_error(frame)
      message = "HTTP/2 stream #{frame.stream.id} was reset"
      if code = frame.reset_error_code
        message = "#{message}: #{code}"
        return HTTP2RefusedStreamError.new(message) if code.refused_stream?
      end
      HTTP2StreamResetError.new(message)
    end

    private def request_headers(env)
      uri = env.request.uri
      headers = HTTP::Headers{
        ":method"    => env.request.method,
        ":scheme"    => uri.scheme.not_nil!,
        ":authority" => authority(uri),
        ":path"      => path_and_query(uri),
      }
      env.request.headers.each do |key, values|
        next if key.starts_with?(":")
        next if skip_header?(key)
        values.each { |value| headers.add(key.downcase, value) }
      end
      headers
    end

    private def authority(uri)
      if port = uri.port
        "#{uri.host}:#{port}"
      else
        uri.host.not_nil!
      end
    end

    private def path_and_query(uri)
      path = uri.path
      path = "/" if path.nil? || path.empty?
      if query = uri.query
        "#{path}?#{query}"
      else
        path
      end
    end

    private def skip_header?(key)
      case key.downcase
      when "connection", "host", "keep-alive", "proxy-connection", "transfer-encoding", "upgrade"
        true
      else
        false
      end
    end
  end
end
