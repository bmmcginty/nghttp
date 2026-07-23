require "./spec_helper"
require "json"

private def copy_and_flush(source, destination)
  buffer = Bytes.new(16 * 1024)
  while (size = source.read(buffer)) > 0
    destination.write(buffer[0, size])
    destination.flush
  end
end

private def local_socks5_proxy(&)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  received = Channel(String).new(1)
  done = Channel(Nil).new(1)

  spawn do
    client : TCPSocket? = nil
    upstream : TCPSocket? = nil
    begin
      client = server.accept
      version = client.read_byte
      nmethods = client.read_byte
      raise "invalid SOCKS5 greeting" unless version == 5 && nmethods
      client.skip(nmethods)
      client.write(Bytes[5, 0])
      client.flush

      version = client.read_byte
      command = client.read_byte
      client.read_byte
      address_type = client.read_byte
      raise "invalid SOCKS5 CONNECT" unless version == 5 && command == 1

      host = case address_type
             when 1
               bytes = Bytes.new(4)
               client.read_fully(bytes)
               bytes.join(".")
             when 3
               length = client.read_byte.not_nil!
               bytes = Bytes.new(length)
               client.read_fully(bytes)
               String.new(bytes)
             else
               raise "unsupported SOCKS5 address type #{address_type}"
             end
      port_bytes = Bytes.new(2)
      client.read_fully(port_bytes)
      target_port = (port_bytes[0].to_i << 8) | port_bytes[1].to_i
      received.send("#{host}:#{target_port}")

      upstream = TCPSocket.new(host, target_port)
      client.write(Bytes[5, 0, 0, 1, 0, 0, 0, 0, 0, 0])
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

  yield "socks5://127.0.0.1:#{port}/", received
ensure
  server.close if server && !server.closed?
  select
  when done.not_nil!.receive
  when timeout(1.second)
  end
end

private def local_socks4_proxy(&)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  received = Channel(String).new(1)
  done = Channel(Nil).new(1)

  spawn do
    client : TCPSocket? = nil
    upstream : TCPSocket? = nil
    begin
      client = server.accept
      version = client.read_byte
      command = client.read_byte
      raise "invalid SOCKS4 CONNECT" unless version == 4 && command == 1

      port_bytes = Bytes.new(2)
      client.read_fully(port_bytes)
      target_port = (port_bytes[0].to_i << 8) | port_bytes[1].to_i

      ip_bytes = Bytes.new(4)
      client.read_fully(ip_bytes)
      host = ip_bytes.join(".")

      while byte = client.read_byte
        break if byte == 0
      end

      received.send("#{host}:#{target_port}")

      upstream = TCPSocket.new(host, target_port)
      client.write(Bytes[0, 90, port_bytes[0], port_bytes[1], ip_bytes[0], ip_bytes[1], ip_bytes[2], ip_bytes[3]])
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

  yield "socks4://127.0.0.1:#{port}/", received
ensure
  server.close if server && !server.closed?
  select
  when done.not_nil!.receive
  when timeout(1.second)
  end
end

private def local_socks4a_proxy(&)
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.as(Socket::IPAddress).port
  received = Channel(String).new(1)
  done = Channel(Nil).new(1)

  spawn do
    client : TCPSocket? = nil
    upstream : TCPSocket? = nil
    begin
      client = server.accept
      version = client.read_byte
      command = client.read_byte
      raise "invalid SOCKS4a CONNECT" unless version == 4 && command == 1

      port_bytes = Bytes.new(2)
      client.read_fully(port_bytes)
      target_port = (port_bytes[0].to_i << 8) | port_bytes[1].to_i

      ip_bytes = Bytes.new(4)
      client.read_fully(ip_bytes)

      while byte = client.read_byte
        break if byte == 0
      end

      domain = String.build do |io|
        while byte = client.read_byte
          break if byte == 0
          io.write_byte(byte)
        end
      end

      raise "invalid SOCKS4a domain request" unless ip_bytes[0, 3] == Bytes[0, 0, 0] && ip_bytes[3] != 0
      received.send("#{domain}:#{target_port}")

      upstream = TCPSocket.new(domain, target_port)
      client.write(Bytes[0, 90, port_bytes[0], port_bytes[1], 0, 0, 0, 0])
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

  yield "socks4a://127.0.0.1:#{port}/", received
ensure
  server.close if server && !server.closed?
  select
  when done.not_nil!.receive
  when timeout(1.second)
  end
end

private def assert_http2_over_socks(
  proxy_url,
  received,
  origin_url = "#{SpecServers.http2_tls_url}/get",
  expected_target = /^127\.0\.0\.1:\d+$/,
)
  session = NGHTTP::Session.new
  cfg = session.new_config
  cfg.proxy = proxy_url
  cfg.protocol = NGHTTP::HTTP2Protocol.new
  cfg.verify = false
  cfg.tries = 0
  cfg.connect_timeout = 1.second
  cfg.read_timeout = 1.second

  session.get(origin_url, config: cfg) do |resp|
    resp.http_version.should eq "2"
    resp.status_code.should eq 200
    JSON.parse(resp.body)["path"].should eq "/get"
  end

  received.receive.should match expected_target
end

describe NGHTTP::Socks5Proxy do
  it "negotiates HTTP/2 over TLS through SOCKS5 proxies" do
    local_socks5_proxy do |proxy_url, received|
      assert_http2_over_socks(proxy_url, received)
    end
  end
end

describe NGHTTP::Socks4aProxy do
  it "negotiates HTTP/2 over TLS through SOCKS4a proxies" do
    local_socks4a_proxy do |proxy_url, received|
      uri = URI.parse(SpecServers.http2_tls_url)
      uri.host = "localhost"
      uri.path = "/get"
      assert_http2_over_socks(proxy_url, received, uri.to_s, /^localhost:\d+$/)
    end
  end
end

describe NGHTTP::Socks4Proxy do
  it "negotiates HTTP/2 over TLS through SOCKS4 proxies" do
    local_socks4_proxy do |proxy_url, received|
      assert_http2_over_socks(proxy_url, received)
    end
  end
end
