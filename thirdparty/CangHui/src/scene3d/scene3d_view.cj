package chui.scene3d

import chui.core.{ControlSemantics, SemanticActionKind, SharedFrameSurface, UiContext, Widget, drawFocusRing, emit,
    focusableControlIdentity, recordControlSemantics}
import chui.graphics.compositeSdlSharedRgbaFrame
import chui.host.{HostNativeSurfaceService, NativeSurfaceBackend, NativeSurfaceDescriptor, NativeSurfaceFrame,
    NativeSurfaceRenderer}
import sdl.{DeviceRotation, GamepadAxis, GamepadButton, GamepadConnectionState, GamepadDevice, MouseButton,
    Rect, Size, UiEvent}

/** Logical placement requested by one Scene3DView inside a normal CangHui layout. */
public struct Scene3DViewPlacement {
    public let viewId: String
    public let x: Float32
    public let y: Float32
    public let width: Float32
    public let height: Float32
    public let scale: Float32

    public init(viewId: String, x: Float32, y: Float32, width: Float32, height: Float32, scale: Float32) {
        if (viewId.isEmpty() || width <= 0.0 || height <= 0.0 || scale <= 0.0) {
            throw IllegalArgumentException("scene3d view placement must have identity and positive geometry")
        }
        this.viewId = viewId
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        this.scale = scale
    }
}

/** Placement receipt is distinct from renderer lifecycle and never carries a native handle. */
public struct Scene3DViewHostReceipt {
    public let ok: Bool
    public let operation: String
    public let code: String
    public let viewId: String
    public let detail: String

    public init(ok: Bool, operation: String, code: String, viewId: String, detail: String) {
        this.ok = ok
        this.operation = operation
        this.code = code
        this.viewId = viewId
        this.detail = detail
    }
}

/** Host extension that positions a native child surface under a normal widget. */
public interface Scene3DViewHost <: HostNativeSurfaceService {
    func place(placement: Scene3DViewPlacement): Scene3DViewHostReceipt
    func remove(viewId: String): Scene3DViewHostReceipt
}

/** Supplies one immutable product scene at a host frame boundary. */
public interface Scene3DViewFrameSource {
    func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot
}

/** Input delivered in widget-local coordinates after Scene3DView owns focus. */
public enum Scene3DViewInputEvent {
    | PointerDown(Float32, Float32, Scene3DHitTestResult)
    | PointerMove(Float32, Float32)
    | PointerUp(Float32, Float32)
    | PointerWheel(Float32, Float32, Float32, Float32)
    | GamepadConnectionChanged(GamepadDevice, GamepadConnectionState)
    | GamepadAxisMotion(UInt32, GamepadAxis, Float32)
    | GamepadButtonDown(UInt32, GamepadButton)
    | GamepadButtonUp(UInt32, GamepadButton)
}

/**
 * Retained bridge between an ephemeral widget and host/provider lifecycle.
 * Applications retain one controller and may rebuild Scene3DView values freely.
 */
public class Scene3DViewController <: NativeSurfaceRenderer {
    private let viewId: String
    private let host: Scene3DViewHost
    private let provider: Scene3DProvider
    private let resource: Scene3DResource
    private let frameSource: Scene3DViewFrameSource
    private let inputHandler: (Scene3DViewInputEvent) -> Bool
    private let compositionMode: Scene3DCompositionMode
    private let sharedFrameProvider: ?Scene3DSharedFrameProvider
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var lastFrameId: Int64 = -1
    private var attached = false
    private var hasPresentedFrame = false
    private var placed = false
    private var placementX: Float32 = 0.0
    private var placementY: Float32 = 0.0
    private var placementWidth: Float32 = 0.0
    private var placementHeight: Float32 = 0.0
    private var placementScale: Float32 = 0.0
    private var placementRevision: Int64 = 0
    private var ownerContextToken: Int64 = 0
    // Composition capability belongs to the retained controller, not the ephemeral widget.
    // Declarative bodies rebuild Scene3DView every frame, while this generation-scoped failure
    // memory must survive those rebuilds so a failed shared upload remains on native-child fallback.
    private var sharedFrameFailureGeneration: Int64 = -1
    private var lastLifecycleReceipt = Scene3DReceipt(false, "initialize", "not-attached", 0, -1,
        "waiting for a host surface")
    private var lastHostReceipt = Scene3DViewHostReceipt(false, "place", "not-placed", "",
        "waiting for widget layout")

    public init(
        viewId: String,
        host: Scene3DViewHost,
        provider: Scene3DProvider,
        resource: Scene3DResource,
        frameSource: Scene3DViewFrameSource,
        onInput!: (Scene3DViewInputEvent) -> Bool = { _ => false },
        compositionMode!: Scene3DCompositionMode = Scene3DCompositionMode.NativeChild
    ) {
        if (viewId.isEmpty()) { throw IllegalArgumentException("scene3d view id must be present") }
        this.viewId = viewId
        this.host = host
        this.provider = provider
        this.resource = resource
        this.frameSource = frameSource
        this.inputHandler = onInput
        this.compositionMode = compositionMode
        this.sharedFrameProvider = provider as Scene3DSharedFrameProvider
        this.lastHostReceipt = Scene3DViewHostReceipt(false, "place", "not-placed", viewId,
            "waiting for widget layout")
        host.bind(this)
    }

    public func id(): String { viewId }
    public func isAttached(): Bool { attached }
    public func currentGeneration(): Int64 { generation }
    public func currentFrameId(): Int64 { lastFrameId }
    public func lifecycleReceipt(): Scene3DReceipt { lastLifecycleReceipt }
    public func hostReceipt(): Scene3DViewHostReceipt { lastHostReceipt }
    public func requestedCompositionMode(): Scene3DCompositionMode { compositionMode }
    public func canAcquireSharedFrame(): Bool {
        compositionMode == Scene3DCompositionMode.PreferSharedFrame && sharedFrameProvider.isSome()
    }

    protected func sharedFrameFallbackRequired(value: Int64): Bool {
        value > 0 && sharedFrameFailureGeneration == value
    }

    protected func recordSharedFrameComposition(value: Int64, ok: Bool): Unit {
        if (ok) {
            if (sharedFrameFailureGeneration == value) { sharedFrameFailureGeneration = -1 }
        } else if (value > 0 && value == generation) {
            sharedFrameFailureGeneration = value
        }
    }

    /** Permanently binds this retained native-surface controller to one window-local UiContext. */
    protected func bindOwnerContext(ctx: UiContext): Unit {
        let candidate = ctx.ownershipToken()
        if (ownerContextToken == 0) {
            ownerContextToken = candidate
        } else if (ownerContextToken != candidate) {
            throw IllegalStateException(
                "Scene3DViewController '${viewId}' cannot be reused across UiContext/window owners")
        }
    }

    public func place(rect: Rect, scale: Float32): Scene3DViewHostReceipt {
        if (rect.w <= 0.0 || rect.h <= 0.0 || scale <= 0.0) {
            lastHostReceipt = Scene3DViewHostReceipt(false, "place", "invalid-geometry", viewId,
                "widget geometry and scale must be positive")
            return lastHostReceipt
        }
        if (placed && rect.x == placementX && rect.y == placementY && rect.w == placementWidth &&
            rect.h == placementHeight && scale == placementScale) {
            lastHostReceipt = Scene3DViewHostReceipt(true, "place", "unchanged", viewId,
                "placement already matches the host")
            return lastHostReceipt
        }
        let receipt = host.place(Scene3DViewPlacement(viewId, rect.x, rect.y, rect.w, rect.h, scale))
        lastHostReceipt = receipt
        if (receipt.ok) {
            placementRevision += 1
            placed = true
            placementX = rect.x
            placementY = rect.y
            placementWidth = rect.w
            placementHeight = rect.h
            placementScale = scale
        }
        receipt
    }

    public func remove(): Scene3DViewHostReceipt {
        let receipt = host.remove(viewId)
        lastHostReceipt = receipt
        if (receipt.ok) { placed = false }
        receipt
    }

    public func requestFrame(): Unit { host.requestFrame() }

    public func attach(surface: NativeSurfaceDescriptor): Unit {
        if (surface.generation <= 0) {
            lastLifecycleReceipt = reject("attach", "invalid-generation", surface.generation, 0,
                "host surface generation must be positive")
            return
        }
        let clock = Scene3DFrameClock(0, 0, 0)
        let receipt = provider.attach(toSceneSurface(surface), clock)
        lastLifecycleReceipt = receipt
        if (!receipt.ok) { return }
        attached = true
        hasPresentedFrame = false
        surfaceId = surface.id
        generation = surface.generation
        sharedFrameFailureGeneration = -1
        lastFrameId = clock.frameId
        let loaded = provider.loadScene(resource)
        lastLifecycleReceipt = loaded
        if (!loaded.ok) {
            let _ = provider.detach(surface.id, surface.generation)
            attached = false
            hasPresentedFrame = false
            surfaceId = ""
            generation = 0
            sharedFrameFailureGeneration = -1
            lastFrameId = -1
        }
    }

    public func resize(surface: NativeSurfaceDescriptor): Unit {
        if (!matches(surface.id, surface.generation)) {
            lastLifecycleReceipt = reject("resize", "stale-generation", surface.generation, lastFrameId,
                "resize does not match the attached host surface")
            return
        }
        lastLifecycleReceipt = provider.resize(toSceneSurface(surface))
    }

    public func draw(frame: NativeSurfaceFrame): Unit {
        if (!attached) {
            lastLifecycleReceipt = reject("frame", "not-attached", generation, frame.frameId,
                "frame arrived without an attached host surface")
            return
        }
        let clock = Scene3DFrameClock(frame.frameId, frame.timestampNanos, frame.targetTimestampNanos)
        let snapshot = frameSource.snapshot(clock)
        let submitted = provider.submit(snapshot, clock)
        lastLifecycleReceipt = submitted
        if (!submitted.ok) { return }
        let presented = provider.present(clock)
        lastLifecycleReceipt = presented
        if (presented.ok) {
            lastFrameId = frame.frameId
            hasPresentedFrame = true
        }
    }

    public func detach(id: String, value: Int64): Unit {
        if (!matches(id, value)) {
            lastLifecycleReceipt = reject("detach", "stale-generation", value, lastFrameId,
                "detach does not match the attached host surface")
            return
        }
        let receipt = provider.detach(id, value)
        lastLifecycleReceipt = receipt
        if (receipt.ok) {
            attached = false
            hasPresentedFrame = false
            surfaceId = ""
            generation = 0
            sharedFrameFailureGeneration = -1
            lastFrameId = -1
        }
    }

    public func hitTest(x: Float32, y: Float32): Scene3DHitTestResult {
        if (!attached || lastFrameId < 0) { return Scene3DHitTestResult.none(generation, lastFrameId) }
        provider.hitTest(Scene3DHitTestRequest(x, y, generation, lastFrameId))
    }

    public func dispatchInput(event: Scene3DViewInputEvent): Bool { inputHandler(event) }

    /**
     * Acquires one provider frame and transfers its exactly-once finish callback to UiContext.
     * The lease remains alive until graph commit/rollback or legacy fallback. Returning false
     * finishes the lease immediately and leaves the caller on the native-child path.
     */
    protected func registerSharedFrame(ctx: UiContext, bounds: Rect, rotationCode: String): Bool {
        if (!attached || !hasPresentedFrame ||
            compositionMode != Scene3DCompositionMode.PreferSharedFrame) {
            return false
        }
        let provider = match (sharedFrameProvider) {
            case Some(value) => value
            case None => return false
        }
        if (placementRevision <= 0 || rotationCode.isEmpty()) { return false }
        let request = Scene3DSharedFrameRequest(
            surfaceId,
            generation,
            lastFrameId,
            bounds.w,
            bounds.h,
            ctx.displayScale,
            placementRevision,
            rotationCode)
        let lease = match (provider.acquireSharedFrame(request)) {
            case Some(value) => value
            case None => return false
        }
        try {
            if (lease.surfaceId != surfaceId || lease.generation != generation ||
                lease.frameId != lastFrameId || !sameScene3DSharedRequest(lease.request, request)) {
                let _ = lease.finish(Scene3DSharedFrameFinishReason.Rejected)
                return false
            }
            // The first portable compositor uploads RGBA8 SDR. Extended-linear/HDR frames keep
            // their explicit contract but remain on the native-child path until a selected target
            // proves the matching color pipeline; metadata alone must never activate HDR.
            if (lease.dynamicRange != Scene3DSharedDynamicRange.Sdr ||
                lease.colorSpace != Scene3DSharedColorSpace.Srgb ||
                lease.payloadKind != Scene3DSharedFramePayloadKind.CpuRgba8 ||
                lease.acquireSync.waitRequired) {
                let _ = lease.finish(Scene3DSharedFrameFinishReason.Fallback)
                return false
            }
            let pixels = lease.copyRgbaPixels()
            ctx.registerSharedFrameSurface(SharedFrameSurface(
                viewId,
                lease.generation,
                lease.frameId,
                bounds,
                lease.pixelWidth,
                lease.pixelHeight,
                lease.rowBytes,
                scene3DSharedColorSpaceName(lease.colorSpace),
                scene3DSharedAlphaModeName(lease.alphaMode),
                scene3DSharedDynamicRangeName(lease.dynamicRange),
                lease.syncEpoch,
                lease.contentCode,
                lease.request.rotationCode,
                pixels,
                onFinish: {outcome =>
                    lease.finish(scene3DSharedFrameFinishReasonFromCore(outcome)).ok
                }
            ))
            true
        } catch (_: Exception) {
            let _ = lease.finish(Scene3DSharedFrameFinishReason.Rejected)
            false
        }
    }

    private func matches(id: String, value: Int64): Bool {
        attached && id == surfaceId && value == generation
    }

    private func reject(operation: String, code: String, value: Int64, frameId: Int64,
        detail: String): Scene3DReceipt {
        Scene3DReceipt(false, operation, code, value, frameId, detail)
    }
}

/** Embedded scene leaf; size/placement participates in the same layout as every other widget. */
public class Scene3DView <: Widget {
    private let controller: Scene3DViewController
    private let controlId: String
    private let preferredWidth: Float32
    private let preferredHeight: Float32
    private var frame = Rect.zero()
    private var nativeFallbackRegisteredThisFrame: Bool = false

    public init(controller: Scene3DViewController, width!: Float32 = 320.0, height!: Float32 = 240.0) {
        if (width <= 0.0 || height <= 0.0) {
            throw IllegalArgumentException("scene3d view preferred size must be positive")
        }
        this.controller = controller
        this.controlId = focusableControlIdentity(controller.id())
        this.preferredWidth = width
        this.preferredHeight = height
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, preferredWidth), min(available.h, preferredHeight))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        nativeFallbackRegisteredThisFrame = false
        controller.bindOwnerContext(ctx)
        let placement = controller.place(rect, ctx.displayScale)
        // A proven shared frame is sampled during this widget's ordinary draw position; otherwise
        // the FrameGraph keeps the established native-child scheduling barrier. Provider lifecycle
        // and input remain here, and failed placement never becomes a phantom surface.
        let generation = controller.currentGeneration()
        if (placement.ok && controller.isAttached() && generation > 0) {
            if (controller.sharedFrameFallbackRequired(generation)) {
                registerNativeFallback(ctx, rect, generation)
            } else if (!controller.registerSharedFrame(
                ctx, rect, scene3DDeviceRotationCode(ctx.deviceRotation()))) {
                registerNativeFallback(ctx, rect, generation)
            }
        }
    }

    public func draw(ctx: UiContext): Unit {
        recordControlSemantics(ctx, frame, "Scene3DView", ControlSemantics(
            "scene3d", label: controller.id(), action: "", shortcut: "", actionOwner: controlId,
            typedActions: [SemanticActionKind.Focus]
        ))
        var composed = false
        match (ctx.sharedFrameSurface(controller.id())) {
            case Some(surface) =>
                let result = compositeSdlSharedRgbaFrame(
                    ctx.renderer,
                    true,
                    surface.pixelWidth,
                    surface.pixelHeight,
                    surface.rowBytes,
                    surface.alphaMode,
                    surface.pixels(),
                    frame,
                    cornerRadius: ctx.theme.smallRadius,
                    rotationCode: surface.rotationCode)
                composed = result.ok
                surface.recordComposition(result.ok, result.code)
                controller.recordSharedFrameComposition(surface.generation, result.ok)
                if (!result.ok) {
                    // Keep the established native child alive for this terminal frame and every
                    // later frame of the same surface generation. A new generation may retry the
                    // shared path, while a persistent renderer/upload failure cannot oscillate
                    // between missing 3D content and a placeholder.
                    registerNativeFallback(ctx, frame, surface.generation)
                }
            case None => ()
        }
        if (!composed) { ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.field) }
        if (ctx.showFocusRing(controlId)) { drawFocusRing(ctx, frame, ctx.theme.smallRadius) }
    }

    private func registerNativeFallback(ctx: UiContext, bounds: Rect, generation: Int64): Unit {
        if (nativeFallbackRegisteredThisFrame) { return }
        ctx.registerNativeChildFrameSurface(controller.id(), generation, bounds)
        nativeFallbackRegisteredThisFrame = true
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) =>
                ctx.requestFrame()
                controller.requestFrame()
                return false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    let localX = x - frame.x
                    let localY = y - frame.y
                    let _ = controller.dispatchInput(Scene3DViewInputEvent.PointerDown(localX, localY,
                        controller.hitTest(localX, localY)))
                    return true
                }
            case UiEvent.MouseMove(x, y) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.PointerMove(x - frame.x, y - frame.y))
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.PointerUp(x - frame.x, y - frame.y))
                }
            case UiEvent.MouseWheel(dx, dy, x, y) =>
                if (ctx.hasFocus(controlId) && frame.contains(x, y)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.PointerWheel(dx, dy,
                        x - frame.x, y - frame.y))
                }
            case UiEvent.GamepadConnectionChanged(device, state) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadConnectionChanged(device, state))
                }
            case UiEvent.GamepadAxisMotion(id, axis, value) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadAxisMotion(id, axis, value))
                }
            case UiEvent.GamepadButtonDown(id, button) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadButtonDown(id, button))
                }
            case UiEvent.GamepadButtonUp(id, button) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadButtonUp(id, button))
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String { Some(controlId) }
    public func interactionOwnerIds(): Array<String> { [controlId] }
}

private func sameScene3DSharedRequest(
    actual: Scene3DSharedFrameRequest,
    expected: Scene3DSharedFrameRequest
): Bool {
    actual.surfaceId == expected.surfaceId && actual.generation == expected.generation &&
        actual.frameId == expected.frameId && actual.logicalWidth == expected.logicalWidth &&
        actual.logicalHeight == expected.logicalHeight && actual.scale == expected.scale &&
        actual.placementRevision == expected.placementRevision &&
        actual.rotationCode == expected.rotationCode
}

private func scene3DSharedFrameFinishReasonFromCore(value: String): Scene3DSharedFrameFinishReason {
    if (value == "presented") { return Scene3DSharedFrameFinishReason.Presented }
    if (value == "fallback") { return Scene3DSharedFrameFinishReason.Fallback }
    if (value == "executor-failed") { return Scene3DSharedFrameFinishReason.ExecutorFailed }
    if (value == "replaced") { return Scene3DSharedFrameFinishReason.Replaced }
    if (value == "abandoned") { return Scene3DSharedFrameFinishReason.Abandoned }
    Scene3DSharedFrameFinishReason.Rejected
}

private func scene3DDeviceRotationCode(value: DeviceRotation): String {
    match (value) {
        case DeviceRotation.Unknown => "unknown"
        case DeviceRotation.Portrait => "portrait"
        case DeviceRotation.LandscapeClockwise => "landscape-clockwise"
        case DeviceRotation.PortraitUpsideDown => "portrait-upside-down"
        case DeviceRotation.LandscapeCounterClockwise => "landscape-counter-clockwise"
    }
}

private func toSceneSurface(surface: NativeSurfaceDescriptor): Scene3DHostSurface {
    Scene3DHostSurface(surface.id, sceneBackend(surface.backend), surface.opaqueHandle,
        surface.logicalWidth, surface.logicalHeight, surface.pixelWidth, surface.pixelHeight,
        surface.scale, surface.generation)
}

private func sceneBackend(backend: NativeSurfaceBackend): Scene3DBackend {
    match (backend) {
        case NativeSurfaceBackend.Metal => Scene3DBackend.Metal
        case NativeSurfaceBackend.Vulkan => Scene3DBackend.Vulkan
        case NativeSurfaceBackend.OpenGLES => Scene3DBackend.OpenGLES
        case NativeSurfaceBackend.Software => Scene3DBackend.Software
    }
}
