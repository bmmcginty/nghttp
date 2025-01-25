abstract class NGHTTP::Cacher
  abstract def get_key(env : NGHTTP::HTTPEnv)
  abstract def have_key?(env : HTTP::Environment)
  abstract def get_cache(env : NGHTTP::HTTPEnv)
  abstract def put_cache(env : NGHTTP::HTTPEnv)
end

class NGHTTP::FSCache < NGHTTP::Cacher
  @root : String
  @hd = OpenSSL::Digest.new("md5")

  def initialize(path = "cache/")
    @root = path
  end

  def get_key(env : NGHTTP::HTTPEnv)
    req = env.request
    get_key(req.method, req.url, env.config.cache_key?, req.headers, req.body_io?)
  end

  def get_key(method, url, cache_key, headers, body)
    bad = /[^a-zA-Z0-9\/\._()-]+/
    path = url.sub(':', "").gsub(bad, '_').gsub(/(^_+|_+$)/, "").gsub(/\/\/+/, "/")
    parts = path.split("/")
    parts.map! do |part|
      if part.size > 200
        right = part[0, 200].rindex "_"
        right = right ? right : 200
        tmp = part[right..-1]
        @hd.reset
        @hd.update(tmp)
        tmp = @hd.final.hexstring
        part = part[0, right - 1] + "_#{tmp}"
      end
      part
    end
    path = parts.join "/"
    if path.ends_with?("/")
      path += "cache.noname"
    end
    @hd.reset
    @hd.update(path)
    t = @hd.final.hexstring[0..1]
    rev_domain = parts[1].split(".").reverse.join(".")
    t = "#{@root}/#{rev_domain}/#{t}/#{path}.#{method}"
    if cache_key
      t = "#{t}.#{cache_key}"
    end
    t
  end

  def put_cache(env)
    key = get_key(env)
    Dir.mkdir_p File.dirname key
    fh = File.open(key + ".temp", "wb")
    resp = env.response
    rio = resp.body_io
    fh << "HTTP/#{resp.http_version} #{resp.status_code}"
    fh << " #{resp.status_message}" if resp.status_message
    fh << "\r\n"
    resp.headers.each do |k, vl|
      vl.each do |v|
        fh << "#{k}: #{v}\r\n"
      end
    end
    fh << "\r\n"
    rio.on_read do |slice, size|
      fh.write slice[0, size]
      fh.flush
    end
    rio.on_close do
      finish_put env, fh
    end
  end

  def finish_put(env, fh)
    name = fh.path
    fh.close
    if env.int_config.discard_cache? == true
      File.delete name
    else
      File.rename name, name[0..name.rindex(".temp").not_nil! - 1]
    end
  end

  def have_key?(env)
    File.exists?(get_key(env))
  end

  def get_cache(env)
    File.open(get_key(env), "rb")
  end
end # class

class NGHTTP::Cache
  include Handler
  @cacher : Cacher

  # @transport : Transport

  def cacher
    @cacher
  end

  def initialize(cacher = FSCache)
    @cacher = cacher.new
  end

  def call(env)
    if env.request?
      handle_request env
    else
      env.response?
      handle_response env
    end
    call_next env
  end

  def handle_request(env)
    # if we don't provide cached results by default, and the request doesn't request it, don't return a cached result
    # if caching is disabled, return
    if env.config.cache? != true
      return
    end
    # after this point, caching has been requested.
    exp = env.config.cache_expires?
    exp = exp ? exp.as(Time::Span) : nil
    cached = cacher.have_key? env
    # if we have a list of permitted cacheable statuses,
    # and this status code is not included,
    # then don't cache; just return
    okcodes = env.config.cache_statuses?
    if cached && okcodes
      tfh = File.open(cacher.get_key(env), "rb")
      sc = tfh.gets.try(&.split(" ")[1]?.try(&.to_i?))
      tfh.close
      if !(sc && okcodes.not_nil!.as(Array(Int32)).includes?(sc.not_nil!))
        return
      end
    end # not cached or okcodes not set
    # if url not in cache
    cacheStillAlive = if !cached
                        false
                        # if no expiration
                      elsif !exp
                        true
                        # cache entry is newer than expiration
                      elsif File.stat(cacher.get_key(env)).mtime > (Time.utc - exp)
                        true
                        # need to recache because of expiration
                      else
                        false
                      end
    # must [re]save to cache
    unless (cached && cacheStillAlive)
      env.int_config.to_cache = true
      return
    end
    # we'll be reading from a non-expired and existing cache
    env.int_config.from_cache = true
    env.int_config.transport = CacheTransport.new cacher: cacher
  end # def

  def handle_response(env)
    if env.int_config.to_cache? != true
      return
    end
    okcodes = env.config.cache_statuses?
    if okcodes && !(okcodes.not_nil!.as(Array(Int32)).includes?(env.response.status_code))
      return
    end
    cacher.put_cache env
  end # def

end # class
