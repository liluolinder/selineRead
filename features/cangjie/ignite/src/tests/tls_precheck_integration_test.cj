package ignite.tests

import ignite.api2
import std.collection.ArrayList
import std.fs.{exists, File, OpenMode}

let TLS_CERT_A = "_helper/testdata/tls/server-cert-a.pem"
let TLS_KEY_A = "_helper/testdata/tls/server-key-a.pem"
let TLS_KEY_B = "_helper/testdata/tls/server-key-b.pem"

@Test
public class TlsPrecheckIntegrationTestSuite {
    @TestCase
    public func testInvalidPemMapsToBadInputWithPrecheckEnabled(): Unit {
        var thrown = false
        try {
            let _ = api2.loadTlsServerConfigForHttp2(
                "",
                "",
                alpnProtocols: ["h2", "http/1.1"],
                requireHttp2Alpn: true,
                enablePrecheck: true
            )
        } catch (e: api2.TlsConfigLoadException) {
            thrown = true
            @Assert(e.code, api2.TlsConfigLoadErrorCode.VerifyFailed)
            @Assert(api2.tlsToIgniteErrorCode(e.code), "TLS_VERIFY_FAILED")
            let snapshot = api2.tlsStartupFailureSnapshot(e)
            @Assert(snapshot.stage, "jinguiSSL_precheck")
            @Assert(snapshot.tlsErrorCode, "VERIFY_FAILED")
            @Assert(snapshot.igniteErrorCode, "TLS_VERIFY_FAILED")
        }
        @Assert(thrown, true)
    }

    @TestCase
    public func testMismatchedKeyMapsToVerifyFailedWithPrecheckEnabled(): Unit {
        let certPem = readTextFile(TLS_CERT_A)
        let keyPem = readTextFile(TLS_KEY_B)

        var thrown = false
        try {
            let _ = api2.loadTlsServerConfigForHttp2(
                certPem,
                keyPem,
                alpnProtocols: ["h2", "http/1.1"],
                requireHttp2Alpn: true,
                enablePrecheck: true
            )
        } catch (e: api2.TlsConfigLoadException) {
            thrown = true
            @Assert(e.code, api2.TlsConfigLoadErrorCode.VerifyFailed)
            @Assert(api2.tlsToIgniteErrorCode(e.code), "TLS_VERIFY_FAILED")
        }
        @Assert(thrown, true)
    }

    @TestCase
    public func testDisablePrecheckSkipsAlpnRequirementCheck(): Unit {
        var thrown = false
        try {
            let _ = api2.loadTlsServerConfigForHttp2(
                "",
                "",
                alpnProtocols: ["http/1.1"],
                requireHttp2Alpn: true,
                enablePrecheck: false
            )
        } catch (e: api2.TlsConfigLoadException) {
            thrown = true
            @Assert(e.code, api2.TlsConfigLoadErrorCode.InternalError)
            @Assert(e.sourceCode, "STDX_TLS_CONFIG_BUILD")
            @Assert(api2.tlsToIgniteErrorCode(e.code), "TLS_INTERNAL_ERROR")
            let snapshot = api2.tlsStartupFailureSnapshot(e)
            @Assert(snapshot.stage, "stdx_tls_build")
            @Assert(snapshot.tlsErrorCode, "INTERNAL_ERROR")
            @Assert(snapshot.hint, "check stdx tls build path and runtime exception details")
        }
        @Assert(thrown, true)
    }

    @TestCase
    public func testPrecheckValidPemWithHttp2AndHttp11Succeeds(): Unit {
        let certPem = readTextFile(TLS_CERT_A)
        let keyPem = readTextFile(TLS_KEY_A)
        let normalizedAlpn = api2.precheckHttpServerTlsConfigInput(
            certPem,
            keyPem,
            alpnProtocols: ["h2", "http/1.1"],
            requireHttp2Alpn: true
        )
        @Assert(contains(normalizedAlpn, "h2"), true)
        @Assert(contains(normalizedAlpn, "http/1.1"), true)
    }

    @TestCase
    public func testPrepareHttpServerTlsMaterialPreservesPemAndNormalizedAlpn(): Unit {
        let certPem = readTextFile(TLS_CERT_A)
        let keyPem = readTextFile(TLS_KEY_A)

        let material = api2.prepareHttpServerTlsMaterial(
            certPem,
            keyPem,
            alpnProtocols: ["h2", "http/1.1"],
            requireHttp2Alpn: true,
            enablePrecheck: true
        )

        @Assert(material.certPem, certPem)
        @Assert(material.keyPem, keyPem)
        @Assert(contains(material.normalizedAlpnProtocols, "h2"), true)
        @Assert(contains(material.normalizedAlpnProtocols, "http/1.1"), true)
    }

    @TestCase
    public func testPreparedHttpServerTlsMaterialBuildsStdxTlsConfigForValidPem(): Unit {
        let material = api2.loadHttpServerTlsMaterialFromFiles(
            resolveFixturePath(TLS_CERT_A),
            resolveFixturePath(TLS_KEY_A),
            alpnProtocols: ["h2", "http/1.1"],
            requireHttp2Alpn: true,
            enablePrecheck: true
        )

        let tlsConfig = api2.buildStdxTlsServerConfigFromPreparedMaterial(
            material
        )

        @Assert(contains(tlsConfig.supportedAlpnProtocols, "h2"), true)
        @Assert(contains(tlsConfig.supportedAlpnProtocols, "http/1.1"), true)
        @Assert(tlsConfig.supportedAlpnProtocols.size >= 2, true)
    }

    func contains(items: Array<String>, target: String): Bool {
        for (item in items) {
            if (item == target) {
                return true
            }
        }
        false
    }
}

func readTextFile(path: String): String {
    let resolvedPath = resolveFixturePath(path)
    let file = File(resolvedPath, OpenMode.Read)
    let out = ArrayList<UInt8>()
    let tmp = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = file.read(tmp)
        if (n <= 0) {
            break
        }
        for (i in 0..n) {
            out.add(tmp[i])
        }
    }
    file.close()
    String.fromUtf8(out.toArray())
}

func resolveFixturePath(path: String): String {
    if (exists(path)) {
        return path
    }
    let workspacePath = "../" + path
    if (exists(workspacePath)) {
        return workspacePath
    }
    path
}
