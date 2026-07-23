require "openssl"

class OpenSSL::SSL::Context::Client
  def alpn_protocols=(protocols : Array(String)) : Nil
    proto = IO::Memory.new
    protocols.each do |protocol|
      raise ArgumentError.new("ALPN protocol identifier is too long") if protocol.bytesize > UInt8::MAX
      proto.write_byte(protocol.bytesize.to_u8)
      proto << protocol
    end
    self.alpn_protocol = proto.to_slice
  end
end
