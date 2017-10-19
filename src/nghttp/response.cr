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
@saved_body
end

end
end

