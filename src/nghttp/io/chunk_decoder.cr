module NGHTTP
class ChunkDecoder < IO
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

def close
@io.close
end

end #class
end #module

