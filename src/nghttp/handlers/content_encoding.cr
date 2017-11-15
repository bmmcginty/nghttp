module NGHTTP
class ContentEncoding
include Handler

def initialize
end

def call(env : HTTPEnv)
if env.response?
encoding=env.response.headers["Content-Encoding"]?
if encoding
out_io=env.response.body_io.not_nil!
encoding.split(/, */).reverse.each do |c|
out_io = case encoding
when "gzip"
Gzip::Reader.new out_io
when "deflate"
Zlib::Reader.new out_io
#Flate::Reader.new out_io
when "zip"
Zlib::Reader.new out_io
when "identity"
out_io
else
raise Exception.new "Invalid content-encoding #{encoding}"
end #case
end #each
env.response.body_io=TransparentIO.new out_io
end #encoding
end #response?
call_next env
end #def

end #class
end #module

