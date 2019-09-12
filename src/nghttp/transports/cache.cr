module NGHTTP
  class CacheTransport < Transport
    @io : IO

    def initialize(env, cacher)
      @io = cacher.get_cache env
      @proxy_host = ""
      @proxy_port = 0
    end

    def socket=(s)
      @io = s
    end

    def socket?
      @io
    end

    def rawsocket?
      nil
    end

    def release
      @io.close
    end

    def closed?
      @io.closed?
    end

    def broken?
      false
    end

    def connect(env)
    end

    def handle_request(env : HTTPEnv)
      nil
    end

    def handle_response(env : HTTPEnv)
      Utils.http_io_to_response env: env, io: @io
      env.response.body_io.as(TransparentIO).close_underlying_io = true
      # env.response.body_io=TransparentIO.new io
    end
  end
end
