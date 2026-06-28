package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.aes.{AesEngineKind}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.{FipsProfile}
import jinguissl_core.crypto.digest.{hmac, HashAlgorithm}
import jinguissl_core.crypto.ecc.{EcPrivateKey, EcPublicKey, NamedCurve, ecdhDeriveSharedSecret, requireFipsCurve}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaPrivateKey, RsaPublicKey}
import jinguissl_core.crypto.utils.{randomSeed, secureCopyInto}
import jinguissl_core.crypto.x509.{X509Certificate, X509VerificationPolicy, X509VerificationResult, x509ParseDer, x509VerifyCertificateChain, x509VerifyCertificateChainWithProfile}

public enum Tls12KeyExchange <: Equatable<Tls12KeyExchange> & ToString {
    | RSA
    | ECDHE_P256
    | ECDHE_P384

    public operator func ==(right: Tls12KeyExchange): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: Tls12KeyExchange): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case RSA => 0
            case ECDHE_P256 => 1
            case ECDHE_P384 => 2
        }
    }

    public func toString(): String {
        match (this) {
            case RSA => "TLS12-RSA"
            case ECDHE_P256 => "TLS12-ECDHE-P256"
            case ECDHE_P384 => "TLS12-ECDHE-P384"
        }
    }
}

public class Tls12HandshakeSecrets {
    public let masterSecret: Array<Byte>
    public let clientWriteKey: Array<Byte>
    public let serverWriteKey: Array<Byte>
    public let clientWriteIv: Array<Byte>
    public let serverWriteIv: Array<Byte>

    public init(
        masterSecret: Array<Byte>,
        clientWriteKey: Array<Byte>,
        serverWriteKey: Array<Byte>,
        clientWriteIv: Array<Byte>,
        serverWriteIv: Array<Byte>
    ) {
        if (masterSecret.size == 0) {
            throw CryptoException(InvalidArgument, "master secret must not be empty")
        }
        if (clientWriteKey.size == 0 || serverWriteKey.size == 0) {
            throw CryptoException(InvalidArgument, "write keys must not be empty")
        }
        if (clientWriteIv.size == 0 || serverWriteIv.size == 0) {
            throw CryptoException(InvalidArgument, "write IVs must not be empty")
        }
        this.masterSecret = masterSecret.clone()
        this.clientWriteKey = clientWriteKey.clone()
        this.serverWriteKey = serverWriteKey.clone()
        this.clientWriteIv = clientWriteIv.clone()
        this.serverWriteIv = serverWriteIv.clone()
    }
}

public let TLS12_PREMASTER_SECRET_LEN: Int64 = 48
public let TLS12_MASTER_SECRET_LEN: Int64 = 48
public let TLS12_DEFAULT_AEAD_KEY_LEN: Int64 = 16
public let TLS12_DEFAULT_AEAD_IV_LEN: Int64 = 12

private let TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256: Int64 = 0x009c
private let TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256: Int64 = 0xc02f
private let TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384: Int64 = 0xc030
private let TLS12_NAMED_CURVE_SECP256R1: Int64 = 0x0017
private let TLS12_NAMED_CURVE_SECP384R1: Int64 = 0x0018
private let TLS12_ECC_POINT_UNCOMPRESSED: Int64 = 0x04
private let TLS12_P256_FIELD_BYTES: Int64 = 32
private let TLS12_P384_FIELD_BYTES: Int64 = 48
private let TLS12_CURVE_PARAMS_NAMED_CURVE: Int64 = 0x03
private let TLS12_VERSION_TLS12_MAJOR: Int64 = 0x03
private let TLS12_VERSION_TLS12_MINOR: Int64 = 0x03

public func tls12HandshakeRequireAllowed(
    profile: FipsProfile,
    keyExchange: Tls12KeyExchange,
    algorithm!: TlsAeadAlgorithm = AES_GCM
): Unit {
    profile.requireAllowed("TLS1.2")
    profile.requireAllowed(algorithm.toString())
    match (keyExchange) {
        case RSA => profile.requireAllowed("RSA")
        case ECDHE_P256 =>
            profile.requireAllowed("ECDH")
            requireFipsCurve(P256)
        case ECDHE_P384 =>
            profile.requireAllowed("ECDH")
            requireFipsCurve(P384)
    }
}

public func tls12BuildClientHello(
    keyExchange: Tls12KeyExchange,
    sessionId!: Array<Byte> = [],
    serverName!: String = "",
    alpnProtocols!: Array<String> = [],
    requestOcspStapling!: Bool = false
): Array<Byte> {
    let random = randomSeed(size: TLS_HELLO_RANDOM_LEN)
    let hello = TlsClientHello(
        random,
        tls12DefaultCipherSuites(keyExchange),
        sessionId: sessionId,
        compressionMethods: [UInt8(0x00)],
        extensions: tls12BuildClientExtensions(keyExchange, serverName, alpnProtocols, requestOcspStapling),
        legacyVersion: TLS1_2
    )
    tlsEncodeClientHelloHandshake(hello)
}

public func tls12BuildServerHello(
    encodedClientHello: Array<Byte>,
    keyExchange: Tls12KeyExchange
): Array<Byte> {
    let clientHello = tlsDecodeClientHelloHandshake(encodedClientHello)
    let selectedCipher = tls12SelectCipherSuite(clientHello.cipherSuites, keyExchange)
    let serverHello = TlsServerHello(
        randomSeed(size: TLS_HELLO_RANDOM_LEN),
        selectedCipher,
        sessionId: clientHello.sessionId,
        compressionMethod: UInt8(0x00),
        extensions: [],
        legacyVersion: TLS1_2
    )
    tlsEncodeServerHelloHandshake(serverHello)
}

public func tls12ExtractClientRandom(encodedClientHello: Array<Byte>): Array<Byte> {
    tlsDecodeClientHelloHandshake(encodedClientHello).random
}

public func tls12ExtractServerRandom(encodedServerHello: Array<Byte>): Array<Byte> {
    tlsDecodeServerHelloHandshake(encodedServerHello).random
}

public func tls12BuildCertificateHandshakeFromDerChain(certChainDer: Array<Array<Byte>>): Array<Byte> {
    tlsEncodeCertificateHandshakeTls12(certChainDer)
}

/**
 * tls12ParseCertificateChainFromHandshake.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls12ParseCertificateChainFromHandshake(encodedCertificate: Array<Byte>): Array<X509Certificate> {
    let certDerChain = tlsDecodeCertificateHandshakeTls12(encodedCertificate)
    if (certDerChain.size == 0) {
        throw CryptoException(ParseError, "TLS12 certificate chain must not be empty")
    }
    let chain = ArrayList<X509Certificate>()
    for (der in certDerChain) {
        chain.add(x509ParseDer(der))
    }
    chain.toArray()
}

public func tls12VerifyCertificateChainFromHandshake(
    encodedCertificate: Array<Byte>,
    policy: X509VerificationPolicy
): X509VerificationResult {
    let chain = tls12ParseCertificateChainFromHandshake(encodedCertificate)
    let leaf = chain[0]
    let embeddedIntermediates: Array<X509Certificate> = if (chain.size > 1) {
        chain[1..]
    } else {
        []
    }
    let mergedPolicy = tlsMergePolicyIntermediates(policy, embeddedIntermediates)
    x509VerifyCertificateChain(leaf, mergedPolicy)
}

public func tls12VerifyCertificateChainFromHandshakeWithProfile(
    encodedCertificate: Array<Byte>,
    policy: X509VerificationPolicy,
    profile: FipsProfile
): X509VerificationResult {
    let chain = tls12ParseCertificateChainFromHandshake(encodedCertificate)
    let leaf = chain[0]
    let embeddedIntermediates: Array<X509Certificate> = if (chain.size > 1) {
        chain[1..]
    } else {
        []
    }
    let mergedPolicy = tlsMergePolicyIntermediates(policy, embeddedIntermediates)
    x509VerifyCertificateChainWithProfile(leaf, mergedPolicy, profile)
}

public func tls12BuildRsaClientKeyExchange(
    serverPublicKey: RsaPublicKey
): (Array<Byte>, Array<Byte>) {
    let preMaster = randomSeed(size: TLS12_PREMASTER_SECRET_LEN)
    preMaster[0] = UInt8(TLS12_VERSION_TLS12_MAJOR)
    preMaster[1] = UInt8(TLS12_VERSION_TLS12_MINOR)

    let encrypted = rsaPkcs1v15Encrypt(serverPublicKey, preMaster)
    let body = tls12EncodeVector16(encrypted, "TLS12 RSA ClientKeyExchange payload")
    let encoded = tlsEncodeClientKeyExchangeHandshake(TlsKeyExchangeMessage(body))
    (encoded, preMaster)
}

/**
 * tls12ProcessRsaClientKeyExchange.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls12ProcessRsaClientKeyExchange(
    serverPrivateKey: RsaPrivateKey,
    encodedClientKeyExchange: Array<Byte>
): Array<Byte> {
    let message = tlsDecodeClientKeyExchangeHandshake(encodedClientKeyExchange)
    let encrypted = tls12DecodeVector16(message.exchangeData, "TLS12 RSA ClientKeyExchange payload")
    let preMaster = rsaPkcs1v15Decrypt(serverPrivateKey, encrypted)
    if (preMaster.size != TLS12_PREMASTER_SECRET_LEN) {
        throw CryptoException(ParseError, "TLS12 RSA pre-master secret length is invalid")
    }
    preMaster
}

public func tls12BuildEcdheServerKeyExchange(serverPublicKey: EcPublicKey): Array<Byte> {
    let (curveId, fieldBytes) = tls12ResolveEcdheCurveSpecFromPublicKey(serverPublicKey)
    let point = tls12EncodeUncompressedPoint(serverPublicKey, fieldBytes)
    let body = Array<Byte>(3 + 1 + point.size, repeat: 0)
    body[0] = UInt8(TLS12_CURVE_PARAMS_NAMED_CURVE)
    let curve = tls12EncodeUInt16(curveId)
    body[1] = curve[0]
    body[2] = curve[1]
    body[3] = UInt8(point.size)
    secureCopyInto(point, body, dstOffset: 4)
    tlsEncodeServerKeyExchangeHandshake(TlsKeyExchangeMessage(body))
}

/**
 * tls12ParseEcdheServerKeyExchange.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls12ParseEcdheServerKeyExchange(encodedServerKeyExchange: Array<Byte>): EcPublicKey {
    let message = tlsDecodeServerKeyExchangeHandshake(encodedServerKeyExchange)
    if (message.exchangeData.size < 4) {
        throw CryptoException(ParseError, "TLS12 ECDHE ServerKeyExchange is too short")
    }

    if (Int64(UInt8(message.exchangeData[0])) != TLS12_CURVE_PARAMS_NAMED_CURVE) {
        throw CryptoException(ParseError, "TLS12 ECDHE curve params type must be named_curve")
    }
    let curve = tls12DecodeUInt16(message.exchangeData, 1)
    let (namedCurve, fieldBytes) = tls12ResolveEcdheCurveSpecFromNamedCurveId(curve)

    let pointLen = Int64(UInt8(message.exchangeData[3]))
    if (pointLen == 0 || pointLen > message.exchangeData.size - 4) {
        throw CryptoException(ParseError, "TLS12 ECDHE point length is invalid")
    }
    if (4 + pointLen != message.exchangeData.size) {
        throw CryptoException(ParseError, "TLS12 ECDHE ServerKeyExchange contains trailing bytes")
    }
    let point = message.exchangeData[4..]
    tls12DecodeUncompressedPoint(point, namedCurve, fieldBytes)
}

public func tls12BuildEcdheClientKeyExchange(clientPublicKey: EcPublicKey): Array<Byte> {
    let (_, fieldBytes) = tls12ResolveEcdheCurveSpecFromPublicKey(clientPublicKey)
    let point = tls12EncodeUncompressedPoint(clientPublicKey, fieldBytes)
    let body = Array<Byte>(1 + point.size, repeat: 0)
    body[0] = UInt8(point.size)
    secureCopyInto(point, body, dstOffset: 1)
    tlsEncodeClientKeyExchangeHandshake(TlsKeyExchangeMessage(body))
}

/**
 * tls12ParseEcdheClientKeyExchange.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls12ParseEcdheClientKeyExchange(encodedClientKeyExchange: Array<Byte>): EcPublicKey {
    let message = tlsDecodeClientKeyExchangeHandshake(encodedClientKeyExchange)
    if (message.exchangeData.size < 2) {
        throw CryptoException(ParseError, "TLS12 ECDHE ClientKeyExchange is too short")
    }

    let pointLen = Int64(UInt8(message.exchangeData[0]))
    if (pointLen == 0 || pointLen > message.exchangeData.size - 1) {
        throw CryptoException(ParseError, "TLS12 ECDHE point length is invalid")
    }
    if (1 + pointLen != message.exchangeData.size) {
        throw CryptoException(ParseError, "TLS12 ECDHE ClientKeyExchange contains trailing bytes")
    }
    let (namedCurve, fieldBytes) = tls12ResolveEcdheCurveSpecFromPointLength(pointLen)
    tls12DecodeUncompressedPoint(message.exchangeData[1..], namedCurve, fieldBytes)
}

/**
 * tls12DeriveSecretsFromPreMaster.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls12DeriveSecretsFromPreMaster(
    preMasterSecret: Array<Byte>,
    clientRandom: Array<Byte>,
    serverRandom: Array<Byte>,
    keyLen!: Int64 = TLS12_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS12_DEFAULT_AEAD_IV_LEN
): Tls12HandshakeSecrets {
    requireRandom32(clientRandom, "client_random")
    requireRandom32(serverRandom, "server_random")
    if (preMasterSecret.size == 0) {
        throw CryptoException(InvalidArgument, "pre-master secret must not be empty")
    }
    if (keyLen <= 0 || ivLen <= 0) {
        throw CryptoException(InvalidArgument, "TLS12 key/iv length must be > 0")
    }

    let masterSeed = concat(clientRandom, serverRandom)
    let masterSecret = tls12PrfSha256(preMasterSecret, "master secret", masterSeed, TLS12_MASTER_SECRET_LEN)

    let keyBlockSeed = concat(serverRandom, clientRandom)
    let total = 2 * keyLen + 2 * ivLen
    let keyBlock = tls12PrfSha256(masterSecret, "key expansion", keyBlockSeed, total)

    var offset = 0
    let clientWriteKey = keyBlock[offset..(offset + keyLen)]
    offset += keyLen
    let serverWriteKey = keyBlock[offset..(offset + keyLen)]
    offset += keyLen
    let clientWriteIv = keyBlock[offset..(offset + ivLen)]
    offset += ivLen
    let serverWriteIv = keyBlock[offset..(offset + ivLen)]

    Tls12HandshakeSecrets(
        masterSecret,
        clientWriteKey,
        serverWriteKey,
        clientWriteIv,
        serverWriteIv
    )
}

public func tls12DeriveSecretsFromEcdhe(
    privateKey: EcPrivateKey,
    peerPublicKey: EcPublicKey,
    clientRandom: Array<Byte>,
    serverRandom: Array<Byte>,
    keyLen!: Int64 = TLS12_DEFAULT_AEAD_KEY_LEN,
    ivLen!: Int64 = TLS12_DEFAULT_AEAD_IV_LEN
): Tls12HandshakeSecrets {
    let preMasterSecret = ecdhDeriveSharedSecret(privateKey, peerPublicKey)
    tls12DeriveSecretsFromPreMaster(preMasterSecret, clientRandom, serverRandom, keyLen: keyLen, ivLen: ivLen)
}

public func tls12CreateClientRecordLayer(
    secrets: Tls12HandshakeSecrets,
    requestedEngine!: AesEngineKind = AUTO
): TlsAeadRecordLayer {
    TlsAeadRecordLayer(
        secrets.clientWriteKey,
        secrets.clientWriteIv,
        readKey: secrets.serverWriteKey,
        readIv: secrets.serverWriteIv,
        version: TLS1_2,
        requestedEngine: requestedEngine
    )
}

public func tls12CreateServerRecordLayer(
    secrets: Tls12HandshakeSecrets,
    requestedEngine!: AesEngineKind = AUTO
): TlsAeadRecordLayer {
    TlsAeadRecordLayer(
        secrets.serverWriteKey,
        secrets.serverWriteIv,
        readKey: secrets.clientWriteKey,
        readIv: secrets.clientWriteIv,
        version: TLS1_2,
        requestedEngine: requestedEngine
    )
}

public func tls12CreateClientRecordLayerChacha20Poly1305(
    secrets: Tls12HandshakeSecrets
): TlsChacha20Poly1305RecordLayer {
    TlsChacha20Poly1305RecordLayer(
        secrets.clientWriteKey,
        secrets.clientWriteIv,
        readKey: secrets.serverWriteKey,
        readIv: secrets.serverWriteIv,
        version: TLS1_2
    )
}

public func tls12CreateServerRecordLayerChacha20Poly1305(
    secrets: Tls12HandshakeSecrets
): TlsChacha20Poly1305RecordLayer {
    TlsChacha20Poly1305RecordLayer(
        secrets.serverWriteKey,
        secrets.serverWriteIv,
        readKey: secrets.clientWriteKey,
        readIv: secrets.clientWriteIv,
        version: TLS1_2
    )
}

/**
 * tls12PrfSha256.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls12PrfSha256(secret: Array<Byte>, label: String, seed: Array<Byte>, outputLen: Int64): Array<Byte> {
    if (secret.size == 0) {
        throw CryptoException(InvalidArgument, "TLS12 PRF secret must not be empty")
    }
    if (outputLen < 0) {
        throw CryptoException(InvalidArgument, "TLS12 PRF output length must be >= 0")
    }
    if (outputLen == 0) {
        return []
    }

    let labelSeed = concat(label.toArray(), seed)
    tls12PHashSha256(secret, labelSeed, outputLen)
}

private func tls12PHashSha256(secret: Array<Byte>, seed: Array<Byte>, outputLen: Int64): Array<Byte> {
    let out = Array<Byte>(outputLen, repeat: 0)
    var a = seed.clone()
    var offset = 0
    while (offset < outputLen) {
        a = hmac(HashAlgorithm.SHA256, secret, a)
        let block = hmac(HashAlgorithm.SHA256, secret, concat(a, seed))
        let remain = outputLen - offset
        let take = if (remain < block.size) {
            remain
        } else {
            block.size
        }
        var i = 0
        while (i < take) {
            out[offset + i] = block[i]
            i += 1
        }
        offset += take
    }
    out
}

private func tls12DefaultCipherSuites(keyExchange: Tls12KeyExchange): Array<Int64> {
    match (keyExchange) {
        case RSA => [TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256]
        case ECDHE_P256 => [TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256, TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256]
        case ECDHE_P384 => [TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384, TLS12_CIPHER_RSA_WITH_AES_128_GCM_SHA256]
    }
}

private func tls12DefaultClientExtensions(keyExchange: Tls12KeyExchange): Array<TlsExtension> {
    match (keyExchange) {
        case RSA => []
        case ECDHE_P256 =>
            [
                TlsExtension(0x000a, [UInt8(0x00), UInt8(0x02), UInt8(0x00), UInt8(0x17)]),
                TlsExtension(0x000b, [UInt8(0x01), UInt8(0x00)])
            ]
        case ECDHE_P384 =>
            [
                TlsExtension(0x000a, [UInt8(0x00), UInt8(0x02), UInt8(0x00), UInt8(0x18)]),
                TlsExtension(0x000b, [UInt8(0x01), UInt8(0x00)])
            ]
    }
}

private func tls12BuildClientExtensions(
    keyExchange: Tls12KeyExchange,
    serverName: String,
    alpnProtocols: Array<String>,
    requestOcspStapling: Bool
): Array<TlsExtension> {
    let list = ArrayList<TlsExtension>()
    for (ext in tls12DefaultClientExtensions(keyExchange)) {
        list.add(ext)
    }
    if (serverName.trimAscii().size > 0) {
        list.add(tlsBuildServerNameExtension(serverName))
    }
    if (alpnProtocols.size > 0) {
        list.add(tlsBuildAlpnExtension(alpnProtocols))
    }
    if (requestOcspStapling) {
        list.add(tlsBuildOcspStatusRequestExtension())
    }
    list.toArray()
}

private func tls12SelectCipherSuite(offered: Array<Int64>, keyExchange: Tls12KeyExchange): Int64 {
    let supported = tls12DefaultCipherSuites(keyExchange)
    for (suite in supported) {
        for (candidate in offered) {
            if (suite == candidate) {
                return suite
            }
        }
    }
    throw CryptoException(ParseError, "TLS12 server could not select a compatible cipher suite")
}

private func rsaPkcs1v15Encrypt(publicKey: RsaPublicKey, message: Array<Byte>): Array<Byte> {
    let k = rsaModulusByteLength(publicKey.modulus)
    if (message.size > k - 11) {
        throw CryptoException(OutOfBounds, "RSA PKCS1v1.5 message is too long")
    }

    let em = Array<Byte>(k, repeat: 0)
    em[0] = UInt8(0x00)
    em[1] = UInt8(0x02)

    let psLen = k - message.size - 3
    if (psLen < 8) {
        throw CryptoException(OutOfBounds, "RSA modulus is too small for PKCS1v1.5 encryption")
    }

    let ps = randomNonZeroBytes(psLen)
    secureCopyInto(ps, em, dstOffset: 2)
    em[2 + psLen] = UInt8(0x00)
    secureCopyInto(message, em, dstOffset: 3 + psLen)

    let m = BigNum.fromBytesBE(em)
    m.modExp(publicKey.exponent, publicKey.modulus).toBytesBE(paddedLen: k)
}

private func rsaPkcs1v15Decrypt(privateKey: RsaPrivateKey, ciphertext: Array<Byte>): Array<Byte> {
    let modulus = privateKey.publicKey.modulus
    let k = rsaModulusByteLength(modulus)
    if (ciphertext.size != k) {
        throw CryptoException(ParseError, "RSA ciphertext length mismatch")
    }

    let c = BigNum.fromBytesBE(ciphertext)
    if (c.cmp(modulus) >= 0) {
        throw CryptoException(ParseError, "RSA ciphertext representative out of range")
    }
    let em = c.modExp(privateKey.privateExponent, modulus).toBytesBE(paddedLen: k)

    if (UInt8(em[0]) != UInt8(0x00) || UInt8(em[1]) != UInt8(0x02)) {
        throw CryptoException(ParseError, "RSA PKCS1v1.5 decrypted block has invalid prefix")
    }

    var sep = 2
    while (sep < em.size && UInt8(em[sep]) != UInt8(0x00)) {
        sep += 1
    }
    if (sep >= em.size) {
        throw CryptoException(ParseError, "RSA PKCS1v1.5 decrypted block missing separator")
    }
    if (sep - 2 < 8) {
        throw CryptoException(ParseError, "RSA PKCS1v1.5 decrypted block has short PS")
    }
    em[(sep + 1)..]
}

private func randomNonZeroBytes(size: Int64): Array<Byte> {
    let out = Array<Byte>(size, repeat: UInt8(0x01))
    var i = 0
    while (i < size) {
        var b = UInt8(0)
        while (b == UInt8(0)) {
            b = randomSeed(size: 1)[0]
        }
        out[i] = b
        i += 1
    }
    out
}

private func rsaModulusByteLength(modulus: BigNum): Int64 {
    let raw = modulus.toBytesBE()
    if (raw.size == 1 && UInt8(raw[0]) == UInt8(0)) {
        throw CryptoException(InvalidArgument, "RSA modulus must be positive")
    }
    raw.size
}

private func tls12ResolveEcdheCurveSpecFromPublicKey(publicKey: EcPublicKey): (Int64, Int64) {
    if (publicKey.curve == P256) {
        return (TLS12_NAMED_CURVE_SECP256R1, TLS12_P256_FIELD_BYTES)
    }
    if (publicKey.curve == P384) {
        return (TLS12_NAMED_CURVE_SECP384R1, TLS12_P384_FIELD_BYTES)
    }
    throw CryptoException(Unsupported, "TLS12 ECDHE currently supports only P-256/P-384")
}

private func tls12ResolveEcdheCurveSpecFromNamedCurveId(namedCurveId: Int64): (NamedCurve, Int64) {
    if (namedCurveId == TLS12_NAMED_CURVE_SECP256R1) {
        return (P256, TLS12_P256_FIELD_BYTES)
    }
    if (namedCurveId == TLS12_NAMED_CURVE_SECP384R1) {
        return (P384, TLS12_P384_FIELD_BYTES)
    }
    throw CryptoException(Unsupported, "TLS12 ECDHE named curve is unsupported")
}

private func tls12ResolveEcdheCurveSpecFromPointLength(pointLen: Int64): (NamedCurve, Int64) {
    if (pointLen == 1 + TLS12_P256_FIELD_BYTES * 2) {
        return (P256, TLS12_P256_FIELD_BYTES)
    }
    if (pointLen == 1 + TLS12_P384_FIELD_BYTES * 2) {
        return (P384, TLS12_P384_FIELD_BYTES)
    }
    throw CryptoException(ParseError, "TLS12 ECDHE point length does not map to supported curve")
}

private func tls12EncodeUncompressedPoint(publicKey: EcPublicKey, fieldBytes: Int64): Array<Byte> {
    let out = Array<Byte>(1 + fieldBytes * 2, repeat: 0)
    out[0] = UInt8(TLS12_ECC_POINT_UNCOMPRESSED)
    let x = publicKey.x.toBytesBE(paddedLen: fieldBytes)
    let y = publicKey.y.toBytesBE(paddedLen: fieldBytes)
    secureCopyInto(x, out, dstOffset: 1)
    secureCopyInto(y, out, dstOffset: 1 + fieldBytes)
    out
}

private func tls12DecodeUncompressedPoint(encoded: Array<Byte>, curve: NamedCurve, fieldBytes: Int64): EcPublicKey {
    if (encoded.size != 1 + fieldBytes * 2) {
        throw CryptoException(ParseError, "TLS12 ECDHE point length is invalid")
    }
    if (Int64(UInt8(encoded[0])) != TLS12_ECC_POINT_UNCOMPRESSED) {
        throw CryptoException(ParseError, "TLS12 ECDHE point must be uncompressed")
    }

    let x = BigNum.fromBytesBE(encoded[1..(1 + fieldBytes)])
    let y = BigNum.fromBytesBE(encoded[(1 + fieldBytes)..])
    EcPublicKey(curve, x, y)
}

private func requireRandom32(random: Array<Byte>, label: String): Unit {
    if (random.size != TLS_HELLO_RANDOM_LEN) {
        throw CryptoException(InvalidArgument, "TLS12 ${label} must be 32 bytes")
    }
}

private func tls12EncodeVector16(payload: Array<Byte>, label: String): Array<Byte> {
    if (payload.size > 65535) {
        throw CryptoException(OutOfBounds, "${label} exceeds uint16 length")
    }
    let out = Array<Byte>(2 + payload.size, repeat: 0)
    let len = tls12EncodeUInt16(payload.size)
    out[0] = len[0]
    out[1] = len[1]
    secureCopyInto(payload, out, dstOffset: 2)
    out
}

private func tls12DecodeVector16(payload: Array<Byte>, label: String): Array<Byte> {
    if (payload.size < 2) {
        throw CryptoException(ParseError, "${label} is too short")
    }
    let len = tls12DecodeUInt16(payload, 0)
    if (len != payload.size - 2) {
        throw CryptoException(ParseError, "${label} length mismatch")
    }
    payload[2..]
}

private func tlsMergePolicyIntermediates(
    base: X509VerificationPolicy,
    embeddedIntermediates: Array<X509Certificate>
): X509VerificationPolicy {
    let mergedIntermediates = concatCertArray(base.intermediates, embeddedIntermediates)
    X509VerificationPolicy(
        base.trustAnchors,
        intermediates: mergedIntermediates,
        crls: base.crls,
        requireCrlForAllIssuers: base.requireCrlForAllIssuers,
        requireCrlIfDistributionPointsPresent: base.requireCrlIfDistributionPointsPresent,
        requireCrlAuthorityKeyIdentifierMatch: base.requireCrlAuthorityKeyIdentifierMatch,
        requireAuthorityKeyIdentifierMatch: base.requireAuthorityKeyIdentifierMatch,
        requiredLeafKeyUsageMask: base.requiredLeafKeyUsageMask,
        requiredLeafExtendedKeyUsages: base.requiredLeafExtendedKeyUsages,
        requiredLeafCertificatePolicies: base.requiredLeafCertificatePolicies,
        requiredLeafDnsName: base.requiredLeafDnsName,
        validationTime: base.validationTime,
        revokedSerialHexLower: base.revokedSerialHexLower
    )
}

private func concatCertArray(left: Array<X509Certificate>, right: Array<X509Certificate>): Array<X509Certificate> {
    if (left.size == 0) {
        return right.clone()
    }
    if (right.size == 0) {
        return left.clone()
    }
    let out = Array<X509Certificate>(left.size + right.size, repeat: left[0])
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

@OverflowWrapping
private func tls12EncodeUInt16(value: Int64): Array<Byte> {
    if (value < 0 || value > 65535) {
        throw CryptoException(OutOfBounds, "value does not fit into uint16")
    }
    let v = UInt16(value)
    [UInt8((v >> 8) & UInt16(0xff)), UInt8(v & UInt16(0xff))]
}

@OverflowWrapping
private func tls12DecodeUInt16(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 2 > bytes.size) {
        throw CryptoException(ParseError, "uint16 decode out of bounds")
    }
    (Int64(UInt8(bytes[offset])) << 8) | Int64(UInt8(bytes[offset + 1]))
}

private func concat(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    secureCopyInto(left, out)
    secureCopyInto(right, out, dstOffset: left.size)
    out
}
