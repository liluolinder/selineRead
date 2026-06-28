package ignite.client

import stdx.net.http.{HttpResponse, HttpHeaders}
import std.collection.ArrayList
import std.io.InputStream

// ── ClientResponse ──

public class ClientResponse {
    let _resp: HttpResponse
    var _bodyCache: ?Array<UInt8> = None

    public init(resp: HttpResponse) {
        _resp = resp
    }

    public prop status: UInt16 {
        get() { _resp.status }
    }

    public prop headers: HttpHeaders {
        get() { _resp.headers }
    }

    public func isOk(): Bool {
        let s = Int64(_resp.status)
        s >= 200 && s < 300
    }

    public func isSuccess(): Bool {
        isOk()
    }

    /// Returns the raw underlying `InputStream` of the HTTP response body.
    ///
    /// This is a **one-pass** stream — it does **not** participate in the
    /// `bodyBytes()` cache. Once the stream has been consumed (by this method,
    /// `bodyBytes()`, or `discard()`), subsequent reads return empty.
    ///
    /// If you need repeatable access to the body content, use `bodyBytes()`
    /// instead, which caches on first read.
    public func bodyStream(): InputStream {
        _resp.body
    }

    /// Returns the response body as a decoded UTF-8 `String`.
    ///
    /// Delegates to `bodyBytes()` (cached). The first call reads and caches
    /// the body; subsequent calls return the cached content. This method is
    /// **repeatable** — calling it multiple times always returns the same result.
    ///
    /// See also: `bodyBytes()`, `bodyStream()`, `discard()`.
    public func body(): String {
        String.fromUtf8(bodyBytes())
    }

    /// Returns the response body as a byte array.
    ///
    /// **Cache-first** — the first call reads and caches the body content
    /// in `_bodyCache`. Subsequent calls return the cached array directly.
    /// This method is **repeatable**: multiple calls return the same content.
    ///
    /// Note: `discard()` does **not** populate `_bodyCache`. Calling
    /// `bodyBytes()` after `discard()` will attempt to read from the already-
    /// consumed raw stream and return an **empty** array.
    ///
    /// See also: `body()`, `bodyStream()`, `discard()`.
    public func bodyBytes(): Array<UInt8> {
        if (let Some(cached) <- _bodyCache) {
            return cached
        }
        let chunks = ArrayList<Array<UInt8>>()
        let tmp = Array<UInt8>(16384, repeat: 0)
        var totalSize: Int64 = 0
        while (true) {
            let n = _resp.body.read(tmp)
            if (n <= 0) { break }
            let chunk = Array<UInt8>(n, repeat: 0)
            for (i in 0..n) {
                chunk[i] = tmp[i]
            }
            totalSize += n
            chunks.add(chunk)
        }

        let arr = Array<UInt8>(totalSize, repeat: 0)
        var offset: Int64 = 0
        for (chunk in chunks) {
            for (i in 0..chunk.size) {
                arr[offset + i] = chunk[i]
            }
            offset += chunk.size
        }

        _bodyCache = arr
        arr
    }

    public func json(): String {
        body()
    }

    public func header(name: String): ?String {
        _resp.headers.getFirst(name)
    }

    public func headerValues(name: String): ArrayList<String> {
        let list = ArrayList<String>()
        for (v in _resp.headers.get(name)) {
            list.add(v)
        }
        list
    }

    /// Returns the observe snapshot parsed from response headers.
    ///
    /// This method reads metadata from response headers only
    /// (`x-ignite-observe-*`) — it is **independent of body content**.
    /// Calling `bodyBytes()`, `bodyStream()`, or `discard()` does **not**
    /// affect the return value.
    ///
    /// Returns `None` if the response does not carry observe headers
    /// (e.g., non-observe or non-Ignite responses).
    public func observeSnapshot(): ?ClientObserveSnapshot {
        if (!hasObserveHeaders()) {
            return None
        }
        let errorClass = normalizedObserveErrorClass(headerOr("x-ignite-observe-error-class", "NONE"))
        Some(
            ClientObserveSnapshot(
                if (errorClass == "NONE") { "success" } else { "error" },
                errorClass,
                "response",
                "-",
                headerOr("x-ignite-observe-backend-id", "-"),
                headerOr("x-ignite-observe-provider-id", "-"),
                headerOr("x-ignite-observe-crypto-provider-id", "-"),
                headerOr("x-ignite-observe-public-path", "-"),
                headerOr("x-ignite-observe-risk-level", "-"),
                headerOr("x-ignite-observe-transport-tags", "-"),
                false,
                false,
                false,
                parseObserveInt64("x-ignite-observe-retry-count", 0),
                parseObserveInt64("x-ignite-observe-duration-ms", 0),
                headerOr("x-ignite-observe-fields", "-"),
                status,
                "-",
                "-",
                "-",
                false,
                ""
            )
        )
    }

    /// Returns the transport touchpoint parsed from response headers.
    ///
    /// This method reads metadata from response headers only
    /// (`x-ignite-observe-*`) — it is **independent of body content**.
    /// Calling `bodyBytes()`, `bodyStream()`, or `discard()` does **not**
    /// affect the return value.
    ///
    /// Returns `None` if the response does not carry observe headers.
    public func transportTouchpoint(): ?ClientTransportTouchpoint {
        if (!hasObserveHeaders()) {
            return None
        }
        Some(
            ClientTransportTouchpoint(
                headerOr("x-ignite-observe-candidate-order", "-"),
                headerOr("x-ignite-observe-backend-id", "-"),
                headerOr("x-ignite-observe-selected-reason", "-"),
                headerOr("x-ignite-observe-fallback-chain", "-"),
                headerOr("x-ignite-observe-provider-id", "-"),
                headerOr("x-ignite-observe-crypto-provider-id", "-"),
                headerOr("x-ignite-observe-public-path", "-"),
                headerOr("x-ignite-observe-risk-level", "-"),
                headerOr("x-ignite-observe-transport-tags", "-")
            )
        )
    }

    /// Drains the raw response body stream without caching.
    ///
    /// Reads the underlying `InputStream` in 16 KB chunks until exhausted.
    /// This method does **not** populate `_bodyCache`, so a subsequent call to
    /// `bodyBytes()` will return an **empty** array (the raw stream is already
    /// consumed).
    ///
    /// Use `discard()` when you need to release the connection / stream
    /// without processing the body content. If you need the body content,
    /// call `bodyBytes()` or `body()` **before** `discard()`.
    ///
    /// Note: `observeSnapshot()` and `transportTouchpoint()` are unaffected
    /// by `discard()` — they read from headers, not from the body stream.
    public func discard(): Unit {
        let tmp = Array<UInt8>(16384, repeat: 0)
        while (true) {
            if (_resp.body.read(tmp) <= 0) {
                break
            }
        }
    }

    func hasObserveHeaders(): Bool {
        if (let Some(_backend) <- header("x-ignite-observe-backend-id")) {
            return true
        }
        false
    }

    func headerOr(name: String, fallback: String): String {
        if (let Some(value) <- header(name)) {
            return value
        }
        fallback
    }

    func normalizedObserveErrorClass(value: String): String {
        if (value == "NONE") {
            return "NONE"
        }
        value
    }

    func parseObserveInt64(name: String, fallback: Int64): Int64 {
        if (let Some(value) <- header(name)) {
            return parseDecimalInt64(value, fallback)
        }
        fallback
    }
}

func parseDecimalInt64(value: String, fallback: Int64): Int64 {
    let digits = value.trimAscii()
    if (digits.size == 0) {
        return fallback
    }
    var result: Int64 = 0
    for (ch in digits.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            return fallback
        }
        result = result * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
    }
    result
}
