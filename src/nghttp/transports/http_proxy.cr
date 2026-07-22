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
        ctx.alpn_protocol = HTTP1Protocol.default.alpn_id
        s = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: proxy_uri.host.not_nil!, sync_close: true
      end # if https
      # https over an http proxy
      if env.request.uri.scheme == "https"
        origin = env.int_config.origin
        port = env.int_config.port
        s << "CONNECT #{origin}:#{port} HTTP/1.1\r\n"
        s << "Host: #{origin}:#{port}\r\n"
        if auth_header = proxy_authorization_header(env, proxy_uri)
          s << "Proxy-Authorization: #{auth_header}\r\n"
        end
        s << "\r\n"
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
        configure_alpn ctx
        t = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: env.request.uri.host, sync_close: true
        select_alpn_protocol t
        @socket = t
      else
        @socket = s
      end # if
    end   # def

    def handle_request(env)
      useLongUrl = env.request.uri.scheme == "http"

      if useLongUrl && !protocol.is_a?(HTTP1Protocol)
        raise UnsupportedProtocolError.new("HTTP/2 over forward HTTP proxies is not supported")
      end

      # if we're an http url, add creds here instead of in a connect method
      if useLongUrl
        proxy_uri = URI.parse env.int_config.proxy
        proxy_auth = proxy_authorization_header(env, proxy_uri)
        env.request.headers["Proxy-Authorization"] = proxy_auth if proxy_auth
      end

      protocol.handle_request env, useLongUrl
    end

    private def proxy_authorization_header(env, proxy_uri)
      user = proxy_uri.user
      return nil unless user

      password = proxy_uri.password || ""
      encoded = Base64.strict_encode("#{user}:#{password}")
      "Basic #{encoded}"
    end
  end # class
end   # module
