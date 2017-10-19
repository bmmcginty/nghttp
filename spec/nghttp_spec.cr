require "./spec_helper"
require "json"

class C
@@c=NGHTTP::Session.new max_redirects: 3, wait: nil
def self.c
@@c
end
end

{% for method in %w(get post put delete) %}
def j{{method.id}}(url, **kw)
u="http://httpbin.apps.bmcginty.us/#{url}"
C.c.{{method.id}}(u,**kw) do |resp|
yield JSON.parse resp.body_io
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
#puts j
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

#  it "works" do
#    false.should eq(true)
#  end
end
