module NGHTTP::Errors
class Unwriteable < Exception
def initialize(name)
@message="By design, you can't write to #{name}"
end #def
end #class

class Unreadable < Exception
def initialize(name)
@message="By design, you can't read from #{name}"
end #def
end #class

class DanglingTransparentIO < Exception
def initialize
@message="This TransparentIO does not have an IO attached to the other end"
end #def
end #class

end #module

require "./io/*"

