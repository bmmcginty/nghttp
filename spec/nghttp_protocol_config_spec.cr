require "./spec_helper"

private class ConfigProtocol < NGHTTP::Protocol
  def name : String
    "test/config"
  end

  def alpn_id : String
    "test/config"
  end

  def uses_host_header? : Bool
    false
  end

  def uses_connection_header? : Bool
    false
  end

  def uses_transfer_encoding? : Bool
    false
  end

  def handle_request(env, full_url = false)
  end

  def handle_response(env : NGHTTP::HTTPEnv)
  end

  def request_to_http_io(env, full_url = false, io = nil)
  end

  def http_io_to_response(env : NGHTTP::HTTPEnv, io = nil)
  end
end

private class ConfigTransport < NGHTTP::Transport
  @socket : SocketType? = nil
  getter connected = false
  getter! socket

  def initialize
  end

  def connect(env)
    @connected = true
  end

  def broken? : Bool
    false
  end

  def closed?
    false
  end

  def no_socket?
    false
  end

  def release
  end

  def handle_request(env : NGHTTP::HTTPEnv)
  end

  def handle_response(env : NGHTTP::HTTPEnv)
  end
end

describe "configured protocols" do
  it "can select the env protocol before a connection exists" do
    session = NGHTTP::Session.new
    protocol = ConfigProtocol.new
    env = session.new_env(nil)
    env.config.protocol = protocol

    env.protocol.should be protocol
  end

  it "applies configured protocols to explicit transports before connect" do
    session = NGHTTP::Session.new
    protocol = ConfigProtocol.new
    transport = ConfigTransport.new
    env = session.new_env(nil)
    env.config.protocol = protocol
    env.int_config.transport = transport
    env.request = session.new_request(
      method: "GET",
      url: "http://example.com/",
      params: nil,
      body: nil,
      headers: nil
    )

    NGHTTP::HTTPConnecter.new.ensure_transport(env)

    transport.connected.should be_true
    transport.protocol.should be protocol
    env.int_config.protocol.should be protocol
  end
end
