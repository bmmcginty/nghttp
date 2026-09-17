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

### DNS overrides

Use `dns_override` to connect selected origin hostnames to literal IP addresses without changing the request hostname, TLS SNI, or certificate hostname:

```crystal
s.config.dns_override = {
  "example.org" => "127.0.0.1",
}
```

Overrides apply to direct, SOCKS, and HTTP CONNECT connections. They are not supported for plain HTTP requests through a forward HTTP proxy because that proxy controls origin DNS resolution.

## Testing

The spec suite starts a local Python httpbin process by default.
Set `NGHTTP_SPEC_HTTPBIN_URL` to use an already-running httpbin server instead.
Set `NGHTTP_SPEC_KEEP_ALIVE_URL` to use an already-running keep-alive test server.
HTTP/2 specs use local h2c and TLS ALPN servers by default.
Set `NGHTTP_SPEC_EXTERNAL_HTTP2_URL` to run the opt-in external HTTP/2 interoperability spec.

See `spec/nghttp_spec.cr`, `spec/nghttp_http2_protocol_spec.cr`, and `docs/http2-ci.md`.

## Development

Most code can be found in the handlers directory.

## TODO

- Define replayable vs one-shot request bodies so automatic retries can avoid resending non-rewindable upload streams.
- Add specs for retry behavior with `String`, `IO::Memory`, `File`, custom rewindable IO, and non-rewindable streaming IO request bodies.
- Add a body factory API for large replayable uploads, such as reopening a file per attempt instead of keeping one mutable IO object.
- Make HTTP/2 upload streaming stop promptly when the stream receives an early error such as `REFUSED_STREAM`.

## Contributing

1. Fork it ( https://github.com/bmmcginty/nghttp/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [bmmcginty](https://github.com/bmmcginty) Brandon McGinty - creator, maintainer
