package jinguissl.tests

import jinguissl.live.*

@Test
public class ContractRuntimeCompatMarkerTestSuite {
    @TestCase
    public func testContractLiveRuntimeCompatibilityMarkerReturnsExpected(): Unit {
        let marker = contractLiveRuntimeCompatibilityMarker()
        @Assert(marker, 0x524B4954)
    }

    @TestCase
    public func testContractLiveRuntimeCompatibilityMarkerIsPositive(): Unit {
        let marker = contractLiveRuntimeCompatibilityMarker()
        @Assert(marker > 0, true)
    }

    // --- RuntimeSurfaceInfo wrapper tests ---
    // These prove that jinguissl.live can expose
    // a wrapper from jinguissl_runtime.jinguissl.runtime.* without
    // touching live.cj or the bridge layer.

    @TestCase
    public func testContractRuntimeSurfaceInfoPackageName(): Unit {
        let info = contractRuntimeSurfaceInfo()
        @Assert(info.packageName, "jinguissl_runtime")
    }

    @TestCase
    public func testContractRuntimeSurfaceInfoCompatibilityMarker(): Unit {
        let info = contractRuntimeSurfaceInfo()
        @Assert(info.compatibilityMarker, 0x524B4954)
    }

    @TestCase
    public func testContractRuntimeSurfaceInfoVersionTag(): Unit {
        let info = contractRuntimeSurfaceInfo()
        @Assert(info.runtimeVersionTag, "0.1.0")
    }

    @TestCase
    public func testContractRuntimeSurfaceInfoAllFieldsPresent(): Unit {
        let info = contractRuntimeSurfaceInfo()
        @Assert(info.packageName.size > 0, true)
        @Assert(info.compatibilityMarker > 0, true)
        @Assert(info.runtimeVersionTag.size > 0, true)
    }
}
