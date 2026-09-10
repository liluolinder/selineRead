package chui.controls

import std.collection.ArrayList
import sdl.{Color, FontSizes, MouseButton, Pen, Rect, Size, UiEvent}
import chui.core.{AnimationSpec, Animator, Bindable, ControlSemantics, InteractionAnimation, Motion, State,
    UiContext, Widget, resolveControlKey, emit, handlePointerClick, localState, recordControlSemantics}

private let PAGE_BTN_W: Float32 = 34.0
private let PAGE_BTN_H: Float32 = 34.0
private let PAGE_GAP: Float32 = 4.0
// A page index of -1 in the item list stands for an ellipsis gap.
private let PAGE_ELLIPSIS: Int64 = -1

/**
 * A page navigator for long, paged content (search results, tables, catalogs). It shows previous/next
 * arrows around a windowed run of page numbers — always the first and last page, the pages around the
 * current one, and an ellipsis for any gap. Clicking a number jumps to that page; the arrows step one
 * page and disable at the ends. `current` is the zero-based page bound two-way, displayed one-based.
 */
public class Pagination <: Widget {
    private let id: String
    private let pageCount: Int64
    private let current: Bindable<Int64>
    private let window: Int64
    private var items: Array<Int64>
    private let maxItemCells: Int64
    private var semanticLabel: String
    private var frame = Rect.zero()
    private var prevRect = Rect.zero()
    private var nextRect = Rect.zero()
    private let itemRects: Array<Rect>
    private let itemAnimations: Array<InteractionAnimation>
    private let prevAnimation: InteractionAnimation
    private let nextAnimation: InteractionAnimation
    private let selectionX: Animator
    private let selectionInitialized: State<Bool>

    public init(pageCount: Int64, current: Bindable<Int64>, window!: Int64 = 1, key!: ?String = None) {
        let ident = resolveControlKey(key, "Pagination")
        let normalizedCount = max(1, pageCount)
        let normalizedWindow = max(0, window)
        let builtItems = paginationItems(normalizedCount, clampPage(current.value, normalizedCount), normalizedWindow)
        this.id = ident
        this.pageCount = normalizedCount
        this.current = current
        this.window = normalizedWindow
        this.items = builtItems
        this.maxItemCells = min(normalizedCount, max(1, normalizedWindow * 2 + 5))
        this.semanticLabel = ""
        this.itemRects = Array<Rect>(maxItemCells, {_ => Rect.zero()})
        this.itemAnimations = Array<InteractionAnimation>(maxItemCells, {i =>
            localState<InteractionAnimation>("Pagination:${ident}:item:${i}") {
                InteractionAnimation()
            }.value
        })
        this.prevAnimation = localState<InteractionAnimation>("Pagination:${ident}:previous") {
            InteractionAnimation()
        }.value
        this.nextAnimation = localState<InteractionAnimation>("Pagination:${ident}:next") {
            InteractionAnimation()
        }.value
        this.selectionX = localState<Animator>("Pagination:${ident}:selection-x") {Animator(0.0)}.value
        this.selectionInitialized = localState<Bool>("Pagination:${ident}:selection-initialized") {false}
        emit(this)
    }

    /** Overrides the semantic name without changing the visible page numbers. */
    public func accessibilityLabel(value: String): Pagination {
        semanticLabel = value
        this
    }

    public func measure(_: UiContext, _: Size): Size {
        let cells = Float32(maxItemCells + 2) // stable maximum page cells plus the two arrows
        Size(cells * PAGE_BTN_W + (cells - 1.0) * PAGE_GAP, PAGE_BTN_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
        refreshItemsAndRects()
    }

    private func refreshItemsAndRects(): Unit {
        items = paginationItems(pageCount, clampPage(current.value, pageCount), window)
        prevRect = Rect(frame.x, frame.y, PAGE_BTN_W, PAGE_BTN_H)
        var cursor = frame.x + PAGE_BTN_W + PAGE_GAP
        for (i in 0..items.size) {
            itemRects[i] = Rect(cursor, frame.y, PAGE_BTN_W, PAGE_BTN_H)
            cursor += PAGE_BTN_W + PAGE_GAP
        }
        nextRect = Rect(frame.x + Float32(maxItemCells + 1) * (PAGE_BTN_W + PAGE_GAP),
            frame.y, PAGE_BTN_W, PAGE_BTN_H)
    }

    public func draw(ctx: UiContext): Unit {
        refreshItemsAndRects()
        let page = clampPage(current.value, pageCount)
        recordControlSemantics(ctx, frame, "Pagination", ControlSemantics(
            "pagination", label: semanticLabel,
            value: "page ${page + 1} of ${pageCount}",
            action: "", shortcut: "",
            actionOwner: id
        ))
        let selectedRect = currentPageRect(page)
        if (!selectionInitialized.value) {
            selectionX.reset(selectedRect.x)
            selectionInitialized.value = true
        }
        let selectedX = selectionX.animate(ctx, target: selectedRect.x,
            spec: AnimationSpec.automatic(duration: Motion.normal, easing: Motion.decelerate))
        ctx.renderer.fillRoundedRect(Rect(selectedX, selectedRect.y, selectedRect.w, selectedRect.h),
            ctx.theme.smallRadius, ctx.theme.accent)
        drawArrow(ctx, prevRect, true, page > 0, prevAnimation, "${id}:previous")
        for (i in 0..items.size) {
            let value = items[i]
            if (value == PAGE_ELLIPSIS) {
                drawEllipsis(ctx, itemRects[i])
            } else {
                drawPage(ctx, itemRects[i], value, value == page, itemAnimations[i], "${id}:page:${value}")
            }
        }
        drawArrow(ctx, nextRect, false, page < pageCount - 1, nextAnimation, "${id}:next")
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        refreshItemsAndRects()
        let page = clampPage(current.value, pageCount)
        if (page > 0 && handlePointerClick(ctx, event, prevRect, "${id}:previous", {=> current.value = page - 1},
            inkRadius: ctx.theme.smallRadius, inkColor: Some(ctx.theme.inkColor()), claimFocus: false)) {
            return true
        }
        if (page < pageCount - 1 && handlePointerClick(ctx, event, nextRect, "${id}:next",
            {=> current.value = page + 1}, inkRadius: ctx.theme.smallRadius,
            inkColor: Some(ctx.theme.inkColor()), claimFocus: false)) {
            return true
        }
        for (i in 0..items.size) {
            let target = items[i]
            if (target != PAGE_ELLIPSIS && handlePointerClick(ctx, event, itemRects[i], "${id}:page:${target}",
                {=> current.value = target}, inkRadius: ctx.theme.smallRadius,
                inkColor: Some(ctx.theme.inkColor()), claimFocus: false)) {
                return true
            }
        }
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (prevRect.contains(x, y) || nextRect.contains(x, y)) {
                    return true
                }
            case _ => ()
        }
        false
    }

    public func interactionOwnerIds(): Array<String> {
        [id]
    }

    private func drawPage(ctx: UiContext, rect: Rect, page: Int64, isCurrent: Bool,
        animation: InteractionAnimation, cellId: String): Unit {
        let progress = animation.animate(ctx, ctx.isHovered(cellId), ctx.isPressed(cellId),
            AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate))
        if (!isCurrent) {
            let inset = progress.press * 1.2
            let visual = rect.inset(inset)
            ctx.renderer.fillRoundedRect(visual, ctx.theme.smallRadius,
                ctx.theme.field.lerp(ctx.theme.fieldActive, progress.hover).lerp(ctx.theme.accentSoft, progress.press))
        }
        let color = if (isCurrent) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        // Displayed one-based.
        drawCentered(ctx, "${page + 1}", rect, color)
    }

    private func drawEllipsis(ctx: UiContext, rect: Rect): Unit {
        drawCentered(ctx, "…", rect, ctx.theme.mutedText)
    }

    private func drawArrow(ctx: UiContext, rect: Rect, pointsLeft: Bool, enabled: Bool,
        animation: InteractionAnimation, cellId: String): Unit {
        let progress = animation.animate(ctx, enabled && ctx.isHovered(cellId), enabled && ctx.isPressed(cellId),
            AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate))
        let visual = rect.inset(progress.press * 1.2)
        ctx.renderer.fillRoundedRect(visual, ctx.theme.smallRadius,
            ctx.theme.field.lerp(ctx.theme.fieldActive, progress.hover).lerp(ctx.theme.accentSoft, progress.press))
        let color = if (enabled) {
            ctx.theme.text
        } else {
            ctx.theme.mutedText.withAlpha(120)
        }
        let pen = Pen(width: 1.8, color: color)
        let cx = rect.centerX()
        let cy = rect.centerY()
        if (pointsLeft) {
            ctx.renderer.strokeLine(cx + 3.0, cy - 5.0, cx - 3.0, cy, pen)
            ctx.renderer.strokeLine(cx - 3.0, cy, cx + 3.0, cy + 5.0, pen)
        } else {
            ctx.renderer.strokeLine(cx - 3.0, cy - 5.0, cx + 3.0, cy, pen)
            ctx.renderer.strokeLine(cx + 3.0, cy, cx - 3.0, cy + 5.0, pen)
        }
    }

    private func drawCentered(ctx: UiContext, text: String, rect: Rect, color: Color): Unit {
        let w = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
        let h = ctx.renderer.textHeight(pointSize: FontSizes.CONTROL)
        ctx.renderer.text(text, rect.centerX() - w / 2.0, rect.centerY() - h / 2.0, color, pointSize: FontSizes.CONTROL)
    }

    private func currentPageRect(page: Int64): Rect {
        for (i in 0..items.size) {
            if (items[i] == page) {
                return itemRects[i]
            }
        }
        itemRects[0]
    }
}

internal func clampPage(page: Int64, pageCount: Int64): Int64 {
    if (pageCount <= 0) {
        0
    } else if (page < 0) {
        0
    } else if (page >= pageCount) {
        pageCount - 1
    } else {
        page
    }
}

/*
 * The page indices to display: always the first and last page, the run current±window, and -1 for each
 * ellipsis gap between them. So 20 pages at page 10 (window 1) yields 0, -1, 9, 10, 11, -1, 19.
 */
internal func paginationItems(pageCount: Int64, current: Int64, window: Int64): Array<Int64> {
    if (pageCount <= 0) {
        return []
    }
    if (pageCount == 1) {
        return [0]
    }
    let cur = clampPage(current, pageCount)
    let lo = max(0, cur - window)
    let hi = min(pageCount - 1, cur + window)
    let result = ArrayList<Int64>()
    result.add(0)
    if (lo > 1) {
        result.add(PAGE_ELLIPSIS)
    }
    var p = max(1, lo)
    let mid = min(pageCount - 2, hi)
    while (p <= mid) {
        result.add(p)
        p += 1
    }
    if (hi < pageCount - 2) {
        result.add(PAGE_ELLIPSIS)
    }
    result.add(pageCount - 1)
    result.toArray()
}
