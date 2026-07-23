# HTTP2 shard upstream patch branches

The local `http2-fork` directory contains branch-per-change patches prepared for upstream pull requests. These branches are intentionally local only; no pull request branches were pushed from this workspace.

## `fix-hpack-huffman-padding`

Commit: `6e45527 Fix HPACK Huffman padding validation`

Problem: the HPACK Huffman decoder rejected byte boundaries where a Huffman symbol had not completed yet. HPACK Huffman values are a bit stream, so symbols may cross byte boundaries; only the final padding bits at the end of the encoded string need validation.

When it came up: `nghttp` hit `COMPRESSION_ERROR` while reading a valid HTTP/2 response for paths such as `/cookies/set?kn1=kv1`. The response headers were valid, but the local shard decoder treated an in-progress symbol at an intermediate byte boundary as invalid padding.

Fix: the decoder now tracks pending bits after the most recently decoded symbol and validates only the final leftover bits. The branch includes decoder coverage for a valid Huffman string whose symbols span byte boundaries.

Verification: `make test` passed in `http2-fork`.

## `fix-headers-end-stream-body-close`

Commit: `d42202d Close stream data for HEADERS END_STREAM`

Problem: a `HEADERS` frame with `END_STREAM` completed the stream without closing the stream data buffer when no `DATA` frame had been seen. Consumers waiting for the response body could block forever even though the peer had already ended the stream.

When it came up: empty HTTP/2 responses, including `204`-style responses and other header-only responses, caused `nghttp` body reads to hang with the selected shard.

Fix: the frame reader now closes stream data when a `HEADERS` frame carries `END_STREAM`, even if the stream data object was not previously initialized by a `DATA` frame. The branch includes a raw frame fixture covering a header-only response.

Verification: `make test` passed in `http2-fork`.

## `expose-rst-stream-error-code`

Commit: `be1c84f Expose received RST_STREAM error codes`

Problem: the shard decoded and logged `RST_STREAM` error codes internally, but callers could not inspect the code from the returned frame. That made it impossible for a client to distinguish `REFUSED_STREAM` from other stream resets.

When it came up: `nghttp` needed to map HTTP/2 failure frames into library-level errors, especially so `REFUSED_STREAM` could be treated distinctly from other reset conditions.

Fix: `HTTP2::Frame` now carries an optional decoded reset error code populated by `read_rst_stream_frame`. The branch includes a connection test that opens a stream, receives `RST_STREAM`, and asserts the decoded `REFUSED_STREAM` code is exposed.

Verification: `make test` passed in `http2-fork`.

## `fix-max-concurrent-stream-counting`

Commit: `e69ddfa Fix max concurrent stream counting`

Problem: max-concurrent-stream enforcement counted the connection control stream and used a fixed stream parity model. On a client connection with `SETTINGS_MAX_CONCURRENT_STREAMS = 1`, that could reject even the first valid outbound request stream.

When it came up: `nghttp` added stream leasing and needed to honor peer concurrency limits without incorrectly blocking the first request or counting stream `0` as active user traffic.

Fix: stream tracking now distinguishes inbound and outbound stream parity for the connection role, excludes stream `0` from active counts, and raises `REFUSED_STREAM` when the outbound peer limit is actually exhausted. The branch includes a settings-driven client stream creation test.

Verification: `make test` passed in `http2-fork`.
