require "./handlers/cookie_jar"
require "./config"
require "./int_config"
require "./connection_manager"
require "./http_error"
require "./errors"

class NGHTTP::Session
  @connection_manager : ConnectionManager = ConnectionManager.new
  @headers = HTTP::Headers.new
  @config = Config.new
  @start_handler : Handler? = nil
  @handlers = Array(Handler).new

  getter config, headers, connection_manager
  getter! start_handler

  def cookiejar
    get_handler("cookiejar").as(NGHTTP::Cookiejar)
  end

  def new_config
    Config.new
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

  def initialize
    @headers.add "User-Agent", "Crystal"
    @headers.add "Accept", "*/*"
    @headers.add "Connection", "keep-alive"
    @config.max_redirects = 3
    @config.connections_per_host = 1
    setup_handlers Handlers.default
  end

  def submit(
    method,
    url,
    params,
    body,
    headers,
    config
  )
    ret = nil
    err = nil
    env = new_env config
    env.request = new_request method: method, url: url, params: params, body: body, headers: headers
    tries = env.config.tries?
    tries = tries ? tries.as(Int32) : 3
    while tries >= 0
      tries -= 1
      env.state = HTTPEnv::State::Request
      begin
        env.response = new_response env
        start_handler.call env
        redirect = env.int_config.redirect?
        if !redirect
          ret = yield env.response
        end
        err = nil
        env.response.body_io.skip_to_end
        env.close
        if redirect
          tries += 1
          next
        end
        break
      rescue e
        err = e
        env.int_config.discard_cache = true
        env.close true
        if e.is_a?(FatalError)
          break
        end
      end # rescue
    end   # while
    if err
      raise err
    end
    ret
  end # def

  def new_response(env)
    ret = Response.new
    ret.env = env
    ret
  end

  def new_env(config)
    env = HTTPEnv.new self
    env.config.merge! @config
    if config
      env.config.merge! config
    end
    env
  end

  def new_request(
    method,
    url,
    params,
    body,
    headers
  )
    req = Request.new
    req.method = method
    req.uri = URI.parse url
    req.set_host_header
    req.headers.merge! @headers
    if headers
      req.headers.merge!(headers)
    end
    if params
      enc_p = HTTP::Params.encode params
      p = req.uri.query
      p = p ? p : ""
      p = p.not_nil!
      if p == ""
        p += enc_p
      elsif p.ends_with? "&"
        p += enc_p
      else
        p += "&#{enc_p}"
      end
      req.uri.query = p
    end
    if body
      if body.is_a?(Hash(String, String))
        body = HTTP::Params.encode(hash: body)
      end # if hash
      req.body_io = body.is_a?(String) ? IO::Memory.new(body) : body
    end # if body
    req
  end

  {% for method in %w(head get post put delete options) %}
def {{method.id}}(
url : String = "",
params : Hash(String,String)? = nil,
body : IO|Hash(String,String)|String|Nil = nil,
headers : HTTP::Headers? = nil,
config : Config? = nil,
override_method = {{method.id.stringify}})
submit(
method: override_method,
url: url,
params: params,
body: body,
headers: headers,
config: config) do |resp|
yield resp
end
end #def

{% end %}

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
