require "http2"

class HTTP2::Connection
  def disable_huffman_encoding : Nil
    @hpack_encoder.default_huffman = false
  end

  private def read_rst_stream_frame(frame)
    raise Error.frame_size_error unless frame.size == RST_STREAM_FRAME_SIZE
    error_code = Error::Code.new(io.read_bytes(UInt32, IO::ByteFormat::BigEndian))
    frame.reset_error_code = error_code
    Log.trace { "  code=#{error_code}" }
  end
end

class HTTP2::Frame
  property reset_error_code : HTTP2::Error::Code?
end

class HTTP2::HPACK::Huffman
  def decode(bytes : Bytes)
    io = IO::Memory.new
    node = tree
    eos_padding = true
    padding_length = 0

    bytes.each do |byte|
      7.downto(0) do |i|
        padding_length += 1

        if byte.bit(i) == 1
          node = node.right
        else
          node = node.left
          eos_padding = false
        end

        raise HTTP2::HPACK::Error.new("node is nil!") unless node

        if value = node.value
          io.write_byte(value)
          node = tree
          eos_padding = true
          padding_length = 0
        end
      end
    end

    unless node == tree
      raise HTTP2::HPACK::Error.new("huffman string padding is larger than 7-bits") if padding_length > 7
      raise HTTP2::HPACK::Error.new("huffman string padding must use MSB of EOS symbol") unless eos_padding
    end

    io.to_s
  end
end
