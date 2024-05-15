class NGHTTP::ContentEncoding
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
      if !env.request.headers["Accept-Encoding"]?
        env.request.headers["Accept-Encoding"] = "gzip,deflate"
      end
    end # def

def handle_response(env)
      if env.request.method != "HEAD"
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
end # if we have a body
end # def

  end # class
