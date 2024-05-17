class NGHTTP::BodyPreparer
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
    if env.request.body_io? && !env.request.headers["Content-Type"]?
      env.request.headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    end # if
  end   # def
end     # class
