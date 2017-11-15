module NGHTTP
{% for i in %w(Socks4 Socks4a Socks5) %}
class {{i.id}}Proxy < DirectConnection
end
{% end %}

end

