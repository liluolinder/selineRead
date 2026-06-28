package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractAesReadinessTestSuite {
    @TestCase
    public func testContractAesHardwareFacade(): Unit {
        let mounts = contractAesListHardwareMountPoints()
        @Assert(mounts.size >= 5, true)

        var foundAesni = false
        var foundArm = false
        var foundShim = false
        var foundLoong = false
        var foundRiscv = false
        for (mount in mounts) {
            if (mount.backend == "aesni") {
                foundAesni = true
            }
            if (mount.backend == "armv8-ce") {
                foundArm = true
            }
            if (mount.backend == "shim") {
                foundShim = true
            }
            if (mount.backend == "loongarch64-reserved") {
                foundLoong = true
            }
            if (mount.backend == "riscv64-reserved") {
                foundRiscv = true
            }
        }
        @Assert(foundAesni, true)
        @Assert(foundArm, true)
        @Assert(foundShim, true)
        @Assert(foundLoong, true)
        @Assert(foundRiscv, true)

        let hint = contractAesDefaultHardwareBackendHint().trimAscii()
        if (hint.size > 0) {
            var foundHint = false
            for (mount in mounts) {
                if (mount.backend == hint) {
                    foundHint = true
                    break
                }
            }
            @Assert(foundHint, true)
        }

        let shim = contractAesProbeHardware(backendHint: "shim")
        @Assert(shim.backend, "shim")
        @Assert(shim.available, true)
        @Assert(shim.accelerated, false)
        @Assert(shim.detail.trimAscii().size > 0, true)

        let loongarch = contractAesProbeHardware(backendHint: "loongarch64")
        @Assert(loongarch.backend, "loongarch64-reserved")
        @Assert(loongarch.available, false)
        @Assert(loongarch.accelerated, false)
    }

    @TestCase
    public func testContractAesHardwareRoadmapAndReleasePlan(): Unit {
        let roadmap = contractAesHardwareRoadmap()
        @Assert(roadmap.size >= 4, true)

        var foundArm = false
        var foundX64 = false
        var foundLoong = false
        var foundRiscv = false
        for (entry in roadmap) {
            if (entry.architecture == "aarch64") {
                foundArm = true
                @Assert(entry.backend, "armv8-ce")
                @Assert(entry.status, "PRIMARY_ACTIVE")
                @Assert(entry.targetVersion, "0.6")
            }
            if (entry.architecture == "x86_64") {
                foundX64 = true
                @Assert(entry.backend, "aesni")
                @Assert(entry.status, "DEFERRED_0_7")
                @Assert(entry.targetVersion, "0.7")
            }
            if (entry.architecture == "loongarch64") {
                foundLoong = true
                @Assert(entry.status, "RESERVED_SKELETON")
            }
            if (entry.architecture == "riscv64") {
                foundRiscv = true
                @Assert(entry.status, "RESERVED_SKELETON")
            }
        }
        @Assert(foundArm, true)
        @Assert(foundX64, true)
        @Assert(foundLoong, true)
        @Assert(foundRiscv, true)

        let report = contractAesCurrentReleasePlan(backendHint: "shim")
        @Assert(report.currentReleaseSeries, "0.6")
        @Assert(report.primaryBackend, "armv8-ce")
        @Assert(report.primaryArchitectures.contains("aarch64"), true)
        @Assert(report.deferredBackends.contains("aesni"), true)
        @Assert(report.reservedBackends.contains("loongarch64-reserved"), true)
        @Assert(report.reservedBackends.contains("riscv64-reserved"), true)
        @Assert(report.usingPrimaryBackend, false)
        @Assert(
            report.warnings.contains("selected AES backend is not the current 0.6 primary backend"),
            true
        )

        try {
            _ = contractRequireAesCurrentReleasePrimaryBackend(backendHint: "shim")
            @Fail("shim backend should not satisfy current release primary backend requirement")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testContractAesEngineFacade(): Unit {
        let resolvedShim = contractResolveAesEngine(backendHint: "shim")
        @Assert(resolvedShim.requested.toString(), "AUTO")
        @Assert(resolvedShim.active.toString(), "HARDWARE")
        @Assert(resolvedShim.backend, "shim")
        @Assert(resolvedShim.accelerated, false)

        let forcedSoftware = contractResolveAesEngine(
            requestedEngine: ContractAesEngineKind.Software,
            backendHint: "shim"
        )
        @Assert(forcedSoftware.requested.toString(), "SOFTWARE")
        @Assert(forcedSoftware.active.toString(), "SOFTWARE")
        @Assert(forcedSoftware.backend, "shim")

        let unavailable = contractTryResolveAesEngine(
            requestedEngine: ContractAesEngineKind.Hardware,
            backendHint: "none"
        )
        @Assert(unavailable.ok, false)
        match (unavailable.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("AES engine unavailable outcome should carry contract code")
        }
        match (unavailable.igniteCode) {
            case Some(value) =>
                @Assert(value.toString(), "CRYPTO_UNAVAILABLE")
            case None =>
                @Fail("AES engine unavailable outcome should carry ignite code")
        }

        try {
            _ = contractRequireAesAcceleratedBackend(backendHint: "shim")
            @Fail("shim backend should not satisfy accelerated backend requirement")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testContractAesNativeBridgeDiagnosticsFacade(): Unit {
        let shimSpec = ContractAesNativeBridgeSpec("shim")
        let diagnostics = contractInspectAesNativeBridge(shimSpec)
        @Assert(diagnostics.spec.backend, "shim")
        @Assert(diagnostics.probe.backend, "shim")
        @Assert(diagnostics.probe.available, true)
        @Assert(diagnostics.probe.accelerated, false)
        @Assert(diagnostics.engine.active.toString(), "HARDWARE")
        @Assert(diagnostics.contract.backend, "shim")
        @Assert(diagnostics.contract.expandKeySymbol, "jinguissl_aes_expand_key")
        @Assert(diagnostics.contract.ghashMulSymbol, "jinguissl_aes_ghash_mul")

        let callShape = contractDescribeAesNativeBridgeCallShape(shimSpec, 16)
        @Assert(callShape.backend, "shim")
        @Assert(callShape.keyBytes == Int64(16), true)
        @Assert(callShape.roundCount == Int64(10), true)
        @Assert(callShape.roundKeyWordCount == Int64(44), true)
        @Assert(callShape.expandedKeyBlobBytes == Int64(188), true)
        @Assert(callShape.blockBytes == Int64(16), true)
        @Assert(callShape.requiresBlockAlignedPayload, true)

        let invalid = contractTryInspectAesNativeBridge(ContractAesNativeBridgeSpec("bogus"))
        @Assert(invalid.ok, false)
        match (invalid.code) {
            case Some(value) =>
                @Assert(value.toString(), "BAD_INPUT")
            case None =>
                @Fail("AES native bridge diagnostics outcome should carry contract code")
        }
    }

    @TestCase
    public func testContractAesStartupSelfCheckFacade(): Unit {
        let recommendation = contractRecommendAesBackend()
        @Assert(recommendation.backendHint.size > 0, true)
        @Assert(recommendation.reason.size > 0, true)

        let report = contractAesStartupSelfCheck(backendHint: "shim")
        @Assert(report.effectiveBackendHint, "shim")
        @Assert(report.recommendation.backendHint.size > 0, true)
        @Assert(report.selectedEngine.backend, "shim")
        @Assert(report.selectedEngine.active.toString(), "HARDWARE")
        @Assert(report.acceleratedBackendReady, false)
        @Assert(report.mountPoints.size >= 3, true)
        match (report.diagnostics) {
            case Some(value) =>
                @Assert(value.spec.backend, "shim")
            case None =>
                @Fail("AES startup self-check should carry diagnostics for shim backend")
        }

        let softwareReport = contractAesStartupSelfCheck(
            requestedEngine: ContractAesEngineKind.Software,
            backendHint: "none"
        )
        @Assert(softwareReport.effectiveBackendHint, "none")
        @Assert(softwareReport.selectedEngine.active.toString(), "SOFTWARE")
        match (softwareReport.diagnostics) {
            case Some(_) =>
                @Fail("software-only AES startup self-check should not carry bridge diagnostics")
            case None => ()
        }
    }
}
