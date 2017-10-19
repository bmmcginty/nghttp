module NGHTTP
class Response
@request : Request
@io = TransparentIO.new
@body_io : IO?
@status_code = 0
@status_message = ""
@http_version = ""
@headers = HTTP::Headers.new
@finished = false
@history : Array(Response)? = nil
@body : String? = nil

delegate client, connection, to: request

property request,http_version,status_code, status_message, headers, io,history
getter! body_io

def body
unless @body
t=body_io.gets_to_end
@body = ( t ? t : "" ).not_nil!
finish
end
@body.not_nil!
end

def initialize(@request : Request)
io.io=request.socket.not_nil!
end

def initialize(request : Request, io : IO)
@request=request
self.io.io=io
end

def dispatch
request.before_response_hooks.each do |hk|
hk.call self
end
t=handle_response
#puts "response:dispatch:returns #{t}"
t
end

def handle_response
read_status_and_headers
set_connection_keepalive
handle_cookies
make_body_reader
ret=nil
ret=client.after_response_parse_hooks.each do |hk|
t=hk.call self
#puts "after_response_parse:#{t}"
if t
#puts "arp:#{t.not_nil!.request.url}"
end
#puts "t:#{t}"
return t if t
end
if ret
#puts "ret:#{ret.not_nil!.request.url}"
return ret
else
return self
end
end

def read_status_and_headers
sock=@io
reqline=sock.gets(limit: 16384)
if reqline
reqline=reqline.strip
end
unless reqline
raise Errors::HTTP::NoResponse.new request.url
end
version,status=reqline.split(" ",2)
if status.index(" ")
status,message=status.split(" ",2)
status=status.to_i
else
status=status.to_i
message=HTTP.default_status_message_for status
end
@http_version,@status_code,@status_message=version,status,message
k,v="",""
rh=@headers
while 1
line=sock.gets(limit: 16384)
if line
line=line.strip
end
break if line==nil || line.not_nil!.size == 0
k,v=line.not_nil!.split(": ",2)
rh.add k,v
end #while
end #def

def handle_cookies
request.client.cookiejar.update_cookiejar headers, request.url
end #def

def set_connection_keepalive
return unless connection
connection=self.connection.not_nil!
connection.keepalive=if http_version=="HTTP/1.0" && headers["Connection"]? != "keep-alive"
false
elsif headers["Connection"]? == "close"
false
else
true
end
ka=headers["Keep-Alive"]?
#keepalive by default
return unless ka
ka.split(/, */).each do |param|
k,v=param.split(/ *= */,2)
if k=="timeout"
connection.keepalive_expires=request.start_time+v.to_i64
end #timeout
if k=="max"
connection.max_requests=v.to_i
end #max
end #params
end #def

def make_body_reader
sock=@io
okay=false
transferEncoding=headers["Transfer-Encoding"]?
if transferEncoding && transferEncoding != "identity"
out_io=ChunkReader.new sock
okay=true
else
out_io=TransparentIO.new sock
end
if !transferEncoding && headers["Content-Length"]?
out_io=SizedReader.new out_io,headers["Content-Length"].to_i
okay=true
end
unless okay
raise Errors::HTTP::MalformedBodyEncoding.new request.url
end
contentEncoding=headers["Content-Encoding"]?
if contentEncoding
contentEncoding.split(/, */).reverse.each do |ce|
out_io=case ce.downcase
when "gzip"
Gzip::Reader.new out_io
when "deflate"
Flate::Reader.new out_io
when "zlib"
Zlib::Reader.new out_io
when "identity"
out_io
else
raise Errors::HTTP::InvalidContentEncoding.new ce,request.url
end #case
end #each
end #if
@body_io=out_io
end #def

def is_redirect?
[301,302,303,307].index(status_code) != nil
end

def finalize
finish
end

def finish
return if @finished
#puts "finish:#{request.url}, body_io:#{body_io},io:#{@io.io},closed:#{self.io.io.not_nil!.closed?}"
begin
body_io.skip_to_end
#puts "finished:#{request.url}, body_io:#{body_io},io:#{@io.io},closed:#{self.io.io.not_nil!.closed?}"
#puts "closing body_io"
body_io.close
#puts "closed body_io"
rescue e
#raise e
ensure
if connection
#puts "releasing pooled connection"
connection.not_nil!.release
request.connection=nil
end
end
request.after_response_hooks.each do |hk|
#puts "calling:#{hk}"
hk.call self
end
@finished=true
end

end #class

end #module


