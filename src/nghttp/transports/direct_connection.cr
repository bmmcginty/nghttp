lib LibC
  MSG_PEEK     = 0x02
  MSG_DONTWAIT = 0x40
end

class NGHTTP::DirectConnection < NGHTTP::Transport
  @rawsocket : TCPSocket? = nil
  @socket : SocketType? = nil
  getter! socket

  def connect(env : HTTPEnv)
    origin = env.int_config.origin.as(String)
    port = env.int_config.port.as(Int32)
    s = TCPSocket.new origin, port, @dns_timeout, @connect_timeout
    s.read_timeout = @read_timeout
    @rawsocket = s
    if env.request.uri.scheme == "https"
      ctx = OpenSSL::SSL::Context::Client.new
      if env.config.ca_paths?
        env.config.ca_paths.each { |i| ctx.ca_certificates = i }
      end
      if env.config.verify? == false
        ctx.verify_mode = OpenSSL::SSL::VerifyMode::None
      end
      s = OpenSSL::SSL::Socket::Client.new s, context: ctx, hostname: env.request.uri.host.not_nil!, sync_close: true
    end
    @socket = s
  end

  def broken? : Bool
    ret = false
    if @rawsocket
      rv = LibC.recv(@rawsocket.as(TCPSocket).fd, nil, 0, LibC::MSG_PEEK + LibC::MSG_DONTWAIT)
      # if conn is closed or we get an error that isn't eagain then we should close conn
      # we have data
      if rv > 0
        # we don't have data, and nonblocking socket gives egain or ewouldblock
      elsif rv < 0 && (Errno.value.ewouldblock? || Errno.value.eagain?)
        # anything else, 0 data returned or some other error
      else
        ret = true
      end # if rv/errno
      Errno.value = Errno::NONE
    end # if rawsocket
    ret
  end # def

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
