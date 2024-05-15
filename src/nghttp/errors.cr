module NGHTTP
private class RetryableError < Exception
end # class

  private class FatalError < Exception
  end # class

class RedirectError < RetryableError
end

class TooManyRedirectsError < FatalError
end

end
