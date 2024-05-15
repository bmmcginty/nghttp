class NGHTTP::KeepAlive
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
      rv = env.request.http_version
      rv = rv.to_f
      connheader = env.response.headers["Connection"]?
      connheader = connheader ? connheader : ""
      connheader = connheader.as(String).downcase.split(";")[0]
      if connheader.includes?("close") || rv < 1.1
        env.connection.require_reconnect = true
      else
        env.connection.require_reconnect = false
      end # if
    end   # def

  end # class
