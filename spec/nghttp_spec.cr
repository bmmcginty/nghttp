require "./spec_helper"
require "json"

class C
  @@c = NGHTTP::Session.new
  @@c.config.max_redirects = 3
  @@c.config.wait = 0.seconds

  def self.c
    @@c
  end
end

SRV = "http://127.0.0.1:5000"

def new_config
  C.c.new_config
end

{% for method in %w(get post put delete) %}
def j{{method.id}}(url, **kw)
url=url.strip "/"
u="#{SRV}/#{url}"
C.c.{{method.id}}(u,**kw) do |resp|
yield JSON.parse resp.body_io
end
end

def r{{method.id}}(url, **kw)
url=url.strip "/"
u="#{SRV}/#{url}"
C.c.{{method.id}}(u,**kw) do |resp|
yield resp
end
end
{% end %}

def keep_alive(alive : Bool)
  headers = HTTP::Headers.new
  if alive == false
    headers["Connection"] = "close"
  end
  C.c.get("http://127.0.0.1/conn", headers: headers) do |resp|
    yield JSON.parse(resp.body_io)
  end
end

describe Nghttp do
  it "gets ip" do
    jget "ip" do |t|
      t["origin"]?.should_not eq nil
    end
  end

  it "gets user-agent" do
    h = HTTP::Headers.new
    h.add "User-Agent", "test"
    jget url: "user-agent", headers: h do |j|
      j["user-agent"]?.should eq "test"
    end
  end

  it "gets custom headrs" do
    h = HTTP::Headers.new
    h.add "test", "123"
    jget "headers", headers: h do |j|
      j["headers"]["Test"]?.should eq "123"
    end
  end

  it "gets with params" do
    jget "get", params: {"abc" => "def"} do |j|
      j["args"]["abc"].should eq "def"
    end
  end

  it "gets with qs" do
    jget "get?ghi=j k l" do |j|
      j["args"]["ghi"].should eq "j k l"
    end
  end

  it "gets with params and qs" do
    jget "get?ghi=j k l", params: {"abc" => "def"} do |j|
      j["args"]["abc"].should eq "def"
      j["args"]["ghi"].should eq "j k l"
    end
  end

  it "posts data" do
    a = "testabcd=efg"
    m = IO::Memory.new a.to_slice
    jpost "/post", body: m do |j|
      j["form"]["testabcd"].should eq "efg"
    end
  end

  it "posts with data and qs" do
    a = "testabcd=efg"
    m = IO::Memory.new a.to_slice
    jpost "/post?a=bc", body: m do |j|
      j["args"]["a"].should eq "bc"
      j["form"]["testabcd"].should eq "efg"
    end
  end

  it "authorizes with propper username and password" do
    cfg = new_config
    cfg.basic_auth = {"abc", "def"}
    rget "/basic-auth/abc/def", config: cfg do |resp|
      JSON.parse(resp.body_io)["user"].as_s.should eq "abc"
      resp.status_code.should eq 200
    end
  end

  it "failes to authorize with invalid username and password" do
    cfg = new_config
    cfg.basic_auth = {"ghi", "jkl"}
    rget "/basic-auth/abc/def", config: cfg do |resp|
      resp.status_code.should eq 401
    end
  end

  it "sets and deletes cookies, verifying each action" do
    jget "/cookies" do |j|
      j["cookies"].as_h.size.should eq 0
    end
    jget "/cookies/set?kn1=kv1&kn2=kv2" do |j|
    end
    jget "/cookies" do |j|
      h = j["cookies"]
      h["kn1"].as_s.should eq "kv1"
      h["kn2"].as_s.should eq "kv2"
      h.as_h.size.should eq 2
    end
    jget "/cookies/delete?kn1=" do |j|
    end
    jget "/cookies" do |j|
      h = j["cookies"]
      h["kn2"].as_s.should eq "kv2"
      h.as_h.size.should eq 1
    end
  end

  it "handles multiple redirects" do
    rget "/redirect/3" do |resp|
      resp.env.request.uri.path.should eq "/get"
      resp.body_io.skip_to_end
    end
  end

  it "handles only permitted number of redirects before throwing error" do
    cfg = new_config
    cfg.max_redirects = 3
    rget "/redirect/3", config: cfg do |resp|
      resp.env.request.uri.path.should eq "/get"
      resp.body_io.skip_to_end
    end
    expect_raises(NGHTTP::TooManyRedirectsError) do
      cfg = new_config
      cfg.max_redirects = 1
      rget "/redirect/2", config: cfg do |resp|
        raise Exception.new("code should never get here")
      end
    end
  end

  it "raises when no redirects are allowed" do
    expect_raises(NGHTTP::TooManyRedirectsError) do
      cfg = new_config
      cfg.max_redirects = 0
      rget "/redirect/1", config: cfg do |resp|
        resp.env.request.uri.path.should eq "/get"
        resp.body_io.skip_to_end
      end
    end
  end

it "handles redirects" do
#t=s.post("http://localhost:5000/redirect-to",params={"url":"/post","status_code":"307"},data={"test":"test2"})
jpost "/redirect-to?url=/anything/post&status_code=307", body: "a=b" do |j|
j["method"].as_s.should eq "POST"
j["form"]["a"].as_s.should eq "b"
end # do
jpost "/redirect-to?url=/anything/get&status_code=302", body: "a=b" do |j|
j["method"].as_s.should eq "GET"
j["form"].as_h.size.should eq 0
end # do
end # it

  it "handles gzipped content" do
    jget "/gzip" do |j|
      j["gzipped"].as_bool.should eq true
    end
  end

  it "handles deflate content" do
    jget "/deflate" do |j|
      j["deflated"].as_bool.should eq true
    end
  end

  it "handles utf-8 content" do
    rget "/encoding/utf8" do |resp|
      t = resp.body_io.gets_to_end
      t.index('\u2200').should_not eq nil
    end
  end

  it "handles read timeouts and clears underlying connections propperly" do
    cfg = new_config
    cfg.read_timeout = 0.5.seconds
    cfg.tries = 2
    3.times do |tim|
      expect_raises(IO::TimeoutError) do
        rget "/delay/5?t=#{tim}", config: cfg do |resp|
          # we should timeout before ever yielding to this block, so this error should never be seen
          "this block should not be called".should eq 0
        end # rget
      end   # raises
    end     # times
  end       # it

  it "respects longer timeouts" do
    cfg = new_config
    cfg.read_timeout = 3.seconds
    rget "/delay/1", config: cfg do |resp|
      resp.should_not be nil
    end
  end

  it "handles content ranges" do
    rget "/range/1024" do |resp|
      resp.body.size.should eq 1024
    end
    cfg = new_config
    cfg.offset = 2
    rget "/range/1024", config: cfg do |resp|
      resp.body.size.should eq 1022
    end
    cfg = new_config
    cfg.offset = 4
    rget "/range/1024", config: cfg do |resp|
      resp.body.size.should eq 1020
    end
    cfg = new_config
    cfg.offset = 5..9
    rget "/range/1024", config: cfg do |resp|
      resp.body.size.should eq 5
      resp.body.should eq "fghij"
    end
    cfg = new_config
    cfg.offset = 0...5
    rget "/range/1024", config: cfg do |resp|
      resp.body.size.should eq 5
      resp.body.should eq "abcde"
    end
  end

  it "handles keep alive" do
    l = [] of String
    3.times do
      keep_alive(true) do |j|
        l << j["connection"].as_s
      end
    end
    l.uniq.size.should eq 1
    l.clear
    3.times do
      keep_alive(false) do |j|
        l << j["connection"].as_s
      end
    end
    l.uniq.size.should eq 3
  end # it

  if 1 == 0
    it "handles http proxy" do
      cfg = new_config
      cfg.proxy = "http://127.0.1:8888/"
      cfg.read_timeout = 0.1.seconds
      rget "/get", config: cfg do
      end
    end
  end

it "resends body on error" do
# we should send a request, the server should timeout, and we should resend the same request
1.should eq 0
end

  #  it "works" do
  #    false.should eq(true)
  #  end
end
