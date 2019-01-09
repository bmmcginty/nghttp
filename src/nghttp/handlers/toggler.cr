module NGHTTP
  class Toggler
    include Handler

    def initialize
    end

    def call(env : HTTPEnv)
      if env.request?
        env.state = HTTPEnv::State::Response
      end
      call_next env
    end
  end
end
