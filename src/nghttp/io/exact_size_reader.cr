class ExactSizeReader < IO
@io : IO
@pos=0_i64
@total=0_i64

def initialize(@io, @total)
end

def read(s : Slice)
return 0_i64 if @pos>=@total
#STDOUT.puts "reading from #{@pos}"
t=@io.read s
#STDOUT.puts "read #{t} bytes"
@pos+=t
#STDOUT.puts "@pos now #{@pos}"
t
end

def write(s : Slice)
raise Exception.new("not writeable")
end

end

