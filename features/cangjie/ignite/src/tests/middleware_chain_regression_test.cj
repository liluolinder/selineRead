package ignite.tests

import ignite.*
import ignite.client.RestClient
import ignite.middleware.*
import ignite.governance.AuditConfig
import ignite.security.{resetSecurityMetrics, securityMetricsSnapshot}
import std.collection.ArrayList
import std.time.DateTime

@Test
public class MiddlewareChainRegressionTestSuite {
    @TestCase
    public func testLoggerAuditRecoverSecurityChainOnRecoveredPanic(): Unit {
        resetSecurityMetrics()
        let loggerLines = ArrayList<String>()
        let auditLines = ArrayList<String>()

        let app = App(config: Config())

        let loggerConfig = LoggerConfig(
            output: { line => loggerLines.add(line) },
            enableEntityLog: true
        )
        loggerConfig.linuxStyle = false
        loggerConfig.enableSelfCheck = false
        app.use(loggerMiddleware(config: loggerConfig))

        let auditConfig = AuditConfig(
            linuxStyle: false,
            redactSensitiveFields: false,
            output: { line => auditLines.add(line) }
        )
        app.use(
            auditMiddleware(
                config: AuditMiddlewareConfig(auditConfig: auditConfig)
            )
        )
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    customHandler: { ctx, _ =>
                        let _ = ctx.status(500).sendString("Recovered")
                    }
                )
            )
        )
        app.use(encryptCookieMiddleware(EncryptCookieConfig(key: "chain-secret")))
        app.get("/panic", { _ => throw Exception("panic-route") })

        let port = choosePort(73)
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        try {
            let body = sendBodyWithRetry(
                "http://127.0.0.1:${port}/panic",
                "sid=${encryptValue("cookie-body", "chain-secret")}",
                500
            )
            @Assert(contains(body, "Recovered"), true)
        } finally {
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }

        @Assert(loggerLines.size > 0, true)
        @Assert(auditLines.size > 0, true)

        let auditPayload = auditLines[auditLines.size - 1]
        @Assert(contains(auditPayload, "\"securityEvent\":\"decrypt_failed,signature_failed\""), true)
        @Assert(contains(auditPayload, "\"securityCode\":\"DECRYPT_FAILED\""), true)
        @Assert(contains(auditPayload, "\"securitySource\":\"encrypt_cookie\""), true)
        @Assert(contains(auditPayload, "\"statusCode\":500"), true)

        let snap = securityMetricsSnapshot()
        @Assert(snap.decryptFailures > 0, true)
        @Assert(snap.signatureFailures > 0, true)
    }

    func sendBodyWithRetry(url: String, cookieHeader: String, expectedStatus: UInt16): String {
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 2
        )
        var attempt: Int64 = 0
        try {
            while (attempt < 20) {
                try {
                    let response = client.request()
                        .method("GET")
                        .url(url)
                        .header("cookie", cookieHeader)
                        .send()
                    @Assert(response.status, expectedStatus)
                    return response.body()
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
        let raw = 36000 + ((nowMs + offset) % 10000)
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
