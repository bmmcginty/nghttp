class NGHTTP::TransferEncoding
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

def handle_request(env)
if env.request.body_io?
        if ! env.request.headers["Content-Length"]?
          env.request.headers["Transfer-Encoding"] = "chunked"
          env.request.body_io = TransparentIO.new ChunkEncoder.new env.request.body_io
        end # if no content-length
end # if body
end # def

def handle_response(env)
if env.request.method == "HEAD"
return
end
# if we're using chunked encoding explicitly,
# or our connection is keep-alive and we don't have an explicit content-length header
# or our connection isn't marked "close"
if (env.response.headers["Transfer-Encoding"]? == "chunked" ||
(!env.response.headers["Content-Length"]? && env.response.headers["connection"]? != "close"))
          env.response.body_io = TransparentIO.new ChunkDecoder.new env.response.body_io
        end # if
    end # def

  end # class
