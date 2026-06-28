package jinguissl_core.tests

import std.collection.ArrayList
import std.fs.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.*
import jinguissl_core.crypto.digest.sha256
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.tls.*
import jinguissl_core.crypto.x25519.{x25519DeriveSharedSecret, x25519PublicFromPrivate}
import jinguissl_core.crypto.x509.{X509SelfSignedConfig, X509VerificationPolicy, x509CreateSelfSignedEcCertificate, x509CreateSelfSignedRsaCertificate, x509ParseEcPrivateKeyPkcs8Pem, x509ParsePem, x509ParseRsaPrivateKeyPkcs8Pem}

private let P256_GX: BigNum = BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296")
private let P256_GY: BigNum = BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")
private let P256_2G_X: BigNum = BigNum.fromHex("7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978")
private let P256_2G_Y: BigNum = BigNum.fromHex("07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1")
private let P384_GX: BigNum = BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7")
private let P384_GY: BigNum = BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F")
private let TLS13_KEY_SHARE_EXTENSION_TYPE: Int64 = 0x0033
private let TLS13_SUPPORTED_GROUPS_EXTENSION_TYPE: Int64 = 0x000a
private let TLS13_SUPPORTED_VERSIONS_EXTENSION_TYPE: Int64 = 0x002b
private let TLS13_GROUP_SECP256R1_TEST: Int64 = 0x0017
private let TLS13_GROUP_X25519_TEST: Int64 = 0x001d
private let TLS13_VERSION_TEST: Int64 = 0x0304

@Test
public class Tls13HandshakeFlowTestSuite {
    @TestCase
    public func testTls13BuildHelloAndExtractKeyShare(): Unit {
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)
        let extractedClientShare = tls13ExtractClientKeyShare(clientHello)
        @Assert(extractedClientShare.x.toHex(), P256_2G_X.toHex())
        @Assert(extractedClientShare.y.toHex(), P256_2G_Y.toHex())

        let serverHello = tls13BuildServerHelloForEcdhe(clientHello, serverPublic)
        let extractedServerShare = tls13ExtractServerKeyShare(serverHello)
        @Assert(extractedServerShare.x.toHex(), P256_GX.toHex())
        @Assert(extractedServerShare.y.toHex(), P256_GY.toHex())

        let decodedServerHello = tlsDecodeServerHelloHandshake(serverHello)
        @Assert(decodedServerHello.cipherSuite, 0x1301)
    }

    @TestCase
    public func testTls13BuildHelloAndExtractKeyShareP384(): Unit {
        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)

        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)
        let extractedClientShare = tls13ExtractClientKeyShare(clientHello)
        @Assert(extractedClientShare.curve.toString(), "P-384")
        @Assert(extractedClientShare.x.toHex(), P384_GX.toHex())
        @Assert(extractedClientShare.y.toHex(), P384_GY.toHex())

        let serverHello = tls13BuildServerHelloForEcdhe(clientHello, serverPublic)
        let extractedServerShare = tls13ExtractServerKeyShare(serverHello)
        @Assert(extractedServerShare.curve.toString(), "P-384")
        @Assert(extractedServerShare.x.toHex(), P384_GX.toHex())
        @Assert(extractedServerShare.y.toHex(), P384_GY.toHex())

        let decodedServerHello = tlsDecodeServerHelloHandshake(serverHello)
        @Assert(decodedServerHello.cipherSuite, 0x1301)
    }

    @TestCase
    public func testTls13EcdheFlowRecordRoundTrip(): Unit {
        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)
        let serverHello = tls13BuildServerHelloForEcdhe(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromEcdhe(
            clientPrivate,
            tls13ExtractServerKeyShare(serverHello),
            transcriptHash
        )
        let serverSecrets = tls13DeriveSecretsFromEcdhe(
            serverPrivate,
            tls13ExtractClientKeyShare(clientHello),
            transcriptHash
        )

        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteKey, serverSecrets.clientWriteKey)
        @Assert(clientSecrets.serverWriteIv, serverSecrets.serverWriteIv)

        let finishedClient = tls13ComputeFinishedVerifyData(clientSecrets.clientHsTrafficSecret, transcriptHash)
        let finishedServerView = tls13ComputeFinishedVerifyData(serverSecrets.clientHsTrafficSecret, transcriptHash)
        @Assert(finishedClient, finishedServerView)

        let clientRecord = tls13CreateClientRecordLayer(clientSecrets)
        let serverRecord = tls13CreateServerRecordLayer(serverSecrets)
        let encrypted = clientRecord.seal(ApplicationData, "tls13-ecdhe-data".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls13-ecdhe-data".toArray())
    }

    @TestCase
    public func testTls13EcdheP384FlowRecordRoundTrip(): Unit {
        let profile = FipsProfile.fromText("TLS1.3\nAES-GCM\nECDH")
        tls13HandshakeRequireAllowed(profile, Tls13HandshakeMode.ECDHE_1RTT, ecdheCurve: P384)

        let clientPrivate = EcPrivateKey(P384, BigNum.one())
        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let serverPrivate = EcPrivateKey(P384, BigNum.one())
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)

        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)
        let serverHello = tls13BuildServerHelloForEcdhe(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromEcdhe(
            clientPrivate,
            tls13ExtractServerKeyShare(serverHello),
            transcriptHash
        )
        let serverSecrets = tls13DeriveSecretsFromEcdhe(
            serverPrivate,
            tls13ExtractClientKeyShare(clientHello),
            transcriptHash
        )

        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteKey, serverSecrets.clientWriteKey)
        @Assert(clientSecrets.serverWriteIv, serverSecrets.serverWriteIv)

        let clientRecord = tls13CreateClientRecordLayer(clientSecrets)
        let serverRecord = tls13CreateServerRecordLayer(serverSecrets)
        let encrypted = clientRecord.seal(ApplicationData, "tls13-ecdhe-p384-data".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls13-ecdhe-p384-data".toArray())
    }

    @TestCase
    public func testTls13X25519FlowRecordRoundTrip(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        @Assert(bytesToHexLower(clientPublic), "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
        @Assert(bytesToHexLower(serverPublic), "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")

        let clientHello = tls13BuildClientHelloX25519(clientPublic)
        let serverHello = tls13BuildServerHelloForX25519(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let extractedClient = tls13ExtractClientX25519KeyShare(clientHello)
        let extractedServer = tls13ExtractServerX25519KeyShare(serverHello)
        @Assert(extractedClient, clientPublic)
        @Assert(extractedServer, serverPublic)

        let clientSecrets = tls13DeriveSecretsFromX25519(clientPrivate, extractedServer, transcriptHash)
        let serverSecrets = tls13DeriveSecretsFromX25519(serverPrivate, extractedClient, transcriptHash)
        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteKey, serverSecrets.clientWriteKey)
        @Assert(clientSecrets.serverWriteIv, serverSecrets.serverWriteIv)

        let shared = x25519DeriveSharedSecret(clientPrivate, serverPublic)
        @Assert(bytesToHexLower(shared), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742")

        let clientRecord = tls13CreateClientRecordLayer(clientSecrets)
        let serverRecord = tls13CreateServerRecordLayer(serverSecrets)
        let encrypted = clientRecord.seal(ApplicationData, "tls13-x25519-data".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls13-x25519-data".toArray())
    }

    @TestCase
    public func testTls13ClientHelloBuildersCarryInteropExtensions(): Unit {
        let ecdhePublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let ecdheHello = tlsDecodeClientHelloHandshake(tls13BuildClientHelloEcdhe(ecdhePublic))
        assertTls13ClientHelloInteropExtensions(ecdheHello, [TLS13_GROUP_SECP256R1_TEST])

        let x25519Private = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let x25519Public = x25519PublicFromPrivate(x25519Private)
        let x25519Hello = tlsDecodeClientHelloHandshake(tls13BuildClientHelloX25519(x25519Public))
        assertTls13ClientHelloInteropExtensions(x25519Hello, [TLS13_GROUP_X25519_TEST])
    }

    @TestCase
    public func testTls13X25519CipherSuiteSelectionAndRecordLayerHandle(): Unit {
        @Assert(TLS13_CIPHER_SUITE_AES_128_GCM_SHA256, 0x1301)
        @Assert(TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256, 0x1303)
        @Assert(tls13CipherSuiteAeadAlgorithm(TLS13_CIPHER_SUITE_AES_128_GCM_SHA256).toString(), "AES-GCM")
        @Assert(tls13CipherSuiteAeadAlgorithm(TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256).toString(), "CHACHA20-POLY1305")
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519WithCipherSuites(
            clientPublic,
            [TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256, TLS13_CIPHER_SUITE_AES_128_GCM_SHA256]
        )
        let decodedClientHello = tlsDecodeClientHelloHandshake(clientHello)
        @Assert(decodedClientHello.cipherSuites[0], TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256)
        @Assert(decodedClientHello.cipherSuites[1], TLS13_CIPHER_SUITE_AES_128_GCM_SHA256)
        let serverHello = tls13BuildServerHelloForX25519(clientHello, serverPublic)
        let selectedCipherSuite = tlsDecodeServerHelloHandshake(serverHello).cipherSuite
        @Assert(selectedCipherSuite, TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256)
        @Assert(tls13CipherSuiteAeadAlgorithm(selectedCipherSuite).toString(), "CHACHA20-POLY1305")
        @Assert(tls13CipherSuiteKeyLen(selectedCipherSuite), 32)
        @Assert(tls13CipherSuiteIvLen(selectedCipherSuite), 12)

        let transcriptHash = sha256(concat(clientHello, serverHello))
        let clientSecrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            clientPrivate,
            serverPublic,
            transcriptHash,
            selectedCipherSuite
        )
        let serverSecrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            serverPrivate,
            clientPublic,
            transcriptHash,
            selectedCipherSuite
        )
        @Assert(clientSecrets.clientWriteKey.size, 32)
        @Assert(serverSecrets.clientWriteKey.size, 32)

        let clientHandle = tls13CreateClientRecordLayerHandle(clientSecrets, selectedCipherSuite)
        let serverHandle = tls13CreateServerRecordLayerHandle(serverSecrets, selectedCipherSuite)
        let payload = "tls13-x25519-chacha-cipher-selection".toArray()
        let encrypted = clientHandle.seal(ApplicationData, payload)
        let opened = serverHandle.open(encrypted)
        @Assert(opened.fragment, payload)

        let (rotatedClientSecrets, rotatedClientHandle) = tls13RotateClientRecordLayerHandle(
            clientSecrets,
            selectedCipherSuite
        )
        let rotatedServerSecrets = tls13RotateClientApplicationTrafficSecrets(serverSecrets)
        let rotatedServerHandle = tls13CreateServerRecordLayerHandle(rotatedServerSecrets, selectedCipherSuite)
        @Assert(rotatedClientSecrets.clientWriteKey, rotatedServerSecrets.clientWriteKey)

        let rotatedPayload = "tls13-x25519-chacha-key-update-handle".toArray()
        let rotatedEncrypted = rotatedClientHandle.seal(ApplicationData, rotatedPayload)
        let rotatedOpened = rotatedServerHandle.open(rotatedEncrypted)
        @Assert(rotatedOpened.fragment, rotatedPayload)
    }

    @TestCase
    public func testTls13RecordChannelCloseNotifyLifecycle(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519WithCipherSuites(
            clientPublic,
            [TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256]
        )
        let serverHello = tls13BuildServerHelloForX25519(clientHello, serverPublic)
        let selectedCipherSuite = tlsDecodeServerHelloHandshake(serverHello).cipherSuite
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            clientPrivate,
            serverPublic,
            transcriptHash,
            selectedCipherSuite
        )
        let serverSecrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            serverPrivate,
            clientPublic,
            transcriptHash,
            selectedCipherSuite
        )

        let clientChannel = tls13CreateClientRecordChannel(clientSecrets, selectedCipherSuite)
        let serverChannel = tls13CreateServerRecordChannel(serverSecrets, selectedCipherSuite)
        @Assert(clientChannel.state.toString(), "ACTIVE")
        @Assert(serverChannel.state.toString(), "ACTIVE")

        let encryptedApp = clientChannel.sealApplicationData("tls13-record-channel".toArray())
        let appInbound = serverChannel.openRecord(encryptedApp)
        @Assert(appInbound.contentType.toString(), "APPLICATION_DATA")
        @Assert(appInbound.fragment, "tls13-record-channel".toArray())
        @Assert(appInbound.stateAfter.toString(), "ACTIVE")

        let serverCloseNotify = serverChannel.sendCloseNotify()
        @Assert(serverChannel.state.toString(), "CLOSE_NOTIFY_SENT")
        let clientCloseEvent = clientChannel.openRecord(serverCloseNotify)
        @Assert(clientCloseEvent.contentType.toString(), "ALERT")
        if (let Some(alert) <- clientCloseEvent.alert) {
            @Assert(alert.level.toString(), "WARNING")
            @Assert(alert.description.toString(), "CLOSE_NOTIFY")
        } else {
            @Fail("close_notify should decode as alert event")
        }
        @Assert(clientCloseEvent.stateAfter.toString(), "CLOSE_NOTIFY_RECEIVED")
        @Assert(clientChannel.state.toString(), "CLOSE_NOTIFY_RECEIVED")

        try {
            _ = clientChannel.sealApplicationData("blocked-after-close-notify".toArray())
            @Fail("client application data should be blocked after peer close_notify")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let clientCloseNotify = clientChannel.sendCloseNotify()
        @Assert(clientChannel.state.toString(), "CLOSED")
        let serverCloseEvent = serverChannel.openRecord(clientCloseNotify)
        @Assert(serverCloseEvent.contentType.toString(), "ALERT")
        @Assert(serverChannel.state.toString(), "CLOSED")
    }

    @TestCase
    public func testTls13RecordChannelFatalAlertLifecycle(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519WithCipherSuites(
            clientPublic,
            [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256]
        )
        let serverHello = tls13BuildServerHelloForX25519(clientHello, serverPublic)
        let selectedCipherSuite = tlsDecodeServerHelloHandshake(serverHello).cipherSuite
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            clientPrivate,
            serverPublic,
            transcriptHash,
            selectedCipherSuite
        )
        let serverSecrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            serverPrivate,
            clientPublic,
            transcriptHash,
            selectedCipherSuite
        )

        let clientChannel = tls13CreateClientRecordChannel(clientSecrets, selectedCipherSuite)
        let serverChannel = tls13CreateServerRecordChannel(serverSecrets, selectedCipherSuite)

        let fatalRecord = clientChannel.sendFatalAlert(HandshakeFailure)
        @Assert(clientChannel.state.toString(), "CLOSED")

        let fatalEvent = serverChannel.openRecord(fatalRecord)
        @Assert(fatalEvent.contentType.toString(), "ALERT")
        if (let Some(alert) <- fatalEvent.alert) {
            @Assert(alert.level.toString(), "FATAL")
            @Assert(alert.description.toString(), "HANDSHAKE_FAILURE")
        } else {
            @Fail("fatal alert should decode as alert event")
        }
        @Assert(serverChannel.state.toString(), "CLOSED")

        try {
            _ = serverChannel.sealApplicationData("server-after-fatal".toArray())
            @Fail("server application data should be blocked after fatal alert")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13EcdheFlowWithChacha20Poly1305RecordRoundTrip(): Unit {
        let profile = FipsProfile.fromText("TLS1.3\nCHACHA20-POLY1305\nECDH")
        tls13HandshakeRequireAllowed(profile, Tls13HandshakeMode.ECDHE_1RTT, algorithm: CHACHA20_POLY1305)

        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)
        let serverHello = tls13BuildServerHelloForEcdhe(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromEcdhe(
            clientPrivate,
            tls13ExtractServerKeyShare(serverHello),
            transcriptHash,
            keyLen: 32,
            ivLen: 12
        )
        let serverSecrets = tls13DeriveSecretsFromEcdhe(
            serverPrivate,
            tls13ExtractClientKeyShare(clientHello),
            transcriptHash,
            keyLen: 32,
            ivLen: 12
        )

        let clientRecord = tls13CreateClientRecordLayerChacha20Poly1305(clientSecrets)
        let serverRecord = tls13CreateServerRecordLayerChacha20Poly1305(serverSecrets)
        let encrypted = clientRecord.seal(ApplicationData, "tls13-ecdhe-chacha-data".toArray())
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, "tls13-ecdhe-chacha-data".toArray())
    }

    @TestCase
    public func testTls13PskAndEarlyDataPlaceholder(): Unit {
        let pskIdentity = "ticket-A".toArray()
        let psk = hexToBytes(TEST_HEX_32_00112233445566778899AABBCCDDEEFF_00112233445566778899AABBCCDDEEFF)

        let clientHello = tls13BuildClientHelloPsk(pskIdentity)
        let serverHello = tls13BuildServerHelloForPsk(clientHello, selectedIdentityIndex: 0)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromPsk(psk, transcriptHash)
        let serverSecrets = tls13DeriveSecretsFromPsk(psk, transcriptHash)
        @Assert(clientSecrets.masterSecret, serverSecrets.masterSecret)
        @Assert(clientSecrets.clientWriteIv, serverSecrets.clientWriteIv)
        @Assert(clientSecrets.serverWriteKey, serverSecrets.serverWriteKey)

        let early1 = tls13DeriveEarlyDataSecrets(psk, sha256(clientHello))
        let early2 = tls13DeriveEarlyDataSecrets(psk, sha256(clientHello))
        @Assert(early1.clientEarlyWriteKey, early2.clientEarlyWriteKey)
        @Assert(early1.clientEarlyWriteIv, early2.clientEarlyWriteIv)
    }

    @TestCase
    public func testTls13SessionTicketPskBinderFlow(): Unit {
        let identity = TlsSessionIdentity(
            TLS1_3,
            "resume-id-01".toArray(),
            serverName: TEST_HOST_API,
            alpnProtocol: "h2"
        )
        let ticket = tlsCreateSessionTicket(
            identity,
            hexToBytes("8899aabbccddeeff00112233445566778899aabbccddeeff0011223344556677"),
            nonce: [UInt8(0x10), UInt8(0x11), UInt8(0x12)],
            nowUnixSeconds: 2000,
            ttlSeconds: 120
        )

        let newSessionTicket = tls13BuildNewSessionTicketFromSessionTicket(ticket, ticketAgeAdd: 0x01020304)
        let decodedNst = tls13DecodeNewSessionTicketHandshake(newSessionTicket)
        @Assert(decodedNst.ticketLifetimeSeconds, 120)
        @Assert(decodedNst.ticketAgeAdd, 0x01020304)
        @Assert(decodedNst.ticketNonce, [UInt8(0x10), UInt8(0x11), UInt8(0x12)])
        @Assert(decodedNst.extensions.size, 0)

        let decodedTicket = tls13DecodeSessionTicketFromNewSessionTicket(newSessionTicket)
        @Assert(decodedTicket.identity.cacheKey(), ticket.identity.cacheKey())
        @Assert(decodedTicket.secret, ticket.secret)

        let clientHello = tls13BuildClientHelloPskFromSessionTicket(ticket)
        let extractedIdentity = tls13ExtractClientPskIdentity(clientHello)
        @Assert(extractedIdentity, tlsEncodeSessionTicket(ticket))
        @Assert(tls13VerifyClientPskBinder(clientHello, ticket.secret), true)

        let serverHello = tls13BuildServerHelloForPskWithBinder(clientHello, ticket.secret)
        let decodedServerHello = tlsDecodeServerHelloHandshake(serverHello)
        @Assert(decodedServerHello.cipherSuite, 0x1301)

        let serverHelloFromTicket = tls13BuildServerHelloForPskFromSessionTicket(
            clientHello,
            nowUnixSeconds: 2010
        )
        let decodedServerHelloFromTicket = tlsDecodeServerHelloHandshake(serverHelloFromTicket)
        @Assert(decodedServerHelloFromTicket.cipherSuite, 0x1301)
        @Assert(tls13ExtractServerSelectedPskIdentity(serverHelloFromTicket), 0)

        let expiredTicket = tlsCreateSessionTicket(
            TlsSessionIdentity(TLS1_3, "resume-id-expired".toArray(), serverName: TEST_HOST_API, alpnProtocol: "h2"),
            hexToBytes("11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff"),
            nonce: [UInt8(0x20), UInt8(0x21)],
            nowUnixSeconds: 1900,
            ttlSeconds: 10
        )
        let fallbackTicket = tlsCreateSessionTicket(
            TlsSessionIdentity(TLS1_3, "resume-id-fallback".toArray(), serverName: TEST_HOST_API, alpnProtocol: "h2"),
            hexToBytes("ffeeddccbbaa00998877665544332211ffeeddccbbaa00998877665544332211"),
            nonce: [UInt8(0x30), UInt8(0x31)],
            nowUnixSeconds: 2000,
            ttlSeconds: 200
        )
        let multiHello = tls13BuildClientHelloPskFromSessionTickets([expiredTicket, fallbackTicket])
        let offers = tls13ExtractClientPskIdentities(multiHello)
        @Assert(offers.size, 2)
        @Assert(offers[0].identity, tlsEncodeSessionTicket(expiredTicket))
        @Assert(offers[1].identity, tlsEncodeSessionTicket(fallbackTicket))

        let selectedIndex = tls13SelectPskIdentityFromSessionTickets(multiHello, nowUnixSeconds: 2050)
        @Assert(selectedIndex, 1)
        let autoServerHello = tls13BuildServerHelloForPskBySessionTickets(multiHello, nowUnixSeconds: 2050)
        @Assert(tls13ExtractServerSelectedPskIdentity(autoServerHello), 1)

        let tampered = clientHello.clone()
        tampered[tampered.size - 1] = UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01)
        @Assert(tls13VerifyClientPskBinder(tampered, ticket.secret), false)
        try {
            _ = tls13BuildServerHelloForPskWithBinder(tampered, ticket.secret)
            @Fail("TLS1.3 should reject tampered PSK binder")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = tls13SelectPskIdentityFromSessionTickets(
                tls13BuildClientHelloPskFromSessionTickets([expiredTicket]),
                nowUnixSeconds: 2050
            )
            @Fail("TLS1.3 should reject session tickets when all candidates are expired")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13KeyUpdateAndTrafficSecretRotation(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519(clientPublic)
        let serverHello = tls13BuildServerHelloForX25519(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromX25519(clientPrivate, serverPublic, transcriptHash)
        let serverSecrets = tls13DeriveSecretsFromX25519(serverPrivate, clientPublic, transcriptHash)

        @Assert(tls13DecodeKeyUpdateHandshake(tls13BuildKeyUpdateHandshake()), false)
        @Assert(tls13DecodeKeyUpdateHandshake(tls13BuildKeyUpdateHandshake(requestPeerUpdate: true)), true)

        let rotatedClientSecrets = tls13RotateClientApplicationTrafficSecrets(clientSecrets)
        let rotatedServerSecrets = tls13RotateClientApplicationTrafficSecrets(serverSecrets)
        @Assert(rotatedClientSecrets.clientWriteKey, rotatedServerSecrets.clientWriteKey)
        @Assert(rotatedClientSecrets.clientWriteIv, rotatedServerSecrets.clientWriteIv)
        @Assert(
            bytesToHexLower(rotatedClientSecrets.clientWriteKey) !=
                bytesToHexLower(clientSecrets.clientWriteKey),
            true
        )
        @Assert(rotatedClientSecrets.serverWriteKey, clientSecrets.serverWriteKey)
        @Assert(rotatedClientSecrets.serverWriteIv, clientSecrets.serverWriteIv)

        let clientRecord = tls13CreateClientRecordLayer(rotatedClientSecrets)
        let serverRecord = tls13CreateServerRecordLayer(rotatedServerSecrets)
        let payload = "tls13-key-update-client-traffic".toArray()
        let encrypted = clientRecord.seal(ApplicationData, payload)
        let opened = serverRecord.open(encrypted)
        @Assert(opened.fragment, payload)

        let malformed = tlsEncodeHandshakeFrame(TlsHandshakeFrame(KeyUpdate, [UInt8(0x02)]))
        try {
            _ = tls13DecodeKeyUpdateHandshake(malformed)
            @Fail("TLS1.3 key_update with invalid request_update should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let (rotatedByHelper, rotatedClientRecord) = tls13RotateClientRecordLayer(clientSecrets)
        let rotatedServerSecretsForClientTraffic = tls13RotateClientApplicationTrafficSecrets(serverSecrets)
        let rotatedServerRecord = tls13CreateServerRecordLayer(rotatedServerSecretsForClientTraffic)
        @Assert(rotatedByHelper.clientWriteKey, rotatedServerSecretsForClientTraffic.clientWriteKey)
        let helperPayload = "tls13-key-update-helper-record-layer".toArray()
        let helperEncrypted = rotatedClientRecord.seal(ApplicationData, helperPayload)
        let helperOpened = rotatedServerRecord.open(helperEncrypted)
        @Assert(helperOpened.fragment, helperPayload)
    }

    @TestCase
    public func testTls13ExporterKeyingMaterial(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519(clientPublic)
        let serverHello = tls13BuildServerHelloForX25519(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))
        let secrets = tls13DeriveSecretsFromX25519(clientPrivate, serverPublic, transcriptHash)

        let exporterMaster = tls13DeriveExporterMasterSecret(secrets.masterSecret, transcriptHash)
        let km1 = tls13ExportKeyingMaterial(
            exporterMaster,
            "EXPORTER-jinguissl-http",
            context: "ctx-a".toArray(),
            outputLen: 32
        )
        let km2 = tls13ExportKeyingMaterial(
            exporterMaster,
            "EXPORTER-jinguissl-http",
            context: "ctx-a".toArray(),
            outputLen: 32
        )
        @Assert(km1, km2)

        let km3 = tls13ExportKeyingMaterial(
            exporterMaster,
            "EXPORTER-jinguissl-http",
            context: "ctx-b".toArray(),
            outputLen: 32
        )
        @Assert(bytesToHexLower(km1) != bytesToHexLower(km3), true)

        let kmLong = tls13ExportKeyingMaterial(
            exporterMaster,
            "EXPORTER-jinguissl-http",
            context: [UInt8(0x01), UInt8(0x02)],
            outputLen: 64
        )
        @Assert(kmLong.size, 64)

        try {
            _ = tls13ExportKeyingMaterial(exporterMaster, "", outputLen: 16)
            @Fail("empty TLS1.3 exporter label should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testTls13RejectMalformedMessages(): Unit {
        let random = incrementalBytes(32)
        let malformedClientHello = tlsEncodeClientHelloHandshake(
            TlsClientHello(
                random,
                [0x1301],
                compressionMethods: [UInt8(0x00)],
                extensions: [
                    TlsExtension(0x0033, []) // key_share empty and supported_versions missing
                ],
                legacyVersion: TLS1_2
            )
        )

        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        try {
            _ = tls13BuildServerHelloForEcdhe(malformedClientHello, serverPublic)
            @Fail("server should reject malformed TLS1.3 ClientHello")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let validEcdheClientHello = tls13BuildClientHelloEcdhe(EcPublicKey(P256, P256_2G_X, P256_2G_Y))
        let validEcdheServerHello = tls13BuildServerHelloForEcdhe(validEcdheClientHello, EcPublicKey(P256, P256_GX, P256_GY))
        let decodedEcdheServerHello = tlsDecodeServerHelloHandshake(validEcdheServerHello)
        let mutatedEcdheExtensions = ArrayList<TlsExtension>()
        for (ext in decodedEcdheServerHello.extensions) {
            if (ext.extType == TLS13_KEY_SHARE_EXTENSION_TYPE) {
                let ecdheKeyShareData = ext.data.clone()
                ecdheKeyShareData[0] = UInt8(0x00)
                ecdheKeyShareData[1] = UInt8(0x19)
                mutatedEcdheExtensions.add(TlsExtension(ext.extType, ecdheKeyShareData))
            } else {
                mutatedEcdheExtensions.add(TlsExtension(ext.extType, ext.data))
            }
        }
        let unsupportedEcdheServerHello = tlsEncodeServerHelloHandshake(
            TlsServerHello(
                decodedEcdheServerHello.random,
                decodedEcdheServerHello.cipherSuite,
                sessionId: decodedEcdheServerHello.sessionId,
                compressionMethod: decodedEcdheServerHello.compressionMethod,
                extensions: mutatedEcdheExtensions.toArray(),
                legacyVersion: decodedEcdheServerHello.legacyVersion
            )
        )
        try {
            _ = tls13ExtractServerKeyShare(unsupportedEcdheServerHello)
            @Fail("unsupported TLS1.3 ECDHE server key_share group should surface as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let validX25519ClientHello = tls13BuildClientHelloX25519(x25519PublicFromPrivate(clientPrivate))
        let validX25519ServerHello = tls13BuildServerHelloForX25519(
            validX25519ClientHello,
            hexToBytes("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")
        )
        let decodedX25519ServerHello = tlsDecodeServerHelloHandshake(validX25519ServerHello)
        let mutatedX25519Extensions = ArrayList<TlsExtension>()
        for (ext in decodedX25519ServerHello.extensions) {
            if (ext.extType == TLS13_KEY_SHARE_EXTENSION_TYPE) {
                let x25519KeyShareData = ext.data.clone()
                x25519KeyShareData[0] = UInt8(0x00)
                x25519KeyShareData[1] = UInt8(0x17)
                mutatedX25519Extensions.add(TlsExtension(ext.extType, x25519KeyShareData))
            } else {
                mutatedX25519Extensions.add(TlsExtension(ext.extType, ext.data))
            }
        }
        let unsupportedX25519ServerHello = tlsEncodeServerHelloHandshake(
            TlsServerHello(
                decodedX25519ServerHello.random,
                decodedX25519ServerHello.cipherSuite,
                sessionId: decodedX25519ServerHello.sessionId,
                compressionMethod: decodedX25519ServerHello.compressionMethod,
                extensions: mutatedX25519Extensions.toArray(),
                legacyVersion: decodedX25519ServerHello.legacyVersion
            )
        )
        try {
            _ = tls13ExtractServerX25519KeyShare(unsupportedX25519ServerHello)
            @Fail("unsupported TLS1.3 X25519 server key_share group should surface as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let pskHello = tls13BuildClientHelloPsk("ticket-B".toArray())
        try {
            _ = tls13BuildServerHelloForPsk(pskHello, selectedIdentityIndex: 1)
            @Fail("server should reject out-of-range selected identity")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ComplianceGate(): Unit {
        let profile = FipsProfile.phase1Default()
        tls13HandshakeRequireAllowed(profile, Tls13HandshakeMode.ECDHE_1RTT)
        tls13HandshakeRequireAllowed(profile, Tls13HandshakeMode.PSK_1RTT)
        tls13HandshakeRequireAllowed(profile, Tls13HandshakeMode.PSK_0RTT_PLACEHOLDER)

        let blockedEcdh = FipsProfile.fromText("TLS1.3\nAES-GCM\nRSA")
        try {
            tls13HandshakeRequireAllowed(blockedEcdh, Tls13HandshakeMode.ECDHE_1RTT)
            @Fail("TLS1.3 ECDHE mode should require ECDH permission")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let blockedTls = FipsProfile.fromText("AES-GCM")
        try {
            tls13HandshakeRequireAllowed(blockedTls, Tls13HandshakeMode.PSK_1RTT)
            @Fail("TLS1.3 PSK mode should require TLS1.3 permission")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let chachaAllowed = FipsProfile.fromText("TLS1.3\nCHACHA20-POLY1305\nECDH")
        tls13HandshakeRequireAllowed(chachaAllowed, Tls13HandshakeMode.ECDHE_1RTT, algorithm: CHACHA20_POLY1305)

        try {
            tls13HandshakeRequireAllowed(chachaAllowed, Tls13HandshakeMode.PSK_1RTT, algorithm: CHACHA20_POLY1305)
        } catch (_: Exception) {
            @Fail("TLS1.3 PSK mode should be allowed with TLS1.3 + CHACHA20-POLY1305")
        }
    }

    @TestCase
    public func testTls13CertificateHandshakeParseAndVerify(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let encoded = tls13BuildCertificateHandshakeFromDerChain(
            [leaf.der, intermediate.der],
            requestContext: [UInt8(0x01), UInt8(0x02)]
        )
        let parsedChain = tls13ParseCertificateChainFromHandshake(encoded)
        @Assert(parsedChain.size, 2)
        @Assert(parsedChain[0].subject.commonName(), TEST_HOST_WWW)
        @Assert(parsedChain[1].subject.commonName(), "Policy Intermediate")

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let verified = tls13VerifyCertificateChainFromHandshake(encoded, policy)
        @Assert(verified.chain.size, 3)
        @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")
    }

    @TestCase
    public func testTls13CertificateRequestBuildAndDecode(): Unit {
        let certAuthority = hexToBytes("300b3109300706035504030c00")
        let encoded = tls13BuildCertificateRequestHandshake(
            requestContext: [UInt8(0x11), UInt8(0x22), UInt8(0x33)],
            signatureSchemes: [
                TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256,
                TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
                TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
            ],
            certificateAuthorities: [certAuthority]
        )

        let parsed = tls13DecodeCertificateRequestHandshake(encoded)
        @Assert(parsed.requestContext, [UInt8(0x11), UInt8(0x22), UInt8(0x33)])
        @Assert(
            parsed.signatureSchemes,
            [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256, TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256]
        )
        @Assert(parsed.certificateAuthorities.size, 1)
        @Assert(parsed.certificateAuthorities[0], certAuthority)

        try {
            _ = tls13BuildCertificateRequestHandshake(signatureSchemes: [])
            @Fail("TLS1.3 CertificateRequest should reject empty signature scheme list")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        let broken = tlsEncodeCertificateRequestHandshakeTls13(
            Tls13CertificateRequestMessage(requestContext: [], extensions: [])
        )
        try {
            _ = tls13DecodeCertificateRequestHandshake(broken)
            @Fail("TLS1.3 CertificateRequest should require signature_algorithms extension")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ClientAuthFlightForCertificateRequest(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let privateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let transcriptHash = sha256("tls13-client-auth-request".toArray())
        let clientHsTrafficSecret = sha256("tls13-client-hs-secret".toArray())
        let requestContext = [UInt8(0xa1), UInt8(0xb2), UInt8(0xc3)]
        let encodedCertificateRequest = tls13BuildCertificateRequestHandshake(
            requestContext: requestContext,
            signatureSchemes: [
                TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256,
                TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256
            ],
            certificateAuthorities: [intermediate.subject.der]
        )

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [leaf.der, intermediate.der],
            encodedCertificateRequest,
            transcriptHash,
            clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: privateKey
        )
        @Assert(clientAuthFlight.role.toString(), "CLIENT")

        let policy = X509VerificationPolicy([root], validationTime: "230101000000Z")
        let verified = tls13VerifyClientAuthFlightForCertificateRequest(
            clientAuthFlight,
            encodedCertificateRequest,
            policy,
            transcriptHash,
            clientHsTrafficSecret
        )
        @Assert(verified.chain.size, 3)
        @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")

        let encodedRsaOnlyRequest = tls13BuildCertificateRequestHandshake(
            requestContext: requestContext,
            signatureSchemes: [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        try {
            _ = tls13BuildClientAuthFlightForCertificateRequest(
                [leaf.der, intermediate.der],
                encodedRsaOnlyRequest,
                transcriptHash,
                clientHsTrafficSecret,
                certificatePrivateKeyEcdsa: privateKey
            )
            @Fail("TLS1.3 CertificateRequest RSA-only policy should reject ECDSA-only client key")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let mismatchedCaRequest = tls13BuildCertificateRequestHandshake(
            requestContext: requestContext,
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [root.subject.der]
        )
        try {
            _ = tls13VerifyClientAuthFlightForCertificateRequest(
                clientAuthFlight,
                mismatchedCaRequest,
                policy,
                transcriptHash,
                clientHsTrafficSecret
            )
            @Fail("TLS1.3 CertificateRequest certificate_authorities mismatch should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let wrongContextRequest = tls13BuildCertificateRequestHandshake(
            requestContext: [UInt8(0x01)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        try {
            _ = tls13VerifyClientAuthFlightForCertificateRequest(
                clientAuthFlight,
                wrongContextRequest,
                policy,
                transcriptHash,
                clientHsTrafficSecret
            )
            @Fail("TLS1.3 CertificateRequest request_context mismatch should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ClientAuthFlightForCertificateRequestP384(): Unit {
        let privateKey = EcPrivateKey(P384, BigNum.one())
        let certificate = x509CreateSelfSignedEcCertificate(
            X509SelfSignedConfig("tls13-client-auth-p384.local"),
            privateKey
        )

        let transcriptHash = sha256("tls13-client-auth-request-p384".toArray())
        let clientHsTrafficSecret = sha256("tls13-client-hs-secret-p384".toArray())
        let requestContext = [UInt8(0xd1), UInt8(0xd2), UInt8(0xd3)]
        let encodedCertificateRequest = tls13BuildCertificateRequestHandshake(
            requestContext: requestContext,
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384],
            certificateAuthorities: [certificate.subject.der]
        )

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            encodedCertificateRequest,
            transcriptHash,
            clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(privateKey)
        )
        @Assert(clientAuthFlight.role.toString(), "CLIENT")

        let policy = X509VerificationPolicy([certificate], validationTime: "270101000000Z")
        let verified = tls13VerifyClientAuthFlightForCertificateRequest(
            clientAuthFlight,
            encodedCertificateRequest,
            policy,
            transcriptHash,
            clientHsTrafficSecret
        )
        @Assert(verified.chain.size, 1)
        @Assert(verified.trustAnchor.subject.commonName(), "tls13-client-auth-p384.local")

        try {
            _ = tls13BuildClientAuthFlightForCertificateRequest(
                [certificate.der],
                encodedCertificateRequest,
                transcriptHash,
                clientHsTrafficSecret,
                certificatePrivateKeyEcdsa: Some(EcPrivateKey(P256, BigNum.one()))
            )
            @Fail("TLS1.3 CertificateRequest P-384 policy should reject P-256 private key")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let tamperedVerify = clientAuthFlight.certificateVerifyHandshake.clone()
        tamperedVerify[tamperedVerify.size - 1] = UInt8(tamperedVerify[tamperedVerify.size - 1]) ^ UInt8(0x01)
        let tamperedFlight = Tls13AuthFlight(
            Tls13AuthFlightRole.CLIENT,
            clientAuthFlight.certificateHandshake,
            tamperedVerify,
            clientAuthFlight.finishedHandshake
        )
        try {
            _ = tls13VerifyClientAuthFlightForCertificateRequest(
                tamperedFlight,
                encodedCertificateRequest,
                policy,
                transcriptHash,
                clientHsTrafficSecret
            )
            @Fail("TLS1.3 client CertificateVerify tamper should fail verification")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ClientAuthFlightForCertificateRequestRsaPss(): Unit {
        let privateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-client-auth-rsa.local"),
            privateKey
        )

        let transcriptHash = sha256("tls13-client-auth-request-rsa".toArray())
        let clientHsTrafficSecret = sha256("tls13-client-hs-secret-rsa".toArray())
        let requestContext = [UInt8(0xf1), UInt8(0xf2)]
        let encodedCertificateRequest = tls13BuildCertificateRequestHandshake(
            requestContext: requestContext,
            signatureSchemes: [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256],
            certificateAuthorities: [certificate.subject.der]
        )

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            encodedCertificateRequest,
            transcriptHash,
            clientHsTrafficSecret,
            certificatePrivateKeyRsa: Some(privateKey)
        )
        @Assert(clientAuthFlight.role.toString(), "CLIENT")

        let policy = X509VerificationPolicy([certificate], validationTime: "270101000000Z")
        let profile = FipsProfile.fromText("RSA\nSHA-256")
        let verified = tls13VerifyClientAuthFlightForCertificateRequestWithProfile(
            clientAuthFlight,
            encodedCertificateRequest,
            policy,
            transcriptHash,
            clientHsTrafficSecret,
            profile
        )
        @Assert(verified.chain.size, 1)
        @Assert(verified.trustAnchor.subject.commonName(), "tls13-client-auth-rsa.local")

        try {
            _ = tls13BuildClientAuthFlightForCertificateRequest(
                [certificate.der],
                encodedCertificateRequest,
                transcriptHash,
                clientHsTrafficSecret,
                certificatePrivateKeyEcdsa: Some(EcPrivateKey(P256, BigNum.one()))
            )
            @Fail("TLS1.3 CertificateRequest RSA-PSS policy should reject non-RSA private key")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testTls13ServerContextClientAuthRequestFlow(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)

        let serverContext = tls13BuildServerHandshakeContextEcdheP256(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )
        let clientAuthContext = tls13BuildClientAuthRequestForServerContext(
            serverContext,
            requestContext: [UInt8(0x41), UInt8(0x42)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        @Assert(clientAuthContext.request.requestContext, [UInt8(0x41), UInt8(0x42)])
        @Assert(clientAuthContext.request.signatureSchemes, [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256])
        @Assert(clientAuthContext.request.certificateAuthorities.size, 1)
        @Assert(clientAuthContext.request.certificateAuthorities[0], intermediate.subject.der)

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [leaf.der, intermediate.der],
            clientAuthContext.encodedCertificateRequest,
            serverContext.flight.transcriptHash,
            serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let verified = tls13ProcessClientAuthFlightForServerContext(
            clientAuthContext,
            clientAuthFlight,
            policy
        )
        @Assert(verified.chain.size, 3)
        @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")

        let profile = FipsProfile.fromText("ECDSA\nSHA-256")
        let verifiedWithProfile = tls13ProcessClientAuthFlightForServerContext(
            clientAuthContext,
            clientAuthFlight,
            policy,
            profile: Some(profile)
        )
        @Assert(verifiedWithProfile.chain.size, 3)

        let tamperedVerify = clientAuthFlight.certificateVerifyHandshake.clone()
        tamperedVerify[tamperedVerify.size - 1] = UInt8(tamperedVerify[tamperedVerify.size - 1]) ^ UInt8(0x01)
        let tamperedFlight = Tls13AuthFlight(
            Tls13AuthFlightRole.CLIENT,
            clientAuthFlight.certificateHandshake,
            tamperedVerify,
            clientAuthFlight.finishedHandshake
        )
        try {
            _ = tls13ProcessClientAuthFlightForServerContext(
                clientAuthContext,
                tamperedFlight,
                policy
            )
            @Fail("TLS1.3 server-side client auth processing should reject tampered CertificateVerify")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let wrongRoleFlight = Tls13AuthFlight(
            Tls13AuthFlightRole.SERVER,
            clientAuthFlight.certificateHandshake,
            clientAuthFlight.certificateVerifyHandshake,
            clientAuthFlight.finishedHandshake
        )
        try {
            _ = tls13ProcessClientAuthFlightForServerContext(
                clientAuthContext,
                wrongRoleFlight,
                policy
            )
            @Fail("TLS1.3 server-side client auth processing should reject non-client auth flight role")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testTls13ServerClientAuthContextBuilderEcdheP256(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)

        let context = tls13BuildServerClientAuthContextEcdheP256(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            requestContext: [UInt8(0x33)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        @Assert(context.request.requestContext, [UInt8(0x33)])
        @Assert(context.request.signatureSchemes, [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256])
        @Assert(context.request.certificateAuthorities.size, 1)

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [leaf.der, intermediate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let verified = tls13ProcessClientAuthFlightForServerContext(
            context,
            clientAuthFlight,
            policy
        )
        @Assert(verified.chain.size, 3)
    }

    @TestCase
    public func testTls13ServerClientAuthContextBuilderEcdheP384(): Unit {
        let certPrivateKey = EcPrivateKey(P384, BigNum.one())
        let certificate = x509CreateSelfSignedEcCertificate(
            X509SelfSignedConfig("tls13-client-auth-context-p384.local"),
            certPrivateKey
        )

        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let serverPrivate = EcPrivateKey(P384, BigNum.one())
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)

        let context = tls13BuildServerClientAuthContextEcdheP384(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            requestContext: [UInt8(0x53), UInt8(0x84)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384],
            certificateAuthorities: [certificate.subject.der]
        )
        @Assert(context.request.requestContext, [UInt8(0x53), UInt8(0x84)])
        @Assert(context.request.signatureSchemes, [TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384])
        @Assert(context.request.certificateAuthorities.size, 1)

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )

        let policy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let verified = tls13ProcessClientAuthFlightForServerContext(
            context,
            clientAuthFlight,
            policy
        )
        @Assert(verified.chain.size, 1)
        @Assert(verified.trustAnchor.subject.commonName(), "tls13-client-auth-context-p384.local")
    }

    @TestCase
    public func testTls13CertificateVerifyEcdsaContexts(): Unit {
        let certificate = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let privateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))
        let transcriptHash = sha256("tls13-certificate-verify-ecdsa".toArray())

        let serverCertificateVerify = tls13BuildServerCertificateVerifyEcdsa(privateKey, transcriptHash)
        @Assert(tls13VerifyServerCertificateVerify(serverCertificateVerify, certificate, transcriptHash), true)

        let clientCertificateVerify = tls13BuildClientCertificateVerifyEcdsa(privateKey, transcriptHash)
        @Assert(tls13VerifyClientCertificateVerify(clientCertificateVerify, certificate, transcriptHash), true)
        @Assert(tls13VerifyServerCertificateVerify(clientCertificateVerify, certificate, transcriptHash), false)

        let decodedServer = tlsDecodeCertificateVerifyHandshake(serverCertificateVerify)
        @Assert(decodedServer.signatureScheme, TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256)
        @Assert(decodedServer.signature.size > 0, true)

        let tamperedTranscriptHash = transcriptHash.clone()
        tamperedTranscriptHash[0] = UInt8((Int64(UInt8(tamperedTranscriptHash[0])) + 1) & 0xff)
        @Assert(tls13VerifyServerCertificateVerify(serverCertificateVerify, certificate, tamperedTranscriptHash), false)
    }

    @TestCase
    public func testTls13CertificateVerifyEcdsaP384SignatureScheme(): Unit {
        let privateKey = EcPrivateKey(P384, BigNum.one())
        let transcriptHash = sha256("tls13-certificate-verify-ecdsa-p384".toArray())

        let serverCertificateVerify = tls13BuildServerCertificateVerifyEcdsa(privateKey, transcriptHash)
        let clientCertificateVerify = tls13BuildClientCertificateVerifyEcdsa(privateKey, transcriptHash)

        let decodedServer = tlsDecodeCertificateVerifyHandshake(serverCertificateVerify)
        let decodedClient = tlsDecodeCertificateVerifyHandshake(clientCertificateVerify)
        @Assert(decodedServer.signatureScheme, TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384)
        @Assert(decodedClient.signatureScheme, TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384)
        @Assert(decodedServer.signature.size > 0, true)
        @Assert(decodedClient.signature.size > 0, true)
    }

    @TestCase
    public func testTls13CertificateVerifyRsaPss(): Unit {
        let privateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-rsa.local"),
            privateKey
        )
        let transcriptHash = sha256("tls13-certificate-verify-rsa".toArray())

        let serverCertificateVerify = tls13BuildServerCertificateVerifyRsaPss(privateKey, transcriptHash)
        @Assert(tls13VerifyServerCertificateVerify(serverCertificateVerify, certificate, transcriptHash), true)

        let decodedServer = tlsDecodeCertificateVerifyHandshake(serverCertificateVerify)
        @Assert(decodedServer.signatureScheme, TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256)
        @Assert(decodedServer.signature.size > 0, true)

        let tamperedSignature = serverCertificateVerify.clone()
        let last = tamperedSignature.size - 1
        tamperedSignature[last] = if (UInt8(tamperedSignature[last]) == UInt8(0x00)) {
            UInt8(0x01)
        } else {
            UInt8(0x00)
        }
        @Assert(tls13VerifyServerCertificateVerify(tamperedSignature, certificate, transcriptHash), false)
    }

    @TestCase
    public func testTls13ServerAuthFlightEcdsaAndVerify(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let privateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)
        let serverHello = tls13BuildServerHelloForEcdhe(clientHello, serverPublic)
        let transcriptHash = sha256(concat(clientHello, serverHello))

        let clientSecrets = tls13DeriveSecretsFromEcdhe(
            clientPrivate,
            tls13ExtractServerKeyShare(serverHello),
            transcriptHash
        )
        let serverSecrets = tls13DeriveSecretsFromEcdhe(
            serverPrivate,
            tls13ExtractClientKeyShare(clientHello),
            transcriptHash
        )

        let flight = tls13BuildServerAuthFlightEcdsa(
            [leaf.der, intermediate.der],
            privateKey,
            transcriptHash,
            serverSecrets.serverHsTrafficSecret
        )
        @Assert(flight.role.toString(), "SERVER")

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let verified = tls13VerifyServerAuthFlight(
            flight,
            policy,
            transcriptHash,
            clientSecrets.serverHsTrafficSecret
        )
        @Assert(verified.chain.size, 3)
        @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")

        try {
            _ = tls13VerifyClientAuthFlight(
                flight,
                policy,
                transcriptHash,
                clientSecrets.clientHsTrafficSecret
            )
            @Fail("verifying SERVER auth flight with CLIENT verifier should fail")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        let tamperedFinished = flight.finishedHandshake.clone()
        tamperedFinished[tamperedFinished.size - 1] = UInt8(tamperedFinished[tamperedFinished.size - 1]) ^ UInt8(0x01)
        let tamperedFlight = Tls13AuthFlight(
            Tls13AuthFlightRole.SERVER,
            flight.certificateHandshake,
            flight.certificateVerifyHandshake,
            tamperedFinished
        )
        try {
            _ = tls13VerifyServerAuthFlight(
                tamperedFlight,
                policy,
                transcriptHash,
                clientSecrets.serverHsTrafficSecret
            )
            @Fail("tampered TLS1.3 Finished should fail auth-flight verification")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ServerAuthFlightEcdsaP384AndVerify(): Unit {
        let certPrivateKey = EcPrivateKey(P384, BigNum.one())
        let certificate = x509CreateSelfSignedEcCertificate(
            X509SelfSignedConfig("tls13-auth-p384.local"),
            certPrivateKey
        )

        let clientPrivate = EcPrivateKey(P384, BigNum.one())
        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let serverPrivate = EcPrivateKey(P384, BigNum.one())
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)

        let context = tls13BuildServerHandshakeContextEcdheP384(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            alpnPreference: ["h2"]
        )

        let policy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let result = tls13ProcessServerHandshakeFlightEcdheP384(
            clientHello,
            clientPrivate,
            context.flight,
            policy
        )
        @Assert(result.verification.chain.size, 1)
        @Assert(result.verification.trustAnchor.subject.commonName(), "tls13-auth-p384.local")
        @Assert(result.secrets.masterSecret, context.secrets.masterSecret)

        let certVerify = tlsDecodeCertificateVerifyHandshake(context.flight.authFlight.certificateVerifyHandshake)
        @Assert(certVerify.signatureScheme, TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384)
    }

    @TestCase
    public func testTls13ServerAuthFlightRsaPssAndProfileVerify(): Unit {
        let privateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-auth-rsa.local"),
            privateKey
        )
        let transcriptHash = sha256("tls13-auth-flight-rsa".toArray())
        let serverHsTrafficSecret = sha256("tls13-auth-flight-rsa-secret".toArray())

        let flight = tls13BuildServerAuthFlightRsaPss(
            [certificate.der],
            privateKey,
            transcriptHash,
            serverHsTrafficSecret
        )
        @Assert(flight.role.toString(), "SERVER")

        let policy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let profile = FipsProfile.fromText("TLS1.3\nRSA\nSHA-256")
        let verified = tls13VerifyServerAuthFlightWithProfile(
            flight,
            policy,
            transcriptHash,
            serverHsTrafficSecret,
            profile
        )
        @Assert(verified.chain.size, 1)
        @Assert(verified.trustAnchor.subject.commonName(), "tls13-auth-rsa.local")
    }

    @TestCase
    public func testTls13ServerHandshakeContextP256HttpFlow(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let clientHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: [TEST_HOST_API],
            alpnPreference: ["h2", "http/1.1"]
        )

        let context = tls13BuildHttpServerHandshakeContextEcdheP256(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            policy: httpPolicy
        )
        @Assert(context.flight.selectedAlpn, "h2")
        @Assert(context.flight.requestedServerName, TEST_HOST_API)
        @Assert(context.flight.acknowledgedServerName, true)

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let result = tls13ProcessServerHandshakeFlightEcdheP256(
            clientHello,
            clientPrivate,
            context.flight,
            policy
        )
        tls13ValidateHttpClientResult(result, policy: httpPolicy)
        @Assert(result.selectedAlpn, "h2")
        @Assert(result.requestedServerName, TEST_HOST_API)
        @Assert(result.acknowledgedServerName, true)
        @Assert(result.verification.chain.size, 3)
        @Assert(result.secrets.masterSecret, context.secrets.masterSecret)

        let tamperedEe = context.flight.encryptedExtensions.clone()
        tamperedEe[tamperedEe.size - 1] = UInt8(tamperedEe[tamperedEe.size - 1]) ^ UInt8(0x01)
        let tamperedFlight = Tls13ServerHandshakeFlight(
            context.flight.serverHello,
            tamperedEe,
            context.flight.authFlight,
            context.flight.transcriptHash,
            selectedAlpn: context.flight.selectedAlpn,
            requestedServerName: context.flight.requestedServerName,
            acknowledgedServerName: context.flight.acknowledgedServerName
        )
        try {
            _ = tls13ProcessServerHandshakeFlightEcdheP256(
                clientHello,
                clientPrivate,
                tamperedFlight,
                policy
            )
            @Fail("tampered EncryptedExtensions should fail transcript hash validation")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ServerHandshakeContextP384HttpFlow(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPrivate = EcPrivateKey(P384, BigNum.one())
        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let serverPrivate = EcPrivateKey(P384, BigNum.one())
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let clientHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: [TEST_HOST_API],
            alpnPreference: ["h2", "http/1.1"]
        )

        let context = tls13BuildHttpServerHandshakeContextEcdheP384(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            policy: httpPolicy
        )
        @Assert(context.flight.selectedAlpn, "h2")
        @Assert(context.flight.requestedServerName, TEST_HOST_API)
        @Assert(context.flight.acknowledgedServerName, true)

        let policy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let result = tls13ProcessServerHandshakeFlightEcdheP384(
            clientHello,
            clientPrivate,
            context.flight,
            policy
        )
        tls13ValidateHttpClientResult(result, policy: httpPolicy)
        @Assert(result.selectedAlpn, "h2")
        @Assert(result.requestedServerName, TEST_HOST_API)
        @Assert(result.acknowledgedServerName, true)
        @Assert(result.verification.chain.size, 3)
        @Assert(result.secrets.masterSecret, context.secrets.masterSecret)
    }

    @TestCase
    public func testTls13HttpClientHelloBuilders(): Unit {
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let ecdheHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            "Api.Example.COM"
        )
        let decodedEcdhe = tlsDecodeClientHelloHandshake(ecdheHello)
        assertTls13ClientHelloInteropExtensions(decodedEcdhe, [TLS13_GROUP_SECP256R1_TEST])

        if (let Some(sniExt) <- tlsFindExtension(decodedEcdhe.extensions, TLS_EXT_SERVER_NAME)) {
            let serverNames = tlsParseServerNameExtension(sniExt)
            @Assert(serverNames.size, 1)
            @Assert(serverNames[0], TEST_HOST_API)
        } else {
            @Fail("HTTP ECDHE ClientHello should carry SNI extension")
        }
        if (let Some(alpnExt) <- tlsFindExtension(decodedEcdhe.extensions, TLS_EXT_ALPN)) {
            let alpn = tlsParseAlpnExtension(alpnExt)
            @Assert(alpn, ["h2", "http/1.1"])
        } else {
            @Fail("HTTP ECDHE ClientHello should carry ALPN extension")
        }

        let x25519Private = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let x25519Public = x25519PublicFromPrivate(x25519Private)
        let x25519Hello = tls13BuildHttpClientHelloX25519(
            x25519Public,
            "edge.example.com",
            alpnProtocols: ["http/1.1"]
        )
        let decodedX25519 = tlsDecodeClientHelloHandshake(x25519Hello)
        assertTls13ClientHelloInteropExtensions(decodedX25519, [TLS13_GROUP_X25519_TEST])
        if (let Some(alpnExt) <- tlsFindExtension(decodedX25519.extensions, TLS_EXT_ALPN)) {
            let alpn = tlsParseAlpnExtension(alpnExt)
            @Assert(alpn, ["http/1.1"])
        } else {
            @Fail("HTTP X25519 ClientHello should carry ALPN extension")
        }
    }

    @TestCase
    public func testTls13HttpClientHelloInteropSummary(): Unit {
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let ecdheHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let ecdheSummary = tls13SummarizeClientHello(ecdheHello)
        @Assert(ecdheSummary.legacyVersion.toString(), "TLS1.2")
        @Assert(ecdheSummary.cipherSuites, [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256])
        @Assert(
            ecdheSummary.extensionTypes,
            [
                TLS13_SUPPORTED_VERSIONS_EXTENSION_TYPE,
                TLS13_SUPPORTED_GROUPS_EXTENSION_TYPE,
                TLS13_EXT_SIGNATURE_ALGORITHMS,
                TLS13_KEY_SHARE_EXTENSION_TYPE,
                TLS_EXT_SERVER_NAME,
                TLS_EXT_ALPN
            ]
        )
        @Assert(ecdheSummary.serverNames, [TEST_HOST_API])
        @Assert(ecdheSummary.alpnProtocols, ["h2", "http/1.1"])
        @Assert(ecdheSummary.supportedVersions, [TLS13_VERSION_TEST])
        @Assert(ecdheSummary.supportedGroups, [TLS13_GROUP_SECP256R1_TEST])
        @Assert(ecdheSummary.keyShareGroups, [TLS13_GROUP_SECP256R1_TEST])
        @Assert(
            ecdheSummary.signatureSchemes,
            [
                TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
                TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
                TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
            ]
        )

        let x25519Private = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let x25519Public = x25519PublicFromPrivate(x25519Private)
        let x25519Hello = tls13BuildHttpClientHelloX25519(
            x25519Public,
            TEST_HOST_API,
            alpnProtocols: ["http/1.1"]
        )
        let x25519Summary = tls13SummarizeClientHello(x25519Hello)
        @Assert(x25519Summary.serverNames, [TEST_HOST_API])
        @Assert(x25519Summary.alpnProtocols, ["http/1.1"])
        @Assert(x25519Summary.supportedVersions, [TLS13_VERSION_TEST])
        @Assert(x25519Summary.supportedGroups, [TLS13_GROUP_X25519_TEST])
        @Assert(x25519Summary.keyShareGroups, [TLS13_GROUP_X25519_TEST])
        @Assert(
            x25519Summary.signatureSchemes,
            [
                TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
                TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
                TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
            ]
        )
    }

    @TestCase
    public func testTls13HttpClientHelloInteropPrecheck(): Unit {
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let ecdheHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let profile = Tls13ClientHelloInteropProfile(
            serverName: TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"],
            cipherSuites: [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256],
            supportedVersions: [TLS13_VERSION_TEST],
            supportedGroups: [TLS13_GROUP_SECP256R1_TEST],
            keyShareGroups: [TLS13_GROUP_SECP256R1_TEST],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256]
        )
        let passReport = tls13PrecheckEncodedClientHelloInterop(ecdheHello, profile)
        @Assert(passReport.ready, true)
        @Assert(passReport.missing.size, 0)
        @Assert(passReport.warnings.size, 0)
    }

    @TestCase
    public func testTls13HttpClientHelloInteropProfilePresetEcdheP256(): Unit {
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let ecdheHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            "Api.Example.COM",
            alpnProtocols: ["H2", "http/1.1"]
        )
        let profile = tls13HttpClientHelloInteropProfileEcdheP256(
            "Api.Example.COM",
            alpnProtocols: ["H2", "http/1.1"]
        )
        let report = tls13PrecheckEncodedClientHelloInterop(ecdheHello, profile)
        @Assert(profile.serverName, TEST_HOST_API)
        @Assert(profile.alpnProtocols, ["h2", "http/1.1"])
        @Assert(report.ready, true)
        @Assert(report.missing.size, 0)
        @Assert(report.warnings.size, 0)
    }

    @TestCase
    public func testTls13HttpClientHelloInteropProfilePresetX25519(): Unit {
        let x25519Private = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let x25519Public = x25519PublicFromPrivate(x25519Private)
        let x25519Hello = tls13BuildHttpClientHelloX25519(x25519Public, TEST_HOST_API)
        let profile = tls13HttpClientHelloInteropProfileX25519(TEST_HOST_API)
        let report = tls13PrecheckEncodedClientHelloInterop(x25519Hello, profile)
        @Assert(profile.alpnProtocols, ["h2", "http/1.1"])
        @Assert(report.ready, true)
        @Assert(report.missing.size, 0)
        @Assert(report.warnings.size, 0)
    }

    @TestCase
    public func testTls13HttpClientHelloInteropPrecheckReportsMissingFields(): Unit {
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let ecdheHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let mismatchedProfile = Tls13ClientHelloInteropProfile(
            serverName: "other.example.com",
            alpnProtocols: ["h3"],
            cipherSuites: [TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256],
            supportedVersions: [TLS13_VERSION_TEST],
            supportedGroups: [TLS13_GROUP_X25519_TEST],
            keyShareGroups: [TLS13_GROUP_X25519_TEST],
            signatureSchemes: [0x9999]
        )
        let failReport = tls13PrecheckEncodedClientHelloInterop(ecdheHello, mismatchedProfile)
        @Assert(failReport.ready, false)
        @Assert(tls13TestContainsString(failReport.missing, "missing SNI other.example.com"), true)
        @Assert(tls13TestContainsString(failReport.missing, "missing ALPN h3"), true)
        @Assert(tls13TestContainsString(failReport.missing, "missing cipher_suite 4867"), true)
        @Assert(tls13TestContainsString(failReport.missing, "missing supported_group 29"), true)
        @Assert(tls13TestContainsString(failReport.missing, "missing key_share_group 29"), true)
        @Assert(tls13TestContainsString(failReport.missing, "missing signature_scheme 39321"), true)
    }

    @TestCase
    public func testTls13HttpClientHelloInteropPrecheckReportsWarnings(): Unit {
        let profile = Tls13ClientHelloInteropProfile(
            serverName: TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"],
            cipherSuites: [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256],
            supportedVersions: [TLS13_VERSION_TEST],
            supportedGroups: [TLS13_GROUP_SECP256R1_TEST],
            keyShareGroups: [TLS13_GROUP_SECP256R1_TEST],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256]
        )
        let warningSummary = Tls13ClientHelloInteropSummary(
            TLS_VERSION_1_3,
            [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256],
            [],
            [TEST_HOST_API],
            ["h2"],
            [TLS13_VERSION_TEST],
            [TLS13_GROUP_SECP256R1_TEST],
            [TLS13_GROUP_SECP256R1_TEST],
            [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256]
        )
        let warningReport = tls13PrecheckClientHelloInterop(warningSummary, profile)
        @Assert(warningReport.ready, false)
        @Assert(warningReport.warnings.size, 1)
    }

    @TestCase
    public func testTls13HttpPolicyRejectsMissingSniAndAlpn(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let strictPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: [TEST_HOST_API],
            alpnPreference: ["h2", "http/1.1"]
        )

        let missingSni = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            "",
            alpnProtocols: ["h2", "http/1.1"]
        )
        try {
            _ = tls13BuildHttpServerHandshakeContextEcdheP256(
                missingSni,
                serverPrivate,
                serverPublic,
                [leaf.der, intermediate.der],
                certificatePrivateKeyEcdsa: Some(certPrivateKey),
                policy: strictPolicy
            )
            @Fail("HTTP profile should reject missing SNI")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let missingHttpAlpn = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["acme-tls/1"]
        )
        try {
            _ = tls13BuildHttpServerHandshakeContextEcdheP256(
                missingHttpAlpn,
                serverPrivate,
                serverPublic,
                [leaf.der, intermediate.der],
                certificatePrivateKeyEcdsa: Some(certPrivateKey),
                policy: strictPolicy
            )
            @Fail("HTTP profile should reject unsupported ALPN result")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13ServerHandshakeContextX25519RsaFlow(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519(clientPublic)
        let rsaPrivateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-x25519-rsa.local"),
            rsaPrivateKey
        )

        let context = tls13BuildServerHandshakeContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyRsa: Some(rsaPrivateKey),
            alpnPreference: ["h2"]
        )
        @Assert(context.flight.selectedAlpn, "")
        @Assert(context.flight.acknowledgedServerName, false)

        let policy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let profile = FipsProfile.fromText("TLS1.3\nRSA\nSHA-256")
        let result = tls13ProcessServerHandshakeFlightX25519(
            clientHello,
            clientPrivate,
            context.flight,
            policy,
            profile: Some(profile)
        )
        @Assert(result.selectedAlpn, "")
        @Assert(result.verification.chain.size, 1)
        @Assert(result.secrets.masterSecret, context.secrets.masterSecret)
    }

    @TestCase
    public func testTls13ServerHandshakeContextX25519RsaFlowWithChachaCipherSuite(): Unit {
        @Assert(TLS13_CIPHER_SUITE_AES_128_GCM_SHA256, 0x1301)
        @Assert(TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256, 0x1303)
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildClientHelloX25519WithCipherSuites(
            clientPublic,
            [TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256, TLS13_CIPHER_SUITE_AES_128_GCM_SHA256]
        )
        let decodedClientHello = tlsDecodeClientHelloHandshake(clientHello)
        @Assert(decodedClientHello.cipherSuites[0], TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256)
        @Assert(decodedClientHello.cipherSuites[1], TLS13_CIPHER_SUITE_AES_128_GCM_SHA256)
        let rsaPrivateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-x25519-chacha.local"),
            rsaPrivateKey
        )

        let context = tls13BuildServerHandshakeContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyRsa: Some(rsaPrivateKey),
            alpnPreference: ["h2"]
        )
        let selectedCipherSuite = tlsDecodeServerHelloHandshake(context.flight.serverHello).cipherSuite
        @Assert(selectedCipherSuite, TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256)
        @Assert(context.secrets.clientWriteKey.size, 32)

        let policy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let profile = FipsProfile.fromText("TLS1.3\nRSA\nSHA-256")
        let result = tls13ProcessServerHandshakeFlightX25519(
            clientHello,
            clientPrivate,
            context.flight,
            policy,
            profile: Some(profile)
        )
        @Assert(result.secrets.clientWriteKey.size, 32)
        @Assert(result.secrets.masterSecret, context.secrets.masterSecret)

        let clientRecordHandle = tls13CreateClientRecordLayerHandle(result.secrets, selectedCipherSuite)
        let serverRecordHandle = tls13CreateServerRecordLayerHandle(context.secrets, selectedCipherSuite)
        let payload = "tls13-server-context-x25519-rsa-chacha".toArray()
        let encrypted = clientRecordHandle.seal(ApplicationData, payload)
        let opened = serverRecordHandle.open(encrypted)
        @Assert(opened.fragment, payload)
    }

    @TestCase
    public func testTls13HttpServerHandshakeContextX25519RsaFlow(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildHttpClientHelloX25519(
            clientPublic,
            "edge.example.com",
            alpnProtocols: ["http/1.1", "h2"]
        )
        let rsaPrivateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("edge.example.com"),
            rsaPrivateKey
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: ["edge.example.com"],
            alpnPreference: ["h2", "http/1.1"]
        )

        let context = tls13BuildHttpServerHandshakeContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyRsa: Some(rsaPrivateKey),
            policy: httpPolicy
        )
        @Assert(context.flight.selectedAlpn, "h2")
        @Assert(context.flight.acknowledgedServerName, true)

        let verifyPolicy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let profile = FipsProfile.fromText("TLS1.3\nRSA\nSHA-256")
        let result = tls13ProcessServerHandshakeFlightX25519(
            clientHello,
            clientPrivate,
            context.flight,
            verifyPolicy,
            profile: Some(profile)
        )
        tls13ValidateHttpClientResult(result, policy: httpPolicy)
        @Assert(result.selectedAlpn, "h2")
        @Assert(result.requestedServerName, "edge.example.com")
        @Assert(result.acknowledgedServerName, true)
    }

    @TestCase
    public func testTls13HttpServerClientAuthContextBuilderX25519(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))

        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)

        let clientHello = tls13BuildHttpClientHelloX25519(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: [TEST_HOST_API],
            alpnPreference: ["h2", "http/1.1"]
        )

        let context = tls13BuildHttpServerClientAuthContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            policy: httpPolicy,
            requestContext: [UInt8(0x41), UInt8(0x42), UInt8(0x43)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        @Assert(context.serverContext.flight.selectedAlpn, "h2")
        @Assert(context.serverContext.flight.requestedServerName, TEST_HOST_API)
        @Assert(context.serverContext.flight.acknowledgedServerName, true)
        @Assert(context.request.requestContext, [UInt8(0x41), UInt8(0x42), UInt8(0x43)])

        let verifyPolicy = X509VerificationPolicy(
            [root],
            validationTime: "230101000000Z"
        )
        let clientResult = tls13ProcessServerHandshakeFlightX25519(
            clientHello,
            clientPrivate,
            context.serverContext.flight,
            verifyPolicy
        )
        tls13ValidateHttpClientResult(clientResult, policy: httpPolicy)

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [leaf.der, intermediate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )

        let verified = tls13ProcessClientAuthFlightForServerContext(
            context,
            clientAuthFlight,
            verifyPolicy
        )
        @Assert(verified.chain.size, 3)
        @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")
    }

    @TestCase
    public func testTls13ServerClientAuthContextBuilderX25519Rsa(): Unit {
        let rsaPrivateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-client-auth-x25519-rsa.local"),
            rsaPrivateKey
        )

        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)
        let clientHello = tls13BuildClientHelloX25519(clientPublic)

        let context = tls13BuildServerClientAuthContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyRsa: Some(rsaPrivateKey),
            signatureSchemes: [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256],
            certificateAuthorities: [certificate.subject.der]
        )
        @Assert(context.request.signatureSchemes, [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256])

        let verifyPolicy = X509VerificationPolicy([certificate], validationTime: "270101000000Z")
        let profile = FipsProfile.fromText("TLS1.3\nRSA\nSHA-256")
        let clientResult = tls13ProcessServerHandshakeFlightX25519(
            clientHello,
            clientPrivate,
            context.serverContext.flight,
            verifyPolicy,
            profile: Some(profile)
        )
        @Assert(clientResult.verification.chain.size, 1)

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyRsa: Some(rsaPrivateKey)
        )
        let verified = tls13ProcessClientAuthFlightForServerContext(
            context,
            clientAuthFlight,
            verifyPolicy,
            profile: Some(profile)
        )
        @Assert(verified.chain.size, 1)
        @Assert(verified.trustAnchor.subject.commonName(), "tls13-client-auth-x25519-rsa.local")
    }

    @TestCase
    public func testTls13HttpServerClientAuthContextBuilderEcdheP384(): Unit {
        let certPrivateKey = EcPrivateKey(P384, BigNum.one())
        let certificate = x509CreateSelfSignedEcCertificate(
            X509SelfSignedConfig("api-p384.example.com"),
            certPrivateKey
        )
        let clientPrivate = EcPrivateKey(P384, BigNum.one())
        let clientPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let serverPrivate = EcPrivateKey(P384, BigNum.one())
        let serverPublic = EcPublicKey(P384, P384_GX, P384_GY)
        let clientHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            "api-p384.example.com",
            alpnProtocols: ["h2", "http/1.1"]
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: ["api-p384.example.com"],
            alpnPreference: ["h2", "http/1.1"]
        )

        let context = tls13BuildHttpServerClientAuthContextEcdheP384(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            policy: httpPolicy,
            requestContext: [UInt8(0xc1)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384],
            certificateAuthorities: [certificate.subject.der]
        )
        @Assert(context.serverContext.flight.selectedAlpn, "h2")
        @Assert(context.serverContext.flight.requestedServerName, "api-p384.example.com")
        @Assert(context.serverContext.flight.acknowledgedServerName, true)
        @Assert(context.request.signatureSchemes, [TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384])

        let verifyPolicy = X509VerificationPolicy(
            [certificate],
            validationTime: "270101000000Z"
        )
        let clientResult = tls13ProcessServerHandshakeFlightEcdheP384(
            clientHello,
            clientPrivate,
            context.serverContext.flight,
            verifyPolicy
        )
        tls13ValidateHttpClientResult(clientResult, policy: httpPolicy)
        @Assert(clientResult.selectedAlpn, "h2")
        @Assert(clientResult.acknowledgedServerName, true)

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )
        let verified = tls13ProcessClientAuthFlightForServerContext(
            context,
            clientAuthFlight,
            verifyPolicy
        )
        @Assert(verified.chain.size, 1)
    }

    @TestCase
    public func testTls13ProcessClientAuthFlightRequirementModes(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let clientHello = tls13BuildClientHelloEcdhe(clientPublic)

        let context = tls13BuildServerClientAuthContextEcdheP256(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            requestContext: [UInt8(0x99)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        let policy = X509VerificationPolicy([root], validationTime: "230101000000Z")

        let optionalResult = tls13ProcessClientAuthFlightForServerContextWithRequirement(
            context,
            policy,
            requireClientCertificate: false
        )
        if (let Some(_) <- optionalResult) {
            @Fail("optional TLS1.3 client auth should allow missing client flight")
        }

        try {
            _ = tls13ProcessClientAuthFlightForServerContextWithRequirement(
                context,
                policy
            )
            @Fail("required TLS1.3 client auth should reject missing client flight")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [leaf.der, intermediate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )
        let presentResult = tls13ProcessClientAuthFlightForServerContextWithRequirement(
            context,
            policy,
            clientAuthFlight: Some(clientAuthFlight),
            requireClientCertificate: false
        )
        if (let Some(verified) <- presentResult) {
            @Assert(verified.chain.size, 3)
            @Assert(verified.trustAnchor.subject.commonName(), "Policy Root")
        } else {
            @Fail("optional TLS1.3 client auth should return verification result when flight is provided")
        }
    }

    @TestCase
    public func testTls13HttpClientAuthRequirementModes(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let certPrivateKey = x509ParseEcPrivateKeyPkcs8Pem(readText("testdata/x509/policy_leaf_key_pkcs8.pem"))
        let clientPrivate = EcPrivateKey(P256, BigNum.fromHex("02"))
        let clientPublic = EcPublicKey(P256, P256_2G_X, P256_2G_Y)
        let serverPrivate = EcPrivateKey(P256, BigNum.one())
        let serverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let clientHello = tls13BuildHttpClientHelloEcdhe(
            clientPublic,
            TEST_HOST_API,
            alpnProtocols: ["h2", "http/1.1"]
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: [TEST_HOST_API],
            alpnPreference: ["h2", "http/1.1"]
        )

        let context = tls13BuildHttpServerClientAuthContextEcdheP256(
            clientHello,
            serverPrivate,
            serverPublic,
            [leaf.der, intermediate.der],
            certificatePrivateKeyEcdsa: Some(certPrivateKey),
            policy: httpPolicy,
            requestContext: [UInt8(0x31), UInt8(0x32)],
            signatureSchemes: [TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256],
            certificateAuthorities: [intermediate.subject.der]
        )
        let verifyPolicy = X509VerificationPolicy([root], validationTime: "230101000000Z")
        let clientResult = tls13ProcessServerHandshakeFlightEcdheP256(
            clientHello,
            clientPrivate,
            context.serverContext.flight,
            verifyPolicy
        )
        tls13ValidateHttpClientResult(clientResult, policy: httpPolicy)

        let optionalNone = tls13ProcessHttpClientAuthFlightForServerContextWithRequirement(
            context,
            verifyPolicy,
            httpPolicy: httpPolicy,
            requireClientCertificate: false
        )
        if (let Some(_) <- optionalNone) {
            @Fail("HTTP optional TLS1.3 client auth should allow missing client flight")
        }

        try {
            _ = tls13ProcessHttpClientAuthFlightForServerContextWithRequirement(
                context,
                verifyPolicy,
                httpPolicy: httpPolicy
            )
            @Fail("HTTP required TLS1.3 client auth should reject missing client flight")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let clientAuthFlight = tls13BuildClientAuthFlightForCertificateRequest(
            [leaf.der, intermediate.der],
            context.encodedCertificateRequest,
            context.serverContext.flight.transcriptHash,
            context.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyEcdsa: Some(certPrivateKey)
        )
        let optionalSome = tls13ProcessHttpClientAuthFlightForServerContextWithRequirement(
            context,
            verifyPolicy,
            httpPolicy: httpPolicy,
            clientAuthFlight: Some(clientAuthFlight),
            requireClientCertificate: false
        )
        if (let Some(verified) <- optionalSome) {
            @Assert(verified.chain.size, 3)
        } else {
            @Fail("HTTP optional TLS1.3 client auth should return verification when flight is present")
        }

        let badFlight = Tls13ServerHandshakeFlight(
            context.serverContext.flight.serverHello,
            context.serverContext.flight.encryptedExtensions,
            context.serverContext.flight.authFlight,
            context.serverContext.flight.transcriptHash,
            selectedAlpn: "acme-tls/1",
            requestedServerName: context.serverContext.flight.requestedServerName,
            acknowledgedServerName: context.serverContext.flight.acknowledgedServerName
        )
        let badContext = Tls13ServerClientAuthContext(
            Tls13ServerHandshakeContext(badFlight, context.serverContext.secrets),
            context.encodedCertificateRequest,
            context.request
        )
        try {
            _ = tls13ProcessHttpClientAuthFlightForServerContextWithRequirement(
                badContext,
                verifyPolicy,
                httpPolicy: httpPolicy,
                requireClientCertificate: false
            )
            @Fail("HTTP TLS1.3 client auth wrapper should reject ALPN not allowed by policy")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTls13HttpClientAuthRequiredHelperWithRsaAuthorities(): Unit {
        let rsaPrivateKey = x509ParseRsaPrivateKeyPkcs8Pem(readText("testdata/x509/rsa_2048_pkcs8.pem"))
        let certificate = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig("tls13-http-client-auth-rsa.local"),
            rsaPrivateKey
        )
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientPublic = x25519PublicFromPrivate(clientPrivate)
        let serverPublic = x25519PublicFromPrivate(serverPrivate)
        let clientHello = tls13BuildHttpClientHelloX25519(
            clientPublic,
            "tls13-http-client-auth-rsa.local",
            alpnProtocols: ["h2", "http/1.1"]
        )
        let httpPolicy = TlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: ["tls13-http-client-auth-rsa.local"],
            alpnPreference: ["h2", "http/1.1"]
        )
        let verifyPolicy = X509VerificationPolicy([certificate], validationTime: "270101000000Z")
        let profile = FipsProfile.fromText("TLS1.3\nRSA\nSHA-256")

        let contextNoAuthorities = tls13BuildHttpServerClientAuthContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyRsa: Some(rsaPrivateKey),
            policy: httpPolicy,
            requestContext: [UInt8(0x61), UInt8(0x62)],
            signatureSchemes: [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256]
        )
        let clientResult = tls13ProcessServerHandshakeFlightX25519(
            clientHello,
            clientPrivate,
            contextNoAuthorities.serverContext.flight,
            verifyPolicy,
            profile: Some(profile)
        )
        tls13ValidateHttpClientResult(clientResult, policy: httpPolicy)

        let clientAuthFlightNoAuthorities = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            contextNoAuthorities.encodedCertificateRequest,
            contextNoAuthorities.serverContext.flight.transcriptHash,
            contextNoAuthorities.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyRsa: Some(rsaPrivateKey)
        )
        let verifiedNoAuthorities = tls13ProcessHttpClientAuthFlightForServerContextRequired(
            contextNoAuthorities,
            clientAuthFlightNoAuthorities,
            verifyPolicy,
            httpPolicy: httpPolicy,
            profile: Some(profile)
        )
        @Assert(verifiedNoAuthorities.chain.size, 1)
        @Assert(verifiedNoAuthorities.trustAnchor.subject.commonName(), "tls13-http-client-auth-rsa.local")

        let contextWithAuthorities = tls13BuildHttpServerClientAuthContextX25519(
            clientHello,
            serverPrivate,
            serverPublic,
            [certificate.der],
            certificatePrivateKeyRsa: Some(rsaPrivateKey),
            policy: httpPolicy,
            requestContext: [UInt8(0x71), UInt8(0x72)],
            signatureSchemes: [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256],
            certificateAuthorities: [certificate.subject.der]
        )
        let clientAuthFlightWithAuthorities = tls13BuildClientAuthFlightForCertificateRequest(
            [certificate.der],
            contextWithAuthorities.encodedCertificateRequest,
            contextWithAuthorities.serverContext.flight.transcriptHash,
            contextWithAuthorities.serverContext.secrets.clientHsTrafficSecret,
            certificatePrivateKeyRsa: Some(rsaPrivateKey)
        )
        _ = tls13ProcessHttpClientAuthFlightForServerContextRequired(
            contextWithAuthorities,
            clientAuthFlightWithAuthorities,
            verifyPolicy,
            httpPolicy: httpPolicy,
            profile: Some(profile)
        )

        let mismatchRequest = tls13BuildCertificateRequestHandshake(
            requestContext: contextWithAuthorities.request.requestContext,
            signatureSchemes: [TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256],
            certificateAuthorities: [hexToBytes("300b3109300706035504030c00")]
        )
        let mismatchContext = Tls13ServerClientAuthContext(
            contextWithAuthorities.serverContext,
            mismatchRequest,
            tls13DecodeCertificateRequestHandshake(mismatchRequest)
        )
        try {
            _ = tls13ProcessHttpClientAuthFlightForServerContextRequired(
                mismatchContext,
                clientAuthFlightWithAuthorities,
                verifyPolicy,
                httpPolicy: httpPolicy,
                profile: Some(profile)
            )
            @Fail("HTTP TLS1.3 required client auth should reject certificate_authorities issuer mismatch")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }
}

private func incrementalBytes(size: Int64, start!: Int64 = 0): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8((start + i) & 0xff)
        i += 1
    }
    out
}

private func concat(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    var i = 0
    while (i < left.size) {
        out[i] = left[i]
        i += 1
    }
    i = 0
    while (i < right.size) {
        out[left.size + i] = right[i]
        i += 1
    }
    out
}

private func assertTls13ClientHelloInteropExtensions(
    clientHello: TlsClientHello,
    expectedSupportedGroups: Array<Int64>
): Unit {
    if (let Some(groupsExt) <- tlsFindExtension(clientHello.extensions, TLS13_SUPPORTED_GROUPS_EXTENSION_TYPE)) {
        @Assert(parseTls13SupportedGroupsExtension(groupsExt), expectedSupportedGroups)
    } else {
        @Fail("TLS1.3 ClientHello should carry supported_groups extension")
    }

    if (let Some(signatureExt) <- tlsFindExtension(clientHello.extensions, TLS13_EXT_SIGNATURE_ALGORITHMS)) {
        @Assert(
            parseTls13SignatureAlgorithmsExtensionForTest(signatureExt),
            [
                TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
                TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
                TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
            ]
        )
    } else {
        @Fail("TLS1.3 ClientHello should carry signature_algorithms extension")
    }
}

private func parseTls13SupportedGroupsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_SUPPORTED_GROUPS_EXTENSION_TYPE) {
        throw Exception("TLS1.3 extension is not supported_groups")
    }
    parseTls13UInt16VectorExtension(extension.data, "TLS1.3 supported_groups")
}

private func parseTls13SignatureAlgorithmsExtensionForTest(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_EXT_SIGNATURE_ALGORITHMS) {
        throw Exception("TLS1.3 extension is not signature_algorithms")
    }
    parseTls13UInt16VectorExtension(extension.data, "TLS1.3 signature_algorithms")
}

private func parseTls13UInt16VectorExtension(data: Array<Byte>, label: String): Array<Int64> {
    if (data.size < 2) {
        throw Exception("${label} extension is truncated")
    }
    let encodedLen = readUInt16BeForTest(data, 0)
    if (encodedLen == 0 || (encodedLen % 2) != 0 || encodedLen + 2 != data.size) {
        throw Exception("${label} vector length is invalid")
    }

    let values = ArrayList<Int64>()
    var offset = 2
    while (offset < data.size) {
        values.add(readUInt16BeForTest(data, offset))
        offset += 2
    }
    values.toArray()
}

private func readUInt16BeForTest(data: Array<Byte>, offset: Int64): Int64 {
    if (offset + 2 > data.size) {
        throw Exception("uint16 read exceeds buffer")
    }
    (Int64(UInt8(data[offset])) << 8) | Int64(UInt8(data[offset + 1]))
}

private func hexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
    if ((clean.size % 2) != 0) {
        throw Exception("invalid hex length")
    }

    let out = Array<Byte>(clean.size / 2, repeat: 0)
    var i = 0
    while (i < clean.size) {
        let hi = hexNibble(clean[i])
        let lo = hexNibble(clean[i + 1])
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

private func hexNibble(ch: Byte): UInt8 {
    if (ch >= b'0' && ch <= b'9') {
        return UInt8(ch - b'0')
    }
    let lower = if (ch >= b'A' && ch <= b'F') {
        ch + 32
    } else {
        ch
    }
    if (lower >= b'a' && lower <= b'f') {
        return UInt8(lower - b'a' + 10)
    }
    throw Exception("invalid hex char")
}

private func bytesToHexLower(bytes: Array<Byte>): String {
    if (bytes.size == 0) {
        return ""
    }
    let table: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]
    var out = ""
    for (b in bytes) {
        let value = UInt8(b)
        out += table[Int64((value >> 4) & UInt8(0x0f))]
        out += table[Int64(value & UInt8(0x0f))]
    }
    out
}

private func tls13TestContainsString(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

private func readText(path: String): String {
    if (!exists(path)) {
        throw Exception("missing test file: ${path}")
    }
    String.fromUtf8(File.readFrom(path))
}
