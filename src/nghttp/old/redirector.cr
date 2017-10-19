require "./extension"

module NGHTTP
class Redirector < Extension
def setup(max_redirects = 30)
client.after_response_parse do |t|
#puts "#{t}:#{t.request.tag}"
if t.request.tag=="redirector"
next nil
end
ourl=t.request.url
resp=t
h=[] of Response
redirect_count=0
while 1
#puts "redirector sees:#{resp.status_code}"
break unless resp.is_redirect?
redirect_count+=1
resp.body_io.gets_to_end
if redirect_count > max_redirects
resp.finish
raise Errors::HTTP::TooManyRedirects.new ourl
end
req=resp.request.dup
resp.finish
h << resp
if h.size > 200
while h.size > 100
h.shift
end
end
req.url=URI.normalize(resp.headers["Location"],req.url)
#puts "subrequest #{req.url}"
req.tag="redirector"
resp=req.dispatch
end #while
resp.history = h
#puts "nexting resp, #{resp.request.url}"
next resp
end #hook
end #def

end #class

end #module

