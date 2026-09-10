package chui.core

import std.collection.ArrayList
import sdl.{DrawIrAsciiAnnotationKind, GamepadButton, Key, MouseButton, Rect, Size, UiEvent}

/** Optional gesture callbacks composed under an `InteractionSurface`'s single semantic owner. */
public class GestureHandlers {
    public let onDoubleTap: ?(() -> Unit)
    public let onLongPress: ?(() -> Unit)
    public let onDragStart: ?((Float32, Float32) -> Unit)
    public let onDragUpdate: ?((Float32, Float32, Float32, Float32) -> Unit)
    public let onDragEnd: ?((Float32, Float32) -> Unit)
    public let onDragCancel: ?(() -> Unit)
    public let onHoverChanged: ?((Bool) -> Unit)
    public let longPressMs: UInt64
    public let dragThreshold: Float32
    public let capturePointer: Bool

    public init(
        onDoubleTap!: ?(() -> Unit) = None,
        onLongPress!: ?(() -> Unit) = None,
        onDragStart!: ?((Float32, Float32) -> Unit) = None,
        onDragUpdate!: ?((Float32, Float32, Float32, Float32) -> Unit) = None,
        onDragEnd!: ?((Float32, Float32) -> Unit) = None,
        onDragCancel!: ?(() -> Unit) = None,
        onHoverChanged!: ?((Bool) -> Unit) = None,
        longPressMs!: UInt64 = UInt64(500),
        dragThreshold!: Float32 = 6.0,
        capturePointer!: Bool = true
    ) {
        this.onDoubleTap = onDoubleTap
        this.onLongPress = onLongPress
        this.onDragStart = onDragStart
        this.onDragUpdate = onDragUpdate
        this.onDragEnd = onDragEnd
        this.onDragCancel = onDragCancel
        this.onHoverChanged = onHoverChanged
        this.longPressMs = max(UInt64(1), longPressMs)
        this.dragThreshold = max(0.0, dragThreshold)
        this.capturePointer = capturePointer
    }
}

private class GestureSurfaceRuntime {
    var pressStartedAt: UInt64 = 0
    var pressX: Float32 = 0.0
    var pressY: Float32 = 0.0
    var lastX: Float32 = 0.0
    var lastY: Float32 = 0.0
    var longPressFired = false
    var hovering = false

    func begin(time: UInt64, x: Float32, y: Float32): Unit {
        pressStartedAt = time
        pressX = x
        pressY = y
        lastX = x
        lastY = y
        longPressFired = false
    }

    func resetPress(): Unit {
        pressStartedAt = 0
        longPressFired = false
    }
}

/** Semantic role owned by one `InteractionSurface`. */
public enum ControlRole {
    | Button
    | Link
    | Checkbox
    | Switch
    | Custom(String)

    public func name(): String {
        match (this) {
            case Button => "button"
            case Link => "link"
            case Checkbox => "checkbox"
            case Switch => "switch"
            case Custom(value) => value
        }
    }
}

/**
 * A one-owner interaction primitive for arbitrary decorative content. It owns exactly one focus id,
 * pressed state, release-inside action and semantic region. Interaction-owning descendants are invalid:
 * their focus ids are removed from the Tab ring, they are reported to ComponentProbe and both outer and
 * nested actions fail closed.
 */
public class InteractionSurface <: Widget {
    private let child: Widget
    private let action: () -> Unit
    private let controlRole: ControlRole
    private let semanticLabel: String
    private let isReadOnly: Bool
    private let isSelected: ?Bool
    private let isExpanded: ?Bool
    private var controlId: String
    private let nestedFocusIds: Array<String>
    private let nestedInteractionOwnerIds: Array<String>
    private var materialProvider: MaterialProvider
    private var surfaceShape: Shape
    private var clipPolicy: ClipPolicy
    private var gestureHandlers = GestureHandlers()
    private let gestureRuntime: GestureSurfaceRuntime
    private var frame = Rect.zero()

    public init(
        action!: () -> Unit,
        role!: ControlRole = ControlRole.Button,
        accessibilityLabel!: String = "",
        key!: ?String = None,
        readOnly!: Bool = false,
        selected!: ?Bool = None,
        expanded!: ?Bool = None,
        body!: () -> Unit
    ) {
        if (role.name().isEmpty()) {
            throw IllegalArgumentException("InteractionSurface role must not be empty")
        }
        this.action = action
        this.controlRole = role
        this.semanticLabel = accessibilityLabel
        this.isReadOnly = readOnly
        this.isSelected = selected
        this.isExpanded = expanded
        let focusStart = focusableCountNow()
        this.child = buildChild(body)
        let registered = focusablesSince(focusStart)
        this.nestedFocusIds = collectNestedFocusIds(child, registered)
        this.nestedInteractionOwnerIds = collectNestedInteractionOwnerIds(child, nestedFocusIds)
        for (id in nestedFocusIds) { unregisterFocusable(id) }
        this.controlId = resolveControlKey(key, "InteractionSurface")
        this.gestureRuntime = localState<GestureSurfaceRuntime>(
            "InteractionSurface:${this.controlId}:gestures") { GestureSurfaceRuntime() }.value
        if (!isReadOnly && nestedInteractionOwnerIds.isEmpty()) { registerFocusable(controlId) }
        this.materialProvider = Materials.themeSurface()
        this.surfaceShape = Shape.rectangle()
        this.clipPolicy = ClipPolicy.Unclipped
        emit(this)
    }

    /** Replaces the auto-derived interaction identity with a stable explicit key. */
    public func key(value: String): InteractionSurface {
        requireControlId(value, "InteractionSurface")
        if (!isReadOnly && nestedInteractionOwnerIds.isEmpty()) { reregisterFocusable(controlId, value) }
        controlId = value
        this
    }

    /** Configures the visual material and the shared surface/ink shape. */
    public func surface(
        shape: Shape,
        material: MaterialProvider,
        clip!: ClipPolicy = ClipPolicy.Shape
    ): InteractionSurface {
        surfaceShape = shape
        materialProvider = material
        clipPolicy = clip
        this
    }

    /** Composes higher-level gestures without introducing a second focus/action owner. */
    public func gestures(value: GestureHandlers): InteractionSurface {
        gestureHandlers = value
        this
    }

    /** Stable structural diagnostic, or `None` when the decorative slot has one owner. */
    public func structuralDiagnostic(): ?String {
        if (nestedInteractionOwnerIds.isEmpty()) { return None }
        Some("nested-interaction-owner: " + joinOwnerIds(nestedInteractionOwnerIds))
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        let state = currentState(ctx)
        let material = materialProvider.resolve(ctx.theme, state)
        drawMaterialSurface(ctx, frame, surfaceShape, material)
        recordControlSemantics(ctx, frame, "InteractionSurface", ControlSemantics(
            controlRole.name(),
            label: semanticLabel,
            action: if (state.enabled) {"InteractionSurface.activate()"} else {""},
            shortcut: if (state.enabled) {"Enter|Space"} else {""},
            actionOwner: controlId,
            selected: isSelected,
            expanded: isExpanded,
            enabled: Some(state.enabled),
            readOnly: Some(state.readOnly),
            typedActions: if (state.enabled) {
                [SemanticActionKind.Focus, SemanticActionKind.Activate]
            } else {
                []
            }
        ))
        recordNestedInteractionDiagnostic()
        ctx.withControlContentEnvironment(ControlContentEnvironment(
            material.foreground,
            supportingForeground: Some(material.supportingForeground),
            role: controlRole.name(),
            interactionOwner: controlId,
            selected: match (isSelected) {case Some(value) => value case None => false},
            expanded: match (isExpanded) {case Some(value) => value case None => false},
            focused: state.focused,
            hovered: state.hovered,
            pressed: state.pressed,
            enabled: state.enabled,
            readOnly: state.readOnly
        )) {=>
            ctx.withInteractionsEnabled(state.enabled) {=>
                withSurfaceClip(ctx, frame, clipPolicy) {=> child.draw(ctx)}
            }
        }
        if (state.enabled && ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, frame, surfaceShape.cornerRadius())
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let state = currentState(ctx)
        if (!state.enabled) { return false }
        let material = materialProvider.resolve(ctx.theme, state)
        if (handleGestures(ctx, event, material)) { return true }
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    activateFromKeyboard(ctx, material)
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    activateFromKeyboard(ctx, material)
                    return true
                }
            case UiEvent.GamepadButtonDown(_, GamepadButton.South) =>
                if (ctx.hasFocus(controlId)) {
                    activateFromKeyboard(ctx, material)
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        if (isReadOnly || !nestedInteractionOwnerIds.isEmpty()) { None } else { Some(controlId) }
    }

    public func interactionOwnerIds(): Array<String> {
        if (!nestedInteractionOwnerIds.isEmpty()) { return nestedInteractionOwnerIds }
        if (isReadOnly) { [] } else { [controlId] }
    }

    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }

    private func currentState(ctx: UiContext): SurfaceState {
        let enabled = ctx.interactionsEnabled() && !isReadOnly && nestedInteractionOwnerIds.isEmpty()
        SurfaceState(
            enabled: enabled,
            readOnly: isReadOnly,
            selected: match (isSelected) {case Some(value) => value case None => false},
            expanded: match (isExpanded) {case Some(value) => value case None => false},
            focused: enabled && ctx.hasFocus(controlId),
            hovered: enabled && ctx.isHovered(controlId),
            pressed: enabled && ctx.isPressed(controlId)
        )
    }

    private func activateFromKeyboard(ctx: UiContext, material: SurfaceMaterial): Unit {
        ctx.startInkRipple(controlId, frame, frame.centerX(), frame.centerY(),
            color: Some(material.ink), cornerRadius: surfaceShape.cornerRadius())
        action()
    }

    private func handleGestures(ctx: UiContext, event: UiEvent, material: SurfaceMaterial): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        match (event) {
            case UiEvent.Frame(info) =>
                if (ctx.isPressed(controlId) && !gestureRuntime.longPressFired &&
                    gestureHandlers.onLongPress.isSome() && info.elapsedMs >= gestureRuntime.pressStartedAt &&
                    info.elapsedMs - gestureRuntime.pressStartedAt >= gestureHandlers.longPressMs) {
                    gestureRuntime.longPressFired = true
                    match (gestureHandlers.onLongPress) { case Some(callback) => callback() case None => () }
                }
                return false
            case UiEvent.MouseMove(x, y) =>
                let inside = frame.contains(x, y)
                if (inside != gestureRuntime.hovering) {
                    gestureRuntime.hovering = inside
                    match (gestureHandlers.onHoverChanged) {
                        case Some(callback) => callback(inside)
                        case None => ()
                    }
                }
                if (ctx.isPressed(controlId)) {
                    let dx = x - gestureRuntime.lastX
                    let dy = y - gestureRuntime.lastY
                    let totalX = x - gestureRuntime.pressX
                    let totalY = y - gestureRuntime.pressY
                    if (!ctx.isDragging(controlId) && gestureHasDragCallbacks(gestureHandlers) &&
                        totalX * totalX + totalY * totalY >=
                            gestureHandlers.dragThreshold * gestureHandlers.dragThreshold) {
                        ctx.beginDrag(controlId)
                        if (gestureHandlers.capturePointer) { ctx.capturePointer(controlId) }
                        match (gestureHandlers.onDragStart) {
                            case Some(callback) => callback(gestureRuntime.pressX, gestureRuntime.pressY)
                            case None => ()
                        }
                    }
                    if (ctx.isDragging(controlId)) {
                        match (gestureHandlers.onDragUpdate) {
                            case Some(callback) => callback(x, y, dx, dy)
                            case None => ()
                        }
                        gestureRuntime.lastX = x
                        gestureRuntime.lastY = y
                        return true
                    } else if (!inside) {
                        ctx.cancelPress(controlId)
                        ctx.cancelInkRipple(controlId)
                    }
                    gestureRuntime.lastX = x
                    gestureRuntime.lastY = y
                }
            case UiEvent.MouseDown(MouseButton.Left, x, y) => if (frame.contains(x, y)) {
                ctx.focus(controlId)
                ctx.press(controlId)
                gestureRuntime.begin(ctx.frame.elapsedMs, x, y)
                ctx.startInkRipple(controlId, frame, x, y, color: Some(material.ink),
                    cornerRadius: surfaceShape.cornerRadius())
                return true
            }
            case UiEvent.MouseUp(MouseButton.Left, x, y) => if (ctx.isPressed(controlId)) {
                let inside = frame.contains(x, y)
                let dragging = ctx.isDragging(controlId)
                ctx.cancelPress(controlId)
                if (dragging) {
                    if (inside || gestureHandlers.capturePointer) {
                        match (gestureHandlers.onDragEnd) {
                            case Some(callback) => callback(x, y)
                            case None => ()
                        }
                    } else {
                        match (gestureHandlers.onDragCancel) { case Some(callback) => callback() case None => () }
                    }
                    ctx.clearDrag()
                } else if (inside && !gestureRuntime.longPressFired) {
                    if (ctx.clickCount == 2 && gestureHandlers.onDoubleTap.isSome()) {
                        match (gestureHandlers.onDoubleTap) { case Some(callback) => callback() case None => () }
                    } else {
                        action()
                    }
                } else if (!inside) {
                    ctx.cancelInkRipple(controlId)
                }
                gestureRuntime.resetPress()
                ctx.releasePointerCapture(controlId)
                return true
            }
            case UiEvent.WindowFocusChanged(false) =>
                let owned = ctx.isPressed(controlId) || ctx.isDragging(controlId) ||
                    ctx.hasPointerCapture(controlId)
                if (owned) {
                    ctx.cancelPress(controlId)
                    ctx.cancelInkRipple(controlId)
                    if (ctx.isDragging(controlId)) {
                        match (gestureHandlers.onDragCancel) {
                            case Some(callback) => callback()
                            case None => ()
                        }
                        ctx.clearDrag()
                    }
                    ctx.releasePointerCapture(controlId)
                    gestureRuntime.resetPress()
                    return true
                }
            case _ => ()
        }
        false
    }

    private func recordNestedInteractionDiagnostic(): Unit {
        if (nestedInteractionOwnerIds.isEmpty()) { return }
        let descendants = joinOwnerIds(nestedInteractionOwnerIds)
        let descendantFocusIds = joinOwnerIds(nestedFocusIds)
        recordProbeStructuralError("nested-interaction-owner",
            "InteractionSurface " + controlId + " contains interaction-owning descendants: " + descendants)
        probeSemanticRegions {=> [
            ProbeSemanticRegion(
                "interaction-diagnostic:" + controlId,
                DrawIrAsciiAnnotationKind.Visual,
                frame,
                widgetType: "InteractionSurfaceDiagnostic",
                properties: [
                    ProbeProperty("diagnostic", "nested-interaction-owner"),
                    ProbeProperty("severity", "error"),
                    ProbeProperty("actionOwner", controlId),
                    ProbeProperty("descendantInteractionOwnerIds", descendants),
                    ProbeProperty("descendantFocusIds", descendantFocusIds)
                ]
            )
        ]}
    }
}

/** Component-style convenience constructor for a gesture-enabled one-owner surface. */
public func GestureSurface(
    action!: () -> Unit,
    gestures!: GestureHandlers = GestureHandlers(),
    role!: ControlRole = ControlRole.Button,
    accessibilityLabel!: String = "",
    key!: ?String = None,
    readOnly!: Bool = false,
    body!: () -> Unit
): InteractionSurface {
    InteractionSurface(action: action, role: role, accessibilityLabel: accessibilityLabel,
        key: key, readOnly: readOnly, body: body).gestures(gestures)
}

private func gestureHasDragCallbacks(value: GestureHandlers): Bool {
    value.onDragStart.isSome() || value.onDragUpdate.isSome() || value.onDragEnd.isSome() ||
        value.onDragCancel.isSome()
}

private func collectNestedFocusIds(child: Widget, registered: Array<String>): Array<String> {
    let result = ArrayList<String>()
    for (id in registered) { addFocusIdIfAbsent(result, id) }
    for (id in child.focusableIds()) { addFocusIdIfAbsent(result, id) }
    result.toArray()
}

private func collectNestedInteractionOwnerIds(child: Widget, nestedFocusIds: Array<String>): Array<String> {
    let result = ArrayList<String>()
    for (id in nestedFocusIds) { addOwnerIdIfAbsent(result, id) }
    for (id in child.interactionOwnerIds()) { addOwnerIdIfAbsent(result, id) }
    result.toArray()
}

private func addFocusIdIfAbsent(values: ArrayList<String>, id: String): Unit {
    if (!values.contains(id)) { values.add(id) }
}

private func addOwnerIdIfAbsent(values: ArrayList<String>, id: String): Unit {
    if (!values.contains(id)) { values.add(id) }
}

private func joinOwnerIds(values: Array<String>): String {
    let out = StringBuilder()
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(value)
    }
    out.toString()
}
