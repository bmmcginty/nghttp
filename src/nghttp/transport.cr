module NGHTTP
  abstract class Transport
    @require_reconnect = false
    @queue : Channel(Transport)? = nil
    @tls : OpenSSL::SSL::Context::Client? = nil
    @dns_timeout = 2
    @connect_timeout : Float64 | Int32 = 5
    @read_timeout : Float64 | Int32 = 30
    @proxy_host : String
    @proxy_port : Int32
    @proxy_username : String?
    @proxy_password : String?
    @proxy_options : HTTP::Params?

    def require_reconnect=(t : Bool)
      @require_reconnect = t
    end

    def require_reconnect?
      @require_reconnect
    end

    alias SocketType = Socket | OpenSSL::SSL::Socket::Client | TransparentIO

    abstract def socket=(s : SocketType?)
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

    def initialize(queue, host, port, username, password, options, tls)
      @queue = queue
      @proxy_host = host
      @proxy_port = port
      @proxy_username = username
      @proxy_password = password
      @proxy_options = options
      @tls = tls
    end

    def read_timeout=(t)
      if s = rawsocket?
        s.read_timeout = t
      end
      @read_timeout = t
    end

    def connect_timeout=(t)
      @connect_timeout = t
    end

    def dns_timeout=(t)
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
      if rawsocket? && !rawsocket.closed?
        begin
          rawsocket.close
        rescue e
          raise e unless ignore_errors
        end # begin/rescue
      end   # if rawsocket
    end     # def

    def closed?
      socket.closed?
    end

    def no_socket?
      socket? == nil
    end

    def broken?
      broken = true
      begin
        rawsocket.wait_readable? 0.1.seconds
      rescue e
        broken = false
      end # read?
      broken
    end
  end # class

end # module

require "./transports/*"
