package ignite.security

import ignite.api2
import ignite.binary.{base64UrlEncode, base64UrlDecode, cloneBytes}
import std.collection.{HashMap, ArrayList}
import std.sync.Mutex

var _decryptFailureCount: Int64 = 0
var _signatureFailureCount: Int64 = 0
var _certRejectCount: Int64 = 0
let _metricsMutex = Mutex()

public enum SecurityProviderKind <: Equatable<SecurityProviderKind> & ToString {
    | jinguiSSL
    | StdxFallback

    public operator func ==(right: SecurityProviderKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SecurityProviderKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case jinguiSSL => 0
            case StdxFallback => 1
        }
    }

    public func toString(): String {
        match (this) {
            case jinguiSSL => "jinguiSSL"
            case StdxFallback => "stdx-fallback"
        }
    }
}

public enum SecurityErrorCode <: Equatable<SecurityErrorCode> & ToString {
    | BadEnvelope
    | KeyNotFound
    | DecryptFailed
    | CryptoUnavailable
    | VerifyFailed

    public operator func ==(right: SecurityErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: SecurityErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case BadEnvelope => 0
            case KeyNotFound => 1
            case DecryptFailed => 2
            case CryptoUnavailable => 3
            case VerifyFailed => 4
        }
    }

    public func toString(): String {
        match (this) {
            case BadEnvelope => "BAD_ENVELOPE"
            case KeyNotFound => "KEY_NOT_FOUND"
            case DecryptFailed => "DECRYPT_FAILED"
            case CryptoUnavailable => "CRYPTO_UNAVAILABLE"
            case VerifyFailed => "VERIFY_FAILED"
        }
    }
}

public class SecurityException <: Exception {
    public let code: SecurityErrorCode

    public init(code: SecurityErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public class SecurityMetricsSnapshot {
    public let decryptFailures: Int64
    public let signatureFailures: Int64
    public let certRejects: Int64

    public init(
        decryptFailures: Int64,
        signatureFailures: Int64,
        certRejects: Int64
    ) {
        this.decryptFailures = decryptFailures
        this.signatureFailures = signatureFailures
        this.certRejects = certRejects
    }
}

public func securityMetricsSnapshot(): SecurityMetricsSnapshot {
    var decryptFailures: Int64 = 0
    var signatureFailures: Int64 = 0
    var certRejects: Int64 = 0
    synchronized(_metricsMutex) {
        decryptFailures = _decryptFailureCount
        signatureFailures = _signatureFailureCount
        certRejects = _certRejectCount
    }
    SecurityMetricsSnapshot(decryptFailures, signatureFailures, certRejects)
}

public func resetSecurityMetrics(): Unit {
    synchronized(_metricsMutex) {
        _decryptFailureCount = 0
        _signatureFailureCount = 0
        _certRejectCount = 0
    }
}

public func recordDecryptFailure(): Unit {
    synchronized(_metricsMutex) {
        _decryptFailureCount += 1
    }
}

public func recordSignatureFailure(): Unit {
    synchronized(_metricsMutex) {
        _signatureFailureCount += 1
    }
}

public func recordCertReject(): Unit {
    synchronized(_metricsMutex) {
        _certRejectCount += 1
    }
}

public class SecurityConfig {
    public var providerKind: SecurityProviderKind
    public var activeKid: String
    public var keyRing: HashMap<String, Array<UInt8>>
    public var aeadAlgorithm: String

    public init(
        providerKind!: SecurityProviderKind = jinguiSSL,
        activeKid!: String = "k1",
        keyRing!: HashMap<String, Array<UInt8>> = HashMap<String, Array<UInt8>>(),
        aeadAlgorithm!: String = "AES-256-GCM"
    ) {
        this.providerKind = providerKind
        this.activeKid = activeKid
        this.keyRing = HashMap<String, Array<UInt8>>()
        this.aeadAlgorithm = normalizeAlg(aeadAlgorithm)
        for ((kid, key) in keyRing) {
            this.keyRing.add(kid, cloneBytes(key))
        }
    }

    public func addKey(kid: String, key: Array<UInt8>): SecurityConfig {
        keyRing.add(kid, cloneBytes(key))
        this
    }

    public func activeKey(): Array<UInt8> {
        match (keyRing.get(activeKid)) {
            case Some(key) => cloneBytes(key)
            case None =>
                throw SecurityException(KeyNotFound, "active key id not found: ${activeKid}")
        }
    }

    public func toClientConfig(): api2.ClientCryptoConfig {
        api2.ClientCryptoConfig(
            providerKind: mapProviderKind(providerKind),
            activeKid: activeKid,
            keyRing: keyRing,
            aeadAlgorithm: aeadAlgorithm
        )
    }
}

public class X509VerifyContext {
    public let source: String
    public let targetUrl: String
    public let scheme: String
    public let host: String
    public let port: Int64
    public let expectedServerName: String
    public let pinnedSha256: Array<String>

    public init(
        source: String,
        targetUrl: String,
        scheme: String,
        host: String,
        port: Int64,
        expectedServerName: String,
        pinnedSha256: Array<String>
    ) {
        this.source = source
        this.targetUrl = targetUrl
        this.scheme = scheme
        this.host = host
        this.port = port
        this.expectedServerName = expectedServerName
        this.pinnedSha256 = clonePinStrings(pinnedSha256)
    }
}

public type X509VerifyHook = (X509VerifyContext) -> Bool

public class X509VerifyOption {
    public var enabled: Bool
    public var requireHttps: Bool
    public var expectedServerName: String
    public var pinnedSha256: Array<String>
    public var hook: ?X509VerifyHook

    public init(
        enabled!: Bool = false,
        requireHttps!: Bool = true,
        expectedServerName!: String = "",
        pinnedSha256!: Array<String> = [],
        hook!: ?X509VerifyHook = None
    ) {
        this.enabled = enabled
        this.requireHttps = requireHttps
        this.expectedServerName = expectedServerName.trimAscii().toAsciiLower()
        this.pinnedSha256 = normalizePinStrings(pinnedSha256)
        this.hook = hook
    }

    public func copy(): X509VerifyOption {
        X509VerifyOption(
            enabled: enabled,
            requireHttps: requireHttps,
            expectedServerName: expectedServerName,
            pinnedSha256: clonePinStrings(pinnedSha256),
            hook: hook
        )
    }
}

func raiseVerifyFailed(message: String): Unit {
    recordCertReject()
    throw SecurityException(VerifyFailed, message)
}

public func verifyX509Target(
    option: X509VerifyOption,
    targetUrl: String,
    source!: String = "ignite/client"
): Unit {
    if (!option.enabled) {
        return
    }

    let info = parseTargetUrl(targetUrl)
    if (option.requireHttps && info.scheme != "https") {
        raiseVerifyFailed("x509 verification requires https target: ${targetUrl}")
    }

    let expectedServerName = option.expectedServerName.trimAscii().toAsciiLower()
    if (expectedServerName.size > 0 && info.host != expectedServerName) {
        raiseVerifyFailed("x509 server name mismatch: expected=${expectedServerName}, got=${info.host}")
    }

    if (option.pinnedSha256.size > 0) {
        match (option.hook) {
            case Some(_) => ()
            case None =>
                raiseVerifyFailed("x509 pinning requires a verify hook to compare presented certificate pins")
        }
    }

    if (let Some(verifyHook) <- option.hook) {
        let ctx = X509VerifyContext(
            source,
            targetUrl,
            info.scheme,
            info.host,
            info.port,
            expectedServerName,
            option.pinnedSha256
        )
        let accepted = try {
            verifyHook(ctx)
        } catch (e: SecurityException) {
            throw e
        } catch (_: Exception) {
            false
        }
        if (!accepted) {
            raiseVerifyFailed("x509 verify hook rejected target: ${targetUrl}")
        }
    }
}

public func randomHex(length: Int64): String {
    try {
        api2.clientCryptoRandomHex(length)
    } catch (e: api2.ClientCryptoException) {
        throw mapClientError(e)
    }
}

public func encryptEnvelopeV1(
    config: SecurityConfig,
    plaintext: Array<UInt8>,
    aad!: Array<UInt8> = []
): String {
    try {
        api2.encryptEnvelopeV1(config.toClientConfig(), plaintext, aad: aad)
    } catch (e: api2.ClientCryptoException) {
        throw mapClientError(e)
    }
}

public func decryptEnvelopeV1(
    config: SecurityConfig,
    envelopeJson: String,
    aad!: Array<UInt8> = []
): Array<UInt8> {
    try {
        api2.decryptEnvelopeV1(config.toClientConfig(), envelopeJson, aad: aad)
    } catch (e: api2.ClientCryptoException) {
        throw mapClientError(e)
    }
}

public func encryptEnvelopeV1Text(
    config: SecurityConfig,
    text: String,
    aadText!: String = ""
): String {
    try {
        api2.encryptJsonToEnvelopeV1(config.toClientConfig(), text, aadText: aadText)
    } catch (e: api2.ClientCryptoException) {
        throw mapClientError(e)
    }
}

public func decryptEnvelopeV1ToText(
    config: SecurityConfig,
    envelopeJson: String,
    aadText!: String = ""
): String {
    try {
        api2.decryptEnvelopeV1ToJson(config.toClientConfig(), envelopeJson, aadText: aadText)
    } catch (e: api2.ClientCryptoException) {
        throw mapClientError(e)
    }
}

public func sealCookieValueV1(
    config: SecurityConfig,
    value: String,
    cookieName!: String = ""
): String {
    let envelopeJson = encryptEnvelopeV1(
        config,
        value.toArray(),
        aad: cookieName.toArray()
    )
    "v1." + base64UrlEncode(envelopeJson.toArray())
}

public func openCookieValueV1(
    config: SecurityConfig,
    encodedValue: String,
    cookieName!: String = ""
): String {
    if (!isCookieEnvelopeV1(encodedValue)) {
        throw SecurityException(BadEnvelope, "cookie value is not v1 envelope")
    }
    let payload = encodedValue[3..encodedValue.size]
    let envelopeJson = try {
        String.fromUtf8(base64UrlDecode(payload))
    } catch (_: Exception) {
        throw SecurityException(BadEnvelope, "invalid cookie envelope encoding")
    }
    let plain = decryptEnvelopeV1(
        config,
        envelopeJson,
        aad: cookieName.toArray()
    )
    String.fromUtf8(plain)
}

public func isCookieEnvelopeV1(value: String): Bool {
    startsWith(value, "v1.")
}

public func deriveKey32FromString(raw: String): Array<UInt8> {
    let bytes = raw.toArray()
    let out = Array<UInt8>(32, repeat: 0)
    if (bytes.size == 0) {
        return out
    }
    var i = 0
    while (i < out.size) {
        out[i] = bytes[i % bytes.size]
        i += 1
    }
    out
}

public func bytesToHex(input: Array<UInt8>): String {
    let chars = "0123456789abcdef".toRuneArray()
    var out = ""
    for (b in input) {
        let n = Int64(b)
        out += chars[(n >> 4) & 0x0F].toString()
        out += chars[n & 0x0F].toString()
    }
    out
}

public func hexToBytes(input: String): Array<UInt8> {
    let text = input.trimAscii().toAsciiLower()
    let runes = text.toRuneArray()
    if (runes.size == 0 || (runes.size % 2) != 0) {
        throw SecurityException(BadEnvelope, "hex text length must be even and non-empty")
    }
    let out = Array<UInt8>(runes.size / 2, repeat: 0)
    var i = 0
    while (i < runes.size) {
        let hi = hexNibble(runes[i])
        let lo = hexNibble(runes[i + 1])
        if (hi < 0 || lo < 0) {
            throw SecurityException(BadEnvelope, "invalid hex text")
        }
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

func mapProviderKind(kind: SecurityProviderKind): api2.ClientCryptoProviderKind {
    match (kind) {
        case jinguiSSL => api2.ClientCryptoProviderKind.jinguiSSL
        case StdxFallback => api2.ClientCryptoProviderKind.StdxFallback
    }
}

func mapClientError(e: api2.ClientCryptoException): SecurityException {
    let code = match (e.code) {
        case api2.ClientCryptoErrorCode.BadEnvelope => BadEnvelope
        case api2.ClientCryptoErrorCode.KeyNotFound => KeyNotFound
        case api2.ClientCryptoErrorCode.DecryptFailed => DecryptFailed
        case api2.ClientCryptoErrorCode.CryptoUnavailable => CryptoUnavailable
    }
    SecurityException(code, e.message)
}

func normalizeAlg(raw: String): String {
    raw.trimAscii().toAsciiUpper()
}

class ParsedTargetUrlInfo {
    let scheme: String
    let host: String
    let port: Int64

    init(scheme: String, host: String, port: Int64) {
        this.scheme = scheme
        this.host = host
        this.port = port
    }
}

func parseTargetUrl(rawTarget: String): ParsedTargetUrlInfo {
    let raw = rawTarget.trimAscii()
    if (raw.size == 0) {
        raiseVerifyFailed("x509 target url must not be empty")
    }
    let lower = raw.toAsciiLower()
    var scheme = ""
    if (startsWith(lower, "https://")) {
        scheme = "https"
    } else if (startsWith(lower, "http://")) {
        scheme = "http"
    } else {
        raiseVerifyFailed("x509 target url must start with http:// or https://")
    }

    let prefix = if (scheme == "https") { 8 } else { 7 }
    let tail = sliceFrom(raw, prefix)
    if (tail.size == 0) {
        raiseVerifyFailed("x509 target url missing host")
    }

    let slash = indexOfRune(tail, r'/')
    let hostPortRaw = if (slash < 0) { tail } else { sliceRange(tail, 0, slash) }
    if (hostPortRaw.size == 0) {
        raiseVerifyFailed("x509 target url missing host")
    }

    parseHostPort(hostPortRaw, scheme)
}

func parseHostPort(hostPortRaw: String, scheme: String): ParsedTargetUrlInfo {
    let defaultPort: Int64 = if (scheme == "https") { 443 } else { 80 }
    let trimmed = hostPortRaw.trimAscii()
    if (trimmed.size == 0) {
        raiseVerifyFailed("x509 target host is empty")
    }

    if (trimmed.toRuneArray()[0] == r'[') {
        let close = indexOfRune(trimmed, r']')
        if (close <= 1) {
            raiseVerifyFailed("x509 ipv6 host is invalid")
        }
        let host = sliceRange(trimmed, 1, close).toAsciiLower()
        var port = defaultPort
        if (close + 1 < trimmed.size) {
            let remainder = sliceFrom(trimmed, close + 1)
            if (startsWith(remainder, ":")) {
                let portText = sliceFrom(remainder, 1)
                port = parsePortOrThrow(portText)
            }
        }
        return ParsedTargetUrlInfo(scheme, host, port)
    }

    let colon = lastIndexOfRune(trimmed, r':')
    if (colon > 0) {
        let host = sliceRange(trimmed, 0, colon).toAsciiLower()
        let portText = sliceFrom(trimmed, colon + 1)
        if (host.size == 0) {
            raiseVerifyFailed("x509 target host is empty")
        }
        return ParsedTargetUrlInfo(scheme, host, parsePortOrThrow(portText))
    }

    ParsedTargetUrlInfo(scheme, trimmed.toAsciiLower(), defaultPort)
}

func parsePortOrThrow(portTextRaw: String): Int64 {
    let text = portTextRaw.trimAscii()
    if (text.size == 0) {
        raiseVerifyFailed("x509 target port is empty")
    }
    let runes = text.toRuneArray()
    var port: Int64 = 0
    for (ch in runes) {
        if (ch < r'0' || ch > r'9') {
            raiseVerifyFailed("x509 target port is invalid")
        }
        port = port * 10 + Int64(UInt32(ch) - UInt32(r'0'))
    }
    if (port <= 0 || port > 65535) {
        raiseVerifyFailed("x509 target port out of range")
    }
    port
}

func normalizePinStrings(rawPins: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (raw in rawPins) {
        let pin = raw.trimAscii().toAsciiLower()
        if (pin.size > 0) {
            out.add(pin)
        }
    }
    out.toArray()
}

func clonePinStrings(input: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (item in input) {
        out.add(item)
    }
    out.toArray()
}

func sliceFrom(s: String, start: Int64): String {
    let runes = s.toRuneArray()
    if (start >= runes.size) {
        return ""
    }
    var out = ""
    var i = start
    while (i < runes.size) {
        out += runes[i].toString()
        i += 1
    }
    out
}

func sliceRange(s: String, start: Int64, endExclusive: Int64): String {
    let runes = s.toRuneArray()
    if (start >= runes.size || endExclusive <= start) {
        return ""
    }
    let end = if (endExclusive > runes.size) { runes.size } else { endExclusive }
    var out = ""
    var i = start
    while (i < end) {
        out += runes[i].toString()
        i += 1
    }
    out
}

func indexOfRune(s: String, needle: Rune): Int64 {
    let runes = s.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == needle) {
            return i
        }
        i += 1
    }
    -1
}

func lastIndexOfRune(s: String, needle: Rune): Int64 {
    let runes = s.toRuneArray()
    var i: Int64 = runes.size - 1
    while (i >= 0) {
        if (runes[i] == needle) {
            return i
        }
        i -= 1
    }
    -1
}

func startsWith(s: String, prefix: String): Bool {
    if (s.size < prefix.size) {
        return false
    }
    let sRunes = s.toRuneArray()
    let pRunes = prefix.toRuneArray()
    var i = 0
    while (i < pRunes.size) {
        if (sRunes[i] != pRunes[i]) {
            return false
        }
        i += 1
    }
    true
}

func hexNibble(ch: Rune): Int64 {
    match (ch) {
        case r'0' => 0
        case r'1' => 1
        case r'2' => 2
        case r'3' => 3
        case r'4' => 4
        case r'5' => 5
        case r'6' => 6
        case r'7' => 7
        case r'8' => 8
        case r'9' => 9
        case r'a' => 10
        case r'b' => 11
        case r'c' => 12
        case r'd' => 13
        case r'e' => 14
        case r'f' => 15
        case _ => -1
    }
}
