require "../errors"

class NGHTTP::Config
hk max_redirects : Int32
end

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
resp=env.response
method="GET"
sc=resp.status_code
if sc==307
method=env.request.method
new_body=nil
if env.request.body_io?
new_body=env.request.body_io
if new_body.is_a?(IO)
new_body.seek 0
end
end
end
        respurl = env.response.headers["location"]
        respuri=URI.parse(respurl)
        orig_uri=env.request.uri
nurl = orig_uri.resolve(respuri).to_s
env.int_config["redirect"]=true
env.int_config["redirect_method"]=method
env.int_config["redirect_url"]=nurl
env.int_config["redirect_count"]=env.int_config.fetch("redirect_count",0).as(Int32)+1
end

def handle_request(env)
if env.int_config["redirect"]? == true
env.int_config["redirect"]=false
env.request.method=env.int_config["redirect_method"].as(String)
new_url=URI.parse env.int_config["redirect_url"].as(String)
env.request.uri=new_url
# TODO: remove this logic from Session class or move into another handler
env.request.set_host_header
end # if
end

  def handle_response(env)
env.int_config["redirect"]=false
if is_redirect(env)
seen=env.int_config.fetch("redirect_count",0).as(Int32)
seen+=1
allowed=env.config["max_redirects"].as(Int32)
puts "seen #{seen}, allowed #{allowed}, #{env.request.uri}"
if seen > allowed
raise TooManyRedirectsError.new
end
setup_redirect env
raise RedirectError.new
end
end # def

end # class