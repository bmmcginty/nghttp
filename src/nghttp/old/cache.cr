require "./extension"
require "./response"

module NGHTTP
class CacheResponse < Response
end

class Cache < Extension
@resps=Hash(Response,IO).new
@root = "cache/"
@hd=OpenSSL::Digest.new("md5")

def get_key(resp : Response)
get_key(resp.request)
end

def get_key(req : Request)
get_key(req.method,req.url,req.headers,req.body)
end

def get_key(method,url,headers,body)
bad=/[^a-zA-Z0-9\/\._()-]+/
path=url.sub(':',"").gsub(bad,'_').gsub(/(^_+|_+$)/,"").gsub(/\/\/+/,"/")
if path.ends_with?("/")
path+="cache.noname"
end
@hd.reset
t=@hd.update(path).hexdigest[0..1]
#path=path.gsub(/\/([^\/]{2,2})/) do |s|
#puts s
#"/#{s}/#{s}"
#end
"#{@root}/#{t}/#{path}.#{method}"
end

def put(resp)
key=get_key(resp)
Dir.mkdir_p key.reverse.split("/",2)[1].reverse
fh=File.open(key+".temp","wb")
@resps[resp]=fh
resp.io.on_read do |slice,size|
fh.write slice[0,size]
end
end

def have_cached_request?(req)
File.exists?(get_key(req))
end

def get_cached_request(req)
File.open(get_key(req.method,req.url,req.headers,req.body),"rb")
end

def setup(default_cache = false, path = nil, wait = 1)
if path
@root=path
end
client.custom_response do |req|
#if we don't provide cached results by default, and the request doesn't request it, don't return a cached result
rwait=req.config.fetch("wait",wait)
if rwait.is_a?(Nil)
rwait=nil
else
rwait=rwait.as(String|Int32).to_f
end
if default_cache == false && req.config["cache"]? != true
sleep rwait.not_nil! if rwait
next nil
end
#if the request specifically requests no caching
if req.config["cache"]? == false
sleep rwait.not_nil! if rwait
next nil
end
#no cache on file
unless have_cached_request? req
sleep rwait.not_nil! if rwait
next nil
end
io=get_cached_request req
t=CacheResponse.new req,io
t=t.dispatch
next t
end
client.before_response do |resp|
#puts "before_response:#{resp}"
next nil if resp.is_a?(CacheResponse)
if default_cache == false && resp.request.config["cache"]? != true
next nil
end
put resp
nil
end
client.after_response do |resp|
#puts "after_response:#{resp}"
next nil if resp.is_a?(CacheResponse)
next nil unless @resps.has_key?(resp)
#puts "skip_to_end"
#resp.io.gets_to_end
#puts "disable io hooks"
resp.io.on_read=resp.io.on_write=nil
#puts "cache:closing:#{resp},fh:#{@resps[resp]}"
@resps[resp].close
@resps.delete resp
key=get_key(resp)
File.rename(key+".temp",key)
nil
end #after_Response
end #def
end #class
end

