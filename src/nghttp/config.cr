require "./types"

class NGHTTP::Config
macro hk(t)
def {{t.var}}=(v : {{t.type}})
@cfg[{{t.var.stringify}}]=v
end
def {{t.var}} : {{t.type}}
@cfg[{{t.var.stringify}}].as({{t.type}})
end
def {{t.var}}? : {{t.type}}?
@cfg[{{t.var.stringify}}]?.as({{t.type}}?)
end
end

@cfg = Types::ConfigType.new

def _cfg
@cfg
end

def has_key?(k)
@cfg.has_key?(k)
end

def merge!(x : Config)
@cfg.merge! x._cfg
end

def merge!(x)
@cfg.merge!(x)
end

def []?(k)
@cfg[k]?
end

def []=(k,v)
@cfg[k]=v
end

def [](k)
@cfg[k]
end

def fetch(k)
@cf.fetch(k)
end

def fetch(k,default)
@cfg.fetch(k,default)
end

end # class
