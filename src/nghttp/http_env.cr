require "./handler.cr"
require "./transport.cr"

module NGHTTP
  class HTTPEnv
    alias FilesValuesType = IO | String | Tuple(String, IO) | Tuple(String, IO, String) | Tuple(String, IO, String, HTTP::Headers)
    alias FilesType = Hash(String, FilesValuesType) | Array(Tuple(String, FilesValuesType))
    alias ConfigValuesType = String | Int32 | Float64 | Bool | Nil | Time::Span | Array(String) | Range(Int32, Int32) | Range(Int64, Int64) | Handler | HTTP::Headers | Transport | URI | Proc(String, String) | OpenSSL::SSL::Context::Client | Hash(String, String) | FilesType | IO
    alias ConfigType = Hash(String, ConfigValuesType)
    # Hash(String,String|Int32|Float64|Bool|Nil|Handler)
    enum State
      None
      Request
      Response
      Closed
    end

    property state : State = State::None
    property session : Session? = nil
    property connection : Transport? = nil
    property config = ConfigType.new
    property int_config = ConfigType.new
    property request = Request.new
    property response = Response.new

    getter! :session

    getter! :connection

    def connection?
      @connection
    end

    def request?
      @state == State::Request
    end

    def response?
      @state == State::Response
    end

    def close(force_close_connection = false)
      # puts "close force=#{force_close_connection}"
      config["no_save_cache"] = true if force_close_connection
      @state = State::Closed
      err = nil
      begin
        response.body_io.close if response.body_io?
      rescue e
        err = e
      end
      conn = @connection
      if conn
        if force_close_connection
          begin
            conn.close ignore_errors: true
          rescue e
            err = e
          end
        end
        conn.release
        conn = @connection = nil
      end
      raise err if err
    end

    def to_s(io : IO)
      io << to_s
    end

    def to_s
      "HTTPEnv #{state}@#{request.uri.to_s}"
    end

    def config
      @config
      # Wrapper.new @config
    end
  end # class

  class Wrapper
    @cls : HTTPEnv::ConfigType

    def initialize(@cls)
    end

    def fetch(key, value)
      @cls.fetch(key, value)
    end

    def []=(key, value)
      @cls[key] = value
    end

    def merge!(v)
      @cls.merge! v
    end

    def merge!(v : Wrapper)
      @cls.merge! v.cls
    end

    def cls
      @cls
    end

    def []?(key)
      @cls[key]?
    end

    def has_key?(key)
      @cls.has_key?(key)
    end

    def keys
      @cls.keys
    end
  end # class

end # module
