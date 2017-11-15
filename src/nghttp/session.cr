module NGHTTP
class Session
@connections = Connections.new
@headers = HTTP::Headers.new
@config = HTTPEnv::ConfigType.new
@start_handler : Handler? = nil
@handlers = Array(Handler).new

getter :config,:headers
getter! :start_handler,:connections

def get_handler(name)
name=name.underscore
handlers.each do |i|
if i.name.underscore==name
return i
end
end #each
end #def

def initialize(**kw)
init kw
setup_handlers Handlers.default
end

def initialize(**kw)
init kw
h=yield Handlers.default
setup_handlers h
end

def init(kw)
@headers.add "User-Agent","Crystal"
@headers.add "Accept", "*/*"
@headers.add "Connection","keep-alive"
@config.merge! kw
end

{% for method in %w(head get post put delete options) %}
def {{method.id}}(url : String = "", params : Hash(String,String)? = nil, body : IO|String|Nil = nil, headers : HTTP::Headers? = nil, config : HTTPEnv::ConfigType? = nil, **kw)
#url : String = "", params : Hash(String,String)? = nil, body : IO|String|Nil = nil, headers : HTTP::Headers? = nil
env=request(method: {{method}}, url: url, params: params, body: body, headers: headers, config: config, extra: kw)
run_env env
end #def

def {{method.id}}(url : String = "", params : Hash(String,String)? = nil, body : IO|String|Nil = nil, headers : HTTP::Headers? = nil, config : HTTPEnv::ConfigType? = nil, **kw)
env=request(method: {{method}}, url: url, headers: headers, params: params, body: body, config: config, extra: kw)
resp=run_env env
#STDOUT.puts "resp:#{resp}"
#STDOUT.puts "yielding resp for #{env.request.uri.to_s}"
yield resp
#STDOUT.puts "yielded resp for #{env.request.uri.to_s}"
resp.body_io.skip_to_end
#STDOUT.puts "closing env for #{env.request.uri.to_s}"
env.close
resp
end #def

{% end %}

def request(*, method, url, params, body, headers, config, extra)
env=HTTPEnv.new
env.session=self
env.response.env=env
env.config.merge! @config
if config
env.config.merge! config
end
extra.each do |k,v|
ks=k.to_s
case ks
when .starts_with?("internal_")
env.int_config[ks.split("_",2)[1]]=v
else
env.config[ks]=v
end
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
env.request.body_io = body.is_a?(String) ? IO::Memory.new(body) : body
end
env
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

def run_env(env : HTTPEnv)
env.state=HTTPEnv::State::Request
begin
start_handler.call env
rescue e
env.close true
raise e
end
env.response
end

def setup_handlers(handlers_list)
other=handlers_list.first
if other.is_a?(Handler)
other=other
else
other=other.new
end
other=other.as(Handler)
@start_handler = other
handlers_list[1..-1].each do |this_class|
if this_class.is_a?(Handler)
this=this_class
else
this=this_class.new
end
this=this.as(Handler)
other.next=this
this.previous=other
other=this
end #each
end #def

end #class
end #module

