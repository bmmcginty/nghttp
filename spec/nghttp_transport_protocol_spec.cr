require "./spec_helper"

describe NGHTTP::Transport do
  it "defaults direct transports to HTTP/1" do
    queue = Channel(NGHTTP::Transport).new(1)
    transport = NGHTTP::DirectConnection.new(queue)

    transport.protocol.should be NGHTTP::HTTP1Protocol.default
  end

  it "defaults proxy transports to HTTP/1" do
    queue = Channel(NGHTTP::Transport).new(1)
    transport = NGHTTP::HttpProxy.new(queue)

    transport.protocol.should be NGHTTP::HTTP1Protocol.default
  end
end
