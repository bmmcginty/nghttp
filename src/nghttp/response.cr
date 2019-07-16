module NGHTTP
  class Response
    @http_version = "1.1"
    @status_code = 0
    @status_message = ""
    @headers = HTTP::Headers.new
    @body_io : TransparentIO? = nil
    @env : HTTPEnv | Nil = nil
    @saved_body : String? = nil

    property :http_version, :status_code, :status_message, :headers, :body_io, :env

    def date
      HTTP.parse_time @headers["Date"]
    end

    getter! :body_io, :env

    def status_code=(v : String)
      @status_code = v.to_i
    end

    def close
      @env.not_nil!.close
    end

    def body
      if @saved_body == nil
        @saved_body = body_io.gets_to_end
      end
      @saved_body.not_nil!
    end

    def json
      begin
        txt = body_io.gets_to_end
        t = JSON.parse txt
      rescue e
        raise e
      end
    end

def xml?
t=nil
begin
t=xml
rescue e
t=nil
end
t
end

    def xml(body = nil, encoding = nil)
      body = body ? body : body_io.gets_to_end
      if encoding
        io = IO::Memory.new(body.to_slice)
        io.set_encoding(encoding)
        buffer = Bytes.new(io.bytesize*4)
        bytes_read = io.read_utf8(buffer.to_slice)
        body = String.new buffer.to_slice[0, bytes_read]
      end
      x = XML.parse_html(body)
      x.make_links_absolute(env.request.url)
      x.as(XML::Node)
    end

    def error?
      @status_code >= 400
    end

    def partial?
      @status_code == 206
    end

    def range_size
      v = get_range_values
      (v[1].to_i64 - v[0].to_i64) + 1_i64
    end

    def range_total_size
      get_range_values[-1]?.try(&.to_i64)
    end

    # no more bytes after this range
    def range_last?
      v = get_range_values
      # puts v
      v.size > 2 ? (v[1].to_i64 + 1_i64) == v[2] : false
    end

    private def get_range_values
      range = @headers["Content-Range"]?
      v = if @status_code == 206 && range
            units, values = range.split(" ", 2)
            values = values.split(/\/|-|,/)
            values.not_nil!
          else
            [] of String
          end
      v
    end

    def offset
      get_range_values
      v[0]? ? v[0] : -1
    end # def

    def get_boundary
      HTTP::Multipart.parse_boundary(headers["Content-Type"])
    end

    def multipart?
      get_boundary
    end

    def parts
      HTTP::Multipart.parse body_io, get_boundary.not_nil! do |headers, io|
        yield headers, io
      end
    end
  end # class
end   # module
