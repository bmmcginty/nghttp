module NGHTTP
  module Handler
    # alias Proc = (HTTPEnv->)
    # |Proc
    property next : Handler | Nil = nil
    property previous : Handler | Nil = nil

    abstract def call(env : HTTPEnv)

    @before_me : Array(String)? = nil
    @after_me : Array(String)? = nil

    def verify_requirements
      return
      if need = @after_me
        target = self
        have = [] of String
        while 1
          n = target.next
          break unless n
          have << n.class.name.split("::")[-1]
          target = n
        end
        missing = need - have
        if missing.size > 0
          raise Exception.new("Handler #{self.class.name} requires #{missing} to be run after it")
        end
      end # after
      if need = @before_me
        target = self
        have = [] of String
        while 1
          n = target.previous
          break unless n
          have << n.class.name.split("::")[-1]
          target = n
        end
        missing = need - have
        if missing.size > 0
          raise Exception.new("Handler #{self.class.name} requires #{missing} to be run before it")
        end
      end # after
      if n = @next
        n.verify_requirements
      end
      if p = @previous
        p.verify_requirements
      end
    end

    def self.new
      raise Exception.new("can't initialize #{self} from handler module")
    end

    def handle_transport(env : HTTPEnv)
      raise Exception.new("handler #{self} has been called as a transport but it has no handle_transport method")
    end

    def call_next(env : HTTPEnv)
      name = nil
handler=nil
status=nil
      if env.request?
        handler = @next
status="req"
elsif env.response?
handler=@previous
status="resp"
else
status=nil
        raise Exception.new("Env #{env} is neither in request or response state")
end
        name = handler.class.to_s
st=Time.monotonic
if handler
handler.call(env)
end
      et = Time.monotonic
#puts "#{(et-st).total_seconds}, #{name}, #{status}"
    end # def

  end # class
end   # module
