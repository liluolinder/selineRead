package ignite.tests

import ignite.security.*
import ignite.middleware.{encryptValue, decryptValue}
import std.collection.HashMap

@Test
public class SecurityTestSuite {
    @TestCase
    public func testSecurityCookieEnvelopeRoundTrip(): Unit {
        let keyRing = HashMap<String, Array<UInt8>>()
        keyRing.add("k1", Array<UInt8>(32, repeat: UInt8(7)))
        let config = SecurityConfig(
            providerKind: StdxFallback,
            activeKid: "k1",
            keyRing: keyRing
        )

        let sealed = sealCookieValueV1(config, "hello-security", cookieName: "sid")
        @Assert(isCookieEnvelopeV1(sealed), true)

        let opened = openCookieValueV1(config, sealed, cookieName: "sid")
        @Assert(opened, "hello-security")
    }

    @TestCase
    public func testSecurityCookieEnvelopeTamperRejected(): Unit {
        let keyRing = HashMap<String, Array<UInt8>>()
        keyRing.add("k1", Array<UInt8>(32, repeat: UInt8(9)))
        let config = SecurityConfig(
            providerKind: StdxFallback,
            activeKid: "k1",
            keyRing: keyRing
        )

        let sealed = sealCookieValueV1(config, "payload", cookieName: "token")
        let tampered = mutateEnvelopePayload(sealed)

        try {
            _ = openCookieValueV1(config, tampered, cookieName: "token")
            @Fail("tampered envelope should fail")
        } catch (_: SecurityException) {
            @Assert(true)
        }
    }

    @TestCase
    public func testEncryptValueDualReadMigration(): Unit {
        let encrypted = encryptValue("legacy-dual-read", "migration-key")
        let decrypted = decryptValue(encrypted, "migration-key")
        @Assert(decrypted, "legacy-dual-read")

        // legacy XOR+Base64 value for plaintext "legacy" with key "k"
        let legacyEncoded = "Bw4MCggS"
        let legacyDecrypted = decryptValue(legacyEncoded, "k")
        @Assert(legacyDecrypted, "legacy")
    }

    @TestCase
    public func testRandomHexLength(): Unit {
        let hex = randomHex(32)
        @Assert(hex.size, 32)
    }

    func mutateEnvelopePayload(value: String): String {
        let runes = value.toRuneArray()
        if (runes.size <= 6) {
            return value + "A"
        }
        let out = Array<Rune>(runes.size, repeat: r'A')
        var i = 0
        while (i < runes.size) {
            out[i] = runes[i]
            i += 1
        }
        let idx = 5
        out[idx] = if (out[idx] == r'A') { r'B' } else { r'A' }
        var s = ""
        for (ch in out) {
            s += ch.toString()
        }
        s
    }
}
