module NGHTTP
class HTTPConnecter
include Handler

def initialize
end

def call(env)
t=env.int_config["transport"]?
if t
#sta=Time.now
t.as(Handler).handle_transport env
#stb=Time.now
#puts "#{stb-sta}:cache"
else
handle_transport env
end #if transport override
call_next env
end #def

#given an env:
#.establish/reestablish/acquire a connection (from a cache or otherwise)
#.transmit a request if needed
#.change state from request to response
#.receive data from a raw connection
#.set headers/protocol information
#.set body_io
def handle_transport(env)
st=Time.now
#sta=Time.now
connection=env.session.connections.get env.request.uri
#stb=Time.now
#puts "#{stb-sta}:conn_get"
env.connection=connection
#sta=Time.now
request_to_connection env
#stb=Time.now
#puts "#{stb-sta}:request_to_connection"
env.state=HTTPEnv::State::Response
#puts "#{connection},#{connection.socket?}"
#sta=Time.now
Utils.http_io_to_response env,connection.socket
#stb=Time.now
#puts "#{stb-sta}:io_to_response"
#puts "2:#{connection},#{connection.socket?}"
env.response.body_io=TransparentIO.new connection.socket, false
end

private def request_to_connection(env)
c=env.connection.socket
#t=c
c=TransparentIO.new c
c.on_write do |data|
#STDOUT.write data
end
req=env.request
q=env.request.uri.query
#m=IO::Memory.new
qs = if q == ""
""
elsif q == nil
""
else
"?#{q}"
end
#puts "sync:#{c.sync?}"
c << "#{req.method.upcase} #{req.uri.path}#{qs} HTTP/#{req.http_version}\r\n"
req.headers.add "Content-Length","0"
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

end #class
end #module

