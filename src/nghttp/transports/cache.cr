class NGHTTP::CacheTransport < NGHTTP::Transport
  @socket : SocketType? = nil
  getter! socket
  @cacher : NGHTTP::Cacher

  def initialize(@cacher)
  end

  def broken? : Bool
    true
  end

  def closed?
    socket.closed?
  end

  def release
  end

  def connect(env)
    @socket = @cacher.get_cache(env)
  end

  def handle_request(env : HTTPEnv)
    nil
  end

  def handle_response(env : HTTPEnv)
    Utils.http_io_to_response env: env
  end
end # class
