module NGHTTP
  alias Resolver = (String -> String)
  alias SSLContextResolver = Proc(OpenSSL::SSL::Context::Client)

  class Connections
    # @available = Hash(String,Channel(Connection)).new
    @all = Hash(String, Channel(Transport)).new
    @connections_per_host = 1
    alias SSLClientContext = OpenSSL::SSL::Context::Client

    def get_timeout(t : Int)
      t
    end

    def get_timeout(t : Float)
      t
    end

    def get_timeout(t)
      raise Exception.new("invalid type #{t.class} for timeout")
    end

    def get(env : HTTPEnv, proxy_url : URI)
      debug_connect = env.config["debug_connect"]?
      uri = env.request.uri
      protocol = uri.scheme ? uri.scheme : "http"
      config_tls = env.config["tls"]?
      tls = if protocol == "https"
if config_tls.is_a?(Proc(OpenSSL::SSL::Context::Client))
              get_ssl_context config_tls.as(SSLContextResolver)
elsif config_tls.is_a?(OpenSSL::SSL::Context::Client)
get_ssl_context config_tls.as(OpenSSL::SSL::Context::Client)
else
              get_ssl_context config_tls
end
            else
              nil
            end
      if tls && env.config["verify"]? == false
        tls.verify_mode = OpenSSL::SSL::VerifyMode::None
      end
      tlso = if tls && config_tls.is_a?(SSLClientContext)
               "#{tls.verify_mode.to_i}/#{tls.options.to_u64}/#{config_tls.hash}"
             elsif tls
               "#{tls.verify_mode.to_i}/#{tls.options.to_u64}"
             else
               "0"
             end
      host = uri.host.not_nil!
      port = if uri.port
               uri.port.not_nil!
             elsif protocol == "https"
               443
             else
               80
             end
      origin = if resolver = env.config["resolver"]?
                 resolver.as(Resolver).call host
               else
                 host
               end
      env.int_config["origin"] = origin
      env.int_config["port"] = port
      proxyType = proxy_url ? proxy_url.scheme : nil
      key = if !proxyType || proxyType == "noproxy"
              "noproxy://nohost:/#{protocol}:#{origin}:#{port}/#tlso}"
            elsif protocol == "http" && (proxyType == "http" || proxyType == "https")
              "#{proxyType}://#{proxy_url.user}@#{proxy_url.host}:#{proxy_url.port}/#{protocol}::/#{tlso}"
            elsif proxyType == "socks4" || proxyType == "socks4a" || proxyType == "socks5"
              "#{proxyType}://#{proxy_url.user}@#{proxy_url.host}:#{proxy_url.port}/#{protocol}:#{origin}:#{port}/#{tlso}"
            elsif protocol == "https" && (proxyType == "http" || proxyType == "https")
              "#{proxyType}://#{proxy_url.user}@#{proxy_url.host}:#{proxy_url.port}/#{protocol}:#{origin}:#{port}/#{tlso}"
            else
              raise Exception.new("invalid scheme #{proxyType} protocol #{protocol}")
            end
      if !@all.has_key? key
        cls = case proxyType
              when "http", "https"
                HttpProxy
              when "socks4"
                Socks4Proxy
              when "socks4a"
                Socks4aProxy
              when "socks5"
                Socks5Proxy
              when "noproxy"
                DirectConnection
              else
                raise Exception.new("Invalid conection protocol #{proxyType}")
              end
        cph = env.config.fetch("connections_per_host", @connections_per_host).to_s.to_i
        queue = Channel(Transport).new(cph)
        @all[key] = queue
        cph.times do
          # origin is the resolved address
          opts = proxy_url.query ? HTTP::Params.parse(proxy_url.query.not_nil!) : nil
          connO = cls.not_nil!.new queue: queue, host: proxy_url.host.not_nil!, port: proxy_url.port.not_nil!, username: proxy_url.user, password: proxy_url.password, options: opts, tls: tls
          queue.send connO
        end
      end
      conn = @all[key].receive
      begin
        really_connect(env, conn)
        {conn, nil}
      rescue e
        {conn, e}
      end
    end

    def really_connect(env, conn)
      timeout = env.config.fetch("timeout",nil)
timeout = timeout ? timeout : 10
      connect_timeout = env.config.fetch("connect_timeout", timeout)
      read_timeout = env.config.fetch("read_timeout", timeout)
      connect_timeout = get_timeout connect_timeout
      read_timeout = get_timeout read_timeout
      conn.connect_timeout = connect_timeout
      conn.read_timeout = read_timeout
      slowbroke = env.config["use_slow_broken_check"]?
      if conn.no_socket?
        conn.connect env
      elsif conn.closed?
        conn.connect env
      elsif conn.require_reconnect?
        conn.close true
        conn.connect env
      elsif 1==0 && conn.broken?
        conn.close true
        conn.connect env
      else
      end # if
      conn
    end # def

private def get_ssl_context(ctxgen : SSLContextResolver)
ctxgen.call
end

    private def get_ssl_context(ctx : SSLClientContext)
      ctx
    end

    private def get_ssl_context(ctx : Nil)
      SSLClientContext.new
    end

    private def get_ssl_context(ctx)
      raise Exception.new("tls must be a client context, got #{typeof(ctx)}")
    end
  end # class
end   # module
