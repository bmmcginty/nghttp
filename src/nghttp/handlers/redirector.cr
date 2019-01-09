# during response chain, this must be handled after cookiejar (so responseReader, cacher, cookieJar, redirector)
# otherwise cookies don't get set before redirected request is generated
module NGHTTP
  class TooManyRedirectionsError < NGHTTP::HTTPError
  end

  class Redirector
    include Handler
    @cache = Hash(String, Tuple(Time, String)).new
    @already_handled = "redirector_already_handled"
    @after_me = ["cookiejar"]

    def cached_redirect?(url : String)
      if v = cache[url]?
        expires, dest = v[0], v[1]
        if expires > Time.now
          return dest
        else # if not expired
          cache.delete url
        end # if expired
      end   # if in cache at all
      nil
    end

    def cache
      @cache
    end

    def initialize
    end

    def call(env)
      unless env.request?
        handle_response env
      end
      unless env.int_config[@already_handled]?
        call_next env
      end
    end

    def is_redirect?(env)
      return false if env.request.method == "HEAD"
      case env.response.status_code
      when 301, 302, 307
        true
      else
        false
      end
    end

    def handle_response(env)
      if env.config["allow_redirects"]? == false
        return
      end
      if is_redirect? env
        redirect_count = env.int_config["redirect_count"] = (env.int_config.fetch("redirect_count", 0).as(Int32))
        maximum_redirects = env.config.fetch("maximum_redirects", 5).as(Int32)
        env.response.body_io.skip_to_end
        env.response.close
        respuri = env.response.headers["location"]
        nurl = URI.parse(respuri).normalize(env.request.uri).to_s
        cache[env.request.url] = {Time.now + 5.minutes, nurl}
        if redirect_count + 1 > maximum_redirects
          original_url = env.int_config.fetch("original_url") { |key| env.request.uri.to_s }
          raise TooManyRedirectionsError.new env, "Too many redirects (#{redirect_count}) for #{original_url}"
        end
        original_url = env.int_config.fetch("original_url", env.request.uri.to_s)
        newreq = env.session.request method: "GET", url: nurl, params: nil, body: nil, headers: env.request.custom_headers, config: env.config, extra: {internal_redirect_count: redirect_count + 1, internal_original_url: original_url}
        newresp = env.session.run_env newreq
        newenv = newresp.env
        env.request = newenv.request
        env.response = newenv.response
        env.connection = newenv.connection if newenv.connection?
        env.state = newenv.state
        env.int_config[@already_handled] = true
      end
    end
  end
end
