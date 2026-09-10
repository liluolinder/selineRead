package chui.core

import std.collection.ArrayList
import sdl.{Color, MouseButton, Point, Rect, Size, UiEvent}

/*
 * Declarative builder support.
 *
 * The UI tree is described with trailing-lambda blocks (see VStack, HStack, Panel).
 * Each concrete widget registers itself with the innermost open block by calling
 * `emit` from its constructor, so a block such as
 *
 *     VStack {
 *         Label("Title")
 *         Button("OK") { => save() }
 *     }
 *
 * collects the Label and Button as the stack's children with no explicit array.
 * Ordinary control flow works inside a block because each statement simply runs:
 *
 *     VStack {
 *         for (row in rows) { buttonRow(row) }
 *         if (expanded) { detailPanel() }
 *     }
 *
 * The stack of open blocks is module-private state. That is safe here: the UI runs on
 * a single thread and the whole tree is rebuilt top to bottom each frame, and every
 * block balances its push and pop through `buildChildren`.
 */
var openBlocks = ArrayList<ArrayList<Widget>>()
var activeStateStore: ?StateStore = None

/*
 * Register a freshly constructed widget with the enclosing builder block. Every widget
 * constructor calls this. Outside any block (for example a widget built to be stored
 * and reused) it is a no-op, so widgets stay ordinary values. Pass an existing widget
 * to place it explicitly: `VStack { for (w in built) { emit(w) } }`.
 */
public func emit(widget: Widget): Unit {
    if (!openBlocks.isEmpty()) {
        openBlocks[openBlocks.size - 1].add(widget)
    }
}

/*
 * A modifier is evaluated immediately after the expression that emitted its child. Find
 * that exact child in the active block and replace it with the decorated node. Searching
 * backwards also keeps modifiers safe when a stored widget is decorated after another
 * declaration in the same block.
 */
protected func replaceLastEmission(original: Widget, replacement: Widget): Unit {
    if (openBlocks.isEmpty()) {
        return
    }
    let block = openBlocks[openBlocks.size - 1]
    var i = block.size - 1
    while (i >= 0) {
        if (let Some(candidate) <- (block[i] as Object)) {
            if (let Some(source) <- (original as Object)) {
                if (refEq(candidate, source)) {
                    block[i] = replacement
                    return
                }
            }
        }
        i -= 1
    }
    // The original was never emitted into this block (a stored widget decorated inside a
    // later block). Append the decorated node at the decoration point — overwriting the
    // last element here would silently destroy an unrelated sibling.
    block.add(replacement)
}

/*
 * Run a builder block and return every widget it declares, in order.
 */
protected func buildChildren(body: () -> Unit): Array<Widget> {
    let block = ArrayList<Widget>()
    openBlocks.add(block)
    try {
        body()
    } finally {
        openBlocks.remove(at: openBlocks.size - 1)
    }
    block.toArray()
}

/*
 * Run a builder block that wraps a single child. No declaration yields an empty
 * placeholder; several are stacked vertically.
 */
protected func buildChild(body: () -> Unit): Widget {
    let children = buildChildren(body)
    match (children.size) {
        case 0 => EmptyView()
        case 1 => children[0]
        case _ => Stack(Axis.Vertical, children)
    }
}

/** Builds an application root while retaining and pruning its keyed local state. */
protected func buildRoot(body: () -> Unit, stateStore: StateStore): Widget {
    let previous = activeStateStore
    var buildStarted = false
    try {
        activeStateStore = Some(stateStore)
        stateStore.beginBuild()
        buildStarted = true
        let root = buildChild(body)
        stateStore.finishBuild()
        buildStarted = false
        semanticParentScopeWidget("@root", root)
    } catch (error: Exception) {
        if (buildStarted) { stateStore.cancelBuild() }
        throw error
    } finally {
        activeStateStore = previous
    }
}

/**
 * Builds the Desktop FrameGraph root inside one retained-metadata transaction. The transaction
 * remains active through measure/layout/event/paint and is committed by DesktopApp only after a
 * successful present (or successful legacy fallback).
 */
protected func buildRetainedRoot(
    body: () -> Unit,
    stateStore: StateStore,
    contextCode: Int64
): Widget {
    let previous = activeStateStore
    var buildStarted = false
    var retainedStarted = false
    try {
        activeStateStore = Some(stateStore)
        stateStore.beginBuild()
        buildStarted = true
        stateStore.beginRetainedFrame(contextCode)
        retainedStarted = true
        let runtime = stateStore.retainedRuntime()
        runtime.declareNode("@root", "", Int64(1))
        let _ = runtime.beginPhase("@root", RetainedUiPhase.Build, Int64(1))
        let child = buildChild(body)
        runtime.endPhase()
        // Desktop assigns the root exact viewport bounds instead of asking it for a preferred
        // size. Record that fixed-root measure decision explicitly so the uncalled Widget
        // `measure` callback does not remain dirty forever.
        let _ = runtime.beginPhase("@root", RetainedUiPhase.Measure, contextCode)
        runtime.endPhase()
        stateStore.finishBuild()
        buildStarted = false
        RetainedWidgetNode("@root", semanticParentScopeWidget("@root", child), runtime)
    } catch (error: Exception) {
        if (buildStarted) { stateStore.cancelBuild() }
        if (retainedStarted) { stateStore.cancelRetainedFrame() }
        throw error
    } finally {
        activeStateStore = previous
    }
}

/** Builds one identity scope without changing the normal widget collection rules. */
protected func buildKeyedChild(key: String, body: () -> Unit): Widget {
    match (activeStateStore) {
        case Some(store) =>
            store.pushScope(key)
            try {
                let runtime = store.retainedRuntime()
                let semanticId = semanticBuildScopeId(store.currentScopePath())
                if (!runtime.isFrameActive()) {
                    semanticParentScopeWidget(semanticId, buildChild(body))
                } else {
                    let id = store.currentScopePath()
                    let parentId = runtime.currentNodeId()
                    runtime.declareNode(
                        id,
                        parentId,
                        retainedUiStableCode(id),
                        layoutIsolated: false)
                    let _ = runtime.beginPhase(
                        id, RetainedUiPhase.Build, retainedUiStableCode(id))
                    try {
                        let child = buildChild(body)
                        runtime.endPhase()
                        RetainedWidgetNode(id, semanticParentScopeWidget(semanticId, child), runtime)
                    } catch (error: Exception) {
                        runtime.endPhase()
                        throw error
                    }
                }
            } finally {
                store.popScope()
            }
        case None => buildChild(body)
    }
}

/** Throws `IllegalStateException` when no application root is being built. */
protected func currentStateStore(): StateStore {
    match (activeStateStore) {
        case Some(store) => store
        case None => throw IllegalStateException("rememberState must be called while building a DesktopApp view")
    }
}

/** Retains implicit control state when building an app and falls back for headless use. */
protected func localState<T>(key: String, initial: () -> T): State<T> {
    match (activeStateStore) {
        case Some(store) => store.remember<T>(key, initial)
        case None => State<T>(initial())
    }
}

/**
 * Throws `IllegalArgumentException` when a required control id is empty, with one consistent message.
 * Every id-taking control routes its check here so the guard and its wording live in a single place
 * (previously each control inlined its own copy).
 */
protected func requireControlId(id: String, kind: String): Unit {
    if (id.isEmpty()) {
        throw IllegalArgumentException("${kind} id must not be empty")
    }
}

/*
 * Resolves a control's identity from an optional explicit key (the unified `key!` parameter). A
 * given key is used verbatim after a non-empty check; when absent, the identity is auto-derived by
 * declaration order within the current `Keyed` scope. This is the single seam behind every control's
 * optional identity: state that must survive structural change passes an explicit key, everything
 * else lets build order name it.
 */
protected func resolveControlKey(key: ?String, kind: String): String {
    match (key) {
        case Some(value) =>
            requireControlId(value, kind)
            value
        case None => controlIdentity(kind)
    }
}

/*
 * A focus/press identity for a control that declared no explicit id. During a build the
 * identity is scoped by `Keyed` and deduplicated in declaration order, so identical
 * default names (two icon-only buttons, two "确定" buttons) never share interaction
 * state. Outside a build the base name is returned unchanged.
 */
protected func controlIdentity(base: String): String {
    match (activeStateStore) {
        case Some(store) => store.uniqueControlId(base)
        case None => base
    }
}

/*
 * Records `id` as a keyboard-focus stop in build (declaration) order. Focusable controls
 * call this once their identity is known, so the shell can walk them with Tab / Shift+Tab.
 * Outside a build it is a no-op, keeping headless widget construction side-effect free.
 */
protected func registerFocusable(id: String): Unit {
    match (activeStateStore) {
        case Some(store) => store.registerFocusable(id)
        case None => ()
    }
}

/*
 * Assigns a build-order identity and registers it as a focus stop in one step. Public so
 * application-defined widgets can join the Tab order exactly like built-in controls: call it in
 * the constructor with a stable base name, then pair `ctx.hasFocus(id)` / `ctx.showFocusRing(id)`
 * in `handle` / `draw` (see `examples/disclosure` for a complete custom row).
 */
public func focusableControlIdentity(base: String): String {
    let id = controlIdentity(base)
    registerFocusable(id)
    id
}

/** Drops `id` from the current build's focus ring (no-op outside a build). */
protected func unregisterFocusable(id: String): Unit {
    match (activeStateStore) {
        case Some(store) => store.unregisterFocusable(id)
        case None => ()
    }
}

/** The number of focus stops the current build has registered so far (0 outside a build). */
protected func focusableCountNow(): Int64 {
    match (activeStateStore) {
        case Some(store) => store.focusableCount()
        case None => 0
    }
}

/** The focus stops registered since `start` in the current build; empty outside a build. */
protected func focusablesSince(start: Int64): Array<String> {
    match (activeStateStore) {
        case Some(store) => store.focusablesFrom(start)
        case None => []
    }
}

/** Keeps the focus ring consistent when a control's `.key(...)` overrides its auto id. */
protected func reregisterFocusable(previous: String, replacement: String): Unit {
    match (activeStateStore) {
        case Some(store) => store.reregisterFocusable(previous, replacement)
        case None => ()
    }
}

/** Concatenates the focus stops of `children` in declaration order (container helper). */
protected func collectFocusableIds(children: Array<Widget>): Array<String> {
    let ids = ArrayList<String>()
    for (child in children) {
        for (id in child.focusableIds()) {
            ids.add(id)
        }
    }
    ids.toArray()
}

/** Concatenates the interaction owners of `children` in declaration order. */
protected func collectInteractionOwnerIds(children: Array<Widget>): Array<String> {
    let ids = ArrayList<String>()
    for (child in children) {
        for (id in child.interactionOwnerIds()) {
            if (!ids.contains(id)) { ids.add(id) }
        }
    }
    ids.toArray()
}

/*
 * Claims the pointer shape for `id` when a MouseMove falls inside `frame`. Controls call
 * this at the top of `handle` without consuming the event, so hover propagates to every
 * layer and the shell resolves the top-most claim (see `UiContext.claimHover`). Public for
 * application-defined widgets, which pair it with `ctx.isHovered(id)` in `draw`.
 */
public func claimHoverIfInside(ctx: UiContext, event: UiEvent, frame: Rect, id: String, shape: CursorShape): Unit {
    match (event) {
        case UiEvent.MouseMove(x, y) => if (frame.contains(x, y)) {
            ctx.claimHover(id, shape)
        }
        case _ => ()
    }
}

/**
 * Unified pointer activation: press inside, cancel permanently on move-out, activate only when the
 * same press releases inside. This is shared by Button, IconButton and button-like controls.
 */
public func handlePointerClick(
    ctx: UiContext,
    event: UiEvent,
    frame: Rect,
    id: String,
    activate: () -> Unit,
    ink!: Bool = true,
    inkFrame!: ?Rect = None,
    inkRadius!: Float32 = 0.0,
    inkColor!: ?Color = None,
    focusTarget!: ?String = None,
    claimFocus!: Bool = true
): Bool {
    claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
    match (event) {
        case UiEvent.MouseMove(x, y) =>
            if (ctx.isPressed(id) && !frame.contains(x, y)) {
                ctx.cancelPress(id)
                ctx.cancelInkRipple(id)
            }
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            if (frame.contains(x, y)) {
                if (claimFocus) {
                    ctx.focus(match (focusTarget) {
                        case Some(value) => value
                        case None => id
                    })
                }
                ctx.press(id)
                if (ink) {
                    let resolvedInkFrame = resolveInkRippleFrame(frame, inkFrame)
                    let origin = resolveInkRippleOrigin(resolvedInkFrame, x, y)
                    ctx.startInkRipple(id, resolvedInkFrame, origin.x, origin.y,
                        color: inkColor, cornerRadius: inkRadius)
                }
                return true
            }
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            if (ctx.isPressed(id)) {
                let shouldActivate = frame.contains(x, y)
                ctx.cancelPress(id)
                if (shouldActivate) {
                    activate()
                } else {
                    ctx.cancelInkRipple(id)
                }
                return true
            }
        case _ => ()
    }
    false
}

internal func resolveInkRippleFrame(hitFrame: Rect, inkFrame: ?Rect): Rect {
    match (inkFrame) {
        case Some(value) => value
        case None => hitFrame
    }
}

internal func resolveInkRippleOrigin(inkFrame: Rect, x: Float32, y: Float32): Point {
    if (inkFrame.contains(x, y)) {
        Point(x, y)
    } else {
        Point(inkFrame.centerX(), inkFrame.centerY())
    }
}

/*
 * Zero-size filler used where a child is required but none was declared. It never
 * emits, so `buildChild` can create it while an outer block is still open.
 */
class EmptyView <: Widget {
    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
