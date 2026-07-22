require "./spec_helper"

private class NonHTTP1Protocol < NGHTTP::Protocol
  def name : String
    "test/non-http1"
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
    raise "not used"
  end

  def handle_response(env : NGHTTP::HTTPEnv)
    raise "not used"
  end

  def request_to_http_io(env, full_url = false, io = nil)
    raise "not used"
  end

  def http_io_to_response(env : NGHTTP::HTTPEnv, io = nil)
    raise "not used"
  end
end

private def handler_env
  session = NGHTTP::Session.new
  env = session.new_env(nil)
  env.request = session.new_request(
    method: "POST",
    url: "http://example.com/path",
    params: nil,
    body: "body",
    headers: nil
  )
  env.response = session.new_response(env)
  env.int_config.protocol = NonHTTP1Protocol.new
  env
end

describe "protocol-aware handlers" do
  it "does not add Host for protocols that do not use Host headers" do
    env = handler_env

    NGHTTP::HostHeader.new.handle_request(env)

    env.request.headers["Host"]?.should be_nil
  end

  it "does not add chunked transfer encoding for protocols that do not use it" do
    env = handler_env

    NGHTTP::TransferEncoding.new.handle_request(env)

    env.request.headers["Transfer-Encoding"]?.should be_nil
    env.request.body_io.should be_a(IO::Memory)
  end

  it "does not mark reconnect from Connection headers for protocols that do not use them" do
    env = handler_env
    queue = Channel(NGHTTP::Transport).new(1)
    transport = NGHTTP::DirectConnection.new(queue)
    transport.protocol = NonHTTP1Protocol.new
    env.connection = transport
    env.response.headers["Connection"] = "close"

    NGHTTP::KeepAlive.new.handle_response(env)

    transport.require_reconnect?.should be_false
  end
end
