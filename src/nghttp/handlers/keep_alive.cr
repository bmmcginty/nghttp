module NGHTTP
  class KeepAlive
    include Handler

    def initialize
    end

    def call(env : HTTPEnv)
      if env.response?
        handle_response env
      end
      call_next env
    end

    def handle_response(env)
      if env.response.headers["Connection"]? == "close"
        env.connection.require_reconnect = true
      else
        env.connection.require_reconnect = false
      end # if
    end   # def

  end # class
end   # module
