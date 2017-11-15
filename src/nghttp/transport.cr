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


abstract class Transport
@queue : Channel(Transport)? = nil
@tls : OpenSSL::SSL::Context::Client? = nil
@dns_timeout = 2
@connect_timeout : Float64|Int32 = 5
@read_timeout : Float64|Int32 = 30
@proxy_host : String
@proxy_port : Int32
@proxy_username : String?
@proxy_password : String?
@proxy_options : HTTP::Params?

alias SocketType = Socket|OpenSSL::SSL::Socket::Client
abstract def socket? : SocketType?
	abstract def rawsocket? : Socket?
abstract def handle_request(env : HTTPEnv)
abstract def handle_response(env : HTTPEnv)

def socket
socket?.not_nil!
end

def rawsocket
rawsocket?.not_nil!
end

def initialize(queue, host, port,username, password, options)
@queue=queue
@proxy_host = host
@proxy_port = port
@proxy_username=username
@proxy_password=password
@proxy_options = options
end

def read_timeout=(t)
if s=rawsocket?
s.read_timeout=t
end
@read_timeout=t
end

def connect_timeout=(t)
@connect_timeout=t
end

def dns_timeout=(t)
@dns_timeout = t
end

private def queue
@queue.not_nil!
end

def release
STDOUT.puts "release #{self}"
queue.send self
sleep 0
end

def close
socket.close
end

def closed?
socket.closed?
end

def no_socket?
socket? == nil
end

def broken?
select_broken?
end

def select_broken?
rs=rawsocket
t=SelectIO.select({rs},nil,nil,0.000001)
#if there's a ti, we aren't broken
if t == nil
return false
end
#puts "broken"
true
end

end #class

end #module

require "./transports/*"

