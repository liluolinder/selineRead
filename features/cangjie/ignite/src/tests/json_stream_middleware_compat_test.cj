package ignite.tests

import ignite.*
import ignite.middleware.*
import seajson.JsonWriter as SeaJsonNativeWriter
import std.collection.ArrayList

/// Focused compatibility audit for the accepted `ctx.jsonStream(...)` sugar.
///
/// This suite proves the current non-buffered middleware boundary of the bridge/sugar path:
/// 1. `compress` still stays unpromised when the stream-compress subset is not applicable
/// 2. `etag` stays unpromised because `responseBody` is not populated
/// 3. `cache` does not reuse the streamed response
/// 4. `idempotency` does not reuse the streamed response
@Test
public class JsonStreamMiddlewareCompatTestSuite {
    @TestCase
    public func testJsonStreamSkipsCompressionWhenStreamCompressSubsetIsNotApplicable(): Unit {
        let app = App(config: Config())
        app.use(compressMiddleware(config: CompressConfig(minBytes: 0)))
        app.get("/json-stream-compress", { ctx =>
            _ = ctx.jsonStream({ jw =>
                jw.startObject()
                jw.writeName("msg")
                jw.writeValue("no-buffered-body")
                jw.endObject()
            }, contentLength: Some(26))
        })

        let resp = app.handleForTest(
            "GET",
            "/json-stream-compress",
            headers: [("accept-encoding", "gzip, deflate")]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-encoding") ?? "", "")
        @Assert(resp.body, "{\"msg\":\"no-buffered-body\"}")
    }

    @TestCase
    public func testJsonStreamSkipsEtagBecauseResponseBodyIsUnpromised(): Unit {
        let app = App(config: Config())
        app.use(etagMiddleware())
        app.get("/json-stream-etag", { ctx =>
            _ = ctx.jsonStream({ jw =>
                jw.startObject()
                jw.writeName("msg")
                jw.writeValue("no-etag")
                jw.endObject()
            }, contentLength: Some(17))
        })

        let resp = app.handleForTest("GET", "/json-stream-etag")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("etag") ?? "", "")
        @Assert(resp.body, "{\"msg\":\"no-etag\"}")
    }

    @TestCase
    public func testJsonStreamSkipsCacheReuseBecauseResponseBodyIsUnpromised(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        app.use(
            cacheMiddleware(
                config: CacheConfig(
                    expiration: Duration.second * 30,
                    cleanupEvery: 1
                )
            )
        )
        app.get("/json-stream-cache", { ctx =>
            hits.add("hit")
            let body = jsonStreamCounterBody(hits.size)
            _ = ctx.jsonStream({ jw =>
                jw.startObject()
                jw.writeName("n")
                jw.writeValue(hits.size)
                jw.endObject()
            }, contentLength: Some(body.size))
        })

        let first = app.handleForTest("GET", "/json-stream-cache")
        @Assert(first.status, UInt16(200))
        @Assert(first.header("x-cache") ?? "", "MISS")
        @Assert(first.body, "{\"n\":1}")

        let second = app.handleForTest("GET", "/json-stream-cache")
        @Assert(second.status, UInt16(200))
        @Assert(second.header("x-cache") ?? "", "MISS")
        @Assert(second.body, "{\"n\":2}")
    }

    @TestCase
    public func testJsonStreamSkipsIdempotencyReuseBecauseResponseBodyIsUnpromised(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        app.use(
            idempotencyMiddleware(
                config: IdempotencyConfig(
                    lifetime: Duration.second * 30,
                    cleanupEvery: 1
                )
            )
        )
        app.post("/json-stream-orders", { ctx =>
            hits.add("hit")
            let body = jsonStreamCounterBody(hits.size)
            _ = ctx.jsonStream({ jw =>
                jw.startObject()
                jw.writeName("n")
                jw.writeValue(hits.size)
                jw.endObject()
            }, contentLength: Some(body.size))
        })

        let first = app.handleForTest(
            "POST",
            "/json-stream-orders",
            headers: [("x-idempotency-key", "stream-order-1")]
        )
        @Assert(first.status, UInt16(200))
        @Assert(first.header("x-idempotency-cached") ?? "", "")
        @Assert(first.body, "{\"n\":1}")

        let second = app.handleForTest(
            "POST",
            "/json-stream-orders",
            headers: [("x-idempotency-key", "stream-order-1")]
        )
        @Assert(second.status, UInt16(200))
        @Assert(second.header("x-idempotency-cached") ?? "", "")
        @Assert(second.body, "{\"n\":2}")
    }
}

/// Focused compatibility audit for the accepted `ctx.jsonEncodeStream(...)` sugar.
///
/// This suite proves the current non-buffered middleware boundary of the
/// writer-facing twin path stays aligned with `ctx.jsonStream(...)`:
/// 1. `compress` still stays unpromised when the stream-compress subset is not applicable
/// 2. `etag` stays unpromised because `responseBody` is not populated
/// 3. `cache` does not reuse the streamed response
/// 4. `idempotency` does not reuse the streamed response
@Test
public class JsonEncodeStreamMiddlewareCompatTestSuite {
    @TestCase
    public func testJsonEncodeStreamSkipsCompressionWhenStreamCompressSubsetIsNotApplicable(): Unit {
        let app = App(config: Config())
        app.use(compressMiddleware(config: CompressConfig(minBytes: 0)))
        let payload = JsonEncodeStreamCompatMessageValue("no-buffered-body")
        let body = payload.toJsonString()
        app.get("/json-encode-stream-compress", { ctx =>
            _ = ctx.jsonEncodeStream(payload, contentLength: Some(body.size))
        })

        let resp = app.handleForTest(
            "GET",
            "/json-encode-stream-compress",
            headers: [("accept-encoding", "gzip, deflate")]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-encoding") ?? "", "")
        @Assert(resp.body, body)
    }

    @TestCase
    public func testJsonEncodeStreamSkipsEtagBecauseResponseBodyIsUnpromised(): Unit {
        let app = App(config: Config())
        app.use(etagMiddleware())
        let payload = JsonEncodeStreamCompatMessageValue("no-etag")
        let body = payload.toJsonString()
        app.get("/json-encode-stream-etag", { ctx =>
            _ = ctx.jsonEncodeStream(payload, contentLength: Some(body.size))
        })

        let resp = app.handleForTest("GET", "/json-encode-stream-etag")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("etag") ?? "", "")
        @Assert(resp.body, body)
    }

    @TestCase
    public func testJsonEncodeStreamSkipsCacheReuseBecauseResponseBodyIsUnpromised(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        app.use(
            cacheMiddleware(
                config: CacheConfig(
                    expiration: Duration.second * 30,
                    cleanupEvery: 1
                )
            )
        )
        app.get("/json-encode-stream-cache", { ctx =>
            hits.add("hit")
            let payload = JsonEncodeStreamCompatCounterValue(hits.size)
            let body = payload.toJsonString()
            _ = ctx.jsonEncodeStream(payload, contentLength: Some(body.size))
        })

        let first = app.handleForTest("GET", "/json-encode-stream-cache")
        @Assert(first.status, UInt16(200))
        @Assert(first.header("x-cache") ?? "", "MISS")
        @Assert(first.body, "{\"n\":1}")

        let second = app.handleForTest("GET", "/json-encode-stream-cache")
        @Assert(second.status, UInt16(200))
        @Assert(second.header("x-cache") ?? "", "MISS")
        @Assert(second.body, "{\"n\":2}")
    }

    @TestCase
    public func testJsonEncodeStreamSkipsIdempotencyReuseBecauseResponseBodyIsUnpromised(): Unit {
        let app = App(config: Config())
        let hits = ArrayList<String>()
        app.use(
            idempotencyMiddleware(
                config: IdempotencyConfig(
                    lifetime: Duration.second * 30,
                    cleanupEvery: 1
                )
            )
        )
        app.post("/json-encode-stream-orders", { ctx =>
            hits.add("hit")
            let payload = JsonEncodeStreamCompatCounterValue(hits.size)
            let body = payload.toJsonString()
            _ = ctx.jsonEncodeStream(payload, contentLength: Some(body.size))
        })

        let first = app.handleForTest(
            "POST",
            "/json-encode-stream-orders",
            headers: [("x-idempotency-key", "stream-order-1")]
        )
        @Assert(first.status, UInt16(200))
        @Assert(first.header("x-idempotency-cached") ?? "", "")
        @Assert(first.body, "{\"n\":1}")

        let second = app.handleForTest(
            "POST",
            "/json-encode-stream-orders",
            headers: [("x-idempotency-key", "stream-order-1")]
        )
        @Assert(second.status, UInt16(200))
        @Assert(second.header("x-idempotency-cached") ?? "", "")
        @Assert(second.body, "{\"n\":2}")
    }
}

func jsonStreamCounterBody(n: Int64): String {
    "{\"n\":${n}}"
}

class JsonEncodeStreamCompatMessageValue <: JsonEncodable & JsonWriterEncodable {
    let _msg: String

    public init(msg: String) {
        _msg = msg
    }

    public func toJsonString(): String {
        "{\"msg\":\"${_msg}\"}"
    }

    public func writeJson(writer: SeaJsonNativeWriter): Unit {
        writer.beginObject()
            .name("msg").value(_msg)
        .endObject()
    }
}

class JsonEncodeStreamCompatCounterValue <: JsonEncodable & JsonWriterEncodable {
    let _n: Int64

    public init(n: Int64) {
        _n = n
    }

    public func toJsonString(): String {
        "{\"n\":${_n}}"
    }

    public func writeJson(writer: SeaJsonNativeWriter): Unit {
        writer.beginObject()
            .name("n").value(_n)
        .endObject()
    }
}
