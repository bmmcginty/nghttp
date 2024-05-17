class NGHTTP::ContentLength
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
    if !env.request.body_io?
      return
    end
    sz = if env.request.body_io.is_a?(IO::Memory)
           env.request.body_io.as(IO::Memory).size - env.request.body_io.as(IO::Memory).tell
         elsif env.request.body_io.is_a?(String)
           env.request.body_io.as(String).size
         else
           nil
         end
    if sz && !env.request.headers["Content-Length"]?
      env.request.headers["Content-Length"] = sz.to_s
    end
  end

  def handle_response(env)
    if env.request.method == "HEAD"
      env.response.body_io = TransparentIO.new ExactSizeReader.new env.response.body_io, 0_i64
    elsif env.response.headers["Transfer-Encoding"]? != "chunked" && env.response.headers["Content-Length"]?
      length = env.response.headers["content-length"].split(",")[0].to_i64
      env.response.body_io = TransparentIO.new ExactSizeReader.new env.response.body_io, length
    end # if
  end   # def

end # class
