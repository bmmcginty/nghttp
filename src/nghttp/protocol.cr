module NGHTTP
  abstract class Protocol
    abstract def name : String
    abstract def uses_host_header? : Bool
    abstract def uses_connection_header? : Bool
    abstract def uses_transfer_encoding? : Bool
    abstract def handle_request(env, full_url = false)
    abstract def handle_response(env : HTTPEnv)
    abstract def request_to_http_io(env, full_url = false, io = nil)
    abstract def http_io_to_response(env : HTTPEnv, io = nil)
  end
end
