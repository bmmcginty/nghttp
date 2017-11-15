class IO
def readable?
wait_readable
end
end

class Scheduler
def self.event_base
@@eb
end
end

struct HTTP::Headers
def []=(key, value : Nil)
@hash.delete key
end
end

class Hash(K,V)
def merge!(t : NamedTuple)
t.each do |k,v|
self[k.to_s]=v
end
end
end 

require "uri"
struct XML::Node
def make_links_absolute(base : String)
bu=URI.parse base
["href","src"].each do |attrname|
xpath_nodes(".//*[@#{attrname}]").each do |i|
if i[attrname].starts_with?("//")
i[attrname]=bu.scheme.not_nil!+":"+i[attrname]
elsif i[attrname] =~ /^[a-z]+:/
#don't modify links that already have protocols and thus aren't relative
else
i[attrname]=URI.parse(i[attrname]).normalize(bu).to_s
end #if
end #each
end #each attrname
end #def
end #class

class URI
def self.normalize(url : String,base : String)
parse(url).normalize(base).to_s
end
def normalize(base : String)
normalize(URI.parse(base))
end
def normalize(base : URI)
dup.normalize! base
end
def normalize!(base : URI)
relative = @host ? true : false
unless @scheme
@scheme=base.scheme
end
unless @host
@host=base.host
end
unless @path
@path=base.path.to_s
end
unless @path.not_nil!.starts_with?("/")
bp = base.path ? base.path : ""
@path=bp.not_nil!.reverse.split("/",2)[1].reverse+"/"+@path.not_nil!
end
normalize!
self
end
end

