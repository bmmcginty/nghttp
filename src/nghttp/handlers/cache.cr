module Cache
  abstract def get_key(env : NGHTTP::HTTPEnv)
  abstract def have_key?(key : String)
  abstract def get_cache(env : NGHTTP::HTTPEnv)
  abstract def put_cache(env : NGHTTP::HTTPEnv)
end

class FSCache
  include Cache
  @root : String
  @hd = OpenSSL::Digest.new("md5")

  def initialize(path = "cache/")
    @root = path
  end

  def get_key(env : NGHTTP::HTTPEnv)
    req = env.request
    get_key(req.method, req.url, env.config["cachekey"]?, req.headers, req.body_io?)
  end

  def get_key(method, url, cachekey, headers, body)
    bad = /[^a-zA-Z0-9\/\._()-]+/
    path = url.sub(':', "").gsub(bad, '_').gsub(/(^_+|_+$)/, "").gsub(/\/\/+/, "/")
    parts = path.split("/")
    parts.map! do |part|
      if part.size > 200
        right = part[0, 200].rindex "_"
        right = right ? right : 200
        tmp = part[right..-1]
        @hd.reset
        tmp = @hd.update(tmp).hexdigest
        part = part[0, right - 1] + "_#{tmp}"
      end
      part
    end
    path = parts.join "/"
    if path.ends_with?("/")
      path += "cache.noname"
    end
    @hd.reset
    t = @hd.update(path).hexdigest[0..1]
    t = "#{@root}/#{t}/#{path}.#{method}"
    if cachekey
      t = "#{t}.#{cachekey}"
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
    fh << "\n"
    resp.headers.each do |k, vl|
      vl.each do |v|
        fh << "#{k}: #{v}\n"
      end
    end
    fh << "\n"
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
    if env.config["no_save_cache"]? == true
      STDOUT.puts "no save cache"
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

module NGHTTP
  class Cache
    include Handler
    @cacher : ::Cache
    # @transport : Transport
    @default_cache : Bool
    @wait : Int32 | Float64

    def cacher
      @cacher
    end

    def initialize(cacher = FSCache, @default_cache = false, @wait = 1, **kw)
      @cacher = cacher.new **kw
      # @transport = CacheTransport.new(cacher)
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
      rwait = env.config.fetch("wait", @wait)
      if rwait.is_a?(Nil)
        rwait = nil
      else
        rwait = rwait.as(String | Int32 | Float64).to_f
      end
      # if caching is disabled, return
      if env.config["cache"]? != true
        sleep rwait.not_nil! if rwait
        return
      end
      # after this point, caching has been requested.
      exp = env.config["cache_expires"]?
      exp = exp ? exp.as(Time::Span) : nil
      cached = cacher.have_key? env
      # if url not in cache
      cacheStillAlive = if !cached
                          false
                          # if no expiration
                        elsif !exp
                          true
                          # cache entry is newer than expiration
                        elsif File.stat(cacher.get_key(env)).mtime > (Time.now - exp)
                          true
                          # need to recache because of expiration
                        else
                          false
                        end
      # must [re]save to cache
      unless (cached && cacheStillAlive)
        env.int_config["to_cache"] = true
        sleep rwait.not_nil! if rwait
        return
      end
      # we'll be reading from a non-expired and existing cache
      env.int_config["from_cache"] = true
      env.int_config["transport"] = CacheTransport.new env: env, cacher: cacher
    end # def

    def handle_response(env)
      return unless env.int_config["to_cache"]? == true
      cacher.put_cache env
    end # def

  end # class
end   # module
