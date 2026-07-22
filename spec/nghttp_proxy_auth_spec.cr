require "./spec_helper"

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
end
