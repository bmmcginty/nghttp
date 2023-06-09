module NGHTTP
  class HTTPError < Exception
    @env : HTTPEnv
    @message : String? = nil
getter env

    def initialize(@env, @message)
    end

    def to_s(io : IO)
      io << @message
    end

    def to_s
      m = IO::Memory.new
      to_s m
      m.gets_to_end
    end

    def inspect
      "#{@env.request.uri.to_s}:#{@message}"
    end

  end #class


  class TooManyRedirectionsError < HTTPError
  end

end #module
