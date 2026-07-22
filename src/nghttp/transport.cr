abstract class NGHTTP::Transport
  @require_reconnect = false
  @released = true
  @queue : Channel(Transport)? = nil
  @protocol : Protocol = HTTP1Protocol.default
  @dns_timeout = 2.seconds
  @connect_timeout = 5.seconds
  @read_timeout = 30.seconds
  alias SocketType = Socket | OpenSSL::SSL::Socket::Client | TransparentIO
  @socket : SocketType? = nil
  setter socket

  abstract def broken? : Bool
  abstract def handle_request(env : HTTPEnv)
  abstract def handle_response(env : HTTPEnv)

  def require_reconnect=(t : Bool)
    @require_reconnect = t
  end

  def require_reconnect?
    @require_reconnect
  end

  def initialize(@queue)
  end

  setter read_timeout, connect_timeout, dns_timeout
  property protocol
  getter! queue

  def acquire
    @released = false
    self
  end

  def release
    return if @released

    @released = true
    queue.send self
    sleep 0.seconds
  end

  def close(ignore_errors = false)
    begin
      socket.close if socket? && (!socket.closed?)
    rescue e
      raise e unless ignore_errors
    end
  end # def

  def closed?
    socket? && socket.closed?
  end

  def no_socket?
    @socket == nil
  end

  def configure_alpn(ctx : OpenSSL::SSL::Context::Client)
    ctx.alpn_protocol = protocol.alpn_id
  end

  def select_alpn_protocol(socket : OpenSSL::SSL::Socket::Client)
    self.protocol = Protocol.for_alpn(socket.alpn_protocol)
  end
end # class

require "./transports/*"
