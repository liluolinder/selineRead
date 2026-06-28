package ignite.tests

import ignite.security.*
import std.collection.ArrayList

@Test
public class SecurityX509VerifyTestSuite {
    @TestCase
    public func testX509VerifyDisabledSkipsValidation(): Unit {
        resetSecurityMetrics()
        let option = X509VerifyOption(enabled: false, requireHttps: true)
        verifyX509Target(option, "http://localhost:8828", source: "test")
        let snap = securityMetricsSnapshot()
        @Assert(snap.certRejects, 0)
        @Assert(true)
    }

    @TestCase
    public func testX509VerifyRequireHttpsRejectsHttp(): Unit {
        resetSecurityMetrics()
        let option = X509VerifyOption(enabled: true, requireHttps: true)
        assertVerifyFailed(option, "http://localhost:8828")
        let snap = securityMetricsSnapshot()
        @Assert(snap.certRejects, 1)
    }

    @TestCase
    public func testX509VerifyServerNameMismatchRejected(): Unit {
        resetSecurityMetrics()
        let option = X509VerifyOption(
            enabled: true,
            requireHttps: false,
            expectedServerName: "api.example.com"
        )
        assertVerifyFailed(option, "http://127.0.0.1:8828")
        let snap = securityMetricsSnapshot()
        @Assert(snap.certRejects, 1)
    }

    @TestCase
    public func testX509VerifyPinningRequiresHook(): Unit {
        resetSecurityMetrics()
        let option = X509VerifyOption(
            enabled: true,
            requireHttps: true,
            pinnedSha256: ["deadbeef"]
        )
        assertVerifyFailed(option, "https://localhost:443")
        let snap = securityMetricsSnapshot()
        @Assert(snap.certRejects, 1)
    }

    @TestCase
    public func testX509VerifyHookReceivesContextAndPasses(): Unit {
        resetSecurityMetrics()
        let captures = ArrayList<String>()
        let option = X509VerifyOption(
            enabled: true,
            requireHttps: true,
            expectedServerName: "localhost",
            pinnedSha256: ["abc123"],
            hook: { ctx =>
                captures.add(ctx.source)
                captures.add(ctx.scheme)
                captures.add(ctx.host)
                captures.add("${ctx.port}")
                captures.add(ctx.expectedServerName)
                captures.add(ctx.pinnedSha256[0])
                true
            }
        )

        verifyX509Target(option, "https://localhost:8828/health", source: "unit-test")
        @Assert(captures.size, 6)
        @Assert(captures[0], "unit-test")
        @Assert(captures[1], "https")
        @Assert(captures[2], "localhost")
        @Assert(captures[3], "8828")
        @Assert(captures[4], "localhost")
        @Assert(captures[5], "abc123")
        let snap = securityMetricsSnapshot()
        @Assert(snap.certRejects, 0)
    }

    @TestCase
    public func testSecurityMetricsManualCounters(): Unit {
        resetSecurityMetrics()
        recordDecryptFailure()
        recordSignatureFailure()
        recordCertReject()
        let snap = securityMetricsSnapshot()
        @Assert(snap.decryptFailures, 1)
        @Assert(snap.signatureFailures, 1)
        @Assert(snap.certRejects, 1)
    }

    func assertVerifyFailed(option: X509VerifyOption, targetUrl: String): Unit {
        try {
            verifyX509Target(option, targetUrl, source: "test")
            @Fail("verify should fail for ${targetUrl}")
        } catch (e: SecurityException) {
            @Assert(e.code, SecurityErrorCode.VerifyFailed)
        }
    }
}
