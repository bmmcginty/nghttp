module Cache
abstract def get_key(env : NGHTTP::HTTPEnv)
abstract def have_key?(key : String)
abstract def get_cache(env : NGHTTP::HTTPEnv)
abstract def put_cache(env : NGHTTP::HTTPEnv)
end

class FSCache
include Cache
@root : String
@hd=OpenSSL::Digest.new("md5")

def initialize(path="cache/")
@root=path
end

def get_key(env : NGHTTP::HTTPEnv)
req=env.request
get_key(req.method,req.url,req.headers,req.body_io?)
end

def get_key(method,url,headers,body)
bad=/[^a-zA-Z0-9\/\._()-]+/
path=url.sub(':',"").gsub(bad,'_').gsub(/(^_+|_+$)/,"").gsub(/\/\/+/,"/")
if path.ends_with?("/")
path+="cache.noname"
end
@hd.reset
t=@hd.update(path).hexdigest[0..1]
"#{@root}/#{t}/#{path}.#{method}"
end

def put_cache(env)
key=get_key(env)
Dir.mkdir_p File.dirname key
fh=File.open(key+".temp","wb")
resp=env.response
rio=resp.body_io
fh << "HTTP/#{resp.http_version} #{resp.status_code}"
fh << " #{resp.status_message}" if resp.status_message
fh << "\n"
resp.headers.each do |k,vl|
vl.each do |v|
fh << "#{k}: #{v}\n"
end
end
fh << "\n"
rio.on_read do |slice,size|
fh.write slice[0,size]
fh.flush
end
rio.on_close do
finish_put env,fh
end
end

def finish_put(env,fh)
name=fh.path
fh.close
File.rename name,name[0..name.rindex(".temp").not_nil!-1]
end

def have_key?(env)
File.exists?(get_key(env))
end

def get_cache(env)
File.open(get_key(env),"rb")
end

end #class

module NGHTTP
class Cache
include Handler
@cacher : ::Cache
@default_cache : Bool
@wait : Int32|Float64

def cacher
@cacher
end

def initialize(cacher = FSCache, @default_cache = false, @wait = 1, **kw)
@cacher=cacher.new **kw
end

def call(env)
if env.request?
handle_request env
else env.response?
handle_response env
end
call_next env
end

def handle_request(env)
#if we don't provide cached results by default, and the request doesn't request it, don't return a cached result
rwait=env.config.fetch("wait",@wait)
if rwait.is_a?(Nil)
rwait=nil
else
rwait=rwait.as(String|Int32).to_f
end
#puts env.config["cache"]?
if env.config["cache"]? != true
sleep rwait.not_nil! if rwait
return
end
#no cache on file
unless cacher.have_key? env
env.int_config["to_cache"]=true
sleep rwait.not_nil! if rwait
return
end
env.int_config["from_cache"]=true
env.int_config["transport"]=self
end #def

def handle_transport(env)
#puts "getting response from cache"
if env.int_config["from_cache"]?
io=cacher.get_cache env
env.state=HTTPEnv::State::Response
Utils.http_io_to_response env,io
env.response.body_io=TransparentIO.new io
else
raise Exception.new "non-cached response given to cache handler"
end #if
end #def

def handle_response(env)
return if env.int_config["to_cache"]? != true
cacher.put_cache env
end #def

end #class
end #module

