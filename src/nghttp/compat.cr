require "http"

struct Time
  def self.epoch(ms : Float64)
    unix (ms*1000).to_i64
  end

  def self.epoch(ms)
    unix ms
  end

  def self.epoch
    unix
  end

  def epoch
    to_unix
  end
end

class Tempfile < File
  def unlink
    delete
  end
end

class HTTP::Server
  def self.new(host : String, port : Int32, handlers)
    t = new handlers
    t.bind_tcp(host, port)
    t
  end
end

struct File::Info
  def mtime
    modification_time
  end

  def ctime
    creation_time
  end
end

class File < IO::FileDescriptor
  alias Stat = Info

  def self.lstat(path)
    info(path, false)
  end

  def self.stat(path)
    info(path)
  end
end
