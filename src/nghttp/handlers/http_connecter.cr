module NGHTTP
class HTTPConnecter
include Handler

def initialize
end

def call(env)
handle_transport env
call_next env
end #def

# Send this request out to be filled.
# If a proxy has been set via the proxies config key, parse that proxy url and attach it to this request.
# We do this evenf or requests with explicitly set transports, in case those transports faile (cache has deleted file).
# Todo: possibly remove proxy search when transport has been explicitly selected.
# If a transport has been configured via int_config, use that transport directly.
# Otherwise, submit this request to the connection manager to get a transport.
# Send this request to the transport and process the response.
def handle_transport(env)
proxies=env.config["proxies"]?.as(Hash(String,String)|Nil)
#if no proxies, use SimpleConnection
noproxy="noproxy://nohost:0"
pUrl = if proxies == nil
noproxy
elsif proxies && proxies.empty?
noproxy
#{"http://example.com"=>"socks4a://[username:password@]sockshost:socksport"}
elsif p=proxies.not_nil!["#{env.request.uri.scheme}://#{env.request.uri.host}"]?
p
#{"http"=>"http://[username:password@]proxyhost:proxyport"}
elsif p=proxies.not_nil!["#{env.request.uri.scheme}"]?
p
#no proxy valid for this url, so use a SimpleConnection
else
noproxy
end
pUri=URI.parse pUrl
env.int_config["proxy"]=pUri
realConn = if t = env.int_config["transport"]?
#todo:if transport is explicitly set, it won't get the values from the resolver, like other prixies
#todo:perhaps set cache to make a cache:// url that it can read with values, like the other proxies?
t.as(Transport)
else
env.session.connections.get env,pUri
end
env.connection=realConn
env.state=HTTPEnv::State::Request
realConn.handle_request env
env.state=HTTPEnv::State::Response
realConn.handle_response env
end

end #class
end #module

