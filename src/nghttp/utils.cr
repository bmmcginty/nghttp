module NGHTTP
class Utils
def self.request_to_http_io(env, full_url = false, io = nil)
c = io ? io : env.connection.socket
req=env.request
eurl = if full_url
env.request.uri.to_s
else
q=env.request.uri.query
qs = if q == ""
""
elsif q == nil
""
else
"?#{q}"
end
"#{req.uri.path}#{qs}"
end
c << "#{req.method.upcase} #{eurl} HTTP/#{req.http_version}\r\n"
req.headers.each do |k,vl|
vl.each do |v|
c << "#{k}: #{v}\r\n"
end
end
c << "\r\n"
if req.body_io?
IO.copy req.body_io,c
end
c.flush
end #def

def self.http_io_to_response(env : HTTPEnv, io = nil)
io = io ? io : env.connection.socket
#puts "io_to_response"
#puts "sync:#{io.sync?}"
resp=env.response
rh=resp.headers
#times=[] of Time
#times << Time.now
rl=io.gets.not_nil!.split(" ",3)
#times << Time.now
resp.http_version=rl[0].split("/",2)[1]
resp.status_code=rl[1]
resp.status_message=rl[2] if rl.size>2
while 1
#times << Time.now
hl = io.gets.not_nil!
#times << Time.now
break if hl == ""
hk, hv = hl.split(": ",2)
rh.add(hk,hv)
end #while
resp.body_io=TransparentIO.new io, false
#0.upto(times.size-1).step(2).each do |i|
#puts "#{times[i+1]-times[i]}:gets"
#end
end #def

def self.make_body_string(env)
env.response.body_io.gets_to_end
end

end #class
end #module

