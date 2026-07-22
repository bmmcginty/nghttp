require "./spec_helper"

describe NGHTTP::HTTP2Protocol do
  it "performs GET requests over HTTP/2 prior knowledge" do
    session = NGHTTP::Session.new
    config = session.new_config
    config.protocol = NGHTTP::HTTP2Protocol.new

    session.get("#{SpecServers.http2_url}/get", config: config) do |resp|
      resp.http_version.should eq "2"
      resp.status_code.should eq 200
      JSON.parse(resp.body)["path"].should eq "/get"
    end
  end

  it "sends POST request bodies over HTTP/2 DATA frames" do
    session = NGHTTP::Session.new
    config = session.new_config
    config.protocol = NGHTTP::HTTP2Protocol.new
    headers = HTTP::Headers{"Content-Type" => "text/plain"}

    session.post("#{SpecServers.http2_url}/echo", body: "hello h2", headers: headers, config: config) do |resp|
      resp.http_version.should eq "2"
      resp.status_code.should eq 200
      resp.headers["content-type"].should eq "text/plain"
      resp.body.should eq "hello h2"
    end
  end
end
