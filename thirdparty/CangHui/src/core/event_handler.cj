package chui.core

import std.collection.ArrayList
import sdl.{FrameInfo, Rect, Size, UiEvent}

public class EventHandler <: Widget {
    private let child: Widget
    private let onEvent: (UiEvent) -> Bool

    public init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit) {
        this.child = buildChild(body)
        this.onEvent = onEvent
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) =>
                let _ = onEvent(event)
                let _ = child.handle(ctx, event)
                return false
            case _ => ()
        }
        if (onEvent(event)) {
            return true
        }
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    public func interactionOwnerIds(): Array<String> {
        let ids = ArrayList<String>()
        ids.add("EventHandler")
        for (id in child.interactionOwnerIds()) {
            if (!ids.contains(id)) { ids.add(id) }
        }
        ids.toArray()
    }
}

public class FrameHandler <: Widget {
    private let child: Widget
    private let onFrame: (FrameInfo) -> Unit
    private let keepsAlive: () -> Bool

    public init(
        onFrame!: (FrameInfo) -> Unit,
        keepsAlive!: () -> Bool = {=> true},
        body!: () -> Unit
    ) {
        this.child = buildChild(body)
        this.onFrame = onFrame
        this.keepsAlive = keepsAlive
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(info) =>
                onFrame(info)
                // A normal frame hook is a per-frame contract. Product bridges with bounded work
                // may opt out after the callback drains its final item, avoiding one retained
                // FrameHandler turning an otherwise static surface into a permanent repaint loop.
                if (keepsAlive()) { ctx.requestFrame() }
                let _ = child.handle(ctx, event)
                return false
            case _ => return child.handle(ctx, event)
        }
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    public func interactionOwnerIds(): Array<String> {
        child.interactionOwnerIds()
    }
}
