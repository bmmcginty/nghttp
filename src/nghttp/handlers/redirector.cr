require "../errors"

class NGHTTP::Redirector
  include Handler

  def initialize
  end

  def call(env : HTTPEnv)
    if env.request?
      handle_request env
    end
    if env.response?
      handle_response env
    end
    call_next env
  end

  def is_redirect(env)
    (300..308).includes?(env.response.status_code)
  end

  def setup_redirect(env)
    resp = env.response
    method = "GET"
    sc = resp.status_code
    new_body_io = nil
    if sc == 307
      method = env.request.method
      if env.request.body_io?
        new_body_io = env.request.body_io
      end # if body_io
    end   # if 307
    respurl = env.response.headers["location"]
    respuri = URI.parse(respurl)
    orig_uri = env.request.uri
    nurl = orig_uri.resolve(respuri).to_s
    env.int_config.redirect = true
    env.int_config.redirect_method = method
    env.int_config.redirect_url = nurl
    env.int_config.redirect_body_io = new_body_io
    count = env.int_config.redirect_count?
    count = count ? count : 0
    count += 1
    env.int_config.redirect_count = count
  end

  def handle_request(env)
    if env.int_config.redirect? == true
      env.int_config.redirect = false
      env.request.method = env.int_config.redirect_method.as(String)
      new_url = URI.parse env.int_config.redirect_url.as(String)
      if new_url.path == ""
        new_url.path = "/"
      end
      env.request.uri = new_url
      env.request.body_io = env.int_config.redirect_body_io?
    end # if
  end

  def handle_response(env)
    env.int_config.redirect = false
    if !is_redirect(env)
      return
    end
    seen = env.int_config.redirect_count?
    seen = seen ? seen : 0
    allowed = env.config.max_redirects
    # if this is a redirect, and we've seen max_redirects thus far, we'll be over the limit now
    if seen >= allowed
      raise TooManyRedirectsError.new
    end
    setup_redirect env
  end # def

end # class
