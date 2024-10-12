require "./handlers/*"

module NGHTTP
  class Handlers
    @@default = [
      Redirector,
      KeepAlive,
      Cookiejar,
      BasicAuthorization,
      ContentRange,
      ContentEncoding,
      ContentLength,
      TransferEncoding,
HostHeader,
      BodyPreparer,
CustomHeaders,
      Cache,
      Wait,
      HTTPConnecter,
      BodySender,
      Toggler,
    ]

    def self.default
      @@default
    end
  end # class
end   # module
