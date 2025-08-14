module NGHTTP
  class HttpProxy < DirectConnection
    @https_proxy = false

    alias SocketType = TCPSocket | OpenSSL::SSL::Socket::Client | TransparentIO
    @rawsocket : TCPSocket? = nil
    @socket : SocketType? = nil

    def connect(env : HTTPEnv)
      proxy_uri = URI.parse env.int_config.proxy
      s = TCPSocket.new(proxy_uri.host.not_nil!, proxy_uri.port.not_nil!)
      @rawsocket = s
      if @https_proxy
        ctx = OpenSSL::SSL::Context::Client.new
        if env.config.ca_paths?
          env.config.ca_paths.each { |i| ctx.ca_certificates = i }
        end
        if proxy_uri.query_params["verify"]? == "0"
          ctx.verify_mode = OpenSSL::SSL::VerifyMode::None
        end
        s = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: proxy_uri.host.not_nil!, sync_close: true
      end # if https
      # https over an http proxy
      if env.request.uri.scheme == "https"
        origin = env.int_config.origin
        port = env.int_config.port
        s << "CONNECT #{origin}:#{port} HTTP/1.1\r\nHost: #{origin}\r\n\r\n"
        s.flush
        rs = s.gets
        rh = [] of String
        while 1
          t = s.gets.not_nil!
          break if t.size == 0
          rh << t
        end # while
        parts = rs.not_nil!.split(" ")
        if parts.size < 2
          raise Exception.new("HTTP Proxy returned #{rs}  when connecting to #{origin}:#{port}")
        end
        if parts[1] != "200"
          s.close
          raise Exception.new("HTTP Proxy returned HTTP error #{parts[1]} when connecting to #{origin}:#{port}")
        end
        #        tls = @tls.as(OpenSSL::SSL::Context::Client)
        ctx = OpenSSL::SSL::Context::Client.new
        if env.config.ca_paths?
          env.config.ca_paths.each { |i| ctx.ca_certificates = i }
        end
        if env.config.verify? == false
          ctx.verify_mode = OpenSSL::SSL::VerifyMode::None
        end
        t = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: env.request.uri.host, sync_close: true
        @socket = t
      else
        @socket = s
      end # if
    end   # def

    def handle_request(env)
      useLongUrl = if env.request.uri.scheme == "https"
                     true
                   else
                     false
                   end
      Utils.request_to_http_io env, useLongUrl
      if env.request.body_io?
        IO.copy(env.request.body_io, env.connection.socket)
        env.connection.socket.flush
      end
    end
  end # class
end   # module
