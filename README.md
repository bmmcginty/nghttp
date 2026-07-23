# nghttp

A client for HTTP goodness. Inspired by python-requests and daily need.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  nghttp:
    github: bmmcginty/nghttp
```

## Usage

```crystal
require "nghttp"
# Create a session.
# It can persist cookies and connections.
s=NGHTTP::Session.new
# Override the user-agent header.
s.headers["User-Agent"]="New User-Agent"
# Enable the cache.
s.config.cache=true
s.config.cache_expires=1.hours
body = s.get"https://example.org/") do |resp|
resp.xml
end
```

## Testing

The spec suite starts a local Python httpbin process by default.
Set `NGHTTP_SPEC_HTTPBIN_URL` to use an already-running httpbin server instead.
Set `NGHTTP_SPEC_KEEP_ALIVE_URL` to use an already-running keep-alive test server.
HTTP/2 specs use local h2c and TLS ALPN servers by default.
Set `NGHTTP_SPEC_EXTERNAL_HTTP2_URL` to run the opt-in external HTTP/2 interoperability spec.

See `spec/nghttp_spec.cr`, `spec/nghttp_http2_protocol_spec.cr`, and `docs/http2-ci.md`.

## Development

Most code can be found in the handlers directory.

## Contributing

1. Fork it ( https://github.com/bmmcginty/nghttp/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [bmmcginty](https://github.com/bmmcginty) Brandon McGinty - creator, maintainer
