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

  def self.copy(src, dst, *, size : Int)
    sl = Bytes.new size
    total = 0_i64
    while (in = src.read sl) > 0
      dst.write sl[0, in]
      total += in
    end
    total
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
