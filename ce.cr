require "./src/nghttp"

zero=File.open("/dev/zero","rb")
encoder=NGHTTP::ChunkWriter.new zero
null = File.open("/dev/null","wb")
s=Bytes.new(16384)
start=Time.now
wait=Time.now+5.seconds
total=0_u64
while 1
t=encoder.read s
#t=zero.read s
null.write s
total+=t
now=Time.now
if now > wait
puts "#{(total/(now-start).total_seconds)/1000/1000} mbps, #{total} bytes, #{(now-start).total_seconds}"
wait = now+5.seconds
end
end
