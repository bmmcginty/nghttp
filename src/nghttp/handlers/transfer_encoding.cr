module NGHTTP
  class TransferEncoding
    include Handler

    def initialize
    end

    def call(env : HTTPEnv)
      if env.request? && env.request.body_io?
        unless env.request.headers["Content-Length"]?
          env.request.headers["Transfer-Encoding"] = "chunked"
          env.request.body_io = TransparentIO.new ChunkEncoder.new env.request.body_io
        end
      elsif env.response?
        if env.request.method != "HEAD" && (env.response.headers["Transfer-Encoding"]? == "chunked" || (!env.response.headers["Content-Length"]? && env.response.headers["connection"]? != "close"))
          env.response.body_io = TransparentIO.new ChunkDecoder.new env.response.body_io
        end # if
      end   # if
      call_next env
    end # def

  end # class
end   # module
