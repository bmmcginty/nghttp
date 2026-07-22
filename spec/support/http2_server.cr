require "http2/server"
require "json"

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
    when "/echo"
      response.headers["content-type"] = request.headers["content-type"]? || "application/octet-stream"
      IO.copy(request.body.not_nil!, response)
    else
      response.status_code = 404
      response.headers["content-type"] = "text/plain"
      response << "not found"
    end
  end
end

host = "127.0.0.1"
port = 0

ARGV.each_with_index do |arg, index|
  case arg
  when "--host"
    host = ARGV[index + 1]
  when "--port"
    port = ARGV[index + 1].to_i
  end
end

server = HTTP::Server.new([H2FixtureHandler.new])
server.bind_tcp(host, port)
server.listen
