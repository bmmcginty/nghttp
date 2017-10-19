class SizedReader < IO::Sized
def write(slice : Bytes)
raise NGHTTP::Errors::Unwriteable.new(self.class.name)
end
end


