class NGHTTP::CustomHeaders
  include Handler
  @after_me = ["BodySender"]

  def initialize
  end

  def call(env : HTTPEnv)
    if env.request?
      handle_request env
    end
    call_next env
  end # def

  def handle_request(env)
    if env.request.custom_headers.size > 0
      env.request.headers.merge! env.request.custom_headers
    end # if
  end   # def
end     # class
