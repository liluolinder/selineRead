package jinguissl_core.tests

import std.collection.{ArrayList, HashMap}
import std.fs.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.sha256
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.rsa.*
import jinguissl_core.crypto.x509.{X509AuthorityKeyIdentifier, X509Certificate, X509Crl, X509Extension, X509SelfSignedConfig, X509VerificationPolicy, X509_KEY_USAGE_DIGITAL_SIGNATURE, X509_KEY_USAGE_KEY_AGREEMENT, X509_KEY_USAGE_KEY_CERT_SIGN, X509_KEY_USAGE_KEY_ENCIPHERMENT, X509_OID_AUTHORITY_KEY_IDENTIFIER, X509_OID_BASIC_CONSTRAINTS, X509_OID_CERTIFICATE_POLICIES, X509_OID_CRL_DISTRIBUTION_POINTS, X509_OID_ECDSA_WITH_SHA256, X509_OID_ECDSA_WITH_SHA384, X509_OID_EKU_CLIENT_AUTH, X509_OID_EKU_SERVER_AUTH, X509_OID_EXTENDED_KEY_USAGE, X509_OID_KEY_USAGE, X509_OID_SHA256_WITH_RSA, X509_OID_SUBJECT_ALT_NAME, X509_OID_SUBJECT_KEY_IDENTIFIER, x509BuildSimpleChain, x509CreateSelfSignedEcCertificate, x509CreateSelfSignedRsaCertificate, x509CreateSystemTrustPolicy, x509DecodeAuthorityKeyIdentifierFromExtension, x509DecodeCertificatePoliciesFromExtension, x509DecodeCrlDistributionPointsFromExtension, x509DecodeExtendedKeyUsageFromExtension, x509DecodeKeyUsageFromExtension, x509DecodeSubjectAlternativeNameDnsFromExtension, x509DecodeSubjectKeyIdentifierFromExtension, x509ExtractAuthorityKeyIdentifier, x509ExtractCertificatePolicyOids, x509ExtractCrlDistributionPointUris, x509ExtractEcPublicKey, x509ExtractExtendedKeyUsageOids, x509ExtractRsaPublicKey, x509ExtractSubjectAlternativeDnsNames, x509ExtractSubjectKeyIdentifier, x509FindExtension, x509LoadSystemTrustAnchors, x509ParseCrlPem, x509ParseDer, x509ParseEcPrivateKeyPkcs8Der, x509ParseEcPrivateKeyPkcs8Pem, x509ParsePem, x509ParsePemChain, x509ParseRsaPrivateKeyPkcs1Der, x509ParseRsaPrivateKeyPkcs1Pem, x509ParseRsaPrivateKeyPkcs8Der, x509ParseRsaPrivateKeyPkcs8Pem, x509SystemTrustBundleCandidatePaths, x509VerifyCertificateChain, x509VerifyCertificateChainWithProfile, x509VerifyCrlSignatureWithIssuer, x509VerifySignatureWithIssuer}

type X509KeyValueVector = HashMap<String, String>

@Test
public class X509TestSuite {
    @TestCase
    public func testParseBoringSslPemAndDerRoundTrip(): Unit {
        let pem = readText("testdata/x509/policy_leaf.pem")
        let cert = x509ParsePem(pem)

        @Assert(cert.serialHexLower(), "03")
        @Assert(cert.subject.commonName(), TEST_HOST_WWW)
        @Assert(cert.issuer.commonName(), "Policy Intermediate")
        @Assert(cert.signatureAlgorithmOid, X509_OID_ECDSA_WITH_SHA256)
        @Assert(cert.extensions.size > 0, true)

        let parsedFromDer = x509ParseDer(cert.der)
        @Assert(parsedFromDer.subject.commonName(), cert.subject.commonName())
        @Assert(parsedFromDer.issuer.commonName(), cert.issuer.commonName())

        let pemRoundTrip = cert.toPem()
        let certRoundTrip = x509ParsePem(pemRoundTrip)
        @Assert(certRoundTrip.der, cert.der)
    }

    @TestCase
    public func testParsePemChainAndBuildSimpleChain(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let pemBundle = leaf.toPem() + intermediate.toPem() + root.toPem()
        let parsed = x509ParsePemChain(pemBundle)
        @Assert(parsed.size, 3)

        let chain = x509BuildSimpleChain(leaf, [intermediate, root])
        @Assert(chain.size, 3)
        @Assert(chain[0].isSelfIssued(), false)
        @Assert(chain[2].isSelfIssued(), true)
    }

    @TestCase
    public func testGenerateSelfSignedRsaCertificateWithKeyUsage(): Unit {
        let privateKey = loadRsa2048PrivateKey()
        let config = X509SelfSignedConfig(
            "jinkui.local",
            serialNumber: [UInt8(0x01), UInt8(0x23), UInt8(0x45)],
            notBefore: "260101000000Z",
            notAfter: "270101000000Z",
            keyUsageMask: X509_KEY_USAGE_DIGITAL_SIGNATURE | X509_KEY_USAGE_KEY_ENCIPHERMENT
        )

        let cert = x509CreateSelfSignedRsaCertificate(config, privateKey)
        @Assert(cert.signatureAlgorithmOid, X509_OID_SHA256_WITH_RSA)
        @Assert(cert.subject.commonName(), "jinkui.local")
        @Assert(cert.issuer.commonName(), "jinkui.local")
        @Assert(cert.isSelfIssued(), true)

        let keyUsageExt = x509FindExtension(cert, X509_OID_KEY_USAGE) ?? throw Exception("missing keyUsage extension")
        let keyUsageMask = x509DecodeKeyUsageFromExtension(keyUsageExt)
        @Assert((keyUsageMask & X509_KEY_USAGE_DIGITAL_SIGNATURE) != 0, true)
        @Assert((keyUsageMask & X509_KEY_USAGE_KEY_ENCIPHERMENT) != 0, true)

        let parsedFromPem = x509ParsePem(cert.toPem())
        @Assert(parsedFromPem.der, cert.der)

        x509VerifySignatureWithIssuer(cert, cert)
    }

    @TestCase
    public func testGenerateSelfSignedEcP384CertificateWithKeyUsage(): Unit {
        let privateKey = EcPrivateKey(P384, BigNum.one())
        let config = X509SelfSignedConfig(
            "jinkui-p384.local",
            serialNumber: [UInt8(0x39)],
            notBefore: "260101000000Z",
            notAfter: "270101000000Z",
            keyUsageMask: X509_KEY_USAGE_DIGITAL_SIGNATURE | X509_KEY_USAGE_KEY_AGREEMENT
        )

        let cert = x509CreateSelfSignedEcCertificate(config, privateKey)
        @Assert(cert.signatureAlgorithmOid, X509_OID_ECDSA_WITH_SHA384)
        @Assert(cert.subject.commonName(), "jinkui-p384.local")
        @Assert(cert.issuer.commonName(), "jinkui-p384.local")
        @Assert(cert.isSelfIssued(), true)

        let keyUsageExt = x509FindExtension(cert, X509_OID_KEY_USAGE) ?? throw Exception("missing keyUsage extension")
        let keyUsageMask = x509DecodeKeyUsageFromExtension(keyUsageExt)
        @Assert((keyUsageMask & X509_KEY_USAGE_DIGITAL_SIGNATURE) != 0, true)
        @Assert((keyUsageMask & X509_KEY_USAGE_KEY_AGREEMENT) != 0, true)

        let parsedFromPem = x509ParsePem(cert.toPem())
        @Assert(parsedFromPem.der, cert.der)

        let extractedEcKey = x509ExtractEcPublicKey(cert)
        let expectedPublic = ecPublicFromPrivateKey(privateKey)
        @Assert(extractedEcKey.curve.toString(), "P-384")
        @Assert(extractedEcKey.x.toHex(), expectedPublic.x.toHex())
        @Assert(extractedEcKey.y.toHex(), expectedPublic.y.toHex())

        x509VerifySignatureWithIssuer(cert, cert)
    }

    @TestCase
    public func testVerifyBoringSslPolicyChain(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            validationTime: "230101000000Z"
        )
        let result = x509VerifyCertificateChain(leaf, policy)
        @Assert(result.chain.size, 3)
        @Assert(result.chain[0].subject.commonName(), TEST_HOST_WWW)
        @Assert(result.trustAnchor.subject.commonName(), "Policy Root")
    }

    @TestCase
    public func testVerifyChainBacktracksPastUntrustedCrossSignedCandidate(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let untrustedSameSubject = cloneWithDifferentDer(root)

        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate, untrustedSameSubject],
            validationTime: "230101000000Z"
        )
        let result = x509VerifyCertificateChain(leaf, policy)
        @Assert(result.chain.size, 3)
        @Assert(result.chain[2].der, root.der)
        @Assert(result.trustAnchor.der, root.der)
    }

    @TestCase
    public func testSystemTrustPemBundleHelpersAcceptExplicitBundlePath(): Unit {
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let paths = x509SystemTrustBundleCandidatePaths()
        @Assert(paths.size >= 0, true)

        let anchors = x509LoadSystemTrustAnchors(extraPemBundlePaths: ["testdata/x509/policy_root.pem"])
        @Assert(containsCertificateDer(anchors, root), true)

        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let policy = x509CreateSystemTrustPolicy(
            intermediates: [intermediate],
            extraPemBundlePaths: ["testdata/x509/policy_root.pem"],
            validationTime: "230101000000Z"
        )
        let result = x509VerifyCertificateChain(leaf, policy)
        @Assert(result.trustAnchor.der, root.der)
    }

    @TestCase
    public func testVerifyBoringSslPolicyChainWithFipsProfile(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            validationTime: "230101000000Z"
        )
        let profile = FipsProfile.phase1Default()
        let result = x509VerifyCertificateChainWithProfile(leaf, policy, profile)
        @Assert(result.chain.size, 3)
    }

    @TestCase
    public func testVerifyChainWithFipsProfileRejectsBlockedAlgorithms(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))
        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            validationTime: "230101000000Z"
        )

        let blockedEcdsa = FipsProfile.fromText("SHA-256\nRSA")
        try {
            _ = x509VerifyCertificateChainWithProfile(leaf, policy, blockedEcdsa)
            @Fail("ECDSA-signed chain should be rejected when ECDSA is blocked")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let blockedSha256 = FipsProfile.fromText("ECDSA\nRSA")
        try {
            _ = x509VerifyCertificateChainWithProfile(leaf, policy, blockedSha256)
            @Fail("SHA-256-signed chain should be rejected when SHA-256 is blocked")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }

    @TestCase
    public func testVerifyChainRejectsRevokedAndUnknownAnchor(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let revokedPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            validationTime: "230101000000Z",
            revokedSerialHexLower: ["03"]
        )
        try {
            _ = x509VerifyCertificateChain(leaf, revokedPolicy)
            @Fail("revoked certificate should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let unknownAnchorPolicy = X509VerificationPolicy(
            [makeUnrelatedTrustAnchor()],
            intermediates: [intermediate],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, unknownAnchorPolicy)
            @Fail("chain should be rejected without trusted root")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyChainRejectsTamperedSignature(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let badSignature = leaf.signatureValue.clone()
        badSignature[0] = UInt8(badSignature[0]) ^ UInt8(0x01)
        let tampered = X509Certificate(
            leaf.der,
            leaf.tbsDer,
            leaf.serialNumber,
            leaf.signatureAlgorithmOid,
            leaf.issuer,
            leaf.subject,
            leaf.notBefore,
            leaf.notAfter,
            leaf.subjectPublicKeyInfoDer,
            leaf.extensions,
            badSignature
        )

        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(tampered, policy)
            @Fail("tampered signature should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyChainRejectsIssuerWithoutBasicConstraints(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let intermediateNoBasicConstraints = cloneCertWithExtensions(
            intermediate,
            filterOutExtension(intermediate.extensions, X509_OID_BASIC_CONSTRAINTS)
        )

        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediateNoBasicConstraints],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, policy)
            @Fail("issuer without basicConstraints should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyChainRejectsIssuerWithCaFalse(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let leafBasicConstraints = x509FindExtension(leaf, X509_OID_BASIC_CONSTRAINTS) ?? throw Exception("leaf basicConstraints extension missing")
        let intermediateCaFalse = cloneCertWithExtensions(
            intermediate,
            replaceExtension(intermediate.extensions, leafBasicConstraints)
        )

        let policy = X509VerificationPolicy(
            [root],
            intermediates: [intermediateCaFalse],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, policy)
            @Fail("issuer with CA=false should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyChainRejectsPathLenViolation(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let rootPathLenZero = X509Extension(
            X509_OID_BASIC_CONSTRAINTS,
            true,
            [
                UInt8(0x30), UInt8(0x06),
                UInt8(0x01), UInt8(0x01), UInt8(0xff),
                UInt8(0x02), UInt8(0x01), UInt8(0x00)
            ]
        )
        let strictRoot = cloneCertWithExtensions(root, replaceExtension(root.extensions, rootPathLenZero))
        let policy = X509VerificationPolicy(
            [strictRoot],
            intermediates: [intermediate],
            validationTime: "230101000000Z"
        )

        try {
            _ = x509VerifyCertificateChain(leaf, policy)
            @Fail("pathLenConstraint should reject additional CA below issuer")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testRejectBrokenPem(): Unit {
        try {
            _ = x509ParsePem("-----BEGIN CERTIFICATE-----\nabc\n")
            @Fail("broken PEM should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testParseCrlAndVerifySignature(): Unit {
        let root = x509ParsePem(readText("testdata/x509/crl_test_root.pem"))
        let leaf = x509ParsePem(readText("testdata/x509/crl_test_leaf.pem"))
        let basicCrl = x509ParseCrlPem(readText("testdata/x509/crl_basic.pem"))
        let revokedCrl = x509ParseCrlPem(readText("testdata/x509/crl_revoked.pem"))

        @Assert(basicCrl.revokedSerialHexLower.size, 0)
        @Assert(revokedCrl.revokedSerialHexLower.size >= 1, true)
        @Assert(arrayContains(revokedCrl.revokedSerialHexLower, leaf.serialHexLower()), true)

        x509VerifyCrlSignatureWithIssuer(basicCrl, root)

        try {
            x509VerifyCrlSignatureWithIssuer(basicCrl, leaf)
            @Fail("CRL signature verification should fail with wrong issuer cert")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let keyUsageNoCrlSign = x509FindExtension(
            x509ParsePem(readText("testdata/x509/policy_leaf.pem")),
            X509_OID_KEY_USAGE
        ) ?? throw Exception("policy leaf keyUsage extension missing")
        let rootNoCrlSign = cloneCertWithExtensions(root, replaceExtension(root.extensions, keyUsageNoCrlSign))
        try {
            x509VerifyCrlSignatureWithIssuer(basicCrl, rootNoCrlSign)
            @Fail("CRL signature verification should fail when issuer keyUsage lacks CRL_SIGN")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyChainWithCrlRevocation(): Unit {
        let root = x509ParsePem(readText("testdata/x509/crl_test_root.pem"))
        let leaf = x509ParsePem(readText("testdata/x509/crl_test_leaf.pem"))
        let basicCrl = x509ParseCrlPem(readText("testdata/x509/crl_basic.pem"))
        let revokedCrl = x509ParseCrlPem(readText("testdata/x509/crl_revoked.pem"))
        let badIssuerCrl = x509ParseCrlPem(readText("testdata/x509/crl_bad_issuer.pem"))

        let okPolicy = X509VerificationPolicy(
            [root],
            crls: [basicCrl]
        )
        let okResult = x509VerifyCertificateChain(leaf, okPolicy)
        @Assert(okResult.chain.size, 2)

        let ignoredCrlPolicy = X509VerificationPolicy(
            [root],
            crls: [badIssuerCrl]
        )
        let ignoredResult = x509VerifyCertificateChain(leaf, ignoredCrlPolicy)
        @Assert(ignoredResult.chain.size, 2)

        let strictMissingCrlPolicy = X509VerificationPolicy(
            [root],
            requireCrlForAllIssuers: true
        )
        try {
            _ = x509VerifyCertificateChain(leaf, strictMissingCrlPolicy)
            @Fail("strict CRL policy should reject missing CRLs")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let strictBadIssuerPolicy = X509VerificationPolicy(
            [root],
            crls: [badIssuerCrl],
            requireCrlForAllIssuers: true
        )
        try {
            _ = x509VerifyCertificateChain(leaf, strictBadIssuerPolicy)
            @Fail("strict CRL policy should reject non-matching issuer CRL")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let revokedPolicy = X509VerificationPolicy(
            [root],
            crls: [revokedCrl]
        )
        try {
            _ = x509VerifyCertificateChain(leaf, revokedPolicy)
            @Fail("certificate should be revoked by CRL")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testDecodeCrlDistributionPointsAndPolicyGate(): Unit {
        let root = x509ParsePem(readText("testdata/x509/crl_test_root.pem"))
        let leaf = x509ParsePem(readText("testdata/x509/crl_test_leaf.pem"))
        let basicCrl = x509ParseCrlPem(readText("testdata/x509/crl_basic.pem"))

        let crlDpExt = createCrlDistributionPointsExtension("http://crl.example.test/root.crl")
        let points = x509DecodeCrlDistributionPointsFromExtension(crlDpExt)
        @Assert(points.size, 1)
        @Assert(points[0].fullNameUris.size, 1)
        @Assert(points[0].fullNameUris[0], "http://crl.example.test/root.crl")

        let leafWithCrlDp = cloneCertWithExtensions(leaf, replaceExtension(leaf.extensions, crlDpExt))
        let uris = x509ExtractCrlDistributionPointUris(leafWithCrlDp)
        @Assert(uris.size, 1)
        @Assert(uris[0], "http://crl.example.test/root.crl")

        let noDpUris = x509ExtractCrlDistributionPointUris(leaf)
        @Assert(noDpUris.size, 0)

        let strictByDpMissingCrl = X509VerificationPolicy(
            [root],
            requireCrlIfDistributionPointsPresent: true
        )
        let noDpResult = x509VerifyCertificateChain(leaf, strictByDpMissingCrl)
        @Assert(noDpResult.chain.size, 2)

        try {
            _ = x509VerifyCertificateChain(leafWithCrlDp, strictByDpMissingCrl)
            @Fail("DP-aware strict CRL policy should reject missing CRL")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let strictByDpWithCrl = X509VerificationPolicy(
            [root],
            crls: [basicCrl],
            requireCrlIfDistributionPointsPresent: true
        )
        let withCrlResult = x509VerifyCertificateChain(leafWithCrlDp, strictByDpWithCrl)
        @Assert(withCrlResult.chain.size, 2)
    }

    @TestCase
    public func testDecodeSubjectAndAuthorityKeyIdentifier(): Unit {
        let keyId = [UInt8(0x11), UInt8(0x22), UInt8(0x33), UInt8(0x44), UInt8(0x55)]
        let skiExt = createSubjectKeyIdentifierExtension(keyId)
        let akiExt = createAuthorityKeyIdentifierExtension(keyId)

        let decodedSki = x509DecodeSubjectKeyIdentifierFromExtension(skiExt)
        @Assert(decodedSki, keyId)

        let decodedAki = x509DecodeAuthorityKeyIdentifierFromExtension(akiExt)
        let decodedAkiKeyId = decodedAki.keyIdentifier ?? throw Exception("decoded AKI keyIdentifier missing")
        @Assert(decodedAkiKeyId, keyId)

        let leaf = x509ParsePem(readText("testdata/x509/crl_test_leaf.pem"))
        let leafWithAki = cloneCertWithExtensions(leaf, replaceExtension(leaf.extensions, akiExt))

        let extractedAki = x509ExtractAuthorityKeyIdentifier(leafWithAki) ?? throw Exception("leaf AKI not extracted")
        let extractedAkiKeyId = extractedAki.keyIdentifier ?? throw Exception("extracted AKI keyIdentifier missing")
        @Assert(extractedAkiKeyId, keyId)
    }

    @TestCase
    public func testDecodeExtendedKeyUsageAndSubjectAltName(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))

        let ekuExt = x509FindExtension(leaf, X509_OID_EXTENDED_KEY_USAGE) ?? throw Exception("leaf EKU extension missing")
        let ekuOids = x509DecodeExtendedKeyUsageFromExtension(ekuExt)
        @Assert(arrayContains(ekuOids, X509_OID_EKU_SERVER_AUTH), true)

        let sanExt = x509FindExtension(leaf, X509_OID_SUBJECT_ALT_NAME) ?? throw Exception("leaf SAN extension missing")
        let sanDns = x509DecodeSubjectAlternativeNameDnsFromExtension(sanExt)
        @Assert(sanDns.size, 1)
        @Assert(sanDns[0], TEST_HOST_WWW)

        let extractedEku = x509ExtractExtendedKeyUsageOids(leaf)
        @Assert(arrayContains(extractedEku, X509_OID_EKU_SERVER_AUTH), true)

        let extractedSanDns = x509ExtractSubjectAlternativeDnsNames(leaf)
        @Assert(extractedSanDns, sanDns)
    }

    @TestCase
    public func testVerifyChainWithLeafDnsAndEkuPolicy(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let strictPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafDnsName: TEST_HOST_WWW,
            requiredLeafExtendedKeyUsages: [X509_OID_EKU_SERVER_AUTH],
            validationTime: "230101000000Z"
        )
        let strictResult = x509VerifyCertificateChain(leaf, strictPolicy)
        @Assert(strictResult.chain.size, 3)

        let mismatchDnsPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafDnsName: TEST_HOST_API,
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, mismatchDnsPolicy)
            @Fail("leaf SAN mismatch should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let leafWithoutSan = cloneCertWithExtensions(leaf, filterOutExtension(leaf.extensions, X509_OID_SUBJECT_ALT_NAME))
        let cnFallbackPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafDnsName: TEST_HOST_WWW,
            validationTime: "230101000000Z"
        )
        let cnFallbackResult = x509VerifyCertificateChain(leafWithoutSan, cnFallbackPolicy)
        @Assert(cnFallbackResult.chain.size, 3)

        let leafWithoutEku = cloneCertWithExtensions(leaf, filterOutExtension(leaf.extensions, X509_OID_EXTENDED_KEY_USAGE))
        let requireEkuPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafExtendedKeyUsages: [X509_OID_EKU_SERVER_AUTH],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leafWithoutEku, requireEkuPolicy)
            @Fail("missing EKU extension should be rejected when EKU policy is required")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let requireClientAuthPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafExtendedKeyUsages: [X509_OID_EKU_CLIENT_AUTH],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, requireClientAuthPolicy)
            @Fail("missing clientAuth EKU should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testVerifyChainWithLeafKeyUsagePolicy(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let requireKeyCertSignPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafKeyUsageMask: X509_KEY_USAGE_KEY_CERT_SIGN,
            validationTime: "230101000000Z"
        )
        let requireKeyCertSignResult = x509VerifyCertificateChain(leaf, requireKeyCertSignPolicy)
        @Assert(requireKeyCertSignResult.chain.size, 3)

        let requireDigitalSignaturePolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafKeyUsageMask: X509_KEY_USAGE_DIGITAL_SIGNATURE,
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, requireDigitalSignaturePolicy)
            @Fail("missing digitalSignature keyUsage should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let leafWithoutKeyUsage = cloneCertWithExtensions(leaf, filterOutExtension(leaf.extensions, X509_OID_KEY_USAGE))
        try {
            _ = x509VerifyCertificateChain(leafWithoutKeyUsage, requireKeyCertSignPolicy)
            @Fail("missing keyUsage extension should be rejected when keyUsage policy is required")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testDecodeCertificatePoliciesAndExtract(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let policiesExt = x509FindExtension(leaf, X509_OID_CERTIFICATE_POLICIES) ?? throw Exception("leaf certificatePolicies extension missing")
        let decodedPolicyOids = x509DecodeCertificatePoliciesFromExtension(policiesExt)
        @Assert(arrayContains(decodedPolicyOids, "1.2.840.113554.4.1.72585.2.1"), true)
        @Assert(arrayContains(decodedPolicyOids, "1.2.840.113554.4.1.72585.2.2"), true)

        let extractedPolicyOids = x509ExtractCertificatePolicyOids(leaf)
        @Assert(arrayContains(extractedPolicyOids, "1.2.840.113554.4.1.72585.2.1"), true)
        @Assert(arrayContains(extractedPolicyOids, "1.2.840.113554.4.1.72585.2.2"), true)
    }

    @TestCase
    public func testVerifyChainWithLeafCertificatePolicyConstraints(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let intermediate = x509ParsePem(readText("testdata/x509/policy_intermediate.pem"))
        let root = x509ParsePem(readText("testdata/x509/policy_root.pem"))

        let requiredOnePolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafCertificatePolicies: ["1.2.840.113554.4.1.72585.2.1"],
            validationTime: "230101000000Z"
        )
        let okOne = x509VerifyCertificateChain(leaf, requiredOnePolicy)
        @Assert(okOne.chain.size, 3)

        let requiredBothPolicies = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafCertificatePolicies: ["1.2.840.113554.4.1.72585.2.1", "1.2.840.113554.4.1.72585.2.2"],
            validationTime: "230101000000Z"
        )
        let okBoth = x509VerifyCertificateChain(leaf, requiredBothPolicies)
        @Assert(okBoth.chain.size, 3)

        let requiredUnknownPolicy = X509VerificationPolicy(
            [root],
            intermediates: [intermediate],
            requiredLeafCertificatePolicies: ["1.3.6.1.4.1.55555.1.1"],
            validationTime: "230101000000Z"
        )
        try {
            _ = x509VerifyCertificateChain(leaf, requiredUnknownPolicy)
            @Fail("missing required certificate policy OID should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let leafWithoutPolicies = cloneCertWithExtensions(leaf, filterOutExtension(leaf.extensions, X509_OID_CERTIFICATE_POLICIES))
        try {
            _ = x509VerifyCertificateChain(leafWithoutPolicies, requiredOnePolicy)
            @Fail("missing certificatePolicies extension should be rejected when policy is required")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testIssuerSelectionPrefersAkiSkiMatch(): Unit {
        let root = x509ParsePem(readText("testdata/x509/crl_test_root.pem"))
        let leaf = x509ParsePem(readText("testdata/x509/crl_test_leaf.pem"))

        let badKeyId = [UInt8(0xaa), UInt8(0xbb), UInt8(0xcc), UInt8(0xdd)]
        let goodKeyId = [UInt8(0x10), UInt8(0x20), UInt8(0x30), UInt8(0x40)]

        let wrongIssuer = cloneCertWithExtensions(root, replaceExtension(root.extensions, createSubjectKeyIdentifierExtension(badKeyId)))
        let rightIssuer = cloneCertWithExtensions(root, replaceExtension(root.extensions, createSubjectKeyIdentifierExtension(goodKeyId)))
        let leafWithAki = cloneCertWithExtensions(leaf, replaceExtension(leaf.extensions, createAuthorityKeyIdentifierExtension(goodKeyId)))

        let selectPolicy = X509VerificationPolicy(
            [wrongIssuer, rightIssuer],
            requireAuthorityKeyIdentifierMatch: true
        )
        let selectedResult = x509VerifyCertificateChain(leafWithAki, selectPolicy)
        @Assert(selectedResult.chain.size, 2)
        let selectedIssuerSki = x509ExtractSubjectKeyIdentifier(selectedResult.chain[1]) ?? throw Exception("selected issuer SKI missing")
        @Assert(selectedIssuerSki, goodKeyId)

        let rejectPolicy = X509VerificationPolicy(
            [wrongIssuer],
            requireAuthorityKeyIdentifierMatch: true
        )
        try {
            _ = x509VerifyCertificateChain(leafWithAki, rejectPolicy)
            @Fail("AKI/SKI mismatch should be rejected when strict match is enabled")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testCrlAkiSkiSelectionAndStrictMatch(): Unit {
        let root = x509ParsePem(readText("testdata/x509/crl_test_root.pem"))
        let leaf = x509ParsePem(readText("testdata/x509/crl_test_leaf.pem"))
        let basicCrl = x509ParseCrlPem(readText("testdata/x509/crl_basic.pem"))

        let goodKeyId = [UInt8(0x01), UInt8(0x10), UInt8(0x20), UInt8(0x30)]
        let badKeyId = [UInt8(0x99), UInt8(0x88), UInt8(0x77), UInt8(0x66)]

        let issuerWithSki = cloneCertWithExtensions(root, replaceExtension(root.extensions, createSubjectKeyIdentifierExtension(goodKeyId)))
        let leafWithAki = cloneCertWithExtensions(leaf, replaceExtension(leaf.extensions, createAuthorityKeyIdentifierExtension(goodKeyId)))
        let crlWithGoodAki = cloneCrlWithAuthorityKeyIdentifier(
            basicCrl,
            Some(X509AuthorityKeyIdentifier(keyIdentifier: Some(goodKeyId)))
        )
        let crlWithBadAki = cloneCrlWithAuthorityKeyIdentifier(
            basicCrl,
            Some(X509AuthorityKeyIdentifier(keyIdentifier: Some(badKeyId)))
        )

        let selectPolicy = X509VerificationPolicy(
            [issuerWithSki],
            crls: [crlWithBadAki, crlWithGoodAki],
            requireCrlForAllIssuers: true,
            requireCrlAuthorityKeyIdentifierMatch: true
        )
        let selectResult = x509VerifyCertificateChain(leafWithAki, selectPolicy)
        @Assert(selectResult.chain.size, 2)

        let strictBadOnlyPolicy = X509VerificationPolicy(
            [issuerWithSki],
            crls: [crlWithBadAki],
            requireCrlForAllIssuers: true,
            requireCrlAuthorityKeyIdentifierMatch: true
        )
        try {
            _ = x509VerifyCertificateChain(leafWithAki, strictBadOnlyPolicy)
            @Fail("strict CRL AKI/SKI policy should reject when matching CRL is unavailable")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let issuerWithoutSki = cloneCertWithExtensions(root, filterOutExtension(root.extensions, X509_OID_SUBJECT_KEY_IDENTIFIER))
        try {
            x509VerifyCrlSignatureWithIssuer(
                crlWithGoodAki,
                issuerWithoutSki,
                requireAuthorityKeyIdentifierMatch: true
            )
            @Fail("strict CRL AKI/SKI check should reject issuer without SKI")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testExtractPublicKeysFromCertificates(): Unit {
        let leaf = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let ecPublic = x509ExtractEcPublicKey(leaf)
        @Assert(ecPublic.curve.toString(), "P-256")
        @Assert(ecPublic.x.isZero(), false)
        @Assert(ecPublic.y.isZero(), false)

        let rsaPrivate = loadRsa2048PrivateKey()
        let rsaCert = x509CreateSelfSignedRsaCertificate(X509SelfSignedConfig("rsa.extract.local"), rsaPrivate)
        let rsaPublic = x509ExtractRsaPublicKey(rsaCert)
        @Assert(rsaPublic.modulus.toHex(), rsaPrivate.publicKey.modulus.toHex())
        @Assert(rsaPublic.exponent.toHex(), rsaPrivate.publicKey.exponent.toHex())
    }

    @TestCase
    public func testParseRsaPrivateKeysPkcs1AndPkcs8(): Unit {
        let digest = sha256("stage5.4-rsa-key-parse".toArray())

        let pkcs1Pem = readText("testdata/x509/rsa512_pkcs1.pem")
        let pkcs1Key = x509ParseRsaPrivateKeyPkcs1Pem(pkcs1Pem)
        let sig1 = rsaSignPkcs1v15(pkcs1Key, digest)
        @Assert(rsaVerifyPkcs1v15(pkcs1Key.publicKey, digest, sig1), true)

        let pkcs1Der = decodePemBlock(pkcs1Pem, "RSA PRIVATE KEY")
        let pkcs1KeyDer = x509ParseRsaPrivateKeyPkcs1Der(pkcs1Der)
        let sig1Der = rsaSignPkcs1v15(pkcs1KeyDer, digest)
        @Assert(rsaVerifyPkcs1v15(pkcs1KeyDer.publicKey, digest, sig1Der), true)

        let pkcs8Pem = readText("testdata/x509/rsa_2048_pkcs8.pem")
        let pkcs8Key = x509ParseRsaPrivateKeyPkcs8Pem(pkcs8Pem)
        let sig2 = rsaSignPkcs1v15(pkcs8Key, digest)
        @Assert(rsaVerifyPkcs1v15(pkcs8Key.publicKey, digest, sig2), true)

        let pkcs8Der = decodePemBlock(pkcs8Pem, "PRIVATE KEY")
        let pkcs8KeyDer = x509ParseRsaPrivateKeyPkcs8Der(pkcs8Der)
        let sig2Der = rsaSignPkcs1v15(pkcs8KeyDer, digest)
        @Assert(rsaVerifyPkcs1v15(pkcs8KeyDer.publicKey, digest, sig2Der), true)
    }

    @TestCase
    public func testParseEcPrivateKeyPkcs8AndSignVerify(): Unit {
        let keyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")
        let privateKey = x509ParseEcPrivateKeyPkcs8Pem(keyPem)
        @Assert(privateKey.curve.toString(), "P-256")

        let keyDer = decodePemBlock(keyPem, "PRIVATE KEY")
        let privateKeyDer = x509ParseEcPrivateKeyPkcs8Der(keyDer)
        @Assert(privateKeyDer.curve.toString(), "P-256")
        @Assert(privateKeyDer.scalar.isZero(), false)

        let leafCert = x509ParsePem(readText("testdata/x509/policy_leaf.pem"))
        let publicKey = x509ExtractEcPublicKey(leafCert)
        let digest = sha256("stage5.4-ec-key-parse".toArray())
        let (r, s) = ecdsaSign(privateKeyDer, digest)
        @Assert(ecdsaVerify(publicKey, digest, r, s), true)
    }

    @TestCase
    public func testVerifyChainWithFipsProfileRejectsWeakRsaKey(): Unit {
        let rsa512Key = x509ParseRsaPrivateKeyPkcs1Pem(readText("testdata/x509/rsa512_pkcs1.pem"))
        let cert = x509CreateSelfSignedRsaCertificate(
            X509SelfSignedConfig(
                "weak-rsa.local",
                notBefore: "260101000000Z",
                notAfter: "270101000000Z"
            ),
            rsa512Key
        )

        let policy = X509VerificationPolicy(
            [cert],
            validationTime: "260201000000Z"
        )
        let profile = FipsProfile.phase1Default()
        try {
            _ = x509VerifyCertificateChainWithProfile(cert, policy, profile)
            @Fail("RSA-512 certificate should be rejected by FIPS profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }
}

private func readText(path: String): String {
    if (!exists(path)) {
        throw Exception("file not found: ${path}")
    }
    String.fromUtf8(File.readFrom(path))
}

private func cloneWithDifferentDer(cert: X509Certificate): X509Certificate {
    let der = cert.der.clone()
    der[der.size - 1] = UInt8(der[der.size - 1]) ^ UInt8(0x01)
    X509Certificate(
        der,
        cert.tbsDer,
        cert.serialNumber,
        cert.signatureAlgorithmOid,
        cert.issuer,
        cert.subject,
        cert.notBefore,
        cert.notAfter,
        cert.subjectPublicKeyInfoDer,
        cert.extensions,
        cert.signatureValue
    )
}

private func makeUnrelatedTrustAnchor(): X509Certificate {
    x509CreateSelfSignedEcCertificate(
        X509SelfSignedConfig(
            "unrelated-trust-anchor.local",
            serialNumber: [UInt8(0x7F)],
            notBefore: "220101000000Z",
            notAfter: "300101000000Z"
        ),
        EcPrivateKey(P256, BigNum.one())
    )
}

private func containsCertificateDer(certs: Array<X509Certificate>, expected: X509Certificate): Bool {
    for (cert in certs) {
        if (cert.der == expected.der) {
            return true
        }
    }
    false
}

private func loadRsa2048PrivateKey(): RsaPrivateKey {
    let vectors = parseKeyValueVectors("testdata/stage3/rsa_params_sample.txt")
    for (item in vectors) {
        if ((item.get("Vector") ?? "") == "RSA-2048") {
            return rsaPrivateKeyFromHex(
                requireValue(item, "N"),
                requireValue(item, "E"),
                requireValue(item, "D")
            )
        }
    }
    throw Exception("RSA-2048 vector not found")
}

private func parseKeyValueVectors(path: String): Array<X509KeyValueVector> {
    let content = readText(path).replace("\r", "\n")
    let lines = content.split('\n')

    let vectors = ArrayList<X509KeyValueVector>()
    var current = HashMap<String, String>()

    for (rawLine in lines) {
        let line = rawLine.trimAscii()
        if (line.size == 0) {
            if (current.size > 0) {
                vectors.add(copyMap(current))
                current = HashMap<String, String>()
            }
            continue
        }
        if (line.startsWith("#")) {
            continue
        }
        if (let Some(pos) <- line.indexOf("=")) {
            let key = line[..pos].trimAscii()
            let value = line[(pos + 1)..].trimAscii()
            current.add(key, value)
        }
    }

    if (current.size > 0) {
        vectors.add(copyMap(current))
    }
    vectors.toArray()
}

private func copyMap(source: HashMap<String, String>): HashMap<String, String> {
    let out = HashMap<String, String>()
    let iter = source.iterator()
    while (let Some((k, v)) <- iter.next()) {
        out.add(k, v)
    }
    out
}

private func requireValue(values: HashMap<String, String>, key: String): String {
    values.get(key) ?? throw Exception("missing key: ${key}")
}

private func cloneCertWithExtensions(cert: X509Certificate, extensions: Array<X509Extension>): X509Certificate {
    X509Certificate(
        cert.der,
        cert.tbsDer,
        cert.serialNumber,
        cert.signatureAlgorithmOid,
        cert.issuer,
        cert.subject,
        cert.notBefore,
        cert.notAfter,
        cert.subjectPublicKeyInfoDer,
        extensions,
        cert.signatureValue
    )
}

private func cloneCrlWithAuthorityKeyIdentifier(
    crl: X509Crl,
    authorityKeyIdentifier: ?X509AuthorityKeyIdentifier
): X509Crl {
    X509Crl(
        crl.der,
        crl.tbsDer,
        crl.signatureAlgorithmOid,
        crl.issuer,
        crl.thisUpdate,
        crl.nextUpdate,
        crl.revokedSerialHexLower,
        crl.signatureValue,
        authorityKeyIdentifier: authorityKeyIdentifier
    )
}

private func filterOutExtension(extensions: Array<X509Extension>, targetOid: String): Array<X509Extension> {
    let out = ArrayList<X509Extension>()
    for (ext in extensions) {
        if (ext.oid != targetOid) {
            out.add(ext)
        }
    }
    out.toArray()
}

private func replaceExtension(extensions: Array<X509Extension>, replacement: X509Extension): Array<X509Extension> {
    let out = ArrayList<X509Extension>()
    var replaced = false
    for (ext in extensions) {
        if (ext.oid == replacement.oid) {
            out.add(replacement)
            replaced = true
        } else {
            out.add(ext)
        }
    }
    if (!replaced) {
        out.add(replacement)
    }
    out.toArray()
}

private func createCrlDistributionPointsExtension(uri: String): X509Extension {
    let uriBytes = uri.toArray()
    if (uriBytes.size == 0 || uriBytes.size > 127) {
        throw Exception("CRL DP URI length must be 1..127 bytes for test vector helper")
    }

    let uriGeneralName = ArrayList<Byte>()
    uriGeneralName.add(UInt8(0x86))
    uriGeneralName.add(UInt8(uriBytes.size))
    for (b in uriBytes) {
        uriGeneralName.add(b)
    }

    let fullName = ArrayList<Byte>()
    fullName.add(UInt8(0xa0))
    fullName.add(UInt8(uriGeneralName.size))
    appendAllBytes(fullName, uriGeneralName.toArray())

    let distributionPoint = ArrayList<Byte>()
    distributionPoint.add(UInt8(0xa0))
    distributionPoint.add(UInt8(fullName.size))
    appendAllBytes(distributionPoint, fullName.toArray())

    let distributionPointSequence = ArrayList<Byte>()
    distributionPointSequence.add(UInt8(0x30))
    distributionPointSequence.add(UInt8(distributionPoint.size))
    appendAllBytes(distributionPointSequence, distributionPoint.toArray())

    let pointsSequence = ArrayList<Byte>()
    pointsSequence.add(UInt8(0x30))
    pointsSequence.add(UInt8(distributionPointSequence.size))
    appendAllBytes(pointsSequence, distributionPointSequence.toArray())

    X509Extension(X509_OID_CRL_DISTRIBUTION_POINTS, false, pointsSequence.toArray())
}

private func createSubjectKeyIdentifierExtension(keyId: Array<Byte>): X509Extension {
    if (keyId.size == 0 || keyId.size > 127) {
        throw Exception("subjectKeyIdentifier keyId length must be 1..127 bytes for test helper")
    }

    let value = ArrayList<Byte>()
    value.add(UInt8(0x04))
    value.add(UInt8(keyId.size))
    appendAllBytes(value, keyId)
    X509Extension(X509_OID_SUBJECT_KEY_IDENTIFIER, false, value.toArray())
}

private func createAuthorityKeyIdentifierExtension(keyId: Array<Byte>): X509Extension {
    if (keyId.size == 0 || keyId.size > 127) {
        throw Exception("authorityKeyIdentifier keyId length must be 1..127 bytes for test helper")
    }

    let keyIdentifier = ArrayList<Byte>()
    keyIdentifier.add(UInt8(0x80))
    keyIdentifier.add(UInt8(keyId.size))
    appendAllBytes(keyIdentifier, keyId)

    let sequence = ArrayList<Byte>()
    sequence.add(UInt8(0x30))
    sequence.add(UInt8(keyIdentifier.size))
    appendAllBytes(sequence, keyIdentifier.toArray())

    X509Extension(X509_OID_AUTHORITY_KEY_IDENTIFIER, false, sequence.toArray())
}

private func appendAllBytes(out: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    for (b in bytes) {
        out.add(b)
    }
}

private func decodePemBlock(pemText: String, blockType: String): Array<Byte> {
    let beginMarker = "-----BEGIN ${blockType}-----"
    let endMarker = "-----END ${blockType}-----"
    let lines = pemText.replace("\r", "\n").split('\n')

    var collecting = false
    var body = ""
    var seen = 0
    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed == beginMarker) {
            collecting = true
            body = ""
            continue
        }
        if (trimmed == endMarker) {
            collecting = false
            seen += 1
            continue
        }
        if (collecting && trimmed.size > 0) {
            body += trimmed
        }
    }

    if (seen != 1) {
        throw Exception("invalid PEM block count for ${blockType}")
    }
    base64Decode(body)
}

private func base64Decode(text: String): Array<Byte> {
    let clean = text.trimAscii().replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "")
    if (clean.size == 0) {
        return []
    }
    if ((clean.size % 4) != 0) {
        throw Exception("invalid base64 length")
    }

    var pad = 0
    var idx = clean.size - 1
    while (idx >= 0 && clean[idx] == b'=') {
        pad += 1
        idx -= 1
    }
    let outLen = clean.size / 4 * 3 - pad
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
        let v2 = UInt32(if (c2 < 0) { 0 } else { c2 })
        let v3 = UInt32(if (c3 < 0) { 0 } else { c3 })
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
    throw Exception("invalid base64 character")
}

private func arrayContains(values: Array<String>, expected: String): Bool {
    for (item in values) {
        if (item == expected) {
            return true
        }
    }
    false
}
