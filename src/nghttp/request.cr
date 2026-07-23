class NGHTTP::Request
  @headers = HTTP::Headers.new
  @custom_headers = HTTP::Headers.new
  @uri = URI.parse ""
  @params = Hash(String, String).new
  @method = "GET"
  @http_version = "1.1"
  @body_io : IO? = nil
  @base_body_io : IO? = nil

  property http_version, uri
  getter! body_io
  getter method, custom_headers, headers

  def body_io=(io : IO?)
    @body_io = io
    @base_body_io = io
  end

  def prepared_body_io=(io : IO?)
    @body_io = io
  end

  def reset
    @headers.clear
    @body_io = @base_body_io
    @body_io.try(&.rewind)
  end

  def method=(s : String)
    @method = s.upcase
  end

  def url
    @uri.to_s
  end
end
