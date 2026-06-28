package ignite.tests

import ignite.*
import std.collection.{ArrayList, HashMap}
import std.fs.{exists, File, OpenMode}
import std.net.{TcpSocket, IPSocketAddress}
import std.time.DateTime

@Test
public class FileDownloadAndRestfulTestSuite {
    @TestCase
    public func testDownloadAndRangeSupportLeadingSlashRelativePath(): Unit {
        let app = App(config: Config())

        app.get("/download-readme", { ctx =>
            _ = ctx.download("/README.md", filename: "README.md")
        })
        app.get("/range-readme", { ctx =>
            _ = ctx.sendFileRange("/README.md")
        })

        let downloadResp = app.handleForTest("GET", "/download-readme")
        @Assert(downloadResp.status, UInt16(200))
        @Assert(contains(downloadResp.header("content-disposition") ?? "", "attachment; filename=\"README.md\""), true)
        @Assert(contains(downloadResp.body, "Ignite"), true)

        let rangeResp = app.handleForTest(
            "GET",
            "/range-readme",
            headers: [("range", "bytes=0-31")]
        )
        @Assert(rangeResp.status, UInt16(206))
        @Assert(contains(rangeResp.header("content-range") ?? "", "bytes 0-31/"), true)
        @Assert(rangeResp.header("content-length") ?? "", "32")
        @Assert(rangeResp.body.size, Int64(32))
    }

    @TestCase
    public func testLargeFileDownloadAndRangeStreamAcrossChunks(): Unit {
        let fixturePath = "/tmp/ignite_streaming_download_fixture.txt"
        let payload = buildLargeAsciiPayload()
        writeTextFile(fixturePath, payload)

        let app = App(config: Config())
        app.get("/large-file", { ctx =>
            _ = ctx.sendFile(fixturePath)
        })
        app.get("/large-range", { ctx =>
            _ = ctx.sendFileRange(fixturePath)
        })
        app.head("/large-file", { ctx =>
            _ = ctx.sendFile(fixturePath)
        })

        let fileResp = app.handleForTest("GET", "/large-file")
        @Assert(fileResp.status, UInt16(200))
        @Assert(fileResp.header("content-length") ?? "", payload.size.toString())
        @Assert(fileResp.header("accept-ranges") ?? "", "bytes")
        @Assert(fileResp.body, payload)

        let start: Int64 = 65520
        let end: Int64 = 65679
        let rangeResp = app.handleForTest(
            "GET",
            "/large-range",
            headers: [("range", "bytes=${start}-${end}")]
        )
        @Assert(rangeResp.status, UInt16(206))
        @Assert(rangeResp.header("content-range") ?? "", "bytes ${start}-${end}/${payload.size}")
        @Assert(rangeResp.header("content-length") ?? "", "${end - start + 1}")
        @Assert(rangeResp.header("accept-ranges") ?? "", "bytes")
        @Assert(rangeResp.body, sliceText(payload, start, end + 1))

        let headResp = app.handleForTest("HEAD", "/large-file")
        @Assert(headResp.status, UInt16(200))
        @Assert(headResp.header("content-length") ?? "", payload.size.toString())
        @Assert(headResp.header("accept-ranges") ?? "", "bytes")
        @Assert(headResp.body, "")
    }

    @TestCase
    public func testLargeFileDownloadAndRangeOverRealHttpKeepKnownLengthWire(): Unit {
        let fixturePath = "/tmp/ignite_streaming_download_wire_fixture.txt"
        let payload = buildLargeAsciiPayload()
        writeTextFile(fixturePath, payload)
        let start: Int64 = 4096
        let end: Int64 = 4351
        let port = chooseUploadTestPort(1897)

        let app = App(config: Config())
        app.get("/large-file-wire", { ctx =>
            _ = ctx.sendFile(fixturePath)
        })
        app.get("/large-range-wire", { ctx =>
            _ = ctx.sendFileRange(fixturePath)
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let fileResp = sendRawDownloadWithRetry(port, "GET", "/large-file-wire")
            @Assert(fileResp.status, UInt16(200))
            @Assert(fileResp.header("content-length") ?? "", payload.size.toString())
            @Assert(fileResp.header("transfer-encoding") ?? "", "")
            @Assert(fileResp.header("accept-ranges") ?? "", "bytes")
            @Assert(fileResp.body, payload)

            let rangeResp = sendRawDownloadWithRetry(
                port,
                "GET",
                "/large-range-wire",
                headers: [("range", "bytes=${start}-${end}")]
            )
            @Assert(rangeResp.status, UInt16(206))
            @Assert(rangeResp.header("content-length") ?? "", "${end - start + 1}")
            @Assert(rangeResp.header("transfer-encoding") ?? "", "")
            @Assert(rangeResp.header("content-range") ?? "", "bytes ${start}-${end}/${payload.size}")
            @Assert(rangeResp.body, sliceText(payload, start, end + 1))
        } finally {
            shutdownUploadTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testPublicFileSegmentInputStreamSupportsKnownLengthSubrangeMigrationOverRealHttp(): Unit {
        let fixturePath = "/tmp/ignite_public_file_segment_stream_fixture.txt"
        let payload = buildLargeAsciiPayload()
        writeTextFile(fixturePath, payload)
        let start: Int64 = 8192
        let length: Int64 = 512
        let end = start + length
        let port = chooseUploadTestPort(1903)

        let app = App(config: Config())
        app.get("/segment-stream-wire", { ctx =>
            let stream = FileSegmentInputStream(fixturePath, start: start, length: length)
            let _ = ctx
                .setHeader("content-disposition", "attachment; filename=\"segment.txt\"")
                .sendStream(
                    stream,
                    contentType: "text/plain; charset=utf-8",
                    contentLength: Some(length)
                )
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendRawDownloadWithRetry(port, "GET", "/segment-stream-wire")
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-length") ?? "", length.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.header("content-disposition") ?? "", "attachment; filename=\"segment.txt\"")
            @Assert(resp.body, sliceText(payload, start, end))
        } finally {
            shutdownUploadTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testSaveBodyToFileStreamsLargeUploadPayload(): Unit {
        let fixturePath = "/tmp/ignite_push_upload_fixture.txt"
        let payload = buildLargeAsciiPayload() + buildLargeAsciiPayload()

        let app = App(config: Config(bodyLimit: 1024 * 1024))
        app.post("/push-upload", { ctx =>
            let saved = ctx.saveBodyToFile(fixturePath)
            _ = ctx.status(201).json(#"{"saved":"# + saved.toString() + #"}"#)
        })

        let resp = app.handleForTest(
            "POST",
            "/push-upload",
            body: payload,
            headers: [("content-type", "text/plain; charset=utf-8")]
        )
        @Assert(resp.status, UInt16(201))
        @Assert(contains(resp.body, #""saved":"# + payload.size.toString()), true)
        @Assert(readTextFile(fixturePath), payload)
    }

    @TestCase
    public func testSaveBodyToFileStreamsKnownLengthUploadOverRealHttp(): Unit {
        let fixturePath = "/tmp/ignite_push_upload_wire_known.txt"
        let payload = buildLargeAsciiPayload() + "known-length-tail"
        let port = chooseUploadTestPort(1881)

        let app = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        app.post("/push-upload-wire-known", { ctx =>
            let cacheBefore = cacheStateLabel(ctx.cachedBodyBytes())
            let saved = ctx.saveBodyToFile(fixturePath)
            let cacheAfter = cacheStateLabel(ctx.cachedBodyBytes())
            _ = ctx
                .setHeader("x-body-cache-before", cacheBefore)
                .setHeader("x-body-cache-after", cacheAfter)
                .status(201)
                .json(#"{"saved":"# + saved.toString() + #"}"#)
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendKnownLengthUploadWithRetry(
                port,
                "/push-upload-wire-known",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(201))
            @Assert(resp.header("x-body-cache-before") ?? "", "miss")
            @Assert(resp.header("x-body-cache-after") ?? "", "miss")
            @Assert(contains(resp.body, #""saved":"# + payload.size.toString()), true)
            @Assert(readTextFile(fixturePath), payload)
        } finally {
            shutdownUploadTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testSaveBodyToFileStreamsChunkedUploadOverRealHttp(): Unit {
        let fixturePath = "/tmp/ignite_push_upload_wire_chunked.txt"
        let payload = buildLargeAsciiPayload() + buildLargeAsciiPayload() + "chunked-tail"
        let port = chooseUploadTestPort(1889)

        let app = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        app.post("/push-upload-wire-chunked", { ctx =>
            let cacheBefore = cacheStateLabel(ctx.cachedBodyBytes())
            let saved = ctx.saveBodyToFile(fixturePath)
            let cacheAfter = cacheStateLabel(ctx.cachedBodyBytes())
            _ = ctx
                .setHeader("x-body-cache-before", cacheBefore)
                .setHeader("x-body-cache-after", cacheAfter)
                .status(201)
                .json(#"{"saved":"# + saved.toString() + #"}"#)
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendChunkedUploadWithRetry(
                port,
                "/push-upload-wire-chunked",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(201))
            @Assert(resp.header("x-body-cache-before") ?? "", "miss")
            @Assert(resp.header("x-body-cache-after") ?? "", "miss")
            @Assert(contains(resp.body, #""saved":"# + payload.size.toString()), true)
            @Assert(readTextFile(fixturePath), payload)
        } finally {
            shutdownUploadTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testSaveBodyToFileRejectsOversizeChunkedUploadOverRealHttpAndRemovesPartialFile(): Unit {
        let fixturePath = "/tmp/ignite_push_upload_wire_chunked_overflow.txt"
        let payload = "123456789"
        let port = chooseUploadTestPort(1911)

        let app = App(config: Config(bodyLimit: 8))
        app.post("/push-upload-wire-chunked-overflow", { ctx =>
            let saved = ctx.saveBodyToFile(fixturePath)
            _ = ctx.status(201).json(#"{"saved":"# + saved.toString() + #"}"#)
        })

        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }
        try {
            let resp = sendChunkedUploadWithRetry(
                port,
                "/push-upload-wire-chunked-overflow",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(413))
            @Assert(resp.header("content-type") ?? "", "text/plain; charset=utf-8")
            @Assert(resp.body, "Payload Too Large")
            @Assert(exists(fixturePath), false)
        } finally {
            shutdownUploadTestApp(app, serverFuture)
        }
    }

    @TestCase
    public func testRestfulCrudEndToEnd(): Unit {
        let app = App(config: Config())
        let store = TodoStore()

        app.get("/todos", { ctx =>
            let doneFilterRaw = (ctx.queryFromUrl("done") ?? "").trimAscii().toAsciiLower()
            if (doneFilterRaw == "true") {
                _ = ctx.json(todoListJson(store.listByDone(true)))
                return
            }
            if (doneFilterRaw == "false") {
                _ = ctx.json(todoListJson(store.listByDone(false)))
                return
            }
            if (doneFilterRaw.size > 0) {
                _ = ctx.status(400).json(errorJson("done must be true or false"))
                return
            }
            _ = ctx.json(todoListJson(store.listAll()))
        })

        app.post("/todos", { ctx =>
            let title = (ctx.queryFromUrl("title") ?? "").trimAscii()
            if (title.size == 0) {
                _ = ctx.status(400).json(errorJson("missing title query parameter"))
                return
            }
            _ = ctx.status(201).json(todoJson(store.create(title)))
        })

        app.get("/todos/:id", { ctx =>
            if (let Some(id) <- parseInt64Strict(ctx.params("id"))) {
                if (let Some(todo) <- store.find(id)) {
                    _ = ctx.json(todoJson(todo))
                } else {
                    _ = ctx.status(404).json(errorJson("todo not found"))
                }
                return
            }
            _ = ctx.status(400).json(errorJson("invalid id"))
        })

        app.patch("/todos/:id", { ctx =>
            if (let Some(id) <- parseInt64Strict(ctx.params("id"))) {
                let doneRaw = (ctx.queryFromUrl("done") ?? "").trimAscii().toAsciiLower()
                if (doneRaw != "true" && doneRaw != "false") {
                    _ = ctx.status(400).json(errorJson("done must be true or false"))
                    return
                }
                if (let Some(todo) <- store.setDone(id, doneRaw == "true")) {
                    _ = ctx.json(todoJson(todo))
                } else {
                    _ = ctx.status(404).json(errorJson("todo not found"))
                }
                return
            }
            _ = ctx.status(400).json(errorJson("invalid id"))
        })

        app.delete("/todos/:id", { ctx =>
            if (let Some(id) <- parseInt64Strict(ctx.params("id"))) {
                if (store.remove(id)) {
                    _ = ctx.sendStatus(204)
                } else {
                    _ = ctx.status(404).json(errorJson("todo not found"))
                }
                return
            }
            _ = ctx.status(400).json(errorJson("invalid id"))
        })

        let list0 = app.handleForTest("GET", "/todos")
        @Assert(list0.status, UInt16(200))
        @Assert(contains(list0.body, #""items":[]"#), true)

        let created = app.handleForTest("POST", "/todos?title=learn-ignite")
        @Assert(created.status, UInt16(201))
        @Assert(contains(created.body, #""id":1"#), true)
        @Assert(contains(created.body, #""title":"learn-ignite""#), true)
        @Assert(contains(created.body, #""done":false"#), true)

        let detail = app.handleForTest("GET", "/todos/1")
        @Assert(detail.status, UInt16(200))
        @Assert(contains(detail.body, #""id":1"#), true)

        let patched = app.handleForTest("PATCH", "/todos/1?done=true")
        @Assert(patched.status, UInt16(200))
        @Assert(contains(patched.body, #""done":true"#), true)

        let filtered = app.handleForTest("GET", "/todos?done=true")
        @Assert(filtered.status, UInt16(200))
        @Assert(contains(filtered.body, #""id":1"#), true)

        let removed = app.handleForTest("DELETE", "/todos/1")
        @Assert(removed.status, UInt16(204))

        let detailMissing = app.handleForTest("GET", "/todos/1")
        @Assert(detailMissing.status, UInt16(404))
        @Assert(contains(detailMissing.body, "todo not found"), true)
    }

    func contains(text: String, sub: String): Bool {
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

    func buildLargeAsciiPayload(): String {
        let line = "ignite-streaming-regression-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ\n"
        var out = ""
        var i: Int64 = 0
        while (i < 4096) {
            out += line
            i += 1
        }
        out
    }

    func writeTextFile(path: String, body: String): Unit {
        let file = File(path, OpenMode.Write)
        file.write(body.toArray())
        file.close()
    }

    func readTextFile(path: String): String {
        let file = File(path, OpenMode.Read)
        let buf = ArrayList<UInt8>()
        let tmp = Array<UInt8>(4096, repeat: 0)
        while (true) {
            let n = file.read(tmp)
            if (n <= 0) {
                break
            }
            for (i in 0..n) {
                buf.add(tmp[i])
            }
        }
        file.close()
        String.fromUtf8(buf.toArray())
    }

    func cacheStateLabel(bytes: ?Array<UInt8>): String {
        match (bytes) {
            case Some(_) => "hit"
            case None => "miss"
        }
    }

    func chooseUploadTestPort(offset: Int64): UInt16 {
        let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let raw = 46000 + ((nowMs + offset) % 10000)
        UInt16(raw)
    }

    func shutdownUploadTestApp(app: App, future: Future<Unit>): Unit {
        app.shutdown()
        try {
            let _ = future.get(Duration.second * 1)
        } catch (_: Exception) {
            future.cancel()
        }
    }

    func sendKnownLengthUploadWithRetry(
        port: UInt16,
        target: String,
        body: String,
        headers!: Array<(String, String)> = []
    ): UploadRawHttpResponse {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                return sendKnownLengthUpload(port, target, body, headers: headers)
            } catch (_: Exception) {
                if (attempt == 19) {
                    throw Exception("failed to connect upload test server: ${port} ${target}")
                }
                sleep(Duration.millisecond * 50)
                attempt += 1
            }
        }
        throw Exception("failed to connect upload test server: ${port} ${target}")
    }

    func sendKnownLengthUpload(
        port: UInt16,
        target: String,
        body: String,
        headers!: Array<(String, String)> = []
    ): UploadRawHttpResponse {
        let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
        socket.connect()
        try {
            let bodyBytes = body.toArray()
            var request = "POST ${target} HTTP/1.1\r\n"
            request += "host: 127.0.0.1:${port}\r\n"
            request += "content-length: ${bodyBytes.size}\r\n"
            request += "connection: close\r\n"
            for ((key, value) in headers) {
                request += "${key}: ${value}\r\n"
            }
            request += "\r\n"
            socket.write(request.toArray())
            socket.write(bodyBytes)
            readRawUploadResponse(socket)
        } finally {
            socket.close()
        }
    }

    func sendChunkedUploadWithRetry(
        port: UInt16,
        target: String,
        body: String,
        headers!: Array<(String, String)> = []
    ): UploadRawHttpResponse {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                return sendChunkedUpload(port, target, body, headers: headers)
            } catch (_: Exception) {
                if (attempt == 19) {
                    throw Exception("failed to connect chunked upload test server: ${port} ${target}")
                }
                sleep(Duration.millisecond * 50)
                attempt += 1
            }
        }
        throw Exception("failed to connect chunked upload test server: ${port} ${target}")
    }

    func sendRawDownloadWithRetry(
        port: UInt16,
        method: String,
        target: String,
        headers!: Array<(String, String)> = []
    ): UploadRawHttpResponse {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                return sendRawDownload(port, method, target, headers: headers)
            } catch (_: Exception) {
                if (attempt == 19) {
                    throw Exception("failed to connect download test server: ${port} ${target}")
                }
                sleep(Duration.millisecond * 50)
                attempt += 1
            }
        }
        throw Exception("failed to connect download test server: ${port} ${target}")
    }

    func sendRawDownload(
        port: UInt16,
        method: String,
        target: String,
        headers!: Array<(String, String)> = []
    ): UploadRawHttpResponse {
        let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
        socket.connect()
        try {
            var request = "${method} ${target} HTTP/1.1\r\n"
            request += "host: 127.0.0.1:${port}\r\n"
            request += "connection: close\r\n"
            for ((key, value) in headers) {
                request += "${key}: ${value}\r\n"
            }
            request += "\r\n"
            socket.write(request.toArray())
            readRawUploadResponse(socket)
        } finally {
            socket.close()
        }
    }

    func sendChunkedUpload(
        port: UInt16,
        target: String,
        body: String,
        headers!: Array<(String, String)> = []
    ): UploadRawHttpResponse {
        let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
        socket.connect()
        try {
            var request = "POST ${target} HTTP/1.1\r\n"
            request += "host: 127.0.0.1:${port}\r\n"
            request += "transfer-encoding: chunked\r\n"
            request += "connection: close\r\n"
            for ((key, value) in headers) {
                request += "${key}: ${value}\r\n"
            }
            request += "\r\n"
            socket.write(request.toArray())
            writeChunkedUploadBody(socket, body)
            readRawUploadResponse(socket)
        } finally {
            socket.close()
        }
    }

    func writeChunkedUploadBody(socket: TcpSocket, body: String): Unit {
        let bytes = body.toArray()
        var index: Int64 = 0
        let chunkSize: Int64 = 2048
        while (index < bytes.size) {
            let end = if (index + chunkSize < bytes.size) { index + chunkSize } else { bytes.size }
            let chunk = bytes[index..end]
            let header = int64ToHex(chunk.size) + "\r\n"
            socket.write(header.toArray())
            socket.write(chunk)
            socket.write("\r\n".toArray())
            index = end
        }
        socket.write("0\r\n\r\n".toArray())
    }

    func readRawUploadResponse(socket: TcpSocket): UploadRawHttpResponse {
        let buf = Array<UInt8>(4096, repeat: 0)
        var raw = ""
        while (true) {
            let n = socket.read(buf)
            if (n <= 0) {
                break
            }
            raw += String.fromUtf8(buf[..n])
        }
        parseRawUploadResponse(raw)
    }

    func parseRawUploadResponse(raw: String): UploadRawHttpResponse {
        let splitIdx = indexOfText(raw, "\r\n\r\n")
        let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
        let rawBody = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
        let lines = headerText.split("\r\n")
        if (lines.size == 0) {
            throw Exception("raw upload response missing status line")
        }

        let status = parseStatusCode(lines[0])
        let headers = HashMap<String, String>()
        var i: Int64 = 1
        while (i < lines.size) {
            let line = lines[i]
            let colonIdx = indexOfRune(line, r':')
            if (colonIdx > 0) {
                let key = line[..colonIdx].trimAscii().toAsciiLower()
                let value = line[colonIdx + 1..line.size].trimAscii()
                headers.add(key, value)
            }
            i += 1
        }

        let body = if ((headers.get("transfer-encoding") ?? "") == "chunked") {
            decodeChunkedBody(rawBody)
        } else {
            rawBody
        }
        UploadRawHttpResponse(status, headers, body)
    }

    func parseStatusCode(statusLine: String): UInt16 {
        let parts = statusLine.split(" ")
        if (parts.size < 2) {
            throw Exception("invalid status line: ${statusLine}")
        }
        let digits = parts[1].trimAscii()
        if (digits.size == 0) {
            throw Exception("invalid status code: ${statusLine}")
        }
        var value: Int64 = 0
        for (ch in digits.toRuneArray()) {
            if (ch < r'0' || ch > r'9') {
                throw Exception("invalid status code: ${statusLine}")
            }
            value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        }
        UInt16(value)
    }

    func decodeChunkedBody(raw: String): String {
        var idx: Int64 = 0
        var out = ""
        while (idx < raw.size) {
            let lineEnd = indexOfText(raw[idx..raw.size], "\r\n")
            if (lineEnd < 0) {
                throw Exception("invalid chunked response")
            }
            let sizeText = raw[idx..idx + lineEnd].trimAscii()
            let chunkSize = parseHexInt64(sizeText)
            idx += lineEnd + 2
            if (chunkSize == 0) {
                break
            }
            out += raw[idx..idx + chunkSize]
            idx += chunkSize + 2
        }
        out
    }

    func parseHexInt64(text: String): Int64 {
        let trimmed = text.trimAscii().toAsciiLower()
        if (trimmed.size == 0) {
            throw Exception("invalid hex integer")
        }
        var value: Int64 = 0
        for (ch in trimmed.toRuneArray()) {
            let digit = if (ch >= r'0' && ch <= r'9') {
                Int64(UInt32(ch) - UInt32(r'0'))
            } else if (ch >= r'a' && ch <= r'f') {
                Int64(UInt32(ch) - UInt32(r'a')) + 10
            } else {
                throw Exception("invalid hex integer")
            }
            value = value * 16 + digit
        }
        value
    }

    func int64ToHex(value: Int64): String {
        let hex = "0123456789abcdef".toRuneArray()
        if (value < 16) {
            return hex[value].toString()
        }
        int64ToHex(value / 16) + hex[value % 16].toString()
    }

    func sliceText(text: String, start: Int64, endExclusive: Int64): String {
        let runes = text.toRuneArray()
        var out = ""
        var i = start
        while (i < endExclusive && i < runes.size) {
            out += runes[i].toString()
            i += 1
        }
        out
    }

    func errorJson(message: String): String {
        #"{"error":"bad_request","message":""# + escapeJson(message) + #""}"#
    }

    func todoListJson(items: Array<TodoItem>): String {
        var out = #"{"items":["#
        for (i in 0..items.size) {
            if (i > 0) {
                out += ","
            }
            out += todoJson(items[i])
        }
        out += "]}"
        out
    }

    func todoJson(todo: TodoItem): String {
        #"{"id":"# + todo.id.toString() +
            #","title":""# + escapeJson(todo.title) +
            #"","done":"# + boolToJson(todo.done) + #"}"#
    }

    func boolToJson(v: Bool): String {
        if (v) { "true" } else { "false" }
    }

    func parseInt64Strict(text: String): ?Int64 {
        let raw = text.trimAscii()
        if (raw.size == 0) {
            return None
        }
        let chars = raw.toRuneArray()
        var i: Int64 = 0
        var sign: Int64 = 1
        if (chars[0] == r'-') {
            sign = -1
            i = 1
        } else if (chars[0] == r'+') {
            i = 1
        }
        if (i >= chars.size) {
            return None
        }
        var out: Int64 = 0
        while (i < chars.size) {
            let ch = chars[i]
            if (ch < r'0' || ch > r'9') {
                return None
            }
            out = out * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
            i += 1
        }
        Some(out * sign)
    }

    func escapeJson(input: String): String {
        var out = ""
        for (r in input.toRuneArray()) {
            if (r == r'\\') {
                out += "\\\\"
            } else if (r == r'"') {
                out += "\\\""
            } else if (r == r'\n') {
                out += "\\n"
            } else if (r == r'\r') {
                out += "\\r"
            } else if (r == r'\t') {
                out += "\\t"
            } else {
                out += r.toString()
            }
        }
        out
    }

    func indexOfText(text: String, target: String): Int64 {
        let a = text.toRuneArray()
        let b = target.toRuneArray()
        if (b.size == 0) { return 0 }
        if (a.size < b.size) { return -1 }
        var i: Int64 = 0
        while (i <= a.size - b.size) {
            var ok = true
            var j: Int64 = 0
            while (j < b.size) {
                if (a[i + j] != b[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) { return i }
            i += 1
        }
        -1
    }

    func indexOfRune(text: String, target: Rune): Int64 {
        let runes = text.toRuneArray()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] == target) {
                return i
            }
            i += 1
        }
        -1
    }
}

public class TodoItem {
    public let id: Int64
    public let title: String
    public var done: Bool

    public init(id: Int64, title: String, done: Bool) {
        this.id = id
        this.title = title
        this.done = done
    }
}

public class TodoStore {
    var items: ArrayList<TodoItem> = ArrayList<TodoItem>()
    var nextId: Int64 = 1

    public func create(title: String): TodoItem {
        let item = TodoItem(nextId, title, false)
        items.add(item)
        nextId += 1
        item
    }

    public func listAll(): Array<TodoItem> {
        items.toArray()
    }

    public func listByDone(done: Bool): Array<TodoItem> {
        let out = ArrayList<TodoItem>()
        for (item in items) {
            if (item.done == done) {
                out.add(item)
            }
        }
        out.toArray()
    }

    public func find(id: Int64): ?TodoItem {
        for (item in items) {
            if (item.id == id) {
                return Some(item)
            }
        }
        None
    }

    public func setDone(id: Int64, done: Bool): ?TodoItem {
        for (item in items) {
            if (item.id == id) {
                item.done = done
                return Some(item)
            }
        }
        None
    }

    public func remove(id: Int64): Bool {
        let kept = ArrayList<TodoItem>()
        var removed = false
        for (item in items) {
            if (item.id == id) {
                removed = true
            } else {
                kept.add(item)
            }
        }
        items = kept
        removed
    }
}

class UploadRawHttpResponse {
    let status: UInt16
    let headers: HashMap<String, String>
    let body: String

    init(status: UInt16, headers: HashMap<String, String>, body: String) {
        this.status = status
        this.headers = headers
        this.body = body
    }

    func header(name: String): ?String {
        headers.get(name.trimAscii().toAsciiLower())
    }
}
