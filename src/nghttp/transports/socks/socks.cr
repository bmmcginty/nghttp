require "../../io"
require "./bytepack"
require "socket"

class String
  def hexstring
    to_slice.hexstring
  end

  def unhex
    sb = String.build(size/2) do |sb|
      bloc = -1
      0.upto(size).step(2) do |idx|
        bloc += 1
        sb << (self[idx].to_u8(16) << 4) + self[idx + 1].to_u8(16)
      end # each
    end   # builder
    sb
  end # def

  def ipv4?
    parts = split(".")
    if parts.size == 4
      good = parts.select { |i| t = i.to_i?; t && 0 <= t && t <= 255 }
      if good.size == 4
        return self
      end
    end
    nil
  end

  def ipv6?
    return nil unless self.match(/^[0-9a-f:]+$/i)
    parts = self.split(":")
    empty_count = 8 - parts.reject(&.empty?).size
    if empty_count
      empty_loc = parts.index("").not_nil!
      parts.delete_at(empty_loc)
      empty_count.times do
        parts.insert(empty_loc, "0000")
      end # fill
    end   # if blanks
    parts.map! do |i|
      i.rjust(4, '0')
    end
    t = parts.join(":")
    if t.size == ((8*4) + 7)
      t
    end
    nil
  end # def

end

class IO
  def reunpack(src, dst, *vars)
    m = IO::Memory.new
    m.pack src, *vars
    m.seek 0
    m.unpack dst
  end
end

module Socks
  abstract class Socks < IO
    @socks : TCPSocket? = nil
    @socks_host : String
    @socks_port : Int32
    @socks_username : String?
    @socks_password : String?
    @socks_anonymous_username : String?
    @remoteaddr = {"", 0}
    @localaddr = {"", 0}
    getter! :socks
    getter :socks_host, :socks_port

def write(io : Bytes) : Nil
socks.write io
end

    delegate read, close, closed?, flush, peek, tty?, rewind, to: socks

    abstract def connect(host : String, port : Int)

    def initialize(host, port, username = nil, password = nil, anonymous_username = "user")
      @socks_host = host
      @socks_port = port
      @socks_username = username
      @socks_password = password
      @socks_anonymous_username = anonymous_username
    end

    def connect_socks
      s = TCPSocket.new @socks_host, @socks_port
      s
    end
  end

  class Socks4 < Socks
    Version = 0x04
    enum Command
      Connect = 0x01
      Bind    = 0x02
    end

    enum Status
      RequestGranted   = 0x5a
      RequestFailed    = 0x5b
      IdentUnavailable = 0x5c
      IdentRejection   = 0x5d
    end

    def connect(host, port)
      @socks = connect_socks
      send_connect host, port
      @localaddr = recv_connect
    end

    def send_connect(host, port)
      ip = if host.ipv4?
             host
           else
             Socket::Addrinfo.tcp(host, port)[0].ip_address.address
           end
      send_connect_ipv4(ip, port)
    end

    def send_connect_ipv4(ip, port)
      bits = ip.split(".").map &.to_i
      ip = socks.reunpack(">4B", ">I", bits[0], bits[1], bits[2], bits[3])[0]
      socks.pack ">2BHIz", Version, Command::Connect, port, ip, @socks_anonymous_username
    end

    def recv_connect
      rsv, status, port, host = socks.unpack(">2BHI")
      status = Status.from_value status.as(UInt8).to_i
      if status != Status::RequestGranted
        raise Exception.new("Error connecting: #{status.to_s}")
      end
      host = socks.reunpack(">I", ">4B", host).join(".")
      {host.as(String), port.as(UInt16).to_i}
    end
  end

  class Socks4a < Socks4
    def connect(host : String, port : Int)
      @socks = connect_socks
      send_connect host, port
      @localaddr = recv_connect
    end

    def send_connect(host, port)
      if host.ipv4?
        send_connect_ipv4(host, port)
      else
        socks.pack ">2BHIzz", Version, Command::Connect, port, 1, "", host
      end
    end
  end

  class Socks5 < Socks
    @authtype : AuthType = AuthType::None
    getter :authtype

    Version = 0x05
    enum AuthType
      None             = 0
      Gssapi           = 1
      UsernamePassword = 2
    end
    enum Command
      Connect      = 1
      Bind         = 2
      UdpAssociate = 3
    end
    enum AddressType
      Ipv4       = 1
      DomainName = 3
      Ipv6       = 4
    end
    enum ConnectStatus
      ConnectionGranted                  = 0
      GeneralFailure                     = 1
      ConnectionNotAllowed               = 2
      NetworkUnreachable                 = 3
      HostUnreachable                    = 4
      ConnectionRefusedByDestinationHost = 5
      TtlExpired                         = 6
      ProtocolError                      = 7
      AddressTypeNotSupported            = 8
    end

    def connect(host : String, port : Int)
      @socks = connect_socks
      send_welcome
      recv_welcome
      handle_auth
      send_connect host, port
      recv_connect
    end

    def handle_auth
    end

    def send_welcome
      auths = {AuthType::None}
      # ,AuthType::UsernamePassword}
      version = 5
      socks.pack "<2B" + ("B"*auths.size), version, auths.size, *auths
    end

    def recv_welcome
      version, authtype = socks.unpack ">BB"
      @authtype = AuthType.from_value authtype.as(UInt8).to_i
    end

    def send_connect(host, port)
      @remoteaddr = {host, port}
      if t = host.ipv4?
        atype = AddressType::Ipv4
        aformat = ">I"
        ip = host.split(".").map &.to_i
        t = socks.reunpack(">4B", ">I", ip[0], ip[1], ip[2], ip[3])
        addr = t[0]
      elsif t = host.ipv6?
        atype = AddressType::Ipv6
        aformat = "16s"
        t = host.ipv6?.not_nil!
        addr = t.gsub(":", "").unhex
      else
        atype = AddressType::DomainName
        aformat = "p"
        addr = host
      end
      a = {">4B" + aformat + "H", Version, Command::Connect, 0, atype, addr, port}
      socks.pack *a
    end

    def recv_connect
      version, status, reserved, atype = socks.unpack "4B"
      status = ConnectStatus.from_value status.as(UInt8).to_i
      unless status.connection_granted?
        raise Exception.new("Error connecting: #{status.to_s}")
      end
      atype = AddressType.from_value atype.as(UInt8).to_i
      host = case atype
             when .ipv4?
               t = socks.unpack(">I")
               bits = socks.reunpack(">I", ">4B", t[0])
               bits.join(".")
             when .ipv6?
               socks.unpack(">16s")[0].as(String).hexstring
             when .domain_name?
               socks.unpack("p")[0].as(String)
             else
               raise Exception.new("invalid atype #{atype.to_s}")
             end
      port = socks.unpack(">H")[0]
      @localaddr = {host, port.as(UInt16).to_i}
    end

    def remote_address
      Socket::IPAddress.new @remoteaddr[0], @remoteaddr[1]
    end

    def local_address
      Socket::IPAddress.new @localaddr[0], @localaddr[1]
    end
  end
end
