package ignite.tests

import ignite.*
import ignite.governance.AuditConfig
import ignite.middleware.*
import std.collection.ArrayList

@Test
public class AuditProxyDetailTestSuite {
    @TestCase
    public func testAuditMiddlewareUsesProxyLocalsAsDetailWhenNoOtherDetailExists(): Unit {
        let auditLines = ArrayList<String>()
        let app = App(config: Config())
        app.use(auditMiddleware(
            config: AuditMiddlewareConfig(
                auditConfig: AuditConfig(
                    linuxStyle: false,
                    redactSensitiveFields: false,
                    output: { line => auditLines.add(line) }
                )
            )
        ))
        app.use({ ctx =>
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY, "temp-file-buffered")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY, "8192")
            ctx.next()
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY, "2")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY, "2")
        })
        app.post("/proxy-detail", { ctx =>
            let _ = ctx.status(201).sendString("ok")
        })

        let resp = app.handleForTest("POST", "/proxy-detail", body: "hello proxy")
        @Assert(resp.status, UInt16(201))
        @Assert(auditLines.size > 0, true)

        let auditPayload = auditLines[auditLines.size - 1]
        @Assert(
            contains(
                auditPayload,
                "\"detail\":\"proxyBodyMode=temp-file-buffered;proxyBodyBytes=8192;proxyResponseBodyMode=known-length-stream;proxyResponseBodyBytes=2;proxyDownstreamBodyMode=known-length-stream;proxyDownstreamBodyBytes=2\""
            ),
            true
        )
    }

    @TestCase
    public func testAuditMiddlewareAppendsProxyDetailAfterSecurityDetail(): Unit {
        let auditLines = ArrayList<String>()
        let app = App(config: Config())
        app.use(auditMiddleware(
            config: AuditMiddlewareConfig(
                auditConfig: AuditConfig(
                    linuxStyle: false,
                    redactSensitiveFields: false,
                    output: { line => auditLines.add(line) }
                )
            )
        ))
        app.use({ ctx =>
            ctx.setLocal("__ignite_sec_detail", "target=https://example.internal/up")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY, "temp-file-buffered-over-limit")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY, "16384")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY, "8192")
            ctx.next()
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY, "17")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY, "17")
        })
        app.post("/proxy-detail-append", { ctx =>
            let _ = ctx.status(413).sendString("Payload Too Large")
        })

        let resp = app.handleForTest("POST", "/proxy-detail-append", body: "large body")
        @Assert(resp.status, UInt16(413))
        @Assert(auditLines.size > 0, true)

        let auditPayload = auditLines[auditLines.size - 1]
        @Assert(
            contains(
                auditPayload,
                "\"detail\":\"target=https://example.internal/up;proxyBodyMode=temp-file-buffered-over-limit;proxyBodyBytes=16384;proxyBodyLimitBytes=8192;proxyResponseBodyMode=known-length-stream;proxyResponseBodyBytes=17;proxyDownstreamBodyMode=known-length-stream;proxyDownstreamBodyBytes=17\""
            ),
            true
        )
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
