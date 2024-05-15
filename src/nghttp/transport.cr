module NGHTTP
  abstract class Transport
    @require_reconnect = false
    @queue : Channel(Transport)? = nil
    @tls : OpenSSL::SSL::Context::Client? = nil
    @dns_timeout = 2.seconds
    @connect_timeout = 5.seconds
    @read_timeout = 30.seconds
    @proxy_host : String
    @proxy_port : Int32
    @proxy_username : String?
    @proxy_password : String?
    @proxy_options : HTTP::Params?
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

    def initialize(queue, host, port, username, password, options, tls)
      @queue = queue
      @proxy_host = host
      @proxy_port = port
      @proxy_username = username
      @proxy_password = password
      @proxy_options = options
      @tls = tls
    end

    def read_timeout=(t : Time::Span)
      @read_timeout = t
    end

    def connect_timeout=(t : Time::Span)
      @connect_timeout = t
    end

    def dns_timeout=(t : Time::Span)
      @dns_timeout = t
    end

    private def queue
      @queue.not_nil!
    end

    def release
      queue.send self
      sleep 0
    end

    def close(ignore_errors = false)
      begin
        socket.close if socket? && (!socket.closed?)
      rescue e
        raise e unless ignore_errors
      end
    end     # def

    def closed?
      socket.closed?
    end

    def no_socket?
      @socket == nil
    end

  end # class

end # module

require "./transports/*"
