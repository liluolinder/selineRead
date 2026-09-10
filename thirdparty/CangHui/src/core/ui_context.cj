package chui.core

import std.collection.ArrayList
import std.sync.AtomicInt64
import sdl.{Color, DeviceRotation, DeviceRotationEvent, FrameInfo, Insets, Rect, Renderer, UiEvent}

// A second press within this window and distance of the previous one continues a multi-click.
private let MULTI_CLICK_MS: UInt64 = 400
private let MULTI_CLICK_DIST: Float32 = 4.0
private let INK_RIPPLE_MS: UInt64 = 420
private let UI_CONTEXT_OWNERSHIP_COUNTER = AtomicInt64(1)

private class InkRippleOverlay {
    let id: String
    let frame: Rect
    let originX: Float32
    let originY: Float32
    let startedAtMs: UInt64
    let durationMs: UInt64
    let strength: Float32
    let color: Color
    let cornerRadius: Float32

    init(id: String, frame: Rect, originX: Float32, originY: Float32, startedAtMs: UInt64,
        durationMs: UInt64, strength: Float32, color: Color, cornerRadius: Float32) {
        this.id = id
        this.frame = frame
        this.originX = originX
        this.originY = originY
        this.startedAtMs = startedAtMs
        this.durationMs = durationMs
        this.strength = strength
        this.color = color
        this.cornerRadius = cornerRadius
    }

    func progress(nowMs: UInt64): Float32 {
        if (nowMs <= startedAtMs) {
            return 0.0
        }
        min(1.0, Float32(nowMs - startedAtMs) / Float32(durationMs))
    }
}

private func deviceRotationChanged(first: DeviceRotation, second: DeviceRotation): Bool {
    match ((first, second)) {
        case (DeviceRotation.Unknown, DeviceRotation.Unknown) => false
        case (DeviceRotation.Portrait, DeviceRotation.Portrait) => false
        case (DeviceRotation.LandscapeClockwise, DeviceRotation.LandscapeClockwise) => false
        case (DeviceRotation.PortraitUpsideDown, DeviceRotation.PortraitUpsideDown) => false
        case (DeviceRotation.LandscapeCounterClockwise, DeviceRotation.LandscapeCounterClockwise) => false
        case _ => true
    }
}

/*
 * The per-frame service hub passed to every widget callback: the renderer and theme, pointer and
 * frame state, and the shared interaction protocols — focus (press claim/settle plus the Tab ring),
 * hover (single winner per pointer move), press, drag, tooltip, IME caret anchor, and the interactive
 * overlay stack. One instance lives for the whole application; the shell brackets event dispatch and
 * drawing with the protected begin/settle/clear calls, and widgets use the public claim/query surface.
 * `resolve` converts unit-carrying lengths (vp/px/fp) into logical pixels. `requestFrame()` keeps a
 * time-driven animation alive under the desktop loop's dirty-frame skipping — without it an idle
 * window stops rendering and the animation freezes.
 */
public class UiContext {
    private let ownershipTokenValue = UI_CONTEXT_OWNERSHIP_COUNTER.fetchAdd(1)
    public let renderer: Renderer
    public var theme: Theme
    public var focusId: String = ""
    // Whether the focused control should paint a ring: true when focus last moved by keyboard
    // (Tab traversal or autofocus), false when a pointer press claimed it — the :focus-visible
    // convention. Behaviour (activation, caret, arrow nav) uses `focusId`; only the ring gates on this.
    public var focusRingVisible: Bool = false
    public var hoverId: String = ""
    public var dragId: String = ""
    public var pressedId: String = ""
    private var pointerCaptureId: String = ""
    // Single-slot overlay: a hovered `Tooltip` registers here during draw and the shell
    // paints it above everything after the tree. Empty text means no tooltip this frame.
    public var tooltipText: String = ""
    public var tooltipAnchor: Rect = Rect.zero()
    public var mouseX: Float32 = 0.0
    public var mouseY: Float32 = 0.0
    public var leftMouseDown: Bool = false
    public var shouldClose: Bool = false
    public var frame: FrameInfo = FrameInfo(UInt64(0), UInt64(0))
    /** Logical size of the drawing surface; overlays clamp their popups to it. */
    public var viewportWidth: Float32 = 0.0
    public var viewportHeight: Float32 = 0.0
    private var reportedRotation: DeviceRotation = DeviceRotation.Unknown
    private var lastRotationEvent: ?DeviceRotationEvent = None
    // Interactive overlays open this frame, bottom to top. Registration order is z-order:
    // the tree draws first (a Modal registers its dialog), then the overlay render pass
    // draws each layer's content, so a popup opened inside a dialog registers — and
    // paints — above it. Events walk the stack top-down (see `dispatchOverlay`).
    private let overlays = ArrayList<Overlay>()
    private let inkRipples = ArrayList<InkRippleOverlay>()
    private let controlContentEnvironments = ArrayList<ControlContentEnvironment>()
    private let typographyEnvironments = ArrayList<TypographyEnvironment>()
    private let interactionEnabledScopes = ArrayList<Bool>()
    // FrameGraph scheduling facts only. Native handles and provider objects never enter this list.
    private let nativeChildFrameSurfaces = ArrayList<NativeChildFrameSurface>()
    private let sharedFrameSurfaces = ArrayList<SharedFrameSurface>()
    private var preserveScrollAnchorRequested = false
    /** Physical pixels per virtual pixel; set from the window content scale. */
    public var displayScale: Float32 = 1.0
    /** User font scale applied to `fp` lengths; `1.0` keeps `fp` equal to `vp`. */
    public var fontScale: Float32 = 1.0

    public init(renderer: Renderer, theme: Theme) {
        this.renderer = renderer
        this.theme = theme
        renderer.setThemeFontFamily(theme.fontFamily)
    }

    /** Stable process-local identity used to keep retained native surfaces inside one UI owner. */
    protected func ownershipToken(): Int64 { ownershipTokenValue }

    /** Clears the previous declarative build's external-surface scheduling registrations. */
    protected func beginFrameSurfaceRegistration(): Unit {
        nativeChildFrameSurfaces.clear()
        finishSharedFrameSurfaces("abandoned")
        sharedFrameSurfaces.clear()
    }

    /** Registers a Scene3D/native child surface without moving its lifecycle or input ownership. */
    protected func registerNativeChildFrameSurface(
        identity: String,
        generation: Int64,
        bounds: Rect
    ): Unit {
        if (identity.isEmpty() || generation <= 0 || bounds.w <= 0.0 || bounds.h <= 0.0) { return }
        nativeChildFrameSurfaces.add(NativeChildFrameSurface(identity, generation, bounds))
    }

    protected func nativeChildFrameSurfaceCount(): Int64 { nativeChildFrameSurfaces.size }

    protected func nativeChildFrameSurfaceAt(index: Int64): NativeChildFrameSurface {
        nativeChildFrameSurfaces[index]
    }

    /** Registers an immutable, handle-free shared frame acquired and released by Scene3D. */
    protected func registerSharedFrameSurface(value: SharedFrameSurface): Unit {
        // A view contributes exactly one composition mode per frame. Shared pixels supersede a
        // native-child barrier with the same stable identity and generation.
        for (i in 0..sharedFrameSurfaces.size) {
            if (sharedFrameSurfaces[i].identity == value.identity) {
                let _ = sharedFrameSurfaces[i].finish("replaced")
                sharedFrameSurfaces[i] = value
                return
            }
        }
        sharedFrameSurfaces.add(value)
    }

    protected func sharedFrameSurfaceCount(): Int64 { sharedFrameSurfaces.size }

    protected func sharedFrameSurfaceAt(index: Int64): SharedFrameSurface {
        sharedFrameSurfaces[index]
    }

    protected func sharedFrameSurface(identity: String): ?SharedFrameSurface {
        for (value in sharedFrameSurfaces) {
            if (value.identity == identity && !value.isFinished()) { return Some(value) }
        }
        None
    }

    /** Resets renderer evidence for every provider frame still owned by this UI frame. */
    protected func beginSharedFrameCompositionAttempt(): Unit {
        for (value in sharedFrameSurfaces) { value.beginCompositionAttempt() }
    }

    /** True only when every unfinished provider frame was sampled successfully at least once. */
    protected func sharedFrameCompositionSucceeded(): Bool {
        for (value in sharedFrameSurfaces) {
            if (!value.isFinished() && !value.compositionSucceeded()) { return false }
        }
        true
    }

    protected func unfinishedSharedFrameSurfaceCount(): Int64 {
        var count: Int64 = 0
        for (value in sharedFrameSurfaces) {
            if (!value.isFinished()) { count += 1 }
        }
        count
    }

    /** Completes every acquired Scene3D frame after graph commit, rollback, or legacy fallback. */
    protected func finishSharedFrameSurfaces(outcome: String): Bool {
        var ok = true
        for (value in sharedFrameSurfaces) {
            if (!value.finish(outcome)) { ok = false }
        }
        ok
    }

    /** Last posture reported by a platform provider, without viewport fallback. */
    public func reportedDeviceRotation(): DeviceRotation {
        reportedRotation
    }

    /** Last complete device-rotation event, including its source and source timestamp. */
    public func deviceRotationEvent(): ?DeviceRotationEvent {
        lastRotationEvent
    }

    /**
     * Effective layout posture. Before a provider reports, viewport aspect ratio is the
     * deterministic fallback; this does not claim that a physical sensor produced a value.
     */
    public func deviceRotation(): DeviceRotation {
        match (reportedRotation) {
            case DeviceRotation.Unknown =>
                if (viewportWidth > viewportHeight) {
                    DeviceRotation.LandscapeClockwise
                } else {
                    DeviceRotation.Portrait
                }
            case value => value
        }
    }

    /** Applies one normalized provider event and wakes layout only when posture changed. */
    public func updateDeviceRotation(event: DeviceRotationEvent): Unit {
        let changed = deviceRotationChanged(reportedRotation, event.rotation)
        reportedRotation = event.rotation
        lastRotationEvent = Some(event)
        if (changed) {
            requestFrame()
        }
    }

    /** Applies Theme-owned renderer resources before a draw pass. */
    protected func syncThemeResources(): Unit {
        renderer.setThemeFontFamily(theme.fontFamily)
    }

    /** Converts a unit-carrying length into logical (virtual) pixels. */
    public func resolve(length: Length): Float32 {
        match (length.unit) {
            case LengthUnit.Vp => length.value
            case LengthUnit.Px => length.value / max(0.001, displayScale)
            case LengthUnit.Fp => length.value * fontScale
        }
    }

    /** Converts unit-carrying edge insets into logical-pixel insets. */
    public func resolve(insets: LengthInsets): Insets {
        Insets(
            max(0.0, resolve(insets.top)),
            max(0.0, resolve(insets.right)),
            max(0.0, resolve(insets.bottom)),
            max(0.0, resolve(insets.left))
        )
    }

    /** Returns the nearest compound-control content environment, if one is active. */
    public func controlContentEnvironment(): ?ControlContentEnvironment {
        if (controlContentEnvironments.isEmpty()) { return None }
        Some(controlContentEnvironments[controlContentEnvironments.size - 1])
    }

    /** Theme or compound-control foreground inherited by content without an explicit color. */
    public func contentForeground(): Color {
        match (controlContentEnvironment()) {
            case Some(value) => value.foreground
            case None => theme.text
        }
    }

    /** Theme or compound-control supporting foreground inherited by muted content. */
    public func contentSupportingForeground(): Color {
        match (controlContentEnvironment()) {
            case Some(value) => value.supportingForeground
            case None => theme.mutedText
        }
    }

    /** Runs one draw callback with a scoped, automatically restored content environment. */
    public func withControlContentEnvironment(environment: ControlContentEnvironment, body: () -> Unit): Unit {
        let effective = ControlContentEnvironment(
            environment.foreground,
            supportingForeground: Some(environment.supportingForeground),
            role: environment.role,
            interactionOwner: environment.interactionOwner,
            selected: environment.selected,
            expanded: environment.expanded,
            focused: environment.focused,
            hovered: environment.hovered,
            pressed: environment.pressed,
            enabled: environment.enabled && interactionsEnabled(),
            readOnly: environment.readOnly
        )
        controlContentEnvironments.add(effective)
        try {
            body()
        } finally {
            controlContentEnvironments.remove(at: controlContentEnvironments.size - 1)
        }
    }

    /** Returns the effective inherited typography values at the current tree position. */
    public func typographyEnvironment(): TypographyEnvironment {
        if (typographyEnvironments.isEmpty()) { return TypographyEnvironment() }
        typographyEnvironments[typographyEnvironments.size - 1]
    }

    /** Runs one widget phase with fieldwise inherited typography and automatic restoration. */
    public func withTypographyEnvironment<T>(environment: TypographyEnvironment, body: () -> T): T {
        let effective = typographyEnvironment().merging(environment)
        typographyEnvironments.add(effective)
        try {
            body()
        } finally {
            typographyEnvironments.remove(at: typographyEnvironments.size - 1)
        }
    }

    /** Whether the currently drawn subtree may receive ordinary interaction. */
    public func interactionsEnabled(): Bool {
        if (interactionEnabledScopes.isEmpty()) { return true }
        interactionEnabledScopes[interactionEnabledScopes.size - 1]
    }

    /** Runs one draw callback with nested `.enabled(...)` values combined by logical conjunction. */
    public func withInteractionsEnabled(isEnabled: Bool, body: () -> Unit): Unit {
        let effective = interactionsEnabled() && isEnabled
        interactionEnabledScopes.add(effective)
        try {
            body()
        } finally {
            interactionEnabledScopes.remove(at: interactionEnabledScopes.size - 1)
        }
    }

    private var focusClaimedInPress = false
    private var focusOrder: Array<String> = []
    /** How many rapid presses ended at the current one: 1 single, 2 double, 3 triple. */
    public var clickCount: Int64 = 1
    private var lastPressMs: UInt64 = 0
    private var lastPressX: Float32 = 0.0
    private var lastPressY: Float32 = 0.0
    private var hasLastPress = false

    public func requestClose(): Unit {
        shouldClose = true
    }

    // Set by a widget during handle or draw when it needs the next frame rendered even without any
    // input event or state change — a blinking caret, a tooltip counting down its reveal delay, a
    // per-frame FrameHandler. The desktop loop reads and clears it each rendered frame (takeFrameRequest)
    // so these animations stay alive while the loop otherwise skips idle frames (档 0).
    private var continuousFrameRequested = false

    /**
     * Requests that the next frame be rendered even if no input arrived and no state changed. Call this
     * from a widget that animates on the frame clock (a caret, a spinner, a countdown); without it the
     * desktop loop may skip rendering while the screen is otherwise idle.
     */
    public func requestFrame(): Unit {
        continuousFrameRequested = true
    }

    /** Reads and clears the continuous-frame request. The desktop loop calls this once per rendered frame. */
    protected func takeFrameRequest(): Bool {
        let requested = continuousFrameRequested
        continuousFrameRequested = false
        requested
    }

    /** Starts or restarts one control-local InkWell ripple. */
    public func startInkRipple(
        id: String,
        frame: Rect,
        x: Float32,
        y: Float32,
        color!: ?Color = None,
        cornerRadius!: Float32 = 0.0
    ): Unit {
        var i = inkRipples.size - 1
        while (i >= 0) {
            if (inkRipples[i].id == id) {
                inkRipples.remove(at: i)
            }
            i -= 1
        }
        let resolvedColor = match (color) {
            case Some(value) => value
            case None => theme.inkColor()
        }
        inkRipples.add(InkRippleOverlay(id, frame, x, y, this.frame.elapsedMs,
            theme.motionLevel.automaticDuration(INK_RIPPLE_MS), theme.motionLevel.amplitude(),
            resolvedColor, cornerRadius))
        requestFrame()
    }

    /** Cancels a control-local ripple when its pointer press leaves the hit target. */
    public func cancelInkRipple(id: String): Unit {
        var i = inkRipples.size - 1
        while (i >= 0) {
            if (inkRipples[i].id == id) {
                inkRipples.remove(at: i)
            }
            i -= 1
        }
    }

    /** Paints active ripples above the widget tree and keeps dirty-frame rendering alive. */
    public func drawInkRipples(): Unit {
        var active = false
        var i = inkRipples.size - 1
        while (i >= 0) {
            let ripple = inkRipples[i]
            let p = ripple.progress(frame.elapsedMs)
            if (p >= 1.0) {
                inkRipples.remove(at: i)
            } else {
                active = true
                let eased = 1.0 - (1.0 - p) * (1.0 - p) * (1.0 - p)
                let radius = 2.0 + max(ripple.frame.w, ripple.frame.h) * 0.52 * eased * ripple.strength
                let fade = if (p < 0.35) { Float32(1.0) } else { max(0.0, (1.0 - p) / 0.65) }
                renderer.pushDrawIrScope(ripple.id)
                try {
                    renderer.fillRoundedRipple(ripple.frame.inset(1.0), max(0.0, ripple.cornerRadius - 1.0),
                        ripple.originX, ripple.originY, radius,
                        ripple.color.withAlpha(Int64(Float32(88.0) * fade * min(1.0, ripple.strength))))
                } finally {
                    renderer.popDrawIrScope()
                }
            }
            i -= 1
        }
        if (active) {
            requestFrame()
        }
    }

    /** Requests that the nearest enclosing ScrollView preserve its current visual anchor. */
    public func preserveScrollAnchor(): Unit {
        preserveScrollAnchorRequested = true
    }

    internal func takeScrollAnchorRequest(): Bool {
        let requested = preserveScrollAnchorRequested
        preserveScrollAnchorRequested = false
        requested
    }

    /*
     * Adopts the focus ring gathered by the latest build. The shell calls this once per
     * frame after building the tree, so keyboard traversal always reflects the controls
     * currently on screen and in their declared order.
     */
    protected func adoptFocusRing(ids: Array<String>): Unit {
        focusOrder = ids.clone()
    }

    /** Focuses only an ID present in the latest declarative focus ring. */
    protected func focusRegistered(id: String, viaKeyboard!: Bool = true): Bool {
        for (candidate in focusOrder) {
            if (candidate == id) {
                focus(id, viaKeyboard: viaKeyboard)
                return true
            }
        }
        false
    }

    /** Build/declaration-order position used by the in-process semantic collector. */
    internal func semanticFocusOrder(id: String): ?Int64 {
        for (index in 0..focusOrder.size) {
            if (focusOrder[index] == id) { return Some(index) }
        }
        None
    }

    /** Moves keyboard focus to the next focusable control, wrapping at the end. */
    public func focusNext(): Unit {
        moveFocus(1)
    }

    /** Moves keyboard focus to the previous focusable control, wrapping at the start. */
    public func focusPrevious(): Unit {
        moveFocus(-1)
    }

    /*
     * Advances focus by `step` positions through the ring. From no focus, a forward step
     * lands on the first control and a backward step on the last, matching how Tab and
     * Shift+Tab enter a window. A focus id no longer present (the tree changed shape) is
     * treated as "outside the ring" and re-enters from the corresponding end.
     */
    private func moveFocus(step: Int64): Unit {
        let count = focusOrder.size
        if (count == 0) {
            return
        }
        var current = -1
        for (i in 0..count) {
            if (focusOrder[i] == focusId) {
                current = i
                break
            }
        }
        let next = if (current < 0) {
            if (step > 0) { 0 } else { count - 1 }
        } else {
            (((current + step) % count) + count) % count
        }
        focusId = focusOrder[next]
        focusRingVisible = true // Tab traversal is keyboard, so the ring shows
    }

    public func hasFocus(id: String): Bool {
        focusId == id
    }

    /*
     * Whether `id` should paint a focus ring: it must have focus AND focus must have last moved
     * by keyboard. A pointer press focuses without a ring, matching the desktop `:focus-visible`
     * convention that a click should not leave a keyboard-style outline.
     */
    public func showFocusRing(id: String): Bool {
        focusId == id && focusRingVisible
    }

    // `viaKeyboard` marks focus the user reached by keyboard (Tab, autofocus) versus a pointer
    // press; it drives whether a ring shows, not focus itself.
    public func focus(id: String, viaKeyboard!: Bool = false): Unit {
        focusId = id
        focusClaimedInPress = true
        focusRingVisible = viaKeyboard
    }

    /** Removes keyboard focus from every control. */
    public func clearFocus(): Unit {
        focusId = ""
        focusRingVisible = false
    }

    /*
     * Desktop-standard blur: a primary press either moves focus to the control that
     * claims it, or clears focus entirely. The shell brackets each MouseDown dispatch
     * with these two calls; any `focus()` during dispatch counts as a claim.
     */
    /*
     * Classifies a primary press as single/double/triple by how closely it follows the
     * previous one in time and space. The shell calls this on each left MouseDown before
     * dispatch, so controls can read `clickCount` while handling the press. Kept as a
     * general primitive: any widget can act on double-clicks, not just text.
     */
    protected func recordPress(x: Float32, y: Float32): Unit {
        let now = frame.elapsedMs
        let dx = x - lastPressX
        let dy = y - lastPressY
        let near = dx * dx + dy * dy <= MULTI_CLICK_DIST * MULTI_CLICK_DIST
        let quick = hasLastPress && now >= lastPressMs && now - lastPressMs <= MULTI_CLICK_MS && near
        if (quick) {
            clickCount = if (clickCount >= 3) {
                1
            } else {
                clickCount + 1
            }
        } else {
            clickCount = 1
        }
        lastPressMs = now
        lastPressX = x
        lastPressY = y
        hasLastPress = true
    }

    protected func beginPointerPress(): Unit {
        focusClaimedInPress = false
    }

    protected func settleFocusAfterPress(): Unit {
        if (!focusClaimedInPress) {
            clearFocus()
        }
    }

    private var hoverClaimed = false
    private var pendingHoverId: String = ""
    private var pendingHoverShape = CursorShape.Default
    private var settledHoverShape = CursorShape.Default

    /*
     * Hover is resolved once per pointer move, mirroring the focus press-settle protocol.
     * The shell brackets a MouseMove dispatch with begin/settle; each control the pointer
     * is inside calls `claimHover`. Dispatch visits top-most first, and only the first
     * claim of a move wins, so overlapping layers resolve to the visually top control.
     */
    protected func beginHoverTest(): Unit {
        hoverClaimed = false
        pendingHoverId = ""
        pendingHoverShape = CursorShape.Default
    }

    /** Claims hover for `id` with the desired pointer shape; the first claim per move wins. */
    public func claimHover(id: String, shape: CursorShape): Unit {
        if (!hoverClaimed) {
            hoverClaimed = true
            pendingHoverId = id
            pendingHoverShape = shape
        }
    }

    protected func settleHover(): Unit {
        hoverId = pendingHoverId
        settledHoverShape = pendingHoverShape
    }

    /** Returns whether `id` is the control currently under the pointer. */
    public func isHovered(id: String): Bool {
        hoverId == id
    }

    /** Registers a tooltip to paint above the tree this frame, anchored to `rect`. */
    public func showTooltip(text: String, rect: Rect): Unit {
        tooltipText = text
        tooltipAnchor = rect
    }

    /** Clears any pending tooltip; the shell calls this before drawing each frame. */
    public func clearTooltip(): Unit {
        tooltipText = ""
    }

    // Where the focused text control wants the IME composition UI anchored, in logical
    // pixels: the caret rectangle it reported during draw (blink phase or not). The shell
    // forwards changes to the window, so the candidate window follows the caret instead
    // of sitting in a screen corner.
    private var textInputAnchor: ?Rect = None

    /** Reports the focused caret rectangle this frame, anchoring the IME candidate window. */
    public func setTextInputAnchor(rect: Rect): Unit {
        textInputAnchor = Some(rect)
    }

    /** Clears the reported caret anchor; the shell calls this before drawing each frame. */
    public func clearTextInputAnchor(): Unit {
        textInputAnchor = None
    }

    /** The caret rectangle reported during this frame's draw, if a text control has focus. */
    public func textInputAnchorRect(): ?Rect {
        textInputAnchor
    }

    /**
     * Registers an interactive overlay (a dropdown/menu popup, a dialog) for this frame,
     * above those already open. Re-registering under an already-present `owner` replaces
     * that entry in place, keeping its z position.
     */
    public func setOverlay(overlay: Overlay): Unit {
        overlay.captureTypography(typographyEnvironment())
        if (!overlay.owner.isEmpty()) {
            for (i in 0..overlays.size) {
                if (overlays[i].owner == overlay.owner) {
                    overlays[i] = overlay
                    return
                }
            }
        }
        overlays.add(overlay)
    }

    /**
     * Removes the overlay registered under `owner`, leaving the rest of the stack open —
     * a closing popup removes exactly its own registration, never a dialog beneath it.
     */
    public func removeOverlay(owner: String): Unit {
        if (owner.isEmpty()) {
            return
        }
        var i = overlays.size - 1
        while (i >= 0) {
            if (overlays[i].owner == owner) {
                overlays.remove(at: i)
            }
            i -= 1
        }
    }

    /** Removes every open overlay — the shell calls this each frame before the tree re-registers. */
    public func clearActiveOverlay(): Unit {
        overlays.clear()
    }

    /** Whether any interactive overlay is currently open. */
    public func hasOverlay(): Bool {
        !overlays.isEmpty()
    }

    /** How many interactive overlays are currently open (a dialog plus its popup counts two). */
    public func overlayCount(): Int64 {
        overlays.size
    }

    /**
     * Offers `event` to the open overlays, top-most first; returns whether one consumed it.
     * A layer that does not consume lets the event fall to the layer beneath — a Modal
     * consumes everything, so events never pass a dialog into the backdrop tree. Public so
     * a custom shell (not just `DesktopApp`) can route events through the overlays.
     */
    public func dispatchOverlay(event: UiEvent): Bool {
        // Walk a snapshot: a handler may close (remove) overlays mid-dispatch. An entry
        // removed by a layer above it is skipped rather than offered a stale event.
        let snapshot = overlays.toArray()
        var i = snapshot.size - 1
        while (i >= 0) {
            let overlay = snapshot[i]
            if (isRegistered(overlay) && overlay.dispatch(this, event)) {
                return true
            }
            i -= 1
        }
        false
    }

    private func isRegistered(overlay: Overlay): Bool {
        for (candidate in overlays) {
            if (refEq(candidate, overlay)) {
                return true
            }
        }
        false
    }

    /**
     * Paints the open overlays bottom to top, after the tree; a custom shell calls this
     * once per frame. Rendering a layer may register further overlays (a dropdown open
     * inside a dialog registers while the dialog's body draws) — the loop picks them up
     * and paints them above, within the same frame.
     */
    public func drawActiveOverlay(): Unit {
        var i = 0
        while (i < overlays.size) {
            overlays[i].render(this)
            i += 1
        }
    }

    /** The pointer shape requested by the hovered control, or `Default` when none. */
    protected func desiredCursor(): CursorShape {
        settledHoverShape
    }

    // Where inside the dragged part the pointer grabbed it. Lives here, not on the widget:
    // the tree is rebuilt every frame, so a controller instance recording the grab in a field
    // would lose it before the first MouseMove arrives at the next frame's fresh instance.
    private var dragGrabOffset: Float32 = 0.0

    /**
     * Marks `id` as the active drag owner. `grab!` records the pointer's offset within the
     * dragged part (for example pointer y minus thumb top), read back via `dragGrab()` on
     * later frames so the drag stays anchored where it was picked up instead of snapping.
     */
    public func beginDrag(id: String, grab!: Float32 = 0.0): Unit {
        dragId = id
        dragGrabOffset = grab
    }

    /** The grab-point offset recorded by `beginDrag`; meaningful only while that drag is active. */
    public func dragGrab(): Float32 {
        dragGrabOffset
    }

    public func isDragging(id: String): Bool {
        dragId == id
    }

    public func clearDrag(): Unit {
        dragId = ""
        dragGrabOffset = 0.0
    }

    /** Routes subsequent primary-pointer move/up events to one stable interaction owner. */
    public func capturePointer(id: String): Unit {
        if (id.isEmpty()) { throw IllegalArgumentException("pointer capture owner must not be empty") }
        pointerCaptureId = id
    }

    public func pointerCaptureOwner(): String { pointerCaptureId }

    public func hasPointerCapture(id: String): Bool { pointerCaptureId == id }

    /** Releases only the caller's capture, preserving a later owner's claim. */
    public func releasePointerCapture(id: String): Unit {
        if (pointerCaptureId == id) { pointerCaptureId = "" }
    }

    /** Marks a control as pressed until the primary pointer is released. */
    public func press(id: String): Unit {
        pressedId = id
    }

    /** Returns whether `id` owns the active primary-pointer press. */
    public func isPressed(id: String): Bool {
        pressedId == id
    }

    /** Clears the active primary-pointer press. */
    public func clearPress(): Unit {
        pressedId = ""
    }

    /** Cancels a specific press without disturbing another control's later claim. */
    public func cancelPress(id: String): Unit {
        if (pressedId == id) {
            pressedId = ""
        }
    }
}
