class ExactSizeReader < IO
  @io : IO
  @pos = 0_i64
  @total = 0_i64

  def initialize(@io, @total)
  end

  def read(slice : Slice)
    return 0 if @pos >= @total
    t = @io.read slice
    @pos += t
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
