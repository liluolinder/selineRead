package chui.core

import std.collection.{ArrayList, HashMap}
import std.convert.*
import sdl.{DrawIrAsciiAnnotation, DrawIrAsciiAnnotationKind, DrawIrAsciiOptions, DrawIrCommand, FrameInfo,
    Key, MouseButton, Rect, Renderer, Size, UiEvent, drawIrAsciiAnnotationKindName, renderDrawIrAscii}
import chui.probe.{CUI_PROBE_PROTOCOL, probeJsonQuote}

/** A stable public property emitted by a probe-enabled widget. */
public struct ProbeProperty {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        if (name.isEmpty()) { throw IllegalArgumentException("probe property name must not be empty") }
        this.name = name
        this.value = value
    }
}

/** One semantic subregion inside a custom-drawn widget. */
public struct ProbeSemanticRegion {
    public let id: String
    public let kind: DrawIrAsciiAnnotationKind
    public let rect: Rect
    public let widgetType: String
    public let properties: Array<ProbeProperty>

    public init(
        id: String,
        kind: DrawIrAsciiAnnotationKind,
        rect: Rect,
        widgetType!: String = "Region",
        properties!: Array<ProbeProperty> = []
    ) {
        requireProbeNodeId(id)
        this.id = id
        this.kind = kind
        this.rect = rect
        this.widgetType = if (widgetType.isEmpty()) {"Region"} else {widgetType}
        this.properties = properties
    }
}

public type ProbeSemanticRegionProvider = () -> Array<ProbeSemanticRegion>

public type ProbeSemanticProvider = () -> Array<ProbeProperty>

private var activeComponentProbeSession: ?ComponentProbeSession = None

/** Wraps one declarative subtree in an addressable instrumentation node. */
public class ProbeNode <: Widget {
    private let id: String
    private let widgetType: String
    private let properties: Array<ProbeProperty>
    private let semantics: ?ProbeSemanticProvider
    private let child: Widget
    private var frame = Rect.zero()

    public init(
        id: String,
        widgetType!: String = "Widget",
        properties!: Array<ProbeProperty> = [],
        semantics!: ?ProbeSemanticProvider = None,
        body!: () -> Unit
    ) {
        requireProbeNodeId(id)
        this.id = id
        this.widgetType = if (widgetType.isEmpty()) { "Widget" } else { widgetType }
        this.properties = properties
        this.semantics = semantics
        declareActiveProbeNode(id, this.widgetType)
        pushActiveProbeParent(id)
        try {
            this.child = buildChild(body)
        } finally {
            popActiveProbeParent()
        }
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
        updateActiveProbeNode(id, widgetType, frame, child.focusableId(), child.interactionsEnabled(),
            properties, semantics, ctx)
    }

    public func draw(ctx: UiContext): Unit {
        enterActiveProbeNode(id)
        ctx.renderer.pushDrawIrScope(id)
        try {
            updateActiveProbeNode(id, widgetType, frame, child.focusableId(), child.interactionsEnabled(),
                properties, semantics, ctx)
            child.draw(ctx)
        } finally {
            ctx.renderer.popDrawIrScope()
            leaveActiveProbeNode()
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        enterProbeEventRoute(id)
        let consumed = child.handle(ctx, event)
        leaveProbeEventRoute(id, consumed)
        consumed
    }

    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}

class ProbedWidget <: Widget {
    private let child: Widget
    private let id: String
    private let widgetType: String
    private let properties: Array<ProbeProperty>
    private let semantics: ?ProbeSemanticProvider
    private var frame = Rect.zero()

    init(
        child: Widget,
        id: String,
        widgetType: String,
        properties: Array<ProbeProperty>,
        semantics: ?ProbeSemanticProvider
    ) {
        requireProbeNodeId(id)
        this.child = child
        this.id = id
        this.widgetType = if (widgetType.isEmpty()) { "Widget" } else { widgetType }
        this.properties = properties
        this.semantics = semantics
        declareActiveProbeNode(id, this.widgetType)
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
        updateActiveProbeNode(id, widgetType, frame, child.focusableId(), child.interactionsEnabled(),
            properties, semantics, ctx)
    }

    public func draw(ctx: UiContext): Unit {
        enterActiveProbeNode(id)
        ctx.renderer.pushDrawIrScope(id)
        try {
            updateActiveProbeNode(id, widgetType, frame, child.focusableId(), child.interactionsEnabled(),
                properties, semantics, ctx)
            child.draw(ctx)
        } finally {
            ctx.renderer.popDrawIrScope()
            leaveActiveProbeNode()
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        enterProbeEventRoute(id)
        let consumed = child.handle(ctx, event)
        leaveProbeEventRoute(id, consumed)
        consumed
    }

    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}

protected func applyProbeModifier(
    widget: Widget,
    id: String,
    widgetType: String,
    properties: Array<ProbeProperty>,
    semantics: ?ProbeSemanticProvider
): Widget {
    let replacement = ProbedWidget(widget, id, widgetType, properties, semantics)
    replaceLastEmission(widget, replacement)
    replacement
}

/** Records one bounded callback activation in the currently running component probe. */
public func probeActivation(name: String): Unit {
    if (name.isEmpty()) { throw IllegalArgumentException("probe activation name must not be empty") }
    match (activeComponentProbeSession) {
        case Some(session) => session.activate(name)
        case None => ()
    }
}

/** Wraps a normal action so component probes can prove callback activation without changing behavior. */
public func probedAction(name: String, action: () -> Unit): () -> Unit {
    { =>
        probeActivation(name)
        action()
    }
}

/** Adds one stable structural error to the active component probe, if any. */
protected func recordProbeStructuralError(code: String, message: String): Unit {
    match (activeComponentProbeSession) {
        case Some(session) => session.failUnique("structural-" + code, message)
        case None => ()
    }
}

/** Records semantic subcontrols only while a component probe is active. */
public func probeSemanticRegions(provider: ProbeSemanticRegionProvider): Unit {
    match (activeComponentProbeSession) {
        case Some(session) => session.recordRegions(provider())
        case None => ()
    }
}

/** Lets stock-control semantics yield to an explicit probe for the same action owner. */
protected func shouldRecordAutomaticControlSemantics(actionOwner: String): Bool {
    match (activeComponentProbeSession) {
        case Some(session) => !session.currentDrawNodeOwns(actionOwner)
        case None => false
    }
}

/**
 * Deterministic device-free component runner. Scripts use one command per line:
 * `move-in x y`, `press x y`, `move-out x y`, `release x y`, `key Enter`,
 * `focus id`, `text value`, `advance ms`, `draw`, and `assert ...`.
 */
public class ComponentProbe {
    public let name: String
    public let width: Float32
    public let height: Float32
    public let theme: Theme

    public init(
        name: String,
        width!: Float32 = 640.0,
        height!: Float32 = 360.0,
        theme!: Theme = Theme.light()
    ) {
        if (name.isEmpty()) { throw IllegalArgumentException("component probe name must not be empty") }
        if (width <= 0.0 || height <= 0.0) {
            throw IllegalArgumentException("component probe viewport must be positive")
        }
        this.name = name
        this.width = width
        this.height = height
        this.theme = theme
    }

    public func run(script: String, body: () -> Unit): String {
        let output = parseProbeOutput(script)
        let renderer = Renderer.recordingHeadless()
        let ctx = UiContext(renderer, theme)
        ctx.viewportWidth = width
        ctx.viewportHeight = height
        let store = StateStore()
        let session = ComponentProbeSession(name, width, height)
        let previous = activeComponentProbeSession
        activeComponentProbeSession = Some(session)
        try {
            var elapsed: UInt64 = 0
            var widget = renderProbeFrame(session, renderer, ctx, store, elapsed, UInt64(0), body)
            for (rawLine in output.script.split("\n")) {
                let line = trimProbeText(rawLine)
                if (line.isEmpty() || line.startsWith("#")) { continue }
                if (line.startsWith("assert ")) {
                    session.assertLine(line)
                    continue
                }
                let parts = splitProbeWords(line)
                if (parts.isEmpty()) { continue }
                let command = parts[0]
                var delta: UInt64 = 0
                session.beginEvent(line)
                if (command == "move" || command == "move-in" || command == "move-out" || command == "hover") {
                    requireProbeArity(parts, 3, command)
                    let x = Float32.parse(parts[1])
                    let y = Float32.parse(parts[2])
                    ctx.mouseX = x
                    ctx.mouseY = y
                    ctx.beginHoverTest()
                    let consumed = widget.handle(ctx, UiEvent.MouseMove(x, y))
                    ctx.settleHover()
                    session.finishEvent(consumed)
                } else if (command == "press") {
                    requireProbeArity(parts, 3, command)
                    let x = Float32.parse(parts[1])
                    let y = Float32.parse(parts[2])
                    ctx.mouseX = x
                    ctx.mouseY = y
                    ctx.leftMouseDown = true
                    ctx.recordPress(x, y)
                    ctx.beginPointerPress()
                    let consumed = widget.handle(ctx, UiEvent.MouseDown(MouseButton.Left, x, y))
                    ctx.settleFocusAfterPress()
                    session.finishEvent(consumed)
                } else if (command == "release") {
                    requireProbeArity(parts, 3, command)
                    let x = Float32.parse(parts[1])
                    let y = Float32.parse(parts[2])
                    ctx.mouseX = x
                    ctx.mouseY = y
                    let consumed = widget.handle(ctx, UiEvent.MouseUp(MouseButton.Left, x, y))
                    ctx.leftMouseDown = false
                    ctx.clearDrag()
                    ctx.clearPress()
                    session.finishEvent(consumed)
                } else if (command == "key") {
                    requireProbeArity(parts, 2, command)
                    let key = parseProbeKey(parts[1])
                    let consumed = match (key) {
                        case Key.Tab =>
                            ctx.focusNext()
                            true
                        case _ => widget.handle(ctx, UiEvent.KeyDown(key, false))
                    }
                    session.finishEvent(consumed)
                } else if (command == "focus") {
                    requireProbeArity(parts, 2, command)
                    ctx.focus(parts[1], viaKeyboard: true)
                    session.finishEvent(true)
                } else if (command == "text") {
                    if (parts.size < 2) { throw IllegalArgumentException("text requires a value") }
                    let value = substringAfterProbeWord(line)
                    session.finishEvent(widget.handle(ctx, UiEvent.TextInput(value)))
                } else if (command == "advance") {
                    requireProbeArity(parts, 2, command)
                    delta = UInt64.parse(parts[1])
                    elapsed += delta
                    ctx.frame = FrameInfo(elapsed, delta)
                    session.finishEvent(widget.handle(ctx, UiEvent.Frame(ctx.frame)))
                } else if (command == "draw") {
                    session.finishEvent(false)
                } else {
                    session.finishEvent(false)
                    throw IllegalArgumentException("unknown component probe command: " + command)
                }
                widget = renderProbeFrame(session, renderer, ctx, store, elapsed, delta, body)
            }
            session.report(output)
        } catch (error: Exception) {
            session.fail("runner-error", error.message)
            session.report(output)
        } finally {
            activeComponentProbeSession = previous
        }
    }
}

private class ProbeNodeSnapshot {
    let id: String
    let widgetType: String
    let parent: String
    let order: Int64
    var frame = Rect.zero()
    var focusId: String = ""
    var focused = false
    var hovered = false
    var pressed = false
    var properties = Array<ProbeProperty>()

    init(id: String, widgetType: String, parent: String, order: Int64) {
        this.id = id
        this.widgetType = widgetType
        this.parent = parent
        this.order = order
    }

    func property(name: String): ?String {
        for (property in properties) {
            if (property.name == name) { return Some(property.value) }
        }
        None
    }

    func state(name: String): Bool {
        if (name == "focused" || name == "focus") { return focused }
        if (name == "hovered" || name == "hover") { return hovered }
        if (name == "pressed" || name == "press") { return pressed }
        match (property(name)) {
            case Some(value) => value == "true"
            case None => false
        }
    }

    func toJson(): String {
        let out = StringBuilder()
        out.append("{\"id\":")
        out.append(probeJsonQuote(id))
        out.append(",\"type\":")
        out.append(probeJsonQuote(widgetType))
        out.append(",\"parent\":")
        out.append(probeJsonQuote(parent))
        out.append(",\"order\":")
        out.append(order)
        out.append(",\"rect\":{\"x\":")
        out.append(frame.x)
        out.append(",\"y\":")
        out.append(frame.y)
        out.append(",\"width\":")
        out.append(frame.w)
        out.append(",\"height\":")
        out.append(frame.h)
        out.append("},\"state\":{\"focused\":")
        out.append(focused)
        out.append(",\"hovered\":")
        out.append(hovered)
        out.append(",\"pressed\":")
        out.append(pressed)
        out.append("},\"properties\":{")
        var first = true
        for (property in sortedProbeProperties(properties)) {
            if (!first) { out.append(",") }
            first = false
            out.append(probeJsonQuote(property.name))
            out.append(":")
            out.append(probeJsonQuote(property.value))
        }
        out.append("}}")
        out.toString()
    }

    func toAsciiAnnotation(): ?DrawIrAsciiAnnotation {
        match (probeNodeAnnotationKind(widgetType, properties)) {
            case Some(kind) => Some(DrawIrAsciiAnnotation(
                id,
                kind,
                frame,
                component: widgetType,
                role: probePropertyValue(properties, "role"),
                label: firstProbeProperty(properties, ["label", "title"]),
                icon: probePropertyValue(properties, "icon"),
                action: probePropertyValue(properties, "action"),
                shortcut: probePropertyValue(properties, "shortcut"),
                value: probePropertyValue(properties, "value"),
                state: probeStateText(properties, focused, hovered, pressed)
            ))
            case None => None
        }
    }
}

private class ProbeSemanticRegionSnapshot {
    let id: String
    let parent: String
    let order: Int64
    let kind: DrawIrAsciiAnnotationKind
    let rect: Rect
    let widgetType: String
    let properties: Array<ProbeProperty>

    init(region: ProbeSemanticRegion, parent: String, order: Int64) {
        this.id = region.id
        this.parent = parent
        this.order = order
        this.kind = region.kind
        this.rect = region.rect
        this.widgetType = region.widgetType
        this.properties = sortedProbeProperties(region.properties)
    }

    func toJson(): String {
        let out = StringBuilder()
        out.append("{\"id\":")
        out.append(probeJsonQuote(id))
        out.append(",\"type\":")
        out.append(probeJsonQuote(widgetType))
        out.append(",\"parent\":")
        out.append(probeJsonQuote(parent))
        out.append(",\"order\":")
        out.append(order)
        out.append(",\"kind\":")
        out.append(probeJsonQuote(drawIrAsciiAnnotationKindName(kind)))
        out.append(",\"rect\":{\"x\":")
        out.append(rect.x)
        out.append(",\"y\":")
        out.append(rect.y)
        out.append(",\"width\":")
        out.append(rect.w)
        out.append(",\"height\":")
        out.append(rect.h)
        out.append("},\"properties\":{")
        var first = true
        for (property in properties) {
            if (!first) { out.append(",") }
            first = false
            out.append(probeJsonQuote(property.name))
            out.append(":")
            out.append(probeJsonQuote(property.value))
        }
        out.append("}}")
        out.toString()
    }

    func toAsciiAnnotation(): DrawIrAsciiAnnotation {
        DrawIrAsciiAnnotation(
            id,
            kind,
            rect,
            component: widgetType,
            role: probePropertyValue(properties, "role"),
            label: firstProbeProperty(properties, ["label", "title"]),
            icon: probePropertyValue(properties, "icon"),
            action: probePropertyValue(properties, "action"),
            shortcut: probePropertyValue(properties, "shortcut"),
            value: probePropertyValue(properties, "value"),
            state: probeStateText(properties, false, false, false)
        )
    }
}

private class ProbeRouteEntry {
    let id: String
    var consumed = false

    init(id: String) { this.id = id }

    func toJson(): String {
        "{\"id\":" + probeJsonQuote(id) + ",\"consumed\":" + consumed.toString() + "}"
    }
}

private class ProbeEventRecord {
    let step: Int64
    let command: String
    let route = ArrayList<ProbeRouteEntry>()
    let activations = ArrayList<String>()
    var consumed = false

    init(step: Int64, command: String) {
        this.step = step
        this.command = command
    }

    func toJson(): String {
        let out = StringBuilder()
        out.append("{\"step\":")
        out.append(step)
        out.append(",\"command\":")
        out.append(probeJsonQuote(command))
        out.append(",\"consumed\":")
        out.append(consumed)
        out.append(",\"route\":[")
        var first = true
        for (entry in route) {
            if (!first) { out.append(",") }
            first = false
            out.append(entry.toJson())
        }
        out.append("],\"activations\":[")
        first = true
        for (name in activations) {
            if (!first) { out.append(",") }
            first = false
            out.append(probeJsonQuote(name))
        }
        out.append("]}")
        out.toString()
    }
}

private class ProbeAnimationSample {
    let id: String
    let node: String
    let kind: String
    let level: String
    let durationMs: UInt64
    let curve: String
    let logicalTimeMs: UInt64
    let progress: Float32
    let target: Float32

    init(id: String, node: String, kind: String, level: String, durationMs: UInt64, curve: String,
        logicalTimeMs: UInt64, progress: Float32, target: Float32) {
        this.id = id
        this.node = node
        this.kind = kind
        this.level = level
        this.durationMs = durationMs
        this.curve = curve
        this.logicalTimeMs = logicalTimeMs
        this.progress = progress
        this.target = target
    }

    func toJson(): String {
        "{\"id\":" + probeJsonQuote(id) + ",\"node\":" + probeJsonQuote(node) +
            ",\"kind\":" + probeJsonQuote(kind) + ",\"level\":" + probeJsonQuote(level) +
            ",\"durationMs\":" + durationMs.toString() + ",\"curve\":" + probeJsonQuote(curve) +
            ",\"logicalTimeMs\":" + logicalTimeMs.toString() + ",\"progress\":" + progress.toString() +
            ",\"target\":" + target.toString() + "}"
    }
}

private class ProbeAssertionResult {
    let expression: String
    let ok: Bool
    let message: String

    init(expression: String, ok: Bool, message: String) {
        this.expression = expression
        this.ok = ok
        this.message = message
    }

    func toJson(): String {
        "{\"expression\":" + probeJsonQuote(expression) + ",\"ok\":" + ok.toString() +
            ",\"message\":" + probeJsonQuote(message) + "}"
    }
}

private class ComponentProbeSession {
    let name: String
    let width: Float32
    let height: Float32
    private let nodes = ArrayList<ProbeNodeSnapshot>()
    private let regions = ArrayList<ProbeSemanticRegionSnapshot>()
    private let parentStack = ArrayList<String>()
    private let drawNodeStack = ArrayList<String>()
    private let childCounts = HashMap<String, Int64>()
    private let animationCounts = HashMap<String, Int64>()
    private let animations = ArrayList<ProbeAnimationSample>()
    private let events = ArrayList<ProbeEventRecord>()
    private let assertions = ArrayList<ProbeAssertionResult>()
    private let failures = ArrayList<String>()
    private var latestDrawIr = Array<DrawIrCommand>()
    private let frames = ArrayList<String>()
    private var currentEvent: ?ProbeEventRecord = None
    private var logicalTimeMs: UInt64 = 0
    private var frameIndex: Int64 = 0

    init(name: String, width: Float32, height: Float32) {
        this.name = name
        this.width = width
        this.height = height
    }

    func beginBuild(): Unit {
        nodes.clear()
        parentStack.clear()
        childCounts.clear()
    }

    func declare(id: String, widgetType: String): Unit {
        if (findNode(id).isSome()) {
            throw IllegalStateException("duplicate component probe node id: " + id)
        }
        let parent = if (parentStack.isEmpty()) { "" } else { parentStack[parentStack.size - 1] }
        let count = match (childCounts.get(parent)) { case Some(value) => value case None => 0 }
        let _ = childCounts.add(parent, count + 1)
        nodes.add(ProbeNodeSnapshot(id, widgetType, parent, count))
    }

    func pushParent(id: String): Unit { parentStack.add(id) }
    func popParent(): Unit { if (!parentStack.isEmpty()) { parentStack.remove(at: parentStack.size - 1) } }

    func updateNode(id: String, widgetType: String, frame: Rect, focusId: ?String,
        subtreeInteractionsEnabled: Bool, base: Array<ProbeProperty>, semantics: ?ProbeSemanticProvider,
        ctx: UiContext): Unit {
        let node = match (findNode(id)) {
            case Some(value) => value
            case None =>
                declare(id, widgetType)
                findNode(id).getOrThrow()
        }
        node.frame = frame
        node.focusId = match (focusId) { case Some(value) => value case None => id }
        node.focused = ctx.hasFocus(node.focusId)
        node.hovered = ctx.isHovered(node.focusId) || ctx.isHovered(id)
        node.pressed = ctx.isPressed(node.focusId) || ctx.isPressed(id)
        let merged = ArrayList<ProbeProperty>()
        for (property in base) { putProbeProperty(merged, property) }
        match (semantics) {
            case Some(provider) => for (property in provider()) { putProbeProperty(merged, property) }
            case None => ()
        }
        if (!(ctx.interactionsEnabled() && subtreeInteractionsEnabled)) {
            removeProbeProperty(merged, "action")
            removeProbeProperty(merged, "shortcut")
            putProbeProperty(merged, ProbeProperty("disabled", "true"))
            putProbeProperty(merged, ProbeProperty("enabled", "false"))
        }
        node.properties = sortedProbeProperties(merged.toArray())
    }

    func enterNode(id: String): Unit { drawNodeStack.add(id) }
    func leaveNode(): Unit { if (!drawNodeStack.isEmpty()) { drawNodeStack.remove(at: drawNodeStack.size - 1) } }

    func currentDrawNodeOwns(actionOwner: String): Bool {
        if (drawNodeStack.isEmpty()) { return false }
        let id = drawNodeStack[drawNodeStack.size - 1]
        match (findNode(id)) {
            case Some(node) => node.id == actionOwner || node.focusId == actionOwner
            case None => false
        }
    }

    func beginDraw(timeMs: UInt64): Unit {
        logicalTimeMs = timeMs
        animations.clear()
        animationCounts.clear()
        drawNodeStack.clear()
        regions.clear()
    }

    func recordRegions(values: Array<ProbeSemanticRegion>): Unit {
        let parent = if (drawNodeStack.isEmpty()) {""} else {drawNodeStack[drawNodeStack.size - 1]}
        for (value in values) {
            if (findNode(value.id).isSome() || findRegion(value.id).isSome()) {
                throw IllegalStateException("duplicate component probe semantic region id: " + value.id)
            }
            regions.add(ProbeSemanticRegionSnapshot(value, parent, regions.size))
        }
    }

    func recordAnimation(kind: String, level: String, durationMs: UInt64, curve: String,
        progress: Float32, target: Float32): Unit {
        let node = if (drawNodeStack.isEmpty()) { "" } else { drawNodeStack[drawNodeStack.size - 1] }
        let key = node + "|" + kind
        let count = match (animationCounts.get(key)) { case Some(value) => value case None => 0 }
        let _ = animationCounts.add(key, count + 1)
        let id = (if (node.isEmpty()) { "root" } else { node }) + "/" + kind + "/" + (count + 1).toString()
        animations.add(ProbeAnimationSample(id, node, kind, level, durationMs, curve,
            logicalTimeMs, progress, target))
    }

    func captureFrame(commands: Array<DrawIrCommand>): Unit {
        latestDrawIr = commands
        let out = StringBuilder()
        out.append("{\"index\":")
        out.append(frameIndex)
        out.append(",\"logicalTimeMs\":")
        out.append(logicalTimeMs)
        out.append(",\"nodes\":[")
        var first = true
        for (node in nodes) {
            if (!first) { out.append(",") }
            first = false
            out.append(node.toJson())
        }
        out.append("],\"regions\":[")
        first = true
        for (region in regions) {
            if (!first) { out.append(",") }
            first = false
            out.append(region.toJson())
        }
        out.append("],\"animations\":[")
        first = true
        for (animation in animations) {
            if (!first) { out.append(",") }
            first = false
            out.append(animation.toJson())
        }
        out.append("],\"drawIr\":[")
        first = true
        for (command in commands) {
            if (!first) { out.append(",") }
            first = false
            out.append(command.toJson())
        }
        out.append("]}")
        frames.add(out.toString())
        frameIndex += 1
    }

    func beginEvent(command: String): Unit {
        let event = ProbeEventRecord(events.size, command)
        events.add(event)
        currentEvent = Some(event)
    }

    func enterRoute(id: String): Unit {
        match (currentEvent) {
            case Some(event) => event.route.add(ProbeRouteEntry(id))
            case None => ()
        }
    }

    func leaveRoute(id: String, consumed: Bool): Unit {
        match (currentEvent) {
            case Some(event) =>
                var i = event.route.size - 1
                while (i >= 0) {
                    if (event.route[i].id == id) {
                        event.route[i].consumed = consumed
                        break
                    }
                    i -= 1
                }
            case None => ()
        }
    }

    func activate(name: String): Unit {
        match (currentEvent) {
            case Some(event) => event.activations.add(name)
            case None => ()
        }
    }

    func finishEvent(consumed: Bool): Unit {
        match (currentEvent) {
            case Some(event) => event.consumed = consumed
            case None => ()
        }
        currentEvent = None
    }

    func assertLine(line: String): Unit {
        try {
            let parts = splitProbeWords(line)
            if (parts.size < 2) { throw IllegalArgumentException("assert requires a subject") }
            let subject = parts[1]
            if (subject == "node") {
                requireProbeArity(parts, 3, "assert node")
                addAssertion(line, findNode(parts[2]).isSome(), "node " + parts[2])
            } else if (subject == "state") {
                requireProbeArity(parts, 5, "assert state")
                let node = requireNode(parts[2])
                let expected = Bool.parse(parts[4])
                let actual = node.state(parts[3])
                addAssertion(line, actual == expected, "state " + parts[3] + " was " + actual.toString())
            } else if (subject == "property") {
                if (parts.size < 5) { throw IllegalArgumentException("assert property requires id key value") }
                let node = requireNode(parts[2])
                let expected = joinProbeWords(parts, 4)
                let actual = match (node.property(parts[3])) { case Some(value) => value case None => "" }
                addAssertion(line, actual == expected, "property " + parts[3] + " was " + actual)
            } else if (subject == "activation") {
                requireProbeArity(parts, 4, "assert activation")
                let actual = activationCount(parts[2])
                let expected = Int64.parse(parts[3])
                addAssertion(line, actual == expected, "activation count was " + actual.toString())
            } else if (subject == "draw") {
                requireProbeArity(parts, 4, "assert draw")
                let actual = latestDrawCount(parts[2])
                let minimum = Int64.parse(parts[3])
                addAssertion(line, actual >= minimum, "draw count was " + actual.toString())
            } else if (subject == "animation") {
                if (parts.size != 5 && parts.size != 7) {
                    throw IllegalArgumentException("assert animation requires node kind active|between min max")
                }
                let samples = matchingAnimations(parts[2], parts[3])
                if (parts[4] == "active") {
                    addAssertion(line, !samples.isEmpty(), "animation samples " + samples.size.toString())
                } else if (parts[4] == "between" && parts.size == 7) {
                    let minimum = Float32.parse(parts[5])
                    let maximum = Float32.parse(parts[6])
                    var ok = false
                    for (sample in samples) {
                        if (sample.progress >= minimum && sample.progress <= maximum) { ok = true }
                    }
                    addAssertion(line, ok, "no animation progress in requested range")
                } else {
                    throw IllegalArgumentException("unknown animation assertion")
                }
            } else if (subject == "event") {
                requireProbeArity(parts, 5, "assert event")
                if (parts[3] != "consumed") { throw IllegalArgumentException("event assertion supports consumed") }
                let event = latestEvent(parts[2])
                let expected = Bool.parse(parts[4])
                let actual = match (event) { case Some(value) => value.consumed case None => false }
                addAssertion(line, actual == expected, "event consumed was " + actual.toString())
            } else {
                throw IllegalArgumentException("unknown assertion subject: " + subject)
            }
        } catch (error: Exception) {
            addAssertion(line, false, error.message)
        }
    }

    func fail(kind: String, message: String): Unit {
        failures.add(kind + ": " + message)
    }

    func failUnique(kind: String, message: String): Unit {
        let value = kind + ": " + message
        if (!failures.contains(value)) { failures.add(value) }
    }

    func reportJson(): String {
        let ok = failures.isEmpty() && assertionsAllPass()
        let out = StringBuilder()
        out.append("{\"protocol\":")
        out.append(probeJsonQuote(CUI_PROBE_PROTOCOL))
        out.append(",\"probe\":")
        out.append(probeJsonQuote(name))
        out.append(",\"ok\":")
        out.append(ok)
        out.append(",\"viewport\":{\"width\":")
        out.append(width)
        out.append(",\"height\":")
        out.append(height)
        out.append("},\"frames\":[")
        var first = true
        for (frame in frames) {
            if (!first) { out.append(",") }
            first = false
            out.append(frame)
        }
        out.append("],\"events\":[")
        first = true
        for (event in events) {
            if (!first) { out.append(",") }
            first = false
            out.append(event.toJson())
        }
        out.append("],\"assertions\":[")
        first = true
        for (assertion in assertions) {
            if (!first) { out.append(",") }
            first = false
            out.append(assertion.toJson())
        }
        out.append("],\"errors\":[")
        first = true
        for (failure in failures) {
            if (!first) { out.append(",") }
            first = false
            out.append(probeJsonQuote(failure))
        }
        out.append("]}")
        out.toString()
    }

    func report(output: ProbeOutputRequest): String {
        if (output.designSnapshot) { return makeDesignSnapshot(output.script).toJson() }
        if (output.uiAudit) {
            let severity = if (output.auditThreshold == "error") {UiHealthSeverity.Error}
                else if (output.auditThreshold == "info") {UiHealthSeverity.Info}
                else {UiHealthSeverity.Warning}
            return UiHealthAudit.analyze(makeDesignSnapshot(output.script),
                policy: UiHealthPolicy(failOn: severity)).toJson()
        }
        if (!output.ascii) { return reportJson() }
        if (!failures.isEmpty() || !assertionsAllPass()) {
            return "CUI_PROBE_ASCII_ERROR: component probe failed; rerun with --json for details\n" + reportJson()
        }
        renderDrawIrAscii(latestDrawIr, width, height,
            options: DrawIrAsciiOptions(columns: output.columns, rows: output.rows),
            annotations: asciiAnnotations())
    }

    private func makeDesignSnapshot(script: String): DesignSnapshot {
        let snapshotNodes = ArrayList<DesignSnapshotNode>()
        let screenId = "screen:" + name
        snapshotNodes.add(DesignSnapshotNode(
            screenId, DesignSnapshotNodeKind.Screen, Rect(0.0, 0.0, width, height),
            widgetType: "ComponentProbe", role: "screen", label: name))
        for (node in nodes) {
            snapshotNodes.add(DesignSnapshotNode(
                node.id, DesignSnapshotNodeKind.Component, node.frame,
                parentId: if (node.parent.isEmpty()) { screenId } else { node.parent },
                order: node.order, widgetType: node.widgetType,
                role: probePropertyValue(node.properties, "role"),
                label: firstProbeProperty(node.properties, ["label", "title"]),
                value: probePropertyValue(node.properties, "value"),
                states: probeDesignSnapshotProperties(node.properties, node.focused, node.hovered, node.pressed)))
        }
        for (region in regions) {
            snapshotNodes.add(DesignSnapshotNode(
                region.id, DesignSnapshotNodeKind.Region, region.rect,
                parentId: if (region.parent.isEmpty()) { screenId } else { region.parent },
                order: region.order, widgetType: region.widgetType,
                role: probePropertyValue(region.properties, "role"),
                label: firstProbeProperty(region.properties, ["label", "title"]),
                value: probePropertyValue(region.properties, "value"),
                states: probeDesignSnapshotProperties(region.properties, false, false, false)))
        }
        let globalStates = [
            DesignSnapshotProperty("probe.ok", (failures.isEmpty() && assertionsAllPass()).toString()),
            DesignSnapshotProperty("probe.logicalTimeMs", logicalTimeMs.toString()),
            DesignSnapshotProperty("probe.frames", frames.size.toString()),
            DesignSnapshotProperty("probe.animations", animations.size.toString())
        ]
        DesignSnapshot(
            name,
            DesignSnapshotEnvironment("headless", width, height, theme: "probe", locale: "und"),
            snapshotNodes.toArray(), drawIr: latestDrawIr, states: globalStates,
            inputDigest: probeScriptDigest(script), generator: "CangHui/ComponentProbe")
    }

    private func asciiAnnotations(): Array<DrawIrAsciiAnnotation> {
        let result = ArrayList<DrawIrAsciiAnnotation>()
        for (region in regions) { result.add(region.toAsciiAnnotation()) }
        for (node in nodes) {
            match (node.toAsciiAnnotation()) {
                case Some(annotation) => result.add(annotation)
                case None => ()
            }
        }
        result.toArray()
    }

    private func findNode(id: String): ?ProbeNodeSnapshot {
        for (node in nodes) { if (node.id == id) { return Some(node) } }
        None
    }

    private func findRegion(id: String): ?ProbeSemanticRegionSnapshot {
        for (region in regions) { if (region.id == id) { return Some(region) } }
        None
    }

    private func requireNode(id: String): ProbeNodeSnapshot {
        match (findNode(id)) {
            case Some(node) => node
            case None => throw IllegalArgumentException("unknown probe node: " + id)
        }
    }

    private func addAssertion(expression: String, ok: Bool, message: String): Unit {
        assertions.add(ProbeAssertionResult(expression, ok, message))
    }

    private func activationCount(name: String): Int64 {
        var count: Int64 = 0
        for (event in events) { for (activation in event.activations) { if (activation == name) { count += 1 } } }
        count
    }

    private func latestDrawCount(kind: String): Int64 {
        if (frames.isEmpty()) { return 0 }
        countProbeText(frames[frames.size - 1], "\"kind\":\"" + kind + "\"")
    }

    private func matchingAnimations(node: String, kind: String): Array<ProbeAnimationSample> {
        let result = ArrayList<ProbeAnimationSample>()
        for (sample in animations) {
            if (sample.node == node && sample.kind == kind) { result.add(sample) }
        }
        result.toArray()
    }

    private func latestEvent(command: String): ?ProbeEventRecord {
        var i = events.size - 1
        while (i >= 0) {
            if (events[i].command.startsWith(command)) { return Some(events[i]) }
            i -= 1
        }
        None
    }

    private func assertionsAllPass(): Bool {
        for (assertion in assertions) { if (!assertion.ok) { return false } }
        true
    }
}

private class ProbeOutputRequest {
    let ascii: Bool
    let designSnapshot: Bool
    let uiAudit: Bool
    let auditThreshold: String
    let columns: Int64
    let rows: Int64
    let script: String

    init(ascii: Bool, designSnapshot: Bool, uiAudit: Bool, auditThreshold: String,
        columns: Int64, rows: Int64, script: String) {
        this.ascii = ascii
        this.designSnapshot = designSnapshot
        this.uiAudit = uiAudit
        this.auditThreshold = auditThreshold
        this.columns = columns
        this.rows = rows
        this.script = script
    }
}

private func parseProbeOutput(script: String): ProbeOutputRequest {
    let lines = script.split("\n")
    if (lines.isEmpty()) { return ProbeOutputRequest(false, false, false, "warning", 96, 32, script) }
    let first = trimProbeText(lines[0])
    if (first == "@cui-design-snapshot") {
        return ProbeOutputRequest(false, true, false, "warning", 96, 32, remainingProbeScript(lines))
    }
    if (first.startsWith("@cui-ui-audit ")) {
        let parts = splitProbeWords(first)
        requireProbeArity(parts, 2, "@cui-ui-audit")
        if (parts[1] != "info" && parts[1] != "warning" && parts[1] != "error") {
            throw IllegalArgumentException("UI audit threshold must be info, warning, or error")
        }
        return ProbeOutputRequest(false, false, true, parts[1], 96, 32, remainingProbeScript(lines))
    }
    if (!first.startsWith("@cui-ascii ")) {
        return ProbeOutputRequest(false, false, false, "warning", 96, 32, script)
    }
    let parts = splitProbeWords(first)
    requireProbeArity(parts, 3, "@cui-ascii")
    let columns = Int64.parse(parts[1])
    let rows = Int64.parse(parts[2])
    ProbeOutputRequest(true, false, false, "warning", columns, rows, remainingProbeScript(lines))
}

private func remainingProbeScript(lines: Array<String>): String {
    let remaining = StringBuilder()
    var i: Int64 = 1
    while (i < lines.size) {
        if (i > 1) { remaining.append("\n") }
        remaining.append(lines[i])
        i += 1
    }
    remaining.toString()
}

private func probeDesignSnapshotProperties(properties: Array<ProbeProperty>, focused: Bool,
    hovered: Bool, pressed: Bool): Array<DesignSnapshotProperty> {
    let values = ArrayList<DesignSnapshotProperty>()
    values.add(DesignSnapshotProperty("focused", focused.toString()))
    values.add(DesignSnapshotProperty("hovered", hovered.toString()))
    values.add(DesignSnapshotProperty("pressed", pressed.toString()))
    for (property in properties) {
        if (property.name != "role" && property.name != "label" && property.name != "title" &&
            property.name != "value") {
            values.add(DesignSnapshotProperty(property.name, property.value))
        }
    }
    values.toArray()
}

private func probeScriptDigest(value: String): String {
    var code: Int64 = 47
    for (byte in value.toArray()) { code = (code * 131 + Int64(byte)) % 2147483647 }
    "probe-script:" + value.toArray().size.toString() + ":" + max(Int64(1), code).toString()
}

private func renderProbeFrame(session: ComponentProbeSession, renderer: Renderer, ctx: UiContext,
    store: StateStore, elapsed: UInt64, delta: UInt64, body: () -> Unit): Widget {
    ctx.frame = FrameInfo(elapsed, delta)
    session.beginBuild()
    let widget = buildRoot(body, store)
    ctx.adoptFocusRing(store.focusRing())
    widget.layout(ctx, Rect(0.0, 0.0, session.width, session.height))
    let _ = widget.handle(ctx, UiEvent.Frame(ctx.frame))
    renderer.clearDrawIr()
    session.beginDraw(elapsed)
    ctx.syncThemeResources()
    renderer.beginScene(session.width, session.height, ctx.theme.bg)
    widget.draw(ctx)
    ctx.drawInkRipples()
    ctx.drawActiveOverlay()
    renderer.endScene()
    session.captureFrame(renderer.drawIr())
    widget
}

protected func recordProbeAnimation(ctx: UiContext, kind: String, durationMs: UInt64, curve: String,
    progress: Float32, target: Float32): Unit {
    match (activeComponentProbeSession) {
        case Some(session) => session.recordAnimation(kind, motionLevelName(ctx.theme.motionLevel), durationMs,
            curve, progress, target)
        case None => ()
    }
}

private func declareActiveProbeNode(id: String, widgetType: String): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.declare(id, widgetType) case None => () }
}

private func pushActiveProbeParent(id: String): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.pushParent(id) case None => () }
}

private func popActiveProbeParent(): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.popParent() case None => () }
}

private func updateActiveProbeNode(id: String, widgetType: String, frame: Rect, focusId: ?String,
    subtreeInteractionsEnabled: Bool, properties: Array<ProbeProperty>, semantics: ?ProbeSemanticProvider,
    ctx: UiContext): Unit {
    match (activeComponentProbeSession) {
        case Some(session) => session.updateNode(id, widgetType, frame, focusId, subtreeInteractionsEnabled,
            properties, semantics, ctx)
        case None => ()
    }
}

private func enterActiveProbeNode(id: String): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.enterNode(id) case None => () }
}

private func leaveActiveProbeNode(): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.leaveNode() case None => () }
}

private func enterProbeEventRoute(id: String): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.enterRoute(id) case None => () }
}

private func leaveProbeEventRoute(id: String, consumed: Bool): Unit {
    match (activeComponentProbeSession) { case Some(session) => session.leaveRoute(id, consumed) case None => () }
}

private func requireProbeNodeId(id: String): Unit {
    if (id.isEmpty()) { throw IllegalArgumentException("component probe node id must not be empty") }
    for (r in id.toRuneArray()) {
        if (r == r'\n' || r == r'\r' || r == r'\t') {
            throw IllegalArgumentException("component probe node id must be one line")
        }
    }
}

private func probeNodeAnnotationKind(widgetType: String,
    properties: Array<ProbeProperty>): ?DrawIrAsciiAnnotationKind {
    let explicit = probePropertyValue(properties, "semanticKind")
    if (explicit == "interactive" || explicit == "action") {
        return Some(DrawIrAsciiAnnotationKind.Interactive)
    }
    if (explicit == "focus" || explicit == "input") {
        return Some(DrawIrAsciiAnnotationKind.Focus)
    }
    if (explicit == "visual" || explicit == "region") {
        return Some(DrawIrAsciiAnnotationKind.Visual)
    }
    if (explicit == "none" || explicit == "hidden") { return None }

    let role = probePropertyValue(properties, "role")
    if (focusProbeWidget(widgetType) || role == "textbox" || role == "searchbox") {
        return Some(DrawIrAsciiAnnotationKind.Focus)
    }
    if (!probePropertyValue(properties, "action").isEmpty() ||
        !probePropertyValue(properties, "shortcut").isEmpty() ||
        interactiveProbeWidget(widgetType) || interactiveProbeRole(role)) {
        return Some(DrawIrAsciiAnnotationKind.Interactive)
    }
    if (!firstProbeProperty(properties, ["label", "title", "icon", "value", "role"]).isEmpty()) {
        return Some(DrawIrAsciiAnnotationKind.Visual)
    }
    None
}

private func interactiveProbeWidget(value: String): Bool {
    value == "Button" || value == "IconButton" || value == "Checkbox" || value == "Switch" ||
        value == "Slider" || value == "Stepper" || value == "Picker" || value == "Rating" ||
        value == "Breadcrumb" || value == "Pagination" || value == "Dropdown" || value == "Link" ||
        value == "MenuItem" || value == "Tab" || value == "TreeItem"
}

private func focusProbeWidget(value: String): Bool {
    value == "TextField" || value == "TextArea" || value == "SearchField" || value == "Input" ||
        value == "Editor"
}

private func interactiveProbeRole(value: String): Bool {
    value == "button" || value == "link" || value == "checkbox" || value == "switch" ||
        value == "slider" || value == "menuitem" || value == "tab" || value == "option"
}

private func probePropertyValue(properties: Array<ProbeProperty>, name: String): String {
    for (property in properties) { if (property.name == name) { return property.value } }
    ""
}

private func firstProbeProperty(properties: Array<ProbeProperty>, names: Array<String>): String {
    for (name in names) {
        let value = probePropertyValue(properties, name)
        if (!value.isEmpty()) { return value }
    }
    ""
}

private func probeStateText(properties: Array<ProbeProperty>, focused: Bool, hovered: Bool,
    pressed: Bool): String {
    let explicit = probePropertyValue(properties, "state")
    if (!explicit.isEmpty()) { return explicit }
    let values = ArrayList<String>()
    if (focused) { values.add("focused") }
    if (hovered) { values.add("hovered") }
    if (pressed) { values.add("pressed") }
    for (name in ["disabled", "enabled", "selected", "checked", "expanded", "playing", "muted", "open", "bound"]) {
        let value = probePropertyValue(properties, name)
        if (!value.isEmpty()) { values.add(name + "=" + value) }
    }
    if (values.isEmpty()) { return "idle" }
    let out = StringBuilder()
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(value)
    }
    out.toString()
}

private func putProbeProperty(target: ArrayList<ProbeProperty>, property: ProbeProperty): Unit {
    var i = target.size - 1
    while (i >= 0) {
        if (target[i].name == property.name) { target.remove(at: i) }
        i -= 1
    }
    target.add(property)
}

private func removeProbeProperty(target: ArrayList<ProbeProperty>, name: String): Unit {
    var i = target.size - 1
    while (i >= 0) {
        if (target[i].name == name) { target.remove(at: i) }
        i -= 1
    }
}

private func sortedProbeProperties(values: Array<ProbeProperty>): Array<ProbeProperty> {
    let sorted = Array<ProbeProperty>(values.size, {i => values[i]})
    var i: Int64 = 0
    while (i < sorted.size) {
        var j = i + 1
        while (j < sorted.size) {
            if (sorted[j].name < sorted[i].name) {
                let current = sorted[i]
                sorted[i] = sorted[j]
                sorted[j] = current
            }
            j += 1
        }
        i += 1
    }
    sorted
}

private func splitProbeWords(value: String): Array<String> {
    let result = ArrayList<String>()
    for (part in value.split(" ")) {
        let trimmed = trimProbeText(part)
        if (!trimmed.isEmpty()) { result.add(trimmed) }
    }
    result.toArray()
}

private func trimProbeText(value: String): String {
    let runes = value.toRuneArray()
    var start: Int64 = 0
    var end = runes.size
    while (start < end && (runes[start] == r' ' || runes[start] == r'\t' || runes[start] == r'\r')) { start += 1 }
    while (end > start && (runes[end - 1] == r' ' || runes[end - 1] == r'\t' || runes[end - 1] == r'\r')) { end -= 1 }
    let out = StringBuilder()
    var i = start
    while (i < end) { out.append(runes[i].toString()); i += 1 }
    out.toString()
}

private func requireProbeArity(parts: Array<String>, expected: Int64, command: String): Unit {
    if (parts.size != expected) {
        throw IllegalArgumentException(command + " expects " + (expected - 1).toString() + " argument(s)")
    }
}

private func parseProbeKey(value: String): Key {
    match (value) {
        case "Escape" => Key.Escape
        case "Backspace" => Key.Backspace
        case "Enter" => Key.Enter
        case "Tab" => Key.Tab
        case "Delete" => Key.Delete
        case "Space" => Key.Space
        case "Home" => Key.Home
        case "End" => Key.End
        case "Left" => Key.Left
        case "Right" => Key.Right
        case "Up" => Key.Up
        case "Down" => Key.Down
        case _ =>
            let bytes = value.toArray()
            if (bytes.size == 1 && ((bytes[0] >= UInt8(65) && bytes[0] <= UInt8(90)) ||
                (bytes[0] >= UInt8(97) && bytes[0] <= UInt8(122)))) {
                Key.Letter(bytes[0])
            } else if (bytes.size == 1 && bytes[0] >= UInt8(48) && bytes[0] <= UInt8(57)) {
                Key.Digit(bytes[0])
            } else {
                throw IllegalArgumentException("unknown probe key: " + value)
            }
    }
}

private func substringAfterProbeWord(line: String): String {
    let runes = line.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size && runes[i] != r' ') { i += 1 }
    while (i < runes.size && runes[i] == r' ') { i += 1 }
    let out = StringBuilder()
    while (i < runes.size) { out.append(runes[i].toString()); i += 1 }
    out.toString()
}

private func joinProbeWords(parts: Array<String>, start: Int64): String {
    let out = StringBuilder()
    var i = start
    while (i < parts.size) {
        if (i > start) { out.append(" ") }
        out.append(parts[i])
        i += 1
    }
    out.toString()
}

private func countProbeText(value: String, needle: String): Int64 {
    if (needle.isEmpty()) { return 0 }
    var count: Int64 = 0
    var start: Int64 = 0
    let source = value.toRuneArray()
    let target = needle.toRuneArray()
    while (start + target.size <= source.size) {
        var matchValue = true
        var i: Int64 = 0
        while (i < target.size) {
            if (source[start + i] != target[i]) { matchValue = false; break }
            i += 1
        }
        if (matchValue) { count += 1; start += target.size } else { start += 1 }
    }
    count
}
