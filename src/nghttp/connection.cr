module NGHTTP
module SelectIO
def self.select(read_ios, write_ios = nil, error_ios = nil)
self.select(read_ios, write_ios, error_ios, nil).not_nil!
end

# Returns an array of all given IOs that are
# * ready to read if they appeared in *read_ios*
# * ready to write if they appeared in *write_ios*
# * have an error condition if they appeared in *error_ios*
#
# If the optional *timeout_sec* is given, `nil` is returned if no
# `IO` was ready after the specified amount of seconds passed. Fractions
# are supported.
#
# If timeout_sec is `nil`, this method blocks until an `IO` is ready.
def self.select(read_ios, write_ios, error_ios, timeout_sec : LibC::TimeT | Int | Float?)
nfds = 0
read_ios.try &.each do |io|
nfds = io.fd if io.fd > nfds
end
write_ios.try &.each do |io|
nfds = io.fd if io.fd > nfds
end
error_ios.try &.each do |io|
nfds = io.fd if io.fd > nfds
end
nfds += 1

read_fdset = FDSet.from_ios(read_ios)
write_fdset = FDSet.from_ios(write_ios)
error_fdset = FDSet.from_ios(error_ios)

if timeout_sec
sec = LibC::TimeT.new(timeout_sec)

if timeout_sec.is_a? Float
usec = (timeout_sec - sec) * 10e6
else
usec = 0
end

timeout = LibC::Timeval.new
timeout.tv_sec = sec
timeout.tv_usec = LibC::SusecondsT.new(usec)
timeout_ptr = pointerof(timeout)
else
timeout_ptr = Pointer(LibC::Timeval).null
end

readfds_ptr = pointerof(read_fdset).as(LibC::FdSet*)
writefds_ptr = pointerof(write_fdset).as(LibC::FdSet*)
errorfds_ptr = pointerof(error_fdset).as(LibC::FdSet*)

ret = LibC.select(nfds, readfds_ptr, writefds_ptr, errorfds_ptr, timeout_ptr)
case ret
when 0 # Timeout
nil
when -1
raise Errno.new("Error waiting with select()")
else
ios = [] of IO
read_ios.try &.each do |io|
ios << io if read_fdset.set?(io)
end
write_ios.try &.each do |io|
ios << io if write_fdset.set?(io)
end
error_ios.try &.each do |io|
ios << io if error_fdset.set?(io)
end
ios
end
end

struct FDSet
NFDBITS = sizeof(Int32) * 8

def self.from_ios(ios)
fdset = new
ios.try &.each do |io|
fdset.set io
end
fdset
end

def initialize
@fdset = StaticArray(Int32, 32).new(0)
end

def set(io)
@fdset[io.fd / NFDBITS] |= 1 << (io.fd % NFDBITS)
end

def set?(io)
@fdset[io.fd / NFDBITS] & 1 << (io.fd % NFDBITS) != 0
end

def to_unsafe
pointerof(@fdset).as(Void*)
end
end
end


class Connection
alias SocketType=TCPSocket|OpenSSL::SSL::Socket::Client|Nil
@host = ""
@port = 0
@tls : Bool|OpenSSL::SSL::Context::Client = false
@queue : Channel(Connection)
@rawsocket : TCPSocket? = nil
@socket : SocketType|Nil = nil
@fd = -1
@broken = false
@fb : Fiber|Nil = nil
@dns_timeout = 2
@connect_timeout = 5
@read_timeout = 30
@ev : Event::Event? = nil

getter! :socket
property :broken,:fb

def initialize(@host,@port,@tls, @queue)
end #def

def connect
#STDOUT.puts "connect"
#STDOUT.flush
s=TCPSocket.new @host, @port, @dns_timeout, @connect_timeout
@rawsocket=s
s.sync=false
@fd=s.fd
s.read_timeout = @read_timeout
tls=@tls
if tls != false
tls = tls == true ? OpenSSL::SSL::Context::Client.new : tls.as(OpenSSL::SSL::Context::Client)
s=OpenSSL::SSL::Socket::Client.new s, context: tls, hostname: @host, sync_close: true
end
@socket=s
end

def release
@queue.send self
sleep 0
end

def socket?
@socket
end

def no_socket?
@socket == nil
end

def closed?
socket.closed?
end

def broken?
t=SelectIO.select({@rawsocket.not_nil!},nil,nil,0.000001)
#if there's a timeout, we aren't broken
if t == nil
return false
end
#puts "broken"
true
end

def xbroken?
rs=@socket
@broken=false
unless @ev
@fb=Fiber.current
@ev=Scheduler.event_base.new_event(@fd,LibEvent2::EventFlags::Read,self) do |s,flags,data|
cls=data.as(::NGHTTP::Connection)
#STDOUT.puts flags
#if we have a timeout, the connection is still good
cls.broken = flags.includes?(LibEvent2::EventFlags::Timeout) ? false : true
cls.fb.not_nil!.resume
end
end
@ev.not_nil!.add (0.0001).seconds
#puts "reschedule"
@rawsocket.not_nil!.blocking=false
Scheduler.reschedule
@rawsocket.not_nil!.blocking=true
#puts "resumed"
if @broken
@broken=false
return true
end #if
false
end

def close
socket.close
end

#delegate :closed?, :read, :write, :flush, :close, :gets, :puts, to: socket

def <<(*a)
a.each do |i|
socket << i
end
end

end #class
end #module

