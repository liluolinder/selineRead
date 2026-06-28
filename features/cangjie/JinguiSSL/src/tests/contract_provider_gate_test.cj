package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractProviderGateTestSuite {
    @TestCase
    public func testContractProviderCapabilityRecordShape(): Unit {
        let capability = contractProviderCapabilityRecord()
        @Assert(capability.providerId, "jinguissl")
        @Assert(capability.providerVersion, "0.6.21")
        @Assert(capability.supportsClientTls, true)
        @Assert(capability.supportsServerTlsAttach, true)
        @Assert(capability.defaultEligible, true)
        @Assert(capability.unsupportedReasons.size > 0, true)
        @Assert(capability.notes.size > 0, true)
    }

    @TestCase
    public func testContractProviderAttachContractInfoShape(): Unit {
        let info = contractProviderAttachContractInfo()
        @Assert(info.providerId, "jinguissl")
        @Assert(info.supportsTlsPrecheck, true)
        @Assert(info.supportsServerTlsAttach, true)
        @Assert(info.tlsPrecheckInputs.contains("serverName"), true)
        @Assert(info.failureFields.contains("contractCode"), true)
        @Assert(info.notes.size > 0, true)
    }

    @TestCase
    public func testContractProviderServerAttachBoundaryShape(): Unit {
        let boundary = contractProviderServerAttachBoundary()
        @Assert(boundary.providerId, "jinguissl")
        @Assert(boundary.status.toString(), "STABLE")
        @Assert(boundary.stableAttach, true)
        @Assert(boundary.blockingLayer.contains("stable accepted-transport"), true)
        @Assert(boundary.recommendedFallback.contains("stdx-default"), true)
        @Assert(boundary.unsupportedReasons.size, 0)
    }

    @TestCase
    public func testContractProviderErrorDescriptorRejectsEmptyProviderId(): Unit {
        try {
            _ = ContractProviderErrorDescriptor(
                "",
                ContractProviderErrorFamily.ProviderUnavailable,
                ContractProviderErrorPhase.ProviderSelection,
                true,
                true,
                "provider selection failed"
            )
            @Fail("empty providerId should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractProviderFallbackDecisionTrimsStrings(): Unit {
        let decision = ContractProviderFallbackDecision(
            " jinguissl ",
            true,
            " stdx/lisi ",
            true,
            true,
            " keep upper-layer attach glue "
        )
        @Assert(decision.providerId, "jinguissl")
        @Assert(decision.fallbackTarget, "stdx/lisi")
        @Assert(decision.reason, "keep upper-layer attach glue")
    }
}
