class NGHTTP::Wait
  include Handler

  def initialize
  end

  def call(env)
    if env.request?
      handle_request env
    end
    call_next env
  end

  def handle_request(env)
    wait = env.config.wait?
    if !wait
      return
    end
    # if caching is disabled, or if we are writing this request to cache, then sleep as required
    if (
         env.config.cache? != true ||
         env.int_config.to_cache? == true
       )
      sleep wait.not_nil!
    end # if
  end   # def

end # class
