package ignite.tests

import ignite.*
import ignite.middleware.*
import std.collection.ArrayList

@Test
public class AccessLogProxyTestSuite {
    @TestCase
    public func testAccessLogIncludesProxyObserveFieldsWhenPresent(): Unit {
        let lines = ArrayList<String>()
        let app = App(config: Config())
        app.use(accessLogMiddleware(
            config: AccessLogConfig(
                output: { line => lines.add(line) },
                enableLatency: false,
                enableIP: false,
                enableUserAgent: false
            )
        ))
        app.use({ ctx =>
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY, "temp-file-buffered")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY, "16384")
            ctx.setLocal(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY, "8192")
            ctx.next()
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY, "2")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY, "known-length-stream")
            ctx.setLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY, "2")
        })
        app.post("/access-log-proxy", { ctx =>
            let _ = ctx.status(201).sendString("ok")
        })

        let resp = app.handleForTest("POST", "/access-log-proxy", body: "proxy-body")
        @Assert(resp.status, UInt16(201))
        @Assert(lines.size, 1)

        let line = lines[0]
        @Assert(contains(line, "POST /access-log-proxy"), true)
        @Assert(contains(line, "proxyBodyMode=temp-file-buffered"), true)
        @Assert(contains(line, "proxyBodyBytes=16384"), true)
        @Assert(contains(line, "proxyBodyLimitBytes=8192"), true)
        @Assert(contains(line, "proxyResponseBodyMode=known-length-stream"), true)
        @Assert(contains(line, "proxyResponseBodyBytes=2"), true)
        @Assert(contains(line, "proxyDownstreamBodyMode=known-length-stream"), true)
        @Assert(contains(line, "proxyDownstreamBodyBytes=2"), true)
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
