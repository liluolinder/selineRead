package chui.core

import sdl.{DeviceRotation, Rect, Size, UiEvent, deviceRotationIsLandscape}

/**
 * Responsive layout selection driven by a normalized device posture.
 *
 * Applications declare both arrangements once and pass `DesktopApp.deviceRotation()` as
 * `rotation`. A provider may enqueue/post `DeviceRotationEvent`; after the shell accepts it,
 * the next declarative build selects the matching tree. Whole-interface rotation is owned
 * by the host shell so pixels, overlays, text input and the new layout rotate as one frame;
 * this widget only chooses layout structure and never impersonates a rotation with a wipe.
 */
public class DeviceRotationLayout <: Widget {
    private let portrait: Widget
    private let landscape: Widget
    private let rotation: DeviceRotation
    private var frame = Rect.zero()

    public init(
        rotation!: DeviceRotation,
        key!: ?String = None,
        portrait!: () -> Unit,
        landscape!: () -> Unit
    ) {
        this.rotation = rotation
        let id = resolveControlKey(key, "DeviceRotationLayout")
        this.portrait = buildKeyedChild("${id}:portrait", portrait)
        this.landscape = buildKeyedChild("${id}:landscape", landscape)
        let inactive = if (deviceRotationIsLandscape(rotation)) { this.portrait } else { this.landscape }
        for (focusId in inactive.focusableIds()) {
            unregisterFocusable(focusId)
        }
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        activeChild().measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        activeChild().layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.pushClip(frame)
        activeChild().draw(ctx)
        ctx.renderer.popClip()
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        activeChild().handle(ctx, event)
    }

    public func isFlexible(): Bool { activeChild().isFlexible() }
    public func flexWeight(): Float32 { activeChild().flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { activeChild().acceptsStretch(axis) }
    public func participatesInLayout(): Bool { activeChild().participatesInLayout() }
    public func focusableId(): ?String { activeChild().focusableId() }
    public func focusableIds(): Array<String> { activeChild().focusableIds() }
    public func interactionOwnerIds(): Array<String> { activeChild().interactionOwnerIds() }
    public func interactionsEnabled(): Bool { activeChild().interactionsEnabled() }

    private func activeChild(): Widget {
        if (deviceRotationIsLandscape(rotation)) { landscape } else { portrait }
    }
}
