module NGHTTP
  class BrokenConnection < Exception
    def to_s
      "broken_connection"
    end

    def to_s(io : IO)
      io << to_s
    end
  end

  class Utils
    def self.request_to_http_io(env, full_url = false, io = nil)
      HTTP1Protocol.request_to_http_io(env, full_url, io)
    end # def

    macro ts
      # t=Time.instant
    end

    macro te(msg)
    end

    def self.http_io_to_response(env : HTTPEnv, io = nil)
      HTTP1Protocol.http_io_to_response(env, io)
    end # def

    def self.make_body_string(env)
      env.response.body_io.gets_to_end
    end
  end # class
end   # module
