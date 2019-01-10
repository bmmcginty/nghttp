module NGHTTP
  class DirectConnection < Transport
    alias SocketType = TCPSocket | OpenSSL::SSL::Socket::Client | TransparentIO
    @rawsocket : TCPSocket? = nil
    @socket : SocketType? = nil

    def socket=(s)
      @socket = s
    end

    def socket?
      @socket
    end

    def rawsocket?
      @rawsocket
    end

    def connect(env : HTTPEnv)
      origin = env.int_config["origin"].as(String)
      port = env.int_config["port"].as(Int32)
      s = TCPSocket.new origin, port, @dns_timeout, @connect_timeout
      @rawsocket = s
      s.read_timeout = @read_timeout
      tls = @tls
      if tls
        begin
          s = OpenSSL::SSL::Socket::Client.new s, context: tls, hostname: env.request.uri.host.not_nil!, sync_close: false
        rescue e
          rs = @rawsocket
          if rs = @rawsocket
            rs.close
          end # if rawsocket
          raise e
        end
      end
      @socket = s
    end

    def handle_request(env : HTTPEnv)
      Utils.request_to_http_io env
    end

    def handle_response(env : HTTPEnv)
      Utils.http_io_to_response env
    end
  end # class
end
