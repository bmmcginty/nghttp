module NGHTTP
  class MockTransport < Transport
    @io : IO
@socket = File.open("/dev/null","w")
getter! socket

    def initialize(env, mocker)
      @io = mocker.get_mock env
      @proxy_host = ""
      @proxy_port = 0
    end

    def closed?
      @io.closed?
    end

    def broken? : Bool
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
