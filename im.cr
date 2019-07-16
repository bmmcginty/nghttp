require "./src/nghttp"
s=NGHTTP::Session.new
s.headers["User-Agent"]="Mozilla/5.0"
ts=Time.now.to_utc-(ARGV[1].to_i.days)
headers=HTTP::Headers.new
headers["If-Modified-Since"]=HTTP.format_time(ts)
puts headers
s.get(ARGV[0],headers: headers) do |resp|
puts resp.status_code,resp.headers
end

