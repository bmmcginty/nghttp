module NGHTTP
  class HTTP1Protocol < Protocol
    @@default = new

    def self.default
      @@default
    end

    def self.request_to_http_io(env, full_url = false, io = nil)
      default.request_to_http_io(env, full_url, io)
    end

    def self.http_io_to_response(env : HTTPEnv, io = nil)
      default.http_io_to_response(env, io)
    end

    def self.handle_request(env, full_url = false)
      default.handle_request(env, full_url)
    end

    def self.handle_response(env : HTTPEnv)
      default.handle_response(env)
    end

    def name : String
      "http/1.1"
    end

    def uses_host_header? : Bool
      true
    end

    def uses_connection_header? : Bool
      true
    end

    def uses_transfer_encoding? : Bool
      true
    end

    def handle_request(env, full_url = false)
      request_to_http_io env, full_url
      if env.request.body_io?
        IO.copy(env.request.body_io, env.connection.socket)
        env.connection.socket.flush
      end
    end

    def handle_response(env : HTTPEnv)
      http_io_to_response env
    end

    def request_to_http_io(env, full_url = false, io = nil)
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
      t.sync = false if t.is_a?(IO::Buffered)
      c << req_line
      req.headers.each do |k, vl|
        vl.each do |v|
          hv = "#{k}: #{v}\r\n"
          c << hv
        end
      end
      c << "\r\n"
      c.flush
    end

    def http_io_to_response(env : HTTPEnv, io = nil)
      io = io ? io : env.connection.socket
      resp = env.response
      rh = resp.headers
      begin
        rl = io.gets.not_nil!.split(" ", 3)
      rescue e : NilAssertionError
        raise BrokenConnection.new
      end
      resp.http_version = rl[0].split("/", 2)[1]
      resp.status_code = rl[1]
      resp.status_message = rl[2] if rl.size > 2
      while 1
        hl = io.gets.not_nil!
        break if hl == ""
        hk, hv = hl.split(": ", 2)
        rh.add(hk, hv)
      end
      resp.body_io = TransparentIO.new io, close_underlying_io: false
    end
  end
end
