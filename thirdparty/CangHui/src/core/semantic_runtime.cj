package chui.core

import std.collection.{ArrayList, HashMap, HashSet}
import sdl.{Rect, Size, UiEvent}

public const SEMANTIC_RUNTIME_HARD_MAX_NODES: Int64 = 4096
public const SEMANTIC_RUNTIME_HARD_MAX_DEPTH: Int64 = 64
public const SEMANTIC_RUNTIME_HARD_MAX_TEXT_BYTES: Int64 = 1048576

/** Per-window observation limits, always clamped by compile-time hard caps. */
public struct SemanticRuntimeLimits {
    public let maxNodes: Int64
    public let maxDepth: Int64
    /** Total UTF-8 bytes accepted across IDs and visible text in one committed frame. */
    public let maxTextBytes: Int64

    public init(
        maxNodes!: Int64 = 2048,
        maxDepth!: Int64 = 32,
        maxTextBytes!: Int64 = 262144
    ) {
        if (maxNodes <= 0 || maxNodes > SEMANTIC_RUNTIME_HARD_MAX_NODES) {
            throw IllegalArgumentException("semantic maxNodes must be in 1..${SEMANTIC_RUNTIME_HARD_MAX_NODES}")
        }
        if (maxDepth <= 0 || maxDepth > SEMANTIC_RUNTIME_HARD_MAX_DEPTH) {
            throw IllegalArgumentException("semantic maxDepth must be in 1..${SEMANTIC_RUNTIME_HARD_MAX_DEPTH}")
        }
        if (maxTextBytes <= 0 || maxTextBytes > SEMANTIC_RUNTIME_HARD_MAX_TEXT_BYTES) {
            throw IllegalArgumentException(
                "semantic maxTextBytes must be in 1..${SEMANTIC_RUNTIME_HARD_MAX_TEXT_BYTES}")
        }
        this.maxNodes = maxNodes
        this.maxDepth = maxDepth
        this.maxTextBytes = maxTextBytes
    }
}

/** A release-safe semantic operation. No coordinate, key, command, or transport operation exists here. */
public enum SemanticActionKind {
    | Activate
    | Focus
    | Increment
    | Decrement
    | Dismiss
}

public func semanticActionName(action: SemanticActionKind): String {
    match (action) {
        case SemanticActionKind.Activate => "activate"
        case SemanticActionKind.Focus => "focus"
        case SemanticActionKind.Increment => "increment"
        case SemanticActionKind.Decrement => "decrement"
        case SemanticActionKind.Dismiss => "dismiss"
    }
}

/** Identifies the in-process feature requesting a typed action. */
public enum SemanticActionSource {
    | Accessibility
    | Keyboard
    | Gamepad
    | Voice
    | Agent
}

public func semanticActionSourceName(source: SemanticActionSource): String {
    match (source) {
        case SemanticActionSource.Accessibility => "accessibility"
        case SemanticActionSource.Keyboard => "keyboard"
        case SemanticActionSource.Gamepad => "gamepad"
        case SemanticActionSource.Voice => "voice"
        case SemanticActionSource.Agent => "agent"
    }
}

/** Voice and agent action dispatch are opt-in. This type does not create an IPC or network surface. */
public struct SemanticInteractionPolicy {
    public let accessibility: Bool
    public let keyboard: Bool
    public let gamepad: Bool
    public let voice: Bool
    public let agent: Bool

    public init(
        accessibility!: Bool = true,
        keyboard!: Bool = true,
        gamepad!: Bool = true,
        voice!: Bool = false,
        agent!: Bool = false
    ) {
        this.accessibility = accessibility
        this.keyboard = keyboard
        this.gamepad = gamepad
        this.voice = voice
        this.agent = agent
    }

    public func allows(source: SemanticActionSource): Bool {
        match (source) {
            case SemanticActionSource.Accessibility => accessibility
            case SemanticActionSource.Keyboard => keyboard
            case SemanticActionSource.Gamepad => gamepad
            case SemanticActionSource.Voice => voice
            case SemanticActionSource.Agent => agent
        }
    }
}

public struct SemanticActionRequest {
    public let windowId: String
    public let expectedRevision: UInt64
    public let nodeId: String
    public let action: SemanticActionKind
    public let source: SemanticActionSource

    public init(
        windowId: String,
        expectedRevision: UInt64,
        nodeId: String,
        action: SemanticActionKind,
        source: SemanticActionSource
    ) {
        validateSemanticIdentifier(windowId, "semantic action window id")
        validateSemanticIdentifier(nodeId, "semantic action node id")
        this.windowId = windowId
        this.expectedRevision = expectedRevision
        this.nodeId = nodeId
        this.action = action
        this.source = source
    }
}

public struct SemanticActionReceipt {
    public let ok: Bool
    public let code: String
    public let windowId: String
    public let revision: UInt64
    public let nodeId: String
    public let action: SemanticActionKind
    public let source: SemanticActionSource
    public let detail: String

    public init(
        ok: Bool,
        code: String,
        windowId: String,
        revision: UInt64,
        nodeId: String,
        action: SemanticActionKind,
        source: SemanticActionSource,
        detail!: String = ""
    ) {
        this.ok = ok
        this.code = code
        this.windowId = windowId
        this.revision = revision
        this.nodeId = nodeId
        this.action = action
        this.source = source
        this.detail = detail
    }
}

public struct SemanticNode {
    public let id: String
    public let parentId: String
    public let order: Int64
    public let frame: Rect
    public let widgetType: String
    public let role: String
    public let label: String
    /** Password values are always redacted to an empty string before entering the tree. */
    public let value: String
    public let placeholder: String
    public let selected: ?Bool
    public let expanded: ?Bool
    public let enabled: Bool
    public let readOnly: Bool
    public let focused: ?Bool
    public let editable: ?Bool
    public let selectionStart: ?Int64
    public let selectionEnd: ?Int64
    public let actions: Array<SemanticActionKind>

    public init(
        id: String,
        frame: Rect,
        widgetType: String,
        role: String,
        parentId!: String = "",
        order!: Int64 = 0,
        label!: String = "",
        value!: String = "",
        placeholder!: String = "",
        selected!: ?Bool = None,
        expanded!: ?Bool = None,
        enabled!: Bool = true,
        readOnly!: Bool = false,
        focused!: ?Bool = None,
        editable!: ?Bool = None,
        selectionStart!: ?Int64 = None,
        selectionEnd!: ?Int64 = None,
        actions!: Array<SemanticActionKind> = []
    ) {
        validateSemanticIdentifier(id, "semantic node id")
        if (!parentId.isEmpty()) { validateSemanticIdentifier(parentId, "semantic parent id") }
        validateSemanticNodeText(id)
        validateSemanticNodeText(parentId)
        validateSemanticNodeText(widgetType)
        validateSemanticNodeText(role)
        validateSemanticNodeText(label)
        validateSemanticNodeText(value)
        validateSemanticNodeText(placeholder)
        this.id = id
        this.parentId = parentId
        this.order = order
        this.frame = frame
        this.widgetType = widgetType
        this.role = role
        this.label = label
        this.value = if (role == "password") { "" } else { value }
        this.placeholder = placeholder
        this.selected = selected
        this.expanded = expanded
        this.enabled = enabled
        this.readOnly = readOnly
        this.focused = focused
        this.editable = editable
        this.selectionStart = selectionStart
        this.selectionEnd = selectionEnd
        this.actions = if (enabled && !readOnly) { actions.clone() } else { [] }
    }
}

public struct SemanticTreeSnapshot {
    public let windowId: String
    public let revision: UInt64
    public let nodes: Array<SemanticNode>

    public init(windowId: String, revision: UInt64, nodes: Array<SemanticNode>) {
        validateSemanticIdentifier(windowId, "semantic snapshot window id")
        if (nodes.size > SEMANTIC_RUNTIME_HARD_MAX_NODES) {
            throw IllegalArgumentException("semantic snapshot exceeds the hard node limit")
        }
        let ids = HashSet<String>()
        for (node in nodes) {
            if (ids.contains(node.id)) {
                throw IllegalArgumentException("semantic snapshot contains a duplicate node id")
            }
            ids.add(node.id)
        }
        this.windowId = windowId
        this.revision = revision
        let owned = ArrayList<SemanticNode>()
        for (node in nodes) { owned.add(cloneSemanticNode(node)) }
        this.nodes = owned.toArray()
    }

    public func node(id: String): ?SemanticNode {
        for (candidate in nodes) {
            if (candidate.id == id) { return Some(candidate) }
        }
        None
    }
}

/** A deterministic ID-level diff suitable for accessibility refresh and non-visual inspection. */
public struct SemanticTreeDiff {
    public let windowId: String
    public let fromRevision: UInt64
    public let toRevision: UInt64
    public let added: Array<String>
    public let removed: Array<String>
    public let changed: Array<String>

    public init(
        windowId: String,
        fromRevision: UInt64,
        toRevision: UInt64,
        added: Array<String>,
        removed: Array<String>,
        changed: Array<String>
    ) {
        this.windowId = windowId
        this.fromRevision = fromRevision
        this.toRevision = toRevision
        this.added = added.clone()
        this.removed = removed.clone()
        this.changed = changed.clone()
    }
}

public type SemanticActionHandler = (SemanticActionRequest) -> Bool

/**
 * Per-window, in-process semantic tree and typed-action dispatcher.
 *
 * It deliberately owns no socket, file, process attach, command parser, coordinate injection, or
 * string-evaluated action. Every request is bound to an exact window and committed revision.
 */
public class SemanticRuntime {
    public let windowId: String
    private var revisionValue: UInt64 = UInt64(0)
    private var committed: Array<SemanticNode> = []
    private let pending = ArrayList<SemanticNode>()
    private let pendingFocusOrders = HashMap<String, Int64>()
    private let parentStack = ArrayList<String>()
    private var collecting: Bool = false
    private var pendingTextBytes: Int64 = 0
    private let policy: SemanticInteractionPolicy
    private let limits: SemanticRuntimeLimits
    private let handler: SemanticActionHandler

    public init(
        windowId: String,
        policy!: SemanticInteractionPolicy = SemanticInteractionPolicy(),
        limits!: SemanticRuntimeLimits = SemanticRuntimeLimits(),
        handler!: SemanticActionHandler = {_ => false}
    ) {
        validateSemanticIdentifier(windowId, "semantic runtime window id")
        this.windowId = windowId
        this.policy = policy
        this.limits = limits
        this.handler = handler
    }

    public prop revision: UInt64 {
        get() { revisionValue }
    }

    public func beginFrame(): Unit {
        if (collecting) { throw IllegalStateException("semantic frame is already collecting") }
        pending.clear()
        pendingFocusOrders.clear()
        parentStack.clear()
        pendingTextBytes = 0
        collecting = true
    }

    public func pushParent(id: String): Unit {
        if (!collecting) { throw IllegalStateException("semantic parent requires an active frame") }
        validateSemanticIdentifier(id, "semantic parent id")
        if (parentStack.size >= limits.maxDepth) {
            throw IllegalStateException("semantic tree depth limit exceeded")
        }
        validateSemanticNodeText(id)
        parentStack.add(id)
    }

    public func popParent(): Unit {
        if (parentStack.isEmpty()) { throw IllegalStateException("semantic parent stack is empty") }
        parentStack.remove(at: parentStack.size - 1)
    }

    public func record(
        frame: Rect,
        widgetType: String,
        semantics: ControlSemantics,
        interactionsEnabled!: Bool = true,
        focusOrder!: ?Int64 = None
    ): Unit {
        if (!collecting) { return }
        validateSemanticIdentifier(semantics.actionOwner, "semantic action owner")
        if (pending.size >= limits.maxNodes) {
            throw IllegalStateException("semantic node limit exceeded")
        }
        for (existing in pending) {
            if (existing.id == semantics.actionOwner) {
                throw IllegalStateException("duplicate semantic node id '${semantics.actionOwner}'")
            }
        }
        var enabled = interactionsEnabled
        match (semantics.enabled) {
            case Some(value) => enabled = enabled && value
            case None => ()
        }
        let readOnly = match (semantics.readOnly) {
            case Some(value) => value
            case None => false
        }
        let parentId = if (parentStack.isEmpty()) { "" } else { parentStack[parentStack.size - 1] }
        let textBytes = semanticControlTextBytes(widgetType, parentId, semantics)
        if (textBytes > limits.maxTextBytes - pendingTextBytes) {
            throw IllegalStateException("semantic text byte limit exceeded")
        }
        let actions = inferSemanticActions(semantics)
        pending.add(SemanticNode(
            semantics.actionOwner,
            frame,
            widgetType,
            semantics.role,
            parentId: parentId,
            order: Int64(pending.size),
            label: semantics.label,
            value: semantics.value,
            placeholder: semantics.placeholder,
            selected: semantics.selected,
            expanded: semantics.expanded,
            enabled: enabled,
            readOnly: readOnly,
            focused: semantics.focused,
            editable: semantics.editable,
            selectionStart: semantics.selectionStart,
            selectionEnd: semantics.selectionEnd,
            actions: actions
        ))
        match (focusOrder) {
            case Some(value) => let _ = pendingFocusOrders.add(semantics.actionOwner, value)
            case None => ()
        }
        pendingTextBytes += textBytes
    }

    public func commitFrame(): SemanticTreeSnapshot {
        if (!collecting) { throw IllegalStateException("semantic frame is not collecting") }
        if (!parentStack.isEmpty()) { throw IllegalStateException("semantic parent stack is not balanced") }
        collecting = false
        revisionValue += UInt64(1)
        committed = orderCommittedSemanticNodes(pending.toArray(), pendingFocusOrders)
        pending.clear()
        pendingFocusOrders.clear()
        pendingTextBytes = 0
        snapshot()
    }

    public func cancelFrame(): Unit {
        pending.clear()
        pendingFocusOrders.clear()
        parentStack.clear()
        pendingTextBytes = 0
        collecting = false
    }

    public func snapshot(): SemanticTreeSnapshot {
        SemanticTreeSnapshot(windowId, revisionValue, committed)
    }

    public func diff(previous: SemanticTreeSnapshot): SemanticTreeDiff {
        if (previous.windowId != windowId) {
            throw IllegalArgumentException("cannot diff semantic trees from different windows")
        }
        if (previous.revision > revisionValue) {
            throw IllegalArgumentException("cannot diff from a future semantic revision")
        }
        let added = ArrayList<String>()
        let removed = ArrayList<String>()
        let changed = ArrayList<String>()
        for (current in committed) {
            match (previous.node(current.id)) {
                case Some(before) => if (!sameSemanticNode(before, current)) { changed.add(current.id) }
                case None => added.add(current.id)
            }
        }
        for (before in previous.nodes) {
            if (findSemanticNode(committed, before.id).isNone()) { removed.add(before.id) }
        }
        SemanticTreeDiff(windowId, previous.revision, revisionValue,
            added.toArray(), removed.toArray(), changed.toArray())
    }

    public func dispatch(request: SemanticActionRequest): SemanticActionReceipt {
        if (collecting) { return rejected(request, "frame-in-progress") }
        if (request.windowId != windowId) { return rejected(request, "window-mismatch") }
        if (request.expectedRevision != revisionValue) { return rejected(request, "stale-revision") }
        if (!policy.allows(request.source)) { return rejected(request, "source-not-allowed") }
        let target = match (findSemanticNode(committed, request.nodeId)) {
            case Some(value) => value
            case None => return rejected(request, "node-not-found")
        }
        if (!target.enabled) { return rejected(request, "node-disabled") }
        if (target.readOnly) { return rejected(request, "node-readonly") }
        if (!containsSemanticAction(target.actions, request.action)) {
            return rejected(request, "action-not-supported")
        }
        let accepted = try {
            handler(request)
        } catch (_: Exception) {
            return rejected(request, "action-handler-failed")
        }
        SemanticActionReceipt(accepted, if (accepted) { "action-handled" } else { "action-declined" },
            windowId, revisionValue, request.nodeId, request.action, request.source)
    }

    private func rejected(request: SemanticActionRequest, code: String): SemanticActionReceipt {
        SemanticActionReceipt(false, code, windowId, revisionValue,
            request.nodeId, request.action, request.source)
    }
}

private var activeSemanticRuntime: ?SemanticRuntime = None

/** Temporarily binds automatic control semantics to one in-process runtime. */
protected func withActiveSemanticRuntime<T>(runtime: SemanticRuntime, body: () -> T): T {
    let previous = activeSemanticRuntime
    activeSemanticRuntime = Some(runtime)
    try {
        body()
    } finally {
        activeSemanticRuntime = previous
    }
}

internal func recordActiveSemanticRuntimeControl(
    frame: Rect,
    widgetType: String,
    semantics: ControlSemantics,
    interactionsEnabled: Bool,
    focusOrder: ?Int64
): Unit {
    match (activeSemanticRuntime) {
        case Some(runtime) => runtime.record(frame, widgetType, semantics,
            interactionsEnabled: interactionsEnabled, focusOrder: focusOrder)
        case None => ()
    }
}

/**
 * Runs a built subtree under one real semantic group node. Root and `Keyed` builders use this
 * instead of inferring hierarchy from overlapping rectangles.
 */
internal func withActiveSemanticParentScope(
    id: String,
    frame: Rect,
    body: () -> Unit
): Unit {
    match (activeSemanticRuntime) {
        case Some(runtime) =>
            runtime.record(frame, "SemanticGroup", ControlSemantics(
                "group", action: "", shortcut: "", actionOwner: id,
                readOnly: Some(true)))
            runtime.pushParent(id)
            try {
                body()
            } finally {
                runtime.popParent()
            }
        case None => body()
    }
}

/** Stable, bounded identity for a `Keyed` build scope. */
internal func semanticBuildScopeId(path: String): String {
    "@scope:" + retainedUiStableCode(path).toString()
}

/**
 * Wraps one build scope without widening retained reuse. Framework-owned provider adapters are
 * installed first, then only the capabilities actually implemented by the child are forwarded.
 * Ordinary widgets therefore remain conservative instead of accidentally opting into reuse.
 */
internal func semanticParentScopeWidget(id: String, child: Widget): Widget {
    let adapted = retainedProviderAdapter(child)
    match (adapted as RetainedMeasureOutputProvider) {
        case Some(measureProvider) =>
            match (adapted as RetainedPaintProofProvider) {
                case Some(paintProvider) => SemanticMeasurePaintParentScopeWidget(
                    id, adapted, measureProvider, paintProvider)
                case None => SemanticMeasureParentScopeWidget(id, adapted, measureProvider)
            }
        case None =>
            match (adapted as RetainedPaintProofProvider) {
                case Some(paintProvider) => SemanticPaintParentScopeWidget(id, adapted, paintProvider)
                case None => SemanticParentScopeWidget(id, adapted)
            }
    }
}

/** Shared forwarding implementation for the four capability-preserving scope variants. */
private class SemanticParentScopeDelegate {
    private let id: String
    private let child: Widget
    private var frame = Rect.zero()

    init(id: String, child: Widget) {
        this.id = id
        this.child = child
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        withActiveSemanticParentScope(id, frame, {=> child.draw(ctx)})
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool { child.handle(ctx, event) }
    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func stackingIndex(): Int64 { child.stackingIndex() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
}

/** Scope wrapper for an ordinary child with no retained proof capabilities. */
private class SemanticParentScopeWidget <: Widget {
    private let scope: SemanticParentScopeDelegate

    init(id: String, child: Widget) { scope = SemanticParentScopeDelegate(id, child) }

    public func measure(ctx: UiContext, available: Size): Size { scope.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit { scope.layout(ctx, rect) }
    public func draw(ctx: UiContext): Unit { scope.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { scope.handle(ctx, event) }
    public func isFlexible(): Bool { scope.isFlexible() }
    public func flexWeight(): Float32 { scope.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { scope.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { scope.participatesInLayout() }
    public func stackingIndex(): Int64 { scope.stackingIndex() }
    public func focusableId(): ?String { scope.focusableId() }
    public func focusableIds(): Array<String> { scope.focusableIds() }
    public func interactionOwnerIds(): Array<String> { scope.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { scope.interactionsEnabled() }
}

/** Scope wrapper that transparently forwards only a measurement reuse proof. */
private class SemanticMeasureParentScopeWidget <: Widget & RetainedMeasureOutputProvider {
    private let scope: SemanticParentScopeDelegate
    private let provider: RetainedMeasureOutputProvider

    init(id: String, child: Widget, provider: RetainedMeasureOutputProvider) {
        scope = SemanticParentScopeDelegate(id, child)
        this.provider = provider
    }

    public func retainedMeasureInputIdentity(ctx: UiContext): String {
        provider.retainedMeasureInputIdentity(ctx)
    }

    public func measure(ctx: UiContext, available: Size): Size { scope.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit { scope.layout(ctx, rect) }
    public func draw(ctx: UiContext): Unit { scope.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { scope.handle(ctx, event) }
    public func isFlexible(): Bool { scope.isFlexible() }
    public func flexWeight(): Float32 { scope.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { scope.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { scope.participatesInLayout() }
    public func stackingIndex(): Int64 { scope.stackingIndex() }
    public func focusableId(): ?String { scope.focusableId() }
    public func focusableIds(): Array<String> { scope.focusableIds() }
    public func interactionOwnerIds(): Array<String> { scope.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { scope.interactionsEnabled() }
}

/** Scope wrapper that transparently forwards only a complete paint proof. */
private class SemanticPaintParentScopeWidget <: Widget & RetainedPaintProofProvider {
    private let scope: SemanticParentScopeDelegate
    private let provider: RetainedPaintProofProvider

    init(id: String, child: Widget, provider: RetainedPaintProofProvider) {
        scope = SemanticParentScopeDelegate(id, child)
        this.provider = provider
    }

    public func retainedPaintProof(ctx: UiContext, frame: Rect): ?RetainedPaintProof {
        provider.retainedPaintProof(ctx, frame)
    }

    public func measure(ctx: UiContext, available: Size): Size { scope.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit { scope.layout(ctx, rect) }
    public func draw(ctx: UiContext): Unit { scope.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { scope.handle(ctx, event) }
    public func isFlexible(): Bool { scope.isFlexible() }
    public func flexWeight(): Float32 { scope.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { scope.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { scope.participatesInLayout() }
    public func stackingIndex(): Int64 { scope.stackingIndex() }
    public func focusableId(): ?String { scope.focusableId() }
    public func focusableIds(): Array<String> { scope.focusableIds() }
    public func interactionOwnerIds(): Array<String> { scope.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { scope.interactionsEnabled() }
}

/** Scope wrapper that preserves both independent retained proof capabilities. */
private class SemanticMeasurePaintParentScopeWidget <:
    Widget & RetainedMeasureOutputProvider & RetainedPaintProofProvider {
    private let scope: SemanticParentScopeDelegate
    private let measureProvider: RetainedMeasureOutputProvider
    private let paintProvider: RetainedPaintProofProvider

    init(
        id: String,
        child: Widget,
        measureProvider: RetainedMeasureOutputProvider,
        paintProvider: RetainedPaintProofProvider
    ) {
        scope = SemanticParentScopeDelegate(id, child)
        this.measureProvider = measureProvider
        this.paintProvider = paintProvider
    }

    public func retainedMeasureInputIdentity(ctx: UiContext): String {
        measureProvider.retainedMeasureInputIdentity(ctx)
    }

    public func retainedPaintProof(ctx: UiContext, frame: Rect): ?RetainedPaintProof {
        paintProvider.retainedPaintProof(ctx, frame)
    }

    public func measure(ctx: UiContext, available: Size): Size { scope.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit { scope.layout(ctx, rect) }
    public func draw(ctx: UiContext): Unit { scope.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { scope.handle(ctx, event) }
    public func isFlexible(): Bool { scope.isFlexible() }
    public func flexWeight(): Float32 { scope.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { scope.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { scope.participatesInLayout() }
    public func stackingIndex(): Int64 { scope.stackingIndex() }
    public func focusableId(): ?String { scope.focusableId() }
    public func focusableIds(): Array<String> { scope.focusableIds() }
    public func interactionOwnerIds(): Array<String> { scope.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { scope.interactionsEnabled() }
}

private func inferSemanticActions(semantics: ControlSemantics): Array<SemanticActionKind> {
    if (!semantics.typedActions.isEmpty()) { return uniqueSemanticActions(semantics.typedActions) }
    let actions = ArrayList<SemanticActionKind>()
    if (semantics.role == "textfield" || semantics.role == "password" ||
        !semantics.action.isEmpty()) {
        actions.add(SemanticActionKind.Focus)
    }
    if (!semantics.action.isEmpty()) { actions.add(SemanticActionKind.Activate) }
    if (semantics.shortcut.contains("Left") || semantics.shortcut.contains("Down")) {
        actions.add(SemanticActionKind.Decrement)
    }
    if (semantics.shortcut.contains("Right") || semantics.shortcut.contains("Up")) {
        actions.add(SemanticActionKind.Increment)
    }
    uniqueSemanticActions(actions.toArray())
}

private func uniqueSemanticActions(input: Array<SemanticActionKind>): Array<SemanticActionKind> {
    let result = ArrayList<SemanticActionKind>()
    for (action in input) {
        if (!containsSemanticAction(result.toArray(), action)) { result.add(action) }
    }
    result.toArray()
}

private func containsSemanticAction(input: Array<SemanticActionKind>, expected: SemanticActionKind): Bool {
    let name = semanticActionName(expected)
    for (action in input) {
        if (semanticActionName(action) == name) { return true }
    }
    false
}

/**
 * Scope nodes remain first so every parent is present before consumers walk its children. Focusable
 * controls then follow the declarative focus ring, independently from paint order (notably ZStack
 * zIndex); non-focusable observation nodes keep their stable collection order after them.
 */
private func orderCommittedSemanticNodes(
    nodes: Array<SemanticNode>,
    focusOrders: HashMap<String, Int64>
): Array<SemanticNode> {
    let scopes = ArrayList<SemanticNode>()
    let focusable = ArrayList<SemanticNode>()
    let observations = ArrayList<SemanticNode>()
    for (node in nodes) {
        if (node.role == "group") {
            scopes.add(node)
        } else if (focusOrders.get(node.id).isSome()) {
            focusable.add(node)
        } else {
            observations.add(node)
        }
    }
    var i: Int64 = 1
    while (i < focusable.size) {
        var j = i
        while (j > 0 && semanticFocusOrder(focusOrders, focusable[j].id) <
            semanticFocusOrder(focusOrders, focusable[j - 1].id)) {
            let current = focusable[j]
            focusable[j] = focusable[j - 1]
            focusable[j - 1] = current
            j -= 1
        }
        i += 1
    }
    let ordered = ArrayList<SemanticNode>()
    for (node in scopes) { ordered.add(node) }
    for (node in focusable) { ordered.add(node) }
    for (node in observations) { ordered.add(node) }
    Array<SemanticNode>(ordered.size, {index => cloneSemanticNodeWithOrder(ordered[index], index)})
}

private func semanticFocusOrder(values: HashMap<String, Int64>, id: String): Int64 {
    match (values.get(id)) {
        case Some(value) => value
        case None => Int64.Max
    }
}

private func sameSemanticNode(left: SemanticNode, right: SemanticNode): Bool {
    if (left.id != right.id || left.parentId != right.parentId || left.order != right.order ||
        left.frame.x != right.frame.x || left.frame.y != right.frame.y || left.frame.w != right.frame.w ||
        left.frame.h != right.frame.h || left.widgetType != right.widgetType || left.role != right.role ||
        left.label != right.label || left.value != right.value || left.placeholder != right.placeholder ||
        left.enabled != right.enabled || left.readOnly != right.readOnly ||
        optionBoolName(left.focused) != optionBoolName(right.focused) ||
        optionBoolName(left.editable) != optionBoolName(right.editable) ||
        optionInt64Name(left.selectionStart) != optionInt64Name(right.selectionStart) ||
        optionInt64Name(left.selectionEnd) != optionInt64Name(right.selectionEnd) ||
        optionBoolName(left.selected) != optionBoolName(right.selected) ||
        optionBoolName(left.expanded) != optionBoolName(right.expanded) ||
        left.actions.size != right.actions.size) {
        return false
    }
    for (index in 0..left.actions.size) {
        if (semanticActionName(left.actions[index]) != semanticActionName(right.actions[index])) { return false }
    }
    true
}

private func optionBoolName(value: ?Bool): String {
    match (value) {
        case Some(actual) => actual.toString()
        case None => "none"
    }
}

private func optionInt64Name(value: ?Int64): String {
    match (value) {
        case Some(actual) => actual.toString()
        case None => "none"
    }
}

private func validateSemanticNodeText(value: String): Unit {
    if (Int64(value.toArray().size) > SEMANTIC_RUNTIME_HARD_MAX_TEXT_BYTES) {
        throw IllegalArgumentException("semantic node text exceeds the hard byte limit")
    }
}

private func validateSemanticIdentifier(value: String, label: String): Unit {
    let bytes = value.toArray().size
    if (value.isEmpty() || bytes > 256 || value.contains("\n") || value.contains("\r")) {
        throw IllegalArgumentException(label + " must contain 1..256 bytes without line breaks")
    }
}

private func semanticControlTextBytes(
    widgetType: String,
    parentId: String,
    semantics: ControlSemantics
): Int64 {
    Int64(widgetType.toArray().size + parentId.toArray().size + semantics.actionOwner.toArray().size +
        semantics.role.toArray().size + semantics.label.toArray().size + semantics.value.toArray().size +
        semantics.placeholder.toArray().size)
}

private func findSemanticNode(nodes: Array<SemanticNode>, id: String): ?SemanticNode {
    for (node in nodes) {
        if (node.id == id) { return Some(node) }
    }
    None
}

private func cloneSemanticNode(node: SemanticNode): SemanticNode {
    SemanticNode(
        node.id,
        node.frame,
        node.widgetType,
        node.role,
        parentId: node.parentId,
        order: node.order,
        label: node.label,
        value: node.value,
        placeholder: node.placeholder,
        selected: node.selected,
        expanded: node.expanded,
        enabled: node.enabled,
        readOnly: node.readOnly,
        focused: node.focused,
        editable: node.editable,
        selectionStart: node.selectionStart,
        selectionEnd: node.selectionEnd,
        actions: node.actions.clone())
}

private func cloneSemanticNodeWithOrder(node: SemanticNode, order: Int64): SemanticNode {
    SemanticNode(
        node.id,
        node.frame,
        node.widgetType,
        node.role,
        parentId: node.parentId,
        order: order,
        label: node.label,
        value: node.value,
        placeholder: node.placeholder,
        selected: node.selected,
        expanded: node.expanded,
        enabled: node.enabled,
        readOnly: node.readOnly,
        focused: node.focused,
        editable: node.editable,
        selectionStart: node.selectionStart,
        selectionEnd: node.selectionEnd,
        actions: node.actions.clone())
}
