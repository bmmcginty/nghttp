module NGHTTP
class Connections
#@available = Hash(String,Channel(Connection)).new
@all = Hash(String,Channel(Connection)).new
@connections_per_host = 1

def get(uri : URI, tls = false)
protocol=uri.scheme ? uri.scheme : "http"
host=uri.host.not_nil!
port = if uri.port
tls = tls ? tls : false
uri.port.not_nil!
elsif protocol == "https"
443
else
80
end
key="#{protocol}/#{host}/#{port}"
if ! @all.has_key? key
cph=@connections_per_host
queue=Channel(Connection).new(cph)
@all[key]=queue
cph.times do
@all[key].send Connection.new host,port, tls,queue
end
end
#puts "receiving conn"
conn=@all[key].receive
case conn
when .no_socket?
#puts "no connection"
conn.connect
when .closed?
#puts "closed"
conn.connect
when .broken?
#puts "broken"
conn.close
conn.connect
else
#puts "good conn"
end
#puts "conn:#{conn}"
conn
end #def

end #class
end #module
