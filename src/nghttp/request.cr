module NGHTTP
  class Request
    @headers = HTTP::Headers.new
    @custom_headers : HTTP::Headers? = nil
    @uri = URI.parse ""
    @params = Hash(String,String).new
    @method = "GET"
    @http_version = "1.1"
    @body_io : IO? = nil

    property :body_io, :method, :uri, :headers, :http_version, :custom_headers, :params
    getter! :body_io

    def method=(s : String)
      @method = s.upcase
    end

    def body_io?
      @body_io
    end

    def url
      @uri.to_s
    end
  end
end
