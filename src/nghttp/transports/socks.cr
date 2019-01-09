require "./socks/*"

module NGHTTP
  {% for i in %w(Socks4 Socks4a Socks5) %}
class {{i.id}}Proxy < DirectConnection
@socks : Socks::Socks? = nil
getter! :socks

def connect(env : HTTPEnv)
origin=env.int_config["origin"].as(String)
port=env.int_config["port"].as(Int32)
@socks=::Socks::{{i.id}}.new @proxy_host,@proxy_port,@proxy_username,@proxy_password
socks.connect origin,port
s=socks.socks
@rawsocket=s
s.read_timeout = @read_timeout
tls=@tls
if tls
s=OpenSSL::SSL::Socket::Client.new s, context: tls, hostname: env.request.uri.host.not_nil!, sync_close: true
end
@socket=s
end

#Todo:change this if the socks proxy uses encapsulation.
#Todo:if so, call socks.socks to get rawsocket

end
{% end %}
end
