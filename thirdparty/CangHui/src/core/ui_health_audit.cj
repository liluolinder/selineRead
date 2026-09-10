package chui.core

import std.collection.{ArrayList, HashSet}
import sdl.Rect

public let CANGHUI_UI_HEALTH_PROTOCOL = "canghui.ui-health/v1"

public enum UiHealthSeverity <: Equatable<UiHealthSeverity> {
    | Info
    | Warning
    | Error

    public operator func ==(other: UiHealthSeverity): Bool {
        uiHealthSeverityName(this) == uiHealthSeverityName(other)
    }
    public operator func !=(other: UiHealthSeverity): Bool { !(this == other) }
}

public func uiHealthSeverityName(value: UiHealthSeverity): String {
    match (value) {
        case UiHealthSeverity.Info => "info"
        case UiHealthSeverity.Warning => "warning"
        case UiHealthSeverity.Error => "error"
    }
}

public struct UiHealthPolicy {
    public let minimumTargetWidth: Float32
    public let minimumTargetHeight: Float32
    public let maximumControlHeight: Float32
    public let failOn: UiHealthSeverity

    public init(
        minimumTargetWidth!: Float32 = 32.0,
        minimumTargetHeight!: Float32 = 32.0,
        maximumControlHeight!: Float32 = 64.0,
        failOn!: UiHealthSeverity = UiHealthSeverity.Warning
    ) {
        if (minimumTargetWidth <= 0.0 || minimumTargetHeight <= 0.0 || maximumControlHeight <= 0.0) {
            throw IllegalArgumentException("UI health geometry thresholds must be positive")
        }
        this.minimumTargetWidth = minimumTargetWidth
        this.minimumTargetHeight = minimumTargetHeight
        this.maximumControlHeight = maximumControlHeight
        this.failOn = failOn
    }
}

/** Stable, source-attributed finding; it never rewrites UI source. */
public struct UiHealthDiagnostic {
    public let code: String
    public let severity: UiHealthSeverity
    public let componentId: String
    public let rect: Rect
    public let evidenceSource: String
    public let message: String
    public let suggestion: String

    public init(code: String, severity: UiHealthSeverity, componentId: String, rect: Rect,
        evidenceSource: String, message: String, suggestion: String) {
        this.code = code
        this.severity = severity
        this.componentId = componentId
        this.rect = rect
        this.evidenceSource = evidenceSource
        this.message = message
        this.suggestion = suggestion
    }

    public func toJson(): String {
        "{\"code\":" + uiHealthQuote(code) +
            ",\"severity\":" + uiHealthQuote(uiHealthSeverityName(severity)) +
            ",\"componentId\":" + uiHealthQuote(componentId) +
            ",\"rect\":{\"x\":" + rect.x.toString() + ",\"y\":" + rect.y.toString() +
            ",\"width\":" + rect.w.toString() + ",\"height\":" + rect.h.toString() + "}" +
            ",\"evidenceSource\":" + uiHealthQuote(evidenceSource) +
            ",\"message\":" + uiHealthQuote(message) +
            ",\"suggestion\":" + uiHealthQuote(suggestion) + "}"
    }
}

public class UiHealthReport {
    public let snapshotDigest: String
    public let diagnostics: Array<UiHealthDiagnostic>
    public let failOn: UiHealthSeverity

    public init(snapshotDigest: String, diagnostics: Array<UiHealthDiagnostic>, failOn: UiHealthSeverity) {
        this.snapshotDigest = snapshotDigest
        this.diagnostics = diagnostics.clone()
        this.failOn = failOn
    }

    public func passed(): Bool {
        for (diagnostic in diagnostics) {
            if (uiHealthSeverityRank(diagnostic.severity) >= uiHealthSeverityRank(failOn)) { return false }
        }
        true
    }

    public func count(severity: UiHealthSeverity): Int64 {
        var total: Int64 = 0
        for (diagnostic in diagnostics) { if (diagnostic.severity == severity) { total += 1 } }
        total
    }

    public func toJson(): String {
        let out = StringBuilder()
        out.append("{\"protocol\":")
        out.append(uiHealthQuote(CANGHUI_UI_HEALTH_PROTOCOL))
        out.append(",\"snapshotDigest\":")
        out.append(uiHealthQuote(snapshotDigest))
        out.append(",\"passed\":")
        out.append(passed())
        out.append(",\"failOn\":")
        out.append(uiHealthQuote(uiHealthSeverityName(failOn)))
        out.append(",\"counts\":{\"info\":")
        out.append(count(UiHealthSeverity.Info))
        out.append(",\"warning\":")
        out.append(count(UiHealthSeverity.Warning))
        out.append(",\"error\":")
        out.append(count(UiHealthSeverity.Error))
        out.append("},\"diagnostics\":[")
        var first = true
        for (diagnostic in diagnostics) {
            if (!first) { out.append(",") }
            first = false
            out.append(diagnostic.toJson())
        }
        out.append("]}")
        out.toString()
    }
}

/** Deterministic semantic/layout/Draw-IR health analysis over one hard-truth snapshot. */
public class UiHealthAudit {
    private init() {}

    public static func analyze(snapshot: DesignSnapshot,
        policy!: UiHealthPolicy = UiHealthPolicy()): UiHealthReport {
        let diagnostics = ArrayList<UiHealthDiagnostic>()
        auditTargets(snapshot.nodes, policy, diagnostics)
        auditContainment(snapshot.nodes, diagnostics)
        auditSiblingOverlap(snapshot.nodes, diagnostics)
        auditDuplicateOwners(snapshot.nodes, diagnostics)
        auditFocusOrder(snapshot.nodes, diagnostics)
        auditAdjacentChrome(snapshot.nodes, diagnostics)
        if (!snapshot.drawIr.isEmpty() && !snapshot.nodes.isEmpty()) {
            diagnostics.add(UiHealthDiagnostic(
                "CHUI-AUDIT-CONTRAST-UNKNOWN", UiHealthSeverity.Info, "$snapshot", Rect.zero(),
                "draw-ir", "Effective contrast cannot be proven without paired foreground and backing colors.",
                "Expose computed foreground/background colors in the component snapshot when contrast is CI-critical."
            ))
        }
        UiHealthReport(snapshot.contentDigest, sortedUiHealthDiagnostics(diagnostics.toArray()), policy.failOn)
    }

    /** Adds stable moved/resized findings between two snapshots without pixel inference. */
    public static func analyzeChange(before: DesignSnapshot, after: DesignSnapshot,
        policy!: UiHealthPolicy = UiHealthPolicy()): UiHealthReport {
        let base = analyze(after, policy: policy)
        let diagnostics = ArrayList<UiHealthDiagnostic>(base.diagnostics)
        let diff = after.diff(before)
        for (id in diff.geometry) {
            let node = findUiHealthNode(after.nodes, id)
            diagnostics.add(UiHealthDiagnostic(
                "CHUI-AUDIT-GEOMETRY-CHANGED", UiHealthSeverity.Info, id,
                match (node) { case Some(value) => value.frame case None => Rect.zero() },
                "design-snapshot-diff", "Component moved or resized between snapshots.",
                "Review keyed layout continuity and the intended adaptive breakpoint."
            ))
        }
        UiHealthReport(after.contentDigest, sortedUiHealthDiagnostics(diagnostics.toArray()), policy.failOn)
    }
}

private func auditTargets(nodes: Array<DesignSnapshotNode>, policy: UiHealthPolicy,
    output: ArrayList<UiHealthDiagnostic>): Unit {
    for (node in nodes) {
        if (!uiHealthInteractive(node)) { continue }
        if (node.frame.w < policy.minimumTargetWidth || node.frame.h < policy.minimumTargetHeight) {
            output.add(UiHealthDiagnostic(
                "CHUI-AUDIT-TARGET-SMALL", UiHealthSeverity.Warning, node.id, node.frame, "semantic+layout",
                "Interactive target is below the configured minimum size.",
                "Use IconButton/Button contentPadding or an explicit minimum frame."
            ))
        }
        if (node.frame.h > policy.maximumControlHeight) {
            output.add(UiHealthDiagnostic(
                "CHUI-AUDIT-TARGET-STRETCHED", UiHealthSeverity.Warning, node.id, node.frame,
                "semantic+layout", "Interactive control is unexpectedly tall.",
                "Keep the control content-sized and apply flex to its container instead."
            ))
        }
        if (node.label.isEmpty() && uiHealthLooksIconOnly(node)) {
            output.add(UiHealthDiagnostic(
                "CHUI-AUDIT-ICON-LABEL-MISSING", UiHealthSeverity.Error, node.id, node.frame, "semantic",
                "Icon-only action has no accessible label.",
                "Set accessibilityLabel on IconButton or InteractionSurface."
            ))
        }
    }
}

private func auditContainment(nodes: Array<DesignSnapshotNode>, output: ArrayList<UiHealthDiagnostic>): Unit {
    for (node in nodes) {
        if (node.parentId.isEmpty()) { continue }
        match (findUiHealthNode(nodes, node.parentId)) {
            case Some(parent) => if (!uiHealthRectContains(parent.frame, node.frame)) {
                let clipped = uiHealthNodeProperty(parent, "clip") == "true" ||
                    uiHealthNodeProperty(parent, "clipPolicy") == "shape"
                output.add(UiHealthDiagnostic(
                    if (clipped) {"CHUI-AUDIT-CLIPPED-DESCENDANT"}
                        else {"CHUI-AUDIT-CONTENT-OUTSIDE-OWNER"},
                    UiHealthSeverity.Warning, node.id, node.frame,
                    "layout", if (clipped) {
                        "Semantic descendant is clipped by its owner's bounds."
                    } else {
                        "Semantic descendant extends outside its owner's bounds."
                    },
                    "Review padding, minimum width and clipping before adding fixed offsets."
                ))
                if (parent.widgetType.contains("Row") || parent.widgetType.contains("Grid")) {
                    output.add(UiHealthDiagnostic(
                        "CHUI-AUDIT-COLLECTION-OVERFLOW", UiHealthSeverity.Warning,
                        parent.id, parent.frame, "semantic+layout",
                        "Row or grid content exceeds its computed owner bounds.",
                        "Use layoutWeight/AdaptiveGrid or reduce fixed cell and gap constraints."
                    ))
                }
            }
            case None => ()
        }
    }
}

private func auditSiblingOverlap(nodes: Array<DesignSnapshotNode>, output: ArrayList<UiHealthDiagnostic>): Unit {
    var i: Int64 = 0
    while (i < nodes.size) {
        var j = i + 1
        while (j < nodes.size) {
            let first = nodes[i]
            let second = nodes[j]
            if (!first.parentId.isEmpty() && first.parentId == second.parentId &&
                uiHealthInteractive(first) && uiHealthInteractive(second) &&
                uiHealthRectsOverlap(first.frame, second.frame)) {
                output.add(UiHealthDiagnostic(
                    "CHUI-AUDIT-SIBLING-OVERLAP", UiHealthSeverity.Error,
                    first.id + "+" + second.id, uiHealthIntersection(first.frame, second.frame),
                    "layout", "Interactive siblings overlap and compete for hit testing.",
                    "Use Row/Grid spacing or one intentional ZStack owner."
                ))
            }
            j += 1
        }
        i += 1
    }
}

private func auditDuplicateOwners(nodes: Array<DesignSnapshotNode>, output: ArrayList<UiHealthDiagnostic>): Unit {
    let owners = HashSet<String>()
    for (node in nodes) {
        let owner = uiHealthNodeProperty(node, "actionOwner")
        if (owner.isEmpty()) { continue }
        if (owners.contains(owner)) {
            output.add(UiHealthDiagnostic(
                "CHUI-AUDIT-DUPLICATE-ACTION-OWNER", UiHealthSeverity.Error, node.id, node.frame,
                "semantic", "Multiple semantic nodes publish the same action owner.",
                "Use one InteractionSurface owner and keep descendants decorative."
            ))
        } else { owners.add(owner) }
    }
}

private func auditFocusOrder(nodes: Array<DesignSnapshotNode>,
    output: ArrayList<UiHealthDiagnostic>): Unit {
    var i: Int64 = 0
    while (i < nodes.size) {
        var j = i + 1
        while (j < nodes.size) {
            let first = nodes[i]
            let second = nodes[j]
            if (!first.parentId.isEmpty() && first.parentId == second.parentId &&
                uiHealthInteractive(first) && uiHealthInteractive(second) &&
                first.order == second.order) {
                output.add(UiHealthDiagnostic(
                    "CHUI-AUDIT-FOCUS-ORDER-AMBIGUOUS", UiHealthSeverity.Warning,
                    first.id + "+" + second.id, uiHealthIntersectionOrUnionEdge(first.frame, second.frame),
                    "semantic", "Interactive siblings publish the same traversal order.",
                    "Keep stable declaration/key order or publish distinct semantic order values."
                ))
            }
            j += 1
        }
        i += 1
    }
}

private func auditAdjacentChrome(nodes: Array<DesignSnapshotNode>, output: ArrayList<UiHealthDiagnostic>): Unit {
    var i: Int64 = 0
    while (i < nodes.size) {
        var j = i + 1
        while (j < nodes.size) {
            let first = nodes[i]
            let second = nodes[j]
            if (first.parentId == second.parentId && uiHealthHasBorder(first) && uiHealthHasBorder(second) &&
                uiHealthSharesExactEdge(first.frame, second.frame)) {
                output.add(UiHealthDiagnostic(
                    "CHUI-AUDIT-ADJACENT-CHROME-SEAM", UiHealthSeverity.Warning,
                    first.id + "+" + second.id, uiHealthIntersectionOrUnionEdge(first.frame, second.frame),
                    "semantic+layout", "Adjacent bordered siblings can paint a doubled seam.",
                    "Move shared chrome to the parent Surface or remove one touching border."
                ))
            }
            j += 1
        }
        i += 1
    }
}

private func uiHealthInteractive(node: DesignSnapshotNode): Bool {
    let role = node.role
    role == "button" || role == "link" || role == "checkbox" || role == "switch" ||
        uiHealthNodeProperty(node, "actions").contains("activate") ||
        !uiHealthNodeProperty(node, "actionOwner").isEmpty()
}

private func uiHealthLooksIconOnly(node: DesignSnapshotNode): Bool {
    node.widgetType.contains("Icon") || !uiHealthNodeProperty(node, "icon").isEmpty()
}

private func uiHealthHasBorder(node: DesignSnapshotNode): Bool {
    let width = uiHealthNodeProperty(node, "borderWidth")
    !width.isEmpty() && width != "0" && width != "0.0"
}

private func uiHealthNodeProperty(node: DesignSnapshotNode, key: String): String {
    let state = uiHealthProperty(node.states, key)
    if (!state.isEmpty()) { return state }
    uiHealthProperty(node.styles, key)
}

private func uiHealthProperty(values: Array<DesignSnapshotProperty>, key: String): String {
    for (value in values) { if (value.key == key) { return value.value } }
    ""
}

private func findUiHealthNode(values: Array<DesignSnapshotNode>, id: String): ?DesignSnapshotNode {
    for (value in values) { if (value.id == id) { return Some(value) } }
    None
}

private func uiHealthRectContains(parent: Rect, child: Rect): Bool {
    child.x >= parent.x && child.y >= parent.y && child.x + child.w <= parent.x + parent.w &&
        child.y + child.h <= parent.y + parent.h
}

private func uiHealthRectsOverlap(first: Rect, second: Rect): Bool {
    min(first.x + first.w, second.x + second.w) > max(first.x, second.x) &&
        min(first.y + first.h, second.y + second.h) > max(first.y, second.y)
}

private func uiHealthIntersection(first: Rect, second: Rect): Rect {
    let x = max(first.x, second.x)
    let y = max(first.y, second.y)
    Rect(x, y, max(0.0, min(first.x + first.w, second.x + second.w) - x),
        max(0.0, min(first.y + first.h, second.y + second.h) - y))
}

private func uiHealthSharesExactEdge(first: Rect, second: Rect): Bool {
    let vertical = (first.x + first.w == second.x || second.x + second.w == first.x) &&
        min(first.y + first.h, second.y + second.h) > max(first.y, second.y)
    let horizontal = (first.y + first.h == second.y || second.y + second.h == first.y) &&
        min(first.x + first.w, second.x + second.w) > max(first.x, second.x)
    vertical || horizontal
}

private func uiHealthIntersectionOrUnionEdge(first: Rect, second: Rect): Rect {
    Rect(min(first.x, second.x), min(first.y, second.y),
        max(first.x + first.w, second.x + second.w) - min(first.x, second.x),
        max(first.y + first.h, second.y + second.h) - min(first.y, second.y))
}

private func sortedUiHealthDiagnostics(values: Array<UiHealthDiagnostic>): Array<UiHealthDiagnostic> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && uiHealthDiagnosticKey(result[j - 1]) > uiHealthDiagnosticKey(value)) {
            result[j] = result[j - 1]
            j -= 1
        }
        result[j] = value
        i += 1
    }
    result
}

private func uiHealthDiagnosticKey(value: UiHealthDiagnostic): String {
    value.code + "|" + value.componentId
}

private func uiHealthSeverityRank(value: UiHealthSeverity): Int64 {
    match (value) {
        case UiHealthSeverity.Info => 1
        case UiHealthSeverity.Warning => 2
        case UiHealthSeverity.Error => 3
    }
}

private func uiHealthQuote(value: String): String {
    let out = StringBuilder(); out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else { out.append(r.toString()) }
    }
    out.append("\""); out.toString()
}
