package chui.core

import std.collection.{ArrayList, HashSet}
import sdl.{DrawIrCommand, Rect}

/** Stable public wire identity for editable-design hard-truth exports. */
public const CANGHUI_DESIGN_SNAPSHOT_PROTOCOL: String = "canghui.design-snapshot/v1"
public const DESIGN_SNAPSHOT_HARD_MAX_NODES: Int64 = 4096
public const DESIGN_SNAPSHOT_HARD_MAX_PROPERTIES: Int64 = 16384
public const DESIGN_SNAPSHOT_HARD_MAX_DRAW_COMMANDS: Int64 = 65536
public const DESIGN_SNAPSHOT_HARD_MAX_TEXT_BYTES: Int64 = 4194304

/** Provider-neutral structure layers. These are evidence categories, not editor policy. */
public enum DesignSnapshotNodeKind {
    | Document
    | Page
    | State
    | Screen
    | Region
    | Component
    | Atomic
}

public func designSnapshotNodeKindName(kind: DesignSnapshotNodeKind): String {
    match (kind) {
        case DesignSnapshotNodeKind.Document => "document"
        case DesignSnapshotNodeKind.Page => "page"
        case DesignSnapshotNodeKind.State => "state"
        case DesignSnapshotNodeKind.Screen => "screen"
        case DesignSnapshotNodeKind.Region => "region"
        case DesignSnapshotNodeKind.Component => "component"
        case DesignSnapshotNodeKind.Atomic => "atomic"
    }
}

/** One deterministic computed-style or state fact. Sensitive facts are redacted before storage. */
public struct DesignSnapshotProperty {
    public let key: String
    public let value: String
    public let redacted: Bool

    public init(key: String, value: String, redacted!: Bool = false) {
        validateDesignSnapshotToken(key, "design snapshot property key")
        this.key = key
        this.value = if (redacted || designSnapshotSensitiveKey(key)) { "[redacted]" } else { value }
        this.redacted = redacted || designSnapshotSensitiveKey(key)
    }
}

/** Replay facts intentionally exclude working directories, native handles and process identity. */
public struct DesignSnapshotEnvironment {
    public let platform: String
    public let viewportWidth: Float32
    public let viewportHeight: Float32
    public let scale: Float32
    public let theme: String
    public let locale: String
    public let reducedMotion: Bool

    public init(
        platform: String,
        viewportWidth: Float32,
        viewportHeight: Float32,
        scale!: Float32 = 1.0,
        theme!: String = "system",
        locale!: String = "und",
        reducedMotion!: Bool = false
    ) {
        validateDesignSnapshotToken(platform, "design snapshot platform")
        validateDesignSnapshotToken(theme, "design snapshot theme")
        validateDesignSnapshotToken(locale, "design snapshot locale")
        if (viewportWidth < 0.0 || viewportHeight < 0.0 || scale <= 0.0) {
            throw IllegalArgumentException("design snapshot viewport and scale must be finite positive values")
        }
        this.platform = platform
        this.viewportWidth = viewportWidth
        this.viewportHeight = viewportHeight
        this.scale = scale
        this.theme = theme
        this.locale = locale
        this.reducedMotion = reducedMotion
    }
}

/** One immutable node aligned by stable id across structure, geometry, semantics and Draw IR scope. */
public class DesignSnapshotNode {
    public let id: String
    public let parentId: String
    public let kind: DesignSnapshotNodeKind
    public let order: Int64
    public let frame: Rect
    public let widgetType: String
    public let role: String
    public let label: String
    public let value: String
    public let styles: Array<DesignSnapshotProperty>
    public let states: Array<DesignSnapshotProperty>

    public init(
        id: String,
        kind: DesignSnapshotNodeKind,
        frame: Rect,
        parentId!: String = "",
        order!: Int64 = 0,
        widgetType!: String = "",
        role!: String = "",
        label!: String = "",
        value!: String = "",
        styles!: Array<DesignSnapshotProperty> = [],
        states!: Array<DesignSnapshotProperty> = []
    ) {
        validateDesignSnapshotIdentifier(id, "design snapshot node id")
        if (!parentId.isEmpty()) { validateDesignSnapshotIdentifier(parentId, "design snapshot parent id") }
        if (order < 0) { throw IllegalArgumentException("design snapshot node order cannot be negative") }
        this.id = id
        this.parentId = parentId
        this.kind = kind
        this.order = order
        this.frame = frame
        this.widgetType = widgetType
        this.role = role
        this.label = label
        this.value = if (role == "password") { "" } else { value }
        this.styles = sortedDesignSnapshotProperties(styles)
        this.states = sortedDesignSnapshotProperties(states)
    }
}

/** Layered deterministic diff. Arrays contain stable node ids or global state keys. */
public struct DesignSnapshotDiff {
    public let fromDigest: String
    public let toDigest: String
    public let structure: Array<String>
    public let geometry: Array<String>
    public let style: Array<String>
    public let state: Array<String>
    public let draw: Array<String>

    public init(
        fromDigest: String,
        toDigest: String,
        structure: Array<String>,
        geometry: Array<String>,
        style: Array<String>,
        state: Array<String>,
        draw: Array<String>
    ) {
        this.fromDigest = fromDigest
        this.toDigest = toDigest
        this.structure = structure.clone()
        this.geometry = geometry.clone()
        this.style = style.clone()
        this.state = state.clone()
        this.draw = draw.clone()
    }
}

/**
 * Canonical, bounded hard-truth export for design tools and CI.
 *
 * Draw order is preserved. Nodes and global states are sorted by stable identity so declaration
 * collection order cannot perturb bytes. The digest is a deterministic change detector, not a
 * cryptographic integrity or signing claim.
 */
public class DesignSnapshot {
    public let identifier: String
    public let generator: String
    public let inputDigest: String
    public let environment: DesignSnapshotEnvironment
    public let nodes: Array<DesignSnapshotNode>
    public let states: Array<DesignSnapshotProperty>
    public let drawIr: Array<DrawIrCommand>
    public let contentDigest: String
    private let canonicalContent: String

    public init(
        identifier: String,
        environment: DesignSnapshotEnvironment,
        nodes: Array<DesignSnapshotNode>,
        drawIr!: Array<DrawIrCommand> = [],
        states!: Array<DesignSnapshotProperty> = [],
        inputDigest!: String = "",
        generator!: String = "CangHui/chui"
    ) {
        validateDesignSnapshotIdentifier(identifier, "design snapshot id")
        validateDesignSnapshotToken(generator, "design snapshot generator")
        validateDesignSnapshotInputDigest(inputDigest)
        validateDesignSnapshotCaps(nodes, drawIr, states)
        let ownedNodes = sortedDesignSnapshotNodes(nodes)
        validateDesignSnapshotTree(ownedNodes)
        this.identifier = identifier
        this.generator = generator
        this.inputDigest = inputDigest
        this.environment = environment
        this.nodes = ownedNodes
        this.states = sortedDesignSnapshotProperties(states)
        this.drawIr = drawIr.clone()
        this.canonicalContent = renderDesignSnapshotContent(
            identifier, generator, inputDigest, environment, this.nodes, this.states, this.drawIr)
        if (canonicalContent.toArray().size > DESIGN_SNAPSHOT_HARD_MAX_TEXT_BYTES) {
            throw IllegalArgumentException("design snapshot exceeds the hard text byte limit")
        }
        this.contentDigest = designSnapshotStableDigest(canonicalContent)
    }

    /** Maps an existing per-window semantic snapshot to one screen root plus component nodes. */
    public static func fromSemantics(
        identifier: String,
        environment: DesignSnapshotEnvironment,
        semantics: SemanticTreeSnapshot,
        drawIr!: Array<DrawIrCommand> = [],
        states!: Array<DesignSnapshotProperty> = [],
        inputDigest!: String = "",
        generator!: String = "CangHui/chui"
    ): DesignSnapshot {
        let mapped = ArrayList<DesignSnapshotNode>()
        let screenId = "screen:" + semantics.windowId
        mapped.add(DesignSnapshotNode(
            screenId, DesignSnapshotNodeKind.Screen,
            Rect(0.0, 0.0, environment.viewportWidth, environment.viewportHeight),
            widgetType: "Window", role: "screen"))
        for (node in semantics.nodes) {
            let parent = if (node.parentId.isEmpty()) { screenId } else { node.parentId }
            mapped.add(DesignSnapshotNode(
                node.id, DesignSnapshotNodeKind.Component, node.frame,
                parentId: parent, order: node.order, widgetType: node.widgetType,
                role: node.role, label: node.label, value: node.value,
                states: designSnapshotSemanticStates(node)))
        }
        DesignSnapshot(identifier, environment, mapped.toArray(), drawIr: drawIr, states: states,
            inputDigest: inputDigest, generator: generator)
    }

    public func toJson(): String {
        "{\"protocol\":" + designSnapshotQuote(CANGHUI_DESIGN_SNAPSHOT_PROTOCOL) +
            ",\"contentDigest\":" + designSnapshotQuote(contentDigest) +
            ",\"content\":" + canonicalContent + "}"
    }

    public func diff(previous: DesignSnapshot): DesignSnapshotDiff {
        let structure = ArrayList<String>()
        let geometry = ArrayList<String>()
        let style = ArrayList<String>()
        let state = ArrayList<String>()
        let draw = ArrayList<String>()
        for (current in nodes) {
            match (designSnapshotNode(previous.nodes, current.id)) {
                case Some(before) =>
                    if (!sameDesignSnapshotStructure(before, current)) { structure.add(current.id) }
                    if (!sameDesignSnapshotRect(before.frame, current.frame)) { geometry.add(current.id) }
                    if (!sameDesignSnapshotProperties(before.styles, current.styles)) { style.add(current.id) }
                    if (!sameDesignSnapshotNodeState(before, current)) { state.add(current.id) }
                case None => structure.add(current.id)
            }
        }
        for (before in previous.nodes) {
            if (designSnapshotNode(nodes, before.id).isNone()) { structure.add(before.id) }
        }
        if (!sameDesignSnapshotProperties(previous.states, states)) { state.add("$snapshot") }
        appendChangedDrawScopes(draw, previous.drawIr, drawIr)
        DesignSnapshotDiff(previous.contentDigest, contentDigest,
            sortedUniqueDesignSnapshotStrings(structure.toArray()),
            sortedUniqueDesignSnapshotStrings(geometry.toArray()),
            sortedUniqueDesignSnapshotStrings(style.toArray()),
            sortedUniqueDesignSnapshotStrings(state.toArray()),
            sortedUniqueDesignSnapshotStrings(draw.toArray()))
    }
}

private func designSnapshotSemanticStates(node: SemanticNode): Array<DesignSnapshotProperty> {
    let values = ArrayList<DesignSnapshotProperty>()
    values.add(DesignSnapshotProperty("enabled", node.enabled.toString()))
    values.add(DesignSnapshotProperty("readOnly", node.readOnly.toString()))
    appendOptionalDesignSnapshotBool(values, "selected", node.selected)
    appendOptionalDesignSnapshotBool(values, "expanded", node.expanded)
    appendOptionalDesignSnapshotBool(values, "focused", node.focused)
    appendOptionalDesignSnapshotBool(values, "editable", node.editable)
    appendOptionalDesignSnapshotInt(values, "selectionStart", node.selectionStart)
    appendOptionalDesignSnapshotInt(values, "selectionEnd", node.selectionEnd)
    if (!node.placeholder.isEmpty()) { values.add(DesignSnapshotProperty("placeholder", node.placeholder)) }
    let actions = StringBuilder()
    var first = true
    for (action in node.actions) {
        if (!first) { actions.append(",") }
        first = false
        actions.append(semanticActionName(action))
    }
    if (!first) { values.add(DesignSnapshotProperty("actions", actions.toString())) }
    values.toArray()
}

private func appendOptionalDesignSnapshotBool(values: ArrayList<DesignSnapshotProperty>, key: String,
    value: ?Bool): Unit {
    match (value) { case Some(actual) => values.add(DesignSnapshotProperty(key, actual.toString())) case None => () }
}

private func appendOptionalDesignSnapshotInt(values: ArrayList<DesignSnapshotProperty>, key: String,
    value: ?Int64): Unit {
    match (value) { case Some(actual) => values.add(DesignSnapshotProperty(key, actual.toString())) case None => () }
}

private func renderDesignSnapshotContent(
    identifier: String,
    generator: String,
    inputDigest: String,
    environment: DesignSnapshotEnvironment,
    nodes: Array<DesignSnapshotNode>,
    states: Array<DesignSnapshotProperty>,
    drawIr: Array<DrawIrCommand>
): String {
    let out = StringBuilder()
    out.append("{\"schemaVersion\":1,\"generator\":")
    out.append(designSnapshotQuote(generator))
    out.append(",\"id\":")
    out.append(designSnapshotQuote(identifier))
    out.append(",\"inputDigest\":")
    out.append(designSnapshotQuote(inputDigest))
    out.append(",\"environment\":")
    out.append(renderDesignSnapshotEnvironment(environment))
    out.append(",\"nodes\":[")
    var first = true
    for (node in nodes) {
        if (!first) { out.append(",") }
        first = false
        out.append(renderDesignSnapshotNode(node))
    }
    out.append("],\"states\":")
    out.append(renderDesignSnapshotProperties(states))
    out.append(",\"drawIr\":[")
    first = true
    for (command in drawIr) {
        if (!first) { out.append(",") }
        first = false
        out.append(command.toJson())
    }
    out.append("]}")
    out.toString()
}

private func renderDesignSnapshotEnvironment(value: DesignSnapshotEnvironment): String {
    "{\"platform\":" + designSnapshotQuote(value.platform) +
        ",\"viewportWidth\":" + value.viewportWidth.toString() +
        ",\"viewportHeight\":" + value.viewportHeight.toString() +
        ",\"scale\":" + value.scale.toString() +
        ",\"theme\":" + designSnapshotQuote(value.theme) +
        ",\"locale\":" + designSnapshotQuote(value.locale) +
        ",\"reducedMotion\":" + value.reducedMotion.toString() + "}"
}

private func renderDesignSnapshotNode(node: DesignSnapshotNode): String {
    "{\"id\":" + designSnapshotQuote(node.id) +
        ",\"parentId\":" + designSnapshotQuote(node.parentId) +
        ",\"kind\":" + designSnapshotQuote(designSnapshotNodeKindName(node.kind)) +
        ",\"order\":" + node.order.toString() +
        ",\"frame\":{\"x\":" + node.frame.x.toString() +
        ",\"y\":" + node.frame.y.toString() +
        ",\"width\":" + node.frame.w.toString() +
        ",\"height\":" + node.frame.h.toString() + "}" +
        ",\"widgetType\":" + designSnapshotQuote(node.widgetType) +
        ",\"role\":" + designSnapshotQuote(node.role) +
        ",\"label\":" + designSnapshotQuote(node.label) +
        ",\"value\":" + designSnapshotQuote(node.value) +
        ",\"styles\":" + renderDesignSnapshotProperties(node.styles) +
        ",\"states\":" + renderDesignSnapshotProperties(node.states) + "}"
}

private func renderDesignSnapshotProperties(values: Array<DesignSnapshotProperty>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append("{\"key\":")
        out.append(designSnapshotQuote(value.key))
        out.append(",\"value\":")
        out.append(designSnapshotQuote(value.value))
        out.append(",\"redacted\":")
        out.append(value.redacted.toString())
        out.append("}")
    }
    out.append("]")
    out.toString()
}

private func designSnapshotStableDigest(value: String): String {
    var code: Int64 = 43
    for (byte in value.toArray()) { code = (code * 131 + Int64(byte)) % 2147483647 }
    "chui-hash-v1:" + value.toArray().size.toString() + ":" + max(Int64(1), code).toString()
}

private func validateDesignSnapshotCaps(nodes: Array<DesignSnapshotNode>, drawIr: Array<DrawIrCommand>,
    states: Array<DesignSnapshotProperty>): Unit {
    if (nodes.size > DESIGN_SNAPSHOT_HARD_MAX_NODES) {
        throw IllegalArgumentException("design snapshot exceeds the hard node limit")
    }
    if (drawIr.size > DESIGN_SNAPSHOT_HARD_MAX_DRAW_COMMANDS) {
        throw IllegalArgumentException("design snapshot exceeds the hard Draw IR limit")
    }
    var properties = states.size
    for (node in nodes) { properties += node.styles.size + node.states.size }
    if (properties > DESIGN_SNAPSHOT_HARD_MAX_PROPERTIES) {
        throw IllegalArgumentException("design snapshot exceeds the hard property limit")
    }
}

private func validateDesignSnapshotTree(nodes: Array<DesignSnapshotNode>): Unit {
    let ids = HashSet<String>()
    for (node in nodes) {
        if (ids.contains(node.id)) { throw IllegalArgumentException("duplicate design snapshot node id") }
        ids.add(node.id)
    }
    for (node in nodes) {
        if (!node.parentId.isEmpty() && !ids.contains(node.parentId)) {
            throw IllegalArgumentException("design snapshot parent does not exist: " + node.parentId)
        }
        var parent = node.parentId
        var depth: Int64 = 0
        while (!parent.isEmpty()) {
            depth += 1
            if (depth > 64 || parent == node.id) {
                throw IllegalArgumentException("design snapshot contains a parent cycle")
            }
            parent = match (designSnapshotNode(nodes, parent)) {
                case Some(value) => value.parentId
                case None => ""
            }
        }
    }
}

private func validateDesignSnapshotIdentifier(value: String, role: String): Unit {
    validateDesignSnapshotToken(value, role)
    if (value.startsWith("/") || value.startsWith("./") || value.contains("../") ||
        value.contains("\\")) {
        throw IllegalArgumentException(role + " cannot contain a filesystem path")
    }
}

private func validateDesignSnapshotToken(value: String, role: String): Unit {
    if (value.isEmpty() || value.toArray().size > 4096 || value.contains("\n") || value.contains("\r") ||
        value.contains("\u{0000}")) {
        throw IllegalArgumentException(role + " must be a bounded single-line value")
    }
}

private func validateDesignSnapshotInputDigest(value: String): Unit {
    if (!value.isEmpty()) {
        validateDesignSnapshotToken(value, "design snapshot input digest")
        if (value.contains("/") || value.contains("\\")) {
            throw IllegalArgumentException("design snapshot input digest cannot contain a path")
        }
    }
}

private func designSnapshotSensitiveKey(value: String): Bool {
    let lowered = designSnapshotAsciiLower(value)
    lowered.contains("path") || lowered.contains("handle") || lowered.contains("token") ||
        lowered.contains("secret") || lowered.contains("password") || lowered.contains("credential")
}

private func designSnapshotAsciiLower(value: String): String {
    let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".toRuneArray()
    let lower = "abcdefghijklmnopqrstuvwxyz".toRuneArray()
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        var mapped = r
        var i: Int64 = 0
        while (i < upper.size) {
            if (upper[i] == r) { mapped = lower[i]; break }
            i += 1
        }
        out.append(mapped.toString())
    }
    out.toString()
}

private func designSnapshotQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}

private func sortedDesignSnapshotProperties(values: Array<DesignSnapshotProperty>): Array<DesignSnapshotProperty> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].key > value.key) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    var previous = ""
    for (value in result) {
        if (value.key == previous) { throw IllegalArgumentException("duplicate design snapshot property key") }
        previous = value.key
    }
    result
}

private func sortedDesignSnapshotNodes(values: Array<DesignSnapshotNode>): Array<DesignSnapshotNode> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].id > value.id) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    result
}

private func sortedUniqueDesignSnapshotStrings(values: Array<String>): Array<String> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1] > value) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    let unique = ArrayList<String>()
    for (value in result) { if (unique.isEmpty() || unique[unique.size - 1] != value) { unique.add(value) } }
    unique.toArray()
}

private func designSnapshotNode(values: Array<DesignSnapshotNode>, id: String): ?DesignSnapshotNode {
    for (value in values) { if (value.id == id) { return Some(value) } }
    None
}

private func sameDesignSnapshotRect(first: Rect, second: Rect): Bool {
    first.x == second.x && first.y == second.y && first.w == second.w && first.h == second.h
}

private func sameDesignSnapshotStructure(first: DesignSnapshotNode, second: DesignSnapshotNode): Bool {
    first.parentId == second.parentId && designSnapshotNodeKindName(first.kind) == designSnapshotNodeKindName(second.kind) &&
        first.order == second.order && first.widgetType == second.widgetType && first.role == second.role
}

private func sameDesignSnapshotNodeState(first: DesignSnapshotNode, second: DesignSnapshotNode): Bool {
    first.label == second.label && first.value == second.value &&
        sameDesignSnapshotProperties(first.states, second.states)
}

private func sameDesignSnapshotProperties(first: Array<DesignSnapshotProperty>,
    second: Array<DesignSnapshotProperty>): Bool {
    if (first.size != second.size) { return false }
    for (i in 0..first.size) {
        if (first[i].key != second[i].key || first[i].value != second[i].value ||
            first[i].redacted != second[i].redacted) { return false }
    }
    true
}

private func appendChangedDrawScopes(output: ArrayList<String>, first: Array<DrawIrCommand>,
    second: Array<DrawIrCommand>): Unit {
    let size = max(first.size, second.size)
    for (i in 0..size) {
        if (i >= first.size) { output.add(if (second[i].scope.isEmpty()) { "$root" } else { second[i].scope }) }
        else if (i >= second.size) { output.add(if (first[i].scope.isEmpty()) { "$root" } else { first[i].scope }) }
        else if (first[i].toJson() != second[i].toJson()) {
            let firstScope = if (first[i].scope.isEmpty()) { "$root" } else { first[i].scope }
            let secondScope = if (second[i].scope.isEmpty()) { "$root" } else { second[i].scope }
            output.add(firstScope)
            output.add(secondScope)
        }
    }
}
