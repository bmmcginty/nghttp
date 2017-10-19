#must be handled after cookiejar (so responseReader, cacher, cookieJar, redirector)
module NGHTTP
class Redirector
include Handler
@already_handled="redirector_already_handled"

def initialize
end

def call(env)
unless env.request?
handle_response env
end
unless env.int_config[@already_handled]?
call_next env
end
end

def is_redirect?(env)
case env.response.status_code
when 301,302,307
true
else
false
end
end

def handle_response(env)
if is_redirect? env
Utils.make_body_string env
env.response.close
#make absolute url here
nurl=env.response.headers["location"]
redirect_count=env.int_config["redirect_count"]=env.int_config.fetch("redirect_count",-1).as(Int32)+1
max_redirects=env.config.fetch("max_redirects",5).as(Int32)
if redirect_count > max_redirects
original_url=env.int_config["original_url"]
raise Exception.new "Too many redirects (#{redirect_count}) for #{original_url}"
end
env.int_config["original_url"]=env.int_config.fetch("original_url",env.request.url)
tr=env.session.request method: "GET", url: nurl, headers: env.request.custom_headers, internal_redirect_count: redirect_count+1, config: env.config
t=tr.env
env.request=t.request
env.response=t.response
env.connection=t.connection
env.state=t.state
env.int_config[@already_handled]=true
end
end

end
end

