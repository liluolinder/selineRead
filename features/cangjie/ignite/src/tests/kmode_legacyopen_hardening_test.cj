package ignite.tests

import ignite.*
import ignite.governance.*
import ignite.middleware.*

@Test
public class KModeLegacyOpenHardeningTestSuite {
    @TestCase
    public func testLegacyOpenWarningOnlyAppearsForEnabledLegacyPolicy(): Unit {
        let disabled = KModePolicy(enabled: false, legacyOpen: true)
        let closed = KModePolicy(enabled: true, legacyOpen: false)

        match (disabled.legacyOpenWarning()) {
            case Some(_) => throw Exception("disabled policy should not emit legacy-open warning")
            case None => ()
        }
        match (closed.legacyOpenWarning()) {
            case Some(_) => throw Exception("non-legacy policy should not emit legacy-open warning")
            case None => ()
        }
    }

    @TestCase
    public func testLegacyOpenWarningSummarizesLoopbackAndWildcardScopes(): Unit {
        let loopback = KModePolicy(
            enabled: true,
            legacyOpen: true,
            allowIPs: ["127.0.0.1", "::1"],
            capabilities: [Diag, Read]
        )
        let wildcard = KModePolicy(
            enabled: true,
            legacyOpen: true,
            allowIPs: ["*"],
            capabilities: [Diag, Admin]
        )

        let loopbackWarning = mustLegacyOpenWarning(loopback)
        let wildcardWarning = mustLegacyOpenWarning(wildcard)

        @Assert(loopback.ipAllowed("127.0.0.1:40123"), true)
        @Assert(loopback.ipAllowed("[::1]:40123"), true)
        @Assert(contains(loopbackWarning, "loopback-only compatibility lane"), true)
        @Assert(contains(loopbackWarning, "capabilities=diag,read"), true)
        @Assert(contains(wildcardWarning, "allowIPs=* wildcard compatibility lane"), true)
        @Assert(contains(wildcardWarning, "capabilities=diag,admin"), true)
    }

    @TestCase
    public func testLegacyOpenPolicyHonorsAllowIpsBeforeGrantingKmodeLocals(): Unit {
        let denied = App(config: Config())
        denied.use(kmodeMiddleware(KModePolicy(
            enabled: true,
            legacyOpen: true,
            allowIPs: ["10.0.0.5"],
            capabilities: [Diag]
        )))
        denied.get("/kmode", { ctx =>
            _ = ctx.sendString(ctx.getLocal("kmode") ?? "false")
        })

        let deniedResp = denied.handleForTest("GET", "/kmode")
        @Assert(deniedResp.status, UInt16(200))
        @Assert(deniedResp.body, "false")

        let wildcard = App(config: Config())
        wildcard.use(kmodeMiddleware(KModePolicy(
            enabled: true,
            legacyOpen: true,
            allowIPs: ["*"],
            capabilities: [Diag]
        )))
        wildcard.get("/kmode", { ctx =>
            _ = ctx.sendString(ctx.getLocal("kmode") ?? "false")
        })

        let wildcardResp = wildcard.handleForTest("GET", "/kmode")
        @Assert(wildcardResp.status, UInt16(200))
        @Assert(wildcardResp.body, "true")
    }

    @TestCase
    public func testBoolOverloadStillGrantsLoopbackLegacyCompatibility(): Unit {
        let app = App(config: Config())
        app.use(kmodeMiddleware(true))
        app.get("/kmode", { ctx =>
            let kmode = ctx.getLocal("kmode") ?? "false"
            let caps = ctx.getLocal("kmode_caps") ?? ""
            _ = ctx.sendString(kmode + "|" + caps)
        })

        let resp = app.handleForTest("GET", "/kmode")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "true|diag,read,write,admin")
    }

    @TestCase
    public func testHeaderBackedPolicyStillGrantsAuthorizedLoopbackRequest(): Unit {
        let app = App(config: Config())
        app.use(kmodeMiddleware(KModePolicy(
            enabled: true,
            legacyOpen: false,
            headerKey: "ignite-secret",
            allowIPs: ["127.0.0.1", "::1"],
            capabilities: [Diag, Read]
        )))
        app.get("/kmode", { ctx =>
            let kmode = ctx.getLocal("kmode") ?? "false"
            let caps = ctx.getLocal("kmode_caps") ?? ""
            _ = ctx.sendString(kmode + "|" + caps)
        })

        let coldResp = app.handleForTest("GET", "/kmode")
        @Assert(coldResp.status, UInt16(200))
        @Assert(coldResp.body, "false|")

        let authedResp = app.handleForTest(
            "GET",
            "/kmode",
            headers: [("X-KMode-Key", "ignite-secret")]
        )
        @Assert(authedResp.status, UInt16(200))
        @Assert(authedResp.body, "true|diag,read")
    }

    func mustLegacyOpenWarning(policy: KModePolicy): String {
        match (policy.legacyOpenWarning()) {
            case Some(message) => message
            case None => throw Exception("expected legacy-open warning")
        }
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
}
