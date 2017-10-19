module NGHTTP
class Cookiejar
include Handler
@cookies = Hash(String,Array(HTTP::Cookie)).new

getter cookies

def initialize
end

def call(env)
if env.request?
set_headers_from_cookiejar headers: env.request.headers, uri: env.request.uri
else
set_cookiejar_from_headers headers: env.response.headers, uri: env.request.uri
end
call_next env
end

def set_headers_from_cookiejar(headers : HTTP::Headers, url : String)
set_headers_from_cookiejar(headers,URI.parse url)
end

def set_headers_from_cookiejar(headers : HTTP::Headers, uri : URI)
uh=".#{uri.host}"
t=[] of HTTP::Cookie
cookies.each do |k,v|
v.each do |c|
#puts "checking secure"
next if c.secure && uri.scheme != "https"
#puts "checking nil domain"
next if c.domain==nil && c.from_host != uri.host
if c.domain && ! c.domain.not_nil!.starts_with?(".")
cd=".#{c.domain}"
elsif c.domain
cd=c.domain
else
cd=nil
end
#uri domain can be longer than cookie domain because cookies propegate downward
#if cookie has provided a domain but uri hostname isn't equal to or child of cookie domain
#puts "cd:#{cd}, uh:#{uh}"
next if cd && ! uh.ends_with?(cd)
#puts "checking path"
next if uri.path && ! uri.path.not_nil!.starts_with?(c.path)
#puts "appending"
t << c
end
end
return unless t.size > 0
ch=headers["Cookie"]?
ch="" unless ch
t.each_with_index do |i,idx|
ch+="#{i.name}=#{i.value}"
ch+="; " if idx < t.size-1
end
headers["Cookie"]=ch
end

def set_cookiejar_from_headers(headers : HTTP::Headers, url : String)
set_cookiejar_from_headers headers,URI.parse url
end

def set_cookiejar_from_headers(headers : HTTP::Headers, uri : URI)
scs=headers.get?("Set-Cookie")
return unless scs
scs.each do |sc|
c=HTTP::Cookie::Parser.parse_set_cookie(sc).not_nil!
if c.domain==nil
c.from_host=uri.host
end
t=find_cookie c
if t && c.expired?
delete_cookie t
elsif t
t.value=c.value
else
unless cookies[c.name]?
cookies[c.name]=Array(HTTP::Cookie).new
end
cookies[c.name] << c
end #if
end #each
end #def

def delete_cookie(c)
h=cookies[c.name]?
return unless h
h.delete c
end

def find_cookie(target)
l=cookies[target.name]?
return nil unless l
l.each do |i|
next if i.domain != target.domain
next if i.path != target.path
next if i.from_host != target.from_host
break i
end
end

end #class

end #module


