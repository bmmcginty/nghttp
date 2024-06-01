require "./types"
require "./http_env"

class NGHTTP::Config
  @cfg = Hash(String, Bool |
                      Int32 |
IO |
                      Nil |
                      String |
                      Time::Span |
                      Transport |
                      Tuple(String, String) |
                      Range(Int32, Int32)).new

  # define typed setters and getters
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

  macro hk_nilable(t)
# allows for setting {{t.var}} to nil
# e.g. if we go 307>302>200
# post body must be explicitly removed after the 302 response
def {{t.var}}=(v : {{t.type}}?)
@cfg[{{t.var.stringify}}]=v
end
def {{t.var}} : {{t.type}}
@cfg[{{t.var.stringify}}].as({{t.type}})
end
def {{t.var}}? : {{t.type}}?
@cfg[{{t.var.stringify}}]?.as({{t.type}}?)
end
end

  def _cfg
    @cfg
  end

  def merge!(x : Config)
    @cfg.merge! x._cfg
  end

  hk verify : Bool
  hk tries : Int32
  hk max_redirects : Int32
  hk debug_connect : Bool
  hk debug_file : IO::FileDescriptor
  hk tls : OpenSSL::SSL::Context::Client
  hk wait : Time::Span
  hk cache : Bool
  hk cache_expires : Time::Span
  hk cache_key : String
  hk cache_statuses : Array(Int32)
  hk basic_auth : Tuple(String, String)
  hk offset : Range(Int32, Int32) | Int32
  hk proxy : String
  hk connections_per_host : Int32
  hk connect_timeout : Time::Span
  hk dns_timeout : Time::Span
  hk read_timeout : Time::Span
end # class
