require "http2"

class HTTP2::Connection
  def client? : Bool
    @type.client?
  end

  def stream_capacity_available? : Bool
    return true unless max = remote_settings.max_concurrent_streams

    streams.active_count_for_stream_type(@type.client? ? 1 : 0) < max
  end

  private def read_rst_stream_frame(frame)
    raise Error.frame_size_error unless frame.size == RST_STREAM_FRAME_SIZE
    error_code = Error::Code.new(io.read_bytes(UInt32, IO::ByteFormat::BigEndian))
    frame.reset_error_code = error_code
    Log.trace { "  code=#{error_code}" }
  end

  private def read_headers_frame(frame)
    stream = frame.stream

    read_padded(frame) do |size|
      if frame.flags.priority?
        exclusive, dep_stream_id = read_stream_id
        raise Error.protocol_error("INVALID stream dependency") if stream.id == dep_stream_id
        weight = read_byte.to_i32 + 1
        stream.priority = Priority.new(exclusive == 1, dep_stream_id, weight)
        Log.trace { "  #{stream.priority.debug}" }
        size -= 5
      end

      if stream.data? && !frame.flags.end_stream?
        raise Error.protocol_error("INVALID trailer part")
      end

      buffer = read_headers_payload(frame, size)

      begin
        if stream.data?
          hpack_decoder.decode(buffer, stream.trailers)
        else
          hpack_decoder.decode(buffer, stream.headers)
          if @type.server?
            validate_request_headers(stream.headers)
          else
            validate_response_headers(stream.headers)
          end
        end
      rescue ex : HPACK::Error
        Log.trace { "HPACK::Error: #{ex.message}" }
        raise Error.compression_error
      end

      if stream.data? || frame.flags.end_stream?
        stream.data.close_write

        if content_length = stream.headers["content-length"]?
          unless content_length.to_i == stream.data.size
            raise Error.protocol_error("MALFORMED data frame")
          end
        end
      end
    end
  end
end

class HTTP2::Streams
  def create(state = Stream::State::IDLE) : Stream
    @mutex.synchronize do
      if max = @connection.remote_settings.max_concurrent_streams
        if unsafe_active_count_for_stream_type(@connection.client? ? 1 : 0) >= max
          raise Error.refused_stream("MAXIMUM outgoing stream capacity reached")
        end
      end
      id = @id_counter += 2
      raise Error.internal_error("STREAM #{id} already exists") if @streams[id]?
      @streams[id] = Stream.new(@connection, id, state: state)
    end
  end

  def active_count_for_stream_type(type) : Int32
    @mutex.synchronize { unsafe_active_count_for_stream_type(type) }
  end

  private def unsafe_active_count_for_stream_type(type) : Int32
    @streams.reduce(0) do |count, (_, stream)|
      if stream.id != 0 && stream.id % 2 == type && stream.active?
        count + 1
      else
        count
      end
    end
  end
end

class HTTP2::Frame
  property reset_error_code : HTTP2::Error::Code?
end

class HTTP2::HPACK::Huffman
  def decode(bytes : Bytes)
    io = IO::Memory.new
    node = tree
    eos_padding = true
    padding_length = 0

    bytes.each do |byte|
      7.downto(0) do |i|
        padding_length += 1

        if byte.bit(i) == 1
          node = node.right
        else
          node = node.left
          eos_padding = false
        end

        raise HTTP2::HPACK::Error.new("node is nil!") unless node

        if value = node.value
          io.write_byte(value)
          node = tree
          eos_padding = true
          padding_length = 0
        end
      end
    end

    unless node == tree
      raise HTTP2::HPACK::Error.new("huffman string padding is larger than 7-bits") if padding_length > 7
      raise HTTP2::HPACK::Error.new("huffman string padding must use MSB of EOS symbol") unless eos_padding
    end

    io.to_s
  end
end
