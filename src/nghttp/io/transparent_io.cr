module NGHTTP
class TransparentIO < IO
alias Writer = (Bytes->)
alias Reader = (Bytes,Int32|Int64->)
alias Closer = (->)
@on_write : Writer?
@on_read : Reader?
@on_close : Closer?
@io : IO
property io
@close_underlying_io : Bool

def on_read=(v : Nil)
@on_read=v
end
def on_write=(v : Nil)
@on_write=v
end
def on_close=(v : Nil)
@on_close=v
end
def on_read(&b : (Bytes,Int32|Int64->))
@on_read=b
end
def on_write(&b : (Bytes->))
@on_write=b
end
def on_close(&b : Closer)
@on_close = b
end

def read(slice : Bytes)
unless @io
raise Errors::DanglingTransparentIO.new
end
size=@io.not_nil!.read slice
if @on_read
@on_read.not_nil!.call(slice,size)
end
size
end

def write(slice : Bytes)
unless @io
raise Errors::DanglingTransparentIO.new
end
@io.not_nil!.write slice
if @on_write
@on_write.not_nil!.call(slice)
end
end

def close
unless @io
raise Errors::DanglingTransparentIO.new
end
if @close_underlying_io == true
@io.not_nil!.close
end
if @on_close
@on_close.not_nil!.call
end
end

def flush
unless @io
raise Errors::DanglingTransparentIO.new
end
@io.not_nil!.flush
end

def initialize(@io, @close_underlying_io = true)
end

end

end #module

