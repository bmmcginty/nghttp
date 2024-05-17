require "./socks/*"

{% for i in %w(Socks4 Socks4a Socks5) %}
class NGHTTP::{{i.id}}Proxy < NGHTTP::DirectConnection
@socks : Socks::Socks? = nil
getter! :socks

def connect(env : HTTPEnv)
origin=env.int_config.origin.as(String)
port=env.int_config.port.as(Int32)
proxy_uri=URI.parse env.int_config.proxy
@socks=::Socks::{{i.id}}.new proxy_uri.host.not_nil!, proxy_uri.port.not_nil!, proxy_uri.user, proxy_uri.password
socks.connect origin,port
s=socks.socks
@rawsocket=s
s.read_timeout = @read_timeout
if env.request.uri.scheme=="https"
s=OpenSSL::SSL::Socket::Client.new s, hostname: env.request.uri.host.not_nil!, sync_close: true
end # if
@socket=s
end

end
{% end %}
