require "./spec_helper"

describe NGHTTP::Protocol do
  it "uses HTTP/1 when ALPN negotiation returns nothing" do
    NGHTTP::Protocol.for_alpn(nil).should be NGHTTP::HTTP1Protocol.default
    NGHTTP::Protocol.for_alpn("").should be NGHTTP::HTTP1Protocol.default
  end

  it "maps HTTP/1 ALPN to the HTTP/1 protocol" do
    NGHTTP::Protocol.for_alpn("http/1.1").should be NGHTTP::HTTP1Protocol.default
  end

  it "raises for unsupported negotiated protocols" do
    expect_raises(NGHTTP::UnsupportedProtocolError, /h2/) do
      NGHTTP::Protocol.for_alpn("h2")
    end
  end
end
