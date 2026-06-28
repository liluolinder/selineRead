package ignite.tests

import ignite.*
import ignite.client.RestClient
import std.time.DateTime

@Test
public class HttpSemanticsMiddlewareCompatTestSuite {
    @TestCase
    public func test405OptionsAnd404FlowThroughGlobalMiddleware(): Unit {
        let app = App(config: Config())
        app.use({ ctx =>
            ctx.next()
            let _ = ctx.setHeader("x-ignite-mw", "hit")
        })
        app.get("/users/:id", { ctx =>
            let _ = ctx.sendString("ok")
        })

        let port = choosePort(118)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        try {
            assertRequestWithRetry(
                "http://127.0.0.1:${port}/users/42",
                "PUT",
                405,
                "GET",
                "hit",
                ""
            )

            assertRequestWithRetry(
                "http://127.0.0.1:${port}/users/42",
                "OPTIONS",
                204,
                "GET",
                "hit",
                ""
            )

            assertRequestWithRetry(
                "http://127.0.0.1:${port}/missing",
                "POST",
                404,
                "",
                "hit",
                "Cannot POST /missing"
            )
        } finally {
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    func assertRequestWithRetry(
        url: String,
        method: String,
        expectedStatus: UInt16,
        expectAllowContains: String,
        expectedMiddlewareHeader: String,
        expectedBodyContains: String
    ) {
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
                        .method(method)
                        .url(url)
                        .send()
                    @Assert(resp.status, expectedStatus)
                    @Assert(resp.header("x-ignite-mw") ?? "", expectedMiddlewareHeader)
                    if (expectAllowContains.size > 0) {
                        @Assert(contains(resp.header("allow") ?? "", expectAllowContains), true)
                    }
                    let body = resp.body()
                    if (expectedBodyContains.size > 0) {
                        @Assert(contains(body, expectedBodyContains), true)
                    }
                    return
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
        let raw = 42000 + ((nowMs + offset) % 10000)
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
