module NGHTTP
  class HttpProxy < DirectConnection
    HTTPS_PROXY = false

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
      s = TCPSocket.new(@proxy_host, @proxy_port)
      @rawsocket = s
      if HTTPS_PROXY
        ctx = OpenSSL::SSL::Context::Client.new
        # todo: fix this to take false/0 or change to get rid of string-passing config mess altogether
        if @proxy_options && @proxy_options.not_nil!["verify"]? == "false"
          ctx.verify_mode = OpenSSL::SSL::VerifyMode::None
        end
        s = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: @proxy_host, sync_close: true
      end
      # https over an http proxy
      if env.request.uri.scheme == "https"
        origin = env.int_config["origin"]
        port = env.int_config["port"]
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
        tls = @tls.as(OpenSSL::SSL::Context::Client)
        t = OpenSSL::SSL::Socket::Client.new s, context: tls, hostname: env.request.uri.host, sync_close: true
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
    end

    def handle_response(env)
      Utils.http_io_to_response env
    end
  end # class
end   # module
