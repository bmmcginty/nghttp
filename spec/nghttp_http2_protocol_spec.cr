require "./spec_helper"

private def h2_config(session)
  config = session.new_config
  config.protocol = NGHTTP::HTTP2Protocol.new
  config
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
end
