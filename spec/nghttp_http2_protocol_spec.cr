require "./spec_helper"

private def h2_config(session)
  config = session.new_config
  config.protocol = NGHTTP::HTTP2Protocol.new
  config
end

private def with_raw_frame_server(frame : Bytes, &)
  port = SpecServers.free_port
  server = TCPServer.new(SpecServers::HOST, port)
  done = Channel(Nil).new

  spawn do
    socket : TCPSocket? = nil
    begin
      socket = server.accept
      preface = Bytes.new(24)
      socket.read_fully(preface)
      settings_header = Bytes.new(9)
      socket.read_fully(settings_header)
      settings_length = (settings_header[0].to_i << 16) | (settings_header[1].to_i << 8) | settings_header[2].to_i
      socket.skip(settings_length) if settings_length > 0

      socket.write(Bytes[0, 0, 0, 4, 0, 0, 0, 0, 0])
      socket.flush
      sleep 50.milliseconds
      socket.write(frame)
      socket.flush
    ensure
      socket.try(&.close)
      done.send(nil)
    end
  end

  yield "http://#{SpecServers::HOST}:#{port}"
ensure
  server.close if server
  select
  when done.not_nil!.receive
  when timeout(1.second)
  end
end

private def with_invalid_frame_server(&)
  with_raw_frame_server(Bytes[0, 0, 0, 1, 0, 0, 0, 0, 0]) do |url|
    yield url
  end
end

private def with_goaway_server(&)
  with_raw_frame_server(Bytes[0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]) do |url|
    yield url
  end
end

private def with_rst_stream_server(&)
  with_raw_frame_server(Bytes[0, 0, 4, 3, 0, 0, 0, 0, 1, 0, 0, 0, 7]) do |url|
    yield url
  end
end

private def with_headers_end_stream_server(&)
  payload = HTTP2::HPACK::Encoder.new(huffman: false).encode(HTTP::Headers{
    ":status" => "204",
  })
  frame = IO::Memory.new
  frame.write_byte(((payload.size >> 16) & 0xff).to_u8)
  frame.write_byte(((payload.size >> 8) & 0xff).to_u8)
  frame.write_byte((payload.size & 0xff).to_u8)
  frame.write_byte(1_u8)
  frame.write_byte(5_u8)
  frame.write(Bytes[0, 0, 0, 1])
  frame.write(payload)

  with_raw_frame_server(frame.to_slice) do |url|
    yield url
  end
end

private def with_http1_tls_alpn_server(&)
  port = SpecServers.free_port
  server = HTTP::Server.new do |context|
    context.response.headers["content-type"] = "text/plain"
    context.response << "http1 fallback"
  end
  context = OpenSSL::SSL::Context::Server.new
  context.certificate_chain = "#{__DIR__}/support/certs/http2_server.crt"
  context.private_key = "#{__DIR__}/support/certs/http2_server.key"
  context.alpn_protocol = "http/1.1"
  server.bind_tls(SpecServers::HOST, port, context)

  spawn do
    server.listen
  end
  SpecServers.wait_for_port(port, 5.seconds)

  yield "https://#{SpecServers::HOST}:#{port}"
ensure
  server.close if server
end

describe NGHTTP::HTTP2Protocol do
  it "performs GET requests over HTTP/2 prior knowledge" do
    session = NGHTTP::Session.new
    config = h2_config(session)

    session.get("#{SpecServers.http2_url}/get", config: config) do |resp|
      resp.http_version.should eq "2"
      resp.status_code.should eq 200
      JSON.parse(resp.body)["path"].should eq "/get"
    end
  end

  it "sends POST request bodies over HTTP/2 DATA frames" do
    session = NGHTTP::Session.new
    config = h2_config(session)
    headers = HTTP::Headers{"Content-Type" => "text/plain"}

    session.post("#{SpecServers.http2_url}/echo", body: "hello h2", headers: headers, config: config) do |resp|
      resp.http_version.should eq "2"
      resp.status_code.should eq 200
      resp.headers["content-type"].should eq "text/plain"
      resp.body.should eq "hello h2"
    end
  end

  it "performs HTTPS requests over HTTP/2 negotiated with ALPN" do
    session = NGHTTP::Session.new
    config = h2_config(session)
    config.verify = false

    session.get("#{SpecServers.http2_tls_url}/get", config: config) do |resp|
      resp.http_version.should eq "2"
      resp.status_code.should eq 200
      JSON.parse(resp.body)["path"].should eq "/get"
    end
  end

  it "falls back to HTTP/1.1 when TLS ALPN selects HTTP/1.1" do
    with_http1_tls_alpn_server do |url|
      session = NGHTTP::Session.new
      config = h2_config(session)
      config.verify = false

      session.get(url, config: config) do |resp|
        resp.http_version.should eq "1.1"
        resp.body.should eq "http1 fallback"
      end
    end
  end

  it "sends custom headers over HTTP/2" do
    session = NGHTTP::Session.new
    headers = HTTP::Headers{"X-Test" => "h2-header"}

    session.get("#{SpecServers.http2_url}/headers", headers: headers, config: h2_config(session)) do |resp|
      JSON.parse(resp.body)["headers"]["x-test"].should eq "h2-header"
    end
  end

  it "sends basic auth over HTTP/2" do
    session = NGHTTP::Session.new
    config = h2_config(session)
    config.basic_auth = {"abc", "def"}

    session.get("#{SpecServers.http2_url}/basic-auth/abc/def", config: config) do |resp|
      resp.status_code.should eq 200
      JSON.parse(resp.body)["user"].should eq "abc"
    end
  end

  it "follows redirects over HTTP/2" do
    session = NGHTTP::Session.new

    session.get("#{SpecServers.http2_url}/redirect/2", config: h2_config(session)) do |resp|
      resp.status_code.should eq 200
      resp.env.request.uri.path.should eq "/get"
      JSON.parse(resp.body)["path"].should eq "/get"
    end
  end

  it "persists cookies over HTTP/2" do
    session = NGHTTP::Session.new
    session.cookiejar["kn1"] = "kv1"
    session.cookiejar["kn2"] = "kv2"

    session.get("#{SpecServers.http2_url}/cookies", config: h2_config(session)) do |resp|
      cookies = JSON.parse(resp.body)["cookies"]
      cookies["kn1"].should eq "kv1"
      cookies["kn2"].should eq "kv2"
    end
  end

  it "handles Set-Cookie response headers over HTTP/2" do
    session = NGHTTP::Session.new

    session.get("#{SpecServers.http2_url}/cookies/set?kn1=kv1", config: h2_config(session)) do |resp|
      resp.body
    end

    session.get("#{SpecServers.http2_url}/cookies", config: h2_config(session)) do |resp|
      JSON.parse(resp.body)["cookies"]["kn1"].should eq "kv1"
    end
  end

  it "can start another HTTP/2 request while the first response body is still open" do
    session = NGHTTP::Session.new
    config = h2_config(session)
    config.connections_per_host = 1

    session.get("#{SpecServers.http2_url}/get", config: config) do |first|
      result = Channel(String | Exception).new

      spawn do
        begin
          session.get("#{SpecServers.http2_url}/get", config: config) do |second|
            result.send(JSON.parse(second.body)["path"].as_s)
          end
        rescue ex
          result.send(ex)
        end
      end

      select
      when value = result.receive
        raise value if value.is_a?(Exception)
        value.should eq "/get"
      when timeout(2.seconds)
        fail "timed out waiting for nested HTTP/2 request"
      end

      JSON.parse(first.body)["path"].should eq "/get"
    end
  end

  it "raises when the HTTP/2 receive loop fails before response headers" do
    with_invalid_frame_server do |url|
      session = NGHTTP::Session.new

      expect_raises(NGHTTP::HTTP2Error, /connection failed/) do
        session.get("#{url}/invalid-frame", config: h2_config(session)) { }
      end
    end
  end

  it "raises a GOAWAY error when the HTTP/2 connection receives GOAWAY before response headers" do
    with_goaway_server do |url|
      session = NGHTTP::Session.new

      expect_raises(NGHTTP::HTTP2GoawayError, /GOAWAY/) do
        session.get("#{url}/goaway", config: h2_config(session)) { }
      end
    end
  end

  it "raises a refused stream error when an HTTP/2 stream receives REFUSED_STREAM before response headers" do
    with_rst_stream_server do |url|
      session = NGHTTP::Session.new

      expect_raises(NGHTTP::HTTP2RefusedStreamError, /REFUSED_STREAM/) do
        session.get("#{url}/rst-stream", config: h2_config(session)) { }
      end
    end
  end

  it "handles HTTP/2 responses that end on the HEADERS frame" do
    with_headers_end_stream_server do |url|
      session = NGHTTP::Session.new

      session.get("#{url}/empty", config: h2_config(session)) do |resp|
        resp.status_code.should eq 204
        resp.body.should eq ""
      end
    end
  end
end
