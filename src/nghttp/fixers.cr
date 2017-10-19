class Scheduler
def self.event_base
@@eb
end
end

struct HTTP::Headers
def []=(key, value : Nil)
@hash.delete key
end
end

class HTTP::Cookie
@from_host : String? = nil

property :from_host

end

class Hash(K,V)
def merge!(t : NamedTuple)
t.each do |k,v|
self[k.to_s]=v
end
end
end 

