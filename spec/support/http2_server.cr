require "../../src/nghttp"
require "http2/server"
require "base64"
require "json"
require "openssl"

class H2FixtureHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    request = context.request
    response = context.response
    response.headers["server"] = "nghttp-spec-h2"

    case request.path
    when "/get"
      response.headers["content-type"] = "application/json"
      response << {
        "method" => request.method,
        "path"   => request.path,
      }.to_json
    when "/headers"
      response.headers["content-type"] = "application/json"
      headers = {} of String => String
      request.headers.each do |key, values|
        headers[key] = values.join(", ")
      end
      response << {"headers" => headers}.to_json
    when "/echo"
      response.headers["content-type"] = request.headers["content-type"]? || "application/octet-stream"
      IO.copy(request.body.not_nil!, response)
    when .starts_with?("/bytes/")
      size = request.path.split("/").last.to_i
      response.headers["content-type"] = "application/octet-stream"
      response << repeated_body(size)
    when .starts_with?("/basic-auth/")
      _empty, _basic_auth, user, password = request.path.split("/", 4)
      expected = "Basic #{Base64.strict_encode("#{user}:#{password}")}"
      if request.headers["authorization"]? == expected
        response.headers["content-type"] = "application/json"
        response << {"user" => user}.to_json
      else
        response.status_code = 401
        response.headers["www-authenticate"] = "Basic"
        response << "unauthorized"
      end
    when .starts_with?("/redirect/")
      count = request.path.split("/").last.to_i
      response.status_code = 302
      response.headers["location"] = count <= 1 ? "/get" : "/redirect/#{count - 1}"
    when "/cookies"
      response.headers["content-type"] = "application/json"
      response << {"cookies" => cookies(request.headers["cookie"]?)}.to_json
    when "/cookies/set"
      params = HTTP::Params.parse(request.query || "")
      params.each do |key, value|
        response.headers.add("set-cookie", "#{key}=#{value}; Path=/")
      end
      response.headers["content-type"] = "application/json"
      response << "{}"
    when "/cookies/delete"
      params = HTTP::Params.parse(request.query || "")
      params.each do |key, _value|
        response.headers.add("set-cookie", "#{key}=; Max-Age=0; Path=/")
      end
      response.headers["content-type"] = "application/json"
      response << "{}"
    else
      response.status_code = 404
      response.headers["content-type"] = "text/plain"
      response << "not found"
    end
  end

  private def cookies(header)
    parsed = {} of String => String
    return parsed unless header

    header.split(";").each do |part|
      key, value = part.strip.split("=", 2)
      parsed[key] = value
    end
    parsed
  end

  private def repeated_body(size)
    String.build(size) do |io|
      size.times do |index|
        io.write_byte(('a'.ord + (index % 26)).to_u8)
      end
    end
  end
end

host = "127.0.0.1"
port = 0
tls = false
cert = ""
key = ""

ARGV.each_with_index do |arg, index|
  case arg
  when "--host"
    host = ARGV[index + 1]
  when "--port"
    port = ARGV[index + 1].to_i
  when "--tls"
    tls = true
  when "--cert"
    cert = ARGV[index + 1]
  when "--key"
    key = ARGV[index + 1]
  end
end

server = HTTP::Server.new([H2FixtureHandler.new])
if tls
  context = OpenSSL::SSL::Context::Server.new
  context.certificate_chain = cert
  context.private_key = key
  server.bind_tls(host, port, context)
else
  server.bind_tcp(host, port)
end
server.listen
