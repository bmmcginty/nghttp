module NGHTTP

class SizedReader < IO::Sized
def write(slice : Bytes)
raise Errors::Unwriteable.new(self.class.name)
end
end

class ChunkWriter
include IO
@chunk_size = 0
@chunk_remaining = 0
@need_chunk = true
@io : IO
def initialize(@io)
end

def write(slice : Bytes)
total = slice.size
start=0
left=total
while left > 0
#STDOUT.puts "left:#{left}"
cs = left > 4096 ? 4096 : left
@io << cs.to_s(16)
@io << "\r\n"
#STDOUT.puts "start:#{start},cs:#{cs},total:#{total}"
@io.write slice[start,cs]
@io << "\r\n"
start+=cs
left-=cs
end
#STDOUT.puts "done"
end #def

def close
@io << "0\r\n\r\n"
end

def read(slice : Bytes)
raise Errors::Unreadable.new(self.class.name)
end

end #class

class ChunkReader
include IO
@chunk_size = 0
@chunk_remaining = 0
@need_chunk = true
@io : IO
@eof=false

def initialize(@io)
end

def write(slice : Bytes)
raise Errors::Unwriteable.new(self.class.name)
end

def get_chunk_size
ts=""
z='\n'+ -10
while 1
t=@io.read_byte.not_nil!
break if t=='\n'.ord
if t>32
ts += (z+t)
#Char.new(t)
end
end
ts.to_i 16
end

def read(slice : Bytes)
return 0 if @eof
total=0
while 1
#STDOUT.puts "total:#{total},slice.size:#{slice.size},need_chunk:#{@need_chunk}"
break if total >= slice.size
if @need_chunk
#STDOUT.puts "getting chunk size"
@chunk_size=@chunk_remaining=get_chunk_size
#STDOUT.puts @chunk_size
@need_chunk=false
end
size = Math.min(@chunk_remaining,slice.size-total)
#STDOUT.puts "size:#{size}"
if size > 0
#STDOUT.puts "reading:#{total},#{size}"
size=@io.read(slice[total,size])
#STDOUT.puts "actually read:#{tt}"
end
total+=size
@chunk_remaining-=size
#STDOUT.puts "chunk_remaining:#{@chunk_remaining}"
if @chunk_remaining==0
2.times do
@io.read_byte
end
@need_chunk=true if @chunk_size > 0
end
if @chunk_size==0
@eof=true
break
end
end
#STDOUT.puts "read #{total}"
total
end #def

end #class

class TransparentIO
include IO
alias Writer = (Bytes->)
alias Reader = (Bytes,Int32|Int64->)
@on_write : Writer?
@on_read : Reader?
@io : IO?
@sync_close = false
property io

def on_read=(v : Nil)
@on_read=v
end
def on_write=(v : Nil)
@on_write=v
end
def on_read(&b : (Bytes,Int32|Int64->))
@on_read=b
end
def on_write(&b : (Bytes->))
@on_write=b
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
if @sync_close
#puts "tio:#{@io}:close"
@io.not_nil!.close
end
end

def flush
unless @io
raise Errors::DanglingTransparentIO.new
end
@io.not_nil!.flush
end

def initialize
end

def initialize(@io)
end

end

end #module

