require "./spec_helper"
require "json"

private def local_proxy(&)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  begin
    yield server, port
  ensure
    server.close unless server.closed?
  end
end

private def read_proxy_headers(client)
  lines = [] of String
  while line = client.gets
    break if line == ""
    lines << line
  end
  lines
end

private def local_connect_proxy(&)
  done = Channel(Nil).new(1)

  local_proxy do |server, port|
    received = Channel(Array(String)).new(1)

    spawn do
      client : TCPSocket? = nil
      upstream : TCPSocket? = nil
      begin
        client = server.accept
        lines = read_proxy_headers(client)
        received.send(lines)

        target = lines[0].split(" ")[1]
        host, port_text = target.split(":", 2)
        upstream = TCPSocket.new(host, port_text.to_i)

        client << "HTTP/1.1 200 Connection Established\r\n\r\n"
        client.flush

        pipe_done = Channel(Nil).new(2)
        spawn do
          IO.copy(client.not_nil!, upstream.not_nil!)
        rescue
        ensure
          upstream.try(&.close)
          pipe_done.send(nil)
        end
        spawn do
          IO.copy(upstream.not_nil!, client.not_nil!)
        rescue
        ensure
          client.try(&.close)
          pipe_done.send(nil)
        end
        pipe_done.receive
      ensure
        client.try(&.close)
        upstream.try(&.close)
        done.send(nil)
      end
    end

    yield "http://127.0.0.1:#{port}/", received
  ensure
    select
    when done.receive
    when timeout(1.second)
    end
  end
end

private def local_tls_connect_proxy(&)
  done = Channel(Nil).new(1)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  context = OpenSSL::SSL::Context::Server.new
  context.certificate_chain = "#{__DIR__}/support/certs/http2_server.crt"
  context.private_key = "#{__DIR__}/support/certs/http2_server.key"
  context.alpn_protocol = "http/1.1"
  received = Channel(Array(String)).new(1)

  spawn do
    client : OpenSSL::SSL::Socket::Server? = nil
    upstream : TCPSocket? = nil
    begin
      tcp_client = server.accept
      client = OpenSSL::SSL::Socket::Server.new(tcp_client, context, sync_close: true)
      lines = read_proxy_headers(client)
      received.send(lines)

      target = lines[0].split(" ")[1]
      host, port_text = target.split(":", 2)
      upstream = TCPSocket.new(host, port_text.to_i)

      client << "HTTP/1.1 200 Connection Established\r\n\r\n"
      client.flush

      pipe_done = Channel(Nil).new(2)
      spawn do
        copy_and_flush(client.not_nil!, upstream.not_nil!)
      rescue
      ensure
        upstream.try(&.close)
        pipe_done.send(nil)
      end
      spawn do
        copy_and_flush(upstream.not_nil!, client.not_nil!)
      rescue
      ensure
        client.try(&.close)
        pipe_done.send(nil)
      end
      pipe_done.receive
    ensure
      client.try(&.close)
      upstream.try(&.close)
      done.send(nil)
    end
  end

  yield "https://127.0.0.1:#{port}/?verify=0", received
ensure
  server.close if server && !server.closed?
  select
  when done.not_nil!.receive
  when timeout(1.second)
  end
end

private def copy_and_flush(source, destination)
  buffer = Bytes.new(16 * 1024)
  while (size = source.read(buffer)) > 0
    destination.write(buffer[0, size])
    destination.flush
  end
end

private def local_http1_tls_server(alpn_protocol : String?, response_body : String, &)
  port = SpecServers.free_port
  server = HTTP::Server.new do |context|
    context.response.headers["content-type"] = "text/plain"
    context.response << response_body
  end
  context = OpenSSL::SSL::Context::Server.new
  context.certificate_chain = "#{__DIR__}/support/certs/http2_server.crt"
  context.private_key = "#{__DIR__}/support/certs/http2_server.key"
  context.alpn_protocol = alpn_protocol if alpn_protocol
  server.bind_tls(SpecServers::HOST, port, context)

  spawn do
    server.listen
  end
  SpecServers.wait_for_port(port, 5.seconds)

  yield "https://#{SpecServers::HOST}:#{port}"
ensure
  server.close if server
end

describe NGHTTP::HttpProxy do
  it "sends optional basic proxy auth on HTTP proxy requests" do
    local_proxy do |server, port|
      received = Channel(Array(String)).new(1)

      spawn do
        client = server.accept
        lines = read_proxy_headers(client)
        received.send(lines)
        client << "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
        client.close
      end

      session = NGHTTP::Session.new
      cfg = session.new_config
      cfg.proxy = "http://proxy-user:proxy-pass@127.0.0.1:#{port}/"
      cfg.tries = 0

      session.get("http://example.com/proxy-path?q=1", config: cfg) do |resp|
        resp.body.should eq "ok"
      end

      lines = received.receive
      lines[0].should eq "GET http://example.com/proxy-path?q=1 HTTP/1.1"
      lines.should contain "Proxy-Authorization: Basic #{Base64.strict_encode("proxy-user:proxy-pass")}"
    end
  end

  it "does not require proxy auth when proxy credentials are absent" do
    local_proxy do |server, port|
      received = Channel(Array(String)).new(1)

      spawn do
        client = server.accept
        lines = read_proxy_headers(client)
        received.send(lines)
        client << "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
        client.close
      end

      session = NGHTTP::Session.new
      cfg = session.new_config
      cfg.proxy = "http://127.0.0.1:#{port}/"
      cfg.tries = 0

      session.get("http://example.com/proxy-path", config: cfg) do |resp|
        resp.body.should eq "ok"
      end

      lines = received.receive
      lines[0].should eq "GET http://example.com/proxy-path HTTP/1.1"
      lines.any?(&.starts_with?("Proxy-Authorization:")).should be_false
    end
  end

  it "rejects HTTP/2 over forward HTTP proxies" do
    session = NGHTTP::Session.new
    env = session.new_env(nil)
    env.request = session.new_request(
      method: "GET",
      url: "http://example.com/proxy-path",
      params: nil,
      body: nil,
      headers: nil
    )
    env.int_config.proxy = "http://127.0.0.1:1/"
    queue = Channel(NGHTTP::Transport).new(1)
    transport = NGHTTP::HttpProxy.new(queue)
    transport.protocol = NGHTTP::HTTP2Protocol.new
    env.connection = transport

    expect_raises(NGHTTP::UnsupportedProtocolError, /forward HTTP proxies/) do
      transport.handle_request(env)
    end
  end

  it "sends proxy auth on CONNECT requests" do
    local_proxy do |server, port|
      received = Channel(Array(String)).new(1)

      spawn do
        client = server.accept
        lines = read_proxy_headers(client)
        received.send(lines)
        client << "HTTP/1.1 200 Connection Established\r\nContent-Length: 0\r\n\r\n"
        client.close
      end

      session = NGHTTP::Session.new
      cfg = session.new_config
      cfg.proxy = "http://proxy-user:proxy-pass@127.0.0.1:#{port}/"
      cfg.tries = 0

      expect_raises(Exception) do
        session.get("https://example.com/proxy-path", config: cfg) do |resp|
          resp.body
        end
      end

      lines = received.receive
      lines[0].should eq "CONNECT example.com:443 HTTP/1.1"
      lines.should contain "Host: example.com:443"
      lines.should contain "Proxy-Authorization: Basic #{Base64.strict_encode("proxy-user:proxy-pass")}"
    end
  end

  it "negotiates HTTP/2 over TLS through HTTP CONNECT proxies" do
    local_connect_proxy do |proxy_url, received|
      session = NGHTTP::Session.new
      cfg = session.new_config
      cfg.proxy = proxy_url
      cfg.protocol = NGHTTP::HTTP2Protocol.new
      cfg.verify = false
      cfg.tries = 0

      session.get("#{SpecServers.http2_tls_url}/get", config: cfg) do |resp|
        resp.http_version.should eq "2"
        resp.status_code.should eq 200
        JSON.parse(resp.body)["path"].should eq "/get"
      end

      lines = received.receive
      lines[0].should match /^CONNECT 127\.0\.0\.1:\d+ HTTP\/1\.1$/
    end
  end

  it "falls back to HTTP/1.1 over HTTP CONNECT proxies when origin ALPN selects HTTP/1.1" do
    local_http1_tls_server("http/1.1", "proxied http1 fallback") do |origin_url|
      local_connect_proxy do |proxy_url, received|
        session = NGHTTP::Session.new
        cfg = session.new_config
        cfg.proxy = proxy_url
        cfg.protocol = NGHTTP::HTTP2Protocol.new
        cfg.verify = false
        cfg.tries = 0

        session.get(origin_url, config: cfg) do |resp|
          resp.http_version.should eq "1.1"
          resp.body.should eq "proxied http1 fallback"
        end

        lines = received.receive
        lines[0].should match /^CONNECT 127\.0\.0\.1:\d+ HTTP\/1\.1$/
      end
    end
  end

  it "negotiates HTTP/2 through HTTPS CONNECT proxies" do
    local_tls_connect_proxy do |proxy_url, received|
      session = NGHTTP::Session.new
      cfg = session.new_config
      cfg.proxy = proxy_url
      cfg.protocol = NGHTTP::HTTP2Protocol.new
      cfg.verify = false
      cfg.tries = 0
      cfg.connect_timeout = 1.second
      cfg.read_timeout = 1.second

      session.get("#{SpecServers.http2_tls_url}/get", config: cfg) do |resp|
        resp.http_version.should eq "2"
        resp.status_code.should eq 200
        JSON.parse(resp.body)["path"].should eq "/get"
      end

      lines = received.receive
      lines[0].should match /^CONNECT 127\.0\.0\.1:\d+ HTTP\/1\.1$/
    end
  end
end
