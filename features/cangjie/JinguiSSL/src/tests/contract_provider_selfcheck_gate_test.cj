package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractProviderSelfCheckGateTestSuite {
    @TestCase
    public func testContractProviderSmokeSelfCheckDefaultPolicyReady(): Unit {
        let report = contractProviderSmokeSelfCheck()
        @Assert(report.overallReady, true)
        @Assert(report.supportsClientTls, true)
        @Assert(report.supportsX509Verify, true)
        @Assert(report.supportsTlsPrecheck, true)
        @Assert(report.stableServerAttach, true)
        @Assert(report.defaultEligible, true)
        @Assert(report.warnings.contains("provider remains experimental in the current public release line"), true)
    }

    @TestCase
    public func testContractTryRequireProviderSmokeProfileStrictFailsClosed(): Unit {
        let outcome = contractTryRequireProviderSmokeProfile(
            ContractProviderSmokeProfile.ProductionStrict
        )
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(code) =>
                @Assert(code.toString(), "UNSUPPORTED")
            case None =>
                @Fail("strict profile failure should carry contract error code")
        }
        match (outcome.igniteCode) {
            case Some(code) =>
                @Assert(code.toString(), "CRYPTO_UNAVAILABLE")
            case None =>
                @Fail("strict profile failure should carry ignite error code")
        }
        match (outcome.result) {
            case Some(_) =>
                @Fail("strict profile failure should not carry a success result")
            case None => ()
        }
    }

    @TestCase
    public func testContractProviderConsumptionGateHttpAndPlanningRemainUsable(): Unit {
        let httpGate = contractDescribeProviderConsumptionGate(
            ContractProviderConsumptionPath.HttpClientTls
        )
        @Assert(httpGate.readyNow, true)
        @Assert(httpGate.status.toString(), "PROVIDER_CANDIDATE")
        @Assert(httpGate.selectedEntryId, "jinguissl-provider-candidate")
        @Assert(httpGate.fallbackTarget, "stdx-default")
        let planningGate = contractDescribeProviderConsumptionGate(
            ContractProviderConsumptionPath.HttpServerAttachPlanning
        )
        @Assert(planningGate.readyNow, true)
        @Assert(planningGate.status.toString(), "PLANNING_ONLY")
        @Assert(planningGate.guide.requiresUpperLayerAttachGlue, true)
        @Assert(planningGate.selectedReason.contains("attach planning only"), true)
    }

    @TestCase
    public func testContractProviderConsumptionGateStableAttachIsPublished(): Unit {
        let gate = contractDescribeProviderConsumptionGate(
            ContractProviderConsumptionPath.HttpServerStableAttach
        )
        @Assert(gate.readyNow, true)
        @Assert(gate.status.toString(), "PROVIDER_CANDIDATE")
        @Assert(gate.blockedCandidates.size == Int64(0), true)
        @Assert(gate.selectedEntryId, "jinguissl-provider-candidate")
        @Assert(gate.guide.publishedContractPath, true)
        @Assert(gate.guide.requiresUpperLayerAttachGlue, false)
        @Assert(gate.selectedReason.contains("provider-candidate route"), true)
        match (gate.smokeReadiness) {
            case Some(readiness) =>
                @Assert(readiness.overallReady, true)
                @Assert(readiness.stableServerAttach, true)
                @Assert(readiness.defaultEligible, true)
            case None =>
                @Fail("stable attach gate should carry mapped smoke readiness")
        }
        let outcome = contractTryRequireProviderConsumptionGate(
            ContractProviderConsumptionPath.HttpServerStableAttach
        )
        @Assert(outcome.ok, true)
        match (outcome.result) {
            case Some(report) =>
                @Assert(report.readyNow, true)
                @Assert(report.selectedEntryId, "jinguissl-provider-candidate")
            case None =>
                @Fail("published stable attach outcome should carry a success result")
        }
    }

    @TestCase
    public func testContractProviderConsumptionGateSshLibraryShape(): Unit {
        let gate = contractDescribeProviderConsumptionGate(
            ContractProviderConsumptionPath.SshClientLibrary
        )
        @Assert(gate.readyNow, true)
        @Assert(gate.status.toString(), "LIBRARY_CONTRACT")
        @Assert(gate.selectedEntryId, "jinguissl-library-direct")
        @Assert(gate.guide.useProviderSelection, false)
        @Assert(gate.guide.requiresUpperLayerAttachGlue, false)
        match (gate.smokeProfile) {
            case Some(_) =>
                @Fail("ssh library gate should not depend on a smoke profile")
            case None => ()
        }
    }

    @TestCase
    public func testContractResolveProviderFallbackOutcomeMatrix(): Unit {
        let verifyResolution = contractResolveProviderFallbackOutcome(
            ContractProviderFallbackResolutionRequest(
                ContractProviderFallbackCauseCode.TlsVerifyError
            )
        )
        @Assert(verifyResolution.finalOutcome.toString(), "NO_AUTO_FALLBACK")
        @Assert(verifyResolution.fallbackTarget, "")
        @Assert(verifyResolution.mustSurface, true)

        let providerUnavailableOnStable = contractResolveProviderFallbackOutcome(
            ContractProviderFallbackResolutionRequest(
                ContractProviderFallbackCauseCode.ProviderUnavailable,
                alreadyOnStableDefault: true
            )
        )
        @Assert(providerUnavailableOnStable.finalOutcome.toString(), "NO_FALLBACK")

        let cryptoUnavailableOnStable = contractResolveProviderFallbackOutcome(
            ContractProviderFallbackResolutionRequest(
                ContractProviderFallbackCauseCode.CryptoUnavailable,
                alreadyOnStableDefault: true
            )
        )
        @Assert(cryptoUnavailableOnStable.finalOutcome.toString(), "MANUAL_REVIEW")
    }
}
