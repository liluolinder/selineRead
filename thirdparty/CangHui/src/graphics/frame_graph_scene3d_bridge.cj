package chui.graphics

/** Explicit Scene3D ingress truth; a native child surface is a barrier, not unified pixels. */
protected class Scene3DFrameGraphBridge {
    public let ok: Bool
    public let code: String
    public let unifiedPixels: Bool
    public let clipOcclusionUnified: Bool
    private let resourceValue: ?FrameResourceDescriptor
    private let passValue: ?FramePassDescriptor

    init(
        ok: Bool,
        code: String,
        unifiedPixels: Bool,
        clipOcclusionUnified: Bool,
        resource: ?FrameResourceDescriptor,
        pass: ?FramePassDescriptor
    ) {
        this.ok = ok
        this.code = code
        this.unifiedPixels = unifiedPixels
        this.clipOcclusionUnified = clipOcclusionUnified
        this.resourceValue = resource
        this.passValue = pass
    }

    public func resource(): ?FrameResourceDescriptor { resourceValue }
    public func pass(): ?FramePassDescriptor { passValue }
}

/**
 * Creates only scheduling metadata. Scene3D provider lifecycle, focus, pointer, keyboard and
 * gamepad routing remain owned by Scene3D; no native surface token enters this graph.
 */
protected func bridgeScene3DExternalSurface(
    viewIdentity: String,
    generation: Int64,
    declarationOrder: Int64,
    mode: FrameExternalMode,
    providerProvedSharedTexture!: Bool = false,
    bounds!: ?FrameDamageRect = None,
    damage!: DamageRegion = DamageRegion.full()
): Scene3DFrameGraphBridge {
    if (viewIdentity.isEmpty() || generation <= 0 || declarationOrder < 0) {
        return Scene3DFrameGraphBridge(
            false, "invalid-scene3d-identity", false, false, None, None)
    }
    if (mode == FrameExternalMode.NoExternalSurface) {
        return Scene3DFrameGraphBridge(
            false, "scene3d-external-mode-required", false, false, None, None)
    }
    if (mode == FrameExternalMode.SharedTexture && !providerProvedSharedTexture) {
        return Scene3DFrameGraphBridge(
            false, "shared-texture-unproven", false, false, None, None)
    }

    let token = scene3DFrameStableToken(viewIdentity) + "." + declarationOrder.toString()
    let resourceId = FrameResourceId("scene3d.resource.${token}", generation)
    let resourceKind = if (mode == FrameExternalMode.SharedTexture) {
        FrameResourceKind.Texture
    } else {
        FrameResourceKind.ExternalSurface
    }
    let resource = FrameResourceDescriptor(
        resourceId, resourceKind, FrameResourceLifetime.Imported)
    let pass = FramePassDescriptor(
        FramePassId("scene3d.barrier.${token}"),
        declarationOrder,
        FramePassKind.ExternalScene3D,
        reads: [resourceId],
        bounds: bounds,
        declaredDamage: damage,
        stableInputCode: generation,
        canCull: false,
        externalMode: mode
    )
    let unified = mode == FrameExternalMode.SharedTexture
    Scene3DFrameGraphBridge(
        true,
        if (unified) { "shared-texture-proved" } else { "native-child-surface-barrier" },
        unified,
        false,
        Some(resource),
        Some(pass)
    )
}

/**
 * Bridges one copied provider frame into the ordinary target-version chain.
 *
 * Unlike the native-child barrier, this pass reads the previous UI target and a handle-free
 * imported texture snapshot, then writes a new target version. The executor therefore composes
 * the pixels inside the same transaction and ordinary later UI passes can occlude the scene.
 */
protected func bridgeScene3DSharedFrame(
    viewIdentity: String,
    generation: Int64,
    frameId: Int64,
    declarationOrder: Int64,
    inputTarget: FrameResourceId,
    outputTarget: FrameResourceId,
    declaredBytes: Int64,
    contentCode: Int64,
    syncEpoch: Int64,
    bounds: FrameDamageRect,
    damage!: DamageRegion = DamageRegion.full(),
    colorSpace!: GraphicsColorSpace = GraphicsColorSpace.Srgb,
    alphaMode!: GraphicsAlphaMode = GraphicsAlphaMode.Premultiplied,
    dynamicRange!: FrameDynamicRange = FrameDynamicRange.Sdr
): Scene3DFrameGraphBridge {
    if (viewIdentity.isEmpty() || generation <= 0 || frameId < 0 || declarationOrder < 0 ||
        declaredBytes <= 0 || contentCode <= 0 || syncEpoch < 0 || inputTarget == outputTarget) {
        return Scene3DFrameGraphBridge(
            false, "invalid-scene3d-shared-frame", false, false, None, None)
    }
    let token = scene3DFrameStableToken(viewIdentity) + "." + declarationOrder.toString()
    let sourceId = FrameResourceId("scene3d.shared.${token}", generation)
    let resource = FrameResourceDescriptor(
        sourceId,
        FrameResourceKind.Texture,
        FrameResourceLifetime.Imported,
        declaredBytes: declaredBytes,
        colorSpace: colorSpace,
        alphaMode: alphaMode,
        dynamicRange: dynamicRange)
    let stableCode = scene3DSharedFrameStableCode(
        generation, frameId, contentCode, syncEpoch)
    let pass = FramePassDescriptor(
        FramePassId("scene3d.composite.${token}"),
        declarationOrder,
        FramePassKind.ExternalScene3D,
        reads: [inputTarget, sourceId],
        writes: [outputTarget],
        bounds: Some(bounds),
        declaredDamage: damage,
        stableInputCode: stableCode,
        canCull: false,
        colorSpace: colorSpace,
        alphaMode: alphaMode,
        dynamicRange: dynamicRange,
        externalMode: FrameExternalMode.SharedTexture)
    Scene3DFrameGraphBridge(
        true,
        "shared-frame-composition",
        true,
        false,
        Some(resource),
        Some(pass))
}

/**
 * Imports one software/native-provider frame and emits only its acquire/synchronization barrier.
 * The ordinary Ui2D pass declares the returned texture resource as an input and samples it while
 * walking the widget tree, preserving exact sibling paint order, clips and overlays.
 */
protected func bridgeScene3DSharedFrameImport(
    viewIdentity: String,
    generation: Int64,
    frameId: Int64,
    declarationOrder: Int64,
    declaredBytes: Int64,
    contentCode: Int64,
    syncEpoch: Int64,
    bounds: FrameDamageRect,
    damage!: DamageRegion = DamageRegion.full(),
    colorSpace!: GraphicsColorSpace = GraphicsColorSpace.Srgb,
    alphaMode!: GraphicsAlphaMode = GraphicsAlphaMode.Premultiplied,
    dynamicRange!: FrameDynamicRange = FrameDynamicRange.Sdr
): Scene3DFrameGraphBridge {
    if (viewIdentity.isEmpty() || generation <= 0 || frameId < 0 || declarationOrder < 0 ||
        declaredBytes <= 0 || contentCode <= 0 || syncEpoch < 0) {
        return Scene3DFrameGraphBridge(
            false, "invalid-scene3d-shared-import", false, false, None, None)
    }
    let token = scene3DFrameStableToken(viewIdentity) + "." + declarationOrder.toString()
    let sourceId = FrameResourceId("scene3d.shared.${token}", generation)
    let resource = FrameResourceDescriptor(
        sourceId,
        FrameResourceKind.Texture,
        FrameResourceLifetime.Imported,
        declaredBytes: declaredBytes,
        colorSpace: colorSpace,
        alphaMode: alphaMode,
        dynamicRange: dynamicRange)
    let pass = FramePassDescriptor(
        FramePassId("scene3d.acquire.${token}"),
        declarationOrder,
        FramePassKind.ExternalScene3D,
        reads: [sourceId],
        bounds: Some(bounds),
        declaredDamage: damage,
        stableInputCode: scene3DSharedFrameStableCode(generation, frameId, contentCode, syncEpoch),
        canCull: false,
        colorSpace: colorSpace,
        alphaMode: alphaMode,
        dynamicRange: dynamicRange,
        externalMode: FrameExternalMode.SharedTexture)
    Scene3DFrameGraphBridge(
        true, "shared-frame-import", true, false, Some(resource), Some(pass))
}

private func scene3DFrameStableToken(value: String): String {
    var code: Int64 = 23
    for (byte in value.toArray()) {
        code = (code * 137 + Int64(byte)) % 2147483647
    }
    code.toString()
}

private func scene3DSharedFrameStableCode(
    generation: Int64,
    frameId: Int64,
    contentCode: Int64,
    syncEpoch: Int64
): Int64 {
    let modulus: Int64 = 2147483647
    var code: Int64 = 41
    code = (code * 137 + scene3DStableCodePart(generation, modulus)) % modulus
    code = (code * 137 + scene3DStableCodePart(frameId, modulus)) % modulus
    code = (code * 137 + scene3DStableCodePart(contentCode, modulus)) % modulus
    code = (code * 137 + scene3DStableCodePart(syncEpoch, modulus)) % modulus
    max(Int64(1), code)
}

private func scene3DStableCodePart(value: Int64, modulus: Int64): Int64 {
    let reduced = value % modulus
    if (reduced < 0) { reduced + modulus } else { reduced }
}
