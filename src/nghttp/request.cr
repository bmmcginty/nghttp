class NGHTTP::Request
  @headers = HTTP::Headers.new
  @custom_headers : HTTP::Headers? = nil
  @uri = URI.parse ""
  @params = Hash(String, String).new
  @method = "GET"
  @http_version = "1.1"
  @body_io : IO? = nil

  property headers, http_version, uri
  setter body_io
getter! body_io
  getter method

  def method=(s : String)
    @method = s.upcase
  end

  def url
    @uri.to_s
  end

end
