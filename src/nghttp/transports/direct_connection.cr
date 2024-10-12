class NGHTTP::DirectConnection < NGHTTP::Transport
  @rawsocket : TCPSocket? = nil
  @socket : SocketType? = nil
  getter! socket

  def connect(env : HTTPEnv)
    origin = env.int_config.origin.as(String)
    port = env.int_config.port.as(Int32)
    s = TCPSocket.new origin, port, @dns_timeout, @connect_timeout
    s.read_timeout = @read_timeout
    if env.request.uri.scheme == "https"
      @rawsocket = s
        ctx = OpenSSL::SSL::Context::Client.new
if env.config.verify? == false
            ctx.verify_mode = OpenSSL::SSL::VerifyMode::None
end
      s = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: env.request.uri.host.not_nil!, sync_close: true
    end
    @socket = s
  end

  def broken? : Bool
    broken = true
    begin
      socket.wait_readable 0.1.seconds
    rescue e
      broken = false
    end # read?
    broken
  end

  def handle_request(env : HTTPEnv)
    Utils.request_to_http_io env
    if env.request.body_io?
      IO.copy(env.request.body_io, env.connection.socket)
      env.connection.socket.flush
    end
  end

  def handle_response(env : HTTPEnv)
    Utils.http_io_to_response env
  end
end # class
