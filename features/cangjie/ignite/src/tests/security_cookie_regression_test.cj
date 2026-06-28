package ignite.tests

import ignite.{App, Config}
import ignite.middleware.{EncryptCookieConfig, encryptCookieMiddleware, encryptValue, decryptValue}
import ignite.security.*
import std.collection.HashMap

@Test
public class SecurityCookieRegressionTestSuite {
    @TestCase
    public func testOpenCookieRejectsInvalidBase64Payload(): Unit {
        let config = buildConfig("cookie-invalid-base64")
        let bad = "v1.!!!"
        try {
            _ = openCookieValueV1(config, bad, cookieName: "sid")
            @Fail("invalid payload should fail")
        } catch (e: SecurityException) {
            @Assert(e.code, SecurityErrorCode.BadEnvelope)
        }
    }

    @TestCase
    public func testOpenCookieRejectsMissingKeyInRing(): Unit {
        let sourceConfig = buildConfig("cookie-source-k1", kid: "k1")
        let sealed = sealCookieValueV1(sourceConfig, "payload", cookieName: "sid")

        let wrongKeyRing = HashMap<String, Array<UInt8>>()
        wrongKeyRing.add("k2", deriveKey32FromString("cookie-source-k2"))
        let wrongConfig = SecurityConfig(
            providerKind: StdxFallback,
            activeKid: "k2",
            keyRing: wrongKeyRing
        )

        try {
            _ = openCookieValueV1(wrongConfig, sealed, cookieName: "sid")
            @Fail("missing key id should fail")
        } catch (e: SecurityException) {
            @Assert(e.code, SecurityErrorCode.KeyNotFound)
        }
    }

    @TestCase
    public func testDecryptValueWrongKeyRecordsDecryptAndSignatureFailure(): Unit {
        resetSecurityMetrics()
        let encoded = encryptValue("dual-read-metrics", "metric-key-a")
        try {
            _ = decryptValue(encoded, "metric-key-b")
        } catch (_: Exception) {}
        let snap = securityMetricsSnapshot()
        @Assert(snap.decryptFailures, 1)
        @Assert(snap.signatureFailures, 1)
    }

    @TestCase
    public func testDecryptValueBadEnvelopeOnlyRecordsDecryptFailure(): Unit {
        resetSecurityMetrics()
        try {
            _ = decryptValue("v1.!!!", "metric-bad-envelope")
        } catch (_: Exception) {}
        let snap = securityMetricsSnapshot()
        @Assert(snap.decryptFailures, 1)
        @Assert(snap.signatureFailures, 0)
    }

    @TestCase
    public func testEncryptValueAlwaysWritesV1Envelope(): Unit {
        let encoded = encryptValue("new-write", "rolling-key")
        @Assert(startsWith(encoded, "v1."), true)
    }

    @TestCase
    public func testEncryptCookieMiddlewareDisablesLegacyDecryptByDefault(): Unit {
        let app = App(config: Config())
        app.use(
            encryptCookieMiddleware(
                EncryptCookieConfig(key: "k")
            )
        )
        app.get("/cookie", { ctx =>
            _ = ctx.sendString(ctx.cookies("sid") ?? "")
        })

        let resp = app.handleForTest(
            "GET",
            "/cookie",
            headers: [("cookie", "sid=Bw4MCggS")]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "Bw4MCggS")
    }

    func buildConfig(rawKey: String, kid!: String = "k1"): SecurityConfig {
        let ring = HashMap<String, Array<UInt8>>()
        ring.add(kid, deriveKey32FromString(rawKey))
        SecurityConfig(
            providerKind: StdxFallback,
            activeKid: kid,
            keyRing: ring
        )
    }

    func startsWith(s: String, prefix: String): Bool {
        if (s.size < prefix.size) {
            return false
        }
        let sRunes = s.toRuneArray()
        let pRunes = prefix.toRuneArray()
        var i: Int64 = 0
        while (i < pRunes.size) {
            if (sRunes[i] != pRunes[i]) {
                return false
            }
            i += 1
        }
        true
    }
}
