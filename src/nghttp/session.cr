require "./handlers/cookie_jar"
require "./http_error"


module NGHTTP
  private class FatalError < Exception
  end # class

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
      while 1
        break if (tries && counter >= tries.not_nil!)
        begin
          env = request(method: method, url: url, params: params, body: body, headers: headers, config: config, extra: extra)
          tries = env.config.fetch("tries", 1).as(Int32)
          resp = run_env env
          err = nil
          break
        rescue e : FatalError
          err = e
          break
        rescue e
          if env
            env.close(true)
          end
          body.rewind if (body && body.is_a?(IO))
          err = e
          if e.is_a?(BrokenConnection)
            err=Exception.new("broken_connection (#{counter}/#{tries})")
          end
        end
        counter += 1
      end
      raise err if err
      env.not_nil!.response
    end

def is_redirect(resp)
(300..308).includes?(resp.status_code)
end

def redirect_method_url_body(resp)
method="GET"
sc=resp.status_code
if sc==307
method=resp.env.request.method
new_body=nil
if resp.env.request.body_io
new_body=resp.env.request.body_io
if new_body.is_a?(IO)
new_body.seek 0
end
end
end
        respurl = resp.env.response.headers["location"]
        respuri=URI.parse(respurl)
        orig_uri=resp.env.request.uri
nurl = orig_uri.resolve(respuri).to_s
{method,nurl,new_body}
end

    {% for method in %w(head get post put delete options) %}
def x{{method.id}}(url : String = "", params : Hash(String,String)? = nil, body : IO|Hash(String,String)|String|Nil = nil, headers : HTTP::Headers? = nil, config : HTTPEnv::ConfigType? = nil, override_method = {{method.id.stringify}}, **kw)
#url : String = "", params : Hash(String,String)? = nil, body : IO|String|Nil = nil, headers : HTTP::Headers? = nil
resp=setup_and_run method: override_method, url: url, params: params, body: body, headers: headers, config: config, extra: kw
resp
end #def

def {{method.id}}(url : String = "", params : Hash(String,String)? = nil, body : IO|Hash(String,String)|String|Nil = nil, headers : HTTP::Headers? = nil, config : HTTPEnv::ConfigType? = nil, override_method = {{method.id.stringify}}, **kw)
resp=nil
err=nil
ret = nil
redirect_limit=3
redirects=0
while 1
resp=setup_and_run method: override_method, url: url, params: params, body: body, headers: headers, config: config, extra: kw
redirect_limit=resp.env.config.fetch("max_redirects", redirect_limit).as(Int32)
if is_redirect(resp)
redirects+=1
new_method, new_url,new_body=redirect_method_url_body(resp)
resp.body_io.skip_to_end
if redirects>redirect_limit
resp.env.close(true)
raise TooManyRedirectionsError.new(resp.env, "too many redirects #{redirects}/#{redirect_limit}")
else
resp.env.close(false)
end
url=new_url
override_method=new_method
body=new_body
next
end
begin
ret = yield resp
begin
if ! [201,204].includes?(resp.status_code)
resp.body_io.skip_to_end
end
rescue e
err=e
end
rescue e #error
err=e
#ensure
#resp.env.close
end
resp.env.close (err ? true : false)
break
end
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
        env.request.params=params
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
        if body.is_a?(Hash(String, String))
          body = HTTP::Params.encode(hash: body)
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
        begin
          env.close true
        rescue e
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
