class NGHTTP::HTTPConnecter
  include Handler

  def initialize
  end

  # For requests, ensure a connection exists.
  # For responses, parse the response headers from the server.
  def call(env)
    if env.request?
      # we do the actual sending for both the headers and body in BodySender
      ensure_transport env
    elsif env.response?
      env.connection.handle_response env
    end
    call_next env
  end # def

  # Send this request out to be filled.
  # If a proxy has been set via config, parse that proxy url and attach it to this request.
  # We do this evenf or requests with explicitly set transports, in case those transports faile (cache has deleted file).
  # Todo: possibly remove proxy search when transport has been explicitly selected.
  # If a transport has been configured via int_config, use that transport directly.
  # Otherwise, submit this request to the connection manager to get a transport.
  # Send this request to the transport and process the response.
  def ensure_transport(env)
    proxy = env.config.proxy?
    # if no proxies, use SimpleConnection
    proxy = proxy ? proxy : "direct:///"
    env.int_config.proxy = proxy
    env.connection = if env.int_config.transport?
                       env.int_config.transport.connect env
                       env.int_config.transport
                     else
                       env.session.connection_manager.get env
                     end
    setup_socket_debug env
  end

  def setup_socket_debug(env)
    if t = env.config.debug_file?
      dbg = t.as(IO)
      s = env.connection.socket = TransparentIO.new env.connection.socket
      s.on_read do |slice, size|
        dbg << "r:"
        dbg.write slice[0, size]
        dbg.flush
      end
      s.on_write do |slice|
        dbg << "w:"
        dbg.write slice
        dbg.flush
      end
      s.on_close do
        dbg.close
      end
    end # if debug_file
  end   # def
end     # class
