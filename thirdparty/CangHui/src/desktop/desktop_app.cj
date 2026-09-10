package chui.desktop

import std.collection.ArrayList
import std.convert.*
import std.env.{getCommandLine, getVariable}
import sdl.{DeviceRotation, DeviceRotationEvent, DeviceRotationSource, FrameInfo, Key, MouseButton, Rect,
    SdlWindow, Surface, UiEvent, WindowFlags, WindowPosition, WindowSpec}
import sdl.input.{Cursor, Keyboard, SystemCursor}
import sdl.dialogs.FileDialogOptions
import sdl.dialogs.FileDialogRequest
import sdl.dialogs.FileDialogs
import sdl.system.AppMetadata
import sdl.system.ApplicationMetadata
import sdl.system.SdlHintSetting
import sdl.system.SdlHint
import sdl.system.SdlHints
import chui.core.{AnimationSpec, CursorShape, DeviceRotationTransition, RetainedUiDamage,
    RetainedUiDamageKind, SemanticActionHandler, SemanticActionReceipt, SemanticActionRequest,
    SemanticInteractionPolicy, SemanticRuntime, SemanticRuntimeLimits, SemanticTreeDiff,
    SemanticTreeSnapshot, StateStore, Theme, ThemeTransition, UiContext, Widget, buildRetainedRoot,
    buildRoot, UiOwnerQueue, UiOwnerTaskHandler, UiOwnerTicket, currentStateGeneration, drawTooltip,
    withActiveSemanticRuntime}
import chui.graphics.{DamageRegion, FrameDamageRect, FrameExecutionReceipt, FrameExternalMode, FrameGraph,
    FrameGraphRuntime, FramePassDescriptor, FramePassExecutionResult, FramePassId, FramePassKind,
    GraphicsAlphaMode,
    FrameResourceDescriptor, FrameResourceId, FrameResourceKind, FrameResourceLifetime,
    SdlFrameGraphExecutor, bridgeScene3DExternalSurface, bridgeScene3DSharedFrameImport,
    sdlFramePhysicalPixelCount}
import chui.kmode.kModeEnabled

// Long enough for the first paint to settle and for background work started at launch
// (dialog-free examples fetch data on worker threads) to land in the frame.
private let SNAPSHOT_SETTLE_FRAMES: UInt64 = 48

/*
 * The desktop shell: owns the SDL window and runs the frame loop that rebuilds the widget tree from
 * `run`'s body, lays it out, dispatches input, and draws. Idle frames are skipped — a frame is only
 * rendered on input, a `State` write, a resize, or a widget's `ctx.requestFrame()`, so time-driven
 * animation must request frames or it freezes. The loop brackets pointer dispatch with the context's
 * focus/hover/click-count protocols, routes events to open overlays before the tree, and paints the
 * tooltip and overlay passes above the tree. Resources registered with `manage` are closed in reverse
 * order, then the window — even when a widget throws out of the loop.
 */
public class DesktopApp {
    private let window: SdlWindow
    private let ctx: UiContext
    private let resolvedPacing: ResolvedFramePacing
    private let resources = ArrayList<Resource>()
    private let queuedEvents = ArrayList<UiEvent>()
    private let stateStore = StateStore()
    private let semanticActionRouter: DesktopSemanticActionRouter
    private let semanticRuntime: SemanticRuntime
    private let uiOwnerQueue = UiOwnerQueue()
    private let captureRequest: ?DesktopCaptureRequest
    // Per-phase frame timing, enabled with `--profile`; None (and zero cost) in a normal run.
    private let profiler: ?FrameProfiler
    // Rev1 stays opt-in while the retained compiler and transactional SDL provider collect live
    // evidence. A debug frame-trace request enables this path automatically; ordinary release
    // applications keep the established immediate renderer unless they explicitly opt in.
    private let frameGraphRuntime = FrameGraphRuntime()
    private let frameGraphExecutor: SdlFrameGraphExecutor
    private let frameTrace = FrameTraceRecorder()
    private let frameGraphEnabled: Bool
    private var frames: UInt64 = 0
    private var frameGraphSurfaceGeneration: Int64 = 0
    private var frameGraphSurfaceWidth: Int32 = -1
    private var frameGraphSurfaceHeight: Int32 = -1
    private var baseCursor: ?Cursor = None
    private var pointerCursor: ?Cursor = None
    private var textCursor: ?Cursor = None
    private var resizeHCursor: ?Cursor = None
    private var resizeVCursor: ?Cursor = None
    private var appliedShape: ?CursorShape = None
    // The caret rectangle last forwarded to the OS for IME anchoring (logical pixels).
    private var appliedInputAnchor: ?Rect = None
    private var themeTransition: ?ThemeTransition = None
    private var deviceRotationTransition: ?DeviceRotationTransition = None
    private let deviceRotationAnimation: AnimationSpec
    private let debugUiScript = DebugUiScriptRunner()

    public init(
        spec: WindowSpec,
        theme!: Theme = Theme.light(),
        frameDelay!: UInt32 = UInt32(16),
        framePacing!: ?FramePacing = None,
        capture!: ?DesktopCaptureRequest = None,
        fontScale!: Float32 = 1.0,
        deviceRotationAnimation!: AnimationSpec = AnimationSpec.automatic(duration: UInt64(320)),
        metadata!: ?AppMetadata = None,
        hints!: Array<SdlHintSetting> = [],
        semanticWindowId!: String = "main",
        semanticPolicy!: SemanticInteractionPolicy = SemanticInteractionPolicy(),
        semanticLimits!: SemanticRuntimeLimits = SemanticRuntimeLimits(),
        onSemanticAction!: SemanticActionHandler = {_ => false}
    ) {
        this.window = configuredWindow(spec, metadata, hints)
        this.ctx = UiContext(window.renderer, theme)
        let actionRouter = DesktopSemanticActionRouter(this.ctx, fallback: onSemanticAction)
        this.semanticActionRouter = actionRouter
        this.semanticRuntime = SemanticRuntime(
            semanticWindowId,
            policy: semanticPolicy,
            limits: semanticLimits,
            handler: {request => actionRouter.dispatch(request)})
        this.frameGraphExecutor = SdlFrameGraphExecutor(
            window.renderer,
            clearColor: theme.bg,
            physicalPixelScale: window.scale * Float32(window.renderer.supersampleFactor()))
        this.frameGraphEnabled = desktopFrameGraphRequested() || frameTrace.active()
        this.resources.add(frameGraphExecutor)
        this.ctx.displayScale = window.scale
        this.ctx.fontScale = max(0.1, fontScale)
        this.deviceRotationAnimation = deviceRotationAnimation
        this.resolvedPacing = resolveFramePacing(framePacing, spec.vsync, frameDelay, kModeEnabled())
        let wantsVsync = framePacingUsesVSync(this.resolvedPacing)
        if (wantsVsync != spec.vsync) {
            window.renderer.setVSync(if (wantsVsync) { Int32(1) } else { Int32(0) })
        }
        this.captureRequest = resolveDesktopCaptureRequest(
            capture,
            DesktopCaptureRequest.fromEnvironment(),
            legacySnapshotRequest()
        )
        this.profiler = if (profileEnabled()) {
            Some(FrameProfiler(60))
        } else {
            None
        }
    }

    public func manage(resource: Resource): Unit {
        resources.add(resource)
    }

    /** Latest committed in-process semantic tree for accessibility and trusted host features. */
    public func semanticSnapshot(): SemanticTreeSnapshot { semanticRuntime.snapshot() }

    public func semanticDiff(previous: SemanticTreeSnapshot): SemanticTreeDiff {
        semanticRuntime.diff(previous)
    }

    /** Dispatches only a typed, revision-bound application action; no coordinates or keys exist. */
    public func dispatchSemanticAction(request: SemanticActionRequest): SemanticActionReceipt {
        semanticRuntime.dispatch(request)
    }

    /**
     * Scoped platform-provider SPI. The borrowed SDL window pointer may be used to
     * create a child native surface but remains owned by DesktopApp.
     */
    public func withBorrowedPlatformWindow<T>(body: (CPointer<Unit>) -> T): T {
        window.withBorrowedPlatformWindow(body)
    }

    /**
     * Prevents the user from shrinking the window below `width` x `height` logical
     * pixels. Layouts do not reflow below their design minimum, so resizable windows
     * should set one to keep content from being squeezed off screen.
     */
    public func setMinimumSize(width: Int32, height: Int32): Unit {
        window.setMinimumSize(width, height)
    }

    /** Sets the window icon (taskbar/alt-tab). The surface must outlive the window. */
    public func setWindowIcon(icon: Surface): Unit {
        window.setIcon(icon)
    }

    /** Requests application shutdown through the normal frame-loop path. */
    public func requestWindowClose(): Unit {
        ctx.requestClose()
    }

    /** Minimizes the owned desktop window. */
    public func minimizeWindow(): Unit {
        window.minimize()
    }

    /** Maximizes a restored window or restores a maximized one. */
    public func toggleMaximizeWindow(): Unit {
        if (window.windowFlags().maximized) {
            window.restore()
        } else {
            window.maximize()
        }
    }

    /** Moves the owned window in desktop coordinates. */
    public func setWindowPosition(x: Int32, y: Int32): Unit {
        window.setPosition(x, y)
    }

    /** Returns the owned window's desktop position. */
    public func windowPosition(): WindowPosition {
        window.position()
    }

    /** Returns a snapshot of the current native window flags. */
    public func windowFlags(): WindowFlags {
        window.windowFlags()
    }

    /**
     * Sets the window's resting cursor — the shape shown wherever no control asks for a
     * different one. Applications wanting a themed base pointer (for example a crosshair
     * over a drawing canvas) call this instead of activating a cursor directly, so the
     * hover-driven shapes (a hand over buttons, an I-beam over text) still layer on top.
     */
    public func useBaseCursor(kind: SystemCursor): Unit {
        match (baseCursor) {
            case Some(existing) => existing.close()
            case None => ()
        }
        baseCursor = createCursor(kind)
        appliedShape = None
        applyDesiredCursor()
    }

    /** Drops all local values created by `rememberState` before the next rebuild. */
    public func clearRememberedState(): Unit {
        stateStore.clear()
    }

    /**
     * Posts work prepared on any thread for deterministic execution by this application's UI owner.
     * The task runs before the next declarative tree build and therefore may safely update UI `State`.
     */
    public func postToUi(
        action: UiOwnerTaskHandler,
        baseEpoch!: ?UInt64 = None,
        topologyHash!: String = ""
    ): UiOwnerTicket {
        uiOwnerQueue.post(action, baseEpoch: baseEpoch, topologyHash: topologyHash)
    }

    /** Current owner epoch for optimistic `postToUi(baseEpoch:)` preparation. */
    public func uiOwnerEpoch(): UInt64 {
        uiOwnerQueue.currentEpoch()
    }

    /** Effective layout posture, using viewport aspect ratio until a provider reports. */
    public func deviceRotation(): DeviceRotation {
        ctx.deviceRotation()
    }

    /** Last posture reported by a provider, or `Unknown` before the first report. */
    public func reportedDeviceRotation(): DeviceRotation {
        ctx.reportedDeviceRotation()
    }

    /**
     * Queues one normalized device posture through ordinary UI event routing. Call this
     * on the UI owner; worker/native callbacks should use `postDeviceRotation`.
     */
    public func queueDeviceRotation(event: DeviceRotationEvent): Unit {
        queuedEvents.add(UiEvent.DeviceRotationChanged(event))
    }

    /** Convenience overload for owner-thread providers and deterministic previews. */
    public func queueDeviceRotation(
        rotation: DeviceRotation,
        source!: DeviceRotationSource = DeviceRotationSource.Host,
        timestampMs!: UInt64 = UInt64(0)
    ): Unit {
        queueDeviceRotation(DeviceRotationEvent(rotation, source: source, timestampMs: timestampMs))
    }

    /** Thread-safe provider ingress; the event is enqueued by the UI owner before a later build. */
    public func postDeviceRotation(event: DeviceRotationEvent): UiOwnerTicket {
        postToUi({ => queueDeviceRotation(event) })
    }

    /** Queues a pointer click through the normal CangHui hit-test and event route. */
    public func queuePointerClick(x: Float32, y: Float32): Unit {
        queuedEvents.add(UiEvent.MouseDown(MouseButton.Left, x, y))
        queuedEvents.add(UiEvent.MouseUp(MouseButton.Left, x, y))
    }

    /** Queues a synthetic pointer down through the normal CangHui hit-test and event route. */
    public func queuePointerDown(x: Float32, y: Float32): Unit {
        queuedEvents.add(UiEvent.MouseDown(MouseButton.Left, x, y))
    }

    /** Queues a synthetic pointer move through the normal CangHui hit-test and event route. */
    public func queuePointerMove(x: Float32, y: Float32): Unit {
        queuedEvents.add(UiEvent.MouseMove(x, y))
    }

    /** Queues a synthetic pointer up through the normal CangHui hit-test and event route. */
    public func queuePointerUp(x: Float32, y: Float32): Unit {
        queuedEvents.add(UiEvent.MouseUp(MouseButton.Left, x, y))
    }

    /**
     * Queues a synthetic drag sequence down -> move* -> up with linear interpolation.
     * `steps` is the number of move events between down and up; it is clamped to at least 1.
     */
    public func queuePointerDrag(
        fromX: Float32,
        fromY: Float32,
        toX: Float32,
        toY: Float32,
        steps!: Int64 = Int64(8)
    ): Unit {
        for (event in buildPointerDragEvents(fromX, fromY, toX, toY, steps)) {
            queuedEvents.add(event)
        }
    }

    /** Applies a theme immediately and cancels any active animated transition. */
    public func setTheme(theme: Theme): Unit {
        closeThemeTransition()
        themeTransition = None
        ctx.theme = theme
        ctx.requestFrame()
    }

    /** Starts an InkWell-like theme reveal from the current pointer position. */
    public func transitionTheme(theme: Theme, durationMs!: UInt64 = UInt64(560)): Unit {
        let x = if (ctx.mouseX > 0.0) { ctx.mouseX } else { Float32(window.width) - 42.0 }
        let y = if (ctx.mouseY > 0.0) { ctx.mouseY } else { Float32(42.0) }
        transitionThemeAt(theme, x, y, durationMs: durationMs)
    }

    /** Starts a theme reveal from an explicit logical-pixel origin.
     *  reverse = true: old theme shrinks toward origin (inward), revealing new theme from outside. */
    public func transitionThemeAt(
        theme: Theme,
        originX: Float32,
        originY: Float32,
        durationMs!: UInt64 = UInt64(560),
        reverse!: Bool = false
    ): Unit {
        let source = match (themeTransition) {
            case Some(active) =>
                let current = active.currentTheme()
                active.close()
                current
            case None => ctx.theme
        }
        ctx.theme = source
        themeTransition = Some(ThemeTransition(source, theme, originX, originY, durationMs: durationMs, reverse: reverse))
        ctx.requestFrame()
    }

    public func openFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.openFile(options: options, window: Some(window))
    }

    public func saveFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.saveFile(options: options, window: Some(window))
    }

    public func openFolderDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.openFolder(options: options, window: Some(window))
    }

    public func run(body: () -> Unit): Unit {
        // Capture the frame-loop failure before shutdown. Cleanup is still deterministic, but a
        // cleanup/affinity failure must never replace the originating application exception.
        var runFailure: ?Exception = None
        try {
            match (profiler) {
                case Some(_) =>
                    println("[profile] 渲染后端 ${ctx.renderer.driverName()}｜超采样 ${ctx.renderer.supersampleFactor()}x｜视口 ${window.width}x${window.height} @ ${window.scale}x｜帧节奏 ${resolvedFramePacingName(resolvedPacing)}")
                case None => ()
            }
            var previousTick = window.ticks()
            // Dirty-frame skipping (档 0): a frame is built, laid out, and drawn only when something can
            // have changed — the first frame, pending input or owner work, a state write since the last
            // render, a resize, or a continuous-frame request (a blinking caret, a tooltip counting
            // down, a per-frame FrameHandler). Otherwise the loop keeps polling input at the frame cadence but
            // leaves the last presented frame on screen, so an idle window costs nothing to build, lay
            // out, or draw. State is snapshotted at the TOP of each rendered frame, so a write made
            // during that frame's layout/dispatch/draw reliably triggers the reflecting render next.
            var lastRenderedGen = currentStateGeneration()
            var continuousRequested = true // force the first frame
            var renderedWidth: Int32 = -1
            var renderedHeight: Int32 = -1
            while (!ctx.shouldClose) {
                let loopStart = window.ticks()
                var rendered = false
                let frame = nextFrame(previousTick)
                previousTick = frame.elapsedMs
                ctx.frame = frame
                advanceThemeTransition(frame.deltaMs)
                advanceDeviceRotationTransition(frame.deltaMs)
                let viewportW = window.width
                let viewportH = window.height
                ctx.viewportWidth = Float32(viewportW)
                ctx.viewportHeight = Float32(viewportH)

                let events = collectPendingEvents()
                let observedStateGen = currentStateGeneration()
                let ownerWorkPending = uiOwnerQueue.hasPending()
                let nonStateInvalidation = continuousRequested || ownerWorkPending || !events.isEmpty() ||
                    debugUiScript.active() ||
                    viewportW != renderedWidth || viewportH != renderedHeight || captureRequest.isSome() ||
                    profiler.isSome() || themeTransition.isSome() || deviceRotationTransition.isSome()
                let renderRequested = nonStateInvalidation || observedStateGen != lastRenderedGen
                // A trace child may request one or more proof frames after the UI becomes idle. Those
                // frames carry empty damage, letting the compiler prove stable-pass culling instead
                // of turning observation itself into an application invalidation.
                let mustRender = renderRequested || frameTrace.active()

                if (mustRender) {
                    rendered = true
                    // Drain a bounded snapshot before build. Reentrant posts remain pending for the
                    // next frame, and State writes made here are included in this frame's generation.
                    let _ = uiOwnerQueue.drain()
                    let frameStateGen = currentStateGeneration()
                    let tBuild = FrameProfiler.now()
                    let widget = if (frameGraphEnabled) {
                        buildRetainedRoot(
                            body,
                            stateStore,
                            desktopRetainedContextCode(
                                viewportW, viewportH, ctx.displayScale, ctx.fontScale,
                                ctx.deviceRotation()))
                    } else {
                        buildRoot(body, stateStore)
                    }
                    let tLayout = FrameProfiler.now()
                    ctx.adoptFocusRing(stateStore.focusRing())
                    semanticActionRouter.bind(widget)
                    ctx.beginFrameSurfaceRegistration()
                    widget.layout(ctx, Rect(0.0, 0.0, Float32(viewportW), Float32(viewportH)))
                    let tEvents = FrameProfiler.now()
                    dispatchCollectedEvents(widget, events)
                    debugUiScript.observe(widget, ctx, viewportW, viewportH)
                    debugUiScript.executeNext(ctx, { event => dispatchSyntheticEvent(widget, event) })
                    dispatchEvent(widget, UiEvent.Frame(frame))
                    let tDraw = FrameProfiler.now()
                    frames += 1
                    let stateChangedDuringFrame = currentStateGeneration() != frameStateGen
                    let traceInvalidated = nonStateInvalidation ||
                        frameStateGen != lastRenderedGen || stateChangedDuringFrame
                    let (beginNs, treeNs, resolveNs, presentNs) = if (frameGraphEnabled) {
                        drawFrameGraph(
                            widget,
                            nonStateInvalidation || stateChangedDuringFrame,
                            traceInvalidated,
                            stateStore.retainedDamage())
                    } else {
                        draw(widget)
                    }
                    if (frameGraphEnabled) {
                        if (desktopFrameSurfaceUsable(viewportW, viewportH)) {
                            let _ = stateStore.finishRetainedFrame()
                        } else {
                            stateStore.cancelRetainedFrame()
                        }
                    }
                    lastRenderedGen = frameStateGen
                    continuousRequested = ctx.takeFrameRequest() || themeTransition.isSome() ||
                        deviceRotationTransition.isSome()
                    renderedWidth = viewportW
                    renderedHeight = viewportH
                    match (profiler) {
                        case Some(p) => p.record(tLayout - tBuild, tEvents - tLayout, tDraw - tEvents, beginNs, treeNs,
                            resolveNs, presentNs)
                        case None => ()
                    }
                } else {
                    continuousRequested = ctx.takeFrameRequest()
                }
                let delay = framePacingDelay(resolvedPacing, tickDelta(loopStart, window.ticks()), rendered)
                if (delay > UInt32(0)) {
                    window.delay(delay)
                }
            }
        } catch (error: Exception) {
            stateStore.cancelRetainedFrame()
            let _ = ctx.finishSharedFrameSurfaces("executor-failed")
            runFailure = Some(error)
        }
        try {
            let _ = uiOwnerQueue.close(reason: "desktop application closed")
            semanticActionRouter.clear()
            closeThemeTransition()
            closeDeviceRotationTransition()
            stateStore.clear()
            closeManagedResources()
            window.close()
        } catch (cleanupError: Exception) {
            runFailure = Some(preferredDesktopRunFailure(runFailure, cleanupError))
        }
        // Trace I/O is deliberately isolated from native cleanup: an invalid/symlinked proof path
        // must never strand the SDL renderer, executor or window.
        try {
            match (runFailure) {
                case Some(_) => frameTrace.fail("application-exception")
                case None => frameTrace.finish()
            }
        } catch (traceError: Exception) {
            runFailure = Some(preferredDesktopRunFailure(runFailure, traceError))
        }
        match (runFailure) {
            case Some(error) => throw error
            case None => ()
        }
    }

    // Polls every event SDL has queued into a buffer, so the render decision can tell whether any input
    // arrived before deciding whether to build a frame at all. Dispatch is deferred (see below).
    private func collectPendingEvents(): ArrayList<UiEvent> {
        let events = ArrayList<UiEvent>()
        while (!queuedEvents.isEmpty()) {
            events.add(queuedEvents.remove(at: 0))
        }
        var current = window.pollEvent()
        while (let Some(event) <- current) {
            events.add(event)
            current = window.pollEvent()
        }
        events
    }

    // Dispatches the collected events in arrival order against the freshly built tree, bracketing each
    // with the same pointer bookkeeping the loop used to do inline — the per-event sequence
    // (prepare, route, complete) is unchanged, only deferred past the render decision.
    private func dispatchCollectedEvents(widget: Widget, events: ArrayList<UiEvent>): Unit {
        for (event in events) {
            preparePointer(event)
            routeEvent(widget, event)
            completePointer(event)
        }
    }

    private func dispatchSyntheticEvent(widget: Widget, event: UiEvent): Unit {
        preparePointer(event)
        routeEvent(widget, event)
        completePointer(event)
    }

    /*
     * Routes one input event. Window-level events belong to the shell and are handled
     * before the overlays, so a modal dialog can neither swallow a quit request nor keep
     * the logical size stale through a resize. The open overlays (dropdowns, menus,
     * dialogs) then see the event before the tree, top-most first — a click inside a
     * popup is not stolen by the dialog or control drawn underneath it, and a dialog
     * consumes whatever its popups decline, protecting the backdrop tree. Pointer
     * bookkeeping brackets BOTH paths: click counting and hover resolution run for
     * overlay-hosted controls (a Modal's fields) exactly as for tree controls, keeping
     * double-clicks and cursor shapes alive there.
     */
    private func routeEvent(widget: Widget, event: UiEvent): Unit {
        match (event) {
            case UiEvent.Quit => ctx.requestClose()
            case UiEvent.WindowResized(w, h) =>
                window.updateLogicalSize(w, h)
            case UiEvent.WindowPixelSizeChanged(w, h) =>
                window.updatePixelSize(w, h)
            case UiEvent.DeviceRotationChanged(rotation) =>
                let previous = ctx.deviceRotation()
                ctx.updateDeviceRotation(rotation)
                beginDeviceRotationTransition(previous, ctx.deviceRotation())
                dispatchEvent(widget, event)
            case UiEvent.MouseMove(_, _) =>
                // Resolve which control the pointer is over, then reflect its requested
                // shape in the system cursor. Bracketing keeps hover single-winner.
                ctx.beginHoverTest()
                if (!ctx.dispatchOverlay(event)) {
                    dispatchEvent(widget, event)
                }
                ctx.settleHover()
                applyDesiredCursor()
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                // Click counting runs before any dispatch so controls can read it while
                // handling the press, wherever the press lands.
                ctx.recordPress(x, y)
                if (ctx.dispatchOverlay(event)) {
                    return // popups and dialogs manage focus themselves
                }
                // A primary press in the tree either moves focus to the claiming control
                // or blurs the current one, matching desktop conventions.
                ctx.beginPointerPress()
                dispatchEvent(widget, event)
                ctx.settleFocusAfterPress()
            case UiEvent.KeyDown(Key.Tab, _) =>
                if (ctx.dispatchOverlay(event)) {
                    return
                }
                // Tab traversal is a shell responsibility: it walks the build-order
                // focus ring and is not forwarded to the focused control, so a text
                // field cannot swallow it. Shift reverses direction.
                if (Keyboard.modifiers().shift) {
                    ctx.focusPrevious()
                } else {
                    ctx.focusNext()
                }
            case _ =>
                if (!ctx.dispatchOverlay(event)) {
                    dispatchEvent(widget, event)
                }
        }
    }

    /**
     * Runs the opt-in rev1 graph without moving closures or native objects into graph metadata.
     * A rejected compile/execution is followed by the established immediate draw in the same frame;
     * compiler state remains unchanged and the SDL provider records fallback only after that draw
     * has really reached `present`.
     */
    private func drawFrameGraph(
        widget: Widget,
        fullDamageRequested: Bool,
        traceInvalidated: Bool,
        retainedDamage: RetainedUiDamage
    ): (UInt64, UInt64, UInt64, UInt64) {
        let started = FrameProfiler.now()
        let width = window.width
        let height = window.height
        // A minimized/native-transition surface may transiently report no drawable area. FrameGraph
        // contracts intentionally reject such dimensions; skipping that frame keeps the desktop
        // loop alive until the next resize instead of turning an ordinary minimize into an exit.
        if (!desktopFrameSurfaceUsable(width, height)) {
            let _ = ctx.finishSharedFrameSurfaces("fallback")
            return (UInt64(0), UInt64(0), UInt64(0), UInt64(0))
        }
        updateFrameGraphSurface(width, height)
        let surfaceWidth = Int64(width)
        let surfaceHeight = Int64(height)
        let target = FrameResourceDescriptor(
            FrameResourceId("desktop.frame", frameGraphSurfaceGeneration),
            FrameResourceKind.Surface,
            FrameResourceLifetime.Persistent,
            declaredBytes: desktopFrameDeclaredBytes(sdlFramePhysicalPixelCount(
                surfaceWidth,
                surfaceHeight,
                window.scale * Float32(ctx.renderer.supersampleFactor()))))
        let resources = ArrayList<FrameResourceDescriptor>()
        resources.add(target)
        let passes = ArrayList<FramePassDescriptor>()
        let sharedDependencies = ArrayList<FramePassId>()
        let presentExternalDependencies = ArrayList<FramePassId>()
        let sharedInputs = ArrayList<FrameResourceId>()
        let damage = if (frameTrace.active()) {
            let damageMode = frameTrace.damageMode(traceInvalidated)
            if (damageMode == 0) {
                DamageRegion.full()
            } else if (damageMode == 1) {
                // Debug trace keeps its deterministic synthetic probe independent from live State.
                DamageRegion.bounded([FrameDamageRect(
                    0,
                    0,
                    min(Int64(64), surfaceWidth),
                    min(Int64(64), surfaceHeight))])
            } else {
                DamageRegion.empty()
            }
        } else if (fullDamageRequested) {
            DamageRegion.full()
        } else {
            desktopRetainedFrameDamage(retainedDamage, surfaceWidth, surfaceHeight)
        }
        let fullBounds = FrameDamageRect(0, 0, surfaceWidth, surfaceHeight)

        frameGraphExecutor.setClearColor(ctx.theme.bg)
        frameGraphExecutor.clearPassBindings()
        frameGraphExecutor.setBeforePresent({ => maybeCapture() })

        for (i in 0..ctx.sharedFrameSurfaceCount()) {
            let surface = ctx.sharedFrameSurfaceAt(i)
            if (surface.isFinished()) { continue }
            let sharedBounds = match (desktopFrameSurfaceBounds(
                surface.bounds, surfaceWidth, surfaceHeight)) {
                case Some(value) => value
                case None =>
                    let _ = surface.finish("fallback")
                    continue
            }
            let bridged = bridgeScene3DSharedFrameImport(
                surface.identity,
                surface.generation,
                surface.frameId,
                passes.size,
                surface.rowBytes * surface.pixelHeight,
                surface.contentCode,
                surface.syncEpoch,
                sharedBounds,
                damage: damage,
                alphaMode: if (surface.alphaMode == "opaque") {
                    GraphicsAlphaMode.Opaque
                } else {
                    GraphicsAlphaMode.Premultiplied
                })
            if (!bridged.ok) {
                let _ = surface.finish("rejected")
                continue
            }
            let resource = match (bridged.resource()) {
                case Some(value) => value
                case None =>
                    let _ = surface.finish("rejected")
                    continue
            }
            let pass = match (bridged.pass()) {
                case Some(value) => value
                case None =>
                    let _ = surface.finish("rejected")
                    continue
            }
            resources.add(resource)
            passes.add(pass)
            sharedInputs.add(resource.id)
            sharedDependencies.add(pass.id)
            frameGraphExecutor.bindPass(pass.id, {context =>
                if (!context.unifiedPixels) {
                    FramePassExecutionResult(false, "shared-frame-unification-missing")
                } else {
                    FramePassExecutionResult(true, "accepted-shared-frame-acquire")
                }
            })
        }

        let uiPass = FramePassDescriptor(
            FramePassId("desktop.ui"),
            passes.size,
            FramePassKind.Ui2D,
            reads: sharedInputs.toArray(),
            writes: [target.id],
            dependsOn: sharedDependencies.toArray(),
            bounds: Some(fullBounds),
            stableInputCode: desktopFrameStableCode(currentStateGeneration(), width, height),
            canCull: true)
        passes.add(uiPass)

        frameGraphExecutor.bindPass(uiPass.id, {_ =>
            ctx.beginSharedFrameCompositionAttempt()
            drawFrameContents(widget, Float32(width), Float32(height))
            if (ctx.sharedFrameCompositionSucceeded()) {
                FramePassExecutionResult(true, "accepted")
            } else {
                FramePassExecutionResult(false, "shared-frame-composition-failed")
            }
        })

        for (i in 0..ctx.nativeChildFrameSurfaceCount()) {
            let surface = ctx.nativeChildFrameSurfaceAt(i)
            let bridged = bridgeScene3DExternalSurface(
                surface.identity,
                surface.generation,
                passes.size,
                FrameExternalMode.NativeChildSurfaceBarrier,
                bounds: desktopFrameSurfaceBounds(surface.bounds, surfaceWidth, surfaceHeight),
                damage: damage)
            if (!bridged.ok) {
                throw IllegalStateException("Scene3D frame barrier rejected: ${bridged.code}")
            }
            let resource = match (bridged.resource()) {
                case Some(value) => value
                case None => throw IllegalStateException("Scene3D frame barrier resource is missing")
            }
            let pass = match (bridged.pass()) {
                case Some(value) => value
                case None => throw IllegalStateException("Scene3D frame barrier pass is missing")
            }
            resources.add(resource)
            passes.add(pass)
            presentExternalDependencies.add(pass.id)
            frameGraphExecutor.bindPass(pass.id, {context =>
                if (context.unifiedPixels) {
                    FramePassExecutionResult(false, "native-child-unification-misreported")
                } else {
                    FramePassExecutionResult(true, "accepted-native-child-barrier")
                }
            })
        }

        passes.add(FramePassDescriptor(
            FramePassId("desktop.present"),
            passes.size,
            FramePassKind.Present,
            reads: [target.id],
            dependsOn: presentExternalDependencies.toArray(),
            bounds: Some(fullBounds),
            stableInputCode: desktopFrameStableCode(currentStateGeneration(), width, height)))
        let graph = FrameGraph(
            "desktop.surface",
            frameGraphSurfaceGeneration,
            Int64(frames),
            surfaceWidth,
            surfaceHeight,
            resources.toArray(),
            passes.toArray(),
            frameDamage: damage)

        ctx.syncThemeResources()
        let receipt = frameGraphRuntime.execute(graph, frameGraphExecutor)
        let finished = FrameProfiler.now()
        if (!receipt.ok) {
            let providerBeforeFallback = frameGraphExecutor.lastReceipt()
            let providerCode = if (providerBeforeFallback.frameId == Int64(frames)) {
                providerBeforeFallback.code
            } else {
                "not-started"
            }
            let legacyTimings = draw(widget, finishSharedFrame: false)
            let sharedFinishOutcome = if (ctx.sharedFrameCompositionSucceeded() ||
                ctx.nativeChildFrameSurfaceCount() > 0) {
                "fallback"
            } else {
                "executor-failed"
            }
            let sharedReleased = ctx.finishSharedFrameSurfaces(sharedFinishOutcome)
            let fallbackUsed = frameGraphExecutor.markLegacyFallbackUsed(
                frameId: Int64(frames),
                nativeChildBarrierCount: ctx.nativeChildFrameSurfaceCount())
            let fallbackFinished = FrameProfiler.now()
            if (frameTrace.captureLegacyFallback(
                receipt,
                fallbackFinished - started,
                fallbackUsed,
                providerCode,
                frameGraphExecutor.lastReceipt().code)) {
                ctx.requestClose()
            }
            if (!sharedReleased) {
                throw IllegalStateException("Scene3D shared frame release failed after graph fallback")
            }
            return legacyTimings
        }
        if (!ctx.finishSharedFrameSurfaces("presented")) {
            throw IllegalStateException("Scene3D shared frame release failed after present")
        }
        applyTextInputAnchor()
        finishFrameTrace(receipt, finished - started)
        // The executor owns scene begin, retained-target resolve and present internally. Rev1 keeps
        // their aggregate in the draw bucket instead of manufacturing unsupported sub-phase data.
        (UInt64(0), finished - started, UInt64(0), UInt64(0))
    }

    private func finishFrameTrace(receipt: FrameExecutionReceipt, durationNs: UInt64): Unit {
        if (frameTrace.capture(receipt, durationNs, frameGraphExecutor.lastReceipt().code)) {
            ctx.requestClose()
        }
    }

    private func updateFrameGraphSurface(width: Int32, height: Int32): Unit {
        if (width != frameGraphSurfaceWidth || height != frameGraphSurfaceHeight) {
            frameGraphSurfaceGeneration += 1
            frameGraphSurfaceWidth = width
            frameGraphSurfaceHeight = height
        }
    }

    private func drawFrameContents(widget: Widget, width: Float32, height: Float32): Unit {
        if (themeTransition.isSome()) {
            let _ = drawThemeTransition(widget, width, height)
            return
        }
        if (deviceRotationTransition.isSome()) {
            let _ = drawDeviceRotationTransition(widget, width, height)
            return
        }
        collectSemanticFrame({ =>
            clearDrawRegistrations()
            widget.draw(ctx)
            ctx.drawInkRipples()
            if (!ctx.hasOverlay()) {
                drawTooltip(ctx, width, height)
            }
            ctx.drawActiveOverlay()
        })
    }

    private func collectSemanticFrame(body: () -> Unit): Unit {
        semanticRuntime.beginFrame()
        try {
            withActiveSemanticRuntime(semanticRuntime, body)
            let _ = semanticRuntime.commitFrame()
        } catch (error: Exception) {
            semanticRuntime.cancelFrame()
            throw error
        }
    }

    // Draws one frame, returning the nanosecond durations of its sub-phases (scene begin, tree draw,
    // supersample resolve, present) for the profiler. The timestamps are a handful of clock reads —
    // negligible against a frame — so they run unconditionally and only the profiler, when enabled,
    // records them.
    private func draw(
        widget: Widget,
        finishSharedFrame!: Bool = true
    ): (UInt64, UInt64, UInt64, UInt64) {
        let t0 = FrameProfiler.now()
        ctx.syncThemeResources()
        ctx.renderer.beginScene(Float32(window.width), Float32(window.height), ctx.theme.bg)
        let t1 = FrameProfiler.now()
        let width = Float32(window.width)
        let height = Float32(window.height)
        let transitionFrame = themeTransition.isSome() || deviceRotationTransition.isSome()
        ctx.beginSharedFrameCompositionAttempt()
        drawFrameContents(widget, width, height)
        // A cached transition snapshot can legitimately present without sampling the provider frame
        // registered by this rebuild. Release that lease as fallback instead of manufacturing a
        // successful composition receipt. The first snapshot frame may still sample and present it.
        if (transitionFrame && !ctx.sharedFrameCompositionSucceeded()) {
            let _ = ctx.finishSharedFrameSurfaces("fallback")
        }
        applyTextInputAnchor()
        let t2 = FrameProfiler.now()
        ctx.renderer.endScene()
        let t3 = FrameProfiler.now()
        maybeCapture()
        ctx.renderer.present()
        let t4 = FrameProfiler.now()
        if (finishSharedFrame) {
            let outcome = if (ctx.sharedFrameCompositionSucceeded()) {
                "presented"
            } else {
                "executor-failed"
            }
            if (!ctx.finishSharedFrameSurfaces(outcome)) {
                throw IllegalStateException("Scene3D shared frame release failed after immediate present")
            }
        }
        (t1 - t0, t2 - t1, t3 - t2, t4 - t3)
    }

    private func advanceThemeTransition(deltaMs: UInt64): Unit {
        match (themeTransition) {
            case Some(transition) where transition.snapshotsReady() => let _ = transition.advance(deltaMs)
            case Some(_) => ()
            case None => ()
        }
    }

    private func beginDeviceRotationTransition(from: DeviceRotation, to: DeviceRotation): Unit {
        // Theme snapshotting already owns the full frame. A posture change still updates layout,
        // but overlapping two whole-frame transitions would capture another transition instead of UI.
        if (themeTransition.isSome()) { return }
        closeDeviceRotationTransition()
        let transition = DeviceRotationTransition(from, to, deviceRotationAnimation, ctx.theme)
        if (transition.deltaDegrees() != 0.0) {
            deviceRotationTransition = Some(transition)
        }
    }

    private func advanceDeviceRotationTransition(deltaMs: UInt64): Unit {
        match (deviceRotationTransition) {
            case Some(transition) where transition.snapshotsReady() => transition.advance(deltaMs)
            case Some(_) => ()
            case None => ()
        }
    }

    private func drawThemeTransition(widget: Widget, width: Float32, height: Float32): Bool {
        match (themeTransition) {
            case Some(transition) =>
                let ready = transition.prepareNextSnapshot(
                    ctx.renderer,
                    width,
                    height,
                    { =>
                        ctx.theme = transition.sourceTheme()
                        ctx.syncThemeResources()
                        clearDrawRegistrations()
                        widget.draw(ctx)
                        ctx.drawActiveOverlay()
                    },
                    { =>
                        ctx.theme = transition.targetTheme()
                        ctx.syncThemeResources()
                        collectSemanticFrame({ =>
                            clearDrawRegistrations()
                            widget.draw(ctx)
                            ctx.drawActiveOverlay()
                        })
                    }
                )
                ctx.theme = transition.sourceTheme()
                ctx.syncThemeResources()
                transition.draw(ctx.renderer, width, height)
                ctx.drawInkRipples()
                if (ready && transition.isComplete()) {
                    let target = transition.targetTheme()
                    transition.close()
                    themeTransition = None
                    ctx.theme = target
                    ctx.requestFrame()
                }
                true
            case None => false
        }
    }

    private func drawDeviceRotationTransition(widget: Widget, width: Float32, height: Float32): Bool {
        match (deviceRotationTransition) {
            case Some(transition) =>
                let ready = transition.prepareNextSnapshot(
                    ctx.renderer,
                    width,
                    height,
                    ctx.theme.bg,
                    { =>
                        collectSemanticFrame({ =>
                            clearDrawRegistrations()
                            widget.draw(ctx)
                            ctx.drawInkRipples()
                            if (!ctx.hasOverlay()) { drawTooltip(ctx, width, height) }
                            ctx.drawActiveOverlay()
                        })
                    }
                )
                transition.draw(ctx.renderer, width, height)
                if (ready && transition.isComplete()) {
                    transition.close()
                    deviceRotationTransition = None
                    ctx.requestFrame()
                }
                true
            case None => false
        }
    }

    private func clearDrawRegistrations(): Unit {
        ctx.clearTooltip()
        ctx.clearActiveOverlay()
        ctx.clearTextInputAnchor()
    }

    private func closeThemeTransition(): Unit {
        match (themeTransition) {
            case Some(transition) => transition.close()
            case None => ()
        }
    }

    private func closeDeviceRotationTransition(): Unit {
        match (deviceRotationTransition) {
            case Some(transition) => transition.close()
            case None => ()
        }
        deviceRotationTransition = None
    }

    /*
     * Forwards the focused caret rectangle to the OS whenever it moves, so the IME
     * composition UI (candidate window) follows typing instead of sitting in a screen
     * corner. Unchanged rectangles are skipped to avoid a per-frame system call, and a
     * platform refusal is ignored — IME anchoring is polish, not frame-critical.
     */
    private func applyTextInputAnchor(): Unit {
        match (ctx.textInputAnchorRect()) {
            case Some(anchor) =>
                if (!sameAnchorRect(appliedInputAnchor, anchor)) {
                    appliedInputAnchor = Some(anchor)
                    try {
                        window.setTextInputArea(anchor)
                    } catch (_: Exception) {
                        ()
                    }
                }
            case None => ()
        }
    }

    // Capture is a renderer-owned request. The CLI starts the built executable
    // directly and supplies this request through DesktopCaptureRequest's host
    // protocol; the argv parser below remains only for older consumers.
    private func maybeCapture(): Unit {
        match (captureRequest) {
            case Some(request) where frames >= request.settleFrames =>
                ctx.renderer.captureBmp(request.path)
                ctx.requestClose()
            case _ => ()
        }
    }

    private func dispatchEvent(widget: Widget, event: UiEvent): Unit {
        let _ = widget.handle(ctx, event)
    }

    // Applies the hovered control's requested shape, skipping the SDL call when it is
    // already active. Cursor feedback is non-critical polish: a platform that refuses a
    // shape simply keeps the current cursor rather than failing the frame.
    private func applyDesiredCursor(): Unit {
        let shape = ctx.desiredCursor()
        match (appliedShape) {
            case Some(current) where current == shape => return
            case _ => ()
        }
        appliedShape = Some(shape)
        match (cursorForShape(shape)) {
            case Some(cursor) => try {
                cursor.setActive()
            } catch (_: Exception) {
                ()
            }
            case None => ()
        }
    }

    private func cursorForShape(shape: CursorShape): ?Cursor {
        match (shape) {
            case CursorShape.Default => ensureCursor(SystemCursor.Default)
            case CursorShape.Interactive => ensurePointerCursor()
            case CursorShape.Text => ensureTextCursor()
            case CursorShape.ResizeH => ensureResizeHCursor()
            case CursorShape.ResizeV => ensureResizeVCursor()
        }
    }

    private func ensureCursor(kind: SystemCursor): ?Cursor {
        match (baseCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                baseCursor = createCursor(kind)
                baseCursor
        }
    }

    private func ensurePointerCursor(): ?Cursor {
        match (pointerCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                pointerCursor = createCursor(SystemCursor.Pointer)
                pointerCursor
        }
    }

    private func ensureTextCursor(): ?Cursor {
        match (textCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                textCursor = createCursor(SystemCursor.Text)
                textCursor
        }
    }

    private func ensureResizeHCursor(): ?Cursor {
        match (resizeHCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                resizeHCursor = createCursor(SystemCursor.EwResize)
                resizeHCursor
        }
    }

    private func ensureResizeVCursor(): ?Cursor {
        match (resizeVCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                resizeVCursor = createCursor(SystemCursor.NsResize)
                resizeVCursor
        }
    }

    private func createCursor(kind: SystemCursor): ?Cursor {
        try {
            let cursor = Cursor.system(kind)
            resources.add(cursor)
            Some(cursor)
        } catch (_: Exception) {
            None
        }
    }

    private func nextFrame(previousTick: UInt64): FrameInfo {
        let currentTick = window.ticks()
        FrameInfo(currentTick, tickDelta(previousTick, currentTick))
    }

    private func preparePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseMove(x, y) => rememberMouse(x, y)
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                rememberMouse(x, y)
                ctx.leftMouseDown = true
            case UiEvent.MouseUp(MouseButton.Left, x, y) => rememberMouse(x, y)
            case UiEvent.DropFile(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropText(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropPosition(x, y) => rememberMouse(x, y)
            case _ => ()
        }
    }

    private func completePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                ctx.leftMouseDown = false
                ctx.clearDrag()
                ctx.clearPress()
            case _ => ()
        }
    }

    private func rememberMouse(x: Float32, y: Float32): Unit {
        ctx.mouseX = x
        ctx.mouseY = y
    }

    private func closeManagedResources(): Unit {
        var i = resources.size - 1
        while (i >= 0) {
            resources[i].close()
            i -= 1
        }
    }
}

/** Keeps the first application failure authoritative when shutdown also fails. */
internal func preferredDesktopRunFailure(original: ?Exception, cleanup: Exception): Exception {
    match (original) {
        case Some(error) => error
        case None => cleanup
    }
}

internal func resolveDesktopCaptureRequest(
    explicit: ?DesktopCaptureRequest,
    host: ?DesktopCaptureRequest,
    legacy: ?DesktopCaptureRequest
): ?DesktopCaptureRequest {
    match (explicit) {
        case Some(request) => Some(request)
        case None => match (host) {
            case Some(request) => Some(request)
            case None => legacy
        }
    }
}

private func legacySnapshotRequest(): ?DesktopCaptureRequest {
    match (legacySnapshotArgument()) {
        case Some(path) => Some(DesktopCaptureRequest(path, settleFrames: legacySnapshotFrameArgument()))
        case None => None
    }
}

private func legacySnapshotFrameArgument(): UInt64 {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--snapshot-frame") {
            try {
                let value = UInt64.parse(args[i + 1])
                if (value > UInt64(0)) {
                    return value
                }
            } catch (_: Exception) {
                return SNAPSHOT_SETTLE_FRAMES
            }
        }
        i += 1
    }
    SNAPSHOT_SETTLE_FRAMES
}

private func sameAnchorRect(applied: ?Rect, next: Rect): Bool {
    match (applied) {
        case Some(rect) => rect.x == next.x && rect.y == next.y && rect.w == next.w && rect.h == next.h
        case None => false
    }
}

internal func tickDelta(previousTick: UInt64, currentTick: UInt64): UInt64 {
    if (currentTick >= previousTick) {
        currentTick - previousTick
    } else {
        UInt64(0)
    }
}

internal func buildPointerDragEvents(
    fromX: Float32,
    fromY: Float32,
    toX: Float32,
    toY: Float32,
    steps: Int64
): ArrayList<UiEvent> {
    let moveSteps = if (steps < 1) { Int64(1) } else { steps }
    let out = ArrayList<UiEvent>()
    out.add(UiEvent.MouseDown(MouseButton.Left, fromX, fromY))
    for (i in 0..moveSteps) {
        let t = Float32(i + 1) / Float32(moveSteps)
        out.add(UiEvent.MouseMove(fromX + (toX - fromX) * t, fromY + (toY - fromY) * t))
    }
    out.add(UiEvent.MouseUp(MouseButton.Left, toX, toY))
    out
}

private func legacySnapshotArgument(): ?String {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--snapshot") {
            return Some(args[i + 1])
        }
        i += 1
    }
    None
}

// True when `--profile` is on the command line, turning on per-phase frame timing.
private func profileEnabled(): Bool {
    for (arg in getCommandLine()) {
        if (arg == "--profile") {
            return true
        }
    }
    false
}

// Internal rollout gate. Frame tracing is a separate compiler-debug path and enables the graph in
// DesktopApp directly; this switch only selects the live renderer path for an ordinary application.
private func desktopFrameGraphRequested(): Bool {
    match (getVariable("CANGHUI_FRAME_GRAPH")) {
        case Some(value) => value == "1" || value == "true" || value == "on" || value == "enabled"
        case None => false
    }
}

internal func desktopFrameSurfaceUsable(width: Int32, height: Int32): Bool {
    width > 0 && height > 0
}

private func desktopFrameDeclaredBytes(pixelCount: Int64): Int64 {
    let maximum: Int64 = 268435456
    let bytesPerPixel: Int64 = 4
    if (pixelCount <= 0 || pixelCount > maximum / bytesPerPixel) {
        // Deliberately one byte over the rev1 default cap: the compiler rejects the graph and the
        // Desktop shell uses its explicit legacy fallback without attempting an oversized target.
        return maximum + 1
    }
    pixelCount * bytesPerPixel
}

private func desktopFrameStableCode(generation: UInt64, width: Int32, height: Int32): Int64 {
    let modulus: Int64 = 2147483647
    var code = Int64(generation % UInt64(modulus))
    code = (code * 131 + Int64(max(Int32(1), width))) % modulus
    code = (code * 137 + Int64(max(Int32(1), height))) % modulus
    max(Int64(1), code)
}

private func desktopRetainedContextCode(
    width: Int32,
    height: Int32,
    displayScale: Float32,
    fontScale: Float32,
    rotation: DeviceRotation
): Int64 {
    let modulus: Int64 = 2147483647
    var code = Int64(max(Int32(1), width))
    code = (code * 131 + Int64(max(Int32(1), height))) % modulus
    code = (code * 137 + Int64(max(0.0, displayScale) * 1000.0)) % modulus
    code = (code * 139 + Int64(max(0.0, fontScale) * 1000.0)) % modulus
    let rotationCode = match (rotation) {
        case DeviceRotation.Unknown => Int64(0)
        case DeviceRotation.Portrait => Int64(1)
        case DeviceRotation.LandscapeClockwise => Int64(2)
        case DeviceRotation.PortraitUpsideDown => Int64(3)
        case DeviceRotation.LandscapeCounterClockwise => Int64(4)
    }
    max(Int64(1), (code * 149 + rotationCode) % modulus)
}

private func desktopRetainedFrameDamage(
    retained: RetainedUiDamage,
    surfaceWidth: Int64,
    surfaceHeight: Int64
): DamageRegion {
    if (retained.kind == RetainedUiDamageKind.Full) { return DamageRegion.full() }
    if (retained.kind == RetainedUiDamageKind.Empty) { return DamageRegion.empty() }
    let rectangles = ArrayList<FrameDamageRect>()
    for (i in 0..retained.rectangleCount()) {
        match (desktopFrameSurfaceBounds(
            retained.rectangleAt(i), surfaceWidth, surfaceHeight)) {
            case Some(value) => rectangles.add(value)
            // A bounded proof that cannot be represented by the target is never discarded.
            case None => return DamageRegion.full()
        }
    }
    if (rectangles.isEmpty()) { DamageRegion.full() } else {
        DamageRegion.bounded(rectangles.toArray())
    }
}

private func desktopFrameSurfaceBounds(
    source: Rect,
    surfaceWidth: Int64,
    surfaceHeight: Int64
): ?FrameDamageRect {
    let rightValue = source.right()
    let bottomValue = source.bottom()
    if (source.x != source.x || source.y != source.y || rightValue != rightValue ||
        bottomValue != bottomValue || rightValue <= 0.0 || bottomValue <= 0.0 ||
        source.x >= Float32(surfaceWidth) || source.y >= Float32(surfaceHeight)) {
        return None
    }
    let left = max(Int64(0), Int64(source.x))
    let top = max(Int64(0), Int64(source.y))
    let right = min(surfaceWidth, Int64(rightValue + 0.999))
    let bottom = min(surfaceHeight, Int64(bottomValue + 0.999))
    if (right <= left || bottom <= top) { return None }
    Some(FrameDamageRect(left, top, right - left, bottom - top))
}

private func configuredWindow(spec: WindowSpec, metadata: ?AppMetadata, hints: Array<SdlHintSetting>): SdlWindow {
    match (metadata) {
        case Some(value) => ApplicationMetadata.apply(value)
        case None => ()
    }
    SdlHints.apply(defaultDesktopHints())
    // Application hints are applied last so a host can explicitly restore the platform default.
    SdlHints.apply(hints)
    SdlWindow(spec)
}

internal func defaultDesktopHints(): Array<SdlHintSetting> {
    [SdlHintSetting(SdlHint.MouseFocusClickthrough, "1")]
}
