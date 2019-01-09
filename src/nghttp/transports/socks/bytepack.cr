class IO
  private def spec_to_class(c)
    case c
    when 'b'
      Int8
    when 'B'
      UInt8
    when 'h'
      Int16
    when 'H'
      UInt16
    when 'i'
      Int32
    when 'I'
      UInt32
    when 'l'
      Int64
    when 'L'
      UInt64
    else
      nil
    end
  end

  def unpack(spec)
    out = [] of Int8 | UInt8 | Int16 | UInt16 | Int32 | UInt32 | Int64 | UInt64 | Char | String | Bool
    endian = IO::ByteFormat::LittleEndian
    repeat_count = nil
    spec.each_char do |c|
      if c == '<'
        endian = IO::ByteFormat::LittleEndian
        repeat_count = nil
        next
      end
      if c == '>'
        endian = IO::ByteFormat::BigEndian
        repeat_count = nil
        next
      end
      if c.number?
        repeat_count = repeat_count ? (repeat_count.to_s + c.to_s).to_i : (c.to_s).to_i
        next
      end
      if c == 's'
        raise Exception.new("Didn't provide length prefix for format s, which provides a non-zero terminated string") unless repeat_count
        out << String.build do |sb|
          repeat_count.times do |tc|
            t = self.read_char
            raise Exception.new("truncated input when reading format s") unless t
            sb << t.not_nil!
          end # times
        end   # builder
        repeat_count = nil
        next
      end
      rc = (repeat_count ? repeat_count : 1)
      rc.times do
        if c == 'c'
          out << UInt8.from_io(self, endian).unsafe_chr
        elsif c == 'z'
          out << String.build do |sb|
            while 1
              t = self.read_char
              break unless t
              break if t.ord == 0
              sb << t.not_nil!
            end # while
          end   # builder
        elsif c == 'p'
          t = Bytes.new(size: UInt8.from_io(self, endian))
          read_fully t
          out << String.new t
          t = nil
        elsif cls = spec_to_class c
          out << cls.from_io(self, endian)
        else
          raise Exception.new("Invalid char #{c} for unpacking")
        end # cls
      end   # times
      repeat_count = nil
    end # each
    out
  end # def

  def pack(spec, *a)
    idx = -1
    endian = IO::ByteFormat::LittleEndian
    repeat_count = nil
    cidx = -1
    spec.each_char do |c|
      cidx += 1
      if c == '<'
        endian = IO::ByteFormat::LittleEndian
        repeat_count = nil
        next
      end
      if c == '>'
        endian = IO::ByteFormat::BigEndian
        repeat_count = nil
        next
      end
      if c.number?
        repeat_count = repeat_count ? (repeat_count.to_s + c.to_s).to_i : (c.to_s).to_i
        next
      end
      if c == 's'
        idx += 1
        value = a[idx]
        if value.is_a?(String)
          raise Exception.new("Didn't provide length prefix for format s, which provides a non-zero terminated string") unless repeat_count
          write value.as(String).to_slice[0, repeat_count]
          repeat_count = nil
          next
        else
          raise Exception.new("Non-string provided for format s")
        end
      end
      rc = (repeat_count ? repeat_count : 1)
      rc.times do
        idx += 1
        value = a[idx]
        if value.is_a?(Enum)
          value = value.value
        end
        if c == 'z' && value.is_a?(String)
          write value.as(String).to_slice
          write_byte 0_u8
        elsif c == 'p' && value.is_a?(String)
          write_byte value.size.to_u8
          write value.as(String).to_slice
        elsif c == '?'
          (value ? 1_u8 : 0_u8).to_io self, endian
        elsif c == 'c' && value.is_a?(Char)
          value.ord.to_u8.to_io(self, endian)
        elsif cls = spec_to_class c
          # if value.class==cls
          # value.to_io(self,endian)
          # else
          cls.new(value.as(Int)).to_io(self, endian)
          # end
        else
          raise Exception.new("Invalid char #{c} for packing #{value}")
        end # if cls
      end   # times
      repeat_count = nil
    end # each_char
  end   # def

end # class

{% if 1 == 0 %}
require "spec"
it "handles packing and unpacking" do
m=IO::Memory.new
sp="<bBhHiIlL4c5s2z"
args={1,2,3,4,5,6,7,8,'a','b','c','d',"abcde","fghij","klmno"}
t=sp+">"+sp[1..-1]
m.pack(t,*args,*args)
m.seek 0
ret = m.unpack(t)
puts args, ret
ret.each_with_index do |i,idx|
#puts idx
(args+args)[idx].should eq i
end
end
{% end %}
