require "./handlers/*"

module NGHTTP
class Handlers
@@default=[Redirector,Cookiejar,ContentEncoding,ContentLength,TransferEncoding,Cache,HTTPConnecter]
def self.default
@@default
end

end #class
end #module

