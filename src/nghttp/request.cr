module NGHTTP
class Request
@headers = HTTP::Headers.new
@custom_headers : HTTP::Headers? = nil
@uri = URI.parse ""
@method = "GET"
@http_version="1.1"
@body_io : IO? = nil

property :body_io,:method,:uri,:headers,:http_version,:custom_headers
getter! :body_io

def body_io?
@body_io
end

def url
@uri.to_s
end

end
end

