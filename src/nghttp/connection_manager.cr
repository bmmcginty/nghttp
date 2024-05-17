class NGHTTP::ConnectionManager
  @all = Hash(String, Channel(Transport)).new
  @connections_per_host = 1

  # return an endpoint, AKA a connected socket or open file
  def get(env : HTTPEnv)
    proxy = URI.parse env.int_config.proxy
    proxy_proto = proxy.scheme.not_nil!
    uri = URI.parse env.request.url
    protocol = uri.scheme.not_nil!
    host = uri.host.not_nil!
    port = if uri.port
             uri.port.not_nil!
           elsif protocol == "https"
             443
           else
             80
           end
    env.int_config.origin = host
    env.int_config.port = port
    # We'll make cph connections per origin, even if that means we are making multiple connections to the same proxy.
    key = "#{host}:#{port}:#{proxy.to_s}"
    if !@all[key]?
      cls = case proxy_proto
            when "direct"
              DirectConnection
            when "http"
              HttpProxy
            when "https"
              HttpsProxy
            when "socks4"
              Socks4Proxy
            when "socks4a"
              Socks4aProxy
            when "socks5"
              Socks5Proxy
            else
              raise Exception.new("Invalid conection protocol #{proxy_proto}")
            end
      create_transport_queue env, key, cls
    end
    conn = @all[key].receive
    connect env, conn
  end

  def create_transport_queue(env, key, cls)
    cph = env.config.connections_per_host
    queue = Channel(Transport).new(cph)
    @all[key] = queue
    cph.times do
      t = cls.new queue
      queue.send t
    end
  end

  def connect(env, conn)
    connect_timeout = env.config.connect_timeout?
    conn.connect_timeout = connect_timeout ? connect_timeout : 2.seconds
    read_timeout = env.config.read_timeout?
    conn.read_timeout = read_timeout ? read_timeout : 30.seconds
    if conn.no_socket?
      conn.connect env
    elsif conn.closed?
      conn.connect env
    elsif conn.require_reconnect?
      conn.close true
      conn.connect env
    else
    end # if
    conn
  end # def

end # class
