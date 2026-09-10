package sdl

public struct WindowSpec {
    public let title: String
    public let width: Int32
    public let height: Int32
    public let resizable: Bool
    public let highDpi: Bool
    /** Whether the platform draws its native title bar and window border. */
    public let decorated: Bool
    /** Convenience alias: `frameless: true` is equivalent to `decorated: false`. */
    public let frameless: Bool
    /**
     * Native window-shape corner radius in logical pixels. A positive radius creates a
     * transparent shaped window and is intended for custom/frameless chrome. Decorated
     * platform windows should normally leave this at zero and use the system's own corners.
     */
    public let cornerRadius: Float32
    public let scale: Float32
    // Whether the renderer waits for the vertical blank on present. On (the default) prevents
    // tearing and is the right choice for real applications. Off lets the frame loop run
    // uncapped, which is how a benchmark measures true per-frame work: with vsync on, every
    // frame period snaps to a refresh multiple (16.7/33.3/50 ms at 60 Hz), so any improvement
    // smaller than a whole refresh interval is invisible.
    public let vsync: Bool
    // Supersample factor per axis (1 = off, 2 = default 4x-samples anti-aliasing). Higher is
    // smoother but pays for that many times the pixels every frame; lower trades edge smoothness
    // for fill cost. 2 suits a hardware renderer; a software renderer may want 1.
    public let supersample: Int32

    public init(
        title: String,
        width: Int32,
        height: Int32,
        resizable!: Bool = true,
        highDpi!: Bool = true,
        scale!: Float32 = 1.0,
        vsync!: Bool = true,
        supersample!: Int32 = 2,
        decorated!: Bool = true,
        frameless!: Bool = false,
        cornerRadius!: Float32 = 0.0
    ) {
        this.title = title
        this.width = width
        this.height = height
        this.resizable = resizable
        this.highDpi = highDpi
        this.decorated = decorated
        this.frameless = frameless
        this.cornerRadius = normalizedCornerRadius(cornerRadius)
        this.scale = normalizedScale(scale)
        this.vsync = vsync
        this.supersample = supersample
    }
}

public class SdlWindow <: Resource {
    internal let windowPtr: CPointer<Unit>
    private let rendererPtr: CPointer<Unit>
    // 可重绑：调度器可能迁移运行 run 循环的绿色线程（见 pollEventEnvelope）
    private var ownerThreadId: UInt64
    private let closeGate: WindowCloseGate
    private let runtime: SdlRuntime
    private var shapeReceiptValue = WindowShapeReceipt(WindowShapeApplyStatus.NotRequested,
        0.0, 0.0, 0, 0)

    public var width: Int32
    public var height: Int32
    public let scale: Float32
    public let cornerRadius: Float32
    public let renderer: Renderer
    public let id: WindowId

    /**
     * Throws `CuiException` when SDL cannot create or initialize the window, renderer, or text input.
     */
    public init(spec: WindowSpec) {
        this.width = spec.width
        this.height = spec.height
        this.scale = spec.scale
        this.cornerRadius = spec.cornerRadius
        this.runtime = SdlRuntime()

        let flags = windowCreationFlags(spec)

        var window = CPointer<Unit>()
        var createdRenderer = CPointer<Unit>()
        var nativeWindowId = UInt32(0)
        var initialShapeReceipt = WindowShapeReceipt(WindowShapeApplyStatus.NotRequested,
            spec.cornerRadius, 0.0, 0, 0)
        let titleText = unsafe { LibC.mallocCString(spec.title) }
        try (titleResource = titleText.asResource()) {
            try {
                let pixelWidth = scaledDimension(spec.width, spec.scale)
                let pixelHeight = scaledDimension(spec.height, spec.scale)
                let ok = unsafe {
                    SDL_CreateWindowAndRenderer(titleResource.value, pixelWidth, pixelHeight, flags, inout window,
                        inout createdRenderer)
                }
                if (!ok || window.isNull() || createdRenderer.isNull()) {
                    throw CuiException("SDL_CreateWindowAndRenderer failed: ${lastSdlError()}")
                }
                configureRenderer(createdRenderer, spec.scale, spec.vsync)
                initialShapeReceipt = applyRoundedWindowShape(window, pixelWidth, pixelHeight,
                    spec.cornerRadius * spec.scale)
                if (!unsafe { SDL_StartTextInput(window) }) {
                    throw CuiException("SDL_StartTextInput failed: ${lastSdlError()}")
                }
                nativeWindowId = unsafe { SDL_GetWindowID(window) }
                if (nativeWindowId == UInt32(0)) {
                    throw CuiException("SDL_GetWindowID failed: ${lastSdlError()}")
                }
            } catch (error: Exception) {
                destroyCreatedResources(window, createdRenderer)
                runtime.close()
                throw error
            }
        }

        this.windowPtr = window
        this.rendererPtr = createdRenderer
        let nativeOwner = unsafe { SDL_GetCurrentThreadID() }
        this.ownerThreadId = nativeOwner
        this.closeGate = WindowCloseGate(nativeOwner)
        this.renderer = Renderer(createdRenderer, contentScale: spec.scale, supersample: spec.supersample)
        this.id = WindowId(nativeWindowId)
        this.shapeReceiptValue = initialShapeReceipt
    }

    public func setTitle(title: String): Unit {
        let cTitle = unsafe { LibC.mallocCString(title) }
        try (titleResource = cTitle.asResource()) {
            ensureSdl(unsafe { SDL_SetWindowTitle(windowPtr, titleResource.value) }, "SDL_SetWindowTitle")
        }
    }

    /** Sets the window icon (taskbar/alt-tab). The surface must outlive the window. */
    public func setIcon(icon: Surface): Unit {
        let _ = unsafe { SDL_SetWindowIcon(windowPtr, icon.ptr) }
    }

    public func setSize(width: Int32, height: Int32): Unit {
        let pixelWidth = scaledDimension(width, scale)
        let pixelHeight = scaledDimension(height, scale)
        ensureSdl(unsafe { SDL_SetWindowSize(windowPtr, pixelWidth, pixelHeight) }, "SDL_SetWindowSize")
        this.width = width
        this.height = height
        refreshRoundedShape(pixelWidth, pixelHeight)
    }

    public func refreshSize(): Size {
        var w: Int32 = 0
        var h: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowSize(windowPtr, inout w, inout h) }, "SDL_GetWindowSize")
        width = Int32(Float32(w) / scale)
        height = Int32(Float32(h) / scale)
        refreshRoundedShape(w, h)
        Size(Float32(width), Float32(height))
    }

    /** Applies a CangHui-logical resize and rebuilds pixel-owned native shape resources. */
    public func updateLogicalSize(logicalWidth: Int32, logicalHeight: Int32): Unit {
        applyResizeUpdate(logicalWindowResizeUpdate(logicalWidth, logicalHeight, scale))
    }

    /** Applies an SDL drawable-pixel change without corrupting unchanged logical layout size. */
    public func updatePixelSize(pixelWidth: Int32, pixelHeight: Int32): Unit {
        applyResizeUpdate(backingPixelResizeUpdate(width, height, pixelWidth, pixelHeight))
    }

    /**
     * Compatibility conversion for callers holding content-scaled window coordinates.
     * `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED` must use `updatePixelSize` instead.
     */
    public func updateSizeFromPixels(pixelWidth: Int32, pixelHeight: Int32): Unit {
        let logical = windowSizeFromPixels(pixelWidth, pixelHeight, scale)
        applyResizeUpdate(WindowResizeUpdate(
            Int32(logical.w), Int32(logical.h), pixelWidth, pixelHeight))
    }

    /**
     * Tells the OS where the text caret is, in the window's logical pixels (the same space
     * as events and drawing), so IME composition UI — the candidate window — appears at the
     * caret instead of a screen corner. The conversion to window pixels happens here.
     */
    public func setTextInputArea(rect: Rect): Unit {
        var raw = Rect(rect.x * scale, rect.y * scale, rect.w * scale, rect.h * scale).toSdlRect()
        ensureSdl(unsafe { SDL_SetTextInputArea(windowPtr, inout raw, 0) }, "SDL_SetTextInputArea")
    }

    public func pollEvent(): ?UiEvent {
        match (pollEventEnvelope()) {
            case Some(envelope) => Some(envelope.event)
            case None => None
        }
    }

    /** Compatibility polling path. Multi-window applications should pump one shared `SdlRuntime`. */
    public func pollEventEnvelope(): ?SdlEventEnvelope {
        let currentThreadId = unsafe { SDL_GetCurrentThreadID() }
        if (!sameNativeThread(ownerThreadId, currentThreadId)) {
            // 仓颉调度器的工作窃取可能把运行 run 循环的主绿色线程迁移到另一个原生线程。
            // Windows 上 SDL 允许在非窗口创建线程上轮询事件（PumpEvents 只要求单线程串行），
            // 因此这里重绑 owner 而不是抛异常：轮询始终由 run 循环串行执行，重绑是安全的。
            // （macOS 等要求主线程 UI 的平台不适用此放宽，需保持原校验。）
            ownerThreadId = currentThreadId
        }
        match (runtime.pollEvent()) {
            case Some(envelope) =>
                let scaled = match (envelope.windowId) {
                    case Some(target) => if (target == id) { scaleEventEnvelope(envelope, scale) } else { envelope }
                    case None => envelope
                }
                Some(scaled)
            case None => None
        }
    }

    public func shapeReceipt(): WindowShapeReceipt { shapeReceiptValue }

    public func ticks(): UInt64 {
        unsafe { SDL_GetTicks() }
    }

    public func delay(ms: UInt32): Unit {
        unsafe { SDL_Delay(ms) }
    }

    public func isClosed(): Bool {
        closeGate.isClosed()
    }

    /**
     * Lends the SDL window pointer to a platform adapter for the duration of `body`.
     * The pointer is framework-owned: consumers must not destroy it or retain it after
     * this window closes. Application scene models should never store this value.
     */
    public func withBorrowedPlatformWindow<T>(body: (CPointer<Unit>) -> T): T {
        if (isClosed() || windowPtr.isNull()) {
            throw IllegalStateException("cannot borrow a closed SDL window")
        }
        body(windowPtr)
    }

    /**
     * Closes native window resources exactly once on the native thread that created them.
     *
     * A first close from another native thread fails before entering renderer or SDL
     * teardown. Once an owner-thread close has completed, repeated calls are no-ops from any
     * thread. Applications must keep creation, event pumping and first close on one native thread.
     */
    public func close(): Unit {
        let currentThreadId = unsafe { SDL_GetCurrentThreadID() }
        let result = closeGate.close(currentThreadId, { =>
            renderer.releaseResources()
            unsafe {
                if (windowPtr.isNotNull()) {
                    let _ = SDL_StopTextInput(windowPtr)
                }
                if (rendererPtr.isNotNull()) {
                    SDL_DestroyRenderer(rendererPtr)
                }
                if (windowPtr.isNotNull()) {
                    SDL_DestroyWindow(windowPtr)
                }
            }
            runtime.close()
        })
        match (result) {
            case WindowCloseResult.WrongThread =>
                throw CuiException(
                    "SDL window close moved across native threads; first close must run on the window owner thread"
                )
            case _ => ()
        }
    }

    private func refreshRoundedShape(pixelWidth: Int32, pixelHeight: Int32): Unit {
        // 最大化时满屏直角：清除已应用的圆角遮罩（还原时恢复配置圆角）
        let maximized = windowFlagsFromRaw(unsafe { SDL_GetWindowFlags(windowPtr) }).maximized
        if (maximized) {
            if (shapeReceiptValue.status == WindowShapeApplyStatus.Applied) {
                let _ = unsafe { SDL_SetWindowShape(windowPtr, CPointer<Unit>()) }
                shapeReceiptValue = WindowShapeReceipt(WindowShapeApplyStatus.NotRequested, 0.0, 0.0,
                    pixelWidth, pixelHeight, detail: "shape cleared for maximized window")
            }
            return
        }
        if (cornerRadius > 0.0) {
            shapeReceiptValue = applyRoundedWindowShape(windowPtr, pixelWidth, pixelHeight, cornerRadius * scale)
        }
    }

    private func applyResizeUpdate(update: WindowResizeUpdate): Unit {
        width = update.logicalWidth
        height = update.logicalHeight
        refreshRoundedShape(update.pixelWidth, update.pixelHeight)
    }
}

internal enum WindowCloseResult {
    | Closed
    | AlreadyClosed
    | WrongThread
}

/**
 * Keeps the native teardown body behind an owner-thread and exactly-once gate. The gate is kept
 * separate from SDL so its no-native-entry behavior can be proven without constructing a window.
 */
internal class WindowCloseGate {
    private let ownerThreadId: UInt64
    private var closed = false

    internal init(ownerThreadId: UInt64) {
        this.ownerThreadId = ownerThreadId
    }

    internal func isClosed(): Bool { closed }

    internal func close(currentThreadId: UInt64, nativeClose: () -> Unit): WindowCloseResult {
        if (closed) {
            return WindowCloseResult.AlreadyClosed
        }
        if (!sameNativeThread(ownerThreadId, currentThreadId)) {
            return WindowCloseResult.WrongThread
        }
        closed = true
        nativeClose()
        WindowCloseResult.Closed
    }
}

internal func sameNativeThread(ownerThreadId: UInt64, currentThreadId: UInt64): Bool {
    ownerThreadId == currentThreadId
}

internal func windowCreationFlags(spec: WindowSpec): UInt64 {
    var flags = UInt64(0)
    if (spec.resizable) {
        flags = flags | SDL_WINDOW_RESIZABLE
    }
    if (spec.highDpi) {
        flags = flags | SDL_WINDOW_HIGH_PIXEL_DENSITY
    }
    if (!spec.decorated || spec.frameless) {
        flags = flags | SDL_WINDOW_BORDERLESS
    }
    if (spec.cornerRadius > 0.0) {
        flags = flags | SDL_WINDOW_TRANSPARENT
    }
    flags
}

internal func normalizedCornerRadius(radius: Float32): Float32 {
    if (radius > 0.0) { radius } else { 0.0 }
}
