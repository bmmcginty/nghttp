require "./handler"
require "./transport"

module NGHTTP
  class Types
    alias FilesValuesType = IO | String | Tuple(String, IO) | Tuple(String, IO, String) | Tuple(String, IO, String, HTTP::Headers)
    alias FilesType = Hash(String, FilesValuesType) | Array(Tuple(String, FilesValuesType))
    alias ConfigValuesType = String | Int32 | Float64 | Bool | Nil | Time::Span | Array(String) | Range(Int32, Int32) | Range(Int64, Int64) | Handler | HTTP::Headers | Transport | URI | Proc(String, String?) | Proc(String, String) | OpenSSL::SSL::Context::Client | Hash(String, String) | FilesType | IO | Array(Int32) | Proc(OpenSSL::SSL::Context::Client)
    alias ConfigType = Hash(String, ConfigValuesType)
  end
end
