package jinguissl.tests

import std.collection.ArrayList
import std.fs.File
import jinguissl_core.crypto.ssh.{sshBuildDefaultKexInit, sshBuildKexEcdhInitX25519, sshEncodeKexInit, sshEncodeNewKeys}
import jinguissl.contract.*

private let LIVE_SOURCE_ROOT: String = ""

@Test
public class ContractSshStartupBundleTestSuite {
    @TestCase
    public func testContractSshLibraryStartupBundles(): Unit {
        let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let transcript = ContractSshKexExchangeTranscript(
            "SSH-2.0-contract-startup-client\r\n".toArray(),
            "SSH-2.0-contract-startup-server\r\n".toArray(),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 1820))),
            sshEncodeKexInit(sshBuildDefaultKexInit(cookie: incrementalBytes(16, start: 1860)))
        )
        let (encodedInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
        let negotiated = ContractSshNegotiatedAlgorithms(
            "curve25519-sha256",
            "rsa-sha2-256",
            "aes128-ctr",
            "aes128-ctr",
            "hmac-sha2-256",
            "hmac-sha2-256",
            compressionAlgorithmClientToServer: "none",
            compressionAlgorithmServerToClient: "none"
        )
        let serverBundle = contractPrepareSshServerLibraryStartupX25519RsaPkcs8Request(
            ContractSshServerLibraryStartupX25519RsaPkcs8Request(
                transcript,
                serverPrivate,
                encodedInit,
                readText("testdata/x509/rsa_2048_pkcs8.pem"),
                negotiated,
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                profile: ContractHttpSshStartupProfile.SshServerLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(serverBundle.template.profile.toString(), "SSH_SERVER_LIBRARY")
        @Assert(serverBundle.readiness.sshReady, true)
        @Assert(serverBundle.handshake.hostSignatureAlgorithm, "rsa-sha2-256")
        @Assert(serverBundle.runtime.sessionId(), serverBundle.handshake.sessionId)

        let ecdsaBundle = contractPrepareSshServerLibraryStartupX25519EcdsaPkcs8Request(
            ContractSshServerLibraryStartupX25519EcdsaPkcs8Request(
                transcript,
                serverPrivate,
                encodedInit,
                readText("testdata/x509/policy_leaf_key_pkcs8.pem"),
                ContractSshNegotiatedAlgorithms(
                    "curve25519-sha256",
                    "ecdsa-sha2-nistp256",
                    "aes128-ctr",
                    "aes128-ctr",
                    "hmac-sha2-256",
                    "hmac-sha2-256",
                    compressionAlgorithmClientToServer: "none",
                    compressionAlgorithmServerToClient: "none"
                ),
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                profile: ContractHttpSshStartupProfile.SshServerLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(ecdsaBundle.handshake.hostKeyAlgorithm, "ecdsa-sha2-nistp256")
        @Assert(ecdsaBundle.runtime.sessionId(), ecdsaBundle.handshake.sessionId)

        let ed25519Bundle = contractPrepareSshServerLibraryStartupX25519Ed25519SeedRequest(
            ContractSshServerLibraryStartupX25519Ed25519SeedRequest(
                transcript,
                serverPrivate,
                encodedInit,
                hexToBytes("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"),
                ContractSshNegotiatedAlgorithms(
                    "curve25519-sha256",
                    "ssh-ed25519",
                    "aes128-ctr",
                    "aes128-ctr",
                    "hmac-sha2-256",
                    "hmac-sha2-256",
                    compressionAlgorithmClientToServer: "none",
                    compressionAlgorithmServerToClient: "none"
                ),
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                profile: ContractHttpSshStartupProfile.SshServerLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(ed25519Bundle.handshake.hostKeyAlgorithm, "ssh-ed25519")
        @Assert(ed25519Bundle.runtime.sessionId(), ed25519Bundle.handshake.sessionId)

        let clientBundle = contractPrepareSshClientLibraryStartupX25519Request(
            ContractSshClientLibraryStartupX25519Request(
                ContractSshClientInitialHandshakeX25519Request(
                    transcript,
                    clientPrivate,
                    encodedInit,
                    serverBundle.handshake.encodedReply,
                    negotiated,
                    sshEncodeNewKeys(),
                    sshEncodeNewKeys(),
                    policy: ContractSshHostVerificationPolicy(
                        negotiatedHostKeyAlgorithm: "rsa-sha2-256",
                        expectedHostKeySha256: serverBundle.handshake.hostKeySha256,
                        requireKnownHost: true,
                        requireHostSignature: true,
                        requireVerifiedHost: true
                    )
                ),
                profile: ContractHttpSshStartupProfile.SshClientLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(clientBundle.template.profile.toString(), "SSH_CLIENT_LIBRARY")
        @Assert(clientBundle.readiness.sshReady, true)
        @Assert(clientBundle.handshake.requireHostVerification().hostSignatureVerified, true)
        @Assert(clientBundle.runtime.sessionId(), clientBundle.handshake.sessionId)

        let productionServer = contractTryPrepareSshServerLibraryStartupX25519RsaPkcs8Request(
            ContractSshServerLibraryStartupX25519RsaPkcs8Request(
                transcript,
                serverPrivate,
                encodedInit,
                readText("testdata/x509/rsa_2048_pkcs8.pem"),
                negotiated,
                sshEncodeNewKeys(),
                sshEncodeNewKeys(),
                profile: ContractHttpSshStartupProfile.ProductionAccelerated,
                aesBackendHint: "shim"
            )
        )
        @Assert(productionServer.ok, false)
        match (productionServer.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("SSH server startup production outcome should carry contract code")
        }

        let invalidClientProfile = contractTryPrepareSshClientLibraryStartupX25519Request(
            ContractSshClientLibraryStartupX25519Request(
                ContractSshClientInitialHandshakeX25519Request(
                    transcript,
                    clientPrivate,
                    encodedInit,
                    serverBundle.handshake.encodedReply,
                    negotiated,
                    sshEncodeNewKeys(),
                    sshEncodeNewKeys()
                ),
                profile: ContractHttpSshStartupProfile.HttpClientLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(invalidClientProfile.ok, false)
        match (invalidClientProfile.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("SSH client startup invalid profile outcome should carry contract code")
        }
    }
}

private func readText(path: String): String {
    String.fromUtf8(File.readFrom("${LIVE_SOURCE_ROOT}${path}"))
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
    let normalized = hex.trimAscii()
    if ((normalized.size % 2) != 0) {
        throw Exception("hex string length must be even")
    }
    let bytes = normalized.toArray()
    let out = ArrayList<Byte>()
    var i = 0
    while (i < normalized.size) {
        out.add(UInt8(parseHexByte(UInt8(bytes[i]), UInt8(bytes[i + 1]))))
        i += 2
    }
    out.toArray()
}

private func parseHexByte(high: UInt8, low: UInt8): Int64 {
    (parseHexNibble(high) << 4) | parseHexNibble(low)
}

private func parseHexNibble(ch: UInt8): Int64 {
    if (ch >= b'0' && ch <= b'9') {
        return Int64(ch) - Int64(b'0')
    }
    if (ch >= b'a' && ch <= b'f') {
        return 10 + Int64(ch) - Int64(b'a')
    }
    if (ch >= b'A' && ch <= b'F') {
        return 10 + Int64(ch) - Int64(b'A')
    }
    throw Exception("invalid hex nibble")
}
