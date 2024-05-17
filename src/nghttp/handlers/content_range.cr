class NGHTTP::ContentRange
  include Handler

  def initialize
  end

  def call(env : HTTPEnv)
    if env.request?
      handle_request env
    end
    call_next env
  end # def

  def handle_request(env)
    offset = env.config.offset?
    if offset.is_a?(String)
      env.request.headers["Range"] = "bytes=#{offset}-"
    elsif offset.is_a?(Int)
      env.request.headers["Range"] = "bytes=#{offset.to_s}-"
    elsif offset.is_a?(Range) && offset.end == -1
      env.request.headers["Range"] = "bytes=#{offset.begin}-"
    elsif offset.is_a?(Range) && offset.excludes_end?
      env.request.headers["Range"] = "bytes=#{offset.begin}-#{offset.end - 1}"
    elsif offset.is_a?(Range)
      env.request.headers["Range"] = "bytes=#{offset.begin}-#{offset.end}"
    end # if offset
  end   # def

end # class
