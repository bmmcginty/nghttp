module NGHTTP
class HTTPEnv
alias ConfigType = Hash(String,String|Int32|Float64|Bool|Nil)
enum State
None
Request
Response
Closed
end

property state : State = State::None
property session : Session? = nil
property connection : Connection? = nil
property config = ConfigType.new
property int_config = Hash(String,String|Int32|Float64|Bool|Handler).new
property request = Request.new
property response = Response.new

getter! :session,:connection

def request?
@state==State::Request
end

def response?
@state == State::Response
end

def close
state=State::Closed
response.body_io.close
connection.release if @connection
@connection=nil
@session=nil
end

def to_s(io : IO)
io << to_s
end

def to_s
"HTTPEnv #{state}@#{request.uri.to_s}"
end

end #class
end #module

