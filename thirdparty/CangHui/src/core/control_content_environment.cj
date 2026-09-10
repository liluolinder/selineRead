package chui.core

import std.collection.ArrayList
import sdl.{Color, DrawIrAsciiAnnotationKind, Rect}

/** Read-only visual and interaction state inherited by decorative control content. */
public struct ControlContentEnvironment {
    public let foreground: Color
    public let supportingForeground: Color
    public let role: String
    public let interactionOwner: String
    public let selected: Bool
    public let expanded: Bool
    public let focused: Bool
    public let hovered: Bool
    public let pressed: Bool
    public let enabled: Bool
    public let readOnly: Bool

    public init(
        foreground: Color,
        supportingForeground!: ?Color = None,
        role!: String = "",
        interactionOwner!: String = "",
        selected!: Bool = false,
        expanded!: Bool = false,
        focused!: Bool = false,
        hovered!: Bool = false,
        pressed!: Bool = false,
        enabled!: Bool = true,
        readOnly!: Bool = false
    ) {
        this.foreground = foreground
        this.supportingForeground = match (supportingForeground) {
            case Some(value) => value
            case None => foreground.withAlpha(Int64(foreground.a) * 3 / 4)
        }
        this.role = role
        this.interactionOwner = interactionOwner
        this.selected = selected
        this.expanded = expanded
        this.focused = focused
        this.hovered = hovered
        this.pressed = pressed
        this.enabled = enabled
        this.readOnly = readOnly
    }
}

/** One outer semantic action for a compound control and its decorative descendants. */
public struct ControlSemantics {
    public let role: String
    public let label: String
    public let value: String
    public let placeholder: String
    public let action: String
    public let shortcut: String
    public let actionOwner: String
    public let selected: ?Bool
    public let expanded: ?Bool
    public let enabled: ?Bool
    public let readOnly: ?Bool
    public let focused: ?Bool
    public let editable: ?Bool
    public let selectionStart: ?Int64
    public let selectionEnd: ?Int64
    /** Typed actions exposed to in-process semantic consumers. String actions remain probe-only. */
    public let typedActions: Array<SemanticActionKind>

    public init(
        role: String,
        label!: String = "",
        value!: String = "",
        placeholder!: String = "",
        action!: String = "control.activate()",
        shortcut!: String = "Enter|Space",
        actionOwner!: String,
        selected!: ?Bool = None,
        expanded!: ?Bool = None,
        enabled!: ?Bool = None,
        readOnly!: ?Bool = None,
        focused!: ?Bool = None,
        editable!: ?Bool = None,
        selectionStart!: ?Int64 = None,
        selectionEnd!: ?Int64 = None,
        typedActions!: Array<SemanticActionKind> = []
    ) {
        if (role.isEmpty()) { throw IllegalArgumentException("control semantic role must not be empty") }
        if (actionOwner.isEmpty()) { throw IllegalArgumentException("control semantic action owner must not be empty") }
        this.role = role
        this.label = label
        this.value = value
        this.placeholder = placeholder
        this.action = action
        this.shortcut = shortcut
        this.actionOwner = actionOwner
        this.selected = selected
        this.expanded = expanded
        this.enabled = enabled
        this.readOnly = readOnly
        this.focused = focused
        this.editable = editable
        this.selectionStart = selectionStart
        this.selectionEnd = selectionEnd
        // The semantic contract owns this list. A caller retaining its constructor input cannot
        // mutate the actions later and silently alter a committed runtime tree.
        this.typedActions = typedActions.clone()
    }
}

/**
 * Records a control region with the current generic `.enabled(...)` scope. Disabled controls keep
 * role/label/value/state but omit actions and shortcuts.
 */
public func recordControlSemantics(
    ctx: UiContext,
    frame: Rect,
    widgetType: String,
    semantics: ControlSemantics
): Unit {
    // A compound control records its one outer action before drawing decorative slot content.
    // Descendants inside that environment are not independently routed by the outer control and
    // therefore must not leak a second, unreachable semantic action node.
    match (ctx.controlContentEnvironment()) {
        // Only an environment that owns an outer interaction may suppress its decorative slot
        // descendants. A plain Surface also supplies inherited foreground colors, but it must not
        // erase the semantics of an independently interactive child.
        case Some(environment) => if (!environment.interactionOwner.isEmpty()) { return }
        case None => ()
    }
    recordControlSemanticsResolved(frame, widgetType, semantics, ctx.interactionsEnabled(),
        ctx.semanticFocusOrder(semantics.actionOwner))
}

/**
 * Compatibility entry for custom controls that do not yet pass `UiContext`. It assumes the caller is
 * enabled; use the context-aware overload so generic disabled modifiers are reflected automatically.
 */
public func recordControlSemantics(
    frame: Rect,
    widgetType: String,
    semantics: ControlSemantics
): Unit {
    recordControlSemanticsResolved(frame, widgetType, semantics, true, None)
}

private func recordControlSemanticsResolved(
    frame: Rect,
    widgetType: String,
    semantics: ControlSemantics,
    interactionsEnabled: Bool,
    focusOrder: ?Int64
): Unit {
    recordActiveSemanticRuntimeControl(frame, widgetType, semantics, interactionsEnabled, focusOrder)
    if (!shouldRecordAutomaticControlSemantics(semantics.actionOwner)) { return }
    let properties = ArrayList<ProbeProperty>()
    properties.add(ProbeProperty("role", semantics.role))
    if (!semantics.label.isEmpty()) { properties.add(ProbeProperty("label", semantics.label)) }
    // Password values are never exported to either runtime semantics or probe evidence.
    if (semantics.role != "password" && !semantics.value.isEmpty()) {
        properties.add(ProbeProperty("value", semantics.value))
    }
    if (!semantics.placeholder.isEmpty()) { properties.add(ProbeProperty("placeholder", semantics.placeholder)) }
    var semanticallyEnabled = interactionsEnabled
    match (semantics.enabled) {
        case Some(value) => semanticallyEnabled = semanticallyEnabled && value
        case None => ()
    }
    if (semanticallyEnabled) {
        if (!semantics.action.isEmpty()) { properties.add(ProbeProperty("action", semantics.action)) }
        if (!semantics.shortcut.isEmpty()) { properties.add(ProbeProperty("shortcut", semantics.shortcut)) }
        match (semantics.enabled) {
            case Some(_) => properties.add(ProbeProperty("enabled", "true"))
            case None => ()
        }
    } else {
        properties.add(ProbeProperty("disabled", "true"))
        properties.add(ProbeProperty("enabled", "false"))
    }
    properties.add(ProbeProperty("actionOwner", semantics.actionOwner))
    properties.add(ProbeProperty("semanticDescendants", "decorative"))
    match (semantics.selected) {
        case Some(value) => properties.add(ProbeProperty("selected", value.toString()))
        case None => ()
    }
    match (semantics.expanded) {
        case Some(value) => properties.add(ProbeProperty("expanded", value.toString()))
        case None => ()
    }
    match (semantics.readOnly) {
        case Some(value) => properties.add(ProbeProperty("readonly", value.toString()))
        case None => ()
    }
    match (semantics.focused) {
        case Some(value) => properties.add(ProbeProperty("focused", value.toString()))
        case None => ()
    }
    match (semantics.editable) {
        case Some(value) => properties.add(ProbeProperty("editable", value.toString()))
        case None => ()
    }
    match (semantics.selectionStart) {
        case Some(value) => properties.add(ProbeProperty("selectionStart", value.toString()))
        case None => ()
    }
    match (semantics.selectionEnd) {
        case Some(value) => properties.add(ProbeProperty("selectionEnd", value.toString()))
        case None => ()
    }
    probeSemanticRegions {=> [
        ProbeSemanticRegion(
            "control-semantic:" + semantics.actionOwner,
            DrawIrAsciiAnnotationKind.Interactive,
            frame,
            widgetType: widgetType,
            properties: properties.toArray()
        )
    ]}
}
