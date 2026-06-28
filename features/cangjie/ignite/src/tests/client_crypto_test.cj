package ignite.tests

import std.collection.HashMap
import ignite.api2

@Test
public class ClientCryptoTestSuite {
    func buildConfig(kind: api2.ClientCryptoProviderKind): api2.ClientCryptoConfig {
        let ring = HashMap<String, Array<UInt8>>()
        ring.add("k1", "0123456789abcdef0123456789abcdef".toArray())
        api2.ClientCryptoConfig(
            providerKind: kind,
            activeKid: "k1",
            keyRing: ring,
            aeadAlgorithm: "AES-256-GCM"
        )
    }

    @TestCase
    public func testEncryptDecryptRoundTripAcrossProviders(): Unit {
        let payload = "{\"message\":\"hello\"}"
        let aad = "route:/v1/demo"

        let configs = [
            buildConfig(api2.ClientCryptoProviderKind.jinguiSSL),
            buildConfig(api2.ClientCryptoProviderKind.StdxFallback)
        ]
        for (cfg in configs) {
            try {
                let envelope = api2.encryptJsonToEnvelopeV1(cfg, payload, aadText: aad)
                let restored = api2.decryptEnvelopeV1ToJson(cfg, envelope, aadText: aad)
                @Assert(restored, payload)
            } catch (e: api2.ClientCryptoException) {
                if (
                    cfg.providerKind == api2.ClientCryptoProviderKind.jinguiSSL &&
                    e.code == api2.ClientCryptoErrorCode.CryptoUnavailable
                ) {
                    @Assert(true)
                } else {
                    @Fail("unexpected error: ${e.code.toString()} ${e.message}")
                }
            }
        }
    }

    @TestCase
    public func testTamperedTagFailsDecrypt(): Unit {
        let cfg = buildConfig(api2.ClientCryptoProviderKind.StdxFallback)
        let envelopeJson = api2.encryptJsonToEnvelopeV1(cfg, "{\"ok\":true}")
        let env = api2.EnvelopeV1.parse(envelopeJson)

        let tamperedTag = mutateToken(env.tag)
        let tampered = api2.EnvelopeV1(1, env.alg, env.kid, env.nonce, env.ct, tamperedTag).toJsonString()

        try {
            let _ = api2.decryptEnvelopeV1ToJson(cfg, tampered)
            @Fail("tampered tag should fail")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.DecryptFailed)
        }
    }

    @TestCase
    public func testKeyNotFoundError(): Unit {
        let cfg = buildConfig(api2.ClientCryptoProviderKind.StdxFallback)
        let envelopeJson = api2.encryptJsonToEnvelopeV1(cfg, "{\"ok\":true}")
        let env = api2.EnvelopeV1.parse(envelopeJson)
        let rewritten = api2.EnvelopeV1(1, env.alg, "k2", env.nonce, env.ct, env.tag).toJsonString()

        try {
            let _ = api2.decryptEnvelopeV1ToJson(cfg, rewritten)
            @Fail("unknown key should fail")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.KeyNotFound)
        }
    }

    @TestCase
    public func testBadEnvelopeRejects(): Unit {
        let cfg = buildConfig(api2.ClientCryptoProviderKind.StdxFallback)
        let badJson = "{\"v\":2,\"alg\":\"AES-256-GCM\",\"kid\":\"k1\",\"nonce\":\"x\",\"ct\":\"y\",\"tag\":\"z\"}"
        try {
            let _ = api2.decryptEnvelopeV1ToJson(cfg, badJson)
            @Fail("invalid version should fail")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.BadEnvelope)
        }
    }

    @TestCase
    public func testRandomHexLength(): Unit {
        let hex = api2.clientCryptoRandomHex(32)
        @Assert(hex.size, 32)
    }
}

func mutateToken(token: String): String {
    let runes = token.toRuneArray()
    if (runes.size == 0) {
        return "a"
    }
    var out = ""
    for (i in 0..runes.size) {
        if (i == 0) {
            if (runes[i] == r'a') {
                out += "b"
            } else {
                out += "a"
            }
        } else {
            out += runes[i].toString()
        }
    }
    out
}
