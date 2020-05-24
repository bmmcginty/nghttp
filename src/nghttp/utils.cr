module NGHTTP
class BrokenConnection < Exception
def to_s
"broken_connection"
end
def to_s(io : IO)
io << to_s
end
end

  class Utils
    def self.request_to_http_io(env, full_url = false, io = nil)
      req = env.request
      eurl = if full_url
               req.uri.to_s
             else
               q = req.uri.query
               qs = if q == ""
                      ""
                    elsif q == nil
                      ""
                    else
                      "?#{q}"
                    end
               path = req.uri.path.not_nil!
               "#{path}#{qs}"
             end
      eurl = eurl.gsub(" ", "%20")
      req_line = "#{req.method.upcase} #{eurl} HTTP/#{req.http_version}\r\n"
        c = io ? io : env.connection.socket
        t = c
        while t.is_a?(TransparentIO)
          t = t.io
        end
        t.as(IO::Buffered).sync = false
#        begin
          c << req_line
          req.headers.each do |k, vl|
            vl.each do |v|
              hv = "#{k}: #{v}\r\n"
              c << hv
end #each single header
            end #each header
          c << "\r\n"
          c.flush
#rescue e
#raise BrokenConnection.new
#          end #begin/end
          # if req.body_io?
          # IO.copy req.body_io,c
          # end
          # c.flush
    end   # def

    macro ts
#t=Time.monotonic
end

    macro te(msg)
    end

    def self.http_io_to_response(env : HTTPEnv, io = nil)
      # ts
      io = io ? io : env.connection.socket
      # te "io1"
      # ts
      resp = env.response
      rh = resp.headers
      te "rsetup"
      ts
begin
      rl = io.gets.not_nil!.split(" ", 3)
rescue e : NilAssertionError
raise BrokenConnection.new
end
      te "rl1"
      ts
      resp.http_version = rl[0].split("/", 2)[1]
      te "rver"
      ts
      resp.status_code = rl[1]
      te "rstatuscode"
      ts
      resp.status_message = rl[2] if rl.size > 2
      te "statusmessage"
      ts
      while 1
        hl = io.gets.not_nil!
        break if hl == ""
        hk, hv = hl.split(": ", 2)
        rh.add(hk, hv)
      end # while
      te "rheaders"
      ts
      resp.body_io = TransparentIO.new io, false
      te "rnewio"
    end # def

    def self.make_body_string(env)
      env.response.body_io.gets_to_end
    end
  end # class
end   # module
