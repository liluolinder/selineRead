package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.compliance.{FipsProfile}
import jinguissl_core.crypto.ecc.{EcPrivateKey, EcPublicKey}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaPrivateKey}
import jinguissl_core.crypto.x509.{X509VerificationPolicy, X509VerificationResult}

public let TLS_HTTP_ALPN_H2: String = "h2"
public let TLS_HTTP_ALPN_HTTP11: String = "http/1.1"

private let TLS_HTTP_VERSION_TLS13: Int64 = 0x0304
private let TLS_HTTP_GROUP_SECP256R1: Int64 = 0x0017
private let TLS_HTTP_GROUP_X25519: Int64 = 0x001d

public class TlsHttpNegotiationPolicy {
    public let requireServerName: Bool
    public let allowedServerNames: Array<String>
    public let alpnPreference: Array<String>

    public init(
        requireServerName!: Bool = true,
        allowedServerNames!: Array<String> = [],
        alpnPreference!: Array<String> = []
    ) {
        let normalizedServerNames = tlsHttpNormalizeServerNames(allowedServerNames)
        var normalizedAlpn = tlsHttpNormalizeAlpn(alpnPreference)
        if (normalizedAlpn.size == 0) {
            normalizedAlpn = tlsHttpDefaultAlpnPreference()
        }

        this.requireServerName = requireServerName
        this.allowedServerNames = normalizedServerNames
        this.alpnPreference = normalizedAlpn
    }
}

public func tlsHttpDefaultAlpnPreference(): Array<String> {
    [TLS_HTTP_ALPN_H2, TLS_HTTP_ALPN_HTTP11]
}

public func tls13HttpClientHelloInteropProfileEcdheP256(
    serverName: String,
    alpnProtocols!: Array<String> = []
): Tls13ClientHelloInteropProfile {
    tls13HttpClientHelloInteropProfileForGroup(serverName, TLS_HTTP_GROUP_SECP256R1, alpnProtocols)
}

public func tls13HttpClientHelloInteropProfileX25519(
    serverName: String,
    alpnProtocols!: Array<String> = []
): Tls13ClientHelloInteropProfile {
    tls13HttpClientHelloInteropProfileForGroup(serverName, TLS_HTTP_GROUP_X25519, alpnProtocols)
}

public func tls13BuildHttpClientHelloEcdhe(
    clientKeyShare: EcPublicKey,
    serverName: String,
    alpnProtocols!: Array<String> = []
): Array<Byte> {
    let baseHello = tlsDecodeClientHelloHandshake(tls13BuildClientHelloEcdhe(clientKeyShare))
    tls13BuildHttpClientHelloFromBase(baseHello, serverName, alpnProtocols)
}

public func tls13BuildHttpClientHelloX25519(
    clientKeyShare: Array<Byte>,
    serverName: String,
    alpnProtocols!: Array<String> = []
): Array<Byte> {
    let baseHello = tlsDecodeClientHelloHandshake(tls13BuildClientHelloX25519(clientKeyShare))
    tls13BuildHttpClientHelloFromBase(baseHello, serverName, alpnProtocols)
}

/**
 * tls13BuildHttpServerHandshakeContextEcdheP256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildHttpServerHandshakeContextEcdheP256(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy()
): Tls13ServerHandshakeContext {
    if (serverKeyExchangePrivate.curve != P256 || serverKeyShare.curve != P256) {
        throw CryptoException(InvalidArgument, "TLS HTTP ECDHE-P256 context requires P-256 key exchange keys")
    }
    let context = tls13BuildServerHandshakeContextEcdheP256(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        alpnPreference: policy.alpnPreference,
        acknowledgeServerName: policy.requireServerName
    )
    tls13ValidateHttpServerFlight(context.flight, policy: policy)
    context
}

/**
 * tls13BuildHttpServerHandshakeContextEcdheP384.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13BuildHttpServerHandshakeContextEcdheP384(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy()
): Tls13ServerHandshakeContext {
    if (serverKeyExchangePrivate.curve != P384 || serverKeyShare.curve != P384) {
        throw CryptoException(InvalidArgument, "TLS HTTP ECDHE-P384 context requires P-384 key exchange keys")
    }
    let context = tls13BuildServerHandshakeContextEcdheP384(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        alpnPreference: policy.alpnPreference,
        acknowledgeServerName: policy.requireServerName
    )
    tls13ValidateHttpServerFlight(context.flight, policy: policy)
    context
}

public func tls13BuildHttpServerHandshakeContextX25519(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    serverKeyShare: Array<Byte>,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy()
): Tls13ServerHandshakeContext {
    let context = tls13BuildServerHandshakeContextX25519(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        alpnPreference: policy.alpnPreference,
        acknowledgeServerName: policy.requireServerName
    )
    tls13ValidateHttpServerFlight(context.flight, policy: policy)
    context
}

public func tls13BuildHttpServerClientAuthContextEcdheP256(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy(),
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let context = tls13BuildHttpServerHandshakeContextEcdheP256(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        policy: policy
    )
    tls13BuildClientAuthRequestForServerContext(
        context,
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
}

public func tls13BuildHttpServerClientAuthContextEcdheP384(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: EcPrivateKey,
    serverKeyShare: EcPublicKey,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy(),
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let context = tls13BuildHttpServerHandshakeContextEcdheP384(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        policy: policy
    )
    tls13BuildClientAuthRequestForServerContext(
        context,
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
}

public func tls13BuildHttpServerClientAuthContextX25519(
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    serverKeyShare: Array<Byte>,
    certChainDer: Array<Array<Byte>>,
    certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
    certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy(),
    requestContext!: Array<Byte> = [],
    signatureSchemes!: Array<Int64> = [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ],
    certificateAuthorities!: Array<Array<Byte>> = []
): Tls13ServerClientAuthContext {
    let context = tls13BuildHttpServerHandshakeContextX25519(
        encodedClientHello,
        serverKeyExchangePrivate,
        serverKeyShare,
        certChainDer,
        certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
        certificatePrivateKeyRsa: certificatePrivateKeyRsa,
        policy: policy
    )
    tls13BuildClientAuthRequestForServerContext(
        context,
        requestContext: requestContext,
        signatureSchemes: signatureSchemes,
        certificateAuthorities: certificateAuthorities
    )
}

public func tls13ValidateHttpServerFlight(
    flight: Tls13ServerHandshakeFlight,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy()
): Unit {
    tls13ValidateHttpNegotiation(
        flight.selectedAlpn,
        flight.requestedServerName,
        flight.acknowledgedServerName,
        policy
    )
}

public func tls13ValidateHttpClientResult(
    result: Tls13ClientHandshakeResult,
    policy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy()
): Unit {
    tls13ValidateHttpNegotiation(
        result.selectedAlpn,
        result.requestedServerName,
        result.acknowledgedServerName,
        policy
    )
}

public func tls13ProcessHttpClientAuthFlightForServerContextWithRequirement(
    context: Tls13ServerClientAuthContext,
    policy: X509VerificationPolicy,
    httpPolicy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy(),
    clientAuthFlight!: ?Tls13AuthFlight = None,
    requireClientCertificate!: Bool = true,
    profile!: ?FipsProfile = None
): ?X509VerificationResult {
    tls13ValidateHttpServerFlight(context.serverContext.flight, policy: httpPolicy)
    tls13ProcessClientAuthFlightForServerContextWithRequirement(
        context,
        policy,
        clientAuthFlight: clientAuthFlight,
        requireClientCertificate: requireClientCertificate,
        profile: profile
    )
}

/**
 * tls13ProcessHttpClientAuthFlightForServerContextRequired.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13ProcessHttpClientAuthFlightForServerContextRequired(
    context: Tls13ServerClientAuthContext,
    clientAuthFlight: Tls13AuthFlight,
    policy: X509VerificationPolicy,
    httpPolicy!: TlsHttpNegotiationPolicy = TlsHttpNegotiationPolicy(),
    profile!: ?FipsProfile = None
): X509VerificationResult {
    let verified = tls13ProcessHttpClientAuthFlightForServerContextWithRequirement(
        context,
        policy,
        httpPolicy: httpPolicy,
        clientAuthFlight: Some(clientAuthFlight),
        requireClientCertificate: true,
        profile: profile
    )
    if (let Some(result) <- verified) {
        return result
    }
    throw CryptoException(ParseError, "TLS HTTP required client auth verification should produce result")
}

private func tls13BuildHttpClientHelloFromBase(
    baseHello: TlsClientHello,
    serverName: String,
    alpnProtocols: Array<String>
): Array<Byte> {
    let extensions = ArrayList<TlsExtension>()
    for (ext in baseHello.extensions) {
        if (ext.extType == TLS_EXT_SERVER_NAME || ext.extType == TLS_EXT_ALPN) {
            continue
        }
        extensions.add(ext)
    }

    let normalizedServerName = serverName.trimAscii().toAsciiLower()
    if (normalizedServerName.size > 0) {
        extensions.add(tlsBuildServerNameExtension(normalizedServerName))
    }
    let normalizedAlpn = tlsHttpNormalizeAlpn(alpnProtocols)
    if (normalizedAlpn.size > 0) {
        extensions.add(tlsBuildAlpnExtension(normalizedAlpn))
    }

    let rebuilt = TlsClientHello(
        baseHello.random,
        baseHello.cipherSuites,
        sessionId: baseHello.sessionId,
        compressionMethods: baseHello.compressionMethods,
        extensions: extensions.toArray(),
        legacyVersion: baseHello.legacyVersion
    )
    tlsEncodeClientHelloHandshake(rebuilt)
}

private func tls13HttpClientHelloInteropProfileForGroup(
    serverName: String,
    group: Int64,
    alpnProtocols: Array<String>
): Tls13ClientHelloInteropProfile {
    Tls13ClientHelloInteropProfile(
        serverName: serverName.trimAscii().toAsciiLower(),
        alpnProtocols: tlsHttpNormalizeAlpn(alpnProtocols),
        cipherSuites: [TLS13_CIPHER_SUITE_AES_128_GCM_SHA256],
        supportedVersions: [TLS_HTTP_VERSION_TLS13],
        supportedGroups: [group],
        keyShareGroups: [group],
        signatureSchemes: tls13HttpClientHelloSignatureSchemes()
    )
}

private func tls13HttpClientHelloSignatureSchemes(): Array<Int64> {
    [
        TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256,
        TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384,
        TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256
    ]
}

private func tls13ValidateHttpNegotiation(
    selectedAlpn: String,
    requestedServerName: String,
    acknowledgedServerName: Bool,
    policy: TlsHttpNegotiationPolicy
): Unit {
    let normalizedAlpn = selectedAlpn.trimAscii().toAsciiLower()
    if (normalizedAlpn.size == 0) {
        throw CryptoException(ParseError, "TLS HTTP profile requires ALPN negotiation")
    }
    if (!tlsHttpContains(policy.alpnPreference, normalizedAlpn)) {
        throw CryptoException(ParseError, "TLS HTTP profile ALPN is not accepted: ${normalizedAlpn}")
    }

    let normalizedServerName = requestedServerName.trimAscii().toAsciiLower()
    if (policy.requireServerName) {
        if (normalizedServerName.size == 0) {
            throw CryptoException(ParseError, "TLS HTTP profile requires client SNI")
        }
        if (!acknowledgedServerName) {
            throw CryptoException(ParseError, "TLS HTTP profile requires server_name acknowledgement")
        }
    }
    if (policy.allowedServerNames.size > 0) {
        if (normalizedServerName.size == 0) {
            throw CryptoException(ParseError, "TLS HTTP profile requires SNI for host allow-list checks")
        }
        if (!tlsHttpContains(policy.allowedServerNames, normalizedServerName)) {
            throw CryptoException(ParseError, "TLS HTTP profile rejected SNI host: ${normalizedServerName}")
        }
    }
}

private func tlsHttpNormalizeServerNames(serverNames: Array<String>): Array<String> {
    let normalized = ArrayList<String>()
    for (serverName in serverNames) {
        let candidate = serverName.trimAscii().toAsciiLower()
        if (candidate.size == 0) {
            throw CryptoException(InvalidArgument, "TLS HTTP allowed server name must not be empty")
        }
        if (candidate.contains(" ") || candidate.contains(",") || candidate.contains("\t")) {
            throw CryptoException(InvalidArgument, "TLS HTTP allowed server name is invalid: ${candidate}")
        }
        if (candidate.contains("\r") || candidate.contains("\n")) {
            throw CryptoException(InvalidArgument, "TLS HTTP allowed server name must be single line")
        }
        if (!tlsHttpContains(normalized.toArray(), candidate)) {
            normalized.add(candidate)
        }
    }
    normalized.toArray()
}

private func tlsHttpNormalizeAlpn(protocols: Array<String>): Array<String> {
    let source = if (protocols.size == 0) {
        tlsHttpDefaultAlpnPreference()
    } else {
        protocols
    }
    let normalized = ArrayList<String>()
    for (protocol in source) {
        let candidate = protocol.trimAscii().toAsciiLower()
        if (candidate.size == 0) {
            throw CryptoException(InvalidArgument, "TLS HTTP ALPN protocol id must not be empty")
        }
        if (candidate.contains(" ") || candidate.contains(",") || candidate.contains("\t")) {
            throw CryptoException(InvalidArgument, "TLS HTTP ALPN protocol id is invalid: ${candidate}")
        }
        if (candidate.contains("\r") || candidate.contains("\n")) {
            throw CryptoException(InvalidArgument, "TLS HTTP ALPN protocol id must be single line")
        }
        if (!tlsHttpContains(normalized.toArray(), candidate)) {
            normalized.add(candidate)
        }
    }
    normalized.toArray()
}

private func tlsHttpContains(values: Array<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}
