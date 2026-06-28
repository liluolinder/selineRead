package ignite.tests

import ignite.*
import ignite.client.RestClient
import ignite.middleware.*
import std.collection.ArrayList
import std.time.DateTime

@Test
public class LegacyCookieWarningTestSuite {
    @TestCase
    public func testLegacyDecryptWarningCanBeEnabled(): Unit {
        let warnings = ArrayList<String>()
        let app = App(config: Config())
        app.use(
            encryptCookieMiddleware(
                EncryptCookieConfig(
                    key: "k",
                    enableLegacyDecrypt: true,
                    legacyDecryptWarn: true,
                    legacyDecryptWarnHook: { msg => warnings.add(msg) }
                )
            )
        )
        app.get("/cookie", { ctx =>
            let _ = ctx.sendString(ctx.cookies("sid") ?? "")
        })

        let port = choosePort(211)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        try {
            let body = sendBodyWithRetry("http://127.0.0.1:${port}/cookie", "sid=Bw4MCggS")
            @Assert(body, "legacy")
        } finally {
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }

        @Assert(warnings.size, 1)
        @Assert(contains(warnings[0], "cookie=sid"), true)
    }

    @TestCase
    public func testLegacyDecryptWarningStaysOffBySwitch(): Unit {
        let warnings = ArrayList<String>()
        let app = App(config: Config())
        app.use(
            encryptCookieMiddleware(
                EncryptCookieConfig(
                    key: "k",
                    enableLegacyDecrypt: true,
                    legacyDecryptWarn: false,
                    legacyDecryptWarnHook: { msg => warnings.add(msg) }
                )
            )
        )
        app.get("/cookie", { ctx =>
            let _ = ctx.sendString(ctx.cookies("sid") ?? "")
        })

        let port = choosePort(233)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        try {
            let body = sendBodyWithRetry("http://127.0.0.1:${port}/cookie", "sid=Bw4MCggS")
            @Assert(body, "legacy")
        } finally {
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }

        @Assert(warnings.size, 0)
    }

    func sendBodyWithRetry(url: String, cookieHeader: String): String {
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 2
        )
        var attempt: Int64 = 0
        try {
            while (attempt < 20) {
                try {
                    let resp = client.request()
                        .method("GET")
                        .url(url)
                        .header("cookie", cookieHeader)
                        .send()
                    @Assert(resp.status, 200)
                    return resp.body()
                } catch (_: Exception) {
                    if (attempt == 19) {
                        throw Exception("failed to connect test server: ${url}")
                    }
                    sleep(Duration.millisecond * 50)
                    attempt += 1
                }
            }
        } finally {
            client.close()
        }
        throw Exception("failed to connect test server: ${url}")
    }

    func choosePort(offset: Int64): UInt16 {
        let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let raw = 43000 + ((nowMs + offset) % 10000)
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
