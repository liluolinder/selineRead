package ignite.api2

import std.collection.ArrayList
import std.fs.{exists, File, OpenMode}
import stdx.crypto.common.{Pem, PemEntry, DerBlob, PrivateKey}
import stdx.net.tls.TlsServerConfig
import stdx.crypto.x509.X509Certificate
import jinguissl.contract.{ContractException, contractValidateHttpServerTlsConfigInput}
import jinguissl_core.crypto.tls.TlsSessionCache

public enum TlsConfigLoadErrorCode <: Equatable<TlsConfigLoadErrorCode> & ToString {
    | BadInput
    | VerifyFailed
    | KeyNotFound
    | CryptoUnavailable
    | ComplianceRejected
    | Unsupported
    | InternalError

    public operator func ==(right: TlsConfigLoadErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsConfigLoadErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case BadInput => 0
            case VerifyFailed => 1
            case KeyNotFound => 2
            case CryptoUnavailable => 3
            case ComplianceRejected => 4
            case Unsupported => 5
            case InternalError => 6
        }
    }

    public func toString(): String {
        match (this) {
            case BadInput => "BAD_INPUT"
            case VerifyFailed => "VERIFY_FAILED"
            case KeyNotFound => "KEY_NOT_FOUND"
            case CryptoUnavailable => "CRYPTO_UNAVAILABLE"
            case ComplianceRejected => "COMPLIANCE_REJECTED"
            case Unsupported => "UNSUPPORTED"
            case InternalError => "INTERNAL_ERROR"
        }
    }
}

public class TlsConfigLoadException <: Exception {
    public let code: TlsConfigLoadErrorCode
    public let sourceCode: String

    public init(code: TlsConfigLoadErrorCode, sourceCode: String, message: String) {
        super(message)
        this.code = code
        this.sourceCode = sourceCode
    }
}

public class TlsStartupFailureSnapshot {
    public let stage: String
    public let tlsErrorCode: String
    public let igniteErrorCode: String
    public let sourceCode: String
    public let hint: String

    public init(
        stage: String,
        tlsErrorCode: String,
        igniteErrorCode: String,
        sourceCode: String,
        hint: String
    ) {
        this.stage = stage
        this.tlsErrorCode = tlsErrorCode
        this.igniteErrorCode = igniteErrorCode
        this.sourceCode = sourceCode
        this.hint = hint
    }
}

public class PreparedHttpServerTlsMaterial {
    public let certPem: String
    public let keyPem: String
    public let normalizedAlpnProtocols: Array<String>

    public init(
        certPem: String,
        keyPem: String,
        normalizedAlpnProtocols: Array<String>
    ) {
        this.certPem = certPem
        this.keyPem = keyPem
        this.normalizedAlpnProtocols = normalizedAlpnProtocols
    }
}

class RawPemPrivateKey <: PrivateKey {
    private let pemLabel: String
    private let derBody: DerBlob

    init(pemLabel: String, derBody: DerBlob) {
        this.pemLabel = pemLabel
        this.derBody = derBody
    }

    public func encodeToDer(): DerBlob {
        derBody
    }

    public func encodeToDer(password!: ?String): DerBlob {
        if (password.isSome()) {
            throw Exception("raw PEM private-key wrapper does not support encrypted re-encode")
        }
        derBody
    }

    public func encodeToPem(): PemEntry {
        PemEntry(pemLabel, derBody)
    }

    public func encodeToPem(password!: ?String): PemEntry {
        if (password.isSome()) {
            throw Exception("raw PEM private-key wrapper does not support encrypted re-encode")
        }
        encodeToPem()
    }

    public override func toString(): String {
        "RawPemPrivateKey(${pemLabel}, ${derBody.size} bytes)"
    }

    public static func decodeDer(encoded: DerBlob): PrivateKey {
        let _ = encoded
        throw Exception("RawPemPrivateKey.decodeDer is unsupported")
    }

    public static func decodeDer(encoded: DerBlob, password!: ?String): PrivateKey {
        let _ = encoded
        let _ = password
        throw Exception("RawPemPrivateKey.decodeDer with encrypted input is unsupported")
    }

    public static func decodeFromPem(text: String): PrivateKey {
        let _ = text
        throw Exception("RawPemPrivateKey.decodeFromPem is unsupported")
    }

    public static func decodeFromPem(text: String, password!: ?String): PrivateKey {
        let _ = text
        let _ = password
        throw Exception("RawPemPrivateKey.decodeFromPem with encrypted input is unsupported")
    }
}

public func tlsToIgniteErrorCode(code: TlsConfigLoadErrorCode): String {
    "TLS_${code.toString()}"
}

public func tlsStartupFailureSnapshot(e: TlsConfigLoadException): TlsStartupFailureSnapshot {
    TlsStartupFailureSnapshot(
        tlsStageFromSourceCode(e.sourceCode),
        e.code.toString(),
        tlsToIgniteErrorCode(e.code),
        e.sourceCode,
        tlsHintForCode(e.code)
    )
}

public func tlsMapContractErrorCode(contractCode: String): TlsConfigLoadErrorCode {
    let normalized = contractCode.trimAscii().toAsciiUpper()
    match (normalized) {
        case "BAD_INPUT" => TlsConfigLoadErrorCode.BadInput
        case "VERIFY_FAILED" => TlsConfigLoadErrorCode.VerifyFailed
        case "KEY_NOT_FOUND" => TlsConfigLoadErrorCode.KeyNotFound
        case "CRYPTO_UNAVAILABLE" => TlsConfigLoadErrorCode.CryptoUnavailable
        case "COMPLIANCE_REJECTED" => TlsConfigLoadErrorCode.ComplianceRejected
        case "UNSUPPORTED" => TlsConfigLoadErrorCode.Unsupported
        case "INTERNAL_ERROR" => TlsConfigLoadErrorCode.InternalError
        case _ => TlsConfigLoadErrorCode.InternalError
    }
}

public func tlsWrapContractException(e: ContractException): TlsConfigLoadException {
    let contractCode = e.code.toString()
    let mappedCode = tlsMapContractErrorCode(contractCode)
    TlsConfigLoadException(
        mappedCode,
        contractCode,
        "jinguiSSL TLS precheck failed [${contractCode}]: ${e.message}"
    )
}

public func precheckHttpServerTlsConfigInput(
    certPem: String,
    keyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true
): Array<String> {
    let precheck = try {
        contractValidateHttpServerTlsConfigInput(
            certPem,
            keyPem,
            alpnProtocols: alpnProtocols,
            requireHttp2Alpn: requireHttp2Alpn
        )
    } catch (e: ContractException) {
        throw tlsWrapContractException(e)
    }
    precheck.normalizedAlpnProtocols
}

public func prepareHttpServerTlsMaterial(
    certPem: String,
    keyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true,
    enablePrecheck!: Bool = true
): PreparedHttpServerTlsMaterial {
    let normalizedAlpn = if (enablePrecheck) {
        precheckHttpServerTlsConfigInput(
            certPem,
            keyPem,
            alpnProtocols: alpnProtocols,
            requireHttp2Alpn: requireHttp2Alpn
        )
    } else {
        normalizeAlpnProtocolsFallback(alpnProtocols)
    }

    PreparedHttpServerTlsMaterial(
        certPem,
        keyPem,
        normalizedAlpn
    )
}

public func loadHttpServerTlsMaterialFromFiles(
    certFile: String,
    keyFile: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true,
    enablePrecheck!: Bool = true
): PreparedHttpServerTlsMaterial {
    let certPem = readTextFileForTls(certFile)
    let keyPem = readTextFileForTls(keyFile)
    prepareHttpServerTlsMaterial(
        certPem,
        keyPem,
        alpnProtocols: alpnProtocols,
        requireHttp2Alpn: requireHttp2Alpn,
        enablePrecheck: enablePrecheck
    )
}

public func buildStdxTlsServerConfigFromPreparedMaterial(
    material: PreparedHttpServerTlsMaterial
): TlsServerConfig {
    try {
        let certChain = X509Certificate.decodeFromPem(material.certPem)
        let certKey = decodePrivateKeyWithoutDescribeOrThrow(material.keyPem)
        var tlsConfig = TlsServerConfig(certChain, certKey)
        tlsConfig.supportedAlpnProtocols = material.normalizedAlpnProtocols
        tlsConfig
    } catch (e: TlsConfigLoadException) {
        throw e
    } catch (e: Exception) {
        throw TlsConfigLoadException(
            TlsConfigLoadErrorCode.InternalError,
            "STDX_TLS_CONFIG_BUILD",
            "stdx TLS config build failed: ${e.message}"
        )
    }
}

/// Load TLS server config from PEM strings, enable HTTP/2 + HTTP/1.1 ALPN.
/// Certificate chain still uses stdx X509 decode, while private key loading keeps the original DER payload
/// behind a lightweight PrivateKey wrapper so listener setup can bypass GeneralPrivateKey.describe().
///
/// - certPem: Certificate PEM content (can contain multiple certificates, decodeFromPem returns Array)
/// - keyPem: Private key PEM content
/// - alpnProtocols: ALPN protocol preference list. when empty, defaults to ["h2", "http/1.1"]
/// - requireHttp2Alpn: when true, precheck requires ALPN list contains h2
/// - return: TlsServerConfig with normalized ALPN list, can be used directly for ServerBuilder.tlsConfig(...)
public func loadTlsServerConfigForHttp2(
    certPem: String,
    keyPem: String,
    alpnProtocols!: Array<String> = ["h2", "http/1.1"],
    requireHttp2Alpn!: Bool = true,
    enablePrecheck!: Bool = true
): TlsServerConfig {
    buildStdxTlsServerConfigFromPreparedMaterial(
        prepareHttpServerTlsMaterial(
            certPem,
            keyPem,
            alpnProtocols: alpnProtocols,
            requireHttp2Alpn: requireHttp2Alpn,
            enablePrecheck: enablePrecheck
        )
    )
}

func decodePrivateKeyWithoutDescribeOrThrow(
    keyPem: String
): PrivateKey {
    var sawPrivateKeyEntry = false

    for (entry in Pem.decode(keyPem)) {
        if (entry.body.isNone()) {
            continue
        }
        let body = entry.body.getOrThrow()
        if (supportsRawPemPrivateKeyLabel(entry.label)) {
            sawPrivateKeyEntry = true
            return RawPemPrivateKey(entry.label, body)
        }
        if (entry.label == PemEntry.LABEL_ENCRYPTED_PRIVATE_KEY) {
            throw TlsConfigLoadException(
                TlsConfigLoadErrorCode.Unsupported,
                "STDX_RAW_KEY_ENCRYPTED_UNSUPPORTED",
                "raw PEM private-key wrapper does not support encrypted PEM without password input"
            )
        }
    }

    if (!sawPrivateKeyEntry) {
        throw TlsConfigLoadException(
            TlsConfigLoadErrorCode.KeyNotFound,
            "STDX_RAW_KEY_NOT_FOUND",
            "No supported private key entry found in PEM."
        )
    }

    throw TlsConfigLoadException(
        TlsConfigLoadErrorCode.InternalError,
        "STDX_RAW_KEY_LOAD_BLOCKED",
        "raw PEM private-key wrapper could not find a supported unencrypted key entry"
    )
}

func supportsRawPemPrivateKeyLabel(label: String): Bool {
    label == PemEntry.LABEL_RSA_PRIVATE_KEY ||
    label == PemEntry.LABEL_EC_PRIVATE_KEY ||
    label == PemEntry.LABEL_SM2_PRIVATE_KEY ||
    label == PemEntry.LABEL_PRIVATE_KEY
}

func normalizeAlpnProtocolsFallback(alpnProtocols: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (raw in alpnProtocols) {
        let item = raw.trimAscii().toAsciiLower()
        if (item.size == 0) {
            continue
        }
        var exists = false
        for (v in out) {
            if (v == item) {
                exists = true
                break
            }
        }
        if (!exists) {
            out.add(item)
        }
    }
    if (out.size == 0) {
        return ["h2", "http/1.1"]
    }
    out.toArray()
}

func readTextFileForTls(path: String): String {
    let resolvedPath = resolveTlsReadPath(path)
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

func resolveTlsReadPath(path: String): String {
    if (exists(path)) {
        return path
    }
    let workspacePath = "../" + path
    if (exists(workspacePath)) {
        return workspacePath
    }
    path
}

func tlsStageFromSourceCode(sourceCode: String): String {
    let normalized = sourceCode.trimAscii().toAsciiUpper()
    if (normalized.startsWith("STDX_")) {
        return "stdx_tls_build"
    }
    "jinguiSSL_precheck"
}

func tlsHintForCode(code: TlsConfigLoadErrorCode): String {
    match (code) {
        case TlsConfigLoadErrorCode.BadInput =>
            "check cert/key pem format and ALPN list (h2,http/1.1)"
        case TlsConfigLoadErrorCode.VerifyFailed =>
            "check certificate chain and private key match"
        case TlsConfigLoadErrorCode.KeyNotFound =>
            "check key source and key id mapping"
        case TlsConfigLoadErrorCode.CryptoUnavailable =>
            "check crypto runtime and dependency availability"
        case TlsConfigLoadErrorCode.ComplianceRejected =>
            "check compliance policy and allowed algorithms"
        case TlsConfigLoadErrorCode.Unsupported =>
            "check unsupported tls option or algorithm setting"
        case TlsConfigLoadErrorCode.InternalError =>
            "check stdx tls build path and runtime exception details"
    }
}

// jinguiSSL contract and TLS-session helpers may expose symbols through public ABI edges.
// Keep explicit type anchors so test linking consistently includes the needed subpackages.
func _useContractExceptionType(value!: ?ContractException = None): Bool {
    if (let Some(_error) <- value) {
        return true
    }
    false
}

func _useTlsSessionCacheType(value!: ?TlsSessionCache = None): Bool {
    if (let Some(_cache) <- value) {
        return true
    }
    false
}
