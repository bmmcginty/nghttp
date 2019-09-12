require "./handlers/cookie_jar"

module NGHTTP
private class FatalError < Exception
end #class

  class Session
    @connections = Connections.new
    @headers = HTTP::Headers.new
    @config = HTTPEnv::ConfigType.new
    @start_handler : Handler? = nil
    @handlers = Array(Handler).new

    getter :config, :headers
    getter! :start_handler, :connections

    def cookiejar
      get_handler("cookiejar").as(NGHTTP::Cookiejar)
    end

    def redirector
      get_handler("redirector").as(NGHTTP::Redirector)
    end

    def get_handler(name)
      name = name.underscore
      seen_start = 0
      h = @start_handler
      while 1
        break unless h
        seen_start += 1 if h == @start_handler
        raise "handler #{name} not found" if seen_start > 1
        return h if h.class.name.split("::")[-1].underscore == name
        h = h.next
      end
    end

    def initialize(**kw)
      init kw
      setup_handlers Handlers.default
    end

    def initialize(**kw)
      init kw
      h = yield Handlers.default
      setup_handlers h
    end

    def init(kw)
      @headers.add "User-Agent", "Crystal"
      @headers.add "Accept", "*/*"
      @headers.add "Connection", "keep-alive"
      @config.merge! kw
    end

    def setup_and_run(method, url, params, body, headers, config, extra)
      counter = 0
      #      err = nil
      env = nil
      resp = nil
      tries = nil
      url = if cr = redirector.cached_redirect? url
              cr
            else
              url
            end
      while 1
        break if (tries && counter >= tries.not_nil!)
        begin
          env = request(method: method, url: url, params: params, body: body, headers: headers, config: config, extra: extra)
          tries = env.config.fetch("tries", 1).as(Int32)
          resp = run_env env
          err = nil
          break
rescue e : FatalError
err=e
break
        rescue e
          # puts e.inspect_with_backtrace
          if env
            env.close(true)
          end
          body.rewind if (body && body.is_a?(IO))
          err = e
        end
        counter += 1
      end
      raise err if err
      env.not_nil!.response
    end

    {% for method in %w(head get post put delete options) %}
def {{method.id}}(url : String = "", params : Hash(String,String)? = nil, body : IO|Hash(String,String)|String|Nil = nil, headers : HTTP::Headers? = nil, config : HTTPEnv::ConfigType? = nil, override_method = {{method.stringify}}, **kw)
#url : String = "", params : Hash(String,String)? = nil, body : IO|String|Nil = nil, headers : HTTP::Headers? = nil
resp=setup_and_run method: override_method, url: url, params: params, body: body, headers: headers, config: config, extra: kw
resp
end #def

def {{method.id}}(url : String = "", params : Hash(String,String)? = nil, body : IO|Hash(String,String)|String|Nil = nil, headers : HTTP::Headers? = nil, config : HTTPEnv::ConfigType? = nil, override_method = {{method.id.stringify}}, **kw)
err=nil
ret = nil
resp=setup_and_run method: override_method, url: url, params: params, body: body, headers: headers, config: config, extra: kw
begin
ret = yield resp
begin
unless [201,204].includes?(resp.status_code)
resp.body_io.skip_to_end
end
rescue e
#puts e.inspect_with_backtrace
err=e
end
rescue e #error
#puts e.inspect_with_backtrace
err=e
#ensure
#resp.env.close
end
#puts "err:#{err}"
resp.env.close (err ? true : false)
raise err if err
ret
end #def

{% end %}

    def request(*, method, url, params, body, headers, config, extra)
      env = HTTPEnv.new
      env.session = self
      env.response.env = env
      env.config.merge! @config
      if config
        env.config.merge! config
      end
      extra.each do |k, v|
        ks = k.to_s
        case ks
when "data"
raise FatalError.new("data param depricated; use body")
        when .starts_with?("internal_")
          env.int_config[ks.split("_", 2)[1]] = v
        else
          env.config[ks] = v
        end
      end
      # env.config.merge! kw
      env.request.method = method
      if 1 == 0
        if qidx = url.index("?")
          env.request.uri = URI.parse url[0...qidx]
          env.request.uri.query = HTTP::Params.parse(url[qidx + 1..-1]).to_s
        end
      else
        env.request.uri = URI.parse url
      end
      set_host_header env
      env.request.headers.merge! @headers
      if headers
        env.request.custom_headers = headers
        env.request.headers.merge!(headers)
      end
      if params
        enc_p = HTTP::Params.encode params
        p = env.request.uri.query
        p = p ? p : ""
        p = p.not_nil!
        if p == ""
          p += enc_p
        elsif p.ends_with? "&"
          p += enc_p
        else
          p += "&#{enc_p}"
        end
        env.request.uri.query = p
      end
      if body
        if body.is_a?(Hash(String,String))
body=HTTP::Params.encode(hash: body)
end
        if body.is_a?(String)
          env.request.headers["Content-Length"] = body.bytesize.to_s
        end # body is string?
        env.request.body_io = body.is_a?(String) ? IO::Memory.new(body) : body
      end
      env
    end

    def set_host_header(env)
      hn = if env.request.uri.port == 80 && env.request.uri.scheme == "http"
             "#{env.request.uri.host}"
           elsif env.request.uri.port == 443 && env.request.uri.scheme == "https"
             "#{env.request.uri.host}"
           elsif env.request.uri.port == nil
             "#{env.request.uri.host}"
           else
             "#{env.request.uri.host}:#{env.request.uri.port}"
           end
      env.request.headers["Host"] = hn
    end

    def run_env(env : HTTPEnv)
      env.state = HTTPEnv::State::Request
      begin
        start_handler.call env
      rescue e
        # puts e.inspect_with_backtrace
        begin
          env.close true
        rescue e
          # puts e.inspect_with_backtrace
        end # try to close
        raise e
      end # begin
      env.response
    end

    def setup_handlers(handlers_list)
      other = handlers_list.first
      if other.is_a?(Handler)
        other = other
      else
        other = other.new
      end
      other = other.as(Handler)
      @start_handler = other
      handlers_list[1..-1].each do |this_class|
        if this_class.is_a?(Handler)
          this = this_class
        else
          this = this_class.new
        end
        this = this.as(Handler)
        other.next = this
        this.previous = other
        other = this
      end # each
      start_handler.verify_requirements
    end # def

  end # class
end   # module
