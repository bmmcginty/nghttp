require "./handlers/*"

module NGHTTP
class Handlers
@@default=[
Redirector,
Cookiejar,
BasicAuthorization,
ContentRange,
ContentEncoding,
ContentLength,
TransferEncoding,
Cache,
HTTPConnecter]
def self.default
@@default
end

end #class
end #module

