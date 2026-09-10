package chui.graphics

import sdl.BackdropEffectRequest

/** Pure lowering of one existing renderer-effect request into graph scheduling metadata. */
protected class RendererEffectFrameGraphBridge {
    public let ok: Bool
    public let code: String
    private let passValue: ?FramePassDescriptor

    init(ok: Bool, code: String, pass: ?FramePassDescriptor) {
        this.ok = ok
        this.code = code
        this.passValue = pass
    }

    public func pass(): ?FramePassDescriptor { passValue }
}

/**
 * The request's pixels are still applied by `RendererEffectAdapter`; the graph owns only ordering,
 * damage expansion and stable resource versions. Group IDs and provider receipts are not traced.
 */
protected func bridgeBackdropEffectRequest(
    request: BackdropEffectRequest,
    declarationOrder: Int64,
    input: FrameResourceId,
    output: FrameResourceId,
    surfaceWidth: Int64,
    surfaceHeight: Int64
): RendererEffectFrameGraphBridge {
    if (declarationOrder < 0 || surfaceWidth <= 0 || surfaceHeight <= 0 || input == output) {
        return RendererEffectFrameGraphBridge(false, "invalid-effect-bridge", None)
    }
    let source = request.resolvedBounds()
    let left = max(Int64(0), Int64(source.x))
    let top = max(Int64(0), Int64(source.y))
    let right = min(surfaceWidth, Int64(source.right() + 0.999))
    let bottom = min(surfaceHeight, Int64(source.bottom() + 0.999))
    if (right <= left || bottom <= top) {
        return RendererEffectFrameGraphBridge(false, "effect-outside-surface", None)
    }
    let bounds = FrameDamageRect(left, top, right - left, bottom - top)
    let radius = Int64(request.blurRadius + request.refraction * 8.0 + 2.999)
    let stableCode = rendererEffectFrameStableCode(
        request.cornerRadius.toString() + "|" + request.blurRadius.toString() + "|" +
        request.refraction.toString() + "|" + request.edgeResponse.toString() + "|" +
        request.requireShapeUnion.toString() + "|" + request.expectedFrameGeneration.toString())
    let pass = FramePassDescriptor(
        FramePassId("renderer.effect.${declarationOrder}"),
        declarationOrder,
        FramePassKind.RendererEffect,
        reads: [input],
        writes: [output],
        bounds: Some(bounds),
        declaredDamage: DamageRegion.bounded([bounds]),
        effectRadius: radius,
        stableInputCode: stableCode,
        canCull: true,
        canMerge: false
    )
    RendererEffectFrameGraphBridge(true, "accepted", Some(pass))
}

private func rendererEffectFrameStableCode(value: String): Int64 {
    var code: Int64 = 29
    for (byte in value.toArray()) {
        code = (code * 139 + Int64(byte)) % 2147483647
    }
    max(Int64(1), code)
}
