require "./spec_helper"

describe NGHTTP::Protocol do
  it "uses HTTP/1 when ALPN negotiation returns nothing" do
    NGHTTP::Protocol.for_alpn(nil).should be NGHTTP::HTTP1Protocol.default
    NGHTTP::Protocol.for_alpn("").should be NGHTTP::HTTP1Protocol.default
  end

  it "maps HTTP/1 ALPN to the HTTP/1 protocol" do
    NGHTTP::Protocol.for_alpn("http/1.1").should be NGHTTP::HTTP1Protocol.default
  end

  it "maps h2 ALPN to an HTTP/2 protocol" do
    NGHTTP::Protocol.for_alpn("h2").should be_a NGHTTP::HTTP2Protocol
  end

  it "exposes whether a protocol can multiplex requests" do
    NGHTTP::HTTP1Protocol.default.multiplexed?.should be_false
    NGHTTP::HTTP2Protocol.new.multiplexed?.should be_true
  end

  it "exposes ALPN protocol preference order" do
    NGHTTP::HTTP1Protocol.default.alpn_ids.should eq ["http/1.1"]
    NGHTTP::HTTP2Protocol.new.alpn_ids.should eq ["h2", "http/1.1"]
  end

  it "raises for unsupported negotiated protocols" do
    expect_raises(NGHTTP::UnsupportedProtocolError, /test-unsupported/) do
      NGHTTP::Protocol.for_alpn("test-unsupported")
    end
  end
end
