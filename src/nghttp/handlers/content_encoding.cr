module NGHTTP
  class ContentEncoding
    include Handler

    def initialize
    end

    def call(env : HTTPEnv)
      if env.request? && !env.request.headers["Accept-Encoding"]?
        env.request.headers["Accept-Encoding"] = "gzip,deflate"
      end
      if env.response? && env.request.method != "HEAD"
        encoding = env.response.headers["Content-Encoding"]?
        if encoding
          out_io = env.response.body_io.not_nil!
          encoding.split(/, */).reverse.each do |c|
            out_io = case encoding
                     when "gzip"
                       Compress::Gzip::Reader.new out_io, true
                     when "deflate"
                       Compress::Zlib::Reader.new out_io, true
                     when "identity"
                       out_io
                     else
                       raise Exception.new "Invalid content-encoding #{encoding}"
                     end # case
          end            # each
          env.response.body_io = TransparentIO.new out_io
        end # encoding
      end   # response?
      call_next env
    end # def

  end # class
end   # module
