module NGHTTP
abstract class Extension
macro inherited
Client::Config=Client::Config|{{@type}}::Config
end

@client : Client

getter client

def initialize(@client)
end

abstract def setup(**kw)

end #class

end #module


