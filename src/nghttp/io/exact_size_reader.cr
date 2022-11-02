class ExactSizeReader < IO
  @io : IO
  @pos = 0_i64
  @total = 0_i64

  def initialize(@io, @total)
  end

  def read(slice : Slice)
    return 0_i64 if @pos >= @total
    # STDOUT.puts "reading from #{@pos}"
    t = @io.read slice
    # STDOUT.puts "read #{t} bytes"
    @pos += t
    # STDOUT.puts "@pos now #{@pos}"
    t
  end

  def close
    @io.close
  end

  def write(slice : Slice) : Nil
    raise Exception.new("not writeable")
  end

  def to_s(sio)
    sio.puts "ExactSizeReader@#{hash} <#{@io.inspect}>"
  end
end
