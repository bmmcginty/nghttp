module NGHTTP
  class BodyPreparer
    include Handler
    @after_me = ["BodySender"]

    def initialize
    end

    def call(env : HTTPEnv)
      if env.request?
        handle_request env
      end
      call_next env
    end # def

    def handle_request(env)
      if env.config.has_key?("files")
        r1 = Random.rand(UInt64::MAX)
        r2 = Random.rand(UInt64::MAX)
        bnd = "-"*35 + "#{r1}#{r2}"
        env.int_config["formdata_boundary"] = bnd
        env.request.headers["Content-Type"] = %(multipart/form-data; boundary="#{bnd}")
      elsif env.request.body_io? && !env.request.headers["Content-Type"]?
        env.request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      end
    end
  end # class
end   # module
