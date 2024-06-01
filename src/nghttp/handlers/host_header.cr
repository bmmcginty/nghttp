class NGHTTP::HostHeader
  include Handler
  @after_me = ["BodyPreparer"]

  def initialize
  end

  def call(env : HTTPEnv)
    if env.request?
      handle_request env
    end
    call_next env
  end # def

  def handle_request(env)
if ! env.request.headers["Host"]?
env.request.headers["Host"]=host_header(env.request.uri)
end # if
end # def

  private def host_header(uri)
    hn = if uri.port == 80 && uri.scheme == "http"
           "#{uri.host}"
         elsif uri.port == 443 && uri.scheme == "https"
           "#{uri.host}"
         elsif uri.port == nil
           "#{uri.host}"
         else
           "#{uri.host}:#{uri.port}"
         end
hn
end # def

end # class
