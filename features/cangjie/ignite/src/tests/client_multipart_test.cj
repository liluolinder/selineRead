package ignite.tests

import ignite.*
import ignite.client.*
import std.collection.ArrayList
import std.time.DateTime

@Test
public class ClientMultipartTestSuite {
    @TestCase
    public func testPostMultipartRoundTrip(): Unit {
        let app = App(config: Config())
        app.post("/upload", { ctx =>
            let meta = ctx.formValue("meta") ?? "-"
            if (let Some(file) <- ctx.formFile("file")) {
                ctx.sendString(
                    "meta=${meta};filename=${file.filename};size=${file.size()};contentType=${file.contentType}"
                )
            } else {
                ctx.status(400).sendString("missing-file")
            }
        })

        let port = choosePort(413)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 2
        )

        try {
            let fields = ArrayList<(String, String)>()
            fields.add(("meta", "upload-alpha"))
            let payload = "ignite-multipart-demo".toArray()
            let files = ArrayList<MultipartFile>()
            files.add(
                MultipartFile("file", "demo.txt", "text/plain", payload)
            )
            let resp = sendMultipartWithRetry(client, "http://127.0.0.1:${port}/upload", fields, files)
            @Assert(resp.status, 200)
            let body = resp.body()
            @Assert(contains(body, "meta=upload-alpha"), true)
            @Assert(contains(body, "filename=demo.txt"), true)
            @Assert(contains(body, "size=${payload.size}"), true)
            @Assert(contains(body, "contentType=text/plain"), true)
        } finally {
            client.close()
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    @TestCase
    public func testBodyMultipartFormAliasRoundTrip(): Unit {
        let app = App(config: Config())
        app.post("/upload-alias", { ctx =>
            let files = ctx.formFiles("file")
            let mode = ctx.formValue("mode") ?? "-"
            ctx.sendString("mode=${mode};count=${files.size}")
        })

        let port = choosePort(467)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 2
        )

        try {
            var attempt: Int64 = 0
            while (attempt < 20) {
                let fields = ArrayList<(String, String)>()
                fields.add(("mode", "alias"))
                let files = ArrayList<MultipartFile>()
                files.add(
                    MultipartFile("file", "a.txt", "text/plain", "A".toArray())
                )
                files.add(
                    MultipartFile("file", "b.txt", "text/plain", "B".toArray())
                )
                try {
                    let resp = client.request()
                        .method("POST")
                        .url("http://127.0.0.1:${port}/upload-alias")
                        .bodyMultipartForm(fields, files)
                        .send()
                    @Assert(resp.status, 200)
                    let body = resp.body()
                    @Assert(contains(body, "mode=alias"), true)
                    @Assert(contains(body, "count=2"), true)
                    return
                } catch (_: Exception) {
                    if (attempt == 19) {
                        throw Exception("failed to connect test server: /upload-alias")
                    }
                    sleep(Duration.millisecond * 50)
                    attempt += 1
                }
            }
            throw Exception("failed to connect test server: /upload-alias")
        } finally {
            client.close()
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    func sendMultipartWithRetry(
        client: RestClient,
        url: String,
        fields: ArrayList<(String, String)>,
        files: ArrayList<MultipartFile>
    ): ClientResponse {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                return client.postMultipart(url, fields, files)
            } catch (_: Exception) {
                if (attempt == 19) {
                    throw Exception("failed to connect test server: ${url}")
                }
                sleep(Duration.millisecond * 50)
                attempt += 1
            }
        }
        throw Exception("failed to connect test server: ${url}")
    }

    func choosePort(offset: Int64): UInt16 {
        let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let raw = 44000 + ((nowMs + offset) % 8000)
        UInt16(raw)
    }

    func contains(text: String, target: String): Bool {
        let t = text.toRuneArray()
        let p = target.toRuneArray()
        if (p.size == 0) {
            return true
        }
        if (t.size < p.size) {
            return false
        }
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
            if (ok) {
                return true
            }
            i += 1
        }
        false
    }
}
