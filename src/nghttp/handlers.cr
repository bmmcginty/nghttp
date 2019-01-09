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
      BodyPreparer,
      Cache,
      HTTPConnecter,
      BodySender,
      Toggler,
    ]

    def self.default
      @@default
    end
  end # class
end   # module
