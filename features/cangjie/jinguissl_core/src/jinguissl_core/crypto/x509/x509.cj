package jinguissl_core.crypto.x509

import std.collection.ArrayList
import std.fs.{File, exists}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.{bytesToHexLower, sha256, sha384, sha512}
import jinguissl_core.crypto.ecc.{EcPrivateKey, EcPublicKey, NamedCurve, ecPublicFromPrivateKey, ecdsaSign, ecdsaVerify, isFipsCurve}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{RsaPrivateKey, RsaPublicKey, RsaHashAlgorithm, rsaSignPkcs1v15WithHash, rsaVerifyPkcs1v15WithHash}
import jinguissl_core.crypto.utils.{constantTimeEquals, secureCopyInto}

private func joinOidParts(parts: Array<Int64>): String {
    if (parts.size == 0) {
        return ""
    }
    var out = parts[0].toString()
    var i = 1
    while (i < parts.size) {
        out = "${out}.${parts[i]}"
        i += 1
    }
    out
}

public let X509_OID_COMMON_NAME: String = joinOidParts([2, 5, 4, 3])
public let X509_OID_KEY_USAGE: String = joinOidParts([2, 5, 29, 15])
public let X509_OID_SUBJECT_ALT_NAME: String = joinOidParts([2, 5, 29, 17])
public let X509_OID_SUBJECT_KEY_IDENTIFIER: String = joinOidParts([2, 5, 29, 14])
public let X509_OID_BASIC_CONSTRAINTS: String = joinOidParts([2, 5, 29, 19])
public let X509_OID_AUTHORITY_KEY_IDENTIFIER: String = joinOidParts([2, 5, 29, 35])
public let X509_OID_EXTENDED_KEY_USAGE: String = joinOidParts([2, 5, 29, 37])
public let X509_OID_CRL_DISTRIBUTION_POINTS: String = joinOidParts([2, 5, 29, 31])
public let X509_OID_CERTIFICATE_POLICIES: String = joinOidParts([2, 5, 29, 32])
public let X509_OID_ANY_POLICY: String = joinOidParts([2, 5, 29, 32, 0])
public let X509_OID_EKU_ANY: String = joinOidParts([2, 5, 29, 37, 0])
public let X509_OID_EKU_SERVER_AUTH: String = joinOidParts([1, 3, 6, 1, 5, 5, 7, 3, 1])
public let X509_OID_EKU_CLIENT_AUTH: String = joinOidParts([1, 3, 6, 1, 5, 5, 7, 3, 2])
public let X509_OID_EKU_CODE_SIGNING: String = joinOidParts([1, 3, 6, 1, 5, 5, 7, 3, 3])
public let X509_OID_EKU_EMAIL_PROTECTION: String = joinOidParts([1, 3, 6, 1, 5, 5, 7, 3, 4])
public let X509_OID_EKU_TIME_STAMPING: String = joinOidParts([1, 3, 6, 1, 5, 5, 7, 3, 8])
public let X509_OID_EKU_OCSP_SIGNING: String = joinOidParts([1, 3, 6, 1, 5, 5, 7, 3, 9])
public let X509_OID_RSA_ENCRYPTION: String = joinOidParts([1, 2, 840, 113549, 1, 1, 1])
public let X509_OID_EC_PUBLIC_KEY: String = joinOidParts([1, 2, 840, 10045, 2, 1])
public let X509_OID_PRIME256V1: String = joinOidParts([1, 2, 840, 10045, 3, 1, 7])
public let X509_OID_SECP384R1: String = joinOidParts([1, 3, 132, 0, 34])
public let X509_OID_SECP521R1: String = joinOidParts([1, 3, 132, 0, 35])
public let X509_OID_SECP256K1: String = joinOidParts([1, 3, 132, 0, 10])
public let X509_OID_SHA256_WITH_RSA: String = joinOidParts([1, 2, 840, 113549, 1, 1, 11])
public let X509_OID_SHA384_WITH_RSA: String = joinOidParts([1, 2, 840, 113549, 1, 1, 12])
public let X509_OID_SHA512_WITH_RSA: String = joinOidParts([1, 2, 840, 113549, 1, 1, 13])
public let X509_OID_ECDSA_WITH_SHA256: String = joinOidParts([1, 2, 840, 10045, 4, 3, 2])
public let X509_OID_ECDSA_WITH_SHA384: String = joinOidParts([1, 2, 840, 10045, 4, 3, 3])
public let X509_OID_ECDSA_WITH_SHA512: String = joinOidParts([1, 2, 840, 10045, 4, 3, 4])

public let X509_KEY_USAGE_DIGITAL_SIGNATURE: Int64 = Int64(1) << 0
public let X509_KEY_USAGE_CONTENT_COMMITMENT: Int64 = Int64(1) << 1
public let X509_KEY_USAGE_KEY_ENCIPHERMENT: Int64 = Int64(1) << 2
public let X509_KEY_USAGE_DATA_ENCIPHERMENT: Int64 = Int64(1) << 3
public let X509_KEY_USAGE_KEY_AGREEMENT: Int64 = Int64(1) << 4
public let X509_KEY_USAGE_KEY_CERT_SIGN: Int64 = Int64(1) << 5
public let X509_KEY_USAGE_CRL_SIGN: Int64 = Int64(1) << 6
public let X509_KEY_USAGE_ENCIPHER_ONLY: Int64 = Int64(1) << 7
public let X509_KEY_USAGE_DECIPHER_ONLY: Int64 = Int64(1) << 8

private let PEM_CERT_BEGIN: String = "-----BEGIN CERTIFICATE-----"
private let PEM_CERT_END: String = "-----END CERTIFICATE-----"

private let DER_TAG_BOOLEAN: Int64 = 0x01
private let DER_TAG_INTEGER: Int64 = 0x02
private let DER_TAG_BIT_STRING: Int64 = 0x03
private let DER_TAG_OCTET_STRING: Int64 = 0x04
private let DER_TAG_NULL: Int64 = 0x05
private let DER_TAG_OID: Int64 = 0x06
private let DER_TAG_UTF8_STRING: Int64 = 0x0c
private let DER_TAG_SEQUENCE: Int64 = 0x30
private let DER_TAG_SET: Int64 = 0x31
private let DER_TAG_PRINTABLE_STRING: Int64 = 0x13
private let DER_TAG_T61_STRING: Int64 = 0x14
private let DER_TAG_IA5_STRING: Int64 = 0x16
private let DER_TAG_UTC_TIME: Int64 = 0x17
private let DER_TAG_GENERALIZED_TIME: Int64 = 0x18
private let DER_TAG_BMP_STRING: Int64 = 0x1e
private let DER_TAG_CONTEXT_0: Int64 = 0xa0
private let DER_TAG_CONTEXT_1: Int64 = 0xa1
private let DER_TAG_CONTEXT_6_PRIMITIVE: Int64 = 0x86
private let DER_TAG_CONTEXT_3: Int64 = 0xa3

public class X509NameAttribute {
    public let oid: String
    public let value: String

    public init(oid: String, value: String) {
        let normalizedOid = oid.trimAscii()
        if (normalizedOid.size == 0) {
            throw CryptoException(InvalidArgument, "X509 attribute OID must not be empty")
        }
        this.oid = normalizedOid
        this.value = value
    }
}

public class X509Name {
    public let attributes: Array<X509NameAttribute>
    public let der: Array<Byte>

    public init(attributes: Array<X509NameAttribute>, der: Array<Byte>) {
        this.attributes = attributes.clone()
        this.der = der.clone()
    }

    public func commonName(): String {
        let found = x509NameFindFirstValue(this, X509_OID_COMMON_NAME)
        found ?? ""
    }
}

public class X509Extension {
    public let oid: String
    public let critical: Bool
    public let value: Array<Byte>

    public init(oid: String, critical: Bool, value: Array<Byte>) {
        let normalizedOid = oid.trimAscii()
        if (normalizedOid.size == 0) {
            throw CryptoException(InvalidArgument, "X509 extension OID must not be empty")
        }
        this.oid = normalizedOid
        this.critical = critical
        this.value = value.clone()
    }
}

public class X509Certificate {
    public let der: Array<Byte>
    public let tbsDer: Array<Byte>
    public let serialNumber: Array<Byte>
    public let signatureAlgorithmOid: String
    public let issuer: X509Name
    public let subject: X509Name
    public let notBefore: String
    public let notAfter: String
    public let subjectPublicKeyInfoDer: Array<Byte>
    public let extensions: Array<X509Extension>
    public let signatureValue: Array<Byte>

    public init(
        der: Array<Byte>,
        tbsDer: Array<Byte>,
        serialNumber: Array<Byte>,
        signatureAlgorithmOid: String,
        issuer: X509Name,
        subject: X509Name,
        notBefore: String,
        notAfter: String,
        subjectPublicKeyInfoDer: Array<Byte>,
        extensions: Array<X509Extension>,
        signatureValue: Array<Byte>
    ) {
        if (der.size == 0 || tbsDer.size == 0 || serialNumber.size == 0 || signatureValue.size == 0) {
            throw CryptoException(InvalidArgument, "X509 certificate fields must not be empty")
        }
        if (signatureAlgorithmOid.trimAscii().size == 0) {
            throw CryptoException(InvalidArgument, "X509 signature algorithm OID must not be empty")
        }
        this.der = der.clone()
        this.tbsDer = tbsDer.clone()
        this.serialNumber = serialNumber.clone()
        this.signatureAlgorithmOid = signatureAlgorithmOid
        this.issuer = issuer
        this.subject = subject
        this.notBefore = notBefore
        this.notAfter = notAfter
        this.subjectPublicKeyInfoDer = subjectPublicKeyInfoDer.clone()
        this.extensions = extensions.clone()
        this.signatureValue = signatureValue.clone()
    }

    public func serialHexLower(): String {
        bytesToHexLower(serialNumber)
    }

    public func isSelfIssued(): Bool {
        x509NameDerEquals(issuer, subject)
    }

    public func toPem(): String {
        x509DerToPem(der)
    }
}

public class X509SelfSignedConfig {
    public let commonName: String
    public let serialNumber: Array<Byte>
    public let notBefore: String
    public let notAfter: String
    public let keyUsageMask: Int64

    public init(
        commonName: String,
        serialNumber!: Array<Byte> = [UInt8(0x01)],
        notBefore!: String = "260101000000Z",
        notAfter!: String = "360101000000Z",
        keyUsageMask!: Int64 = X509_KEY_USAGE_DIGITAL_SIGNATURE | X509_KEY_USAGE_KEY_ENCIPHERMENT
    ) {
        let cn = commonName.trimAscii()
        if (cn.size == 0) {
            throw CryptoException(InvalidArgument, "X509 self-signed common name must not be empty")
        }
        if (serialNumber.size == 0) {
            throw CryptoException(InvalidArgument, "X509 self-signed serial number must not be empty")
        }
        let notBeforeIsValid = isValidX509Time(notBefore)
        let notAfterIsValid = isValidX509Time(notAfter)
        if (!notBeforeIsValid || !notAfterIsValid) {
            throw CryptoException(InvalidArgument, "X509 validity time must be UTCTime(YYMMDDHHMMSSZ) or GeneralizedTime(YYYYMMDDHHMMSSZ)")
        }
        this.commonName = cn
        this.serialNumber = trimLeadingZeroBytes(serialNumber)
        this.notBefore = notBefore
        this.notAfter = notAfter
        this.keyUsageMask = keyUsageMask
    }
}

public class X509Crl {
    public let der: Array<Byte>
    public let tbsDer: Array<Byte>
    public let signatureAlgorithmOid: String
    public let issuer: X509Name
    public let thisUpdate: String
    public let nextUpdate: String
    public let revokedSerialHexLower: Array<String>
    public let authorityKeyIdentifier: ?X509AuthorityKeyIdentifier
    public let signatureValue: Array<Byte>

    public init(
        der: Array<Byte>,
        tbsDer: Array<Byte>,
        signatureAlgorithmOid: String,
        issuer: X509Name,
        thisUpdate: String,
        nextUpdate: String,
        revokedSerialHexLower: Array<String>,
        signatureValue: Array<Byte>,
        authorityKeyIdentifier!: ?X509AuthorityKeyIdentifier = None
    ) {
        if (der.size == 0 || tbsDer.size == 0 || signatureValue.size == 0) {
            throw CryptoException(InvalidArgument, "X509 CRL fields must not be empty")
        }
        if (signatureAlgorithmOid.trimAscii().size == 0) {
            throw CryptoException(InvalidArgument, "X509 CRL signature algorithm OID must not be empty")
        }
        if (!isValidX509Time(thisUpdate)) {
            throw CryptoException(InvalidArgument, "X509 CRL thisUpdate format is invalid")
        }
        let hasNextUpdate = nextUpdate.size > 0
        if (hasNextUpdate) {
            let nextUpdateIsValid = isValidX509Time(nextUpdate)
            if (!nextUpdateIsValid) {
                throw CryptoException(InvalidArgument, "X509 CRL nextUpdate format is invalid")
            }
        }
        this.der = der.clone()
        this.tbsDer = tbsDer.clone()
        this.signatureAlgorithmOid = signatureAlgorithmOid
        this.issuer = issuer
        this.thisUpdate = thisUpdate
        this.nextUpdate = nextUpdate
        this.revokedSerialHexLower = normalizeHexList(revokedSerialHexLower)
        this.authorityKeyIdentifier = cloneAuthorityKeyIdentifier(authorityKeyIdentifier)
        this.signatureValue = signatureValue.clone()
    }
}

public class X509VerificationPolicy {
    public let trustAnchors: Array<X509Certificate>
    public let intermediates: Array<X509Certificate>
    public let crls: Array<X509Crl>
    public let requireCrlForAllIssuers: Bool
    public let requireCrlIfDistributionPointsPresent: Bool
    public let requireCrlAuthorityKeyIdentifierMatch: Bool
    public let requireAuthorityKeyIdentifierMatch: Bool
    public let requiredLeafKeyUsageMask: Int64
    public let requiredLeafExtendedKeyUsages: Array<String>
    public let requiredLeafCertificatePolicies: Array<String>
    public let requiredLeafDnsName: String
    public let validationTime: String
    public let revokedSerialHexLower: Array<String>

    public init(
        trustAnchors: Array<X509Certificate>,
        intermediates!: Array<X509Certificate> = [],
        crls!: Array<X509Crl> = [],
        requireCrlForAllIssuers!: Bool = false,
        requireCrlIfDistributionPointsPresent!: Bool = false,
        requireCrlAuthorityKeyIdentifierMatch!: Bool = false,
        requireAuthorityKeyIdentifierMatch!: Bool = false,
        requiredLeafKeyUsageMask!: Int64 = 0,
        requiredLeafExtendedKeyUsages!: Array<String> = [],
        requiredLeafCertificatePolicies!: Array<String> = [],
        requiredLeafDnsName!: String = "",
        validationTime!: String = "",
        revokedSerialHexLower!: Array<String> = []
    ) {
        if (trustAnchors.size == 0) {
            throw CryptoException(InvalidArgument, "X509 verification requires at least one trust anchor")
        }
        let hasValidationTime = validationTime.size > 0
        if (hasValidationTime) {
            let validationTimeIsValid = isValidX509Time(validationTime)
            if (!validationTimeIsValid) {
                throw CryptoException(InvalidArgument, "validationTime must be UTCTime(YYMMDDHHMMSSZ) or GeneralizedTime(YYYYMMDDHHMMSSZ)")
            }
        }
        if (requiredLeafKeyUsageMask < 0) {
            throw CryptoException(InvalidArgument, "requiredLeafKeyUsageMask must be non-negative")
        }
        let normalizedRequiredLeafDnsName = requiredLeafDnsName.trimAscii().toAsciiLower()

        this.trustAnchors = trustAnchors.clone()
        this.intermediates = intermediates.clone()
        this.crls = crls.clone()
        this.requireCrlForAllIssuers = requireCrlForAllIssuers
        this.requireCrlIfDistributionPointsPresent = requireCrlIfDistributionPointsPresent
        this.requireCrlAuthorityKeyIdentifierMatch = requireCrlAuthorityKeyIdentifierMatch
        this.requireAuthorityKeyIdentifierMatch = requireAuthorityKeyIdentifierMatch
        this.requiredLeafKeyUsageMask = requiredLeafKeyUsageMask
        this.requiredLeafExtendedKeyUsages = normalizeOidList(requiredLeafExtendedKeyUsages)
        this.requiredLeafCertificatePolicies = normalizeOidList(requiredLeafCertificatePolicies)
        this.requiredLeafDnsName = normalizedRequiredLeafDnsName
        this.validationTime = validationTime
        this.revokedSerialHexLower = normalizeHexList(revokedSerialHexLower)
    }
}

public class X509VerificationResult {
    public let chain: Array<X509Certificate>
    public let trustAnchor: X509Certificate

    public init(chain: Array<X509Certificate>, trustAnchor: X509Certificate) {
        if (chain.size == 0) {
            throw CryptoException(InvalidArgument, "verified chain must not be empty")
        }
        this.chain = chain.clone()
        this.trustAnchor = trustAnchor
    }
}

public class X509BasicConstraints {
    public let ca: Bool
    public let pathLenConstraint: ?Int64

    public init(ca: Bool, pathLenConstraint!: ?Int64 = None) {
        if (let Some(pathLen) <- pathLenConstraint) {
            if (pathLen < 0) {
                throw CryptoException(InvalidArgument, "X509 basicConstraints pathLenConstraint must be >= 0")
            }
        }
        this.ca = ca
        this.pathLenConstraint = pathLenConstraint
    }
}

public class X509CrlDistributionPoint {
    public let fullNameUris: Array<String>

    public init(fullNameUris: Array<String>) {
        this.fullNameUris = fullNameUris.clone()
    }
}

public class X509AuthorityKeyIdentifier {
    public let keyIdentifier: ?Array<Byte>

    public init(keyIdentifier!: ?Array<Byte> = None) {
        if (let Some(value) <- keyIdentifier) {
            this.keyIdentifier = Some(value.clone())
            return
        }
        this.keyIdentifier = None
    }
}

/**
 * x509ParseDer.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ParseDer(der: Array<Byte>): X509Certificate {
    let certElem = derReadSingleElement(der, "X509 certificate")
    if (certElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 certificate must be DER SEQUENCE")
    }

    let certReader = DerReader(certElem.value)
    let tbsElem = certReader.readElement("X509 TBSCertificate", expectedTag: DER_TAG_SEQUENCE)
    let sigAlgElem = certReader.readElement("X509 signatureAlgorithm", expectedTag: DER_TAG_SEQUENCE)
    let sigValueElem = certReader.readElement("X509 signatureValue", expectedTag: DER_TAG_BIT_STRING)
    if (certReader.hasRemaining()) {
        throw CryptoException(ParseError, "X509 certificate contains trailing bytes")
    }

    let signatureAlgorithmOid = parseAlgorithmIdentifier(sigAlgElem, "X509 certificate signatureAlgorithm")
    let signatureValue = decodeBitStringValue(sigValueElem.value, "X509 certificate signatureValue")

    let tbsReader = DerReader(tbsElem.value)
    if (tbsReader.hasRemaining()) {
        let nextTag = tbsReader.peekTag()
        if (nextTag == DER_TAG_CONTEXT_0) {
            let versionElem = tbsReader.readElement("X509 version", expectedTag: DER_TAG_CONTEXT_0)
            let versionReader = DerReader(versionElem.value)
            _ = versionReader.readElement("X509 version INTEGER", expectedTag: DER_TAG_INTEGER)
            if (versionReader.hasRemaining()) {
                throw CryptoException(ParseError, "X509 version wrapper contains trailing bytes")
            }
        }
    }

    let serialElem = tbsReader.readElement("X509 serialNumber", expectedTag: DER_TAG_INTEGER)
    let serialNumber = parsePositiveInteger(serialElem.value, "X509 serialNumber")

    _ = tbsReader.readElement("X509 tbs.signature", expectedTag: DER_TAG_SEQUENCE)
    let issuerElem = tbsReader.readElement("X509 issuer", expectedTag: DER_TAG_SEQUENCE)
    let validityElem = tbsReader.readElement("X509 validity", expectedTag: DER_TAG_SEQUENCE)
    let subjectElem = tbsReader.readElement("X509 subject", expectedTag: DER_TAG_SEQUENCE)
    let subjectPublicKeyInfoElem = tbsReader.readElement("X509 subjectPublicKeyInfo", expectedTag: DER_TAG_SEQUENCE)

    var extensions: Array<X509Extension> = []
    while (tbsReader.hasRemaining()) {
        let tag = tbsReader.peekTag()
        if (tag == DER_TAG_CONTEXT_3) {
            let extElem = tbsReader.readElement("X509 extensions", expectedTag: DER_TAG_CONTEXT_3)
            extensions = parseExtensions(extElem.value)
            continue
        }
        if (isContextSpecificTag(tag)) {
            _ = tbsReader.readElement("X509 optional context-specific field")
            continue
        }
        throw CryptoException(ParseError, "X509 TBSCertificate has unsupported field tag: 0x${intToHexLower(tag)}")
    }

    let issuer = parseName(issuerElem)
    let subject = parseName(subjectElem)
    let (notBefore, notAfter) = parseValidity(validityElem.value)

    X509Certificate(
        der,
        tbsElem.encoded,
        serialNumber,
        signatureAlgorithmOid,
        issuer,
        subject,
        notBefore,
        notAfter,
        subjectPublicKeyInfoElem.encoded,
        extensions,
        signatureValue
    )
}

/**
 * x509ParsePem.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ParsePem(pem: String): X509Certificate {
    let certs = x509ParsePemChain(pem)
    if (certs.size != 1) {
        throw CryptoException(ParseError, "PEM text contains multiple certificates; use x509ParsePemChain")
    }
    certs[0]
}

/**
 * x509ParsePemChain.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ParsePemChain(pemBundle: String): Array<X509Certificate> {
    let normalized = pemBundle.replace("\r", "\n")
    let lines = normalized.split('\n')

    let certs = ArrayList<X509Certificate>()
    var collecting = false
    var body = ""

    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed == PEM_CERT_BEGIN) {
            if (collecting) {
                throw CryptoException(ParseError, "nested PEM certificate BEGIN marker")
            }
            collecting = true
            body = ""
            continue
        }
        if (trimmed == PEM_CERT_END) {
            if (!collecting) {
                throw CryptoException(ParseError, "PEM certificate END marker without BEGIN")
            }
            let der = base64Decode(body)
            certs.add(x509ParseDer(der))
            collecting = false
            body = ""
            continue
        }
        if (collecting && trimmed.size > 0) {
            body += trimmed
        }
    }

    if (collecting) {
        throw CryptoException(ParseError, "unterminated PEM certificate block")
    }
    if (certs.size == 0) {
        throw CryptoException(ParseError, "no PEM certificate found")
    }
    certs.toArray()
}

@When[os == "Linux"]
public func x509SystemTrustBundleCandidatePaths(): Array<String> {
    [
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/ca-bundle.pem",
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
        "/etc/ssl/cert.pem"
    ]
}

@When[os == "macOS"]
public func x509SystemTrustBundleCandidatePaths(): Array<String> {
    [
        "/etc/ssl/cert.pem",
        "/opt/homebrew/etc/ca-certificates/cert.pem",
        "/usr/local/etc/ca-certificates/cert.pem",
        "/opt/homebrew/etc/openssl@3/cert.pem",
        "/usr/local/etc/openssl@3/cert.pem"
    ]
}

@When[os == "Windows"]
public func x509SystemTrustBundleCandidatePaths(): Array<String> {
    []
}

@When[os != "Linux" && os != "macOS" && os != "Windows"]
public func x509SystemTrustBundleCandidatePaths(): Array<String> {
    []
}

/**
 * x509LoadSystemTrustAnchors.
 *
 * Loads PEM-bundle trust anchors from common platform paths plus optional
 * caller-supplied bundle paths. Windows Root Store extraction is intentionally
 * not claimed here; Windows callers can pass an exported PEM bundle path until
 * a native store reader lands.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509LoadSystemTrustAnchors(extraPemBundlePaths!: Array<String> = []): Array<X509Certificate> {
    let anchors = ArrayList<X509Certificate>()
    let paths = concatStringArrays(x509SystemTrustBundleCandidatePaths(), extraPemBundlePaths)
    for (path in paths) {
        appendTrustAnchorsFromPemPath(anchors, path)
    }
    anchors.toArray()
}

/**
 * x509CreateSystemTrustPolicy.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509CreateSystemTrustPolicy(
    intermediates!: Array<X509Certificate> = [],
    extraPemBundlePaths!: Array<String> = [],
    requiredLeafDnsName!: String = "",
    validationTime!: String = ""
): X509VerificationPolicy {
    let anchors = x509LoadSystemTrustAnchors(extraPemBundlePaths: extraPemBundlePaths)
    if (anchors.size == 0) {
        throw CryptoException(Unsupported, "no system PEM trust anchor bundle is available")
    }
    X509VerificationPolicy(
        anchors,
        intermediates: intermediates,
        requiredLeafDnsName: requiredLeafDnsName,
        validationTime: validationTime
    )
}

/**
 * x509ParseCrlDer.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ParseCrlDer(der: Array<Byte>): X509Crl {
    let crlElem = derReadSingleElement(der, "X509 CRL")
    if (crlElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 CRL must be DER SEQUENCE")
    }

    let crlReader = DerReader(crlElem.value)
    let tbsElem = crlReader.readElement("X509 CRL tbsCertList", expectedTag: DER_TAG_SEQUENCE)
    let sigAlgElem = crlReader.readElement("X509 CRL signatureAlgorithm", expectedTag: DER_TAG_SEQUENCE)
    let sigValueElem = crlReader.readElement("X509 CRL signatureValue", expectedTag: DER_TAG_BIT_STRING)
    if (crlReader.hasRemaining()) {
        throw CryptoException(ParseError, "X509 CRL contains trailing bytes")
    }

    let outerSigOid = parseAlgorithmIdentifier(sigAlgElem, "X509 CRL signatureAlgorithm")
    let signatureValue = decodeBitStringValue(sigValueElem.value, "X509 CRL signatureValue")

    let tbsReader = DerReader(tbsElem.value)
    if (tbsReader.hasRemaining()) {
        let nextTag = tbsReader.peekTag()
        if (nextTag == DER_TAG_INTEGER) {
            _ = tbsReader.readElement("X509 CRL version", expectedTag: DER_TAG_INTEGER)
        }
    }

    let tbsSigElem = tbsReader.readElement("X509 CRL tbs.signature", expectedTag: DER_TAG_SEQUENCE)
    let tbsSigOid = parseAlgorithmIdentifier(tbsSigElem, "X509 CRL tbs.signature")
    if (tbsSigOid != outerSigOid) {
        throw CryptoException(ParseError, "X509 CRL signature algorithm mismatch between tbs and outer structure")
    }

    let issuerElem = tbsReader.readElement("X509 CRL issuer", expectedTag: DER_TAG_SEQUENCE)
    let thisUpdateElem = tbsReader.readElement("X509 CRL thisUpdate")
    let thisUpdate = decodeTimeValue(thisUpdateElem.tag, thisUpdateElem.value, "X509 CRL thisUpdate")

    var nextUpdate = ""
    if (tbsReader.hasRemaining()) {
        let nextTag = tbsReader.peekTag()
        if (nextTag == DER_TAG_UTC_TIME || nextTag == DER_TAG_GENERALIZED_TIME) {
            let nextUpdateElem = tbsReader.readElement("X509 CRL nextUpdate")
            nextUpdate = decodeTimeValue(nextUpdateElem.tag, nextUpdateElem.value, "X509 CRL nextUpdate")
        }
    }

    var revokedSerials: Array<String> = []
    if (tbsReader.hasRemaining()) {
        let nextTag = tbsReader.peekTag()
        if (nextTag == DER_TAG_SEQUENCE) {
            let revokedElem = tbsReader.readElement("X509 CRL revokedCertificates", expectedTag: DER_TAG_SEQUENCE)
            revokedSerials = parseRevokedCertificates(revokedElem.value)
        }
    }

    var crlExtensions: Array<X509Extension> = []

    while (tbsReader.hasRemaining()) {
        let tag = tbsReader.peekTag()
        if (tag == DER_TAG_CONTEXT_0) {
            let extElem = tbsReader.readElement("X509 CRL extensions", expectedTag: DER_TAG_CONTEXT_0)
            crlExtensions = parseExtensions(extElem.value)
            continue
        }
        if (isContextSpecificTag(tag)) {
            _ = tbsReader.readElement("X509 CRL optional field")
            continue
        }
        throw CryptoException(ParseError, "unsupported X509 CRL field tag: 0x${intToHexLower(tag)}")
    }

    let issuer = parseName(issuerElem)
    let authorityKeyIdentifier = x509DecodeAuthorityKeyIdentifierFromExtensions(crlExtensions)
    X509Crl(
        der,
        tbsElem.encoded,
        outerSigOid,
        issuer,
        thisUpdate,
        nextUpdate,
        revokedSerials,
        signatureValue,
        authorityKeyIdentifier: authorityKeyIdentifier
    )
}

public func x509ParseCrlPem(crlPem: String): X509Crl {
    x509ParseCrlDer(decodeSinglePemBlock(crlPem, "X509 CRL"))
}

/**
 * x509VerifyCrlSignatureWithIssuer.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509VerifyCrlSignatureWithIssuer(
    crl: X509Crl,
    issuer: X509Certificate,
    requireAuthorityKeyIdentifierMatch!: Bool = false
): Unit {
    if (!x509NameDerEquals(crl.issuer, issuer.subject)) {
        throw CryptoException(ParseError, "CRL issuer does not match issuer certificate subject")
    }
    x509RequireCrlAuthorityKeyIdentifierMatch(crl, issuer, requireAuthorityKeyIdentifierMatch)

    let keyUsageExt = x509FindExtension(issuer, X509_OID_KEY_USAGE)
    if (let Some(ext) <- keyUsageExt) {
        let keyUsage = x509DecodeKeyUsageFromExtension(ext)
        if ((keyUsage & X509_KEY_USAGE_CRL_SIGN) == 0) {
            throw CryptoException(ParseError, "issuer certificate keyUsage does not allow CRL signing")
        }
    }

    let oid = crl.signatureAlgorithmOid
    if (
        oid == X509_OID_SHA256_WITH_RSA ||
        oid == X509_OID_SHA384_WITH_RSA ||
        oid == X509_OID_SHA512_WITH_RSA
    ) {
        let issuerKey = decodeRsaPublicKeyFromSpki(issuer.subjectPublicKeyInfoDer)
        let digest = digestForSignatureAlgorithm(oid, crl.tbsDer)
        let hashAlg = rsaHashAlgorithmFromSignatureOid(oid)
        let ok = rsaVerifyPkcs1v15WithHash(issuerKey, digest, crl.signatureValue, hashAlg)
        if (!ok) {
            throw CryptoException(ParseError, "X509 CRL RSA signature verification failed")
        }
        return
    }

    if (
        oid == X509_OID_ECDSA_WITH_SHA256 ||
        oid == X509_OID_ECDSA_WITH_SHA384 ||
        oid == X509_OID_ECDSA_WITH_SHA512
    ) {
        let issuerKey = decodeEcPublicKeyFromSpki(issuer.subjectPublicKeyInfoDer)
        let digest = digestForSignatureAlgorithm(oid, crl.tbsDer)
        let (r, s) = decodeEcdsaSignature(crl.signatureValue)
        let ok = try {
            ecdsaVerify(issuerKey, digest, r, s)
        } catch (_: CryptoException) {
            false
        }
        if (!ok) {
            throw CryptoException(ParseError, "X509 CRL ECDSA signature verification failed")
        }
        return
    }

    throw CryptoException(Unsupported, "unsupported CRL signature algorithm OID: ${oid}")
}

/**
 * x509DerToPem.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DerToPem(der: Array<Byte>): String {
    if (der.size == 0) {
        throw CryptoException(InvalidArgument, "DER data must not be empty")
    }

    let encoded = base64Encode(der)
    let lines = ArrayList<String>()
    var i = 0
    while (i < encoded.size) {
        let end = minI64(encoded.size, i + 64)
        lines.add(encoded[i..end])
        i = end
    }

    var out = "${PEM_CERT_BEGIN}\n"
    var idx = 0
    while (idx < lines.size) {
        out += lines[idx]
        out += "\n"
        idx += 1
    }
    out += "${PEM_CERT_END}\n"
    out
}

public func x509BuildSimpleChain(leaf: X509Certificate, candidates: Array<X509Certificate>): Array<X509Certificate> {
    let chain = ArrayList<X509Certificate>()
    chain.add(leaf)

    var current = leaf
    var hop = 0
    while (!current.isSelfIssued()) {
        if (hop > candidates.size) {
            break
        }
        hop += 1

        let next = findIssuer(current, candidates)
        if (let Some(issuer) <- next) {
            if (containsCertificate(chain, issuer)) {
                break
            }
            chain.add(issuer)
            current = issuer
            continue
        }
        break
    }
    chain.toArray()
}

private func x509BuildTrustedChain(
    leaf: X509Certificate,
    trustAnchors: Array<X509Certificate>,
    intermediates: Array<X509Certificate>
): Array<X509Certificate> {
    let candidates = concatCertificateArrays(intermediates, trustAnchors)
    let chain = ArrayList<X509Certificate>()
    chain.add(leaf)
    if (x509ExtendTrustedChain(chain, candidates, trustAnchors, 0)) {
        return chain.toArray()
    }
    []
}

private func x509ExtendTrustedChain(
    chain: ArrayList<X509Certificate>,
    candidates: Array<X509Certificate>,
    trustAnchors: Array<X509Certificate>,
    depth: Int64
): Bool {
    let current = chain[chain.size - 1]
    if (let Some(_) <- findTrustAnchor(current, trustAnchors)) {
        return true
    }
    if (current.isSelfIssued()) {
        return false
    }
    if (depth > candidates.size) {
        return false
    }

    let issuers = findIssuerCandidates(current, candidates)
    for (issuer in issuers) {
        if (containsCertificate(chain, issuer)) {
            continue
        }
        chain.add(issuer)
        if (x509ExtendTrustedChain(chain, candidates, trustAnchors, depth + 1)) {
            return true
        }
        _ = chain.remove(at: chain.size - 1)
    }
    false
}

public func x509NameFindFirstValue(name: X509Name, oid: String): ?String {
    let expected = oid.trimAscii()
    for (attr in name.attributes) {
        if (attr.oid == expected) {
            return Some(attr.value)
        }
    }
    None
}

public func x509FindExtension(cert: X509Certificate, oid: String): ?X509Extension {
    let expected = oid.trimAscii()
    for (ext in cert.extensions) {
        if (ext.oid == expected) {
            return Some(ext)
        }
    }
    None
}

/**
 * x509DecodeKeyUsageFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeKeyUsageFromExtension(extension: X509Extension): Int64 {
    if (extension.oid != X509_OID_KEY_USAGE) {
        throw CryptoException(InvalidArgument, "extension is not keyUsage")
    }
    x509DecodeKeyUsageBits(extension.value)
}

/**
 * x509DecodeBasicConstraintsFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeBasicConstraintsFromExtension(extension: X509Extension): X509BasicConstraints {
    if (extension.oid != X509_OID_BASIC_CONSTRAINTS) {
        throw CryptoException(InvalidArgument, "extension is not basicConstraints")
    }
    x509DecodeBasicConstraintsBits(extension.value)
}

/**
 * x509DecodeSubjectKeyIdentifierFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeSubjectKeyIdentifierFromExtension(extension: X509Extension): Array<Byte> {
    if (extension.oid != X509_OID_SUBJECT_KEY_IDENTIFIER) {
        throw CryptoException(InvalidArgument, "extension is not subjectKeyIdentifier")
    }
    x509DecodeSubjectKeyIdentifierBits(extension.value)
}

/**
 * x509DecodeAuthorityKeyIdentifierFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeAuthorityKeyIdentifierFromExtension(extension: X509Extension): X509AuthorityKeyIdentifier {
    if (extension.oid != X509_OID_AUTHORITY_KEY_IDENTIFIER) {
        throw CryptoException(InvalidArgument, "extension is not authorityKeyIdentifier")
    }
    x509DecodeAuthorityKeyIdentifierBits(extension.value)
}

/**
 * x509DecodeCrlDistributionPointsFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeCrlDistributionPointsFromExtension(extension: X509Extension): Array<X509CrlDistributionPoint> {
    if (extension.oid != X509_OID_CRL_DISTRIBUTION_POINTS) {
        throw CryptoException(InvalidArgument, "extension is not CRL distribution points")
    }
    x509DecodeCrlDistributionPoints(extension.value)
}

/**
 * x509DecodeExtendedKeyUsageFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeExtendedKeyUsageFromExtension(extension: X509Extension): Array<String> {
    if (extension.oid != X509_OID_EXTENDED_KEY_USAGE) {
        throw CryptoException(InvalidArgument, "extension is not extendedKeyUsage")
    }
    x509DecodeExtendedKeyUsageOids(extension.value)
}

/**
 * x509DecodeSubjectAlternativeNameDnsFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeSubjectAlternativeNameDnsFromExtension(extension: X509Extension): Array<String> {
    if (extension.oid != X509_OID_SUBJECT_ALT_NAME) {
        throw CryptoException(InvalidArgument, "extension is not subjectAltName")
    }
    x509DecodeSubjectAlternativeNameDns(extension.value)
}

/**
 * x509DecodeCertificatePoliciesFromExtension.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeCertificatePoliciesFromExtension(extension: X509Extension): Array<String> {
    if (extension.oid != X509_OID_CERTIFICATE_POLICIES) {
        throw CryptoException(InvalidArgument, "extension is not certificatePolicies")
    }
    x509DecodeCertificatePolicyOids(extension.value)
}

/**
 * x509ExtractCrlDistributionPointUris.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ExtractCrlDistributionPointUris(cert: X509Certificate): Array<String> {
    let ext = x509FindExtension(cert, X509_OID_CRL_DISTRIBUTION_POINTS)
    if (let None <- ext) {
        return []
    }
    if (let Some(value) <- ext) {
        let points = x509DecodeCrlDistributionPointsFromExtension(value)
        if (points.size == 0) {
            return []
        }
        let uris = ArrayList<String>()
        for (point in points) {
            for (uri in point.fullNameUris) {
                uris.add(uri)
            }
        }
        return uris.toArray()
    }
    throw CryptoException(ParseError, "CRL distribution points extension resolution failed")
}

/**
 * x509ExtractExtendedKeyUsageOids.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ExtractExtendedKeyUsageOids(cert: X509Certificate): Array<String> {
    let ext = x509FindExtension(cert, X509_OID_EXTENDED_KEY_USAGE)
    if (let None <- ext) {
        return []
    }
    if (let Some(value) <- ext) {
        return x509DecodeExtendedKeyUsageFromExtension(value)
    }
    throw CryptoException(ParseError, "extendedKeyUsage extension resolution failed")
}

/**
 * x509ExtractSubjectAlternativeDnsNames.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ExtractSubjectAlternativeDnsNames(cert: X509Certificate): Array<String> {
    let ext = x509FindExtension(cert, X509_OID_SUBJECT_ALT_NAME)
    if (let None <- ext) {
        return []
    }
    if (let Some(value) <- ext) {
        return x509DecodeSubjectAlternativeNameDnsFromExtension(value)
    }
    throw CryptoException(ParseError, "subjectAltName extension resolution failed")
}

/**
 * x509ExtractCertificatePolicyOids.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ExtractCertificatePolicyOids(cert: X509Certificate): Array<String> {
    let ext = x509FindExtension(cert, X509_OID_CERTIFICATE_POLICIES)
    if (let None <- ext) {
        return []
    }
    if (let Some(value) <- ext) {
        return x509DecodeCertificatePoliciesFromExtension(value)
    }
    throw CryptoException(ParseError, "certificatePolicies extension resolution failed")
}

/**
 * x509ExtractSubjectKeyIdentifier.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ExtractSubjectKeyIdentifier(cert: X509Certificate): ?Array<Byte> {
    let ext = x509FindExtension(cert, X509_OID_SUBJECT_KEY_IDENTIFIER)
    if (let None <- ext) {
        return None
    }
    if (let Some(value) <- ext) {
        return Some(x509DecodeSubjectKeyIdentifierFromExtension(value))
    }
    throw CryptoException(ParseError, "subjectKeyIdentifier extension resolution failed")
}

/**
 * x509ExtractAuthorityKeyIdentifier.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ExtractAuthorityKeyIdentifier(cert: X509Certificate): ?X509AuthorityKeyIdentifier {
    let ext = x509FindExtension(cert, X509_OID_AUTHORITY_KEY_IDENTIFIER)
    if (let None <- ext) {
        return None
    }
    if (let Some(value) <- ext) {
        return Some(x509DecodeAuthorityKeyIdentifierFromExtension(value))
    }
    throw CryptoException(ParseError, "authorityKeyIdentifier extension resolution failed")
}

/**
 * x509DecodeKeyUsageBits.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeKeyUsageBits(derEncodedBitString: Array<Byte>): Int64 {
    let elem = derReadSingleElement(derEncodedBitString, "X509 keyUsage value")
    if (elem.tag != DER_TAG_BIT_STRING) {
        throw CryptoException(ParseError, "X509 keyUsage value must be DER BIT STRING")
    }

    let payload = elem.value
    if (payload.size == 0) {
        throw CryptoException(ParseError, "X509 keyUsage BIT STRING is empty")
    }
    let unusedBits = Int64(UInt8(payload[0]))
    if (unusedBits < 0 || unusedBits > 7) {
        throw CryptoException(ParseError, "X509 keyUsage unused bits must be 0..7")
    }
    if (payload.size == 1 && unusedBits != 0) {
        throw CryptoException(ParseError, "X509 keyUsage BIT STRING has invalid unused bits")
    }

    let bytes = payload[1..]
    let totalBits = bytes.size * 8 - unusedBits
    if (totalBits < 0) {
        throw CryptoException(ParseError, "X509 keyUsage BIT STRING length is invalid")
    }

    var mask: Int64 = 0
    var bit = 0
    while (bit < totalBits && bit < 62) {
        let byteIndex = bit / 8
        let bitInByte = bit % 8
        let flag = UInt8(UInt32(1) << UInt32(7 - bitInByte))
        if ((UInt8(bytes[byteIndex]) & flag) != UInt8(0)) {
            mask = mask | (Int64(1) << bit)
        }
        bit += 1
    }
    mask
}

/**
 * x509DecodeBasicConstraintsBits.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeBasicConstraintsBits(derEncodedSequence: Array<Byte>): X509BasicConstraints {
    let elem = derReadSingleElement(derEncodedSequence, "X509 basicConstraints value")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 basicConstraints value must be DER SEQUENCE")
    }

    let reader = DerReader(elem.value)
    var ca = false
    var pathLen: ?Int64 = None
    if (reader.hasRemaining()) {
        let nextTag = reader.peekTag()
        if (nextTag == DER_TAG_BOOLEAN) {
            let caElem = reader.readElement("X509 basicConstraints.cA", expectedTag: DER_TAG_BOOLEAN)
            ca = decodeBoolean(caElem.value, "X509 basicConstraints.cA")
        }
    }
    if (reader.hasRemaining()) {
        let nextTag = reader.peekTag()
        if (nextTag == DER_TAG_INTEGER) {
            let pathLenElem = reader.readElement("X509 basicConstraints.pathLenConstraint", expectedTag: DER_TAG_INTEGER)
            pathLen = Some(parseSmallPositiveInteger(pathLenElem.value, "X509 basicConstraints.pathLenConstraint"))
        }
    }
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "X509 basicConstraints has trailing fields")
    }
    X509BasicConstraints(ca, pathLenConstraint: pathLen)
}

/**
 * x509DecodeSubjectKeyIdentifierBits.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeSubjectKeyIdentifierBits(derEncodedOctetString: Array<Byte>): Array<Byte> {
    let elem = derReadSingleElement(derEncodedOctetString, "X509 subjectKeyIdentifier value")
    if (elem.tag != DER_TAG_OCTET_STRING) {
        throw CryptoException(ParseError, "X509 subjectKeyIdentifier value must be DER OCTET STRING")
    }
    if (elem.value.size == 0) {
        throw CryptoException(ParseError, "X509 subjectKeyIdentifier must not be empty")
    }
    elem.value
}

/**
 * x509DecodeAuthorityKeyIdentifierBits.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeAuthorityKeyIdentifierBits(derEncodedSequence: Array<Byte>): X509AuthorityKeyIdentifier {
    let elem = derReadSingleElement(derEncodedSequence, "X509 authorityKeyIdentifier value")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 authorityKeyIdentifier value must be DER SEQUENCE")
    }

    let reader = DerReader(elem.value)
    var keyIdentifier: ?Array<Byte> = None
    while (reader.hasRemaining()) {
        let field = reader.readElement("X509 authorityKeyIdentifier field")
        if (field.tag == 0x80) {
            if (field.value.size == 0) {
                throw CryptoException(ParseError, "X509 authorityKeyIdentifier keyIdentifier must not be empty")
            }
            keyIdentifier = Some(field.value.clone())
            continue
        }
        if (field.tag == DER_TAG_CONTEXT_0) {
            if (field.value.size == 0) {
                throw CryptoException(ParseError, "X509 authorityKeyIdentifier keyIdentifier wrapper is empty")
            }
            let keyElem = derReadSingleElement(field.value, "X509 authorityKeyIdentifier explicit keyIdentifier")
            if (keyElem.tag != DER_TAG_OCTET_STRING) {
                throw CryptoException(ParseError, "X509 authorityKeyIdentifier explicit keyIdentifier must be OCTET STRING")
            }
            if (keyElem.value.size == 0) {
                throw CryptoException(ParseError, "X509 authorityKeyIdentifier explicit keyIdentifier must not be empty")
            }
            keyIdentifier = Some(keyElem.value.clone())
            continue
        }
        if (isContextSpecificTag(field.tag)) {
            continue
        }
        throw CryptoException(ParseError, "unsupported X509 authorityKeyIdentifier field tag: 0x${intToHexLower(field.tag)}")
    }
    X509AuthorityKeyIdentifier(keyIdentifier: keyIdentifier)
}

private func x509DecodeAuthorityKeyIdentifierFromExtensions(extensions: Array<X509Extension>): ?X509AuthorityKeyIdentifier {
    for (ext in extensions) {
        if (ext.oid == X509_OID_AUTHORITY_KEY_IDENTIFIER) {
            return Some(x509DecodeAuthorityKeyIdentifierFromExtension(ext))
        }
    }
    None
}

/**
 * x509DecodeCrlDistributionPoints.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeCrlDistributionPoints(derEncodedSequence: Array<Byte>): Array<X509CrlDistributionPoint> {
    let elem = derReadSingleElement(derEncodedSequence, "X509 CRL distribution points value")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 CRL distribution points value must be DER SEQUENCE")
    }

    let points = ArrayList<X509CrlDistributionPoint>()
    let reader = DerReader(elem.value)
    while (reader.hasRemaining()) {
        let pointElem = reader.readElement("X509 CRL distribution point", expectedTag: DER_TAG_SEQUENCE)
        points.add(parseCrlDistributionPoint(pointElem.value))
    }
    points.toArray()
}

/**
 * x509DecodeExtendedKeyUsageOids.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeExtendedKeyUsageOids(derEncodedSequence: Array<Byte>): Array<String> {
    let elem = derReadSingleElement(derEncodedSequence, "X509 extendedKeyUsage value")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 extendedKeyUsage value must be DER SEQUENCE")
    }
    let out = ArrayList<String>()
    let reader = DerReader(elem.value)
    while (reader.hasRemaining()) {
        let oidElem = reader.readElement("X509 extendedKeyUsage OID", expectedTag: DER_TAG_OID)
        out.add(decodeOid(oidElem.value, "X509 extendedKeyUsage OID"))
    }
    out.toArray()
}

/**
 * x509DecodeSubjectAlternativeNameDns.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeSubjectAlternativeNameDns(derEncodedSequence: Array<Byte>): Array<String> {
    let elem = derReadSingleElement(derEncodedSequence, "X509 subjectAltName value")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 subjectAltName value must be DER SEQUENCE")
    }

    let out = ArrayList<String>()
    let reader = DerReader(elem.value)
    while (reader.hasRemaining()) {
        let nameElem = reader.readElement("X509 subjectAltName GeneralName")
        if (nameElem.tag == 0x82) {
            out.add(decodeAsciiText(nameElem.value, "X509 subjectAltName dNSName").toAsciiLower())
            continue
        }
        if (isContextSpecificTag(nameElem.tag)) {
            continue
        }
        throw CryptoException(ParseError, "unsupported X509 subjectAltName GeneralName tag: 0x${intToHexLower(nameElem.tag)}")
    }
    out.toArray()
}

/**
 * x509DecodeCertificatePolicyOids.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509DecodeCertificatePolicyOids(derEncodedSequence: Array<Byte>): Array<String> {
    let elem = derReadSingleElement(derEncodedSequence, "X509 certificatePolicies value")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "X509 certificatePolicies value must be DER SEQUENCE")
    }

    let out = ArrayList<String>()
    let reader = DerReader(elem.value)
    while (reader.hasRemaining()) {
        let policyInfoElem = reader.readElement("X509 certificatePolicies policyInformation", expectedTag: DER_TAG_SEQUENCE)
        let policyInfoReader = DerReader(policyInfoElem.value)
        let oidElem = policyInfoReader.readElement("X509 certificatePolicies policyIdentifier", expectedTag: DER_TAG_OID)
        out.add(decodeOid(oidElem.value, "X509 certificatePolicies policyIdentifier"))
        while (policyInfoReader.hasRemaining()) {
            _ = policyInfoReader.readElement("X509 certificatePolicies policyQualifierInfo")
        }
    }
    out.toArray()
}

public func x509CreateSelfSignedRsaCertificate(config: X509SelfSignedConfig, privateKey: RsaPrivateKey): X509Certificate {
    let subjectNameDer = encodeCommonName(config.commonName)
    let signatureAlgorithm = encodeAlgorithmIdentifier(X509_OID_SHA256_WITH_RSA)
    let subjectPublicKeyInfo = encodeRsaSubjectPublicKeyInfo(privateKey.publicKey)

    let tbsParts = ArrayList<Byte>()
    appendBytes(tbsParts, derWrap(DER_TAG_CONTEXT_0, encodeIntegerFromInt(2)))
    appendBytes(tbsParts, encodePositiveInteger(config.serialNumber))
    appendBytes(tbsParts, signatureAlgorithm)
    appendBytes(tbsParts, subjectNameDer)
    appendBytes(tbsParts, encodeValidity(config.notBefore, config.notAfter))
    appendBytes(tbsParts, subjectNameDer)
    appendBytes(tbsParts, subjectPublicKeyInfo)

    let extensionsSequence = encodeExtensionsForSelfSigned(config.keyUsageMask)
    if (extensionsSequence.size > 0) {
        appendBytes(tbsParts, derWrap(DER_TAG_CONTEXT_3, extensionsSequence))
    }

    let tbsDer = derWrap(DER_TAG_SEQUENCE, tbsParts.toArray())
    let signature = rsaSignPkcs1v15WithHash(privateKey, sha256(tbsDer), RsaHashAlgorithm.SHA256)

    let certParts = ArrayList<Byte>()
    appendBytes(certParts, tbsDer)
    appendBytes(certParts, signatureAlgorithm)
    appendBytes(certParts, encodeBitString(signature))
    let certDer = derWrap(DER_TAG_SEQUENCE, certParts.toArray())
    x509ParseDer(certDer)
}

public func x509CreateSelfSignedEcCertificate(config: X509SelfSignedConfig, privateKey: EcPrivateKey): X509Certificate {
    let subjectNameDer = encodeCommonName(config.commonName)
    let signatureOid = x509SelfSignedEcSignatureOid(privateKey.curve)
    let signatureAlgorithm = encodeAlgorithmIdentifier(signatureOid, withNullParam: false)
    let subjectPublicKeyInfo = encodeEcSubjectPublicKeyInfo(ecPublicFromPrivateKey(privateKey))

    let tbsParts = ArrayList<Byte>()
    appendBytes(tbsParts, derWrap(DER_TAG_CONTEXT_0, encodeIntegerFromInt(2)))
    appendBytes(tbsParts, encodePositiveInteger(config.serialNumber))
    appendBytes(tbsParts, signatureAlgorithm)
    appendBytes(tbsParts, subjectNameDer)
    appendBytes(tbsParts, encodeValidity(config.notBefore, config.notAfter))
    appendBytes(tbsParts, subjectNameDer)
    appendBytes(tbsParts, subjectPublicKeyInfo)

    let extensionsSequence = encodeExtensionsForSelfSigned(config.keyUsageMask)
    if (extensionsSequence.size > 0) {
        appendBytes(tbsParts, derWrap(DER_TAG_CONTEXT_3, extensionsSequence))
    }

    let tbsDer = derWrap(DER_TAG_SEQUENCE, tbsParts.toArray())
    let digest = digestForSignatureAlgorithm(signatureOid, tbsDer)
    let (r, s) = ecdsaSign(privateKey, digest)
    let signature = encodeEcdsaSignatureDer(r, s)

    let certParts = ArrayList<Byte>()
    appendBytes(certParts, tbsDer)
    appendBytes(certParts, signatureAlgorithm)
    appendBytes(certParts, encodeBitString(signature))
    let certDer = derWrap(DER_TAG_SEQUENCE, certParts.toArray())
    x509ParseDer(certDer)
}

/**
 * x509VerifyCertificateChain.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509VerifyCertificateChain(leaf: X509Certificate, policy: X509VerificationPolicy): X509VerificationResult {
    let chain = x509BuildTrustedChain(leaf, policy.trustAnchors, policy.intermediates)
    if (chain.size == 0) {
        throw CryptoException(ParseError, "X509 chain does not terminate at a trusted anchor")
    }

    let trustAnchor = findTrustAnchor(chain[chain.size - 1], policy.trustAnchors)
    if (let None <- trustAnchor) {
        throw CryptoException(ParseError, "X509 chain does not terminate at a trusted anchor")
    }

    x509RequireLeafUsageConstraints(chain[0], policy)

    let now = policy.validationTime
    var i = 0
    while (i < chain.size) {
        let cert = chain[i]
        if (now.size > 0) {
            x509RequireTimeValidAt(cert, now)
        }
        x509RequireNotRevoked(cert, policy.revokedSerialHexLower)

        if (i + 1 < chain.size) {
            let issuerIndex = i + 1
            let issuer = chain[i + 1]
            x509RequireIssuerNameMatch(cert, issuer)
            x509RequireAuthorityKeyIdentifierMatch(cert, issuer, policy.requireAuthorityKeyIdentifierMatch)
            x509VerifySignatureWithIssuer(cert, issuer)
            let issuerIsTrustAnchor = issuerIndex == chain.size - 1
            let caCertsBelowIssuer = x509CountCaCertificatesBelow(chain, issuerIndex)
            x509RequireIssuerCanSign(issuer, issuerIsTrustAnchor, caCertsBelowIssuer)
            let hasCrlDistributionPoints = x509CertificateHasCrlDistributionPoints(cert)
            let requireCrlForDistributionPoints = policy.requireCrlIfDistributionPointsPresent && hasCrlDistributionPoints
            let requireCrlForCert = policy.requireCrlForAllIssuers || requireCrlForDistributionPoints
            x509RequireNotRevokedByCrl(
                cert,
                issuer,
                policy.crls,
                now,
                requireCrlForCert,
                policy.requireCrlAuthorityKeyIdentifierMatch
            )
        }
        i += 1
    }

    if (let Some(anchor) <- trustAnchor) {
        return X509VerificationResult(chain, anchor)
    }
    throw CryptoException(ParseError, "X509 trust anchor resolution failed")
}

public func x509VerifyCertificateChainWithProfile(
    leaf: X509Certificate,
    policy: X509VerificationPolicy,
    profile: FipsProfile
): X509VerificationResult {
    let result = x509VerifyCertificateChain(leaf, policy)

    for (cert in result.chain) {
        x509RequireSignatureAlgorithmAllowed(cert, profile)
        x509RequirePublicKeyAllowed(cert, profile)
    }
    result
}

/**
 * x509VerifySignatureWithIssuer.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509VerifySignatureWithIssuer(cert: X509Certificate, issuer: X509Certificate): Unit {
    x509RequireIssuerNameMatch(cert, issuer)

    let oid = cert.signatureAlgorithmOid
    if (
        oid == X509_OID_SHA256_WITH_RSA ||
        oid == X509_OID_SHA384_WITH_RSA ||
        oid == X509_OID_SHA512_WITH_RSA
    ) {
        let issuerKey = decodeRsaPublicKeyFromSpki(issuer.subjectPublicKeyInfoDer)
        let digest = digestForSignatureAlgorithm(oid, cert.tbsDer)
        let hashAlg = rsaHashAlgorithmFromSignatureOid(oid)
        let ok = rsaVerifyPkcs1v15WithHash(issuerKey, digest, cert.signatureValue, hashAlg)
        if (!ok) {
            throw CryptoException(ParseError, "X509 RSA signature verification failed")
        }
        return
    }

    if (
        oid == X509_OID_ECDSA_WITH_SHA256 ||
        oid == X509_OID_ECDSA_WITH_SHA384 ||
        oid == X509_OID_ECDSA_WITH_SHA512
    ) {
        let issuerKey = decodeEcPublicKeyFromSpki(issuer.subjectPublicKeyInfoDer)
        let digest = digestForSignatureAlgorithm(oid, cert.tbsDer)
        let (r, s) = decodeEcdsaSignature(cert.signatureValue)
        let ok = try {
            ecdsaVerify(issuerKey, digest, r, s)
        } catch (_: CryptoException) {
            false
        }
        if (!ok) {
            throw CryptoException(ParseError, "X509 ECDSA signature verification failed")
        }
        return
    }

    throw CryptoException(Unsupported, "unsupported certificate signature algorithm OID: ${oid}")
}

/**
 * x509RequireTimeValidAt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509RequireTimeValidAt(cert: X509Certificate, validationTime: String): Unit {
    let now = normalizeTimeForCompare(validationTime)
    let notBefore = normalizeTimeForCompare(cert.notBefore)
    let notAfter = normalizeTimeForCompare(cert.notAfter)

    if (now < notBefore) {
        throw CryptoException(ParseError, "certificate is not yet valid")
    }
    if (now > notAfter) {
        throw CryptoException(ParseError, "certificate is expired")
    }
}

/**
 * x509RequireNotRevoked.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509RequireNotRevoked(cert: X509Certificate, revokedSerialHexLower: Array<String>): Unit {
    if (revokedSerialHexLower.size == 0) {
        return
    }

    let serial = normalizeHex(cert.serialHexLower())
    for (item in revokedSerialHexLower) {
        if (serial == item) {
            throw CryptoException(ParseError, "certificate serial is revoked")
        }
    }
}

private func x509RequireNotRevokedByCrl(
    cert: X509Certificate,
    issuer: X509Certificate,
    crls: Array<X509Crl>,
    validationTime: String,
    requireCrlForIssuer: Bool,
    requireCrlAuthorityKeyIdentifierMatch: Bool
): Unit {
    if (crls.size == 0) {
        if (requireCrlForIssuer) {
            throw CryptoException(ParseError, "CRL is required but CRL list is empty")
        }
        return
    }

    let matchedCrl = x509FindCrlForIssuer(issuer, crls)
    if (let None <- matchedCrl) {
        if (requireCrlForIssuer) {
            throw CryptoException(ParseError, "CRL is required but no matching CRL exists for issuer")
        }
        return
    }

    if (let Some(crl) <- matchedCrl) {
        x509VerifyCrlSignatureWithIssuer(
            crl,
            issuer,
            requireAuthorityKeyIdentifierMatch: requireCrlAuthorityKeyIdentifierMatch
        )
        if (validationTime.size > 0) {
            x509RequireCrlCurrentAt(crl, validationTime)
        }

        let serial = normalizeHex(cert.serialHexLower())
        for (revoked in crl.revokedSerialHexLower) {
            if (revoked == serial) {
                throw CryptoException(ParseError, "certificate serial is revoked by CRL")
            }
        }
        return
    }

    throw CryptoException(ParseError, "CRL resolution failed")
}

public func x509ExtractRsaPublicKey(cert: X509Certificate): RsaPublicKey {
    decodeRsaPublicKeyFromSpki(cert.subjectPublicKeyInfoDer)
}

public func x509ExtractEcPublicKey(cert: X509Certificate): EcPublicKey {
    decodeEcPublicKeyFromSpki(cert.subjectPublicKeyInfoDer)
}

public func x509ParseRsaPrivateKeyPkcs1Der(pkcs1Der: Array<Byte>): RsaPrivateKey {
    decodeRsaPrivateKeyPkcs1(pkcs1Der)
}

public func x509ParseRsaPrivateKeyPkcs1Pem(pkcs1Pem: String): RsaPrivateKey {
    x509ParseRsaPrivateKeyPkcs1Der(decodeSinglePemBlock(pkcs1Pem, "RSA PRIVATE KEY"))
}

/**
 * x509ParseRsaPrivateKeyPkcs8Der.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ParseRsaPrivateKeyPkcs8Der(pkcs8Der: Array<Byte>): RsaPrivateKey {
    let (algorithmOid, curveOid, privateKeyDer) = decodePkcs8PrivateKeyInfo(pkcs8Der)
    if (algorithmOid != X509_OID_RSA_ENCRYPTION) {
        throw CryptoException(ParseError, "PKCS8 key algorithm is not RSA")
    }
    if (curveOid.size > 0) {
        throw CryptoException(ParseError, "RSA PKCS8 parameters should not contain curve OID")
    }
    decodeRsaPrivateKeyPkcs1(privateKeyDer)
}

public func x509ParseRsaPrivateKeyPkcs8Pem(pkcs8Pem: String): RsaPrivateKey {
    x509ParseRsaPrivateKeyPkcs8Der(decodeSinglePemBlock(pkcs8Pem, "PRIVATE KEY"))
}

/**
 * x509ParseEcPrivateKeyPkcs8Der.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x509ParseEcPrivateKeyPkcs8Der(pkcs8Der: Array<Byte>): EcPrivateKey {
    let (algorithmOid, curveOid, privateKeyDer) = decodePkcs8PrivateKeyInfo(pkcs8Der)
    if (algorithmOid != X509_OID_EC_PUBLIC_KEY) {
        throw CryptoException(ParseError, "PKCS8 key algorithm is not EC")
    }
    if (curveOid.size == 0) {
        throw CryptoException(ParseError, "EC PKCS8 requires namedCurve OID parameter")
    }
    let curve = curveFromNamedCurveOid(curveOid)
    decodeEcPrivateKeySec1(privateKeyDer, curve)
}

public func x509ParseEcPrivateKeyPkcs8Pem(pkcs8Pem: String): EcPrivateKey {
    x509ParseEcPrivateKeyPkcs8Der(decodeSinglePemBlock(pkcs8Pem, "PRIVATE KEY"))
}

public func x509NameDerEquals(left: X509Name, right: X509Name): Bool {
    bytesEqual(left.der, right.der)
}

private class DerElement {
    let tag: Int64
    let value: Array<Byte>
    let encoded: Array<Byte>

    init(tag: Int64, value: Array<Byte>, encoded: Array<Byte>) {
        this.tag = tag
        this.value = value
        this.encoded = encoded
    }
}

private class DerReader {
    let _bytes: Array<Byte>
    var _offset: Int64 = 0

    init(bytes: Array<Byte>) {
        this._bytes = bytes.clone()
    }

    func hasRemaining(): Bool {
        _offset < _bytes.size
    }

    func peekTag(): Int64 {
        if (_offset >= _bytes.size) {
            throw CryptoException(ParseError, "DER reader has no remaining bytes")
        }
        Int64(UInt8(_bytes[_offset]))
    }

    func readElement(label: String, expectedTag!: Int64 = -1): DerElement {
        if (_offset >= _bytes.size) {
            throw CryptoException(ParseError, "${label} is truncated")
        }

        let start = _offset
        let tagByte = UInt8(_bytes[_offset])
        if ((tagByte & UInt8(0x1f)) == UInt8(0x1f)) {
            throw CryptoException(ParseError, "${label} uses unsupported high-tag-number form")
        }
        _offset += 1

        let (valueLen, lenBytes) = derDecodeLength(_bytes, _offset, label)
        _offset += lenBytes

        if (valueLen < 0 || _offset + valueLen > _bytes.size) {
            throw CryptoException(ParseError, "${label} length exceeds input bounds")
        }

        let end = _offset + valueLen
        let value = _bytes[_offset..end]
        let encoded = _bytes[start..end]
        _offset = end

        let tag = Int64(tagByte)
        if (expectedTag >= 0 && tag != expectedTag) {
            throw CryptoException(ParseError, "${label} tag mismatch, expected=0x${intToHexLower(expectedTag)}, actual=0x${intToHexLower(tag)}")
        }

        DerElement(tag, value, encoded)
    }
}

private func derReadSingleElement(bytes: Array<Byte>, label: String): DerElement {
    let reader = DerReader(bytes)
    let elem = reader.readElement(label)
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "${label} contains trailing bytes")
    }
    elem
}

private func parseAlgorithmIdentifier(element: DerElement, label: String): String {
    let reader = DerReader(element.value)
    let oidElem = reader.readElement("${label} OID", expectedTag: DER_TAG_OID)
    let oid = decodeOid(oidElem.value, "${label} OID")
    while (reader.hasRemaining()) {
        _ = reader.readElement("${label} parameter")
    }
    oid
}

private func decodeBitStringValue(payload: Array<Byte>, label: String): Array<Byte> {
    if (payload.size == 0) {
        throw CryptoException(ParseError, "${label} BIT STRING payload is empty")
    }
    let unusedBits = Int64(UInt8(payload[0]))
    if (unusedBits < 0 || unusedBits > 7) {
        throw CryptoException(ParseError, "${label} BIT STRING unused bits must be 0..7")
    }
    if (unusedBits != 0) {
        throw CryptoException(ParseError, "${label} BIT STRING with non-zero unused bits is not supported")
    }
    payload[1..]
}

private func parsePositiveInteger(encoded: Array<Byte>, label: String): Array<Byte> {
    if (encoded.size == 0) {
        throw CryptoException(ParseError, "${label} INTEGER is empty")
    }

    let isNegative = (UInt8(encoded[0]) & UInt8(0x80)) != UInt8(0)
    if (isNegative) {
        throw CryptoException(ParseError, "${label} INTEGER must be non-negative")
    }

    let trimmed = trimLeadingZeroBytes(encoded)
    if (trimmed.size == 0) {
        return [UInt8(0)]
    }
    trimmed
}

private func parseName(element: DerElement): X509Name {
    let attrs = ArrayList<X509NameAttribute>()
    let nameReader = DerReader(element.value)
    while (nameReader.hasRemaining()) {
        let setElem = nameReader.readElement("X509 RDN", expectedTag: DER_TAG_SET)
        let setReader = DerReader(setElem.value)
        while (setReader.hasRemaining()) {
            let atvElem = setReader.readElement("X509 AttributeTypeAndValue", expectedTag: DER_TAG_SEQUENCE)
            let atvReader = DerReader(atvElem.value)
            let oidElem = atvReader.readElement("X509 attribute OID", expectedTag: DER_TAG_OID)
            let valueElem = atvReader.readElement("X509 attribute value")
            if (atvReader.hasRemaining()) {
                throw CryptoException(ParseError, "X509 AttributeTypeAndValue has trailing bytes")
            }

            let oid = decodeOid(oidElem.value, "X509 attribute OID")
            let value = decodeAttributeValue(valueElem.tag, valueElem.value)
            attrs.add(X509NameAttribute(oid, value))
        }
    }
    X509Name(attrs.toArray(), element.encoded)
}

private func parseValidity(encoded: Array<Byte>): (String, String) {
    let reader = DerReader(encoded)
    let notBeforeElem = reader.readElement("X509 validity.notBefore")
    let notAfterElem = reader.readElement("X509 validity.notAfter")
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "X509 validity contains trailing bytes")
    }

    let notBefore = decodeTimeValue(notBeforeElem.tag, notBeforeElem.value, "X509 validity.notBefore")
    let notAfter = decodeTimeValue(notAfterElem.tag, notAfterElem.value, "X509 validity.notAfter")
    (notBefore, notAfter)
}

private func parseExtensions(explicitValue: Array<Byte>): Array<X509Extension> {
    if (explicitValue.size == 0) {
        return []
    }

    let wrapperReader = DerReader(explicitValue)
    let seqElem = wrapperReader.readElement("X509 extensions sequence", expectedTag: DER_TAG_SEQUENCE)
    if (wrapperReader.hasRemaining()) {
        throw CryptoException(ParseError, "X509 extensions explicit wrapper has trailing bytes")
    }

    let extensions = ArrayList<X509Extension>()
    let reader = DerReader(seqElem.value)
    while (reader.hasRemaining()) {
        let extElem = reader.readElement("X509 extension", expectedTag: DER_TAG_SEQUENCE)
        let extReader = DerReader(extElem.value)

        let oidElem = extReader.readElement("X509 extension OID", expectedTag: DER_TAG_OID)
        let oid = decodeOid(oidElem.value, "X509 extension OID")

        var critical = false
        if (extReader.hasRemaining()) {
            let nextTag = extReader.peekTag()
            if (nextTag == DER_TAG_BOOLEAN) {
                let criticalElem = extReader.readElement("X509 extension critical", expectedTag: DER_TAG_BOOLEAN)
                critical = decodeBoolean(criticalElem.value, "X509 extension critical")
            }
        }

        let valueElem = extReader.readElement("X509 extension value", expectedTag: DER_TAG_OCTET_STRING)
        if (extReader.hasRemaining()) {
            throw CryptoException(ParseError, "X509 extension has trailing bytes")
        }
        extensions.add(X509Extension(oid, critical, valueElem.value))
    }
    extensions.toArray()
}

private func parseRevokedCertificates(encoded: Array<Byte>): Array<String> {
    if (encoded.size == 0) {
        return []
    }

    let serials = ArrayList<String>()
    let reader = DerReader(encoded)
    while (reader.hasRemaining()) {
        let entryElem = reader.readElement("X509 CRL revoked certificate entry", expectedTag: DER_TAG_SEQUENCE)
        let entryReader = DerReader(entryElem.value)
        let serialElem = entryReader.readElement("X509 CRL revoked certificate serial", expectedTag: DER_TAG_INTEGER)
        let serial = parsePositiveInteger(serialElem.value, "X509 CRL revoked certificate serial")
        serials.add(normalizeHex(bytesToHexLower(serial)))

        let revocationDateElem = entryReader.readElement("X509 CRL revocationDate")
        _ = decodeTimeValue(revocationDateElem.tag, revocationDateElem.value, "X509 CRL revocationDate")

        while (entryReader.hasRemaining()) {
            _ = entryReader.readElement("X509 CRL revoked certificate extension")
        }
    }
    serials.toArray()
}

private func parseCrlDistributionPoint(encoded: Array<Byte>): X509CrlDistributionPoint {
    let reader = DerReader(encoded)
    var fullNameUris: Array<String> = []
    while (reader.hasRemaining()) {
        let tag = reader.peekTag()
        if (tag == DER_TAG_CONTEXT_0) {
            let distributionPointElem = reader.readElement("X509 CRL distributionPoint", expectedTag: DER_TAG_CONTEXT_0)
            fullNameUris = parseDistributionPointNameUris(distributionPointElem.value)
            continue
        }
        if (isContextSpecificTag(tag)) {
            _ = reader.readElement("X509 CRL distributionPoint optional field")
            continue
        }
        throw CryptoException(ParseError, "unsupported X509 CRL distributionPoint field tag: 0x${intToHexLower(tag)}")
    }
    X509CrlDistributionPoint(fullNameUris)
}

private func parseDistributionPointNameUris(encoded: Array<Byte>): Array<String> {
    if (encoded.size == 0) {
        return []
    }
    let reader = DerReader(encoded)
    let nameElem = reader.readElement("X509 CRL distributionPointName choice")
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "X509 CRL distributionPointName has trailing bytes")
    }
    if (nameElem.tag == DER_TAG_CONTEXT_0) {
        return parseGeneralNameUris(nameElem.value)
    }
    if (nameElem.tag == DER_TAG_CONTEXT_1) {
        return []
    }
    throw CryptoException(ParseError, "unsupported X509 CRL distributionPointName tag: 0x${intToHexLower(nameElem.tag)}")
}

private func parseGeneralNameUris(encoded: Array<Byte>): Array<String> {
    if (encoded.size == 0) {
        return []
    }

    var generalNames = encoded
    if (Int64(UInt8(generalNames[0])) == DER_TAG_SEQUENCE) {
        let wrapper = derReadSingleElement(generalNames, "X509 CRL fullName GeneralNames")
        if (wrapper.tag != DER_TAG_SEQUENCE) {
            throw CryptoException(ParseError, "X509 CRL fullName must decode to SEQUENCE")
        }
        generalNames = wrapper.value
    }

    let out = ArrayList<String>()
    let reader = DerReader(generalNames)
    while (reader.hasRemaining()) {
        let nameElem = reader.readElement("X509 CRL GeneralName")
        if (nameElem.tag == DER_TAG_CONTEXT_6_PRIMITIVE) {
            out.add(decodeAsciiText(nameElem.value, "X509 CRL URI generalName"))
            continue
        }
        if (isContextSpecificTag(nameElem.tag)) {
            continue
        }
        throw CryptoException(ParseError, "unsupported X509 CRL GeneralName tag: 0x${intToHexLower(nameElem.tag)}")
    }
    out.toArray()
}

private func decodeAsciiText(encoded: Array<Byte>, label: String): String {
    for (ch in encoded) {
        if (UInt8(ch) > UInt8(0x7f)) {
            throw CryptoException(ParseError, "${label} must be ASCII")
        }
    }
    try {
        String.fromUtf8(encoded)
    } catch (_: Exception) {
        throw CryptoException(ParseError, "${label} is not valid text")
    }
}

private func decodeBoolean(encoded: Array<Byte>, label: String): Bool {
    if (encoded.size != 1) {
        throw CryptoException(ParseError, "${label} BOOLEAN length must be 1")
    }
    UInt8(encoded[0]) != UInt8(0)
}

private func decodeTimeValue(tag: Int64, encoded: Array<Byte>, label: String): String {
    if (tag != DER_TAG_UTC_TIME && tag != DER_TAG_GENERALIZED_TIME) {
        throw CryptoException(ParseError, "${label} must be UTCTime or GeneralizedTime")
    }

    let text = try {
        String.fromUtf8(encoded)
    } catch (_: Exception) {
        throw CryptoException(ParseError, "${label} is not valid UTF-8")
    }

    if (!isValidX509Time(text)) {
        throw CryptoException(ParseError, "${label} has invalid format")
    }
    text
}

private func decodeAttributeValue(tag: Int64, encoded: Array<Byte>): String {
    if (
        tag == DER_TAG_UTF8_STRING ||
        tag == DER_TAG_PRINTABLE_STRING ||
        tag == DER_TAG_T61_STRING ||
        tag == DER_TAG_IA5_STRING
    ) {
        return try {
            String.fromUtf8(encoded)
        } catch (_: Exception) {
            "0x${bytesToHexLower(encoded)}"
        }
    }

    if (tag == DER_TAG_BMP_STRING) {
        if ((encoded.size % 2) != 0) {
            return "0x${bytesToHexLower(encoded)}"
        }
        let out = ArrayList<Byte>()
        var i = 0
        while (i < encoded.size) {
            let hi = UInt8(encoded[i])
            let lo = UInt8(encoded[i + 1])
            if (hi != UInt8(0)) {
                return "0x${bytesToHexLower(encoded)}"
            }
            out.add(lo)
            i += 2
        }
        return try {
            String.fromUtf8(out.toArray())
        } catch (_: Exception) {
            "0x${bytesToHexLower(encoded)}"
        }
    }

    "0x${bytesToHexLower(encoded)}"
}

private func encodeCommonName(commonName: String): Array<Byte> {
    let oid = derWrap(DER_TAG_OID, encodeOid(X509_OID_COMMON_NAME))
    let value = derWrap(DER_TAG_UTF8_STRING, commonName.toArray())

    let atv = derWrap(DER_TAG_SEQUENCE, concatBytes(oid, value))
    let rdn = derWrap(DER_TAG_SET, atv)
    derWrap(DER_TAG_SEQUENCE, rdn)
}

private func encodeValidity(notBefore: String, notAfter: String): Array<Byte> {
    let nb = encodeTime(notBefore)
    let na = encodeTime(notAfter)
    derWrap(DER_TAG_SEQUENCE, concatBytes(nb, na))
}

private func encodeTime(text: String): Array<Byte> {
    if (isUtcTime(text)) {
        return derWrap(DER_TAG_UTC_TIME, text.toArray())
    }
    if (isGeneralizedTime(text)) {
        return derWrap(DER_TAG_GENERALIZED_TIME, text.toArray())
    }
    throw CryptoException(InvalidArgument, "invalid X509 time format: ${text}")
}

private func encodeAlgorithmIdentifier(oid: String, withNullParam!: Bool = true): Array<Byte> {
    let list = ArrayList<Byte>()
    appendBytes(list, derWrap(DER_TAG_OID, encodeOid(oid)))
    if (withNullParam) {
        appendBytes(list, derWrap(DER_TAG_NULL, []))
    }
    derWrap(DER_TAG_SEQUENCE, list.toArray())
}

private func encodeRsaSubjectPublicKeyInfo(publicKey: RsaPublicKey): Array<Byte> {
    let rsaKey = encodeRsaPublicKey(publicKey)
    let spk = encodeBitString(rsaKey)

    let list = ArrayList<Byte>()
    appendBytes(list, encodeAlgorithmIdentifier(X509_OID_RSA_ENCRYPTION))
    appendBytes(list, spk)
    derWrap(DER_TAG_SEQUENCE, list.toArray())
}

private func encodeEcSubjectPublicKeyInfo(publicKey: EcPublicKey): Array<Byte> {
    let fieldLen = fieldByteLengthForCurve(publicKey.curve)
    let point = Array<Byte>(1 + fieldLen * 2, repeat: 0)
    point[0] = UInt8(0x04)
    let x = publicKey.x.toBytesBE(paddedLen: fieldLen)
    let y = publicKey.y.toBytesBE(paddedLen: fieldLen)
    secureCopyInto(x, point, dstOffset: 1)
    secureCopyInto(y, point, dstOffset: 1 + fieldLen)

    let algIdentifier = encodeEcPublicKeyAlgorithmIdentifier(publicKey.curve)
    let spk = encodeBitString(point)

    let list = ArrayList<Byte>()
    appendBytes(list, algIdentifier)
    appendBytes(list, spk)
    derWrap(DER_TAG_SEQUENCE, list.toArray())
}

private func encodeEcPublicKeyAlgorithmIdentifier(curve: NamedCurve): Array<Byte> {
    let list = ArrayList<Byte>()
    appendBytes(list, derWrap(DER_TAG_OID, encodeOid(X509_OID_EC_PUBLIC_KEY)))
    appendBytes(list, derWrap(DER_TAG_OID, encodeOid(namedCurveOid(curve))))
    derWrap(DER_TAG_SEQUENCE, list.toArray())
}

private func x509SelfSignedEcSignatureOid(curve: NamedCurve): String {
    match (curve) {
        case P256 | SECP256K1 => X509_OID_ECDSA_WITH_SHA256
        case P384 => X509_OID_ECDSA_WITH_SHA384
        case P521 => X509_OID_ECDSA_WITH_SHA512
    }
}

private func encodeRsaPublicKey(publicKey: RsaPublicKey): Array<Byte> {
    let modulus = encodePositiveInteger(publicKey.modulus.toBytesBE())
    let exponent = encodePositiveInteger(publicKey.exponent.toBytesBE())
    derWrap(DER_TAG_SEQUENCE, concatBytes(modulus, exponent))
}

private func encodeExtensionsForSelfSigned(keyUsageMask: Int64): Array<Byte> {
    if (keyUsageMask == 0) {
        return []
    }
    let ext = encodeKeyUsageExtension(keyUsageMask)
    derWrap(DER_TAG_SEQUENCE, ext)
}

private func encodeKeyUsageExtension(mask: Int64): Array<Byte> {
    if (mask < 0) {
        throw CryptoException(InvalidArgument, "keyUsage mask must be non-negative")
    }
    let keyUsageBitStringDer = encodeKeyUsageBitString(mask)

    let list = ArrayList<Byte>()
    appendBytes(list, derWrap(DER_TAG_OID, encodeOid(X509_OID_KEY_USAGE)))
    appendBytes(list, derWrap(DER_TAG_BOOLEAN, [UInt8(0xff)]))
    appendBytes(list, derWrap(DER_TAG_OCTET_STRING, keyUsageBitStringDer))
    derWrap(DER_TAG_SEQUENCE, list.toArray())
}

private func encodeKeyUsageBitString(mask: Int64): Array<Byte> {
    var highestBit = Int64(-1)
    var bit = 0
    while (bit <= 61) {
        if ((mask & (Int64(1) << bit)) != 0) {
            highestBit = bit
        }
        bit += 1
    }

    if (highestBit < 0) {
        return encodeBitString([])
    }

    let byteLen = highestBit / 8 + 1
    let bits = Array<Byte>(byteLen, repeat: 0)
    bit = 0
    while (bit <= highestBit) {
        if ((mask & (Int64(1) << bit)) != 0) {
            let byteIndex = bit / 8
            let bitInByte = bit % 8
            let flag = UInt8(UInt32(1) << UInt32(7 - bitInByte))
            bits[byteIndex] = UInt8(bits[byteIndex]) | flag
        }
        bit += 1
    }

    let unusedBits = byteLen * 8 - (highestBit + 1)
    encodeBitString(bits, unusedBits: unusedBits)
}

private func encodeBitString(data: Array<Byte>, unusedBits!: Int64 = 0): Array<Byte> {
    if (unusedBits < 0 || unusedBits > 7) {
        throw CryptoException(InvalidArgument, "BIT STRING unused bits must be 0..7")
    }
    let payload = Array<Byte>(data.size + 1, repeat: 0)
    payload[0] = UInt8(unusedBits)
    secureCopyInto(data, payload, dstOffset: 1)
    derWrap(DER_TAG_BIT_STRING, payload)
}

private func encodePositiveInteger(raw: Array<Byte>): Array<Byte> {
    let magnitude = trimLeadingZeroBytes(raw)
    if (magnitude.size == 0) {
        return derWrap(DER_TAG_INTEGER, [UInt8(0)])
    }

    if ((UInt8(magnitude[0]) & UInt8(0x80)) != UInt8(0)) {
        let withPad = Array<Byte>(magnitude.size + 1, repeat: 0)
        withPad[0] = UInt8(0x00)
        secureCopyInto(magnitude, withPad, dstOffset: 1)
        return derWrap(DER_TAG_INTEGER, withPad)
    }
    derWrap(DER_TAG_INTEGER, magnitude)
}

private func encodeIntegerFromInt(value: Int64): Array<Byte> {
    if (value < 0) {
        throw CryptoException(InvalidArgument, "DER INTEGER helper supports only non-negative values")
    }
    if (value == 0) {
        return derWrap(DER_TAG_INTEGER, [UInt8(0x00)])
    }

    let tmp = ArrayList<Byte>()
    var x = value
    while (x > 0) {
        tmp.add(UInt8(x & 0xff))
        x >>= 8
    }
    let bytes = Array<Byte>(tmp.size, repeat: 0)
    var i = 0
    while (i < tmp.size) {
        bytes[i] = tmp[tmp.size - 1 - i]
        i += 1
    }
    encodePositiveInteger(bytes)
}

private func derWrap(tag: Int64, value: Array<Byte>): Array<Byte> {
    let len = encodeDerLength(value.size)
    let out = Array<Byte>(1 + len.size + value.size, repeat: 0)
    out[0] = UInt8(tag)
    secureCopyInto(len, out, dstOffset: 1)
    secureCopyInto(value, out, dstOffset: 1 + len.size)
    out
}

private func derDecodeLength(bytes: Array<Byte>, offset: Int64, label: String): (Int64, Int64) {
    if (offset >= bytes.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    let first = UInt8(bytes[offset])
    if ((first & UInt8(0x80)) == UInt8(0)) {
        return (Int64(first), 1)
    }

    let width = Int64(first & UInt8(0x7f))
    if (width == 0) {
        throw CryptoException(ParseError, "${label} DER length uses indefinite form")
    }
    if (width > 4) {
        throw CryptoException(ParseError, "${label} DER length width is too large")
    }
    if (offset + 1 + width > bytes.size) {
        throw CryptoException(ParseError, "${label} DER length is truncated")
    }

    var length: Int64 = 0
    var i = 0
    while (i < width) {
        length = (length << 8) | Int64(UInt8(bytes[offset + 1 + i]))
        i += 1
    }
    if (length < 0) {
        throw CryptoException(ParseError, "${label} DER length is negative")
    }
    if (length < 128) {
        throw CryptoException(ParseError, "${label} DER length uses non-minimal long form")
    }
    (length, 1 + width)
}

private func encodeDerLength(length: Int64): Array<Byte> {
    if (length < 0) {
        throw CryptoException(OutOfBounds, "DER length must be non-negative")
    }
    if (length < 128) {
        return [UInt8(length)]
    }

    let tmp = ArrayList<Byte>()
    var x = length
    while (x > 0) {
        tmp.add(UInt8(x & 0xff))
        x >>= 8
    }
    if (tmp.size > 4) {
        throw CryptoException(OutOfBounds, "DER length exceeds 4-byte support limit")
    }

    let out = Array<Byte>(1 + tmp.size, repeat: 0)
    out[0] = UInt8(0x80 | UInt8(tmp.size))
    var i = 0
    while (i < tmp.size) {
        out[1 + i] = tmp[tmp.size - 1 - i]
        i += 1
    }
    out
}

private func decodeOid(encoded: Array<Byte>, label: String): String {
    if (encoded.size == 0) {
        throw CryptoException(ParseError, "${label} OID is empty")
    }

    let firstByte = Int64(UInt8(encoded[0]))
    var first = firstByte / 40
    var second = firstByte % 40
    if (first > 2) {
        second = second + (first - 2) * 40
        first = 2
    }

    let nodes = ArrayList<String>()
    nodes.add(first.toString())
    nodes.add(second.toString())

    var value: Int64 = 0
    var open = false
    var i = 1
    while (i < encoded.size) {
        let b = Int64(UInt8(encoded[i]))
        value = (value << 7) | (b & 0x7f)
        open = true
        if ((b & 0x80) == 0) {
            nodes.add(value.toString())
            value = 0
            open = false
        }
        i += 1
    }
    if (open) {
        throw CryptoException(ParseError, "${label} OID has unterminated base-128 node")
    }

    var out = nodes[0]
    i = 1
    while (i < nodes.size) {
        out += ".${nodes[i]}"
        i += 1
    }
    out
}

private func encodeOid(oid: String): Array<Byte> {
    let parts = oid.trimAscii().split('.', removeEmpty: true)
    if (parts.size < 2) {
        throw CryptoException(InvalidArgument, "OID must have at least two nodes")
    }

    let first = parseDecimal(parts[0], "OID first node")
    let second = parseDecimal(parts[1], "OID second node")
    if (first < 0 || first > 2) {
        throw CryptoException(InvalidArgument, "OID first node must be 0..2")
    }
    if (first < 2 && second >= 40) {
        throw CryptoException(InvalidArgument, "OID second node must be < 40 when first node is 0 or 1")
    }

    let out = ArrayList<Byte>()
    out.add(UInt8(first * 40 + second))

    var idx = 2
    while (idx < parts.size) {
        let node = parseDecimal(parts[idx], "OID node")
        if (node < 0) {
            throw CryptoException(InvalidArgument, "OID node must be non-negative")
        }
        appendBase128Node(out, node)
        idx += 1
    }
    out.toArray()
}

private func appendBase128Node(out: ArrayList<Byte>, node: Int64): Unit {
    let tmp = ArrayList<Byte>()
    var value = node
    tmp.add(UInt8(value & 0x7f))
    value >>= 7
    while (value > 0) {
        tmp.add(UInt8(value & 0x7f))
        value >>= 7
    }

    var i = tmp.size - 1
    while (i >= 0) {
        let base = UInt8(tmp[i])
        if (i != 0) {
            out.add(base | UInt8(0x80))
        } else {
            out.add(base)
        }
        i -= 1
    }
}

private func parseDecimal(text: String, label: String): Int64 {
    let s = text.trimAscii()
    if (s.size == 0) {
        throw CryptoException(InvalidArgument, "${label} must not be empty")
    }
    var value: Int64 = 0
    for (ch in s.toArray()) {
        if (ch < b'0' || ch > b'9') {
            throw CryptoException(InvalidArgument, "${label} is not a decimal integer")
        }
        value = value * 10 + Int64(ch - b'0')
    }
    value
}

private func decodeSinglePemBlock(pemText: String, blockType: String): Array<Byte> {
    let beginMarker = "-----BEGIN ${blockType}-----"
    let endMarker = "-----END ${blockType}-----"
    let normalized = pemText.replace("\r", "\n")
    let lines = normalized.split('\n')

    var collecting = false
    var body = ""
    var seenBlocks = 0

    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed == beginMarker) {
            if (collecting) {
                throw CryptoException(ParseError, "nested PEM block BEGIN for ${blockType}")
            }
            collecting = true
            body = ""
            continue
        }
        if (trimmed == endMarker) {
            if (!collecting) {
                throw CryptoException(ParseError, "PEM END marker without BEGIN for ${blockType}")
            }
            collecting = false
            seenBlocks += 1
            continue
        }
        if (collecting && trimmed.size > 0) {
            body += trimmed
        }
    }

    if (collecting) {
        throw CryptoException(ParseError, "unterminated PEM block for ${blockType}")
    }
    if (seenBlocks != 1) {
        throw CryptoException(ParseError, "expected exactly one PEM block for ${blockType}")
    }
    base64Decode(body)
}

private func base64Decode(text: String): Array<Byte> {
    let clean = stripAsciiWhitespace(text)
    if (clean.size == 0) {
        return []
    }
    if ((clean.size % 4) != 0) {
        throw CryptoException(ParseError, "base64 text length must be multiple of 4")
    }

    let padChars = countBase64Padding(clean)
    let outLen = clean.size / 4 * 3 - padChars
    if (outLen < 0) {
        throw CryptoException(ParseError, "invalid base64 padding length")
    }

    let out = Array<Byte>(outLen, repeat: 0)
    var src = 0
    var dst = 0
    while (src < clean.size) {
        let c0 = base64DecodeChar(clean[src], false)
        let c1 = base64DecodeChar(clean[src + 1], false)
        let c2 = base64DecodeChar(clean[src + 2], true)
        let c3 = base64DecodeChar(clean[src + 3], true)

        let v0 = UInt32(c0)
        let v1 = UInt32(c1)
        let v2 = UInt32(maxI64(c2, 0))
        let v3 = UInt32(maxI64(c3, 0))
        let word = (v0 << 18) | (v1 << 12) | (v2 << 6) | v3

        if (dst < outLen) {
            out[dst] = UInt8((word >> 16) & UInt32(0xff))
            dst += 1
        }
        if (dst < outLen && c2 >= 0) {
            out[dst] = UInt8((word >> 8) & UInt32(0xff))
            dst += 1
        }
        if (dst < outLen && c3 >= 0) {
            out[dst] = UInt8(word & UInt32(0xff))
            dst += 1
        }
        src += 4
    }
    out
}

private func base64Encode(bytes: Array<Byte>): String {
    if (bytes.size == 0) {
        return ""
    }

    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let out = ArrayList<Byte>()
    var i = 0
    while (i < bytes.size) {
        let remaining = bytes.size - i
        let b0 = UInt32(UInt8(bytes[i]))
        let b1 = if (remaining > 1) {
            UInt32(UInt8(bytes[i + 1]))
        } else {
            UInt32(0)
        }
        let b2 = if (remaining > 2) {
            UInt32(UInt8(bytes[i + 2]))
        } else {
            UInt32(0)
        }

        let word = (b0 << 16) | (b1 << 8) | b2
        let c0 = Int64((word >> 18) & UInt32(0x3f))
        let c1 = Int64((word >> 12) & UInt32(0x3f))
        let c2 = Int64((word >> 6) & UInt32(0x3f))
        let c3 = Int64(word & UInt32(0x3f))

        out.add(alphabet[c0])
        out.add(alphabet[c1])
        out.add(if (remaining > 1) { alphabet[c2] } else { b'=' })
        out.add(if (remaining > 2) { alphabet[c3] } else { b'=' })
        i += 3
    }

    String.fromUtf8(out.toArray())
}

private func stripAsciiWhitespace(text: String): String {
    var out = ""
    for (ch in text.toArray()) {
        if (ch == b' ' || ch == b'\n' || ch == b'\r' || ch == b'\t') {
            continue
        }
        out += String.fromUtf8([ch])
    }
    out
}

private func countBase64Padding(text: String): Int64 {
    var pad = 0
    var i = text.size - 1
    while (i >= 0 && text[i] == b'=') {
        pad += 1
        i -= 1
    }
    if (pad > 2) {
        throw CryptoException(ParseError, "base64 padding exceeds 2 chars")
    }
    pad
}

private func base64DecodeChar(ch: Byte, allowPadding: Bool): Int64 {
    if (ch >= b'A' && ch <= b'Z') {
        return Int64(ch - b'A')
    }
    if (ch >= b'a' && ch <= b'z') {
        return Int64(ch - b'a' + 26)
    }
    if (ch >= b'0' && ch <= b'9') {
        return Int64(ch - b'0' + 52)
    }
    if (ch == b'+') {
        return 62
    }
    if (ch == b'/') {
        return 63
    }
    if (allowPadding && ch == b'=') {
        return -1
    }
    throw CryptoException(ParseError, "invalid base64 character")
}

private func findTrustAnchor(last: X509Certificate, trustAnchors: Array<X509Certificate>): ?X509Certificate {
    for (anchor in trustAnchors) {
        if (bytesEqual(anchor.der, last.der)) {
            return Some(anchor)
        }
    }
    None
}

private func concatStringArrays(left: Array<String>, right: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (item in left) {
        out.add(item)
    }
    for (item in right) {
        out.add(item)
    }
    out.toArray()
}

private func appendTrustAnchorsFromPemPath(out: ArrayList<X509Certificate>, path: String): Unit {
    let normalized = path.trimAscii()
    if (normalized.size == 0 || !exists(normalized)) {
        return
    }
    try {
        let pem = String.fromUtf8(File.readFrom(normalized))
        let certs = x509ParsePemChain(pem)
        for (cert in certs) {
            appendUniqueCertificate(out, cert)
        }
    } catch (_: Exception) {
        return
    }
}

private func appendUniqueCertificate(out: ArrayList<X509Certificate>, cert: X509Certificate): Unit {
    if (!containsCertificate(out, cert)) {
        out.add(cert)
    }
}

private func x509FindCrlForIssuer(issuer: X509Certificate, crls: Array<X509Crl>): ?X509Crl {
    let matched = ArrayList<X509Crl>()
    for (crl in crls) {
        if (x509NameDerEquals(crl.issuer, issuer.subject)) {
            matched.add(crl)
        }
    }
    if (matched.size == 0) {
        return None
    }
    if (matched.size == 1) {
        return Some(matched[0])
    }

    let issuerSki = x509ExtractSubjectKeyIdentifier(issuer)
    if (let Some(ski) <- issuerSki) {
        var fallback: ?X509Crl = None
        var i = 0
        while (i < matched.size) {
            if (let Some(aki) <- matched[i].authorityKeyIdentifier) {
                if (let Some(keyId) <- aki.keyIdentifier) {
                    if (bytesEqual(ski, keyId)) {
                        return Some(matched[i])
                    }
                    i += 1
                    continue
                }
                if (let None <- fallback) {
                    fallback = Some(matched[i])
                }
                i += 1
                continue
            }
            if (let None <- fallback) {
                fallback = Some(matched[i])
            }
            i += 1
        }
        if (let Some(crl) <- fallback) {
            return Some(crl)
        }
        return None
    }
    Some(matched[0])
}

private func x509RequireCrlCurrentAt(crl: X509Crl, validationTime: String): Unit {
    let now = normalizeTimeForCompare(validationTime)
    let thisUpdate = normalizeTimeForCompare(crl.thisUpdate)
    if (now < thisUpdate) {
        throw CryptoException(ParseError, "CRL is not yet valid")
    }
    if (crl.nextUpdate.size > 0) {
        let nextUpdate = normalizeTimeForCompare(crl.nextUpdate)
        if (now > nextUpdate) {
            throw CryptoException(ParseError, "CRL is expired")
        }
    }
}

private func concatCertificateArrays(left: Array<X509Certificate>, right: Array<X509Certificate>): Array<X509Certificate> {
    let list = ArrayList<X509Certificate>()
    for (item in left) {
        list.add(item)
    }
    for (item in right) {
        list.add(item)
    }
    list.toArray()
}

private func x509RequireIssuerNameMatch(cert: X509Certificate, issuer: X509Certificate): Unit {
    if (!x509NameDerEquals(cert.issuer, issuer.subject)) {
        throw CryptoException(ParseError, "certificate issuer does not match issuer subject")
    }
}

private func x509RequireAuthorityKeyIdentifierMatch(cert: X509Certificate, issuer: X509Certificate, requireMatch: Bool): Unit {
    let certAki = x509ExtractAuthorityKeyIdentifier(cert)
    if (let None <- certAki) {
        return
    }

    if (let Some(aki) <- certAki) {
        if (let None <- aki.keyIdentifier) {
            return
        }
        if (let Some(akiKeyId) <- aki.keyIdentifier) {
            let issuerSki = x509ExtractSubjectKeyIdentifier(issuer)
            if (let None <- issuerSki) {
                if (requireMatch) {
                    throw CryptoException(ParseError, "issuer certificate is missing subjectKeyIdentifier required by authorityKeyIdentifier")
                }
                return
            }
            if (let Some(issuerSkiValue) <- issuerSki) {
                if (!bytesEqual(akiKeyId, issuerSkiValue)) {
                    throw CryptoException(ParseError, "authorityKeyIdentifier does not match issuer subjectKeyIdentifier")
                }
                return
            }
        }
    }
    throw CryptoException(ParseError, "authorityKeyIdentifier resolution failed")
}

private func x509RequireLeafUsageConstraints(cert: X509Certificate, policy: X509VerificationPolicy): Unit {
    x509RequireLeafKeyUsage(cert, policy.requiredLeafKeyUsageMask)
    x509RequireLeafExtendedKeyUsages(cert, policy.requiredLeafExtendedKeyUsages)
    x509RequireLeafCertificatePolicies(cert, policy.requiredLeafCertificatePolicies)
    x509RequireLeafDnsName(cert, policy.requiredLeafDnsName)
}

private func x509RequireLeafKeyUsage(cert: X509Certificate, requiredMask: Int64): Unit {
    if (requiredMask == 0) {
        return
    }

    let ext = x509FindExtension(cert, X509_OID_KEY_USAGE)
    if (let None <- ext) {
        throw CryptoException(ParseError, "leaf certificate is missing required keyUsage extension")
    }
    if (let Some(keyUsageExt) <- ext) {
        let keyUsage = x509DecodeKeyUsageFromExtension(keyUsageExt)
        if ((keyUsage & requiredMask) != requiredMask) {
            throw CryptoException(ParseError, "leaf certificate keyUsage does not satisfy required mask")
        }
        return
    }
    throw CryptoException(ParseError, "leaf certificate keyUsage extension resolution failed")
}

private func x509RequireLeafExtendedKeyUsages(cert: X509Certificate, requiredOids: Array<String>): Unit {
    if (requiredOids.size == 0) {
        return
    }

    let ext = x509FindExtension(cert, X509_OID_EXTENDED_KEY_USAGE)
    if (let None <- ext) {
        throw CryptoException(ParseError, "leaf certificate is missing required extendedKeyUsage extension")
    }
    if (let Some(ekuExt) <- ext) {
        let decoded = x509DecodeExtendedKeyUsageFromExtension(ekuExt)
        if (arrayContainsString(decoded, X509_OID_EKU_ANY)) {
            return
        }
        for (requiredOid in requiredOids) {
            if (!arrayContainsString(decoded, requiredOid)) {
                throw CryptoException(ParseError, "leaf certificate extendedKeyUsage does not contain required OID: ${requiredOid}")
            }
        }
        return
    }
    throw CryptoException(ParseError, "leaf certificate extendedKeyUsage extension resolution failed")
}

private func x509RequireLeafCertificatePolicies(cert: X509Certificate, requiredOids: Array<String>): Unit {
    if (requiredOids.size == 0) {
        return
    }

    let ext = x509FindExtension(cert, X509_OID_CERTIFICATE_POLICIES)
    if (let None <- ext) {
        throw CryptoException(ParseError, "leaf certificate is missing required certificatePolicies extension")
    }
    if (let Some(policyExt) <- ext) {
        let decoded = x509DecodeCertificatePoliciesFromExtension(policyExt)
        if (arrayContainsString(decoded, X509_OID_ANY_POLICY)) {
            return
        }
        for (requiredOid in requiredOids) {
            if (!arrayContainsString(decoded, requiredOid)) {
                throw CryptoException(ParseError, "leaf certificate certificatePolicies does not contain required OID: ${requiredOid}")
            }
        }
        return
    }
    throw CryptoException(ParseError, "leaf certificate certificatePolicies extension resolution failed")
}

private func x509RequireLeafDnsName(cert: X509Certificate, requiredDnsName: String): Unit {
    let expected = requiredDnsName.trimAscii().toAsciiLower()
    if (expected.size == 0) {
        return
    }

    let dnsSans = x509ExtractSubjectAlternativeDnsNames(cert)
    if (dnsSans.size > 0) {
        for (pattern in dnsSans) {
            if (x509DnsNameMatches(pattern, expected)) {
                return
            }
        }
        throw CryptoException(ParseError, "leaf certificate subjectAltName does not match required DNS name: ${expected}")
    }

    let commonName = cert.subject.commonName()
    if (commonName.size == 0) {
        throw CryptoException(ParseError, "leaf certificate has no DNS subjectAltName and empty subject CN")
    }
    if (!x509DnsNameMatches(commonName, expected)) {
        throw CryptoException(ParseError, "leaf certificate subject CN does not match required DNS name: ${expected}")
    }
}

private func x509DnsNameMatches(patternRaw: String, hostnameRaw: String): Bool {
    let pattern = normalizeDnsNameForMatch(patternRaw)
    let hostname = normalizeDnsNameForMatch(hostnameRaw)

    if (pattern == hostname) {
        return true
    }

    if (!pattern.startsWith("*.")) {
        return false
    }
    if (countByteInString(pattern, b'*') != 1) {
        return false
    }

    let suffix = pattern[1..]
    if (hostname.size <= suffix.size || !hostname.endsWith(suffix)) {
        return false
    }
    let prefix = hostname[..(hostname.size - suffix.size)]
    if (prefix.size == 0) {
        return false
    }
    for (ch in prefix.toArray()) {
        if (ch == b'.') {
            return false
        }
    }
    true
}

private func x509RequireCrlAuthorityKeyIdentifierMatch(crl: X509Crl, issuer: X509Certificate, requireMatch: Bool): Unit {
    if (let None <- crl.authorityKeyIdentifier) {
        if (requireMatch) {
            throw CryptoException(ParseError, "CRL is missing authorityKeyIdentifier required for issuer matching")
        }
        return
    }

    if (let Some(aki) <- crl.authorityKeyIdentifier) {
        if (let None <- aki.keyIdentifier) {
            if (requireMatch) {
                throw CryptoException(ParseError, "CRL authorityKeyIdentifier does not contain keyIdentifier")
            }
            return
        }
        if (let Some(akiKeyId) <- aki.keyIdentifier) {
            let issuerSki = x509ExtractSubjectKeyIdentifier(issuer)
            if (let None <- issuerSki) {
                if (requireMatch) {
                    throw CryptoException(ParseError, "issuer certificate is missing subjectKeyIdentifier required by CRL authorityKeyIdentifier")
                }
                return
            }
            if (let Some(issuerSkiValue) <- issuerSki) {
                if (!bytesEqual(akiKeyId, issuerSkiValue)) {
                    throw CryptoException(ParseError, "CRL authorityKeyIdentifier does not match issuer subjectKeyIdentifier")
                }
                return
            }
        }
    }
    throw CryptoException(ParseError, "CRL authorityKeyIdentifier resolution failed")
}

private func x509RequireIssuerCanSign(issuer: X509Certificate, allowMissingBasicConstraints: Bool, caCertsBelowIssuer: Int64): Unit {
    let ext = x509FindExtension(issuer, X509_OID_KEY_USAGE)
    if (let None <- ext) {
        // keyUsage is optional in RFC; keep permissive when absent.
    } else if (let Some(keyUsageExt) <- ext) {
        let keyUsage = x509DecodeKeyUsageFromExtension(keyUsageExt)
        if ((keyUsage & X509_KEY_USAGE_KEY_CERT_SIGN) == 0) {
            throw CryptoException(ParseError, "issuer certificate keyUsage does not allow certificate signing")
        }
    }

    let basicConstraintsExt = x509FindExtension(issuer, X509_OID_BASIC_CONSTRAINTS)
    if (let None <- basicConstraintsExt) {
        if (allowMissingBasicConstraints) {
            return
        }
        throw CryptoException(ParseError, "issuer certificate is missing basicConstraints extension")
    }
    if (let Some(extValue) <- basicConstraintsExt) {
        let basicConstraints = x509DecodeBasicConstraintsFromExtension(extValue)
        if (!basicConstraints.ca) {
            throw CryptoException(ParseError, "issuer certificate basicConstraints CA flag is false")
        }
        if (let Some(pathLen) <- basicConstraints.pathLenConstraint) {
            if (caCertsBelowIssuer > pathLen) {
                throw CryptoException(ParseError, "issuer certificate pathLenConstraint is violated")
            }
        }
        return
    }
    throw CryptoException(ParseError, "issuer basicConstraints extension resolution failed")
}

private func x509RequireSignatureAlgorithmAllowed(cert: X509Certificate, profile: FipsProfile): Unit {
    let oid = cert.signatureAlgorithmOid
    let hashName = hashNameFromSignatureAlgorithmOid(oid)

    if (
        oid == X509_OID_SHA256_WITH_RSA ||
        oid == X509_OID_SHA384_WITH_RSA ||
        oid == X509_OID_SHA512_WITH_RSA
    ) {
        profile.requireAllowed("RSA")
        profile.requireAllowed(hashName)
        return
    }

    if (
        oid == X509_OID_ECDSA_WITH_SHA256 ||
        oid == X509_OID_ECDSA_WITH_SHA384 ||
        oid == X509_OID_ECDSA_WITH_SHA512
    ) {
        profile.requireAllowed("ECDSA")
        profile.requireAllowed(hashName)
        return
    }

    throw CryptoException(ComplianceRejected, "certificate signature algorithm is blocked by FIPS profile: ${oid}")
}

private func x509RequirePublicKeyAllowed(cert: X509Certificate, profile: FipsProfile): Unit {
    let rsaKey = tryDecodeRsaPublicKey(cert.subjectPublicKeyInfoDer)
    if (let Some(rsa) <- rsaKey) {
        profile.requireAllowed("RSA")
        if (rsa.bits() < 2048) {
            throw CryptoException(ComplianceRejected, "RSA public key is too small for FIPS-ready profile")
        }
        return
    }

    let ecKey = tryDecodeEcPublicKey(cert.subjectPublicKeyInfoDer)
    if (let Some(ec) <- ecKey) {
        profile.requireAllowed("ECDSA")
        if (!isFipsCurve(ec.curve)) {
            throw CryptoException(ComplianceRejected, "EC curve is blocked by FIPS-ready profile: ${ec.curve.toString()}")
        }
        return
    }

    throw CryptoException(ComplianceRejected, "certificate public key algorithm is blocked by FIPS profile")
}

private func tryDecodeRsaPublicKey(spkiDer: Array<Byte>): ?RsaPublicKey {
    try {
        return Some(decodeRsaPublicKeyFromSpki(spkiDer))
    } catch (e: CryptoException) {
        if (e.code == Unsupported) {
            return None
        }
        throw e
    }
}

private func tryDecodeEcPublicKey(spkiDer: Array<Byte>): ?EcPublicKey {
    try {
        return Some(decodeEcPublicKeyFromSpki(spkiDer))
    } catch (e: CryptoException) {
        if (e.code == Unsupported) {
            return None
        }
        throw e
    }
}

private func hashNameFromSignatureAlgorithmOid(oid: String): String {
    if (oid == X509_OID_SHA256_WITH_RSA || oid == X509_OID_ECDSA_WITH_SHA256) {
        return "SHA-256"
    }
    if (oid == X509_OID_SHA384_WITH_RSA || oid == X509_OID_ECDSA_WITH_SHA384) {
        return "SHA-384"
    }
    if (oid == X509_OID_SHA512_WITH_RSA || oid == X509_OID_ECDSA_WITH_SHA512) {
        return "SHA-512"
    }
    throw CryptoException(ComplianceRejected, "unsupported certificate signature hash in FIPS policy: ${oid}")
}

private func decodeRsaPublicKeyFromSpki(spkiDer: Array<Byte>): RsaPublicKey {
    let spkiElem = derReadSingleElement(spkiDer, "X509 SubjectPublicKeyInfo")
    if (spkiElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "SubjectPublicKeyInfo must be SEQUENCE")
    }

    let reader = DerReader(spkiElem.value)
    let algElem = reader.readElement("SubjectPublicKeyInfo.algorithm", expectedTag: DER_TAG_SEQUENCE)
    let keyElem = reader.readElement("SubjectPublicKeyInfo.subjectPublicKey", expectedTag: DER_TAG_BIT_STRING)
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "SubjectPublicKeyInfo contains trailing bytes")
    }

    let algReader = DerReader(algElem.value)
    let oidElem = algReader.readElement("SubjectPublicKeyInfo.algorithm OID", expectedTag: DER_TAG_OID)
    let oid = decodeOid(oidElem.value, "SubjectPublicKeyInfo.algorithm OID")
    if (oid != X509_OID_RSA_ENCRYPTION) {
        throw CryptoException(Unsupported, "issuer key algorithm is not RSA")
    }
    if (algReader.hasRemaining()) {
        let params = algReader.readElement("SubjectPublicKeyInfo.algorithm parameters")
        if (params.tag != DER_TAG_NULL) {
            throw CryptoException(ParseError, "RSA algorithm parameters must be NULL")
        }
        if (algReader.hasRemaining()) {
            throw CryptoException(ParseError, "RSA algorithm parameters contain trailing bytes")
        }
    }

    let rsaKeyBytes = decodeBitStringValue(keyElem.value, "SubjectPublicKeyInfo.subjectPublicKey")
    let rsaElem = derReadSingleElement(rsaKeyBytes, "RSAPublicKey")
    if (rsaElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "RSAPublicKey must be SEQUENCE")
    }

    let rsaReader = DerReader(rsaElem.value)
    let modulusElem = rsaReader.readElement("RSAPublicKey.modulus", expectedTag: DER_TAG_INTEGER)
    let exponentElem = rsaReader.readElement("RSAPublicKey.exponent", expectedTag: DER_TAG_INTEGER)
    if (rsaReader.hasRemaining()) {
        throw CryptoException(ParseError, "RSAPublicKey contains trailing bytes")
    }

    let modulus = BigNum.fromBytesBE(parsePositiveInteger(modulusElem.value, "RSAPublicKey.modulus"))
    let exponent = BigNum.fromBytesBE(parsePositiveInteger(exponentElem.value, "RSAPublicKey.exponent"))
    RsaPublicKey(modulus, exponent)
}

private func decodeEcPublicKeyFromSpki(spkiDer: Array<Byte>): EcPublicKey {
    let spkiElem = derReadSingleElement(spkiDer, "X509 SubjectPublicKeyInfo")
    if (spkiElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "SubjectPublicKeyInfo must be SEQUENCE")
    }

    let reader = DerReader(spkiElem.value)
    let algElem = reader.readElement("SubjectPublicKeyInfo.algorithm", expectedTag: DER_TAG_SEQUENCE)
    let keyElem = reader.readElement("SubjectPublicKeyInfo.subjectPublicKey", expectedTag: DER_TAG_BIT_STRING)
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "SubjectPublicKeyInfo contains trailing bytes")
    }

    let algReader = DerReader(algElem.value)
    let algOidElem = algReader.readElement("SubjectPublicKeyInfo.algorithm OID", expectedTag: DER_TAG_OID)
    let algOid = decodeOid(algOidElem.value, "SubjectPublicKeyInfo.algorithm OID")
    if (algOid != X509_OID_EC_PUBLIC_KEY) {
        throw CryptoException(Unsupported, "issuer key algorithm is not EC")
    }

    let curveOidElem = algReader.readElement("SubjectPublicKeyInfo.curve OID", expectedTag: DER_TAG_OID)
    let curveOid = decodeOid(curveOidElem.value, "SubjectPublicKeyInfo.curve OID")
    if (algReader.hasRemaining()) {
        throw CryptoException(ParseError, "SubjectPublicKeyInfo.algorithm has trailing bytes")
    }
    let curve = curveFromNamedCurveOid(curveOid)
    let fieldLen = fieldByteLengthForCurve(curve)

    let point = decodeBitStringValue(keyElem.value, "SubjectPublicKeyInfo.subjectPublicKey")
    let expectedPointLen = 1 + fieldLen * 2
    if (point.size != expectedPointLen || UInt8(point[0]) != UInt8(0x04)) {
        throw CryptoException(ParseError, "EC public key must use uncompressed point format for ${curve.toString()}")
    }

    let x = BigNum.fromBytesBE(point[1..(1 + fieldLen)])
    let y = BigNum.fromBytesBE(point[(1 + fieldLen)..expectedPointLen])
    EcPublicKey(curve, x, y)
}

private func decodeRsaPrivateKeyPkcs1(pkcs1Der: Array<Byte>): RsaPrivateKey {
    let keyElem = derReadSingleElement(pkcs1Der, "RSAPrivateKey")
    if (keyElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "RSAPrivateKey must be DER SEQUENCE")
    }

    let reader = DerReader(keyElem.value)
    _ = reader.readElement("RSAPrivateKey.version", expectedTag: DER_TAG_INTEGER)
    let modulusElem = reader.readElement("RSAPrivateKey.modulus", expectedTag: DER_TAG_INTEGER)
    let exponentElem = reader.readElement("RSAPrivateKey.publicExponent", expectedTag: DER_TAG_INTEGER)
    let privateExponentElem = reader.readElement("RSAPrivateKey.privateExponent", expectedTag: DER_TAG_INTEGER)

    if (reader.hasRemaining()) {
        _ = reader.readElement("RSAPrivateKey.prime1", expectedTag: DER_TAG_INTEGER)
    }
    if (reader.hasRemaining()) {
        _ = reader.readElement("RSAPrivateKey.prime2", expectedTag: DER_TAG_INTEGER)
    }
    if (reader.hasRemaining()) {
        _ = reader.readElement("RSAPrivateKey.exponent1", expectedTag: DER_TAG_INTEGER)
    }
    if (reader.hasRemaining()) {
        _ = reader.readElement("RSAPrivateKey.exponent2", expectedTag: DER_TAG_INTEGER)
    }
    if (reader.hasRemaining()) {
        _ = reader.readElement("RSAPrivateKey.coefficient", expectedTag: DER_TAG_INTEGER)
    }

    let modulus = BigNum.fromBytesBE(parsePositiveInteger(modulusElem.value, "RSAPrivateKey.modulus"))
    let exponent = BigNum.fromBytesBE(parsePositiveInteger(exponentElem.value, "RSAPrivateKey.publicExponent"))
    let privateExponent = BigNum.fromBytesBE(parsePositiveInteger(privateExponentElem.value, "RSAPrivateKey.privateExponent"))
    RsaPrivateKey(modulus, exponent, privateExponent)
}

private func decodePkcs8PrivateKeyInfo(pkcs8Der: Array<Byte>): (String, String, Array<Byte>) {
    let elem = derReadSingleElement(pkcs8Der, "PKCS8 PrivateKeyInfo")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "PKCS8 PrivateKeyInfo must be DER SEQUENCE")
    }

    let reader = DerReader(elem.value)
    _ = reader.readElement("PKCS8.version", expectedTag: DER_TAG_INTEGER)

    let algElem = reader.readElement("PKCS8.privateKeyAlgorithm", expectedTag: DER_TAG_SEQUENCE)
    let algReader = DerReader(algElem.value)
    let algOidElem = algReader.readElement("PKCS8.privateKeyAlgorithm OID", expectedTag: DER_TAG_OID)
    let algorithmOid = decodeOid(algOidElem.value, "PKCS8.privateKeyAlgorithm OID")

    var curveOid = ""
    if (algReader.hasRemaining()) {
        let paramsElem = algReader.readElement("PKCS8.privateKeyAlgorithm parameters")
        if (paramsElem.tag == DER_TAG_OID) {
            curveOid = decodeOid(paramsElem.value, "PKCS8.privateKeyAlgorithm curve OID")
        } else if (paramsElem.tag == DER_TAG_NULL) {
            curveOid = ""
        } else {
            throw CryptoException(ParseError, "unsupported PKCS8 algorithm parameters tag")
        }
    }
    if (algReader.hasRemaining()) {
        throw CryptoException(ParseError, "PKCS8.privateKeyAlgorithm contains trailing bytes")
    }

    let privateKeyElem = reader.readElement("PKCS8.privateKey", expectedTag: DER_TAG_OCTET_STRING)
    while (reader.hasRemaining()) {
        _ = reader.readElement("PKCS8 optional field")
    }
    (algorithmOid, curveOid, privateKeyElem.value)
}

private func decodeEcPrivateKeySec1(sec1Der: Array<Byte>, expectedCurve: NamedCurve): EcPrivateKey {
    let elem = derReadSingleElement(sec1Der, "ECPrivateKey")
    if (elem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "ECPrivateKey must be DER SEQUENCE")
    }

    let reader = DerReader(elem.value)
    let versionElem = reader.readElement("ECPrivateKey.version", expectedTag: DER_TAG_INTEGER)
    let version = parsePositiveInteger(versionElem.value, "ECPrivateKey.version")
    if (version.size != 1 || version[0] != UInt8(0x01)) {
        throw CryptoException(ParseError, "ECPrivateKey.version must be 1")
    }

    let privateKeyElem = reader.readElement("ECPrivateKey.privateKey", expectedTag: DER_TAG_OCTET_STRING)
    var embeddedCurve = expectedCurve

    while (reader.hasRemaining()) {
        let tag = reader.peekTag()
        if (tag == DER_TAG_CONTEXT_0) {
            let curveElem = reader.readElement("ECPrivateKey.parameters", expectedTag: DER_TAG_CONTEXT_0)
            let curveReader = DerReader(curveElem.value)
            let oidElem = curveReader.readElement("ECPrivateKey.parameters OID", expectedTag: DER_TAG_OID)
            if (curveReader.hasRemaining()) {
                throw CryptoException(ParseError, "ECPrivateKey.parameters has trailing bytes")
            }
            let oid = decodeOid(oidElem.value, "ECPrivateKey.parameters OID")
            embeddedCurve = curveFromNamedCurveOid(oid)
            continue
        }
        if (tag == DER_TAG_CONTEXT_1) {
            _ = reader.readElement("ECPrivateKey.publicKey", expectedTag: DER_TAG_CONTEXT_1)
            continue
        }
        throw CryptoException(ParseError, "unsupported ECPrivateKey optional field tag")
    }

    if (embeddedCurve != expectedCurve) {
        throw CryptoException(ParseError, "ECPrivateKey curve does not match PKCS8 algorithm parameters")
    }

    let scalarBytes = trimLeadingZeroBytes(privateKeyElem.value)
    EcPrivateKey(expectedCurve, BigNum.fromBytesBE(scalarBytes))
}

private func curveFromNamedCurveOid(oid: String): NamedCurve {
    if (oid == X509_OID_PRIME256V1) {
        return P256
    }
    if (oid == X509_OID_SECP384R1) {
        return P384
    }
    if (oid == X509_OID_SECP521R1) {
        return P521
    }
    if (oid == X509_OID_SECP256K1) {
        return SECP256K1
    }
    throw CryptoException(Unsupported, "unsupported EC named curve OID: ${oid}")
}

private func namedCurveOid(curve: NamedCurve): String {
    match (curve) {
        case P256 => X509_OID_PRIME256V1
        case P384 => X509_OID_SECP384R1
        case P521 => X509_OID_SECP521R1
        case SECP256K1 => X509_OID_SECP256K1
    }
}

private func fieldByteLengthForCurve(curve: NamedCurve): Int64 {
    match (curve) {
        case P256 | SECP256K1 => 32
        case P384 => 48
        case P521 => 66
    }
}

private func decodeEcdsaSignature(signatureDer: Array<Byte>): (BigNum, BigNum) {
    let sigElem = derReadSingleElement(signatureDer, "ECDSA signature")
    if (sigElem.tag != DER_TAG_SEQUENCE) {
        throw CryptoException(ParseError, "ECDSA signature must be DER SEQUENCE")
    }
    let reader = DerReader(sigElem.value)
    let rElem = reader.readElement("ECDSA signature.r", expectedTag: DER_TAG_INTEGER)
    let sElem = reader.readElement("ECDSA signature.s", expectedTag: DER_TAG_INTEGER)
    if (reader.hasRemaining()) {
        throw CryptoException(ParseError, "ECDSA signature has trailing bytes")
    }

    let r = BigNum.fromBytesBE(parsePositiveInteger(rElem.value, "ECDSA signature.r"))
    let s = BigNum.fromBytesBE(parsePositiveInteger(sElem.value, "ECDSA signature.s"))
    (r, s)
}

private func encodeEcdsaSignatureDer(r: BigNum, s: BigNum): Array<Byte> {
    let encodedR = encodePositiveInteger(r.toBytesBE())
    let encodedS = encodePositiveInteger(s.toBytesBE())
    derWrap(DER_TAG_SEQUENCE, concatBytes(encodedR, encodedS))
}

private func digestForSignatureAlgorithm(signatureOid: String, tbsDer: Array<Byte>): Array<Byte> {
    if (signatureOid == X509_OID_SHA256_WITH_RSA || signatureOid == X509_OID_ECDSA_WITH_SHA256) {
        return sha256(tbsDer)
    }
    if (signatureOid == X509_OID_SHA384_WITH_RSA || signatureOid == X509_OID_ECDSA_WITH_SHA384) {
        return sha384(tbsDer)
    }
    if (signatureOid == X509_OID_SHA512_WITH_RSA || signatureOid == X509_OID_ECDSA_WITH_SHA512) {
        return sha512(tbsDer)
    }
    throw CryptoException(Unsupported, "unsupported signature algorithm OID: ${signatureOid}")
}

private func rsaHashAlgorithmFromSignatureOid(signatureOid: String): RsaHashAlgorithm {
    if (signatureOid == X509_OID_SHA256_WITH_RSA) {
        return RsaHashAlgorithm.SHA256
    }
    if (signatureOid == X509_OID_SHA384_WITH_RSA) {
        return RsaHashAlgorithm.SHA384
    }
    if (signatureOid == X509_OID_SHA512_WITH_RSA) {
        return RsaHashAlgorithm.SHA512
    }
    throw CryptoException(Unsupported, "unsupported RSA signature algorithm OID: ${signatureOid}")
}

private func normalizeTimeForCompare(text: String): String {
    let t = text.trimAscii()
    if (isGeneralizedTime(t)) {
        return t[..14]
    }
    if (!isUtcTime(t)) {
        throw CryptoException(ParseError, "invalid X509 time format")
    }

    let yy = parseDecimal(t[..2], "UTCTime year")
    let century = if (yy >= 50) { "19" } else { "20" }
    "${century}${t[..12]}"
}

private func normalizeOidList(items: Array<String>): Array<String> {
    if (items.size == 0) {
        return []
    }
    let out = ArrayList<String>()
    for (item in items) {
        let oid = item.trimAscii()
        if (oid.size == 0) {
            throw CryptoException(InvalidArgument, "requiredLeafExtendedKeyUsages must not contain empty OID")
        }
        if (!arrayListContainsString(out, oid)) {
            out.add(oid)
        }
    }
    out.toArray()
}

private func arrayListContainsString(values: ArrayList<String>, expected: String): Bool {
    var i = 0
    while (i < values.size) {
        if (values[i] == expected) {
            return true
        }
        i += 1
    }
    false
}

private func arrayContainsString(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

private func normalizeDnsNameForMatch(text: String): String {
    let normalized = text.trimAscii().toAsciiLower()
    if (normalized.size == 0 || normalized.startsWith(".") || normalized.endsWith(".")) {
        throw CryptoException(ParseError, "invalid DNS name")
    }
    for (ch in normalized.toArray()) {
        if (UInt8(ch) > UInt8(0x7f)) {
            throw CryptoException(ParseError, "DNS name must be ASCII")
        }
    }
    normalized
}

private func countByteInString(text: String, expected: Byte): Int64 {
    var count = 0
    for (ch in text.toArray()) {
        if (ch == expected) {
            count += 1
        }
    }
    count
}

private func normalizeHexList(items: Array<String>): Array<String> {
    if (items.size == 0) {
        return []
    }
    let out = Array<String>(items.size, repeat: "")
    var i = 0
    while (i < items.size) {
        out[i] = normalizeHex(items[i])
        i += 1
    }
    out
}

private func normalizeHex(text: String): String {
    var clean = text.trimAscii().toAsciiLower().replace(" ", "").replace("\n", "").replace("\t", "")
    if (clean.startsWith("0x")) {
        clean = clean[2..]
    }
    if (clean.size == 0) {
        return "0"
    }
    var i = 0
    while (i < clean.size - 1 && clean[i] == b'0') {
        i += 1
    }
    clean[i..]
}

private func parseSmallPositiveInteger(encoded: Array<Byte>, label: String): Int64 {
    let value = parsePositiveInteger(encoded, label)
    if (value.size > 8) {
        throw CryptoException(ParseError, "${label} exceeds Int64 range")
    }
    if (value.size == 8 && (UInt8(value[0]) & UInt8(0x80)) != UInt8(0)) {
        throw CryptoException(ParseError, "${label} exceeds Int64 range")
    }

    var out: Int64 = 0
    for (b in value) {
        out = (out << 8) | Int64(UInt8(b))
    }
    out
}

private func x509CountCaCertificatesBelow(chain: Array<X509Certificate>, issuerIndex: Int64): Int64 {
    if (issuerIndex <= 0) {
        return 0
    }

    var count = 0
    var i = 0
    while (i < issuerIndex) {
        if (x509CertificateHasCaFlag(chain[i])) {
            count += 1
        }
        i += 1
    }
    count
}

private func x509CertificateHasCaFlag(cert: X509Certificate): Bool {
    let ext = x509FindExtension(cert, X509_OID_BASIC_CONSTRAINTS)
    if (let None <- ext) {
        return false
    }
    if (let Some(basicConstraintsExt) <- ext) {
        return x509DecodeBasicConstraintsFromExtension(basicConstraintsExt).ca
    }
    throw CryptoException(ParseError, "certificate basicConstraints extension resolution failed")
}

private func x509CertificateHasCrlDistributionPoints(cert: X509Certificate): Bool {
    let ext = x509FindExtension(cert, X509_OID_CRL_DISTRIBUTION_POINTS)
    if (let None <- ext) {
        return false
    }
    if (let Some(crldpExt) <- ext) {
        return x509DecodeCrlDistributionPointsFromExtension(crldpExt).size > 0
    }
    throw CryptoException(ParseError, "certificate CRL distribution points extension resolution failed")
}

private func cloneAuthorityKeyIdentifier(value: ?X509AuthorityKeyIdentifier): ?X509AuthorityKeyIdentifier {
    if (let None <- value) {
        return None
    }
    if (let Some(aki) <- value) {
        if (let None <- aki.keyIdentifier) {
            return Some(X509AuthorityKeyIdentifier())
        }
        if (let Some(keyId) <- aki.keyIdentifier) {
            return Some(X509AuthorityKeyIdentifier(keyIdentifier: Some(keyId.clone())))
        }
    }
    throw CryptoException(ParseError, "authorityKeyIdentifier clone failed")
}

private func isValidX509Time(text: String): Bool {
    let utcTime = isUtcTime(text)
    let generalizedTime = isGeneralizedTime(text)
    utcTime || generalizedTime
}

private func isUtcTime(text: String): Bool {
    if (text.size != 13 || !text.endsWith("Z")) {
        return false
    }
    let body = text[..12]
    isAsciiDigits(body)
}

private func isGeneralizedTime(text: String): Bool {
    if (text.size != 15 || !text.endsWith("Z")) {
        return false
    }
    let body = text[..14]
    isAsciiDigits(body)
}

private func isAsciiDigits(text: String): Bool {
    for (ch in text.toArray()) {
        if (ch < b'0' || ch > b'9') {
            return false
        }
    }
    true
}

private func findIssuer(cert: X509Certificate, candidates: Array<X509Certificate>): ?X509Certificate {
    let matched = findIssuerCandidates(cert, candidates)
    if (matched.size == 0) {
        return None
    }
    Some(matched[0])
}

private func findIssuerCandidates(cert: X509Certificate, candidates: Array<X509Certificate>): Array<X509Certificate> {
    let matched = ArrayList<X509Certificate>()
    for (candidate in candidates) {
        if (bytesEqual(cert.der, candidate.der)) {
            continue
        }
        if (x509NameDerEquals(cert.issuer, candidate.subject)) {
            matched.add(candidate)
        }
    }

    if (matched.size == 0) {
        return []
    }
    if (matched.size == 1) {
        return matched.toArray()
    }

    let certAki = x509ExtractAuthorityKeyIdentifier(cert)
    if (let Some(aki) <- certAki) {
        if (let Some(akiKeyId) <- aki.keyIdentifier) {
            let preferred = ArrayList<X509Certificate>()
            let fallback = ArrayList<X509Certificate>()
            var i = 0
            while (i < matched.size) {
                let candidateSki = x509ExtractSubjectKeyIdentifier(matched[i])
                if (let Some(ski) <- candidateSki) {
                    if (bytesEqual(akiKeyId, ski)) {
                        preferred.add(matched[i])
                    } else {
                        fallback.add(matched[i])
                    }
                } else {
                    fallback.add(matched[i])
                }
                i += 1
            }
            if (preferred.size > 0) {
                for (item in fallback) {
                    preferred.add(item)
                }
                return preferred.toArray()
            }
        }
    }
    matched.toArray()
}

private func containsCertificate(chain: ArrayList<X509Certificate>, cert: X509Certificate): Bool {
    var i = 0
    while (i < chain.size) {
        if (bytesEqual(chain[i].der, cert.der)) {
            return true
        }
        i += 1
    }
    false
}

private func isContextSpecificTag(tag: Int64): Bool {
    let b = UInt8(tag)
    (b & UInt8(0xc0)) == UInt8(0x80)
}

private func trimLeadingZeroBytes(input: Array<Byte>): Array<Byte> {
    if (input.size == 0) {
        return []
    }
    var i = 0
    while (i < input.size && input[i] == 0) {
        i += 1
    }
    if (i >= input.size) {
        return [UInt8(0)]
    }
    input[i..]
}

private func appendBytes(out: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

private func concatBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    secureCopyInto(left, out)
    secureCopyInto(right, out, dstOffset: left.size)
    out
}

private func bytesEqual(left: Array<Byte>, right: Array<Byte>): Bool {
    constantTimeEquals(left, right)
}

private func intToHexLower(value: Int64): String {
    let digits: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]
    if (value == 0) {
        return "0"
    }
    var x = value
    var out = ""
    while (x > 0) {
        let nibble = x & 0x0f
        out = digits[nibble] + out
        x >>= 4
    }
    out
}

private func minI64(left: Int64, right: Int64): Int64 {
    if (left < right) {
        return left
    }
    right
}

private func maxI64(left: Int64, right: Int64): Int64 {
    if (left > right) {
        return left
    }
    right
}
