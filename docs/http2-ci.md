# HTTP/2 spec CI guidance

The normal CI path should run the full spec suite without relying on public network services:

```sh
shards install
crystal spec --error-trace
```

That command starts local support servers for HTTP/1.1 httpbin-compatible behavior, keep-alive checks, h2c, and TLS ALPN HTTP/2. The external HTTP/2 interoperability spec remains pending unless `NGHTTP_SPEC_EXTERNAL_HTTP2_URL` is set, so the default suite is suitable for pull requests and offline development.

Run the external interoperability check as a separate opt-in job:

```sh
NGHTTP_SPEC_EXTERNAL_HTTP2_URL=https://nghttp2.org/httpbin \
  crystal spec spec/nghttp_http2_protocol_spec.cr --error-trace
```

Keeping the external check separate avoids making every CI run depend on a public service, while still giving maintainers a way to catch behavior differences against an independent HTTP/2 server. A good CI policy is to run the default suite on every push and pull request, then run the external job on a schedule, before release, or as a manually triggered workflow.

If a CI provider supports job-level retries, apply them only to the external job. Failures in the local suite should be treated as deterministic regressions; failures in the external job may also indicate service downtime, network policy, TLS trust changes, or remote endpoint changes.
