class NGHTTP::Request
  @headers = HTTP::Headers.new
  @custom_headers : HTTP::Headers? = nil
  @uri = URI.parse ""
  @params = Hash(String, String).new
  @method = "GET"
  @http_version = "1.1"
  @body_io : IO? = nil

  property uri, headers, http_version
  setter body_io
  getter method

  def body_io
    @body_io.not_nil!
  end

  def body_io?
    @body_io != nil
  end

  def method=(s : String)
    @method = s.upcase
  end

  def url
    @uri.to_s
  end

  def set_host_header
    hn = if @uri.port == 80 && @uri.scheme == "http"
           "#{@uri.host}"
         elsif @uri.port == 443 && @uri.scheme == "https"
           "#{@uri.host}"
         elsif @uri.port == nil
           "#{@uri.host}"
         else
           "#{@uri.host}:#{@uri.port}"
         end
    @headers["Host"] = hn
  end
end
