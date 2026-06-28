package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractMetadataTestSuite {
    @TestCase
    public func testContractFacadeInfoShape(): Unit {
        let info = contractFacadeInfo()
        @Assert(info.apiVersion, "1.0.0")
        @Assert(info.stabilityLevel, "L1")
        @Assert(info.freezeDate, "2026-03-24")
        @Assert(info.stableDomains.size > 0, true)
        @Assert(info.importRule.contains("jinguissl.contract.*"), true)
    }

    @TestCase
    public func testContractCapabilityInfoShape(): Unit {
        let info = contractCapabilityInfo()
        @Assert(info.stableDomains.size > 0, true)
        @Assert(info.httpTlsFeatures.contains("tls13-x25519"), true)
        @Assert(info.sshFeatures.contains("x25519-kex"), true)
        @Assert(info.x509Features.contains("certificate-chain-verify"), true)
        @Assert(info.directStdxTlsServerConfigBridge, false)
        @Assert(info.notes.size > 0, true)
    }

    @TestCase
    public func testContractFacadeInfoRejectsEmptyVersion(): Unit {
        try {
            _ = ContractFacadeInfo("", "L1", "2026-03-24", ["tls13"], "import jinguissl.contract.* only")
            @Fail("empty version should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractErrorAndIgniteCodesStayStable(): Unit {
        @Assert(ContractErrorCode.VerifyFailed.toString(), "VERIFY_FAILED")
        @Assert(ContractIgniteCryptoErrorCode.DecryptFailed.toString(), "DECRYPT_FAILED")
    }
}
