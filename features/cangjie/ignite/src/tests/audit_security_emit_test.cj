package ignite.tests

import ignite.governance.{AuditEvent, AuditConfig, emitAudit}
import std.collection.ArrayList

@Test
public class AuditSecurityEmitTestSuite {
    @TestCase
    public func testEmitAuditLinuxLineIncludesSecuritySuffix(): Unit {
        let lines = ArrayList<String>()
        let event = AuditEvent()
        event.requestId = "req-sec-1"
        event.action = "GET /panic"
        event.route = "/panic"
        event.result = "deny"
        event.riskLevel = 2
        event.statusCode = 503
        event.latencyMs = 9
        event.guardEvent = "kmode_failover"
        event.guardExitCause = "matched"
        event.securityEvent = "decrypt_failed,signature_failed"
        event.securityCode = "DECRYPT_FAILED"
        event.securitySource = "encrypt_cookie"

        emitAudit(
            event,
            config: AuditConfig(
                linuxStyle: true,
                redactSensitiveFields: false,
                output: { line => lines.add(line) }
            )
        )

        @Assert(lines.size, 2)
        @Assert(contains(lines[0], "guardEvent=kmode_failover"), true)
        @Assert(contains(lines[0], "guardExitCause=matched"), true)
        @Assert(contains(lines[0], "securityEvent=decrypt_failed,signature_failed"), true)
        @Assert(contains(lines[0], "securityCode=DECRYPT_FAILED"), true)
        @Assert(contains(lines[0], "securitySource=encrypt_cookie"), true)
        @Assert(contains(lines[1], "\"guardEvent\":\"kmode_failover\""), true)
        @Assert(contains(lines[1], "\"guardExitCause\":\"matched\""), true)
        @Assert(contains(lines[1], "\"securityEvent\":\"decrypt_failed,signature_failed\""), true)
    }

    @TestCase
    public func testEmitAuditWithoutLinuxStyleStillKeepsSecurityFields(): Unit {
        let lines = ArrayList<String>()
        let event = AuditEvent()
        event.guardEvent = "kmode_failover"
        event.guardExitCause = "cooldown_skip"
        event.securityEvent = "cert_rejected"
        event.securityCode = "VERIFY_FAILED"
        event.securitySource = "proxy"

        emitAudit(
            event,
            config: AuditConfig(
                linuxStyle: false,
                redactSensitiveFields: false,
                output: { line => lines.add(line) }
            )
        )

        @Assert(lines.size, 1)
        @Assert(contains(lines[0], "\"guardEvent\":\"kmode_failover\""), true)
        @Assert(contains(lines[0], "\"guardExitCause\":\"cooldown_skip\""), true)
        @Assert(contains(lines[0], "\"securityEvent\":\"cert_rejected\""), true)
        @Assert(contains(lines[0], "\"securityCode\":\"VERIFY_FAILED\""), true)
        @Assert(contains(lines[0], "\"securitySource\":\"proxy\""), true)
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
