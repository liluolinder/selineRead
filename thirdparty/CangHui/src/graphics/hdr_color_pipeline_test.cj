package chui.graphics

private func hdrTestAdapter(hasHdr!: Bool = true): GraphicsAdapterCapabilities {
    let values = if (hasHdr) {
        [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture,
            GraphicsCapability.HdrSurface
        ]
    } else {
        [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture
        ]
    }
    GraphicsAdapterCapabilities(
        "hdr-test", "adapter", GraphicsBackend.Metal, GraphicsProfile.Core3D,
        GraphicsLimits(8192, 4, 8, 4), capabilities: values)
}

private func hdrExtendedRequest(
    allowFallback!: Bool = true,
    requestExtendedOutput!: Bool = true
): HdrPresentationRequest {
    HdrPresentationRequest(
        HdrContentIntent(
            HdrDynamicRange.EdrLinear, HdrColorPrimaries.DisplayP3,
            referenceHeadroom: 2.0, masteringPeakNits: 400.0),
        output: HdrOutputRequest(
            requestExtendedOutput: requestExtendedOutput,
            allowSdrFallback: allowFallback))
}

private func hdrTestSurface(
    supportsEdr: Bool,
    supportsHdr10: Bool,
    surfaceId!: String = "main-surface",
    generation!: Int64 = 3,
    maxHeadroom!: Float32 = 1.0,
    maxPeakNits!: Float32 = 100.0
): HdrSurfaceCapabilities {
    HdrSurfaceCapabilities(
        "hdr-test-provider", surfaceId, generation, supportsEdr, supportsHdr10,
        maxHeadroom: maxHeadroom, maxPeakNits: maxPeakNits)
}

private class RecordingHdrActivationProvider <: HdrSurfaceActivationProvider {
    private let identityValue: String
    private let fail: Bool
    private let forceSdr: Bool
    private let mismatch: Bool
    private let omitToneMapProof: Bool
    private let wrongOutputBinding: Bool
    private var calls: Int64 = 0

    init(
        identityValue!: String = "hdr-test-provider",
        fail!: Bool = false,
        forceSdr!: Bool = false,
        mismatch!: Bool = false,
        omitToneMapProof!: Bool = false,
        wrongOutputBinding!: Bool = false
    ) {
        this.identityValue = identityValue
        this.fail = fail
        this.forceSdr = forceSdr
        this.mismatch = mismatch
        this.omitToneMapProof = omitToneMapProof
        this.wrongOutputBinding = wrongOutputBinding
    }

    public func identity(): String { identityValue }

    public func activate(
        plan: HdrSurfacePlan,
        surfaceId: String,
        surfaceGeneration: Int64
    ): HdrProviderActivationResult {
        calls += 1
        let outputSurfaceId = if (wrongOutputBinding) { "other-surface" } else { surfaceId }
        if (fail) {
            return HdrProviderActivationResult(
                false, "native-call-failed", HdrDynamicRange.Sdr,
                HdrColorPrimaries.Srgb, 1.0, 100.0, outputSurfaceId, surfaceGeneration,
                false, plan.request.output.fallbackToneMap, "")
        }
        if (forceSdr) {
            return HdrProviderActivationResult(
                true, "native-sdr", HdrDynamicRange.Sdr,
                HdrColorPrimaries.Srgb, 1.0, 100.0, outputSurfaceId, surfaceGeneration,
                !omitToneMapProof, plan.request.output.fallbackToneMap, "native-sdr-output")
        }
        if (mismatch) {
            return HdrProviderActivationResult(
                true, "wrong-native-mode", HdrDynamicRange.Hdr10Pq,
                HdrColorPrimaries.Rec2020, 2.0, 400.0, outputSurfaceId, surfaceGeneration,
                false, plan.request.output.fallbackToneMap, "wrong-native-output")
        }
        let toneMapped = plan.request.content.dynamicRange != HdrDynamicRange.Sdr &&
            plan.plannedDynamicRange == HdrDynamicRange.Sdr
        HdrProviderActivationResult(
            true, "native-active", plan.plannedDynamicRange, plan.plannedPrimaries,
            plan.plannedHeadroom, plan.plannedPeakNits, outputSurfaceId, surfaceGeneration,
            toneMapped, plan.request.output.fallbackToneMap, "native-output-active")
    }

    func callCount(): Int64 { calls }
}

@Test
func hdrColorContractNamesAndKnownToneMapVectorsStayStable(): Unit {
    @Expect(CANGHUI_HDR_COLOR_PROTOCOL, "canghui.hdr-color.v2")
    @Expect(hdrDynamicRangeName(HdrDynamicRange.EdrLinear), "edr-linear")
    @Expect(hdrColorPrimariesName(HdrColorPrimaries.Rec2020), "rec2020")
    @Expect(hdrSurfacePlanStatusName(HdrSurfacePlanStatus.ExtendedPlanned), "extended-planned")

    let clamped = toneMapHdrToSdr(
        HdrLinearRgb(-1.0, 0.5, 2.0), SdrToneMapOperator.Clamp)
    @Expect(clamped, HdrLinearRgb(0.0, 0.5, 1.0))

    let reinhard = toneMapHdrToSdr(
        HdrLinearRgb(1.0, 3.0, Float32.NaN), SdrToneMapOperator.Reinhard)
    @Expect(reinhard, HdrLinearRgb(0.5, 0.75, 0.0))

    let aces = toneMapHdrToSdr(
        HdrLinearRgb(1.0, 1.0, 1.0), SdrToneMapOperator.AcesFitted)
    @Expect(aces.red > 0.803 && aces.red < 0.805)
}

@Test
func hdrContentIntentStrictlySeparatesSdrAndExtendedRanges(): Unit {
    var weakExtendedRejected = false
    try {
        let _ = HdrContentIntent(
            HdrDynamicRange.EdrLinear, HdrColorPrimaries.DisplayP3,
            referenceHeadroom: 1.0, masteringPeakNits: 100.0)
    } catch (_: IllegalArgumentException) {
        weakExtendedRejected = true
    }
    @Expect(weakExtendedRejected)

    var sdrHeadroomRejected = false
    try {
        let _ = HdrContentIntent(
            HdrDynamicRange.Sdr, HdrColorPrimaries.DisplayP3,
            referenceHeadroom: 2.0, masteringPeakNits: 100.0)
    } catch (_: IllegalArgumentException) {
        sdrHeadroomRejected = true
    }
    @Expect(sdrHeadroomRejected)

    var invalidHdr10 = false
    try {
        let _ = HdrContentIntent(
            HdrDynamicRange.Hdr10Pq, HdrColorPrimaries.DisplayP3,
            referenceHeadroom: 4.0, masteringPeakNits: 1000.0)
    } catch (_: IllegalArgumentException) {
        invalidHdr10 = true
    }
    @Expect(invalidHdr10)
}

@Test
func hdrPlanningReportsCapabilityAndNeverClaimsActivation(): Unit {
    let surface = hdrTestSurface(
        true, true, maxHeadroom: 4.0, maxPeakNits: 1000.0)
    let exact = planHdrSurface(hdrExtendedRequest(), hdrTestAdapter(), surface)
    @Expect(exact.status == HdrSurfacePlanStatus.ExtendedPlanned)
    @Expect(exact.code, "extended-output-planned")
    @Expect(exact.capabilityAvailable)
    @Expect(exact.plansExtendedOutput())

    let clamped = planHdrSurface(
        HdrPresentationRequest(HdrContentIntent(
            HdrDynamicRange.Hdr10Pq, HdrColorPrimaries.Rec2020,
            referenceHeadroom: 8.0, masteringPeakNits: 4000.0)),
        hdrTestAdapter(), surface)
    @Expect(clamped.status == HdrSurfacePlanStatus.ExtendedClamped)
    @Expect(clamped.plannedHeadroom, Float32(4.0))
    @Expect(clamped.plannedPeakNits, Float32(1000.0))

    let fallback = planHdrSurface(
        hdrExtendedRequest(), hdrTestAdapter(hasHdr: false), surface)
    @Expect(fallback.status == HdrSurfacePlanStatus.SdrFallbackPlanned)
    @Expect(fallback.usesSdrToneMap())
    @Expect(!fallback.capabilityAvailable)

    let unsupported = planHdrSurface(
        hdrExtendedRequest(allowFallback: false),
        hdrTestAdapter(hasHdr: false), surface)
    @Expect(!unsupported.ok())
    @Expect(unsupported.status == HdrSurfacePlanStatus.Unsupported)

    let sdrPlan = planHdrSurface(
        HdrPresentationRequest(HdrContentIntent(
            HdrDynamicRange.Sdr, HdrColorPrimaries.Srgb)),
        hdrTestAdapter(hasHdr: false), hdrTestSurface(false, false))
    @Expect(!sdrPlan.capabilityAvailable)
}

@Test
func hdrProviderReceiptIsTheOnlyActualActivationTruth(): Unit {
    let plan = planHdrSurface(
        hdrExtendedRequest(), hdrTestAdapter(),
        hdrTestSurface(true, false, maxHeadroom: 4.0, maxPeakNits: 800.0))
    let provider = RecordingHdrActivationProvider()
    let active = activateHdrSurface(plan, provider, "main-surface", 3)
    @Expect(active.active)
    @Expect(active.extendedOutputActive())
    @Expect(active.code, "provider-output-active")
    @Expect(active.actualDynamicRange == HdrDynamicRange.EdrLinear)
    @Expect(!active.usesSdrToneMap())
    @Expect(active.outputEvidence, "native-output-active")
    @Expect(provider.callCount(), 1)

    let failed = activateHdrSurface(
        plan, RecordingHdrActivationProvider(fail: true), "main-surface", 3)
    @Expect(!failed.active)
    @Expect(!failed.extendedOutputActive())
    @Expect(failed.code.contains("provider-activation-failed"))

    let mismatched = activateHdrSurface(
        plan, RecordingHdrActivationProvider(mismatch: true), "main-surface", 3)
    @Expect(!mismatched.active)
    @Expect(mismatched.code, "provider-result-plan-mismatch")
}

@Test
func hdrProviderMayReportActualSdrFallbackWithoutFakingExtendedActivation(): Unit {
    let plan = planHdrSurface(
        hdrExtendedRequest(), hdrTestAdapter(),
        hdrTestSurface(
            true, false, generation: 4, maxHeadroom: 4.0, maxPeakNits: 800.0))
    let receipt = activateHdrSurface(
        plan, RecordingHdrActivationProvider(forceSdr: true), "main-surface", 4)
    @Expect(receipt.active)
    @Expect(!receipt.extendedOutputActive())
    @Expect(receipt.usesSdrToneMap())
    @Expect(receipt.toneMapOperator == SdrToneMapOperator.AcesFitted)
    @Expect(receipt.outputEvidence, "native-sdr-output")
    @Expect(receipt.code, "provider-sdr-fallback-active")
    @Expect(receipt.frameColorSpace() == GraphicsColorSpace.Srgb)
    @Expect(receipt.frameDynamicRange() == FrameDynamicRange.Sdr)
}

@Test
func hdrActivationRejectsPlanBindingAndToneMapEvidenceMismatchBeforeClaimingActive(): Unit {
    let plan = planHdrSurface(
        hdrExtendedRequest(), hdrTestAdapter(),
        hdrTestSurface(
            true, false, generation: 5, maxHeadroom: 4.0, maxPeakNits: 800.0))

    let wrongGenerationProvider = RecordingHdrActivationProvider()
    let wrongGeneration = activateHdrSurface(
        plan, wrongGenerationProvider, "main-surface", 6)
    @Expect(!wrongGeneration.active)
    @Expect(wrongGeneration.code, "plan-surface-binding-mismatch")
    @Expect(wrongGenerationProvider.callCount(), 0)

    let wrongProvider = RecordingHdrActivationProvider(identityValue: "other-hdr-provider")
    let wrongIdentity = activateHdrSurface(plan, wrongProvider, "main-surface", 5)
    @Expect(!wrongIdentity.active)
    @Expect(wrongIdentity.code, "plan-surface-binding-mismatch")
    @Expect(wrongProvider.callCount(), 0)

    let missingProof = activateHdrSurface(
        plan, RecordingHdrActivationProvider(forceSdr: true, omitToneMapProof: true),
        "main-surface", 5)
    @Expect(!missingProof.active)
    @Expect(missingProof.code, "provider-tone-map-evidence-mismatch")

    let wrongOutput = activateHdrSurface(
        plan, RecordingHdrActivationProvider(wrongOutputBinding: true),
        "main-surface", 5)
    @Expect(!wrongOutput.active)
    @Expect(wrongOutput.code, "provider-output-binding-mismatch")
}

@Test
func hdrSdrDisplayP3MappingRemainsWideGamutButNotExtendedRange(): Unit {
    let request = HdrPresentationRequest(HdrContentIntent(
        HdrDynamicRange.Sdr, HdrColorPrimaries.DisplayP3,
        referenceHeadroom: 1.0, masteringPeakNits: 100.0))
    let plan = planHdrSurface(
        request, hdrTestAdapter(hasHdr: false),
        hdrTestSurface(false, false, surfaceId: "p3-surface", generation: 1))
    @Expect(plan.status == HdrSurfacePlanStatus.SdrPlanned)
    let receipt = activateHdrSurface(plan, RecordingHdrActivationProvider(), "p3-surface", 1)
    @Expect(receipt.active)
    @Expect(!receipt.extendedOutputActive())
    @Expect(receipt.frameColorSpace() == GraphicsColorSpace.DisplayP3)
    @Expect(receipt.frameDynamicRange() == FrameDynamicRange.Sdr)
}

@Test
func hdrFrameGraphUsesActualProviderReceiptForExtendedRangeGate(): Unit {
    let plan = planHdrSurface(
        hdrExtendedRequest(), hdrTestAdapter(),
        hdrTestSurface(
            true, false, generation: 1, maxHeadroom: 4.0, maxPeakNits: 800.0))
    let receipt = activateHdrSurface(
        plan, RecordingHdrActivationProvider(), "main-surface", 1)
    let output = FrameResourceDescriptor(
        FrameResourceId("hdr.output", 1), FrameResourceKind.Texture,
        FrameResourceLifetime.Persistent,
        colorSpace: receipt.frameColorSpace(), dynamicRange: receipt.frameDynamicRange())
    let pass = FramePassDescriptor(
        FramePassId("hdr.compose"), 0, FramePassKind.OffscreenComposition,
        writes: [output.id], colorSpace: receipt.frameColorSpace(),
        dynamicRange: receipt.frameDynamicRange())
    let graph = FrameGraph("hdr", 1, 1, 16, 16, [output], [pass])

    let rejected = compileFrameGraph(
        graph, FrameGraphCompilerState(),
        FrameGraphExecutorCapabilities(supportsExtendedDynamicRange: false))
    @Expect(!rejected.ok)
    @Expect(rejected.code, "unsupported-dynamic-range")

    let accepted = compileFrameGraph(
        graph, FrameGraphCompilerState(),
        FrameGraphExecutorCapabilities(supportsExtendedDynamicRange: true))
    @Expect(accepted.ok)
}

@Test
func hdrUnsupportedPlanDoesNotInvokeProvider(): Unit {
    let plan = planHdrSurface(
        hdrExtendedRequest(allowFallback: false), hdrTestAdapter(hasHdr: false),
        hdrTestSurface(false, false, generation: 1))
    let provider = RecordingHdrActivationProvider()
    let receipt = activateHdrSurface(plan, provider, "main-surface", 1)
    @Expect(!receipt.active)
    @Expect(receipt.code, "plan-unsupported")
    @Expect(provider.callCount(), 0)
}
