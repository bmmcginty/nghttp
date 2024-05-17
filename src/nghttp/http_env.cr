require "./handler.cr"
require "./transport.cr"
require "./types.cr"

module NGHTTP
  class HTTPEnv
    # Hash(String,String|Int32|Float64|Bool|Nil|Handler)
    enum State
      None
      Request
      Response
      Closed
    end

    @state : State = State::None
    @session : Session
    @connection : Transport? = nil
    @config = Config.new
    @int_config = IntConfig.new
    @request : Request? = nil
    @response : Response? = nil
    setter request, response, connection, state
    getter config, int_config, session, state

    # creates a new config, potentially fo ra sub-request
    def connection
      @connection.not_nil!
    end

    def request
      @request.not_nil!
    end

    def response
      @response.not_nil!
    end

    def initialize(@session)
    end

    def connection?
      @connection
    end

    def request?
      @state.request?
    end

    def response?
      @state.response?
    end

    def close(force_close_connection = false)
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
          end # rescue
        end   # if force
        conn.release
        conn = @connection = nil
      end # if con
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
    @cls : Types::ConfigType

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
