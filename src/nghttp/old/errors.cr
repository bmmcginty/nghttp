module NGHTTP::Errors
class Unwriteable < Exception
def initialize(name)
@message="By design, you can't write to #{name}"
end #def
end #class

class Unreadable < Exception
def initialize(name)
@message="By design, you can't read from #{name}"
end #def
end #class

class DanglingTransparentIO < Exception
def initialize
@message="This TransparentIO does not have an IO attached to the other end"
end #def
end #class

end #module

module NGHTTP::Errors::HTTP
class Error < Exception
@url="not given"
@msg="no error description given"

def initialize(@url)
end

def to_s
%(#{@msg} "#{@url}")
end

def to_s(io : IO)
io.write to_s.to_slice
end

end

class TooManyRedirects < Error
@msg="Too many redirects"
end

class InvalidRequestBody < Error
@msg="body provided for invalid method/url"
end

class NoResponse < Error
@msg="no response received from server"
end

class MalformedBodyEncoding < Error
@msg="no content-length or transfer-encoding given"
end

class InvalidContentEncoding < Error
def initialize(encoding,url)
@msg="Invalid encoding #{encoding}"
@url=url
end

end #class

end #module


