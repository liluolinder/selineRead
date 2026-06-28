package ignite.tests

import ignite.governance.AuditEvent

@Test
public class AuditSecurityFieldTestSuite {
    @TestCase
    public func testAuditEventContainsSecurityFields(): Unit {
        let event = AuditEvent()
        event.guardEvent = "kmode_failover"
        event.guardExitCause = "single_flight_skip"
        event.securityEvent = "decrypt_failed,signature_failed"
        event.securityCode = "DECRYPT_FAILED"
        event.securitySource = "encrypt_cookie"
        let json = event.toJson()

        @Assert(contains(json, "\"guardEvent\":\"kmode_failover\""), true)
        @Assert(contains(json, "\"guardExitCause\":\"single_flight_skip\""), true)
        @Assert(contains(json, "\"securityEvent\":\"decrypt_failed,signature_failed\""), true)
        @Assert(contains(json, "\"securityCode\":\"DECRYPT_FAILED\""), true)
        @Assert(contains(json, "\"securitySource\":\"encrypt_cookie\""), true)
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
