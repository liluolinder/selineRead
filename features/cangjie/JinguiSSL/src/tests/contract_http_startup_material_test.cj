package jinguissl.tests

import std.fs.File
import jinguissl.contract.*

private let TEST_HOST_API: String = "api.policy.example"
private let TEST_HOST_API_UPPER_PADDED: String = "  API.POLICY.EXAMPLE  "
private let TEST_HOST_WWW: String = "www.policy.example"
private let TEST_HOST_WWW_UPPER: String = "WWW.POLICY.EXAMPLE"
private let TEST_HOST_WWW_LOWER_PADDED: String = "  www.policy.example  "
private let TEST_HOST_WWW_UPPER_PADDED: String = "  WWW.POLICY.EXAMPLE  "
private let LIVE_SOURCE_ROOT: String = ""

@Test
public class ContractHttpStartupMaterialTestSuite {
    @TestCase
    public func testContractValidateTlsHttpNegotiationPolicy(): Unit {
        let result = contractValidateTlsHttpNegotiationPolicy(
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_API_UPPER_PADDED, TEST_HOST_API, TEST_HOST_WWW_UPPER],
                alpnPreference: [" H2 ", "http/1.1", "h2"]
            )
        )
        @Assert(result.requireServerName, true)
        @Assert(result.normalizedAllowedServerNames, [TEST_HOST_API, TEST_HOST_WWW])
        @Assert(result.normalizedAlpnPreference, ["h2", "http/1.1"])

        let defaults = contractValidateTlsHttpNegotiationPolicy(
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: false
            )
        )
        @Assert(defaults.requireServerName, false)
        @Assert(defaults.normalizedAllowedServerNames.size, 0)
        @Assert(defaults.normalizedAlpnPreference, ["h2", "http/1.1"])
    }

    @TestCase
    public func testContractTryValidateTlsHttpNegotiationPolicyOutcome(): Unit {
        let ok = contractTryValidateTlsHttpNegotiationPolicy(
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_API],
                alpnPreference: ["h2"]
            )
        )
        @Assert(ok.ok, true)
        match (ok.result) {
            case Some(value) =>
                @Assert(value.normalizedAllowedServerNames, [TEST_HOST_API])
            case None =>
                @Fail("TLS HTTP policy success outcome should carry result")
        }

        let failed = contractTryValidateTlsHttpNegotiationPolicy(
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: ["bad host name"],
                alpnPreference: ["h2"]
            )
        )
        @Assert(failed.ok, false)
        match (failed.code) {
            case Some(value) => @Assert(value.toString(), "BAD_INPUT")
            case None => @Fail("TLS HTTP policy failed outcome should carry contract code")
        }
        match (failed.igniteCode) {
            case Some(value) => @Assert(value.toString(), "BAD_ENVELOPE")
            case None => @Fail("TLS HTTP policy failed outcome should carry ignite code")
        }
    }

    @TestCase
    public func testContractValidateHttpServerTlsConfigInput(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let certChainPem = "${leafPem}\n${intermediatePem}"
        let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")

        let result = contractValidateHttpServerTlsConfigInput(
            certChainPem,
            leafKeyPem,
            alpnProtocols: [" H2 ", "http/1.1", "h2"],
            requireHttp2Alpn: true
        )
        @Assert(result.certificateChainLength, 2)
        @Assert(result.normalizedAlpnProtocols, ["h2", "http/1.1"])
        @Assert(result.keyAlgorithm == "RSA" || result.keyAlgorithm == "EC", true)

        let http1Only = contractValidateHttpServerTlsConfigInput(
            certChainPem,
            leafKeyPem,
            alpnProtocols: ["http/1.1"],
            requireHttp2Alpn: false
        )
        @Assert(http1Only.normalizedAlpnProtocols, ["http/1.1"])

        try {
            _ = contractValidateHttpServerTlsConfigInput(
                certChainPem,
                leafKeyPem,
                alpnProtocols: ["http/1.1"],
                requireHttp2Alpn: true
            )
            @Fail("missing h2 ALPN should fail when requireHttp2Alpn is true")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }

        let wrongKeyPem = readText("testdata/x509/rsa_2048_pkcs8.pem")
        try {
            _ = contractValidateHttpServerTlsConfigInput(
                certChainPem,
                wrongKeyPem,
                alpnProtocols: ["h2", "http/1.1"],
                requireHttp2Alpn: true
            )
            @Fail("certificate and private key mismatch should fail")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "VERIFY_FAILED")
        }
    }

    @TestCase
    public func testContractTryValidateHttpServerTlsConfigInputOutcome(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let certChainPem = "${leafPem}\n${intermediatePem}"
        let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")

        let ok = contractTryValidateHttpServerTlsConfigInput(
            certChainPem,
            leafKeyPem,
            alpnProtocols: ["h2", "http/1.1"],
            requireHttp2Alpn: true
        )
        @Assert(ok.ok, true)
        match (ok.result) {
            case Some(value) =>
                @Assert(value.certificateChainLength, 2)
            case None =>
                @Fail("TLS config success outcome should carry result")
        }

        let failed = contractTryValidateHttpServerTlsConfigInput(
            certChainPem,
            leafKeyPem,
            alpnProtocols: ["http/1.1"],
            requireHttp2Alpn: true
        )
        @Assert(failed.ok, false)
        match (failed.code) {
            case Some(value) => @Assert(value.toString(), "BAD_INPUT")
            case None => @Fail("TLS config failed outcome should carry contract code")
        }
        match (failed.igniteCode) {
            case Some(value) => @Assert(value.toString(), "BAD_ENVELOPE")
            case None => @Fail("TLS config failed outcome should carry ignite code")
        }
    }

    @TestCase
    public func testContractPrepareHttpServerTlsMaterial(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let certChainPem = "${leafPem}\n${intermediatePem}"
        let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")

        let material = contractPrepareHttpServerTlsMaterial(
            certChainPem,
            leafKeyPem,
            alpnProtocols: [" H2 ", "http/1.1", "h2"],
            requireHttp2Alpn: true
        )
        @Assert(material.validation.certificateChainLength, 2)
        @Assert(material.validation.normalizedAlpnProtocols, ["h2", "http/1.1"])
        @Assert(material.certificateChainPemBlocks.size, 2)
        @Assert(material.certificateChainPemBundle().contains("BEGIN CERTIFICATE"), true)
        @Assert(material.leafCertificatePem().contains("BEGIN CERTIFICATE"), true)
        @Assert(material.privateKeyPem.contains("BEGIN PRIVATE KEY"), true)

        let failed = contractTryPrepareHttpServerTlsMaterial(
            certChainPem,
            leafKeyPem,
            alpnProtocols: ["http/1.1"],
            requireHttp2Alpn: true
        )
        @Assert(failed.ok, false)
        match (failed.code) {
            case Some(value) => @Assert(value.toString(), "BAD_INPUT")
            case None => @Fail("TLS server material failed outcome should carry contract code")
        }
    }

    @TestCase
    public func testContractHttpServerTlsRequestFacades(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let certChainPem = "${leafPem}\n${intermediatePem}"
        let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")

        let request = ContractHttpServerTlsConfigRequest(
            certChainPem,
            leafKeyPem,
            alpnProtocols: [" H2 ", "http/1.1", "h2"],
            requireHttp2Alpn: true
        )
        let validated = contractValidateHttpServerTlsConfigRequest(request)
        @Assert(validated.certificateChainLength, 2)
        @Assert(validated.normalizedAlpnProtocols, ["h2", "http/1.1"])

        let prepared = contractPrepareHttpServerTlsMaterialRequest(request)
        @Assert(prepared.validation.keyAlgorithm == "RSA" || prepared.validation.keyAlgorithm == "EC", true)
        @Assert(prepared.certificateChainPemBlocks.size, 2)

        let failed = contractTryPrepareHttpServerTlsMaterialRequest(
            ContractHttpServerTlsConfigRequest(
                certChainPem,
                leafKeyPem,
                alpnProtocols: ["http/1.1"],
                requireHttp2Alpn: true
            )
        )
        @Assert(failed.ok, false)
        match (failed.code) {
            case Some(value) => @Assert(value.toString(), "BAD_INPUT")
            case None => @Fail("request-style TLS server material failure should carry contract code")
        }
    }

    @TestCase
    public func testContractValidateHttpClientTlsConfigInput(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let rootPem = readText("testdata/x509/policy_root.pem")
        let (derPin, _spkiPin) = contractComputeLeafPinsFromPem(leafPem)

        let result = contractValidateHttpClientTlsConfigInput(
            rootPem,
            intermediatesPemBundle: intermediatePem,
            hostname: TEST_HOST_WWW_UPPER_PADDED,
            validationTime: "230101000000Z",
            pinPolicy: ContractX509PinPolicy(allowedLeafDerSha256: [derPin]),
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_WWW_LOWER_PADDED, TEST_HOST_WWW_UPPER],
                alpnPreference: [" H2 ", "http/1.1"]
            )
        )
        @Assert(result.trustAnchorCount, 1)
        @Assert(result.intermediateCount, 1)
        @Assert(result.normalizedHostname, TEST_HOST_WWW)
        @Assert(result.hasValidationTimeOverride, true)
        @Assert(result.allowedLeafDerPinCount, 1)
        @Assert(result.allowedLeafSpkiPinCount, 0)
        @Assert(result.negotiationPolicy.normalizedAllowedServerNames, [TEST_HOST_WWW])
        @Assert(result.negotiationPolicy.normalizedAlpnPreference, ["h2", "http/1.1"])

        try {
            _ = contractValidateHttpClientTlsConfigInput(
                rootPem,
                hostname: TEST_HOST_WWW,
                policy: ContractTlsHttpNegotiationPolicy(
                    requireServerName: true,
                    allowedServerNames: [TEST_HOST_API]
                )
            )
            @Fail("hostname outside allowed server names should fail")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractPrepareHttpClientTlsTrustMaterial(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let rootPem = readText("testdata/x509/policy_root.pem")
        let (derPin, _spkiPin) = contractComputeLeafPinsFromPem(leafPem)

        let material = contractPrepareHttpClientTlsTrustMaterial(
            rootPem,
            intermediatesPemBundle: intermediatePem,
            hostname: TEST_HOST_WWW_UPPER_PADDED,
            validationTime: "230101000000Z",
            pinPolicy: ContractX509PinPolicy(allowedLeafDerSha256: [derPin]),
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_WWW_LOWER_PADDED, TEST_HOST_WWW_UPPER],
                alpnPreference: [" H2 ", "http/1.1"]
            )
        )
        @Assert(material.validation.trustAnchorCount, 1)
        @Assert(material.validation.intermediateCount, 1)
        @Assert(material.validation.normalizedHostname, TEST_HOST_WWW)
        @Assert(material.trustAnchorPemBlocks.size, 1)
        @Assert(material.intermediatePemBlocks.size, 1)
        @Assert(material.trustAnchorsPemBundle().contains("BEGIN CERTIFICATE"), true)
        @Assert(material.intermediatesPemBundle().contains("BEGIN CERTIFICATE"), true)
        @Assert(material.pinPolicy.allowedLeafDerSha256.size, 1)
        @Assert(material.validation.negotiationPolicy.normalizedAlpnPreference, ["h2", "http/1.1"])

        let failed = contractTryPrepareHttpClientTlsTrustMaterial(
            rootPem,
            hostname: TEST_HOST_WWW,
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_API]
            )
        )
        @Assert(failed.ok, false)
        match (failed.code) {
            case Some(value) => @Assert(value.toString(), "BAD_INPUT")
            case None => @Fail("TLS client material failed outcome should carry contract code")
        }
    }

    @TestCase
    public func testContractTryValidateHttpClientTlsConfigInputOutcome(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let rootPem = readText("testdata/x509/policy_root.pem")
        let (_derPin, spkiPin) = contractComputeLeafPinsFromPem(leafPem)

        let ok = contractTryValidateHttpClientTlsConfigInput(
            rootPem,
            intermediatesPemBundle: intermediatePem,
            hostname: TEST_HOST_WWW,
            validationTime: "230101000000Z",
            pinPolicy: ContractX509PinPolicy(allowedLeafSpkiSha256: [spkiPin]),
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_WWW],
                alpnPreference: ["h2"]
            )
        )
        @Assert(ok.ok, true)
        match (ok.result) {
            case Some(value) =>
                @Assert(value.allowedLeafSpkiPinCount, 1)
            case None =>
                @Fail("TLS client config success outcome should carry result")
        }

        let failed = contractTryValidateHttpClientTlsConfigInput(
            rootPem,
            hostname: "",
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true
            )
        )
        @Assert(failed.ok, false)
        match (failed.code) {
            case Some(value) => @Assert(value.toString(), "BAD_INPUT")
            case None => @Fail("TLS client config failed outcome should carry contract code")
        }
        match (failed.igniteCode) {
            case Some(value) => @Assert(value.toString(), "BAD_ENVELOPE")
            case None => @Fail("TLS client config failed outcome should carry ignite code")
        }
    }

    @TestCase
    public func testContractHttpClientTlsRequestFacades(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let rootPem = readText("testdata/x509/policy_root.pem")
        let chainPem = "${leafPem}\n${intermediatePem}"
        let (_derPin, spkiPin) = contractComputeLeafPinsFromPem(leafPem)

        let trustRequest = ContractHttpClientTlsTrustRequest(
            rootPem,
            intermediatesPemBundle: intermediatePem,
            hostname: TEST_HOST_WWW_UPPER_PADDED,
            validationTime: "230101000000Z",
            pinPolicy: ContractX509PinPolicy(allowedLeafSpkiSha256: [spkiPin]),
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: [TEST_HOST_WWW_LOWER_PADDED],
                alpnPreference: [" H2 ", "http/1.1"]
            )
        )

        let validated = contractValidateHttpClientTlsTrustRequest(trustRequest)
        @Assert(validated.normalizedHostname, TEST_HOST_WWW)
        @Assert(validated.negotiationPolicy.normalizedAlpnPreference, ["h2", "http/1.1"])

        let material = contractPrepareHttpClientTlsTrustMaterialRequest(trustRequest)
        @Assert(material.trustAnchorPemBlocks.size, 1)
        @Assert(material.intermediatePemBlocks.size, 1)
        @Assert(material.pinPolicy.allowedLeafSpkiSha256.size, 1)

        let failed = contractTryVerifyServerCertificateChainPem(
            chainPem,
            rootPem,
            intermediatesPemBundle: intermediatePem,
            hostname: TEST_HOST_API,
            validationTime: "230101000000Z",
            pinPolicy: ContractX509PinPolicy(allowedLeafSpkiSha256: [spkiPin])
        )
        @Assert(failed.ok, false)
        @Assert(failed.code.toString(), "VERIFY_FAILED")
    }

    @TestCase
    public func testContractHttpLibraryStartupBundles(): Unit {
        let leafPem = readText("testdata/x509/policy_leaf.pem")
        let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
        let rootPem = readText("testdata/x509/policy_root.pem")
        let certChainPem = "${leafPem}\n${intermediatePem}"
        let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")
        let (_derPin, spkiPin) = contractComputeLeafPinsFromPem(leafPem)

        let serverBundle = contractPrepareHttpServerLibraryStartupRequest(
            ContractHttpServerLibraryStartupRequest(
                ContractHttpServerTlsConfigRequest(
                    certChainPem,
                    leafKeyPem,
                    alpnProtocols: ["h2", "http/1.1"]
                ),
                profile: ContractHttpSshStartupProfile.HttpServerLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(serverBundle.template.profile.toString(), "HTTP_SERVER_LIBRARY")
        @Assert(serverBundle.readiness.httpTlsReady, true)
        @Assert(serverBundle.readiness.aesCurrentReleasePlan.currentReleaseSeries, "0.6")
        @Assert(serverBundle.material.certificateChainPemBlocks.size, 2)

        let productionServer = contractTryPrepareHttpServerLibraryStartupRequest(
            ContractHttpServerLibraryStartupRequest(
                ContractHttpServerTlsConfigRequest(certChainPem, leafKeyPem),
                profile: ContractHttpSshStartupProfile.ProductionAccelerated,
                aesBackendHint: "shim"
            )
        )
        @Assert(productionServer.ok, false)
        match (productionServer.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("HTTP server startup production outcome should carry contract code")
        }

        let clientBundle = contractPrepareHttpClientLibraryStartupRequest(
            ContractHttpClientLibraryStartupRequest(
                ContractHttpClientTlsTrustRequest(
                    rootPem,
                    intermediatesPemBundle: intermediatePem,
                    hostname: TEST_HOST_WWW,
                    validationTime: "230101000000Z",
                    pinPolicy: ContractX509PinPolicy(allowedLeafSpkiSha256: [spkiPin]),
                    policy: ContractTlsHttpNegotiationPolicy(
                        requireServerName: true,
                        allowedServerNames: [TEST_HOST_WWW],
                        alpnPreference: ["h2", "http/1.1"]
                    )
                ),
                profile: ContractHttpSshStartupProfile.HttpClientLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(clientBundle.template.profile.toString(), "HTTP_CLIENT_LIBRARY")
        @Assert(clientBundle.readiness.httpTlsReady, true)
        @Assert(clientBundle.trust.validation.normalizedHostname, TEST_HOST_WWW)

        let invalidProfile = contractTryPrepareHttpClientLibraryStartupRequest(
            ContractHttpClientLibraryStartupRequest(
                ContractHttpClientTlsTrustRequest(rootPem, hostname: TEST_HOST_WWW),
                profile: ContractHttpSshStartupProfile.SshClientLibrary,
                aesBackendHint: "shim"
            )
        )
        @Assert(invalidProfile.ok, false)
        match (invalidProfile.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("HTTP client startup invalid profile outcome should carry contract code")
        }
    }
}

private func readText(path: String): String {
    String.fromUtf8(File.readFrom("${LIVE_SOURCE_ROOT}${path}"))
}
