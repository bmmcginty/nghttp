require "./handler.cr"
require "./transport.cr"
module NGHTTP
class HTTPEnv
alias ConfigValuesType = String|Int32|Float64|Bool|Nil|Array(String)|Range(Int32,Int32)|Range(Int64,Int64)|Handler|HTTP::Headers|Transport|URI|Proc(String,String)
alias ConfigType = Hash(String,ConfigValuesType)
#Hash(String,String|Int32|Float64|Bool|Nil|Handler)
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
@state==State::Request
end

def response?
@state == State::Response
end

def close(force_close_connection = false)
@state=State::Closed
response.body_io.close if response.body_io?
conn=@connection
if conn
if force_close_connection
conn.close
end
conn.release
conn=@connection=nil
end
end

def to_s(io : IO)
io << to_s
end

def to_s
"HTTPEnv #{state}@#{request.uri.to_s}"
end

end #class
end #module

