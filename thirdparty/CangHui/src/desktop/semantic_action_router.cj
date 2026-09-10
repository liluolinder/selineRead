package chui.desktop

import chui.core.{SemanticActionHandler, SemanticActionKind, SemanticActionRequest, UiContext, Widget}
import sdl.{Key, UiEvent}

/**
 * Window-local adapter from the release-safe semantic plane to ordinary CangHui event routing.
 *
 * It accepts no coordinates, raw key names, command strings, process attachment, IPC or network
 * transport. SemanticRuntime has already bound the request to an exact window, revision, enabled
 * node and declared action before this adapter sees it.
 */
protected class DesktopSemanticActionRouter {
    private let ctx: UiContext
    private let fallback: SemanticActionHandler
    private var widget: ?Widget = None

    protected init(ctx: UiContext, fallback!: SemanticActionHandler = {_ => false}) {
        this.ctx = ctx
        this.fallback = fallback
    }

    protected func bind(value: Widget): Unit { widget = Some(value) }

    protected func clear(): Unit { widget = None }

    protected func dispatch(request: SemanticActionRequest): Bool {
        let handled = match (request.action) {
            case SemanticActionKind.Focus => ctx.focusRegistered(request.nodeId)
            case SemanticActionKind.Activate => dispatchFocused(request.nodeId, Key.Enter)
            case SemanticActionKind.Increment => dispatchFocused(request.nodeId, Key.Right)
            case SemanticActionKind.Decrement => dispatchFocused(request.nodeId, Key.Left)
            case SemanticActionKind.Dismiss => dispatchKey(Key.Escape)
        }
        if (handled) { true } else { fallback(request) }
    }

    private func dispatchFocused(id: String, key: Key): Bool {
        if (!ctx.focusRegistered(id)) { return false }
        dispatchKey(key)
    }

    private func dispatchKey(key: Key): Bool {
        let event = UiEvent.KeyDown(key, false)
        if (ctx.dispatchOverlay(event)) { return true }
        match (widget) {
            case Some(value) => value.handle(ctx, event)
            case None => false
        }
    }
}
