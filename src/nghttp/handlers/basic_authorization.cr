class NGHTTP::BasicAuthorization
  include Handler

  def initialize
  end

  def call(env : HTTPEnv)
    if env.request?
      handle_request env
    end
    call_next env
  end

  def handle_request(env)
    creds = env.config["basic_auth"]?.as(Array(String) | Nil)
    if creds
      env.request.headers["Authorization"] = make_basic_auth_string creds[0], creds[1]
    end
  end

  def make_basic_auth_string(username, password)
    encoded = Base64.strict_encode("#{username}:#{password}")
    "Basic " + encoded
  end
end
