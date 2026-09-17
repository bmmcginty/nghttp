require "./spec_helper"

private def local_override_server(&)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  received = Channel(Array(String)).new(1)
  done = Channel(Nil).new(1)

  spawn do
    client : TCPSocket? = nil
    begin
      client = server.accept
      lines = [] of String
      while line = client.gets
        break if line == ""
        lines << line
      end
      received.send(lines)
      client << "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
      client.flush
    ensure
      client.try(&.close)
      done.send(nil)
    end
  end

  yield port, received
ensure
  server.close if server && !server.closed?
  select
  when done.not_nil!.receive
  when timeout(1.second)
  end
end

private def override_env(session, address)
  env = session.new_env(nil)
  env.config.dns_override = {"example.invalid" => address}
  env.int_config.proxy = "direct:///"
  env.request = session.new_request(
    method: "GET",
    url: "http://example.invalid/",
    params: nil,
    body: nil,
    headers: nil
  )
  env
end

describe "DNS overrides" do
  it "connects to the override while preserving the HTTP hostname" do
    local_override_server do |port, received|
      session = NGHTTP::Session.new
      config = session.new_config
      config.dns_override = {"EXAMPLE.INVALID" => "127.0.0.1"}
      config.tries = 0

      session.get("http://example.invalid:#{port}/override", config: config) do |response|
        response.body.should eq "ok"
      end

      lines = received.receive
      lines[0].should eq "GET /override HTTP/1.1"
      lines.should contain "Host: example.invalid:#{port}"
    end
  end

  it "keeps separate connection pools when an override changes" do
    session = NGHTTP::Session.new
    connection1, _ = session.connection_manager.get(override_env(session, "127.0.0.1"))
    connection2, _ = session.connection_manager.get(override_env(session, "127.0.0.2"))

    connection1.should_not be connection2
    connection1.release
    connection2.release
  end

  it "rejects override values that are not IP literals" do
    session = NGHTTP::Session.new
    env = override_env(session, "localhost")

    expect_raises(Socket::Error, /Invalid IP address/) do
      session.connection_manager.get(env)
    end
  end
end
