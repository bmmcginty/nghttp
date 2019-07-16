class HTTP::Cookie
@from_host : String? = ""
property from_host

macro genjson
def self.new(json : JSON::PullParser)
t_name=nil
t_value=nil
t_from_host=nil
t_expires=nil
t_path=nil
t_max_age=nil
t_domain=nil
t_secure=nil
t_http_only=nil
t_extension=nil
t_creation_time=nil
{% for name in %w(from_host name value path expires max_age domain secure http_only extension creation_time) %}
t_{{name.id}}=nil
{% end %}
json.read_object do |key|
{% for name,idx in %w(from_host name value path expires max_age domain secure http_only extension creation_time) %}
{% types = %w(String? String String String Time? Time::Span? String? Bool Bool String? Time) %}
if key=={{name.id.stringify}}
t_{{name.id}}={{types[idx].id}}.new(json)
end #if key
{% end %} #each field
end #read object
t=new name: t_name.not_nil!, value: t_value.not_nil!, path: t_path.not_nil!, expires: t_expires, max_age: t_max_age, domain: t_domain, secure: t_secure.not_nil!, http_only: t_http_only.not_nil!, extension: t_extension
t.creation_time=t_creation_time.not_nil!
t.name=t_name.not_nil!
t.value=t_value.not_nil!
t
end

def to_json(json : JSON::Builder)
json.object do
{% for name,idx in %w(from_host name value path expires max_age domain secure http_only extension creation_time) %}
{% types = %w(String? String String String Time? Time::Span? String? Bool Bool String? Time) %}
v=@{{name.id}}
json.field {{name.id.stringify}} do
v.to_json json
end
{% end %} #each field
end #object
end #def

end

genjson
end #class

struct Time::Span
def to_json(json : JSON::Builder)
json.array do
@seconds.to_json json
@nanoseconds.to_json json
end
end

def initialize(json : JSON::PullParser)
json.read_begin_array
@seconds=json.read_int
@nanoseconds=json.read_int.to_i
json.read_end_array
end #def
end #struct


struct JSON::Any
  def []?(key : Int) : JSON::Any?
    t = previous_def
    (t && t.raw) ? t : nil
  end

  def []?(key : String) : JSON::Any?
    t = previous_def
    (t && t.raw) ? t : nil
  end

  def each
    case object = @raw
    when Array
      object.each do |i|
        yield i
      end
    when Hash
      object.each do |k, v|
        yield Any.new(k), v
      end
    end # case
  end   # def
end     # struct

class IO
  def wait_readable?(t)
    wait_readable(t)
  end

  def wait_readable?
    wait_readable
  end

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

class Hash(K, V)
  def merge!(t : NamedTuple)
    t.each do |k, v|
      self[k.to_s] = v
    end
  end
end

require "uri"

struct XML::Node
  def parents
    t = [] of self
    p = self
    while p = p.parent
      t << p
    end
    t
  end

  def iter
    xpath_nodes(".//*|.//text()").each do |i|
      yield i
    end
  end

  def all_text
    if self.text?
      self.text
    else
      txt = String.build do |sb|
        iter do |child|
          if child.text?
            sb << child.text
          elsif child.element?
            case child.name.downcase
            when "br"
              sb << "\n"
            when "p"
              sb << "\n\n"
            end # case
          end   # if element or text
        end     # each child
      end       # builder
      txt
    end # not text
  end   # def

  def make_links_absolute(base : String)
    bu = URI.parse base
    ["href", "src", "action"].each do |attrname|
      xpath_nodes(".//*[@#{attrname}]").each do |i|
        if i[attrname].starts_with?("//")
          i[attrname] = bu.scheme.not_nil! + ":" + i[attrname]
        elsif i[attrname] =~ /^[a-z]+:/
          # don't modify links that already have protocols and thus aren't relative
        else
          i[attrname] = URI.parse(i[attrname]).normalize(bu).to_s
        end # if
      end   # each
    end     # each attrname
  end       # def
end         # class

class URI
  def self.normalize(url : String, base : String)
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
      @scheme = base.scheme
    end
    unless @host
      @host = base.host
    end
    unless @path
      @path = base.path.to_s
    end
    unless @path.not_nil!.starts_with?("/")
      bp = base.path ? base.path : ""
      @path = bp.not_nil!.reverse.split("/", 2)[1].reverse + "/" + @path.not_nil!
    end
    normalize!
    self
  end
end
