module NGHTTP
class Utils
def self.make_body_string(env)
env.response.body_io.gets_to_end
end

def self.http_io_to_response(env : HTTPEnv, io : IO)
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
#0.upto(times.size-1).step(2).each do |i|
#puts "#{times[i+1]-times[i]}:gets"
#end
end #def

end #class
end #module

