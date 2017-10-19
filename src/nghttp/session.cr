module NGHTTP
class Session
@connections = Connections.new
@headers = HTTP::Headers.new
@config = HTTPEnv::ConfigType.new
@start_handler : Handler? = nil
@handlers : Array(Handler.class)? = nil

getter! :start_handler,:connections

def initialize(**kw)
setup_handlers
@headers.add "User-Agent","Crystal"
@headers.add "Accept", "*/*"
@headers.add "Connection","keep-alive"
@config.merge! kw
end

{% for method in %w(head get post put delete options) %}
def {{method.id}}(url,**kw)
begin
resp=request(**kw, method: {{method}}, url: url)
yield resp
ensure
if resp
resp.close
end
end
end #def

def {{method.id}}(url, **kw)
request(**kw, method: {{method}}, url: url)
end #def

{% end %}

def request(method = "", url = "", headers : HTTP::Headers? = nil, params : Hash(String,String)|Nil = nil, body : IO|Nil = nil, config : HTTPEnv::ConfigType|Nil = nil, **kw)
env=HTTPEnv.new
env.session=self
env.response.env=env
env.config.merge! @config
cfg=nil
kw.each do |k,v|
ks=k.to_s
if ks.starts_with?("internal_")
env.int_config[ks]=v
else
env.config[ks]=v
end
end
if config
cfg2=env.config
env.config=config
env.config.merge! cfg2
end
#env.config.merge! kw
env.request.method=method
env.request.uri=URI.parse url
set_host_header env
env.request.headers.merge! @headers
if headers
env.request.custom_headers=headers
env.request.headers.merge!(headers)
end
if params
enc_p = HTTP::Params.encode params
p = env.request.uri.query
p = p ? p : ""
p=p.not_nil!
if p == ""
p+=enc_p
elsif p.ends_with? "&"
p+=enc_p
else
p+="&#{enc_p}"
end
env.request.uri.query = p
end
if body
env.request.body_io = body
end
run_env env
env.response
end

def set_host_header(env)
hn = if env.request.uri.port == 80 && env.request.uri.scheme == "http"
"#{env.request.uri.host}"
elsif env.request.uri.port == 443 && env.request.uri.scheme == "https"
"#{env.request.uri.host}"
elsif env.request.uri.port==nil
"#{env.request.uri.host}"
else
"#{env.request.uri.host}:#{env.request.uri.port}"
end
env.request.headers["Host"]=hn
end

def run_env(env)
env.state=HTTPEnv::State::Request
start_handler.call env
end

def setup_handlers
custom_handlers=@handlers
handlers_list=custom_handlers ? custom_handlers : Handlers.default
other=handlers_list.first.new
@start_handler = other
handlers_list[1..-1].each do |this_class|
this=this_class.new
other.next=this
this.previous=other
other=this
end #each
end #def

end #class
end #module

