require "./spec_helper"

private def protocol_env(method = "GET", url = "http://example.com/path?q=1")
  session = NGHTTP::Session.new
  env = session.new_env(nil)
  env.request = session.new_request(
    method: method,
    url: url,
    params: nil,
    body: nil,
    headers: nil
  )
  env.response = session.new_response(env)
  env
end

describe NGHTTP::HTTP1Protocol do
  it "can be used through the generic protocol interface" do
    protocol = NGHTTP::HTTP1Protocol.default.as(NGHTTP::Protocol)
    env = protocol_env
    io = IO::Memory.new

    protocol.request_to_http_io(env, io: io)

    io.to_s.lines[0].should eq "GET /path?q=1 HTTP/1.1"
  end

  it "writes origin-form request targets by default" do
    env = protocol_env
    env.request.headers["Host"] = "example.com"
    io = IO::Memory.new

    NGHTTP::HTTP1Protocol.request_to_http_io(env, io: io)

    io.to_s.lines[0].should eq "GET /path?q=1 HTTP/1.1"
    io.to_s.should contain "Host: example.com\r\n"
  end

  it "writes / for empty origin-form request targets" do
    env = protocol_env(url: "https://example.com")
    io = IO::Memory.new

    NGHTTP::HTTP1Protocol.request_to_http_io(env, io: io)

    io.to_s.lines[0].should eq "GET / HTTP/1.1"
  end

  it "writes absolute-form request targets when requested" do
    env = protocol_env
    io = IO::Memory.new

    NGHTTP::HTTP1Protocol.request_to_http_io(env, full_url: true, io: io)

    io.to_s.lines[0].should eq "GET http://example.com/path?q=1 HTTP/1.1"
  end

  it "parses response status lines and headers" do
    env = protocol_env
    io = IO::Memory.new("HTTP/1.1 201 Created\r\nContent-Length: 2\r\nX-Test: ok\r\n\r\nhi")

    NGHTTP::HTTP1Protocol.http_io_to_response(env, io)

    env.response.http_version.should eq "1.1"
    env.response.status_code.should eq 201
    env.response.status_message.should eq "Created"
    env.response.headers["X-Test"].should eq "ok"
    env.response.body_io.gets_to_end.should eq "hi"
  end
end
