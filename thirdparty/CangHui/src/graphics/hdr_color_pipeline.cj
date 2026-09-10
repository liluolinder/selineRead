package chui.graphics

/** Internal HDR/EDR planning, provider activation and deterministic SDR tone-map contract. */
protected let CANGHUI_HDR_COLOR_PROTOCOL = "canghui.hdr-color.v2"

protected enum HdrDynamicRange <: Equatable<HdrDynamicRange> {
    | Sdr
    | EdrLinear
    | Hdr10Pq

    public operator func ==(other: HdrDynamicRange): Bool {
        hdrDynamicRangeName(this) == hdrDynamicRangeName(other)
    }

    public operator func !=(other: HdrDynamicRange): Bool { !(this == other) }
}

protected func hdrDynamicRangeName(value: HdrDynamicRange): String {
    match (value) {
        case HdrDynamicRange.Sdr => "sdr"
        case HdrDynamicRange.EdrLinear => "edr-linear"
        case HdrDynamicRange.Hdr10Pq => "hdr10-pq"
    }
}

protected enum HdrColorPrimaries <: Equatable<HdrColorPrimaries> {
    | Srgb
    | DisplayP3
    | Rec2020

    public operator func ==(other: HdrColorPrimaries): Bool {
        hdrColorPrimariesName(this) == hdrColorPrimariesName(other)
    }

    public operator func !=(other: HdrColorPrimaries): Bool { !(this == other) }
}

protected func hdrColorPrimariesName(value: HdrColorPrimaries): String {
    match (value) {
        case HdrColorPrimaries.Srgb => "srgb"
        case HdrColorPrimaries.DisplayP3 => "display-p3"
        case HdrColorPrimaries.Rec2020 => "rec2020"
    }
}

protected enum SdrToneMapOperator <: Equatable<SdrToneMapOperator> {
    | Clamp
    | Reinhard
    | AcesFitted

    public operator func ==(other: SdrToneMapOperator): Bool {
        sdrToneMapOperatorName(this) == sdrToneMapOperatorName(other)
    }

    public operator func !=(other: SdrToneMapOperator): Bool { !(this == other) }
}

protected func sdrToneMapOperatorName(value: SdrToneMapOperator): String {
    match (value) {
        case SdrToneMapOperator.Clamp => "clamp"
        case SdrToneMapOperator.Reinhard => "reinhard"
        case SdrToneMapOperator.AcesFitted => "aces-fitted"
    }
}

/** Content truth is independent from output capability and activation. */
protected struct HdrContentIntent {
    public let dynamicRange: HdrDynamicRange
    public let primaries: HdrColorPrimaries
    public let referenceHeadroom: Float32
    public let masteringPeakNits: Float32

    public init(
        dynamicRange: HdrDynamicRange,
        primaries: HdrColorPrimaries,
        referenceHeadroom!: Float32 = 1.0,
        masteringPeakNits!: Float32 = 100.0
    ) {
        if (!hdrFinitePositive(referenceHeadroom) || referenceHeadroom > 64.0 ||
            !hdrFinitePositive(masteringPeakNits) || masteringPeakNits > 10000.0) {
            throw IllegalArgumentException("HDR content intent limits are invalid")
        }
        if (dynamicRange == HdrDynamicRange.Sdr) {
            if (referenceHeadroom != 1.0 || masteringPeakNits > 100.0 ||
                primaries == HdrColorPrimaries.Rec2020) {
                throw IllegalArgumentException("SDR content requires unit headroom, <=100 nits and mappable primaries")
            }
        } else {
            if (referenceHeadroom <= 1.0 || masteringPeakNits <= 100.0) {
                throw IllegalArgumentException("extended-range content requires >1 headroom and >100 nits")
            }
            if (dynamicRange == HdrDynamicRange.Hdr10Pq &&
                primaries != HdrColorPrimaries.Rec2020) {
                throw IllegalArgumentException("HDR10 PQ requires Rec.2020 primaries")
            }
        }
        this.dynamicRange = dynamicRange
        this.primaries = primaries
        this.referenceHeadroom = referenceHeadroom
        this.masteringPeakNits = masteringPeakNits
    }
}

/** Output policy says whether extended presentation should be attempted. */
protected struct HdrOutputRequest {
    public let requestExtendedOutput: Bool
    public let allowSdrFallback: Bool
    public let fallbackToneMap: SdrToneMapOperator

    public init(
        requestExtendedOutput!: Bool = true,
        allowSdrFallback!: Bool = true,
        fallbackToneMap!: SdrToneMapOperator = SdrToneMapOperator.AcesFitted
    ) {
        this.requestExtendedOutput = requestExtendedOutput
        this.allowSdrFallback = allowSdrFallback
        this.fallbackToneMap = fallbackToneMap
    }
}

protected struct HdrPresentationRequest {
    public let content: HdrContentIntent
    public let output: HdrOutputRequest

    public init(content: HdrContentIntent, output!: HdrOutputRequest = HdrOutputRequest()) {
        this.content = content
        this.output = output
    }
}

/** Platform capability truth supplied after adapter selection; it is not activation truth. */
protected struct HdrSurfaceCapabilities {
    public let providerId: String
    public let surfaceId: String
    public let surfaceGeneration: Int64
    public let supportsEdr: Bool
    public let supportsHdr10: Bool
    public let maxHeadroom: Float32
    public let maxPeakNits: Float32

    public init(
        providerId: String,
        surfaceId: String,
        surfaceGeneration: Int64,
        supportsEdr: Bool,
        supportsHdr10: Bool,
        maxHeadroom!: Float32 = 1.0,
        maxPeakNits!: Float32 = 100.0
    ) {
        let _ = FramePassId(providerId)
        let _ = FramePassId(surfaceId)
        if (surfaceGeneration <= 0) {
            throw IllegalArgumentException("HDR surface generation must be positive")
        }
        if (!hdrFinitePositive(maxHeadroom) || maxHeadroom < 1.0 || maxHeadroom > 64.0 ||
            !hdrFinitePositive(maxPeakNits) || maxPeakNits > 10000.0) {
            throw IllegalArgumentException("HDR surface limits are invalid")
        }
        if ((supportsEdr || supportsHdr10) &&
            (maxHeadroom <= 1.0 || maxPeakNits <= 100.0)) {
            throw IllegalArgumentException("HDR/EDR capability requires >1 headroom and >100 nits")
        }
        this.providerId = providerId
        this.surfaceId = surfaceId
        this.surfaceGeneration = surfaceGeneration
        this.supportsEdr = supportsEdr
        this.supportsHdr10 = supportsHdr10
        this.maxHeadroom = maxHeadroom
        this.maxPeakNits = maxPeakNits
    }
}

protected enum HdrSurfacePlanStatus <: Equatable<HdrSurfacePlanStatus> {
    | SdrPlanned
    | ExtendedPlanned
    | ExtendedClamped
    | SdrFallbackPlanned
    | Unsupported

    public operator func ==(other: HdrSurfacePlanStatus): Bool {
        hdrSurfacePlanStatusName(this) == hdrSurfacePlanStatusName(other)
    }

    public operator func !=(other: HdrSurfacePlanStatus): Bool { !(this == other) }
}

protected func hdrSurfacePlanStatusName(value: HdrSurfacePlanStatus): String {
    match (value) {
        case HdrSurfacePlanStatus.SdrPlanned => "sdr-planned"
        case HdrSurfacePlanStatus.ExtendedPlanned => "extended-planned"
        case HdrSurfacePlanStatus.ExtendedClamped => "extended-clamped"
        case HdrSurfacePlanStatus.SdrFallbackPlanned => "sdr-fallback-planned"
        case HdrSurfacePlanStatus.Unsupported => "unsupported"
    }
}

/** Capability-derived plan only. It deliberately has no `active` or `selected` field. */
protected struct HdrSurfacePlan {
    public let status: HdrSurfacePlanStatus
    public let code: String
    public let request: HdrPresentationRequest
    public let providerId: String
    public let surfaceId: String
    public let surfaceGeneration: Int64
    public let capabilityAvailable: Bool
    public let plannedDynamicRange: HdrDynamicRange
    public let plannedPrimaries: HdrColorPrimaries
    public let plannedHeadroom: Float32
    public let plannedPeakNits: Float32

    public init(
        status: HdrSurfacePlanStatus,
        code: String,
        request: HdrPresentationRequest,
        providerId: String,
        surfaceId: String,
        surfaceGeneration: Int64,
        capabilityAvailable: Bool,
        plannedDynamicRange: HdrDynamicRange,
        plannedPrimaries: HdrColorPrimaries,
        plannedHeadroom: Float32,
        plannedPeakNits: Float32
    ) {
        let _ = FramePassId(code)
        let _ = FramePassId(providerId)
        let _ = FramePassId(surfaceId)
        if (surfaceGeneration <= 0 || !hdrFinitePositive(plannedHeadroom) ||
            !hdrFinitePositive(plannedPeakNits)) {
            throw IllegalArgumentException("HDR surface plan binding or limits are invalid")
        }
        this.status = status
        this.code = code
        this.request = request
        this.providerId = providerId
        this.surfaceId = surfaceId
        this.surfaceGeneration = surfaceGeneration
        this.capabilityAvailable = capabilityAvailable
        this.plannedDynamicRange = plannedDynamicRange
        this.plannedPrimaries = plannedPrimaries
        this.plannedHeadroom = plannedHeadroom
        this.plannedPeakNits = plannedPeakNits
    }

    public func ok(): Bool { status != HdrSurfacePlanStatus.Unsupported }
    public func plansExtendedOutput(): Bool {
        status == HdrSurfacePlanStatus.ExtendedPlanned ||
        status == HdrSurfacePlanStatus.ExtendedClamped
    }
    public func usesSdrToneMap(): Bool {
        request.content.dynamicRange != HdrDynamicRange.Sdr &&
        plannedDynamicRange == HdrDynamicRange.Sdr
    }
}

protected func planHdrSurface(
    request: HdrPresentationRequest,
    adapter: GraphicsAdapterCapabilities,
    surface: HdrSurfaceCapabilities
): HdrSurfacePlan {
    let content = request.content
    let adapterHdr = adapter.has(GraphicsCapability.HdrSurface)
    let rangeSupported = adapterHdr &&
        ((content.dynamicRange == HdrDynamicRange.EdrLinear && surface.supportsEdr) ||
         (content.dynamicRange == HdrDynamicRange.Hdr10Pq && surface.supportsHdr10))
    if (content.dynamicRange == HdrDynamicRange.Sdr) {
        return HdrSurfacePlan(
            HdrSurfacePlanStatus.SdrPlanned, "sdr-output-planned", request,
            surface.providerId, surface.surfaceId, surface.surfaceGeneration,
            false, HdrDynamicRange.Sdr, content.primaries, 1.0, content.masteringPeakNits)
    }
    if (!request.output.requestExtendedOutput) {
        return HdrSurfacePlan(
            HdrSurfacePlanStatus.SdrFallbackPlanned, "sdr-output-requested", request,
            surface.providerId, surface.surfaceId, surface.surfaceGeneration,
            rangeSupported, HdrDynamicRange.Sdr, HdrColorPrimaries.Srgb, 1.0, 100.0)
    }

    if (rangeSupported) {
        let headroom = min(content.referenceHeadroom, surface.maxHeadroom)
        let peakNits = min(content.masteringPeakNits, surface.maxPeakNits)
        if (headroom <= 1.0 || peakNits <= 100.0) {
            return hdrSdrFallbackOrUnsupported(
                request, surface, false, "extended-range-limit-invalid")
        }
        let exact = headroom == content.referenceHeadroom && peakNits == content.masteringPeakNits
        return HdrSurfacePlan(
            if (exact) { HdrSurfacePlanStatus.ExtendedPlanned } else {
                HdrSurfacePlanStatus.ExtendedClamped
            },
            if (exact) { "extended-output-planned" } else { "extended-output-clamped" },
            request, surface.providerId, surface.surfaceId, surface.surfaceGeneration,
            true, content.dynamicRange, content.primaries, headroom, peakNits)
    }
    hdrSdrFallbackOrUnsupported(request, surface, false, "extended-surface-unsupported")
}

private func hdrSdrFallbackOrUnsupported(
    request: HdrPresentationRequest,
    surface: HdrSurfaceCapabilities,
    capabilityAvailable: Bool,
    unsupportedCode: String
): HdrSurfacePlan {
    if (request.output.allowSdrFallback) {
        return HdrSurfacePlan(
            HdrSurfacePlanStatus.SdrFallbackPlanned, "sdr-fallback-planned", request,
            surface.providerId, surface.surfaceId, surface.surfaceGeneration,
            capabilityAvailable, HdrDynamicRange.Sdr, HdrColorPrimaries.Srgb, 1.0, 100.0)
    }
    HdrSurfacePlan(
        HdrSurfacePlanStatus.Unsupported, unsupportedCode, request,
        surface.providerId, surface.surfaceId, surface.surfaceGeneration,
        capabilityAvailable, HdrDynamicRange.Sdr, HdrColorPrimaries.Srgb, 1.0, 100.0)
}

/** Provider-authored result. It is validated against the plan before becoming a receipt. */
protected struct HdrProviderActivationResult {
    public let ok: Bool
    public let code: String
    public let actualDynamicRange: HdrDynamicRange
    public let actualPrimaries: HdrColorPrimaries
    public let actualHeadroom: Float32
    public let actualPeakNits: Float32
    public let outputSurfaceId: String
    public let outputSurfaceGeneration: Int64
    public let toneMapApplied: Bool
    public let toneMapOperator: SdrToneMapOperator
    public let outputEvidence: String

    public init(
        ok: Bool,
        code: String,
        actualDynamicRange: HdrDynamicRange,
        actualPrimaries: HdrColorPrimaries,
        actualHeadroom: Float32,
        actualPeakNits: Float32,
        outputSurfaceId: String,
        outputSurfaceGeneration: Int64,
        toneMapApplied: Bool,
        toneMapOperator: SdrToneMapOperator,
        outputEvidence: String
    ) {
        let _ = FramePassId(outputSurfaceId)
        if (code.isEmpty() || !hdrFinitePositive(actualHeadroom) ||
            !hdrFinitePositive(actualPeakNits) || outputSurfaceGeneration <= 0 ||
            (ok && outputEvidence.isEmpty())) {
            throw IllegalArgumentException("HDR activation result is invalid")
        }
        if (!outputEvidence.isEmpty()) { let _ = FramePassId(outputEvidence) }
        if (ok && actualDynamicRange == HdrDynamicRange.Sdr &&
            (actualHeadroom != 1.0 || actualPeakNits > 100.0 ||
             actualPrimaries == HdrColorPrimaries.Rec2020)) {
            throw IllegalArgumentException("active SDR output metadata is inconsistent")
        }
        if (ok && actualDynamicRange != HdrDynamicRange.Sdr &&
            (actualHeadroom <= 1.0 || actualPeakNits <= 100.0)) {
            throw IllegalArgumentException("active extended output metadata is inconsistent")
        }
        if (ok && actualDynamicRange == HdrDynamicRange.Hdr10Pq &&
            actualPrimaries != HdrColorPrimaries.Rec2020) {
            throw IllegalArgumentException("active HDR10 output requires Rec.2020")
        }
        if (ok && toneMapApplied && actualDynamicRange != HdrDynamicRange.Sdr) {
            throw IllegalArgumentException("tone-map evidence requires active SDR output")
        }
        this.ok = ok
        this.code = code
        this.actualDynamicRange = actualDynamicRange
        this.actualPrimaries = actualPrimaries
        this.actualHeadroom = actualHeadroom
        this.actualPeakNits = actualPeakNits
        this.outputSurfaceId = outputSurfaceId
        this.outputSurfaceGeneration = outputSurfaceGeneration
        this.toneMapApplied = toneMapApplied
        this.toneMapOperator = toneMapOperator
        this.outputEvidence = outputEvidence
    }
}

protected interface HdrSurfaceActivationProvider {
    func identity(): String
    func activate(
        plan: HdrSurfacePlan,
        surfaceId: String,
        surfaceGeneration: Int64
    ): HdrProviderActivationResult
}

/** Only this provider-backed receipt can claim actual output activation. */
protected struct HdrSurfaceActivationReceipt {
    public let active: Bool
    public let code: String
    public let providerId: String
    public let surfaceId: String
    public let surfaceGeneration: Int64
    public let planStatus: HdrSurfacePlanStatus
    public let actualDynamicRange: HdrDynamicRange
    public let actualPrimaries: HdrColorPrimaries
    public let actualHeadroom: Float32
    public let actualPeakNits: Float32
    public let fallbackToneMap: SdrToneMapOperator
    public let toneMapApplied: Bool
    public let toneMapOperator: SdrToneMapOperator
    public let outputEvidence: String

    public init(
        active: Bool,
        code: String,
        providerId: String,
        surfaceId: String,
        surfaceGeneration: Int64,
        plan: HdrSurfacePlan,
        actualDynamicRange: HdrDynamicRange,
        actualPrimaries: HdrColorPrimaries,
        actualHeadroom: Float32,
        actualPeakNits: Float32,
        toneMapApplied: Bool,
        toneMapOperator: SdrToneMapOperator,
        outputEvidence: String
    ) {
        this.active = active
        this.code = code
        this.providerId = providerId
        this.surfaceId = surfaceId
        this.surfaceGeneration = surfaceGeneration
        this.planStatus = plan.status
        this.actualDynamicRange = actualDynamicRange
        this.actualPrimaries = actualPrimaries
        this.actualHeadroom = actualHeadroom
        this.actualPeakNits = actualPeakNits
        this.fallbackToneMap = plan.request.output.fallbackToneMap
        this.toneMapApplied = toneMapApplied
        this.toneMapOperator = toneMapOperator
        this.outputEvidence = outputEvidence
    }

    public func extendedOutputActive(): Bool {
        active && actualDynamicRange != HdrDynamicRange.Sdr
    }

    public func usesSdrToneMap(): Bool {
        active && toneMapApplied
    }

    public func frameColorSpace(): GraphicsColorSpace {
        if (!active) { throw IllegalStateException("inactive HDR receipt has no frame color space") }
        hdrFrameColorSpace(actualDynamicRange, actualPrimaries)
    }

    public func frameDynamicRange(): FrameDynamicRange {
        if (!active) { throw IllegalStateException("inactive HDR receipt has no frame dynamic range") }
        if (actualDynamicRange == HdrDynamicRange.Sdr) {
            FrameDynamicRange.Sdr
        } else {
            FrameDynamicRange.ReservedExtended
        }
    }
}

protected func activateHdrSurface(
    plan: HdrSurfacePlan,
    provider: HdrSurfaceActivationProvider,
    surfaceId: String,
    surfaceGeneration: Int64
): HdrSurfaceActivationReceipt {
    let providerId = provider.identity()
    let _ = FramePassId(providerId)
    let _ = FramePassId(surfaceId)
    if (surfaceGeneration <= 0) {
        throw IllegalArgumentException("HDR surface generation must be positive")
    }
    if (providerId != plan.providerId || surfaceId != plan.surfaceId ||
        surfaceGeneration != plan.surfaceGeneration) {
        return HdrSurfaceActivationReceipt(
            false, "plan-surface-binding-mismatch", providerId, surfaceId,
            surfaceGeneration, plan, HdrDynamicRange.Sdr, HdrColorPrimaries.Srgb,
            1.0, 100.0, false, plan.request.output.fallbackToneMap, "")
    }
    if (!plan.ok()) {
        return HdrSurfaceActivationReceipt(
            false, "plan-unsupported", providerId, surfaceId, surfaceGeneration, plan,
            HdrDynamicRange.Sdr, HdrColorPrimaries.Srgb, 1.0, 100.0,
            false, plan.request.output.fallbackToneMap, "")
    }

    let result = provider.activate(plan, surfaceId, surfaceGeneration)
    if (!result.ok) {
        return HdrSurfaceActivationReceipt(
            false, "provider-activation-failed:" + result.code,
            providerId, surfaceId, surfaceGeneration, plan,
            result.actualDynamicRange, result.actualPrimaries,
            result.actualHeadroom, result.actualPeakNits, false,
            result.toneMapOperator, "")
    }

    if (result.outputSurfaceId != surfaceId ||
        result.outputSurfaceGeneration != surfaceGeneration) {
        return HdrSurfaceActivationReceipt(
            false, "provider-output-binding-mismatch", providerId, surfaceId,
            surfaceGeneration, plan, result.actualDynamicRange, result.actualPrimaries,
            result.actualHeadroom, result.actualPeakNits, false,
            result.toneMapOperator, "")
    }

    let plannedMatch = result.actualDynamicRange == plan.plannedDynamicRange &&
        result.actualPrimaries == plan.plannedPrimaries &&
        result.actualHeadroom <= plan.plannedHeadroom &&
        result.actualPeakNits <= plan.plannedPeakNits
    let allowedProviderFallback = plan.plansExtendedOutput() &&
        plan.request.output.allowSdrFallback &&
        result.actualDynamicRange == HdrDynamicRange.Sdr &&
        result.actualPrimaries == HdrColorPrimaries.Srgb &&
        result.actualHeadroom == 1.0 && result.actualPeakNits <= 100.0
    if (!plannedMatch && !allowedProviderFallback) {
        return HdrSurfaceActivationReceipt(
            false, "provider-result-plan-mismatch", providerId, surfaceId,
            surfaceGeneration, plan, result.actualDynamicRange, result.actualPrimaries,
            result.actualHeadroom, result.actualPeakNits, false,
            result.toneMapOperator, "")
    }
    let toneMapExpected = plan.request.content.dynamicRange != HdrDynamicRange.Sdr &&
        result.actualDynamicRange == HdrDynamicRange.Sdr
    if (result.toneMapApplied != toneMapExpected ||
        (toneMapExpected && result.toneMapOperator != plan.request.output.fallbackToneMap)) {
        return HdrSurfaceActivationReceipt(
            false, "provider-tone-map-evidence-mismatch", providerId, surfaceId,
            surfaceGeneration, plan, result.actualDynamicRange, result.actualPrimaries,
            result.actualHeadroom, result.actualPeakNits, false,
            result.toneMapOperator, "")
    }
    HdrSurfaceActivationReceipt(
        true,
        if (allowedProviderFallback) { "provider-sdr-fallback-active" } else {
            "provider-output-active"
        },
        providerId, surfaceId, surfaceGeneration, plan,
        result.actualDynamicRange, result.actualPrimaries,
        result.actualHeadroom, result.actualPeakNits, result.toneMapApplied,
        result.toneMapOperator, result.outputEvidence)
}

private func hdrFrameColorSpace(
    dynamicRange: HdrDynamicRange,
    primaries: HdrColorPrimaries
): GraphicsColorSpace {
    if (dynamicRange != HdrDynamicRange.Sdr) {
        return GraphicsColorSpace.ExtendedLinearSrgb
    }
    match (primaries) {
        case HdrColorPrimaries.Srgb => GraphicsColorSpace.Srgb
        case HdrColorPrimaries.DisplayP3 => GraphicsColorSpace.DisplayP3
        case HdrColorPrimaries.Rec2020 =>
            throw IllegalStateException("SDR Rec.2020 has no portable FrameGraph mapping")
    }
}

protected struct HdrLinearRgb <: Equatable<HdrLinearRgb> {
    public let red: Float32
    public let green: Float32
    public let blue: Float32

    public init(red: Float32, green: Float32, blue: Float32) {
        this.red = red
        this.green = green
        this.blue = blue
    }

    public operator func ==(other: HdrLinearRgb): Bool {
        red == other.red && green == other.green && blue == other.blue
    }

    public operator func !=(other: HdrLinearRgb): Bool { !(this == other) }
}

/** Pure deterministic SDR oracle. It intentionally excludes display-specific dithering. */
protected func toneMapHdrToSdr(value: HdrLinearRgb, algorithm: SdrToneMapOperator): HdrLinearRgb {
    HdrLinearRgb(
        toneMapHdrChannel(value.red, algorithm),
        toneMapHdrChannel(value.green, algorithm),
        toneMapHdrChannel(value.blue, algorithm))
}

private func toneMapHdrChannel(value: Float32, algorithm: SdrToneMapOperator): Float32 {
    let x = sanitizeHdrChannel(value)
    let mapped = match (algorithm) {
        case SdrToneMapOperator.Clamp => x
        case SdrToneMapOperator.Reinhard => x / (1.0 + x)
        case SdrToneMapOperator.AcesFitted =>
            (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)
    }
    min(1.0, max(0.0, mapped))
}

private func sanitizeHdrChannel(value: Float32): Float32 {
    if (value < 0.0) { return 0.0 }
    if (value > 65504.0) { return 65504.0 }
    if (value - value != 0.0) { return 0.0 }
    value
}

private func hdrFinitePositive(value: Float32): Bool {
    value > 0.0 && value <= 65504.0 && value - value == 0.0
}
