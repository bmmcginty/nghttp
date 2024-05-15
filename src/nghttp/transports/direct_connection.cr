module NGHTTP
  class DirectConnection < Transport
    @rawsocket : TCPSocket? = nil
    @socket : SocketType? = nil
getter! socket

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

    def broken? : Bool
      broken = true
      begin
        socket.wait_readable 0.1.seconds
      rescue e
        broken = false
      end # read?
      broken
    end

    def handle_request(env : HTTPEnv)
      Utils.request_to_http_io env
if env.request.body_io?
          IO.copy(env.request.body_io, env.connection.socket)
env.connection.socket.flush
end
    end

    def handle_response(env : HTTPEnv)
      Utils.http_io_to_response env
    end

  end # class
end
