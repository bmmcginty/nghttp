module NGHTTP
module Handler
alias Proc = (HTTPEnv->)
property next : Handler|Proc|Nil = nil
property previous : Handler|Proc|Nil = nil
abstract def call(env : HTTPEnv)

def self.new
raise Exception.new("can't initialize #{self} from handler module")
end

def handle_transport(env : HTTPEnv)
raise Exception.new("handler #{self} has been called as a transport but it has no handle_transport method")
end

def call_next(env : HTTPEnv)
st=Time.now
name=nil
if env.request?
next_handler=@next
name=next_handler.class.to_s
if next_handler
next_handler.call env
end
elsif env.response?
previous_handler=@previous
name=previous_handler.class.to_s
if previous_handler
previous_handler.call env
end
else
raise Exception.new("Env #{env} is neither in request or response state")
end #else
et=Time.now
#puts "#{et-st}:#{name}"
end #def

end #class
end #module

