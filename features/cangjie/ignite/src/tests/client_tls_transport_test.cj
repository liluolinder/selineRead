package ignite.tests

import ignite.*
import ignite.client.*
import std.collection.ArrayList
import std.time.DateTime

@Test
public class ClientTlsTransportTestSuite {
    @TestCase
    public func testHttpsRequestToPlainHttpListenerIsObservedAsTlsFailure(): Unit {
        let app = App(config: Config())
        app.get("/tls-mismatch", { ctx =>
            ctx.sendString("plain-ok")
        })

        let port = choosePort(587)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            waitForPlainHttpReady(probeClient, "http://127.0.0.1:${port}/tls-mismatch")

            try {
                let _ = client.request()
                    .method("GET")
                    .url("https://127.0.0.1:${port}/tls-mismatch")
                    .header("x-ignite-log-case", "tls-handshake-mismatch")
                    .send()
                @Fail("https request to plain http listener should fail")
            } catch (e: Exception) {
                @Assert(e.message.size > 0, true)
            }

            @Assert(observedMessages.size, 1)
            @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
            @Assert(contains(observedMessages[0], "errorClass=TLS"), true)
            @Assert(contains(observedMessages[0], "phase=handshake"), true)
            @Assert(contains(observedMessages[0], "causeCode=tls_not_configured"), true)
            @Assert(contains(observedMessages[0], "backendId=stdx-http-client"), true)
            @Assert(contains(observedMessages[0], "providerId=tls:stdx-default"), true)
            @Assert(contains(observedMessages[0], "publicPath=stable-default"), true)
            @Assert(contains(observedMessages[0], "transportTags=scene=client,scheme=https"), true)
            @Assert(contains(observedMessages[0], "retryable=false"), true)
            @Assert(contains(observedMessages[0], "fallbackSuggested=false"), true)
            @Assert(contains(observedMessages[0], "connectionConsumed=false"), true)
            @Assert(contains(observedMessages[0], "retryCount=0"), true)
            @Assert(contains(observedMessages[0], "fields=case=tls-handshake-mismatch"), true)
        } finally {
            probeClient.close()
            client.close()
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    func waitForPlainHttpReady(client: RestClient, url: String): Unit {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                let resp = client.request()
                    .method("GET")
                    .url(url)
                    .send()
                if (resp.status == 200) {
                    let _ = resp.body()
                    return
                }
            } catch (_: Exception) {}
            if (attempt == 19) {
                throw Exception("failed to connect test server: ${url}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
        throw Exception("failed to connect test server: ${url}")
    }

    func choosePort(offset: Int64): UInt16 {
        let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let raw = 46000 + ((nowMs + offset) % 6000)
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
