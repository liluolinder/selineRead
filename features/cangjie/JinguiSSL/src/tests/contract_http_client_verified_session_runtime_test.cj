package jinguissl.tests

import std.fs.File
import jinguissl.live.*

private let LIVE_SOURCE_ROOT: String = ""
private let TEST_HOST_WWW: String = "www." + "example.com"

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

@Test
public class ContractHttpClientVerifiedSessionRuntimeTestSuite {
    @TestCase
    public func testContractHttpClientVerifiedSessionRuntimeReadyAndClosed(): Unit {
        let serverName = TEST_HOST_WWW
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let rootPem = readText("testdata/x509/policy_root.pem")
        let certChainPem = "${leafPem}\n${intermediatePem}"
        let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")
        let policy = ContractTlsHttpNegotiationPolicy(
            requireServerName: true,
            allowedServerNames: [serverName],
            alpnPreference: ["h2", "http/1.1"]
        )

        let clientHello = contractTls13BuildHttpClientHelloX25519(
            serverName,
            alpnProtocols: ["h2", "http/1.1"],
            clientPrivateKey: Some(incrementalBytes(32, start: 48))
        )
        let serverFlight = contractTls13BuildHttpServerFlightX25519(
            clientHello.encodedClientHello,
            incrementalBytes(32, start: 80),
            certChainPem,
            leafKeyPem,
            policy: policy
        )
        let verified = contractTls13VerifyHttpServerFlightX25519WithSession(
            clientHello,
            serverFlight,
            rootPem,
            intermediatesPemBundle: intermediatePem,
            hostname: serverName,
            policy: policy
        )
        let runtime = contractTls13OpenHttpClientVerifiedSessionRuntime(verified)

        @Assert(runtime.status.toString(), "READY")
        @Assert(runtime.secureSessionReady, true)
        @Assert(runtime.result.selectedAlpn, "h2")
        @Assert(runtime.result.requestedServerName, serverName)
        @Assert(runtime.result.acknowledgedServerName, true)
        @Assert(runtime.result.chainLength, 3)
        @Assert(runtime.channelSet.clientChannel.version.toString(), "TLS1.3")
        @Assert(runtime.channelSet.serverChannel.version.toString(), "TLS1.3")
        @Assert(runtime.channelSet.clientChannel.algorithm.toString(), "AES-256-GCM")

        let closed = contractTls13CloseHttpClientVerifiedSessionRuntime(runtime, reason: "client-close")
        @Assert(closed.status.toString(), "CLOSED")
        @Assert(closed.secureSessionReady, false)
        @Assert(closed.closeReason, "client-close")
        @Assert(closed.result.selectedAlpn, "h2")
        @Assert(closed.result.requestedServerName, serverName)
        @Assert(closed.channelSet.clientChannel.version.toString(), "TLS1.3")
    }
}
