require "./src/nghttp"
puts "running"
c=NGHTTP::Session.new wait: nil, cache: false, debug_connect: true
a=Time.now
idx=0_u64
while 1
idx+=1
puts idx if idx%1000 == 0
break if idx>=10000
t=c.get("http://httpbin.apps.bmcginty.us/#{idx}", cache: false)
z=t.body_io.gets_to_end
#"#{t.body_io.gets_to_end.not_nil!.size}"
t.close
end
b=Time.now
puts b-a

