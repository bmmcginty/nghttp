module NGHTTP
class Response
@http_version = "1.1"
@status_code = 0
@status_message = ""
@headers = HTTP::Headers.new
@body_io : TransparentIO? = nil
@env : HTTPEnv|Nil = nil
@saved_body : String? = nil

property :http_version,:status_code,:status_message,:headers,:body_io,:env

getter! :body_io,:env

def status_code=(v : String)
@status_code=v.to_i
end

def close
@env.not_nil!.close
end

def body
if ! @saved_body
@saved_body = body_io.gets_to_end
end
@saved_body.not_nil!
end

def error?
@status_code>=400
end

def partial?
@status_code==206
end

def offset
range = @headers["Content-Range"]?
if @status_code == 206 && range
units,values=range.split(" ",2)
values=values.split(",")
values=values.each &.split(/\/|-/)
if values.size > 1
return -2
end
return values[0][0].to_i
end
-1
end #def

end #class
end #module

