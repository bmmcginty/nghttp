require "./spec_helper"
require "http2"

private class ManagedH2Client
  @connection : HTTP2::Connection
  @requests = {} of HTTP2::Stream => Channel(Nil)

  def initialize(url : String)
    uri = URI.parse(url)
    host = uri.host.not_nil!
    port = uri.port || 80
    @authority = "#{host}:#{port}"

    io = TCPSocket.new(host, port)
    @connection = HTTP2::Connection.new(io, HTTP2::Connection::Type::CLIENT)
    @connection.write_client_preface
    @connection.write_settings

    frame = @connection.receive
    unless frame.try(&.type) == HTTP2::Frame::Type::SETTINGS
      raise "expected HTTP/2 SETTINGS frame"
    end

    spawn receive_frames
  end

  def get(path)
    request("GET", path)
  end

  def request(method, path)
    stream = @connection.streams.create
    @requests[stream] = Channel(Nil).new
    stream.send_headers(HTTP::Headers{
      ":method"    => method,
      ":path"      => path,
      ":scheme"    => "http",
      ":authority" => @authority,
    })

    @requests[stream].receive
    {stream.headers, stream.data.gets_to_end}
  ensure
    @requests.delete(stream) if stream
  end

  def close
    @connection.close unless @connection.closed?
  end

  private def receive_frames
    while frame = @connection.receive
      if frame.type == HTTP2::Frame::Type::HEADERS
        @requests[frame.stream]?.try(&.send(nil))
      end
    end
  end
end

describe "managed HTTP/2 fixture" do
  it "serves HTTP/2 responses" do
    client = ManagedH2Client.new(SpecServers.http2_url)
    headers, body = client.get("/get")

    headers[":status"].should eq "200"
    JSON.parse(body)["path"].should eq "/get"
  ensure
    client.try(&.close)
  end
end
