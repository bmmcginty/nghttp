require "./spec_helper"

describe HTTP2::HPACK::Huffman do
  it "decodes valid Huffman strings whose symbols span byte boundaries" do
    value = "/cookies/set?kn1=kv1"
    encoded = HTTP2::HPACK.huffman.encode(value)

    HTTP2::HPACK.huffman.decode(encoded).should eq value
  end
end
