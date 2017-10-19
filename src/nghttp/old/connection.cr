class Scheduler
def self.event_base
@@eb
end
end

module NGHTTP
class Connection
@fb : Fiber? = nil
@broken = false
@keepalive=true
@keepalive_expires=Int64.new(0)
@max_requests = 0
@last_request_start = Int64.new(0)
@available = true
@request_count = 0
@socket : IO?
@rawsocket : IO?
@host : String
@port : Int32
@tls = false
@connect_timeout : Int32|Float64
@read_timeout : Int32|Float64
property socket,keepalive,keepalive_expires,max_requests,available,fb,broken
getter host,port

def initialize(@host,@port,@connect_timeout,@read_timeout,@tls = nil)
end

def acquire(force_reconnect = false)
@available=false
if force_reconnect
reconnect
else
reconnect?
end
@request_count+=1
@last_request_start=Time.now.epoch
self
end

def release
@available=true
end

def reconnect?
return unless should_reconnect?
reconnect
end

def reconnect
#puts "reconnecting #{@request_count}"
if @socket
@socket.not_nil!.close
end
@request_count = 0
@last_request_start=Time.now.epoch
@rawsocket=rs=s=TCPSocket.new
s.sync=true
s.read_timeout=@read_timeout
rs.connect @host,@port,connect_timeout: @connect_timeout
if @tls
ctx=OpenSSL::SSL::Context::Client.new
s=OpenSSL::SSL::Socket::Client.new(io: s, sync_close: true, context: ctx, hostname: @host)
end
@socket=s
end

def should_reconnect?
unless @socket
#puts "rc:no socket"
return true
end
if @keepalive == false
#puts "rc:keepalive false"
return true
end
#if @request_count == 0
#puts "rc:rc==0"
#return true
#end
if @max_requests > 0 && @request_count > @max_requests
#puts "rc:maxrequests"
return true
end
if @keepalive_expires > 0 && (@last_request_start + @keepalive_expires) >= Time.now.epoch
#puts "rc:keepalive_expires"
return true
end
if @keepalive_expires == 0 && Time.now.epoch-@last_request_start > 30
return true
end
if @rawsocket
rs=@rawsocket.not_nil!.as(TCPSocket)
@fb=Fiber.current
e=Scheduler.event_base.new_event(rs.fd,LibEvent2::EventFlags::Read,self) do |s,flags,data|
cls=data.as(Connection)
#puts "flags:#{flags}"
cls.broken = flags.includes?(LibEvent2::EventFlags::Read)
cls.fb.not_nil!.resume
end
e.add (0.1).seconds
#puts "eventing"
Scheduler.reschedule
#puts "evented #{@broken}"
if @broken
@broken=false
return true
end
end #if
false
end #def

end #class

end #module
