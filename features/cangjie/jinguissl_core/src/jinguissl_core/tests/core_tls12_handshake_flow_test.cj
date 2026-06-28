package jinguissl_core.tests

import std.fs.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.*
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.rsa.*
import jinguissl_core.crypto.tls.*
import jinguissl_core.crypto.x509.{X509VerificationPolicy, x509ParsePem}

private let P256_GX: BigNum = BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296")
private let P256_GY: BigNum = BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")
private let P256_2G_X: BigNum = BigNum.fromHex("7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978")
private let P256_2G_Y: BigNum = BigNum.fromHex("07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1")
private let P384_GX: BigNum = BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7")
private let P384_GY: BigNum = BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F")

@Test
public class Tls12HandshakeFlowTestSuite {
    @TestCase
    public func testTls12RsaHandshakeFlowAndRecordRoundTrip(): Unit {
        let profile = FipsProfile.phase1Default()
        tls12HandshakeRequireAllowed(profile, Tls12KeyExchange.RSA)

        let clientHello = tls12BuildClientHello(Tls12KeyExchange.RSA)
        let serverHello = tls12BuildServerHello(clientHello, Tls12KeyExchange.RSA)
        let clientRandom = tls12ExtractClientRandom(clientHello)
        let serverRandom = tls12ExtractServerRandom(serverHello)
        @Assert(clientRandom.size, 32)
        @Assert(serverRandom.size, 32)

        let serverPrivateKey = loadRsa2048PrivateKey()
        let (clientKeyExchange, clientPreMaster) = tls12BuildRsaClientKeyExchange(serverPrivateKey.publicKey)
        let serverPreMaster = tls12ProcessRsaClientKeyExchange(serverPrivateKey, clientKeyExchange)
        @Assert(clientPreMaster, serverPreMaster)

        let clientSecrets = tls12DeriveSecretsFromPreMaster(clientPreMaster, clientRandom, serverRandom)
        let serverSecrets = tls12DeriveSecretsFromPreMaster(serverPreMaster, clientRandom, serverRandom)
        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteKey, serverSecrets.clientWriteKey)
        @Assert(clientSecrets.serverWriteKey, serverSecrets.serverWriteKey)

        let clientRecord = tls12CreateClientRecordLayer(clientSecrets)
        let serverRecord = tls12CreateServerRecordLayer(serverSecrets)

        let encrypted = clientRecord.seal(ApplicationData, "tls12-rsa-flow".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls12-rsa-flow".toArray())
    }

    @TestCase
    public func testTls12EcdheHandshakeFlowAndRecordRoundTrip(): Unit {
        let profile = FipsProfile.phase1Default()
        tls12HandshakeRequireAllowed(profile, Tls12KeyExchange.ECDHE_P256)

        let clientHello = tls12BuildClientHello(Tls12KeyExchange.ECDHE_P256)
        let serverHello = tls12BuildServerHello(clientHello, Tls12KeyExchange.ECDHE_P256)
        let clientRandom = tls12ExtractClientRandom(clientHello)
        let serverRandom = tls12ExtractServerRandom(serverHello)

        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)

        let serverKeyExchange = tls12BuildEcdheServerKeyExchange(serverPublic)
        let parsedServerPublic = tls12ParseEcdheServerKeyExchange(serverKeyExchange)

        let clientKeyExchange = tls12BuildEcdheClientKeyExchange(clientPublic)
        let parsedClientPublic = tls12ParseEcdheClientKeyExchange(clientKeyExchange)

        let clientSecrets = tls12DeriveSecretsFromEcdhe(clientPrivate, parsedServerPublic, clientRandom, serverRandom)
        let serverSecrets = tls12DeriveSecretsFromEcdhe(serverPrivate, parsedClientPublic, clientRandom, serverRandom)
        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteIv, serverSecrets.clientWriteIv)
        @Assert(clientSecrets.serverWriteIv, serverSecrets.serverWriteIv)

        let clientRecord = tls12CreateClientRecordLayer(clientSecrets)
        let serverRecord = tls12CreateServerRecordLayer(serverSecrets)

        let encrypted = clientRecord.seal(ApplicationData, "tls12-ecdhe-flow".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls12-ecdhe-flow".toArray())
    }

    @TestCase
    public func testTls12EcdheP384HandshakeFlowAndRecordRoundTrip(): Unit {
        let profile = FipsProfile.phase1Default()
        tls12HandshakeRequireAllowed(profile, Tls12KeyExchange.ECDHE_P384)

        let clientHello = tls12BuildClientHello(Tls12KeyExchange.ECDHE_P384)
        let serverHello = tls12BuildServerHello(clientHello, Tls12KeyExchange.ECDHE_P384)
        let clientRandom = tls12ExtractClientRandom(clientHello)
        let serverRandom = tls12ExtractServerRandom(serverHello)

        let serverPrivate = EcPrivateKey(P384, BigNum.one())
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let clientPrivate = EcPrivateKey(P384, BigNum.one())
        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)

        let serverKeyExchange = tls12BuildEcdheServerKeyExchange(serverPublic)
        let parsedServerPublic = tls12ParseEcdheServerKeyExchange(serverKeyExchange)

        let clientKeyExchange = tls12BuildEcdheClientKeyExchange(clientPublic)
        let parsedClientPublic = tls12ParseEcdheClientKeyExchange(clientKeyExchange)

        let clientSecrets = tls12DeriveSecretsFromEcdhe(clientPrivate, parsedServerPublic, clientRandom, serverRandom)
        let serverSecrets = tls12DeriveSecretsFromEcdhe(serverPrivate, parsedClientPublic, clientRandom, serverRandom)
        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteIv, serverSecrets.clientWriteIv)
        @Assert(clientSecrets.serverWriteIv, serverSecrets.serverWriteIv)

        let clientRecord = tls12CreateClientRecordLayer(clientSecrets)
        let serverRecord = tls12CreateServerRecordLayer(serverSecrets)

        let encrypted = clientRecord.seal(ApplicationData, "tls12-ecdhe-p384-flow".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls12-ecdhe-p384-flow".toArray())
    }

    @TestCase
    public func testTls12EcdheHandshakeFlowWithChacha20Poly1305RecordLayer(): Unit {
        let profile = FipsProfile.fromText("TLS1.2\nCHACHA20-POLY1305\nECDH")
        tls12HandshakeRequireAllowed(profile, Tls12KeyExchange.ECDHE_P256, algorithm: CHACHA20_POLY1305)

        let clientHello = tls12BuildClientHello(Tls12KeyExchange.ECDHE_P256)
        let serverHello = tls12BuildServerHello(clientHello, Tls12KeyExchange.ECDHE_P256)
        let clientRandom = tls12ExtractClientRandom(clientHello)
        let serverRandom = tls12ExtractServerRandom(serverHello)

        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)

        let serverKeyExchange = tls12BuildEcdheServerKeyExchange(serverPublic)
        let parsedServerPublic = tls12ParseEcdheServerKeyExchange(serverKeyExchange)

        let clientKeyExchange = tls12BuildEcdheClientKeyExchange(clientPublic)
        let parsedClientPublic = tls12ParseEcdheClientKeyExchange(clientKeyExchange)

        let clientSecrets = tls12DeriveSecretsFromEcdhe(
            clientPrivate,
            parsedServerPublic,
            clientRandom,
            serverRandom,
            keyLen: 32,
            ivLen: 12
        )
        let serverSecrets = tls12DeriveSecretsFromEcdhe(
            serverPrivate,
            parsedClientPublic,
            clientRandom,
            serverRandom,
            keyLen: 32,
            ivLen: 12
        )

        let clientRecord = tls12CreateClientRecordLayerChacha20Poly1305(clientSecrets)
        let serverRecord = tls12CreateServerRecordLayerChacha20Poly1305(serverSecrets)
        let encrypted = clientRecord.seal(ApplicationData, "tls12-ecdhe-chacha-flow".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls12-ecdhe-chacha-flow".toArray())
    }

    @TestCase
    public func testTls12ClientHelloCarriesSniAlpnAndOcspExtensions(): Unit {
        let clientHelloEncoded = tls12BuildClientHello(
            Tls12KeyExchange.ECDHE_P256,
            serverName: TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"],
            requestOcspStapling: true
        )
        let hello = tlsDecodeClientHelloHandshake(clientHelloEncoded)

        let sniExt = tlsFindExtension(hello.extensions, TLS_EXT_SERVER_NAME) ?? throw Exception("missing SNI extension")
        let sniHosts = tlsParseServerNameExtension(sniExt)
        @Assert(sniHosts.size, 1)
        @Assert(sniHosts[0], TEST_HOST_API)

        let alpnExt = tlsFindExtension(hello.extensions, TLS_EXT_ALPN) ?? throw Exception("missing ALPN extension")
        let alpn = tlsParseAlpnExtension(alpnExt)
        @Assert(alpn, ["h2", "http/1.1"])

        let ocspExt = tlsFindExtension(hello.extensions, TLS_EXT_STATUS_REQUEST) ?? throw Exception("missing OCSP status_request extension")
        let ocsp = tlsParseOcspStatusRequestExtension(ocspExt)
        @Assert(ocsp.statusType, TLS_STATUS_REQUEST_TYPE_OCSP)
        @Assert(ocsp.responderIds.size, 0)
        @Assert(ocsp.requestExtensions.size, 0)
    }

    @TestCase
    public func testTls12HandshakeRejectMalformedInputs(): Unit {
        let serverPrivateKey = loadRsa2048PrivateKey()
        let (clientKeyExchange, _) = tls12BuildRsaClientKeyExchange(serverPrivateKey.publicKey)
        let tampered = clientKeyExchange.clone()
        tampered[tampered.size - 1] = UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01)
        try {
            _ = tls12ProcessRsaClientKeyExchange(serverPrivateKey, tampered)
            @Fail("tampered RSA ClientKeyExchange should fail to decrypt")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let brokenServerKeyExchange = tlsEncodeServerKeyExchangeHandshake(
            TlsKeyExchangeMessage([UInt8(0x01), UInt8(0x00), UInt8(0x17), UInt8(0x02), UInt8(0x04), UInt8(0x00)])
        )
        try {
            _ = tls12ParseEcdheServerKeyExchange(brokenServerKeyExchange)
            @Fail("invalid ECDHE ServerKeyExchange point should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let validServerKeyExchange = tls12BuildEcdheServerKeyExchange(EcPublicKey(P256, P256_GX, P256_GY))
        let unsupportedCurveServerKeyExchange = validServerKeyExchange.clone()
        unsupportedCurveServerKeyExchange[5] = UInt8(0x00)
        unsupportedCurveServerKeyExchange[6] = UInt8(0x19)
        try {
            _ = tls12ParseEcdheServerKeyExchange(unsupportedCurveServerKeyExchange)
            @Fail("unsupported TLS12 ECDHE named curve should surface as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testTls12HandshakeComplianceGate(): Unit {
        let blocked = FipsProfile.fromText("TLS1.2\nAES-GCM")
        try {
            tls12HandshakeRequireAllowed(blocked, Tls12KeyExchange.RSA)
            @Fail("TLS12 RSA handshake should require RSA in profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let blockedEcdh = FipsProfile.fromText("TLS1.2\nAES-GCM\nRSA")
        try {
            tls12HandshakeRequireAllowed(blockedEcdh, Tls12KeyExchange.ECDHE_P256)
            @Fail("TLS12 ECDHE handshake should require ECDH in profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
        try {
            tls12HandshakeRequireAllowed(blockedEcdh, Tls12KeyExchange.ECDHE_P384)
            @Fail("TLS12 ECDHE-P384 handshake should require ECDH in profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let chachaAllowed = FipsProfile.fromText("TLS1.2\nCHACHA20-POLY1305\nECDH")
        tls12HandshakeRequireAllowed(chachaAllowed, Tls12KeyExchange.ECDHE_P256, algorithm: CHACHA20_POLY1305)

        try {
            tls12HandshakeRequireAllowed(chachaAllowed, Tls12KeyExchange.RSA, algorithm: CHACHA20_POLY1305)
            @Fail("TLS12 RSA mode should still require RSA permission with CHACHA20-POLY1305")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }

    @TestCase
    public func testTls12CertificateHandshakeParseAndVerify(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let encoded = tls12BuildCertificateHandshakeFromDerChain([leaf.der, intermediate.der])
        let parsedChain = tls12ParseCertificateChainFromHandshake(encoded)
        @Assert(parsedChain.size, 2)
        @Assert(parsedChain[0].subject.commonName(), TEST_HOST_WWW)
        @Assert(parsedChain[1].subject.commonName(), "Policy Intermediate")

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let verified = tls12VerifyCertificateChainFromHandshake(encoded, policy)
        @Assert(verified.chain.size, 3)
        @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")
    }
}

private func loadRsa2048PrivateKey(): RsaPrivateKey {
    let path = "testdata/stage3/rsa_params_sample.txt"
    if (!exists(path)) {
        throw Exception("missing RSA vector file: ${path}")
    }

    let lines = String.fromUtf8(File.readFrom(path)).replace("\r", "\n").split('\n')
    var inTarget = false
    var n = ""
    var e = ""
    var d = ""

    for (rawLine in lines) {
        let line = rawLine.trimAscii()
        if (line.size == 0 || line.startsWith("#")) {
            continue
        }
        if (let Some(pos) <- line.indexOf("=")) {
            let key = line[..pos].trimAscii()
            let value = line[(pos + 1)..].trimAscii()
            if (key == "Vector") {
                if (inTarget && value != "RSA-2048") {
                    break
                }
                inTarget = (value == "RSA-2048")
                continue
            }
            if (!inTarget) {
                continue
            }
            if (key == "N") {
                n = value
            } else if (key == "E") {
                e = value
            } else if (key == "D") {
                d = value
            }
        }
    }

    if (n.size == 0 || e.size == 0 || d.size == 0) {
        throw Exception("RSA-2048 key vector is incomplete")
    }

    rsaPrivateKeyFromHex(n, e, d)
}

private func readText(path: String): String {
    if (!exists(path)) {
        throw Exception("missing test file: ${path}")
    }
    String.fromUtf8(File.readFrom(path))
}
