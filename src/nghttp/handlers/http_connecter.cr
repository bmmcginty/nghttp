module NGHTTP
  class HTTPConnecter
    include Handler
alias ProxyVendor=(String->String?)

    def initialize
    end

    # For requests, ensure a connection exists.
    # For responses, parse the response headers from the server.
    def call(env)
a=Time.monotonic
      if env.request?
        ensure_transport env
      elsif env.response?
        env.connection.not_nil!.handle_response env
      end
b=Time.monotonic
#puts "#{(b-a).total_seconds} connector #{env.request?}"
      call_next env
    end # def

    # Send this request out to be filled.
    # If a proxy has been set via the proxies config key, parse that proxy url and attach it to this request.
    # We do this evenf or requests with explicitly set transports, in case those transports faile (cache has deleted file).
    # Todo: possibly remove proxy search when transport has been explicitly selected.
    # If a transport has been configured via int_config, use that transport directly.
    # Otherwise, submit this request to the connection manager to get a transport.
    # Send this request to the transport and process the response.
    def ensure_transport(env)
      proxies = env.config["proxies"]?.as(Hash(String, String) | Nil)
      # if no proxies, use SimpleConnection
      noproxy = "noproxy://nohost:0"
      pUrl = if proxies == nil
ev=env.config["proxy_vendor"]?
if ev
ev.as(ProxyVendor).call("#{env.request.uri.scheme}://#{env.request.uri.host}").as(String)
else
               noproxy
end
             elsif proxies && proxies.empty?
               noproxy
               # {"http://example.com"=>"socks4a://[username:password@]sockshost:socksport"}
             elsif p = proxies.not_nil!["#{env.request.uri.scheme}://#{env.request.uri.host}"]?
               p
               # {"http"=>"http://[username:password@]proxyhost:proxyport"}
             elsif p = proxies.not_nil!["#{env.request.uri.scheme}"]?
               p
               # no proxy valid for this url, so use a SimpleConnection
             else
               noproxy
             end
      pUri = URI.parse pUrl
      env.int_config["proxy"] = pUri
      realConn, err = if t = env.int_config["transport"]?
                        # todo:if transport is explicitly set, it won't get the values from the resolver, like other proxies
                        # todo:perhaps set cache to make a cache:// url that it can read with values, like the other proxies?
                        {t.as(Transport), nil}
                      else
                        env.session.connections.get(env, pUri)
                      end
      env.connection = realConn
      raise err if err
      if t = env.config["debugfn"]?
        dbg = t.as(IO)
        s = realConn.socket = TransparentIO.new realConn.socket
        s.on_read do |slice, size|
          dbg << "r:"
          dbg.write slice[0, size]
          dbg.flush
        end
        s.on_write do |slice|
          dbg << "w:"
          dbg.write slice
          dbg.flush
        end
        s.on_close do
          dbg.close
        end
      end # if debugfn
    end
  end # class
end   # module
