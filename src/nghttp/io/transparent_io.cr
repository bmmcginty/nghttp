module NGHTTP
  class TransparentIO < IO
    alias Writer = (Bytes ->)
    alias Reader = (Bytes, Int32 | Int64 ->)
    alias Closer = (->)
    @on_write : Writer?
    @on_read : Reader?
    @on_close : Closer?
    @io : TCPSocket|OpenSSL::SSL::Socket::Client |TransparentIO
    @close_underlying_io : Bool
    property io, close_underlying_io

def wait_readable(t)
@io.wait_readable t
end

    def to_s(io : IO)
      io << to_s
    end

    def to_s
      "TransparentIO #{@io}"
    end

    def on_read=(v : Nil)
      @on_read = v
    end

    def on_write=(v : Nil)
      @on_write = v
    end

    def on_close=(v : Nil)
      @on_close = v
    end

    def on_read(&b : (Bytes, Int32 | Int64 ->))
      @on_read = b
    end

    def on_write(&b : (Bytes ->))
      @on_write = b
    end

    def on_close(&b : Closer)
      @on_close = b
    end

    def debug_hex
      on_read do |slice, size|
        STDOUT << "r:#{slice[0, size].hexstring}\n"
      end
      on_write do |slice|
        STDOUT << "w:#{slice.hexstring}\n"
      end
    end

    def rewind
      @io.rewind
    end

    def read(slice : Bytes)
      size = @io.read slice
#      if @io.is_a? Compress::Gzip::Reader
        # STDOUT.write slice[0,size]
#      end
      if @on_read
        @on_read.not_nil!.call(slice, size)
      end
      size
    end

    def write(slice : Bytes) : Nil
      @io.write slice
      if @on_write
        @on_write.not_nil!.call(slice)
      end
    end

    def close
      if @close_underlying_io == true
        @io.close
      end
      if @on_close
        @on_close.not_nil!.call
      end
    end

    def flush
      @io.flush
    end

    def peek
      @io.peek
    end

    def initialize(@io, @close_underlying_io = true)
    end
  end
end # module
