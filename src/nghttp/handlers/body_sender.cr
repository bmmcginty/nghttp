module NGHTTP
  class BodySender
    include Handler
    @before_me = ["BodyPreparer"]

    def initialize
    end

    def call(env)
      if env.request?
        handle_request env
      end
      call_next env
    end

    def handle_request(env)
      # should only handle headers?
      env.connection.handle_request env
      return if env.int_config["from_cache"]? == true
      send_body env
a=Time.monotonic
      env.connection.socket.flush
b=Time.monotonic
#puts "#{(b-a).total_seconds} flush"
    end

    def send_body(env)
      if env.request.method.match /GET|PUT|POST|DELETE/i
        if bio = env.request.body_io?
          IO.copy(bio, env.connection.socket)
        elsif files = env.config["files"]?
          HTTP::FormData.build io: env.connection.socket, boundary: env.int_config["formdata_boundary"].as(String) do |builder|
            if files.is_a?(Hash)
              files.each do |name, f|
                handle_field builder, name, f
              end                    # each
elsif files.is_a?(Array(Int32))
raise "invalid files hash"
            elsif files.is_a?(Array) # array of tuples
              files.each do |f|
                handle_field builder, f[0], f[1]
              end # each
            end   # if hash
          end     # builder
        end       # if files
      end         # if match
    end           # def

    def handle_field(builder, field_name, field)
      if field.is_a?(String)
        builder.field field_name.as(String), field
      elsif field.is_a?(IO)
        builder.file field_name.as(String), field.as(IO)
      elsif field.is_a?(Tuple)
        if field.size == 4
          field = field.as(Tuple(String, IO, String, HTTP::Headers))
        elsif field.size == 3
          field = field.as(Tuple(String, IO, String))
        else
          field = field.as(Tuple(String, IO))
        end
        filename = field[0]?
        filename = filename ? filename.as(String) : field_name
        io = field[1]
        io = io.is_a?(Slice) ? IO::Memory.new(io) : io
        ctype = field[2]?
        headers = field[3]?
        headers = headers ? headers : HTTP::Headers.new
        if ctype
          headers["Content-Type"] = ctype.as(String)
        end
        md = HTTP::FormData::FileMetadata.new filename: filename.as(String)
        builder.file field_name.as(String), io, md, headers.as(HTTP::Headers)
      else
        raise Exception.new("invalid type for files")
      end # if
    end   # def

  end # class
end   # module
