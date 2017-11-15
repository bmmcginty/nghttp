require "./spec_helper"
require "json"

class C
@@c=NGHTTP::Session.new maximum_redirects: 3, wait: nil, debug: false
def self.c
@@c
end
end

{% for method in %w(get post put delete) %}
def j{{method.id}}(url, **kw)
url=url.strip "/"
u="http://httpbin.apps.bmcginty.us/#{url}"
C.c.{{method.id}}(u,**kw) do |resp|
yield JSON.parse resp.body_io
end
end

def r{{method.id}}(url, **kw)
url=url.strip "/"
u="http://httpbin.apps.bmcginty.us/#{url}"
C.c.{{method.id}}(u,**kw) do |resp|
yield resp
end
end
{% end %}

describe Nghttp do

it "gets ip" do
jget "ip" do |t|
t["origin"]?.should_not eq nil
end
end

it "gets user-agent" do
h=HTTP::Headers.new
h.add "User-Agent","test"
jget url: "user-agent", headers: h do |j|
j["user-agent"]?.should eq "test"
end
end

it "gets custom headrs" do
h=HTTP::Headers.new
h.add "test","123"
jget "headers", headers: h do |j|
j["headers"]["Test"]?.should eq "123"
end
end

it "gets with params" do
jget "get", params: {"abc"=>"def"} do |j|
j["args"]["abc"].should eq "def"
end
end

it "gets with qs" do
jget "get?ghi=j k l" do |j|
j["args"]["ghi"].should eq "j k l"
end
end

it "gets with params and qs" do
jget "get?ghi=j k l", params: {"abc"=>"def"} do |j|
j["args"]["abc"].should eq "def"
j["args"]["ghi"].should eq "j k l"
end
end

it "posts data" do
a="testabcd"
m=IO::Memory.new a.to_slice
jpost "/post", body: m do |j|
j["data"].should eq a
end
end

it "posts with data and qs" do
a="testabcd"
m=IO::Memory.new a.to_slice
jpost "/post?a=bc", body: m do |j|
j["data"].should eq a
j["args"]["a"].should eq "bc"
end
end

it "authorizes with propper username and password" do
rget "/basic-auth/abc/def", basic_auth: ["abc","def"] do |resp|
JSON.parse(resp.body_io)["user"].as_s.should eq "abc"
resp.status_code.should eq 200
end
end

it "failes to authorize with invalid username and password" do
rget "/basic-auth/abc/def", basic_auth: ["ghi","jkl"] do |resp|
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
h=j["cookies"]
h["kn1"].as_s.should eq "kv1"
h["kn2"].as_s.should eq "kv2"
h.as_h.size.should eq 2
end
jget "/cookies/delete?kn1=" do |j|
end
jget "/cookies" do |j|
h=j["cookies"]
h["kn2"].as_s.should eq "kv2"
h.as_h.size.should eq 1
end
end

it "handles multiple redirects" do
rget "/redirect/3" do |resp|
#puts resp.env.config
resp.env.request.uri.path.should eq "/get"
resp.body_io.skip_to_end
end
end

it "handles only permitted number of redirects before throwing error" do
rget "/redirect/3", maximum_redirects: 3 do |resp|
#puts resp.env.config
resp.env.request.uri.path.should eq "/get"
resp.body_io.skip_to_end
end
expect_raises(NGHTTP::TooManyRedirectionsError) do
rget "/redirect/2", maximum_redirects: 1 do |resp|
#puts resp.env.request.uri
resp.env.request.uri.path.should eq "/get"
resp.body_io.skip_to_end
end
end
end

it "raises when no redirects are allowed" do
expect_raises(NGHTTP::TooManyRedirectionsError) do
rget "/redirect/1", maximum_redirects: 0 do |resp|
#puts "xxx"
#puts resp.env.request.uri
resp.env.request.uri.path.should eq "/get"
resp.body_io.skip_to_end
end
end
end

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
t=resp.body_io.gets_to_end
t.index('\u2200').should_not eq nil
end
end

it "handles read timeouts and clears underlying connections propperly" do
3.times do
expect_raises(Exception) do
STDOUT.puts "/5"
rget "/delay/5", read_timeout: 1 do |resp|
end
end
end
STDOUT.puts "/1"
rget "/delay/1", read_timeout: 3 do | resp|
resp.should_not be nil
end
end

it "handles content ranges" do
rget "/range/1024" do |resp|
resp.body.size.should eq 1024
end
rget "/range/1024", offset: 2 do |resp|
resp.body.size.should eq 1022
end
rget "/range/1024", offset: "4" do |resp|
resp.body.size.should eq 1020
end
rget "/range/1024", offset: 5..9 do |resp|
resp.body.size.should eq 5
resp.body.should eq "fghij"
end
rget "/range/1024", offset: 0...5 do |resp|
resp.body.size.should eq 5
resp.body.should eq "abcde"
end

end

#  it "works" do
#    false.should eq(true)
#  end
end
