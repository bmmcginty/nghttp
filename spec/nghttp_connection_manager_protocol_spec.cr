require "./spec_helper"

private class PoolProtocol < NGHTTP::Protocol
  def initialize(@name : String)
  end

  def name : String
    @name
  end

  def alpn_id : String
    @name
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

private def pool_env(session, protocol)
  env = session.new_env(nil)
  env.config.protocol = protocol
  env.int_config.proxy = "direct:///"
  env.request = session.new_request(
    method: "GET",
    url: "http://example.com/",
    params: nil,
    body: nil,
    headers: nil
  )
  env
end

describe NGHTTP::ConnectionManager do
  it "keeps separate pools for different protocols" do
    session = NGHTTP::Session.new
    env1 = pool_env(session, PoolProtocol.new("test/one"))
    env2 = pool_env(session, PoolProtocol.new("test/two"))

    conn1, _ = session.connection_manager.get(env1)
    conn2, _ = session.connection_manager.get(env2)

    conn1.should_not be conn2
    conn1.release
    conn2.release
  end
end
