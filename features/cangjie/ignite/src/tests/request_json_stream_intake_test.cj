package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.HashMap
import std.io.InputStream
import stdx.encoding.json.{JsonValue, JsonObject}
import stdx.net.http.{HttpContext, HttpHeaders, WebSocket}

@Test
public class RequestJsonStreamIntakeTestSuite {
    @TestCase
    public func testRequestJsonReaderReadsObjectKeysAndValues(): Unit {
        let carrier = RequestJsonStreamTestCarrier(
            "POST", "/json-read",
            #"{"name":"ignite","count":42,"active":true,"score":3.14}"#
        )
        let ctx = Ctx(carrier, App(config: Config(bodyLimit: 512)))
        let reader = ctx.requestJsonReader()

        reader.startObject()
        @Assert(reader.readName(), "name")
        @Assert(reader.readValue<String>(), "ignite")
        @Assert(reader.readName(), "count")
        @Assert(reader.readValue<Int64>(), Int64(42))
        @Assert(reader.readName(), "active")
        @Assert(reader.readValue<Bool>(), true)
        @Assert(reader.readName(), "score")
        @Assert(reader.readValue<Float64>(), Float64(3.14))
        reader.endObject()
    }

    @TestCase
    public func testRequestJsonReaderInheritsBodyLimitOverflow(): Unit {
        let jsonBody = #"{"payload":"this is a very long json payload that exceeds the configured body limit"}"#
        let carrier = RequestJsonStreamTestCarrier("POST", "/json-limit", jsonBody)
        let ctx = Ctx(carrier, App(config: Config(bodyLimit: 20)))
        let reader = ctx.requestJsonReader()

        try {
            reader.startObject()
            let _ = reader.readName()
            @Fail("requestJsonReader should throw BufferedRequestBodyTooLargeException when body exceeds limit")
        } catch (e: BufferedRequestBodyTooLargeException) {
            @Assert(e.limitBytes, Int64(20))
            @Assert(e.attemptedBytes > 20, true)
            @Assert(e.message.size > 0, true)
        }
    }

    @TestCase
    public func testRequestJsonReaderSmallBodyWithinLimitSucceeds(): Unit {
        let carrier = RequestJsonStreamTestCarrier(
            "POST", "/json-ok",
            #"{"status":"ok","code":200}"#
        )
        let ctx = Ctx(carrier, App(config: Config(bodyLimit: 128)))
        let reader = ctx.requestJsonReader()

        reader.startObject()
        @Assert(reader.readName(), "status")
        @Assert(reader.readValue<String>(), "ok")
        @Assert(reader.readName(), "code")
        @Assert(reader.readValue<Int64>(), Int64(200))
        reader.endObject()
    }

    @TestCase
    public func testBodyBytesThenRequestJsonReaderReplaysFromCache(): Unit {
        let jsonBody = #"{"name":"ignite","count":42}"#
        let carrier = RequestJsonStreamTestCarrier("POST", "/json-replay", jsonBody)
        let ctx = Ctx(carrier, App(config: Config(bodyLimit: 128)))

        let cached = ctx.bodyBytes()
        @Assert(String.fromUtf8(cached), jsonBody)

        let reader = ctx.requestJsonReader()
        reader.startObject()
        @Assert(reader.readName(), "name")
        @Assert(reader.readValue<String>(), "ignite")
        @Assert(reader.readName(), "count")
        @Assert(reader.readValue<Int64>(), Int64(42))
        reader.endObject()
    }

    @TestCase
    public func testRequestJsonReaderThenBodyBytesStaysOnePassAfterFullConsume(): Unit {
        let carrier = RequestJsonStreamTestCarrier(
            "POST", "/json-one-pass",
            #"{"status":"ok","code":200}"#
        )
        let ctx = Ctx(carrier, App(config: Config(bodyLimit: 128)))

        let reader = ctx.requestJsonReader()
        reader.startObject()
        @Assert(reader.readName(), "status")
        @Assert(reader.readValue<String>(), "ok")
        @Assert(reader.readName(), "code")
        @Assert(reader.readValue<Int64>(), Int64(200))
        reader.endObject()

        let after = ctx.bodyBytes()
        @Assert(after.size, Int64(0))
        @Assert(String.fromUtf8(after), "")
    }

    @TestCase
    public func testBindJsonOr400RemainsUnchangedAfterRequestJsonReader(): Unit {
        let app = App(config: Config())
        app.post("/bind", { ctx =>
            if (let Some(req) <- ctx.bindJsonOr400<RequestJsonStreamTestReq>(
                { jsonValue => decodeRequestJsonStreamTestReq(jsonValue) }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let okResp = app.handleForTest(
            "POST",
            "/bind",
            body: #"{"name":"seam","val":7}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(okResp.status, UInt16(201))
        @Assert(okResp.body, "created:seam:7")

        let badResp = app.handleForTest(
            "POST",
            "/bind",
            body: #"{"name":"broken","val":"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_json""#), true)
    }

    @TestCase
    public func testBindJsonReaderOr400Success(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream", { ctx =>
            if (let Some(req) <- ctx.bindJsonReaderOr400<RequestJsonStreamTestReq>(
                { reader => RequestJsonStreamTestReq.fromJson(reader) }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let okResp = app.handleForTest(
            "POST",
            "/bind-stream",
            body: #"{"name":"streamed","val":9}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(okResp.status, UInt16(201))
        @Assert(okResp.body, "created:streamed:9")
    }

    @TestCase
    public func testBindJsonReaderOr400InvalidJsonReturnsReadable400(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream", { ctx =>
            if (let Some(req) <- ctx.bindJsonReaderOr400<RequestJsonStreamTestReq>(
                { reader => RequestJsonStreamTestReq.fromJson(reader) }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let badResp = app.handleForTest(
            "POST",
            "/bind-stream",
            body: #"{"name":"broken","val":"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_json""#), true)
    }

    @TestCase
    public func testBindJsonReaderOr400DecoderFailureReturnsInvalidPayload(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-invalid-payload", { ctx =>
            if (let Some(req) <- ctx.bindJsonReaderOr400<RequestJsonStreamTestReq>(
                { reader => decodeRequestJsonStreamMissingVal(reader) }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let badResp = app.handleForTest(
            "POST",
            "/bind-stream-invalid-payload",
            body: #"{"name":"only","other":1}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_payload""#), true)
    }

    @TestCase
    public func testBindJsonReaderOr400OverflowReturnsInvalidPayload(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-overflow", { ctx =>
            if (let Some(value) <- ctx.bindJsonReaderOr400<Int8>(
                { reader => reader.readValue<Int8>() }
            )) {
                _ = ctx.status(201).sendString("${value}")
            }
        })

        let badResp = app.handleForTest(
            "POST",
            "/bind-stream-overflow",
            body: "128",
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_payload""#), true)
    }

    @TestCase
    public func testBindJsonReaderOr400ValidationFailureReturnsReadable400(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-validate", { ctx =>
            if (let Some(req) <- ctx.bindJsonReaderOr400<RequestJsonStreamTestReq>(
                { reader => RequestJsonStreamTestReq.fromJson(reader) },
                validate: { req =>
                    if (req.val <= 0) {
                        return Some("val must be positive")
                    }
                    None
                }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let badValidation = app.handleForTest(
            "POST",
            "/bind-stream-validate",
            body: #"{"name":"streamed","val":0}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badValidation.status, UInt16(400))
        @Assert(containsRequestJsonStr(badValidation.body, #""reason":"validation_failed""#), true)
    }

    @TestCase
    public func testBindJsonReaderOr400InheritsBodyLimitOverflow(): Unit {
        let app = App(config: Config(bodyLimit: 20))
        app.post("/bind-stream-limit", { ctx =>
            if (let Some(req) <- ctx.bindJsonReaderOr400<RequestJsonStreamTestReq>(
                { reader => RequestJsonStreamTestReq.fromJson(reader) }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let resp = app.handleForTest(
            "POST",
            "/bind-stream-limit",
            body: #"{"name":"this is a very long streamed request body","val":1}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(resp.status, UInt16(413))
        @Assert(containsRequestJsonStr(resp.body.toAsciiLower(), "large"), true)
    }

    @TestCase
    public func testBindJsonDeserializeOr400Success(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-typed", { ctx =>
            if (let Some(req) <- ctx.bindJsonDeserializeOr400<RequestJsonStreamTestReq>()) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let okResp = app.handleForTest(
            "POST",
            "/bind-stream-typed",
            body: #"{"name":"typed","val":12}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(okResp.status, UInt16(201))
        @Assert(okResp.body, "created:typed:12")
    }

    @TestCase
    public func testBindJsonDeserializeOr400InvalidJsonReturnsReadable400(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-typed", { ctx =>
            if (let Some(req) <- ctx.bindJsonDeserializeOr400<RequestJsonStreamTestReq>()) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let badResp = app.handleForTest(
            "POST",
            "/bind-stream-typed",
            body: #"{"name":"broken","val":"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_json""#), true)
    }

    @TestCase
    public func testBindJsonDeserializeOr400DecoderFailureReturnsInvalidPayload(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-typed-invalid-payload", { ctx =>
            if (let Some(req) <- ctx.bindJsonDeserializeOr400<RequestJsonStreamTestReq>()) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let badResp = app.handleForTest(
            "POST",
            "/bind-stream-typed-invalid-payload",
            body: #"{"name":"typed","other":1}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_payload""#), true)
    }

    @TestCase
    public func testBindJsonDeserializeOr400OverflowReturnsInvalidPayload(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-typed-overflow", { ctx =>
            if (let Some(value) <- ctx.bindJsonDeserializeOr400<Int8>()) {
                _ = ctx.status(201).sendString("${value}")
            }
        })

        let badResp = app.handleForTest(
            "POST",
            "/bind-stream-typed-overflow",
            body: "128",
            headers: [("content-type", "application/json")]
        )
        @Assert(badResp.status, UInt16(400))
        @Assert(containsRequestJsonStr(badResp.body, #""reason":"invalid_payload""#), true)
    }

    @TestCase
    public func testBindJsonDeserializeOr400ValidationFailureReturnsReadable400(): Unit {
        let app = App(config: Config())
        app.post("/bind-stream-typed-validate", { ctx =>
            if (let Some(req) <- ctx.bindJsonDeserializeOr400<RequestJsonStreamTestReq>(
                validate: { req =>
                    if (req.val <= 0) {
                        return Some("val must be positive")
                    }
                    None
                }
            )) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let badValidation = app.handleForTest(
            "POST",
            "/bind-stream-typed-validate",
            body: #"{"name":"typed","val":0}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(badValidation.status, UInt16(400))
        @Assert(containsRequestJsonStr(badValidation.body, #""reason":"validation_failed""#), true)
    }

    @TestCase
    public func testBindJsonDeserializeOr400InheritsBodyLimitOverflow(): Unit {
        let app = App(config: Config(bodyLimit: 20))
        app.post("/bind-stream-typed-limit", { ctx =>
            if (let Some(req) <- ctx.bindJsonDeserializeOr400<RequestJsonStreamTestReq>()) {
                _ = ctx.status(201).sendString("created:${req.name}:${req.val}")
            }
        })

        let resp = app.handleForTest(
            "POST",
            "/bind-stream-typed-limit",
            body: #"{"name":"this is a very long streamed request body","val":1}"#,
            headers: [("content-type", "application/json")]
        )
        @Assert(resp.status, UInt16(413))
        @Assert(containsRequestJsonStr(resp.body.toAsciiLower(), "large"), true)
    }
}

func decodeRequestJsonStreamTestReq(jsonValue: JsonValue): RequestJsonStreamTestReq {
    let obj = jsonValue.asObject()
    let name = requireRequestJsonStreamTestStringField(obj, "name")
    let val = requireRequestJsonStreamTestIntField(obj, "val")
    RequestJsonStreamTestReq(name, val)
}

func decodeRequestJsonStreamMissingVal(reader: JsonReader): RequestJsonStreamTestReq {
    reader.startObject()
    let firstField = reader.readName()
    if (firstField != "name") {
        throw Exception("missing field: name")
    }
    let name = reader.readValue<String>()
    let secondField = reader.readName()
    if (secondField != "val") {
        throw Exception("missing field: val")
    }
    let val = reader.readValue<Int64>()
    reader.endObject()
    RequestJsonStreamTestReq(name, val)
}

func requireRequestJsonStreamTestStringField(obj: JsonObject, key: String): String {
    if (let Some(v) <- obj.get(key)) {
        return v.asString().getValue()
    }
    throw Exception("missing field: ${key}")
}

func requireRequestJsonStreamTestIntField(obj: JsonObject, key: String): Int64 {
    if (let Some(v) <- obj.get(key)) {
        return v.asInt().getValue()
    }
    throw Exception("missing field: ${key}")
}

func containsRequestJsonStr(text: String, sub: String): Bool {
    let t = text.toRuneArray()
    let p = sub.toRuneArray()
    if (p.size == 0) { return true }
    if (t.size < p.size) { return false }
    var i: Int64 = 0
    while (i <= t.size - p.size) {
        var ok = true
        var j: Int64 = 0
        while (j < p.size) {
            if (t[i + j] != p[j]) {
                ok = false
                break
            }
            j += 1
        }
        if (ok) { return true }
        i += 1
    }
    false
}

struct RequestJsonStreamTestReq <: JsonDeserializable<RequestJsonStreamTestReq> {
    let name: String
    let val: Int64

    init(name: String, val: Int64) {
        this.name = name
        this.val = val
    }

    public static func fromJson(reader: JsonReader): RequestJsonStreamTestReq {
        reader.startObject()
        let firstField = reader.readName()
        if (firstField != "name") {
            throw Exception("missing field: name")
        }
        let name = reader.readValue<String>()
        let secondField = reader.readName()
        if (secondField != "val") {
            throw Exception("missing field: val")
        }
        let val = reader.readValue<Int64>()
        reader.endObject()
        RequestJsonStreamTestReq(name, val)
    }
}

class RequestJsonStreamTestCarrier <: CurrentRequestCarrier {
    let methodText: String
    let pathText: String
    let requestBytes: Array<Byte>
    let bodyStream: RequestJsonStreamTestBytesInputStream
    let responseHeaders = HashMap<String, String>()
    public var responseStatus: UInt16 = 200
    public var responseBody: String = ""

    init(methodText: String, pathText: String, bodyText: String) {
        this.methodText = methodText
        this.pathText = pathText
        this.requestBytes = toRequestJsonStreamTestByteArray(bodyText.toArray())
        this.bodyStream = RequestJsonStreamTestBytesInputStream(this.requestBytes)
    }

    public func header(name: String): ?String {
        responseHeaders.get(name.trimAscii().toAsciiLower())
    }

    public override func rawHttpContext(): HttpContext {
        throw Exception("raw HttpContext should not be required for request JSON stream tests")
    }

    public override func upgradeWebSocketRaw(): WebSocket {
        throw Exception("websocket upgrade should not run in request JSON stream tests")
    }

    public override func openResponseTransportWriterRaw(): ResponseTransportWriter {
        throw Exception("response transport writer should not open in request JSON stream tests")
    }

    public override func requestMethod(): String {
        methodText
    }

    public override func requestPath(): String {
        pathText
    }

    public override func requestUrlString(): String {
        pathText
    }

    public override func requestVersionString(): String {
        "HTTP/1.1"
    }

    public override func requestRemoteAddr(): String {
        "127.0.0.1"
    }

    public override func requestQueryValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestFormValue(key: String): ?String {
        let _ = key
        None
    }

    public override func requestHeaderValue(key: String): ?String {
        if (key.trimAscii().toAsciiLower() == "content-length") {
            return Some(requestBytes.size.toString())
        }
        None
    }

    public override func requestHeaders(): HttpHeaders {
        let headers = HttpHeaders()
        headers.add("content-length", requestBytes.size.toString())
        headers
    }

    public override func requestBodyStream(): InputStream {
        bodyStream
    }

    public override func requestBodySize(): ?Int64 {
        Some(requestBytes.size)
    }

    public override func setResponseStatus(code: UInt16): Unit {
        responseStatus = code
    }

    public override func setResponseHeader(key: String, value: String): Unit {
        responseHeaders.add(key.trimAscii().toAsciiLower(), value)
    }

    public override func addResponseHeaders(headers: HttpHeaders): Unit {
        let _ = headers
    }

    public override func setResponseString(body: String): Unit {
        responseBody = body
    }

    public override func setResponseBytes(data: Array<UInt8>): Unit {
        responseBody = String.fromUtf8(data)
    }

    public override func attachResponseBodyStream(stream: InputStream): Unit {
        let _ = stream
    }
}

class RequestJsonStreamTestBytesInputStream <: InputStream {
    let bytes: Array<Byte>
    var cursor: Int64 = 0

    init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (cursor >= bytes.size || outBuf.size == 0) {
            return 0
        }
        let remaining = bytes.size - cursor
        let readLen = if (remaining < outBuf.size) { remaining } else { outBuf.size }
        var i: Int64 = 0
        while (i < readLen) {
            outBuf[i] = bytes[cursor + i]
            i += 1
        }
        cursor += readLen
        readLen
    }

    public func close(): Unit {}
}

func toRequestJsonStreamTestByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i: Int64 = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}
