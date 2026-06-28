import ignite.api2
import std.env.getVariable
import std.fs.{exists, File, OpenMode}
import std.collection.ArrayList
import stdx.crypto.x509.X509Certificate
import stdx.crypto.keys.GeneralPrivateKey

let H2_WIRE_CERT_FALLBACK = "../_helper/testdata/tls/server-cert-a.pem"
let H2_WIRE_KEY_FALLBACK = "../_helper/testdata/tls/server-key-a.pem"
let H2_GUARD_DEFAULT_STAGE = "full"
let H2_GUARD_STAGE_MAINLINE_BUILD = "mainline_build"
let H2_GUARD_STAGE_LEGACY_KEY_DECODE = "legacy_key_decode"

main() {
    let certFile = resolveTlsPath("IGNITE_SAMPLE_TLS_CERT", H2_WIRE_CERT_FALLBACK)
    let keyFile = resolveTlsPath("IGNITE_SAMPLE_TLS_KEY", H2_WIRE_KEY_FALLBACK)
    if (certFile.size == 0 || keyFile.size == 0) {
        printTlsHint()
        return
    }

    let certPem = readTextFile(certFile)
    let keyPem = readTextFile(keyFile)
    let stage = resolveGuardStage()
    println("[sample/h2wire] tls guard stage=${stage}")
    runGuardStage(stage, certPem, keyPem)
}

func resolveGuardStage(): String {
    if (let Some(raw) <- getVariable("IGNITE_H2_TLS_GUARD_STAGE")) {
        let normalized = raw.trimAscii().toAsciiLower()
        if (
            normalized == "precheck" ||
            normalized == "cert_decode" ||
            normalized == H2_GUARD_STAGE_LEGACY_KEY_DECODE ||
            normalized == "key_decode" ||
            normalized == H2_GUARD_STAGE_MAINLINE_BUILD ||
            normalized == "stdx_build" ||
            normalized == "full"
        ) {
            return normalized
        }
    }
    H2_GUARD_DEFAULT_STAGE
}

func runGuardStage(stage: String, certPem: String, keyPem: String): Unit {
    match (stage) {
        case "precheck" => runPrecheck(certPem, keyPem)
        case "cert_decode" => runCertDecode(certPem)
        case "legacy_key_decode" => runLegacyKeyDecode(keyPem)
        case "key_decode" => runLegacyKeyDecode(keyPem)
        case "mainline_build" => runMainlineBuild(certPem, keyPem)
        case "stdx_build" => runMainlineBuild(certPem, keyPem)
        case "full" =>
            runPrecheck(certPem, keyPem)
            runCertDecode(certPem)
            runMainlineBuild(certPem, keyPem)
        case _ => throw Exception("unsupported guard stage=${stage}")
    }
}

func runPrecheck(certPem: String, keyPem: String): Unit {
    let normalizedAlpn = api2.precheckHttpServerTlsConfigInput(
        certPem,
        keyPem,
        alpnProtocols: ["h2", "http/1.1"],
        requireHttp2Alpn: true
    )
    println("[sample/h2wire] tls guard precheck ok: " + joinText(normalizedAlpn, ","))
}

func runCertDecode(certPem: String): Unit {
    let certChain = X509Certificate.decodeFromPem(certPem)
    println("[sample/h2wire] tls guard cert decode ok: chain=${certChain.size}")
}

func runLegacyKeyDecode(keyPem: String): Unit {
    let _ = GeneralPrivateKey.decodeFromPem(keyPem)
    println("[sample/h2wire] tls guard legacy key decode ok")
}

func runMainlineBuild(certPem: String, keyPem: String): Unit {
    let tlsConfig = api2.loadTlsServerConfigForHttp2(
        certPem,
        keyPem,
        alpnProtocols: ["h2", "http/1.1"],
        requireHttp2Alpn: true,
        enablePrecheck: false
    )
    println("[sample/h2wire] tls guard mainline build ok: " + joinText(tlsConfig.supportedAlpnProtocols, ","))
}

func resolveTlsPath(envName: String, fallback: String): String {
    if (let Some(path) <- getVariable(envName)) {
        let trimmed = path.trimAscii()
        if (trimmed.size > 0 && exists(trimmed)) {
            return trimmed
        }
    }
    if (exists(fallback)) {
        return fallback
    }
    ""
}

func printTlsHint(): Unit {
    println("[sample/h2wire] missing TLS certificate or key")
    println("[sample/h2wire] set IGNITE_SAMPLE_TLS_CERT and IGNITE_SAMPLE_TLS_KEY")
    println("[sample/h2wire] local workspace fallback is ${H2_WIRE_CERT_FALLBACK} / ${H2_WIRE_KEY_FALLBACK}")
}

func readTextFile(path: String): String {
    let file = File(path, OpenMode.Read)
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

func joinText(values: Array<String>, separator: String): String {
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += separator
        }
        out += value
        first = false
    }
    out
}
