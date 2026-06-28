package jinguissl.tests

import std.fs.File
import jinguissl.contract.*

private let LIVE_SOURCE_ROOT: String = ""
private let TEST_HOST_WWW: String = "www." + "example.com"

@Test
public class ContractProviderSmokeTestSuite {
    @TestCase
    public func testContractProviderSmokeFixtureCatalogShape(): Unit {
        let catalog = contractProviderSmokeFixtureCatalog()
        @Assert(catalog.size > 0, true)
        let successFixture = contractRequireProviderSmokeFixture(" success-x509-policy-chain ")
        @Assert(successFixture.category.toString(), "SUCCESS")
        let unavailableFixture = contractRequireProviderSmokeFixture("provider-not-linked")
        match (unavailableFixture.expectedFamily) {
            case Some(family) =>
                @Assert(family.toString(), "PROVIDER_UNAVAILABLE")
            case None =>
                @Fail("provider-not-linked fixture should carry expected family")
        }
    }

    @TestCase
    public func testContractProviderSmokeSuccessBaselineShape(): Unit {
        let report = contractDescribeProviderSmokeBaseline("success-x509-policy-chain")
        @Assert(report.expectedSuccess, true)
        @Assert(report.executionMode.toString(), "VERIFY_PATH")
        @Assert(report.warnings.size, 0)
        match (report.expectedDescriptor) {
            case Some(_) =>
                @Fail("success baseline should not carry expected descriptor")
            case None => ()
        }
        match (report.expectedFallback) {
            case Some(_) =>
                @Fail("success baseline should not carry fallback decision")
            case None => ()
        }
    }

    @TestCase
    public func testContractProviderSmokeFailureBaselineShape(): Unit {
        let report = contractDescribeProviderSmokeBaseline("verify-hostname-mismatch")
        @Assert(report.expectedSuccess, false)
        @Assert(report.executionMode.toString(), "VERIFY_PATH")
        match (report.expectedDescriptor) {
            case Some(descriptor) =>
                @Assert(descriptor.family.toString(), "TLS_VERIFY_ERROR")
                @Assert(descriptor.phase.toString(), "TLS_VERIFY")
                @Assert(descriptor.fallbackSuggested, false)
                match (descriptor.code) {
                    case Some(code) =>
                        @Assert(code.toString(), "VERIFY_FAILED")
                    case None =>
                        @Fail("failure baseline descriptor should carry code")
                }
            case None =>
                @Fail("failure baseline should carry expected descriptor")
        }
        match (report.expectedFallback) {
            case Some(fallback) =>
                @Assert(fallback.fallbackSuggested, false)
                @Assert(fallback.mustSurface, true)
            case None =>
                @Fail("failure baseline should carry fallback decision")
        }
    }

    @TestCase
    public func testContractProviderSmokeSuiteCountsStayConsistent(): Unit {
        let suite = contractDescribeProviderSmokeSuiteRequest(
            ContractProviderSmokeSuiteRequest(
                fixtureIds: [
                    "success-x509-policy-chain",
                    "provider-not-linked",
                    "attach-stable-listener-unpublished"
                ]
            )
        )
        @Assert(suite.totalFixtureCount == Int64(3), true)
        @Assert(suite.successFixtureCount == Int64(1), true)
        @Assert(suite.failureFixtureCount == Int64(2), true)
        @Assert(suite.verifyPathCount == Int64(1), true)
        @Assert(suite.providerSelectionPathCount == Int64(1), true)
        @Assert(suite.metadataOnlyCount == Int64(1), true)
        @Assert(
            suite.warnings.contains(
                "metadata-only smoke baselines should be asserted through contract descriptors instead of being counted as live handshake regressions"
            ),
            true
        )
    }

    @TestCase
    public func testContractTryDescribeProviderSmokeBaselineRequestMapsBadInput(): Unit {
        let outcome = contractTryDescribeProviderSmokeBaselineRequest(
            ContractProviderSmokeBaselineRequest("missing-fixture")
        )
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(code) =>
                @Assert(code.toString(), "BAD_INPUT")
            case None =>
                @Fail("failure outcome should carry contract error code")
        }
        match (outcome.igniteCode) {
            case Some(code) =>
                @Assert(code.toString(), "BAD_ENVELOPE")
            case None =>
                @Fail("failure outcome should carry ignite error code")
        }
        match (outcome.result) {
            case Some(_) =>
                @Fail("failure outcome should not carry result")
            case None => ()
        }
    }

    @TestCase
    public func testContractProviderSmokeExecutableRunnerExecutesStableFixtures(): Unit {
        let report = contractRunProviderSmokeExecutableSuiteRequest(
            ContractProviderSmokeExecutableSuiteRequest(
                fixtureIds: [
                    "success-x509-policy-chain",
                    "verify-hostname-mismatch",
                    "verify-pin-mismatch",
                    "precheck-cert-key-mismatch",
                    "provider-not-linked",
                    "attach-stable-listener-unpublished"
                ],
                material: Some(providerSmokeExecutableMaterial())
            )
        )
        @Assert(report.totalFixtureCount, 6)
        @Assert(report.executedFixtureCount, 5)
        @Assert(report.skippedFixtureCount, 1)
        @Assert(report.verifyPathExecutedCount, 3)
        @Assert(report.precheckPathExecutedCount, 1)
        @Assert(report.providerSelectionPathExecutedCount, 1)
        @Assert(report.metadataOnlySkippedCount, 1)
        @Assert(report.warnings.contains(
            "fixture attach-stable-listener-unpublished is metadata-only; no live handshake or attach execution is claimed"
        ), true)

        let success = requireExecutableResult(report, "success-x509-policy-chain")
        if (success.status.toString() != "PASSED") {
            @Fail(success.message)
        }
        @Assert(success.executedEntrypoints.size, 2)

        let hostname = requireExecutableResult(report, "verify-hostname-mismatch")
        @Assert(hostname.status.toString(), "PASSED")

        let pin = requireExecutableResult(report, "verify-pin-mismatch")
        @Assert(pin.status.toString(), "PASSED")

        let precheck = requireExecutableResult(report, "precheck-cert-key-mismatch")
        @Assert(precheck.status.toString(), "PASSED")

        let provider = requireExecutableResult(report, "provider-not-linked")
        @Assert(provider.status.toString(), "PASSED")

        let attach = requireExecutableResult(report, "attach-stable-listener-unpublished")
        @Assert(attach.status.toString(), "SKIPPED")
        @Assert(attach.executedEntrypoints.size, 0)

        @Assert(report.passedFixtureCount, 5)
        @Assert(report.failedFixtureCount, 0)
    }

    @TestCase
    public func testContractProviderSmokeExecutableRunnerSkipsMaterialBoundFixturesWithoutMaterial(): Unit {
        let report = contractRunProviderSmokeExecutableSuiteRequest(
            ContractProviderSmokeExecutableSuiteRequest(
                fixtureIds: [
                    "success-x509-policy-chain",
                    "provider-not-linked"
                ]
            )
        )
        @Assert(report.totalFixtureCount, 2)
        @Assert(report.executedFixtureCount, 1)
        @Assert(report.skippedFixtureCount, 1)
        @Assert(report.passedFixtureCount, 1)
        @Assert(report.failedFixtureCount, 0)

        let success = requireExecutableResult(report, "success-x509-policy-chain")
        @Assert(success.status.toString(), "SKIPPED")
        @Assert(success.message, "fixture success-x509-policy-chain requires executable PEM material")

        let provider = requireExecutableResult(report, "provider-not-linked")
        @Assert(provider.status.toString(), "PASSED")
    }

    @TestCase
    public func testContractTryRunProviderSmokeExecutableSuiteMapsBadInput(): Unit {
        let outcome = contractTryRunProviderSmokeExecutableSuiteRequest(
            ContractProviderSmokeExecutableSuiteRequest(
                fixtureIds: ["missing-fixture"]
            )
        )
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(code) =>
                @Assert(code.toString(), "BAD_INPUT")
            case None =>
                @Fail("executable suite failure should carry contract error code")
        }
        match (outcome.igniteCode) {
            case Some(code) =>
                @Assert(code.toString(), "BAD_ENVELOPE")
            case None =>
                @Fail("executable suite failure should carry ignite error code")
        }
    }
}

private func providerSmokeExecutableMaterial(): ContractProviderSmokeExecutableMaterial {
    ContractProviderSmokeExecutableMaterial(
        readText("testdata/x509/policy_leaf.pem"),
        readText("testdata/x509/policy_intermediate.pem"),
        readText("testdata/x509/policy_root.pem"),
        readText("testdata/x509/policy_leaf_key_pkcs8.pem"),
        mismatchPrivateKeyPem: readText("testdata/x509/rsa_2048_pkcs8.pem"),
        successHostname: TEST_HOST_WWW,
        mismatchHostname: "not.policy.example",
        validationTime: "230101000000Z"
    )
}

private func requireExecutableResult(
    report: ContractProviderSmokeExecutableSuiteReport,
    fixtureId: String
): ContractProviderSmokeExecutableResult {
    for (result in report.results) {
        if (result.fixture.fixtureId == fixtureId) {
            return result
        }
    }
    @Fail("missing executable result ${fixtureId}")
}

private func readText(path: String): String {
    String.fromUtf8(File.readFrom("${LIVE_SOURCE_ROOT}${path}"))
}
