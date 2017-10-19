module NGHTTP
class Client
@default_headers = HTTP::Headers.new
@version = "HTTP/1.1"
@connections = Hash(String,Array(Connection)).new
@proxys = Hash(String,String).new
@cookiejar = Cookiejar.new
@before_request_hooks = Array((Request->)).new
@after_request_hooks = Array((Request->)).new
@custom_response_hooks = Array((Request->(Response|Nil))).new
@before_response_hooks = Array((Response->Response|Nil)).new
@after_response_hooks = Array((Response->Response|Nil)).new
@after_response_parse_hooks = Array((Response->Response|Nil)).new
@connections_per_host = 4
@read_timeout = 30
@connect_timeout = 2
@tries = 1
property :tries

{% for name in %w(connect_timeout read_timeout) %}
def {{name.id}}=(val)
@{{name.id}}=val
connections.each do |k,v|
v.each do |c|
c.{{name.id}}=val
if c.socket
c.socket.{{name.id}}=val
end #socket
end #conn
end #hash
end #def
{% end %}

{% for w in %w(before_request after_request custom_response before_response after_response after_response_parse) %}
def {{w.id}}_hooks
@{{w.id}}_hooks
end
{% end %}
{% for w in %w(before_request after_request) %}
def {{w.id}}(&b : (Request->))
@{{w.id}}_hooks << b
end
{% end %}
{% for w in %w(before_response after_response after_response_parse) %}
def {{w.id}}(&b : (Response->Response|Nil))
@{{w.id}}_hooks << b
end
{% end %}
def custom_response(&b : (Request->Response|Nil))
custom_response_hooks << b
end

property cookiejar,proxys,connections_per_host,version
getter before_request_hooks,custom_response_hooks,before_response_hooks,after_Response_hooks,after_response_parse_hooks,connections,default_headers

def cookies
cookiejar.cookies
end

def get_connection(url : String, force_reconnect = false)
get_connection(URI.parse(url), force_reconnect: force_reconnect)
end

def get_connection(uri : URI, force_reconnect = false)
scheme= uri.scheme ? uri.scheme : "http"
if uri.port
port = uri.port.not_nil!
else
port = (uri.scheme == "http") ? 80 : 443
end
host=uri.host.not_nil!
key="#{scheme}/#{host}/#{port}"
unless connections.has_key? key
connections[key]=Array(Connection).new
end
conns=connections[key]
avail=conns.select &.available
if avail.size == 0 && conns.size < @connections_per_host
#puts "new conn for #{key}"
conns.push Connection.new(host: host, port: port, tls: scheme=="https", connect_timeout: @connect_timeout, read_timeout: @read_timeout)
avail=conns.select &.available
end
while avail.size == 0
#puts "unavail"
sleep 1
avail=conns.select &.available
end
avail[-1].acquire force_reconnect: force_reconnect
end #def

def initialize
self.default_headers = { "User-Agent" => "Crystal", "Accept" => "*/*", "Connection" => "keep-alive" }
end

def default_headers=(d)
@default_headers.merge! d
end

{% for method in %w(head get post put delete options) %}
def {{method.id}}(url, headers = nil, body = nil, tries = nil, max_backoff = 16, **kw)
r=Request.new(client: self, method: {{method.id.stringify}}, url: url, headers: headers, body: body)
r.config.merge! kw
ctr=0
backoff=1
ret=nil
tries = tries ? tries : @tries
tries=tries.not_nil!
while 1
if r.connection
r.connection.not_nil!.release
r.connection=nil
end
if tries > -1 && ctr >= tries
raise Exception.new("no more retries for url #{r.url}, #{ctr}/#{tries} tries failed")
end
r.config["force_reconnect"] = true if ctr > 0
begin
t = r.dispatch
ret=t
break
rescue e
backoff = 1 if backoff > max_backoff
#puts "sleeping:#{backoff}, error:#{e.to_s}"
sleep backoff
backoff = backoff * 2
ctr+=1
end
end
ret.not_nil!
end

def {{method.id}}(*a,**kw)
begin
resp={{method.id}}(*a,**kw)
yield resp
ensure
resp.not_nil!.finish
end
end
{% end %}

end #class
end #module

