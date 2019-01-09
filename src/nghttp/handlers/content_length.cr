module NGHTTP
  class ContentLength
    include Handler

    def initialize
    end

    def call(env : HTTPEnv)
      if env.response?
        if env.request.method == "HEAD"
          env.response.body_io = TransparentIO.new ExactSizeReader.new env.response.body_io, 0_i64
        elsif env.response.headers["Transfer-Encoding"]? != "chunked" && env.response.headers["Content-Length"]?
          length = env.response.headers["content-length"].split(",")[0].to_i64
          env.response.body_io = TransparentIO.new ExactSizeReader.new env.response.body_io, length
        end # if
      end   # if
      call_next env
    end # def

  end # class
end   # module
