class SizedReader < IO::Sized
  def write(slice : Bytes) : Nil
    raise NGHTTP::Errors::Unwriteable.new(self.class.name)
  end
end
