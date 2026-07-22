require "./spec_helper"

describe NGHTTP::TransparentIO do
  it "wraps generic IO bodies" do
    io = NGHTTP::TransparentIO.new(IO::Memory.new("hello"))

    io.gets_to_end.should eq "hello"
  end

  it "runs read callbacks for generic IO bodies" do
    io = NGHTTP::TransparentIO.new(IO::Memory.new("hello"))
    observed = 0
    io.on_read do |_slice, size|
      observed += size
    end

    io.gets_to_end.should eq "hello"
    observed.should eq 5
  end

  it "delegates peek when wrapped IO can peek" do
    io = NGHTTP::TransparentIO.new(IO::Memory.new("hello"))

    io.peek.should_not be_nil
  end

  it "returns nil from peek when wrapped IO cannot peek" do
    io = NGHTTP::TransparentIO.new(ExactSizeReader.new(IO::Memory.new("hello"), 5))

    io.peek.should be_nil
  end

  it "raises clearly when wait_readable is unavailable" do
    io = NGHTTP::TransparentIO.new(IO::Memory.new("hello"))

    expect_raises(IO::Error, /wait_readable/) do
      io.wait_readable(1.second)
    end
  end
end
