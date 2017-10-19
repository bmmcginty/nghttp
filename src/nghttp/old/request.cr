class Hash(K,V)
def merge!(t : NamedTuple)
t.each do |k,v|
self[k.to_s]=v
end
end

end

module NGHTTP
class Request
delegate before_request_hooks, after_request_hooks, before_response_hooks, custom_response_hooks, after_response_hooks, default_headers, cookiejar, connections, to: client
delegate version, to: client
@custom_headers : Hash(String,String)|HTTP::Headers|Nil = nil
@headers : HTTP::Headers
@url : String
@body : IO|String|Nil
@client : Client
@connection : Connection?
@start_time = Int64.new(0)
@io = TransparentIO.new
@tag = ""
@config = Hash(String,String|Bool|Int32|Float64|Nil).new

property client,connection,method,url,headers,body,start_time,tag
#getter! connection
getter io,config

def initialize(client : Client, method : String, url : String, headers : HTTP::Headers|Hash|Nil = nil, body : String|IO|Nil = nil, config = nil)
if headers.is_a? Hash
h=headers
headers=HTTP::Headers.new
h.each do |k,v|
headers[k]=v
end
end
if config
@config=config.not_nil!
end
if !(method == "post" || method == "put") && body
raise Errors::HTTP::InvalidRequestBody.new %(#{method}/"#{url}")
end
@method=method
@client=client
@url=url
h=default_headers.dup
@headers=h
@body=body
@custom_headers = headers
end

def dispatch
host=url.split("://",2)[1].split("/",2)[0].reverse.split("@",2)[0].reverse.split(":")[0]
@headers["Host"]=host
@headers.merge!(@custom_headers.not_nil!) if @custom_headers
cookiejar.update_headers @headers,url
@start_time=Time.now.epoch
#you'd add request signing for authentication via these hooks, for example
before_request_hooks.each do |hk|
t=hk.call(self)
end
#if you want your caching layer to intercept an outbound request and return a response, return it below
ret=nil
ret=custom_response_hooks.each do |hk|
t=hk.call self
#puts "hk:#{hk},t:#{t}"
return t if t
end #each
if ret
#puts "custom_resp:#{ret}"
end
unless ret
ret=default_send
end
after_request_hooks.each do |hk|
hk.call self
end
ret.not_nil!
end

def default_send
fr=@config["force_reconnect"]? == true
@connection=client.get_connection @url,fr
send
resp=Response.new self
resp.dispatch
end #def

def connection
@connection
end

def socket
@connection.not_nil!.socket.not_nil!
end

def send
@io.io=socket
socket=self.io
tu=URI.parse(url).not_nil!
t=tu.path.not_nil!
if tu.query
t+="?#{tu.query.not_nil!}"
end
eurl=t
socket << "#{method.upcase} #{eurl} #{version}\r\n"
if body
#if body && body.is_a?(String)
headers.add "Transfer-Encoding","chunked"
end
headers.each do |k,v|
v.each do |vv|
socket << "#{k}: #{vv}\r\n"
end
end
socket << "\r\n"
if body
ceb=ChunkWriter.new socket
if body.is_a? String
ceb.write body.as(String).to_slice
else
IO.copy body.as(IO),ceb
end
ceb.close
end
socket.flush
end

end #class

end #module

