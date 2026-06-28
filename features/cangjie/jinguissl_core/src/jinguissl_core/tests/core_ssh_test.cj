package jinguissl_core.tests

import std.collection.ArrayList
import std.fs.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.*
import jinguissl_core.crypto.ed25519.{ed25519PublicKeyFromSeed, ed25519Sign}
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.rsa.*
import jinguissl_core.crypto.ssh.*

@Test
public class SshTestSuite {
    @TestCase
    public func testVersionBannerRoundTripAndValidation(): Unit {
        let banner = sshBuildVersionBanner("jinguissl_0.1", comments: "dev")
        let encoded = sshEncodeVersionBanner(banner)
        @Assert(String.fromUtf8(encoded), "SSH-2.0-jinguissl_0.1 dev\r\n")

        let decoded = sshDecodeVersionBanner(encoded)
        @Assert(decoded.protocolVersion, "2.0")
        @Assert(decoded.softwareVersion, "jinguissl_0.1")
        @Assert(decoded.comments, "dev")

        let openssh = sshDecodeVersionBanner("SSH-2.0-OpenSSH_9.7\r\n".toArray())
        @Assert(openssh.protocolVersion, "2.0")
        @Assert(openssh.softwareVersion, "OpenSSH_9.7")
        @Assert(openssh.comments, "")

        try {
            _ = sshDecodeVersionBanner("SSH-1.5-legacy\r\n".toArray())
            @Fail("unsupported protocol banner should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        try {
            _ = sshDecodeVersionBanner("SSH-2.0-no-crlf".toArray())
            @Fail("banner without CRLF should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testKexInitRoundTripAndNegotiation(): Unit {
        let cookie = incrementalBytes(16, start: 16)
        let base = sshBuildDefaultKexInit(cookie: cookie)
        let encoded = sshEncodeKexInit(base)
        let decoded = sshDecodeKexInit(encoded)

        @Assert(decoded.cookie, cookie)
        @Assert(decoded.kexAlgorithms[0], "curve25519-sha256")
        @Assert(decoded.serverHostKeyAlgorithms[0], "ssh-ed25519")
        @Assert(decoded.firstKexPacketFollows, false)
        @Assert(decoded.reserved, 0)

        let client = SshKexInitMessage(
            cookie,
            ["curve25519-sha256", "ecdh-sha2-nistp256"],
            ["ssh-ed25519", "rsa-sha2-256"],
            [SSH_CIPHER_AES128_GCM_OPENSSH, "aes128-ctr"],
            [SSH_CIPHER_AES128_GCM_OPENSSH, "aes128-ctr"],
            ["hmac-sha2-256"],
            ["hmac-sha2-256"],
            ["none"],
            ["none"]
        )
        let server = SshKexInitMessage(
            incrementalBytes(16, start: 64),
            ["ecdh-sha2-nistp256", "curve25519-sha256"],
            ["rsa-sha2-256", "ssh-ed25519"],
            ["aes128-ctr", SSH_CIPHER_AES128_GCM_OPENSSH],
            ["aes128-ctr", SSH_CIPHER_AES128_GCM_OPENSSH],
            ["hmac-sha2-256"],
            ["hmac-sha2-256"],
            ["none"],
            ["none"]
        )

        let negotiated = sshNegotiateKexInit(client, server)
        @Assert(negotiated.kexAlgorithm, "ecdh-sha2-nistp256")
        @Assert(negotiated.serverHostKeyAlgorithm, "rsa-sha2-256")
        @Assert(negotiated.encryptionAlgorithmClientToServer, "aes128-ctr")
        @Assert(negotiated.macAlgorithmClientToServer, "hmac-sha2-256")
        @Assert(negotiated.compressionAlgorithmServerToClient, "none")

        let noOverlapServer = SshKexInitMessage(
            incrementalBytes(16, start: 96),
            [SSH_KEX_ALGORITHM_SNTRUP761X25519_SHA512_OPENSSH],
            ["ssh-ed448"],
            [SSH_CIPHER_AES256_GCM_OPENSSH],
            [SSH_CIPHER_AES256_GCM_OPENSSH],
            ["hmac-sha2-512"],
            ["hmac-sha2-512"],
            [SSH_COMPRESSION_ZLIB_OPENSSH],
            [SSH_COMPRESSION_ZLIB_OPENSSH]
        )
        try {
            _ = sshNegotiateKexInit(client, noOverlapServer)
            @Fail("negotiation without common algorithms should fail")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testTransportPacketEncodeDecodeAndMalformed(): Unit {
        let payload = "ssh-payload".toArray()
        let knownPadding = incrementalBytes(64, start: 128)
        let encoded = sshEncodeTransportPacket(
            payload,
            blockSize: 16,
            randomPadding: knownPadding
        )
        let decoded = sshDecodeTransportPacket(encoded, blockSize: 16)

        @Assert(decoded.payload, payload)
        @Assert((decoded.packetLength % 16), 0)
        @Assert(decoded.padding.size >= SSH_MIN_PACKET_PADDING_LEN, true)

        let malformedLength = encoded.clone()
        let originalLast = Int64(UInt8(malformedLength[3]))
        malformedLength[3] = UInt8((originalLast + 1) & 0xff)
        try {
            _ = sshDecodeTransportPacket(malformedLength, blockSize: 16)
            @Fail("packet_length mismatch should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let malformedType = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16)))
        malformedType[0] = UInt8(0x15)
        try {
            _ = sshDecodeKexInit(malformedType)
            @Fail("non-KEXINIT payload should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testKexEcdhX25519FlowAndExchangeHash(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientKexInit = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 1)))
        let serverKexInit = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 33)))
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_0.1\r\n".toArray(),
            "SSH-2.0-jinkui-server_0.1\r\n".toArray(),
            clientKexInit,
            serverKexInit
        )

        let (encodedInit, clientPublic) = sshBuildKexEcdhInitX25519(clientPrivate)
        let serverHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGR1bW15LWhvc3Qta2V5".toArray()
        let hostSignature = incrementalBytes(64, start: 201)
        let (encodedReply, serverResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            serverHostKey,
            hostSignature
        )
        let clientResult = sshClientProcessKexEcdhReplyX25519(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply
        )

        @Assert(serverResult.sharedSecret, clientResult.sharedSecret)
        @Assert(serverResult.exchangeHash, clientResult.exchangeHash)
        @Assert(serverResult.sessionId, clientResult.sessionId)
        @Assert(serverResult.clientEphemeralPublicKey, clientPublic)
        @Assert(serverResult.serverHostKey, serverHostKey)
        @Assert(serverResult.hostSignature, hostSignature)

        let decodedInit = sshDecodeKexEcdhInit(encodedInit)
        let decodedReply = sshDecodeKexEcdhReply(encodedReply)
        @Assert(decodedInit.clientEphemeralPublicKey, clientPublic)
        @Assert(decodedReply.serverHostKey, serverHostKey)
        @Assert(decodedReply.signature, hostSignature)

        let newKeys = sshEncodeNewKeys()
        sshDecodeNewKeys(newKeys)
    }

    @TestCase
    public func testKexEcdhRejectMismatchedPrivateAndMalformedNewKeys(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let wrongPrivate = hexToBytes("a546e36bf2c8278f843ec7394f6f55f4550f2f19fd3a812c47f5f57de7a3112a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientKexInit = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 4)))
        let serverKexInit = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 48)))
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_0.2\r\n".toArray(),
            "SSH-2.0-jinkui-server_0.2\r\n".toArray(),
            clientKexInit,
            serverKexInit
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let (encodedReply, _) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7".toArray(),
            incrementalBytes(48, start: 128)
        )

        try {
            _ = sshClientProcessKexEcdhReplyX25519(
                transcript,
                wrongPrivate,
                encodedInit,
                encodedReply
            )
            @Fail("mismatched client private key should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            sshDecodeNewKeys([UInt8(SSH_MSG_KEXINIT)])
            @Fail("non-NEWKEYS packet should be rejected by decoder")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testDeriveSessionKeysSha256FromKexResult(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let clientKexInit = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 12)))
        let serverKexInit = sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 44)))
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_0.3\r\n".toArray(),
            "SSH-2.0-jinkui-server_0.3\r\n".toArray(),
            clientKexInit,
            serverKexInit
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let (encodedReply, serverResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtleQ==".toArray(),
            incrementalBytes(64, start: 90)
        )
        let clientResult = sshClientProcessKexEcdhReplyX25519(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply
        )
        @Assert(serverResult.exchangeHash, clientResult.exchangeHash)

        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-ed25519",
            "aes128-ctr",
            "aes256-ctr",
            "hmac-sha2-256",
            "hmac-sha2-512",
            "none",
            "none"
        )
        let derived = sshDeriveSessionKeysFromX25519Result(clientResult, negotiated)
        @Assert(derived.sessionId, clientResult.sessionId)
        @Assert(derived.clientToServer.cipherName, "aes128-ctr")
        @Assert(derived.clientToServer.iv.size, 16)
        @Assert(derived.clientToServer.encryptionKey.size, 16)
        @Assert(derived.clientToServer.integrityKey.size, 32)
        @Assert(derived.serverToClient.cipherName, "aes256-ctr")
        @Assert(derived.serverToClient.iv.size, 16)
        @Assert(derived.serverToClient.encryptionKey.size, 32)
        @Assert(derived.serverToClient.integrityKey.size, 64)
    }

    @TestCase
    public func testCompleteInitialKeyExchangeX25519AndSupportProbes(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_0.4\r\n".toArray(),
            "SSH-2.0-jinkui-server_0.4\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 18))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 60)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let (encodedReply, serverResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ==".toArray(),
            incrementalBytes(48, start: 142)
        )
        let clientResult = sshClientProcessKexEcdhReplyX25519(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply
        )
        @Assert(serverResult.sharedSecret, clientResult.sharedSecret)

        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-rsa",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )
        let derived = sshCompleteInitialKeyExchangeX25519(
            clientResult,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(derived.clientToServer.encryptionKey.size, 16)
        @Assert(derived.serverToClient.integrityKey.size, 32)

        @Assert(sshIsCipherSupported("aes128-ctr"), true)
        @Assert(sshIsCipherSupported("aes256-ctr"), true)
        @Assert(sshIsCipherSupported(SSH_CIPHER_CHACHA20_POLY1305_OPENSSH), true)
        @Assert(sshIsCipherSupported(SSH_CIPHER_AES128_GCM_OPENSSH), true)
        @Assert(sshIsCipherSupported(SSH_CIPHER_AES256_GCM_OPENSSH), true)
        @Assert(sshIsMacSupported("hmac-sha2-256"), true)
        @Assert(sshIsMacSupported("hmac-sha2-512"), true)
        @Assert(sshIsMacSupported(SSH_MAC_ALGORITHM_UMAC64_OPENSSH), false)

        let preservedSessionId = incrementalBytes(32, start: 5)
        let resolved = sshResolveSessionId(clientResult.exchangeHash, existingSessionId: preservedSessionId)
        @Assert(resolved, preservedSessionId)
    }

    @TestCase
    public func testPacketProtectionLayerRoundTripAndMacReject(): Unit {
        let derived = buildAesCtrDerivedSessionKeys()
        let clientLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Client)
        let serverLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Server)

        let firstPayload = "ssh-active-data-1".toArray()
        let sealedFirst = clientLayer.seal(
            firstPayload,
            randomPadding: incrementalBytes(128, start: 137)
        )
        let openedFirst = serverLayer.open(sealedFirst)
        @Assert(openedFirst.payload, firstPayload)
        @Assert(clientLayer.writeSequence, 1)
        @Assert(serverLayer.readSequence, 1)

        let secondPayload = incrementalBytes(97, start: 33)
        let sealedSecond = serverLayer.seal(
            secondPayload,
            randomPadding: incrementalBytes(160, start: 211)
        )
        let openedSecond = clientLayer.open(sealedSecond)
        @Assert(openedSecond.payload, secondPayload)
        @Assert(serverLayer.writeSequence, 1)
        @Assert(clientLayer.readSequence, 1)

        let tampered = sealedFirst.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x80))
        let freshServerLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Server)
        try {
            _ = freshServerLayer.open(tampered)
            @Fail("tampered SSH packet MAC should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testDeriveSessionKeysSha256ForAeadCiphers(): Unit {
        let sharedSecret = incrementalBytes(32, start: 17)
        let exchangeHash = incrementalBytes(32, start: 71)
        let sessionId = exchangeHash.clone()

        let gcmNegotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            SSH_CIPHER_AES256_GCM_OPENSSH,
            SSH_CIPHER_AES128_GCM_OPENSSH,
            "none",
            "none",
            "none",
            "none"
        )
        let gcmDerived = sshDeriveSessionKeysSha256(sharedSecret, exchangeHash, sessionId, gcmNegotiated)
        @Assert(gcmDerived.clientToServer.iv.size, 12)
        @Assert(gcmDerived.clientToServer.encryptionKey.size, 32)
        @Assert(gcmDerived.clientToServer.integrityKey.size, 0)
        @Assert(gcmDerived.serverToClient.iv.size, 12)
        @Assert(gcmDerived.serverToClient.encryptionKey.size, 16)
        @Assert(gcmDerived.serverToClient.integrityKey.size, 0)

        let chachaNegotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-ed25519",
            SSH_CIPHER_CHACHA20_POLY1305_OPENSSH,
            SSH_CIPHER_CHACHA20_POLY1305_OPENSSH,
            "none",
            "none",
            "none",
            "none"
        )
        let chachaDerived = sshDeriveSessionKeysSha256(sharedSecret, exchangeHash, sessionId, chachaNegotiated)
        @Assert(chachaDerived.clientToServer.iv.size, 12)
        @Assert(chachaDerived.clientToServer.encryptionKey.size, 32)
        @Assert(chachaDerived.clientToServer.integrityKey.size, 0)
        @Assert(chachaDerived.serverToClient.iv.size, 12)
        @Assert(chachaDerived.serverToClient.encryptionKey.size, 32)
        @Assert(chachaDerived.serverToClient.integrityKey.size, 0)
    }

    @TestCase
    public func testPacketProtectionLayerAesGcmRoundTripAndTagReject(): Unit {
        let derived = buildAesGcmDerivedSessionKeys(SSH_CIPHER_AES128_GCM_OPENSSH)
        let clientLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Client)
        let serverLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Server)

        let payload = incrementalBytes(111, start: 44)
        let sealed = clientLayer.seal(payload, randomPadding: incrementalBytes(192, start: 31))
        let opened = serverLayer.open(sealed)
        @Assert(opened.payload, payload)
        @Assert(clientLayer.writeSequence, 1)
        @Assert(serverLayer.readSequence, 1)

        let tampered = sealed.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01))
        let freshServerLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Server)
        try {
            _ = freshServerLayer.open(tampered)
            @Fail("tampered SSH packet AEAD tag should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testPacketProtectionLayerChacha20Poly1305RoundTripAndTagReject(): Unit {
        let derived = buildChacha20Poly1305DerivedSessionKeys()
        let clientLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Client)
        let serverLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Server)

        let payload = incrementalBytes(149, start: 93)
        let sealed = clientLayer.seal(payload, randomPadding: incrementalBytes(224, start: 52))
        let opened = serverLayer.open(sealed)
        @Assert(opened.payload, payload)
        @Assert(clientLayer.writeSequence, 1)
        @Assert(serverLayer.readSequence, 1)

        let tampered = sealed.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x80))
        let freshServerLayer = sshBuildPacketProtectionLayer(derived, role: SshPeerRole.Server)
        try {
            _ = freshServerLayer.open(tampered)
            @Fail("tampered SSH packet ChaCha20-Poly1305 tag should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testHandshakeStateMachineTransitionsAndPhaseMismatch(): Unit {
        let state = SshHandshakeStateMachine()
        @Assert(state.phase.toString(), "IDENTIFICATION")

        try {
            state.markKexInitDone()
            @Fail("phase mismatch should reject KEXINIT completion")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        state.markVersionExchangeDone()
        @Assert(state.phase.toString(), "KEXINIT")
        state.markKexInitDone()
        @Assert(state.phase.toString(), "KEX_ECDH")
        state.markKexEcdhDone()
        @Assert(state.phase.toString(), "NEWKEYS")
        state.markNewKeysDone()
        @Assert(state.phase.toString(), "ACTIVE")
        state.ensureActive()

        state.beginRekey()
        @Assert(state.phase.toString(), "KEXINIT")
    }

    @TestCase
    public func testHandshakeCoordinatorActivatesTransportAndRoundTrip(): Unit {
        let (clientResult, serverResult) = buildX25519KexResults(72)
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-ed25519",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let clientCoordinator = SshHandshakeCoordinator(SshPeerRole.Client, negotiated)
        clientCoordinator.markVersionExchangeDone()
        clientCoordinator.markKexInitDone()
        clientCoordinator.markKexEcdhDone(clientResult)
        @Assert(clientCoordinator.phase.toString(), "NEWKEYS")
        @Assert(clientCoordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys()), false)
        @Assert(clientCoordinator.isActive, false)
        @Assert(clientCoordinator.acceptNewKeys(SshPeerRole.Client, sshEncodeNewKeys()), true)
        @Assert(clientCoordinator.isActive, true)

        let serverCoordinator = SshHandshakeCoordinator(SshPeerRole.Server, negotiated)
        serverCoordinator.markVersionExchangeDone()
        serverCoordinator.markKexInitDone()
        serverCoordinator.markKexEcdhDone(serverResult)
        @Assert(serverCoordinator.acceptNewKeys(SshPeerRole.Client, sshEncodeNewKeys()), false)
        @Assert(serverCoordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys()), true)
        @Assert(serverCoordinator.isActive, true)

        let payload = "ssh-active-coordinator".toArray()
        let sealed = clientCoordinator.seal(
            payload,
            randomPadding: incrementalBytes(128, start: 180)
        )
        let opened = serverCoordinator.open(sealed)
        @Assert(opened.payload, payload)
        @Assert(clientCoordinator.writeSequence, 1)
        @Assert(serverCoordinator.readSequence, 1)

        @Assert(clientCoordinator.sessionId(), clientResult.sessionId)
        let derived = clientCoordinator.derivedKeys()
        @Assert(derived.clientToServer.encryptionKey.size, 16)
        @Assert(derived.clientToServer.integrityKey.size, 32)
    }

    @TestCase
    public func testHandshakeCoordinatorRejectsPhaseMismatchAndReplay(): Unit {
        let (clientResult, _) = buildX25519KexResults(96)
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-rsa",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let coordinator = SshHandshakeCoordinator(SshPeerRole.Client, negotiated)
        try {
            _ = coordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys())
            @Fail("accept NEWKEYS before KEX_ECDH should fail")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        coordinator.markVersionExchangeDone()
        coordinator.markKexInitDone()
        coordinator.markKexEcdhDone(clientResult)
        _ = coordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys())
        try {
            _ = coordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys())
            @Fail("duplicate peer NEWKEYS should fail")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testCompleteInitialHandshakeCoordinatorHelper(): Unit {
        let (clientResult, serverResult) = buildX25519KexResults(120)
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-ed25519",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )
        let clientCoordinator = sshCompleteInitialHandshakeCoordinatorX25519(
            SshPeerRole.Client,
            clientResult,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        let serverCoordinator = sshCompleteInitialHandshakeCoordinatorX25519(
            SshPeerRole.Server,
            serverResult,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(clientCoordinator.isActive, true)
        @Assert(serverCoordinator.isActive, true)

        let payload = incrementalBytes(73, start: 27)
        let sealed = clientCoordinator.seal(
            payload,
            randomPadding: incrementalBytes(160, start: 222)
        )
        let opened = serverCoordinator.open(sealed)
        @Assert(opened.payload, payload)
    }

    @TestCase
    public func testHandshakeCoordinatorRekeyPreservesSessionIdAndRotatesKeys(): Unit {
        let (clientInitial, serverInitial) = buildX25519KexResults(152)
        let (clientRekey, serverRekey) = buildX25519KexResults(216)
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "ssh-ed25519",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let clientCoordinator = sshCompleteInitialHandshakeCoordinatorX25519(
            SshPeerRole.Client,
            clientInitial,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        let serverCoordinator = sshCompleteInitialHandshakeCoordinatorX25519(
            SshPeerRole.Server,
            serverInitial,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        let initialSessionId = clientCoordinator.sessionId()
        let initialClientKey = clientCoordinator.derivedKeys().clientToServer.encryptionKey

        let clientAfterRekey = clientCoordinator.rekeyWithX25519(
            clientRekey,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        let serverAfterRekey = serverCoordinator.rekeyWithX25519(
            serverRekey,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(clientCoordinator.sessionId(), initialSessionId)
        @Assert(serverCoordinator.sessionId(), initialSessionId)
        @Assert(bytesEqual(clientAfterRekey.sessionId, initialSessionId), true)
        @Assert(bytesEqual(serverAfterRekey.sessionId, initialSessionId), true)
        @Assert(bytesEqual(initialClientKey, clientAfterRekey.clientToServer.encryptionKey), false)

        let payload = "ssh-rekey-active".toArray()
        let sealed = clientCoordinator.seal(
            payload,
            randomPadding: incrementalBytes(128, start: 33)
        )
        let opened = serverCoordinator.open(sealed)
        @Assert(opened.payload, payload)
    }

    @TestCase
    public func testHandshakeCoordinatorRekeyRequiresActiveState(): Unit {
        let (clientKexResult, _) = buildX25519KexResults(248)
        let coordinator = SshHandshakeCoordinator(
            SshPeerRole.Client,
            SshNegotiatedAlgorithms(
                "curve25519-sha256",
                "ssh-ed25519",
                "aes128-ctr",
                "aes128-ctr",
                "hmac-sha2-256",
                "hmac-sha2-256",
                "none",
                "none"
            )
        )
        try {
            _ = coordinator.rekeyWithX25519(
                clientKexResult,
                sshEncodeNewKeys(),
                sshEncodeNewKeys()
            )
            @Fail("rekey before ACTIVE should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyServerHostSignatureRsaSha2(): Unit {
        let exchangeHash = sha256("ssh-host-signature-rsa".toArray())
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = sshEncodeRsaHostPublicKey(privateKey.publicKey)
        let signatureSha256 = sshSignExchangeHashRsa(privateKey, exchangeHash)
        let signatureSha512 = sshSignExchangeHashRsa(
            privateKey,
            exchangeHash,
            signatureAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA512
        )
        @Assert(sshExtractHostKeyAlgorithm(hostKeyBlob), SSH_HOST_KEY_ALGORITHM_RSA)
        @Assert(sshExtractHostSignatureAlgorithm(signatureSha256), SSH_HOST_KEY_ALGORITHM_RSA_SHA256)
        @Assert(sshExtractHostSignatureAlgorithm(signatureSha512), SSH_HOST_KEY_ALGORITHM_RSA_SHA512)

        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureSha256,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256
            ),
            true
        )
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureSha512,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA512
            ),
            true
        )
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureSha256,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA512
            ),
            false
        )

        let tampered = signatureSha256.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01))
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                tampered,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256
            ),
            false
        )

        let kexResult = SshX25519KexResult(
            incrementalBytes(32, start: 3),
            exchangeHash,
            exchangeHash,
            incrementalBytes(32, start: 35),
            incrementalBytes(32, start: 67),
            hostKeyBlob,
            signatureSha512
        )
        @Assert(
            sshVerifyServerHostSignatureFromKexResult(
                kexResult,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA512
            ),
            true
        )
    }

    @TestCase
    public func testVerifyServerHostSignatureEcdsaP256(): Unit {
        let exchangeHash = sha256("ssh-host-signature-ecdsa".toArray())
        let privateKey = EcPrivateKey(P256, BigNum.one())
        let publicKey = EcPublicKey(
            P256,
            BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"),
            BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")
        )
        let hostKeyBlob = sshEncodeEcdsaHostPublicKey(publicKey)
        let signatureBlob = sshSignExchangeHashEcdsa(privateKey, exchangeHash)
        @Assert(sshExtractHostKeyAlgorithm(hostKeyBlob), SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256)
        @Assert(sshExtractHostSignatureAlgorithm(signatureBlob), SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256)

        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256
            ),
            true
        )

        let tampered = signatureBlob.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x40))
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                tampered,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256
            ),
            false
        )

        let invalidCurveHostKeyBlob = hostKeyBlob.clone()
        let invalidCurveName = "nistp999".toArray()
        var curveNameOffset = 4 + SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256.size + 4
        var curveIndex = 0
        while (curveIndex < invalidCurveName.size) {
            invalidCurveHostKeyBlob[curveNameOffset + curveIndex] = invalidCurveName[curveIndex]
            curveIndex += 1
        }
        try {
            _ = sshVerifyServerHostSignature(
                exchangeHash,
                invalidCurveHostKeyBlob,
                signatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256
            )
            @Fail("unsupported SSH ECDSA host key curve should surface as Unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testVerifyServerHostSignatureEcdsaP384(): Unit {
        let exchangeHash = sha256("ssh-host-signature-ecdsa-p384".toArray())
        let privateKey = EcPrivateKey(P384, BigNum.one())
        let publicKey = EcPublicKey(
            P384,
            BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7"),
            BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F")
        )
        let hostKeyBlob = sshEncodeEcdsaHostPublicKey(publicKey)
        let signatureBlob = sshSignExchangeHashEcdsa(privateKey, exchangeHash)
        @Assert(sshExtractHostKeyAlgorithm(hostKeyBlob), SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384)
        @Assert(sshExtractHostSignatureAlgorithm(signatureBlob), SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384)

        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384
            ),
            true
        )

        let tampered = signatureBlob.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x02))
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                tampered,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384
            ),
            false
        )
    }

    @TestCase
    public func testVerifyServerHostSignatureLegacyRsaSha1Gate(): Unit {
        let exchangeHash = sha256("ssh-host-signature-rsa-sha1".toArray())
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = sshEncodeRsaHostPublicKey(privateKey.publicKey)
        let signatureSha1 = sshSignExchangeHashRsa(
            privateKey,
            exchangeHash,
            signatureAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA
        )
        @Assert(sshExtractHostKeyAlgorithm(hostKeyBlob), SSH_HOST_KEY_ALGORITHM_RSA)
        @Assert(sshExtractHostSignatureAlgorithm(signatureSha1), SSH_HOST_KEY_ALGORITHM_RSA)

        try {
            _ = sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureSha1,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA
            )
            @Fail("rsa-sha1 verification should remain blocked by default")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureSha1,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA,
                allowLegacyRsaSha1: true
            ),
            true
        )

        let tampered = signatureSha1.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01))
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                tampered,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA,
                allowLegacyRsaSha1: true
            ),
            false
        )
    }

    @TestCase
    public func testVerifyServerHostSignatureEd25519(): Unit {
        let exchangeHash = hexToBytes("72")
        let seed = hexToBytes("4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb")
        let publicKey = hexToBytes("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c")
        let signature = hexToBytes(
            "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
            "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
        )
        @Assert(ed25519PublicKeyFromSeed(seed), publicKey)
        @Assert(ed25519Sign(seed, exchangeHash), signature)

        let hostKeyBlob = sshBuildEd25519HostKeyBlobFromSeed(seed)
        let signatureBlob = sshSignExchangeHashEd25519(seed, exchangeHash)
        @Assert(sshExtractHostKeyAlgorithm(hostKeyBlob), SSH_HOST_KEY_ALGORITHM_ED25519)
        @Assert(sshExtractHostSignatureAlgorithm(signatureBlob), SSH_HOST_KEY_ALGORITHM_ED25519)

        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ED25519
            ),
            true
        )

        let tampered = signatureBlob.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01))
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                tampered,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ED25519
            ),
            false
        )
    }

    @TestCase
    public func testEncodeEd25519HostKeyAndSignatureHelpers(): Unit {
        let seed = hexToBytes("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        let publicKey = ed25519PublicKeyFromSeed(seed)
        let exchangeHash = sha256("ssh-ed25519-helper-round-trip".toArray())
        let rawSignature = ed25519Sign(seed, exchangeHash)

        let hostKeyBlob = sshEncodeEd25519HostPublicKey(publicKey)
        let signatureBlob = sshEncodeEd25519HostSignature(rawSignature)

        @Assert(sshExtractHostKeyAlgorithm(hostKeyBlob), SSH_HOST_KEY_ALGORITHM_ED25519)
        @Assert(sshExtractHostSignatureAlgorithm(signatureBlob), SSH_HOST_KEY_ALGORITHM_ED25519)
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                hostKeyBlob,
                signatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ED25519
            ),
            true
        )
    }

    @TestCase
    public func testEncodeRsaAndEcdsaHostKeyAndSignatureHelpers(): Unit {
        let exchangeHash = sha256("ssh-rsa-ecdsa-helper-round-trip".toArray())

        let rsaPrivateKey = loadRsa2048VectorPrivateKey()
        let rsaHostKeyBlob = sshEncodeRsaHostPublicKey(rsaPrivateKey.publicKey)
        let rsaRawSignature = rsaSignPkcs1v15WithHash(
            rsaPrivateKey,
            sha256(exchangeHash),
            RsaHashAlgorithm.SHA256
        )
        let rsaSignatureBlob = sshEncodeRsaHostSignature(SSH_HOST_KEY_ALGORITHM_RSA_SHA256, rsaRawSignature)
        @Assert(sshExtractHostKeyAlgorithm(rsaHostKeyBlob), SSH_HOST_KEY_ALGORITHM_RSA)
        @Assert(sshExtractHostSignatureAlgorithm(rsaSignatureBlob), SSH_HOST_KEY_ALGORITHM_RSA_SHA256)
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                rsaHostKeyBlob,
                rsaSignatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256
            ),
            true
        )

        let ecdsaPrivateKey = EcPrivateKey(P256, BigNum.one())
        let ecdsaPublicKey = EcPublicKey(
            P256,
            BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"),
            BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")
        )
        let ecdsaHostKeyBlob = sshEncodeEcdsaHostPublicKey(ecdsaPublicKey)
        let (r, s) = ecdsaSign(ecdsaPrivateKey, sha256(exchangeHash))
        let ecdsaSignatureBlob = sshEncodeEcdsaHostSignature(P256, r, s)
        @Assert(sshExtractHostKeyAlgorithm(ecdsaHostKeyBlob), SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256)
        @Assert(sshExtractHostSignatureAlgorithm(ecdsaSignatureBlob), SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256)
        @Assert(
            sshVerifyServerHostSignature(
                exchangeHash,
                ecdsaHostKeyBlob,
                ecdsaSignatureBlob,
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256
            ),
            true
        )

        try {
            _ = sshEncodeEcdsaHostSignature(P521, BigNum.one(), BigNum.one())
            @Fail("unsupported SSH ECDSA P-521 helper should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testRequireVerifiedHostIdentityPolicy(): Unit {
        let exchangeHash = sha256("ssh-host-identity-policy".toArray())
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let signatureBlob = buildSshRsaHostSignatureBlob(
            privateKey,
            exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA_SHA256
        )
        let kexResult = SshX25519KexResult(
            incrementalBytes(32, start: 11),
            exchangeHash,
            exchangeHash,
            incrementalBytes(32, start: 43),
            incrementalBytes(32, start: 75),
            hostKeyBlob,
            signatureBlob
        )
        let pinnedFingerprint = sha256(hostKeyBlob)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: pinnedFingerprint,
            requireKnownHost: true,
            requireHostSignature: true
        )
        let verified = sshRequireVerifiedHostIdentity(kexResult, policy: policy)
        @Assert(verified.hostKeyAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA)
        @Assert(verified.hostSignatureAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA_SHA256)
        @Assert(verified.hostKeySha256, pinnedFingerprint)
        @Assert(verified.hostSignatureVerified, true)

        try {
            _ = sshRequireVerifiedHostIdentity(
                kexResult,
                policy: SshHostVerificationPolicy(
                    negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
                    expectedHostKeySha256: incrementalBytes(32, start: 200),
                    requireKnownHost: true,
                    requireHostSignature: true
                )
            )
            @Fail("known-host fingerprint mismatch should fail")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let tampered = signatureBlob.clone()
        tampered[tampered.size - 1] = UInt8(UInt8(tampered[tampered.size - 1]) ^ UInt8(0x20))
        let tamperedResult = SshX25519KexResult(
            kexResult.sharedSecret,
            kexResult.exchangeHash,
            kexResult.sessionId,
            kexResult.clientEphemeralPublicKey,
            kexResult.serverEphemeralPublicKey,
            kexResult.serverHostKey,
            tampered
        )
        let pinnedOnly = sshRequireVerifiedHostIdentity(
            tamperedResult,
            policy: SshHostVerificationPolicy(
                expectedHostKeySha256: pinnedFingerprint,
                requireKnownHost: true,
                requireHostSignature: false
            )
        )
        @Assert(pinnedOnly.hostSignatureVerified, false)
    }

    @TestCase
    public func testRequireVerifiedHostIdentityLegacyRsaSha1Gate(): Unit {
        let exchangeHash = sha256("ssh-host-identity-rsa-sha1-gate".toArray())
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let signatureBlob = buildSshRsaHostSignatureBlob(
            privateKey,
            exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA
        )
        let kexResult = SshX25519KexResult(
            incrementalBytes(32, start: 21),
            exchangeHash,
            exchangeHash,
            incrementalBytes(32, start: 53),
            incrementalBytes(32, start: 85),
            hostKeyBlob,
            signatureBlob
        )
        try {
            _ = sshRequireVerifiedHostIdentity(
                kexResult,
                policy: SshHostVerificationPolicy(
                    negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA,
                    requireHostSignature: true
                )
            )
            @Fail("legacy ssh-rsa must be blocked without explicit allowLegacyRsaSha1")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let verified = sshRequireVerifiedHostIdentity(
            kexResult,
            policy: SshHostVerificationPolicy(
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA,
                requireHostSignature: true,
                allowLegacyRsaSha1: true
            )
        )
        @Assert(verified.hostSignatureVerified, true)
        @Assert(verified.hostSignatureAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA)
    }

    @TestCase
    public func testClientProcessKexEcdhReplyX25519VerifiedPath(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_verified\r\n".toArray(),
            "SSH-2.0-jinkui-server_verified\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 12))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 52)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)

        let (_, provisionalResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            incrementalBytes(64, start: 131)
        )
        let signature = buildSshRsaHostSignatureBlob(
            privateKey,
            provisionalResult.exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA_SHA256
        )
        let (encodedReply, serverResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            signature
        )
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(hostKeyBlob),
            requireKnownHost: true,
            requireHostSignature: true
        )

        let clientResult = sshClientProcessKexEcdhReplyX25519Verified(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply,
            policy: policy
        )
        @Assert(clientResult.exchangeHash, serverResult.exchangeHash)
        @Assert(clientResult.sessionId, serverResult.sessionId)

        let tamperedReply = encodedReply.clone()
        tamperedReply[tamperedReply.size - 1] = UInt8(UInt8(tamperedReply[tamperedReply.size - 1]) ^ UInt8(0x80))
        try {
            _ = sshClientProcessKexEcdhReplyX25519Verified(
                transcript,
                clientPrivate,
                encodedInit,
                tamperedReply,
                policy: policy
            )
            @Fail("tampered host signature should fail verified client processing")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testHandshakeCoordinatorMarkKexEcdhDoneVerifiedPath(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(160)
        let hostKeyFingerprint = sha256(clientResult.serverHostKey)
        let coordinator = SshHandshakeCoordinator(
            SshPeerRole.Client,
            SshNegotiatedAlgorithms(
                "curve25519-sha256",
                "rsa-sha2-256",
                "aes128-ctr",
                "aes128-ctr",
                "hmac-sha2-256",
                "hmac-sha2-256",
                "none",
                "none"
            )
        )
        coordinator.markVersionExchangeDone()
        coordinator.markKexInitDone()
        let verification = coordinator.markKexEcdhDoneVerified(
            clientResult,
            policy: SshHostVerificationPolicy(
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
                expectedHostKeySha256: hostKeyFingerprint,
                requireKnownHost: true,
                requireHostSignature: true
            )
        )
        @Assert(coordinator.phase.toString(), "NEWKEYS")
        @Assert(verification.hostSignatureVerified, true)
        @Assert(verification.hostKeySha256, hostKeyFingerprint)

        _ = coordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys())
        _ = coordinator.acceptNewKeys(SshPeerRole.Client, sshEncodeNewKeys())
        @Assert(coordinator.isActive, true)
        @Assert(coordinator.hostVerification().hostSignatureAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA_SHA256)
    }

    @TestCase
    public func testHandshakeCoordinatorMarkKexEcdhDoneVerifiedRejectsTamperedSignature(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(190)
        let tamperedSignature = clientResult.hostSignature.clone()
        tamperedSignature[tamperedSignature.size - 1] =
            UInt8(UInt8(tamperedSignature[tamperedSignature.size - 1]) ^ UInt8(0x01))
        let tamperedResult = SshX25519KexResult(
            clientResult.sharedSecret,
            clientResult.exchangeHash,
            clientResult.sessionId,
            clientResult.clientEphemeralPublicKey,
            clientResult.serverEphemeralPublicKey,
            clientResult.serverHostKey,
            tamperedSignature
        )

        let coordinator = SshHandshakeCoordinator(
            SshPeerRole.Client,
            SshNegotiatedAlgorithms(
                "curve25519-sha256",
                "rsa-sha2-256",
                "aes128-ctr",
                "aes128-ctr",
                "hmac-sha2-256",
                "hmac-sha2-256",
                "none",
                "none"
            )
        )
        coordinator.markVersionExchangeDone()
        coordinator.markKexInitDone()
        try {
            _ = coordinator.markKexEcdhDoneVerified(
                tamperedResult,
                policy: SshHostVerificationPolicy(
                    negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
                    expectedHostKeySha256: sha256(clientResult.serverHostKey),
                    requireKnownHost: true,
                    requireHostSignature: true
                )
            )
            @Fail("tampered signature must fail before coordinator enters NEWKEYS")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
        @Assert(coordinator.phase.toString(), "KEX_ECDH")
    }

    @TestCase
    public func testCompleteInitialHandshakeCoordinatorX25519VerifiedHelper(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(220)
        let coordinator = sshCompleteInitialHandshakeCoordinatorX25519Verified(
            SshPeerRole.Client,
            clientResult,
            SshNegotiatedAlgorithms(
                "curve25519-sha256",
                "rsa-sha2-256",
                "aes128-ctr",
                "aes128-ctr",
                "hmac-sha2-256",
                "hmac-sha2-256",
                "none",
                "none"
            ),
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            policy: SshHostVerificationPolicy(
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
                expectedHostKeySha256: sha256(clientResult.serverHostKey),
                requireKnownHost: true,
                requireHostSignature: true
            )
        )
        @Assert(coordinator.isActive, true)
        @Assert(coordinator.hostVerification().hostSignatureVerified, true)
    }

    @TestCase
    public func testVerifyHostIdentityWithRequirementModes(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(260)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(clientResult.serverHostKey),
            requireKnownHost: true,
            requireHostSignature: true
        )

        let requiredOk = sshVerifyHostIdentityWithRequirement(
            clientResult,
            policy: policy,
            requireVerifiedHost: true
        )
        match (requiredOk) {
            case Some(value) =>
                @Assert(value.hostSignatureVerified, true)
                @Assert(value.hostSignatureAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA_SHA256)
            case None =>
                @Fail("required host verification should return verification result")
        }

        let tamperedResult = tamperSshKexHostSignature(clientResult, 0x01)
        try {
            _ = sshVerifyHostIdentityWithRequirement(
                tamperedResult,
                policy: policy,
                requireVerifiedHost: true
            )
            @Fail("required host verification must fail on tampered host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let optionalResult = sshVerifyHostIdentityWithRequirement(
            tamperedResult,
            policy: policy,
            requireVerifiedHost: false
        )
        match (optionalResult) {
            case Some(_) =>
                @Fail("optional host verification should return None for tampered signature")
            case None =>
                @Assert(true, true)
        }
    }

    @TestCase
    public func testVerifyHostIdentityWithRequirementLegacyRsaSha1Gate(): Unit {
        let exchangeHash = sha256("ssh-host-identity-requirement-rsa-sha1-gate".toArray())
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let signatureBlob = buildSshRsaHostSignatureBlob(
            privateKey,
            exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA
        )
        let kexResult = SshX25519KexResult(
            incrementalBytes(32, start: 17),
            exchangeHash,
            exchangeHash,
            incrementalBytes(32, start: 49),
            incrementalBytes(32, start: 81),
            hostKeyBlob,
            signatureBlob
        )
        let blockedPolicy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA,
            requireHostSignature: true
        )

        try {
            _ = sshVerifyHostIdentityWithRequirement(
                kexResult,
                policy: blockedPolicy,
                requireVerifiedHost: true
            )
            @Fail("required mode must reject legacy ssh-rsa when allowLegacyRsaSha1=false")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let optionalBlocked = sshVerifyHostIdentityWithRequirement(
            kexResult,
            policy: blockedPolicy,
            requireVerifiedHost: false
        )
        match (optionalBlocked) {
            case Some(_) =>
                @Fail("optional mode should return None when legacy ssh-rsa is blocked")
            case None =>
                @Assert(true, true)
        }

        let optionalAllowed = sshVerifyHostIdentityWithRequirement(
            kexResult,
            policy: SshHostVerificationPolicy(
                negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA,
                requireHostSignature: true,
                allowLegacyRsaSha1: true
            ),
            requireVerifiedHost: false
        )
        match (optionalAllowed) {
            case Some(value) =>
                @Assert(value.hostSignatureAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA)
                @Assert(value.hostSignatureVerified, true)
            case None =>
                @Fail("allowLegacyRsaSha1=true should allow optional verification to return value")
        }
    }

    @TestCase
    public func testVerifyHostIdentityWithConfigFactories(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(380)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(clientResult.serverHostKey),
            requireKnownHost: true,
            requireHostSignature: true
        )
        let strictConfig = sshHostVerificationConfigRequired(policy: policy)
        let strictResult = sshVerifyHostIdentityWithConfig(clientResult, config: strictConfig)
        match (strictResult) {
            case Some(value) =>
                @Assert(value.hostSignatureVerified, true)
                @Assert(value.hostSignatureAlgorithm, SSH_HOST_KEY_ALGORITHM_RSA_SHA256)
            case None =>
                @Fail("required config should return verification result on valid host signature")
        }

        let tamperedResult = tamperSshKexHostSignature(clientResult, 0x08)
        let optionalConfig = sshHostVerificationConfigOptional(policy: policy)
        let optionalResult = sshVerifyHostIdentityWithConfig(tamperedResult, config: optionalConfig)
        match (optionalResult) {
            case Some(_) =>
                @Fail("optional config should return None on tampered host signature")
            case None =>
                @Assert(true, true)
        }
    }

    @TestCase
    public func testHandshakeCoordinatorMarkKexEcdhDoneWithHostVerificationConfigModes(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(420)
        let tamperedResult = tamperSshKexHostSignature(clientResult, 0x10)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(clientResult.serverHostKey),
            requireKnownHost: true,
            requireHostSignature: true
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )
        let optionalCoordinator = SshHandshakeCoordinator(SshPeerRole.Client, negotiated)
        optionalCoordinator.markVersionExchangeDone()
        optionalCoordinator.markKexInitDone()
        let optionalResult = optionalCoordinator.markKexEcdhDoneWithHostVerificationConfig(
            tamperedResult,
            config: sshHostVerificationConfigOptional(policy: policy)
        )
        match (optionalResult) {
            case Some(_) =>
                @Fail("optional config path should not return host verification for tampered signature")
            case None =>
                @Assert(optionalCoordinator.phase.toString(), "NEWKEYS")
        }

        let requiredCoordinator = SshHandshakeCoordinator(SshPeerRole.Client, negotiated)
        requiredCoordinator.markVersionExchangeDone()
        requiredCoordinator.markKexInitDone()
        try {
            _ = requiredCoordinator.markKexEcdhDoneWithHostVerificationConfig(
                tamperedResult,
                config: sshHostVerificationConfigRequired(policy: policy)
            )
            @Fail("required config path must reject tampered host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
        @Assert(requiredCoordinator.phase.toString(), "KEX_ECDH")
    }

    @TestCase
    public func testHandshakeCoordinatorMarkKexEcdhDoneWithHostVerificationRequirementModes(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(300)
        let tamperedResult = tamperSshKexHostSignature(clientResult, 0x02)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(clientResult.serverHostKey),
            requireKnownHost: true,
            requireHostSignature: true
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let optionalCoordinator = SshHandshakeCoordinator(SshPeerRole.Client, negotiated)
        optionalCoordinator.markVersionExchangeDone()
        optionalCoordinator.markKexInitDone()
        let optionalVerification = optionalCoordinator.markKexEcdhDoneWithHostVerificationRequirement(
            tamperedResult,
            policy: policy,
            requireVerifiedHost: false
        )
        match (optionalVerification) {
            case Some(_) =>
                @Fail("optional coordinator path should not return verification on tampered signature")
            case None =>
                @Assert(optionalCoordinator.phase.toString(), "NEWKEYS")
        }

        _ = optionalCoordinator.acceptNewKeys(SshPeerRole.Client, sshEncodeNewKeys())
        _ = optionalCoordinator.acceptNewKeys(SshPeerRole.Server, sshEncodeNewKeys())
        @Assert(optionalCoordinator.isActive, true)
        try {
            _ = optionalCoordinator.hostVerification()
            @Fail("optional host verification should not populate hostVerification()")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let requiredCoordinator = SshHandshakeCoordinator(SshPeerRole.Client, negotiated)
        requiredCoordinator.markVersionExchangeDone()
        requiredCoordinator.markKexInitDone()
        try {
            _ = requiredCoordinator.markKexEcdhDoneWithHostVerificationRequirement(
                tamperedResult,
                policy: policy,
                requireVerifiedHost: true
            )
            @Fail("required coordinator path must reject tampered host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
        @Assert(requiredCoordinator.phase.toString(), "KEX_ECDH")
    }

    @TestCase
    public func testCompleteInitialHandshakeCoordinatorX25519WithHostVerificationRequirementModes(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(340)
        let tamperedResult = tamperSshKexHostSignature(clientResult, 0x04)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(clientResult.serverHostKey),
            requireKnownHost: true,
            requireHostSignature: true
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let optionalCoordinator = sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
            SshPeerRole.Client,
            tamperedResult,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            policy: policy,
            requireVerifiedHost: false
        )
        @Assert(optionalCoordinator.isActive, true)
        try {
            _ = optionalCoordinator.hostVerification()
            @Fail("optional helper should keep host verification empty when verification fails")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
                SshPeerRole.Client,
                tamperedResult,
                negotiated,
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                policy: policy,
                requireVerifiedHost: true
            )
            @Fail("required helper must fail on tampered host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testCompleteInitialHandshakeCoordinatorX25519WithHostVerificationConfigModes(): Unit {
        let clientResult = buildVerifiedRsaClientKexResult(460)
        let tamperedResult = tamperSshKexHostSignature(clientResult, 0x20)
        let policy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(clientResult.serverHostKey),
            requireKnownHost: true,
            requireHostSignature: true
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let optionalCoordinator = sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
            SshPeerRole.Client,
            tamperedResult,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            config: sshHostVerificationConfigOptional(policy: policy)
        )
        @Assert(optionalCoordinator.isActive, true)
        try {
            _ = optionalCoordinator.hostVerification()
            @Fail("optional config helper should keep host verification empty on verification failure")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = sshCompleteInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
                SshPeerRole.Client,
                tamperedResult,
                negotiated,
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                config: sshHostVerificationConfigRequired(policy: policy)
            )
            @Fail("required config helper must fail on tampered host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testCompleteServerInitialHandshakeX25519ResultWrapperRoundTrip(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_srv_result\r\n".toArray(),
            "SSH-2.0-jinkui-server_srv_result\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 940))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 980)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)

        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let (_, provisionalResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            incrementalBytes(64, start: 1020)
        )
        let hostSignature = buildSshRsaHostSignatureBlob(
            privateKey,
            provisionalResult.exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA_SHA256
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let serverCompleted = sshCompleteServerInitialHandshakeX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            hostSignature,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(serverCompleted.coordinator.isActive, true)
        @Assert(serverCompleted.kexResult.exchangeHash.size, 32)

        let clientCompleted = sshCompleteClientInitialHandshakeX25519(
            transcript,
            clientPrivate,
            encodedInit,
            serverCompleted.encodedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(clientCompleted.coordinator.isActive, true)
        match (clientCompleted.hostVerification) {
            case Some(_) =>
                @Fail("plain client wrapper should not set host verification")
            case None =>
                @Assert(true, true)
        }
        @Assert(clientCompleted.coordinator.sessionId(), serverCompleted.coordinator.sessionId())

        let fromClient = clientCompleted.coordinator.seal(
            "client->server(result)".toArray(),
            randomPadding: incrementalBytes(64, start: 1088)
        )
        @Assert(serverCompleted.coordinator.open(fromClient).payload, "client->server(result)".toArray())

        let fromServer = serverCompleted.coordinator.seal(
            "server->client(result)".toArray(),
            randomPadding: incrementalBytes(64, start: 1168)
        )
        @Assert(clientCompleted.coordinator.open(fromServer).payload, "server->client(result)".toArray())
    }

    @TestCase
    public func testCompleteClientInitialHandshakeX25519ResultWrapperModes(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_result_modes\r\n".toArray(),
            "SSH-2.0-jinkui-server_result_modes\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 1248))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 1288)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let (_, provisionalResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            incrementalBytes(64, start: 1328)
        )
        let hostSignature = buildSshRsaHostSignatureBlob(
            privateKey,
            provisionalResult.exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA_SHA256
        )
        let (encodedReply, _) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            hostSignature
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )
        let hostPolicy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(hostKeyBlob),
            requireKnownHost: true,
            requireHostSignature: true
        )

        let plainCompleted = sshCompleteClientInitialHandshakeX25519(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(plainCompleted.coordinator.isActive, true)
        match (plainCompleted.hostVerification) {
            case Some(_) =>
                @Fail("plain wrapper should not have host verification")
            case None =>
                @Assert(true, true)
        }
        try {
            _ = plainCompleted.requireHostVerification()
            @Fail("plain wrapper should not have host verification result")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let verifiedCompleted = sshCompleteClientInitialHandshakeX25519Verified(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            policy: hostPolicy
        )
        @Assert(verifiedCompleted.coordinator.isActive, true)
        @Assert(verifiedCompleted.requireHostVerification().hostSignatureVerified, true)

        let tamperedReply = encodedReply.clone()
        tamperedReply[tamperedReply.size - 1] = UInt8(UInt8(tamperedReply[tamperedReply.size - 1]) ^ UInt8(0x01))

        let optionalCompleted = sshCompleteClientInitialHandshakeX25519WithHostVerificationConfig(
            transcript,
            clientPrivate,
            encodedInit,
            tamperedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            config: sshHostVerificationConfigOptional(policy: hostPolicy)
        )
        @Assert(optionalCompleted.coordinator.isActive, true)
        match (optionalCompleted.hostVerification) {
            case Some(_) =>
                @Fail("optional wrapper should keep host verification empty on tampered signature")
            case None =>
                @Assert(true, true)
        }

        try {
            _ = sshCompleteClientInitialHandshakeX25519WithHostVerificationRequirement(
                transcript,
                clientPrivate,
                encodedInit,
                tamperedReply,
                negotiated,
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                policy: hostPolicy,
                requireVerifiedHost: true
            )
            @Fail("required wrapper should reject tampered host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testCompleteServerInitialHandshakeCoordinatorX25519HelperRoundTrip(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_srv_helper\r\n".toArray(),
            "SSH-2.0-jinkui-server_srv_helper\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 700))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 740)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)

        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let (_, provisionalResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            incrementalBytes(64, start: 780)
        )
        let hostSignature = buildSshRsaHostSignatureBlob(
            privateKey,
            provisionalResult.exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA_SHA256
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )

        let (encodedReply, serverCoordinator) = sshCompleteServerInitialHandshakeCoordinatorX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            hostSignature,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(serverCoordinator.isActive, true)
        @Assert(serverCoordinator.sessionId().size, 32)

        let clientCoordinator = sshCompleteClientInitialHandshakeCoordinatorX25519(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(clientCoordinator.isActive, true)
        @Assert(clientCoordinator.sessionId(), serverCoordinator.sessionId())

        let fromClient = clientCoordinator.seal("client->server".toArray(), randomPadding: incrementalBytes(64, start: 821))
        @Assert(serverCoordinator.open(fromClient).payload, "client->server".toArray())

        let fromServer = serverCoordinator.seal("server->client".toArray(), randomPadding: incrementalBytes(64, start: 901))
        @Assert(clientCoordinator.open(fromServer).payload, "server->client".toArray())
    }

    @TestCase
    public func testCompleteClientInitialHandshakeCoordinatorX25519HelperModes(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = SshKexExchangeTranscript(
            "SSH-2.0-jinkui-client_helper\r\n".toArray(),
            "SSH-2.0-jinkui-server_helper\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 520))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 560)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let privateKey = loadRsa2048VectorPrivateKey()
        let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)
        let (_, provisionalResult) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            incrementalBytes(64, start: 600)
        )
        let hostSignature = buildSshRsaHostSignatureBlob(
            privateKey,
            provisionalResult.exchangeHash,
            SSH_HOST_KEY_ALGORITHM_RSA_SHA256
        )
        let (encodedReply, _) = sshServerProcessKexEcdhInitX25519(
            transcript,
            serverPrivate,
            encodedInit,
            hostKeyBlob,
            hostSignature
        )
        let negotiated = SshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            "none",
            "none"
        )
        let hostPolicy = SshHostVerificationPolicy(
            negotiatedHostKeyAlgorithm: SSH_HOST_KEY_ALGORITHM_RSA_SHA256,
            expectedHostKeySha256: sha256(hostKeyBlob),
            requireKnownHost: true,
            requireHostSignature: true
        )

        let plainCoordinator = sshCompleteClientInitialHandshakeCoordinatorX25519(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys()
        )
        @Assert(plainCoordinator.isActive, true)
        @Assert(plainCoordinator.sessionId().size, 32)

        let verifiedCoordinator = sshCompleteClientInitialHandshakeCoordinatorX25519Verified(
            transcript,
            clientPrivate,
            encodedInit,
            encodedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            policy: hostPolicy
        )
        @Assert(verifiedCoordinator.isActive, true)
        @Assert(verifiedCoordinator.hostVerification().hostSignatureVerified, true)

        let tamperedReply = encodedReply.clone()
        tamperedReply[tamperedReply.size - 1] = UInt8(UInt8(tamperedReply[tamperedReply.size - 1]) ^ UInt8(0x01))

        let optionalCoordinator = sshCompleteClientInitialHandshakeCoordinatorX25519WithHostVerificationConfig(
            transcript,
            clientPrivate,
            encodedInit,
            tamperedReply,
            negotiated,
            sshEncodeNewKeys(),
            sshEncodeNewKeys(),
            config: sshHostVerificationConfigOptional(policy: hostPolicy)
        )
        @Assert(optionalCoordinator.isActive, true)
        try {
            _ = optionalCoordinator.hostVerification()
            @Fail("optional helper should not populate host verification on tampered signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = sshCompleteClientInitialHandshakeCoordinatorX25519WithHostVerificationRequirement(
                transcript,
                clientPrivate,
                encodedInit,
                tamperedReply,
                negotiated,
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                policy: hostPolicy,
                requireVerifiedHost: true
            )
            @Fail("required helper should reject tampered server reply host signature")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }
}

private func tamperSshKexHostSignature(
    kexResult: SshX25519KexResult,
    bitMask: Int64
): SshX25519KexResult {
    let tamperedSignature = kexResult.hostSignature.clone()
    tamperedSignature[tamperedSignature.size - 1] =
        UInt8(UInt8(tamperedSignature[tamperedSignature.size - 1]) ^ UInt8(bitMask))
    SshX25519KexResult(
        kexResult.sharedSecret,
        kexResult.exchangeHash,
        kexResult.sessionId,
        kexResult.clientEphemeralPublicKey,
        kexResult.serverEphemeralPublicKey,
        kexResult.serverHostKey,
        tamperedSignature
    )
}

private func buildVerifiedRsaClientKexResult(seedStart: Int64): SshX25519KexResult {
    let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
    let transcript = SshKexExchangeTranscript(
        "SSH-2.0-jinkui-client_verified_seed\r\n".toArray(),
        "SSH-2.0-jinkui-server_verified_seed\r\n".toArray(),
        sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: seedStart))),
        sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: seedStart + 40)))
    )
    let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
    let privateKey = loadRsa2048VectorPrivateKey()
    let hostKeyBlob = buildSshRsaHostKeyBlob(privateKey.publicKey)

    let (_, provisionalResult) = sshServerProcessKexEcdhInitX25519(
        transcript,
        serverPrivate,
        encodedInit,
        hostKeyBlob,
        incrementalBytes(64, start: seedStart + 96)
    )
    let signature = buildSshRsaHostSignatureBlob(
        privateKey,
        provisionalResult.exchangeHash,
        SSH_HOST_KEY_ALGORITHM_RSA_SHA256
    )
    let (encodedReply, _) = sshServerProcessKexEcdhInitX25519(
        transcript,
        serverPrivate,
        encodedInit,
        hostKeyBlob,
        signature
    )
    sshClientProcessKexEcdhReplyX25519(transcript, clientPrivate, encodedInit, encodedReply)
}

private func loadRsa2048VectorPrivateKey(): RsaPrivateKey {
    let content = String.fromUtf8(File.readFrom("testdata/stage3/rsa_params_sample.txt"))
    let lines = content.replace("\r", "\n").split('\n')

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
                inTarget = value == "RSA-2048"
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
            if (n.size != 0 && e.size != 0 && d.size != 0) {
                break
            }
        }
    }

    if (n.size == 0 || e.size == 0 || d.size == 0) {
        throw Exception("RSA-2048 vector not found in rsa_params_sample.txt")
    }
    rsaPrivateKeyFromHex(n, e, d)
}

private func buildSshRsaHostKeyBlob(publicKey: RsaPublicKey): Array<Byte> {
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_RSA.toArray()),
        encodeSshString(encodeSshMpintPositive(publicKey.exponent.toBytesBE())),
        encodeSshString(encodeSshMpintPositive(publicKey.modulus.toBytesBE()))
    )
}

private func buildSshRsaHostSignatureBlob(
    privateKey: RsaPrivateKey,
    exchangeHash: Array<Byte>,
    signatureAlgorithm: String
): Array<Byte> {
    let digest = if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA) {
        sha1(exchangeHash)
    } else if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        sha256(exchangeHash)
    } else if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA512) {
        sha512(exchangeHash)
    } else {
        throw Exception("unsupported RSA signature algorithm for test fixture")
    }

    let hashAlgorithm = if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA) {
        RsaHashAlgorithm.SHA1
    } else if (signatureAlgorithm == SSH_HOST_KEY_ALGORITHM_RSA_SHA256) {
        RsaHashAlgorithm.SHA256
    } else {
        RsaHashAlgorithm.SHA512
    }
    let signature = rsaSignPkcs1v15WithHash(privateKey, digest, hashAlgorithm)
    concatSshParts(
        encodeSshString(signatureAlgorithm.toArray()),
        encodeSshString(signature)
    )
}

private func buildSshEcdsaP256HostKeyBlob(publicKey: EcPublicKey): Array<Byte> {
    let encodedPoint = Array<Byte>(65, repeat: 0)
    encodedPoint[0] = UInt8(0x04)
    let x = publicKey.x.toBytesBE(paddedLen: 32)
    let y = publicKey.y.toBytesBE(paddedLen: 32)
    var i = 0
    while (i < 32) {
        encodedPoint[1 + i] = x[i]
        encodedPoint[33 + i] = y[i]
        i += 1
    }
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256.toArray()),
        encodeSshString("nistp256".toArray()),
        encodeSshString(encodedPoint)
    )
}

private func buildSshEcdsaP256HostSignatureBlob(
    privateKey: EcPrivateKey,
    exchangeHash: Array<Byte>
): Array<Byte> {
    let digest = sha256(exchangeHash)
    let (r, s) = ecdsaSign(privateKey, digest)
    let signaturePair = concatSshParts(
        encodeSshString(encodeSshMpintPositive(r.toBytesBE())),
        encodeSshString(encodeSshMpintPositive(s.toBytesBE()))
    )
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP256.toArray()),
        encodeSshString(signaturePair)
    )
}

private func buildSshEcdsaP384HostKeyBlob(publicKey: EcPublicKey): Array<Byte> {
    let encodedPoint = Array<Byte>(97, repeat: 0)
    encodedPoint[0] = UInt8(0x04)
    let x = publicKey.x.toBytesBE(paddedLen: 48)
    let y = publicKey.y.toBytesBE(paddedLen: 48)
    var i = 0
    while (i < 48) {
        encodedPoint[1 + i] = x[i]
        encodedPoint[49 + i] = y[i]
        i += 1
    }
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384.toArray()),
        encodeSshString("nistp384".toArray()),
        encodeSshString(encodedPoint)
    )
}

private func buildSshEcdsaP384HostSignatureBlob(
    privateKey: EcPrivateKey,
    exchangeHash: Array<Byte>
): Array<Byte> {
    let digest = sha384(exchangeHash)
    let (r, s) = ecdsaSign(privateKey, digest)
    let signaturePair = concatSshParts(
        encodeSshString(encodeSshMpintPositive(r.toBytesBE())),
        encodeSshString(encodeSshMpintPositive(s.toBytesBE()))
    )
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_ECDSA_NISTP384.toArray()),
        encodeSshString(signaturePair)
    )
}

private func buildSshEd25519HostKeyBlob(publicKey: Array<Byte>): Array<Byte> {
    if (publicKey.size != 32) {
        throw Exception("ed25519 public key fixture must be 32 bytes")
    }
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_ED25519.toArray()),
        encodeSshString(publicKey)
    )
}

private func buildSshEd25519HostSignatureBlob(signature: Array<Byte>): Array<Byte> {
    if (signature.size != 64) {
        throw Exception("ed25519 signature fixture must be 64 bytes")
    }
    concatSshParts(
        encodeSshString(SSH_HOST_KEY_ALGORITHM_ED25519.toArray()),
        encodeSshString(signature)
    )
}

private func encodeSshMpintPositive(unsigned: Array<Byte>): Array<Byte> {
    if (unsigned.size == 0) {
        return []
    }
    var start = 0
    while (start + 1 < unsigned.size && UInt8(unsigned[start]) == UInt8(0x00)) {
        start += 1
    }
    let trimmed = unsigned[start..]
    if (trimmed.size == 0) {
        return []
    }
    if ((UInt8(trimmed[0]) & UInt8(0x80)) != UInt8(0x00)) {
        let out = Array<Byte>(trimmed.size + 1, repeat: 0)
        var i = 0
        while (i < trimmed.size) {
            out[i + 1] = trimmed[i]
            i += 1
        }
        return out
    }
    trimmed
}

private func encodeSshString(data: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(4 + data.size, repeat: 0)
    out[0] = UInt8((data.size >> 24) & 0xff)
    out[1] = UInt8((data.size >> 16) & 0xff)
    out[2] = UInt8((data.size >> 8) & 0xff)
    out[3] = UInt8(data.size & 0xff)
    var i = 0
    while (i < data.size) {
        out[4 + i] = data[i]
        i += 1
    }
    out
}

private func concatSshParts(first: Array<Byte>, second: Array<Byte>): Array<Byte> {
    concatSshParts([first, second])
}

private func concatSshParts(first: Array<Byte>, second: Array<Byte>, third: Array<Byte>): Array<Byte> {
    concatSshParts([first, second, third])
}

private func concatSshParts(parts: Array<Array<Byte>>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (part in parts) {
        for (b in part) {
            out.add(b)
        }
    }
    out.toArray()
}

private func buildAesCtrDerivedSessionKeys(): SshDerivedSessionKeys {
    let clientToServer = SshDirectionKeyMaterial(
        "aes128-ctr",
        "hmac-sha2-256",
        incrementalBytes(16, start: 1),
        incrementalBytes(16, start: 33),
        incrementalBytes(32, start: 65)
    )
    let serverToClient = SshDirectionKeyMaterial(
        "aes128-ctr",
        "hmac-sha2-256",
        incrementalBytes(16, start: 97),
        incrementalBytes(16, start: 129),
        incrementalBytes(32, start: 161)
    )
    SshDerivedSessionKeys(incrementalBytes(32, start: 11), clientToServer, serverToClient)
}

private func buildAesGcmDerivedSessionKeys(cipherName: String): SshDerivedSessionKeys {
    let keyLen = if (cipherName == SSH_CIPHER_AES128_GCM_OPENSSH) {
        16
    } else {
        32
    }
    let clientToServer = SshDirectionKeyMaterial(
        cipherName,
        "none",
        incrementalBytes(12, start: 17),
        incrementalBytes(keyLen, start: 49),
        []
    )
    let serverToClient = SshDirectionKeyMaterial(
        cipherName,
        "none",
        incrementalBytes(12, start: 81),
        incrementalBytes(keyLen, start: 113),
        []
    )
    SshDerivedSessionKeys(incrementalBytes(32, start: 145), clientToServer, serverToClient)
}

private func buildChacha20Poly1305DerivedSessionKeys(): SshDerivedSessionKeys {
    let clientToServer = SshDirectionKeyMaterial(
        SSH_CIPHER_CHACHA20_POLY1305_OPENSSH,
        "none",
        incrementalBytes(12, start: 19),
        incrementalBytes(32, start: 51),
        []
    )
    let serverToClient = SshDirectionKeyMaterial(
        SSH_CIPHER_CHACHA20_POLY1305_OPENSSH,
        "none",
        incrementalBytes(12, start: 83),
        incrementalBytes(32, start: 115),
        []
    )
    SshDerivedSessionKeys(incrementalBytes(32, start: 147), clientToServer, serverToClient)
}

private func buildX25519KexResults(seedStart: Int64): (SshX25519KexResult, SshX25519KexResult) {
    let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
    let transcript = SshKexExchangeTranscript(
        "SSH-2.0-jinkui-client_state\r\n".toArray(),
        "SSH-2.0-jinkui-server_state\r\n".toArray(),
        sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: seedStart))),
        sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: seedStart + 32)))
    )
    let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
    let (encodedReply, serverResult) = sshServerProcessKexEcdhInitX25519(
        transcript,
        serverPrivate,
        encodedInit,
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtleQ==".toArray(),
        incrementalBytes(64, start: seedStart + 64)
    )
    let clientResult = sshClientProcessKexEcdhReplyX25519(
        transcript,
        clientPrivate,
        encodedInit,
        encodedReply
    )
    (clientResult, serverResult)
}

private func bytesEqual(left: Array<Byte>, right: Array<Byte>): Bool {
    if (left.size != right.size) {
        return false
    }
    var i = 0
    while (i < left.size) {
        if (UInt8(left[i]) != UInt8(right[i])) {
            return false
        }
        i += 1
    }
    true
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
