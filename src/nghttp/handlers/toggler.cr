  class NGHTTP::Toggler
    include Handler

    def initialize
    end

    def call(env : HTTPEnv)
      if env.request?
handle_request env
      end # if
      call_next env
  end # def

def handle_request(env)
        env.state = HTTPEnv::State::Response
end # def

end # class
