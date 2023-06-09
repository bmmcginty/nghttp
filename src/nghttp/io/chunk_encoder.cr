module NGHTTP
  class ChunkEncoder < IO
    @io : IO
    @plain_size : Int32 | Int64 = 0

    macro reset
@eof = false
@plain_buffer = Bytes.new(16384)
@plain = Bytes.empty
@plain_size = 0
@encoded_buffer = Bytes.new(16384+8)
@encoded = Bytes.empty
@encoded_remaining = 0
end

    reset

    def rewind
      @io.rewind
      reset
    end

    private def fill_buffer
      # p "fill_buffer"
      @plain_size = @io.read @plain_buffer
      @plain = @plain_buffer + 0
      # p "read #{@plain_size} bytes"
    end

    private def transform
      # p "transform"
      fill_buffer if @encoded_remaining <= 0
      amount_to_encode = Math.min(@plain_size, @encoded_buffer.size)
      hdr = "#{amount_to_encode.to_s(16)}\r\n".to_slice
      data = @plain_buffer[0, amount_to_encode]
      ftr = "\r\n".to_slice
      total_size = hdr.size + data.size + ftr.size
      encoded = @encoded_buffer
      encoded.copy_from hdr
      encoded += hdr.size
      encoded.copy_from data
      encoded += data.size
      encoded.copy_from ftr
      encoded += ftr.size
      @encoded_remaining = total_size
      @encoded = @encoded_buffer[0, total_size]
      # p "#{total_size} to read"
    end

    def initialize(@io)
    end

    def read(slice : Slice)
      return 0 if @eof
      if @encoded_remaining <= 0
        transform
      end
      amount_to_write = Math.min(@encoded_remaining, slice.size)
      slice.copy_from(@encoded[0, amount_to_write])
      @encoded += amount_to_write
      @encoded_remaining -= amount_to_write
      if @encoded_remaining == 0 && @plain_size == 0
        @eof = true
      end
      amount_to_write
    end

    def write(slice : Slice) : Nil
      raise Errors::Unwriteable.new(self.class.name)
    end

    def close
      @io.close
    end
  end # class
end   # module
