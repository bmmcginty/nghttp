class NGHTTP::Cookiejar
  include Handler

  alias Cookie = HTTP::Cookie
  @cookies = Hash(String, Array(Cookie)).new
  @custom_cookies = Hash(String, Array(Cookie)).new
  @disabled = false

  getter cookies, custom_cookies
  property :disabled

  def initialize
  end

  def call(env)
    if @disabled
      return
    end
    if env.request?
      handle_request env
    end
    if env.response?
      handle_response env
    end
    call_next env
  end

  def handle_request(env)
    set_headers_from_cookiejar headers: env.request.headers, uri: env.request.uri
  end

  def handle_response(env)
    set_cookiejar_from_headers headers: env.response.headers, uri: env.request.uri
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "disabled" do
        disabled.to_json json
      end
      json.field "custom_cookies" do
        custom_cookies.to_json json
      end
      json.field "cookies" do
        cookies.to_json json
      end
    end # object
  end   # def

  def load_json(parser : JSON::PullParser)
    parser.read_object do |key|
      case key
      when "cookies"
        @cookies = Hash(String, Array(Cookie)).new(parser)
      when "custom_cookies"
        @custom_cookies = Hash(String, Array(Cookie)).new(parser)
      when "disabled"
        @disabled = parser.read_bool
      else
        raise "invalid field #{key}"
      end # each object
    end   # case
  end     # def

  def clear
    @cookies.clear
    @custom_cookies.clear
  end

  def []=(name, value)
    find = custom_cookies[name]?
    if find && find.size > 0
      find[0].value = value
    else
      c = Cookie.new name: name, value: value
      custom_cookies[name] = [c]
    end
  end

  def [](name)
    if t = @custom_cookies[name]?
      t[0].value
    else
      @cookies[name][0].value
    end
  end

  def cookieline
    a = [] of String
    [custom_cookies, cookies].each do |jar|
      jar.each do |k, vl|
        vl.each do |v|
          a << "#{k}=#{v.value}"
        end # v
      end   # k,vl
    end     # jar
    a.join("; ")
  end # def

  def set_headers_from_cookiejar(headers : HTTP::Headers, url : String)
    set_headers_from_cookiejar(headers, URI.parse url)
  end

  def set_headers_from_cookiejar(headers : HTTP::Headers, uri : URI)
    uh = ".#{uri.host}"
    t = [] of Cookie
    cookies.each do |k, v|
      v.each do |c|
        next if c.secure && uri.scheme != "https"
        next if c.domain == nil && c.from_host != uri.host
        if c.domain && !c.domain.not_nil!.starts_with?(".")
          cd = ".#{c.domain}"
        elsif c.domain
          cd = c.domain
        else
          cd = nil
        end
        # uri domain can be longer than cookie domain because cookies propegate downward
        # if cookie has provided a domain but uri hostname isn't equal to or child of cookie domain
        next if cd && !uh.ends_with?(cd)
        # todo: check c.path
        next if uri.path && !uri.path.not_nil!.starts_with?(c.path.not_nil!)
        t << c
      end
    end
    custom_cookies.each do |k, vl|
      vl.each do |i|
        t << i
      end
    end
    return unless t.size > 0
    ch = headers["Cookie"]?
    ch = "" unless ch
    t.each_with_index do |i, idx|
      ch += "#{i.name}=#{i.value}"
      ch += "; " if idx < t.size - 1
    end
    headers["Cookie"] = ch
  end

  def set_cookiejar_from_headers(headers : HTTP::Headers, url : String)
    set_cookiejar_from_headers headers, URI.parse url
  end

  def set_cookiejar_from_headers(headers : HTTP::Headers, uri : URI)
    scs = headers.get?("Set-Cookie")
    return unless scs
    scs.each do |sc|
      set_cookiejar_from_set_cookie(sc, uri)
    end # each set-cookie header
  end   # def

  def set_cookiejar_from_set_cookie(sc, uri)
    c = Cookie::Parser.parse_set_cookie(sc)
    unless c
      return
    end
    if custom_cookies.has_key?(c.name)
      custom_cookies.delete c.name
    end
    if c.domain == nil
      c.from_host = uri.host
    end
    t = find_cookie c
    if t && c.expired?
      delete_cookie t
    elsif c.expired?
      # do nothing; don't add it.
    elsif t
      t.value = c.value
    else
      unless cookies[c.name]?
        cookies[c.name] = Array(Cookie).new
      end
      cookies[c.name] << c
    end # if
  end   # def

  def delete_cookie(c)
    h = cookies[c.name]?
    return unless h
    h.delete c
  end

  def find_cookie(target)
    l = cookies[target.name]?
    return nil unless l
    l.each do |i|
      next if i.domain != target.domain
      next if i.path != target.path
      next if i.from_host != target.from_host
      break i
    end
  end
end # class
