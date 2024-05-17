class NGHTTP::IntConfig < NGHTTP::Config
  # request is being fetched from the network and written to the cache
  hk to_cache : Bool
  # request will be read from teh cache
  hk from_cache : Bool
  # set by the ConnectionManager,
  # or by a handler designed to provide a custom response
  hk transport : Transport
  # If a request generates an error,
  # set this flag. We might not have a full or accurate response to cache,
  # and we'd rather discard and refetch.
  hk discard_cache : Bool
  # The hostname of the destination web server.
  hk origin : String
  # The port of the destination web server.
  hk port : Int32
  # Set by a handler.
  # used instead of env.config.proxy because we use direct:/// as a url when env.config.proxy isn't set.
  hk proxy : String
  # Is this request generated from a redirect?
  hk redirect : Bool
  # The methodused for the redirect.
  # Only HTTP 307 is designed to possibly (re)-use the post method.
  hk redirect_method : String
  # The new url.
  hk redirect_url : String
  # The number of redirections we have seen thus far.
  hk redirect_count : Int32
end
