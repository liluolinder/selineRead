package chui.core

import sdl.{Rect, Size, UiEvent}

/**
 * Computes the stable column count used by `AdaptiveGrid`.
 *
 * A cell never becomes narrower than `minCellWidth` unless even one cell cannot fit. The result is
 * clamped to the explicit min/max column range, making compact/common/wide breakpoints data-driven
 * without changing fixed-column `Grid` or `LazyGrid`.
 */
public func adaptiveGridColumns(
    width: Float32,
    minCellWidth: Float32,
    spacing: Float32,
    minColumns!: Int64 = 1,
    maxColumns!: Int64 = Int64.Max
): Int64 {
    if (minCellWidth <= 0.0) { throw IllegalArgumentException("adaptive grid minimum cell width must be positive") }
    if (minColumns <= 0 || maxColumns < minColumns) {
        throw IllegalArgumentException("adaptive grid column bounds are invalid")
    }
    let safeGap = max(0.0, spacing)
    let raw = max(Int64(1), Int64(max(0.0, width + safeGap) / (minCellWidth + safeGap)))
    min(maxColumns, max(minColumns, raw))
}

/** Equal-width grid whose columns derive from available width and a minimum cell width. */
public class AdaptiveGrid <: Widget {
    private let minCellWidth: Length
    private let minColumns: Int64
    private let maxColumns: Int64
    private let children: Array<Widget>
    private var horizontalGap: Length = vpLength(CUI_GAP)
    private var verticalGap: Length = vpLength(CUI_GAP)
    private var lastColumns: Int64 = 1

    public init(
        minCellWidth: Length,
        minColumns!: Int64 = 1,
        maxColumns!: Int64 = Int64.Max,
        body!: () -> Unit
    ) {
        if (minColumns <= 0 || maxColumns < minColumns) {
            throw IllegalArgumentException("AdaptiveGrid column bounds are invalid")
        }
        this.minCellWidth = minCellWidth
        this.minColumns = minColumns
        this.maxColumns = maxColumns
        this.children = buildChildren(body)
        emit(this)
    }

    public init(
        minCellWidth: Float32,
        minColumns!: Int64 = 1,
        maxColumns!: Int64 = Int64.Max,
        body!: () -> Unit
    ) {
        this(vpLength(minCellWidth), minColumns: minColumns, maxColumns: maxColumns, body: body)
    }

    public func spacing(value: Length): AdaptiveGrid {
        horizontalGap = value
        verticalGap = value
        this
    }

    public func spacing(value: Float32): AdaptiveGrid { spacing(vpLength(value)) }

    public func spacing(horizontal: Length, vertical: Length): AdaptiveGrid {
        horizontalGap = horizontal
        verticalGap = vertical
        this
    }

    public func spacing(horizontal: Float32, vertical: Float32): AdaptiveGrid {
        spacing(vpLength(horizontal), vpLength(vertical))
    }

    /** Last column count resolved by measure/layout; useful for probes and deterministic tests. */
    public func resolvedColumns(): Int64 { lastColumns }

    public func measure(ctx: UiContext, available: Size): Size {
        let columns = columnsFor(ctx, available.w)
        let heights = adaptiveRowHeights(ctx, available.w, available.h, columns)
        Size(available.w, min(available.h,
            adaptiveHeightSum(heights) + adaptiveGapExtent(heights.size, gapV(ctx))))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let columns = columnsFor(ctx, rect.w)
        lastColumns = columns
        let hGap = gapH(ctx)
        let cellWidth = adaptiveCellWidth(rect.w, hGap, columns)
        let heights = adaptiveRowHeights(ctx, rect.w, rect.h, columns)
        var y = rect.y
        var childIndex: Int64 = 0
        var row: Int64 = 0
        while (row < heights.size) {
            var column: Int64 = 0
            while (column < columns && childIndex < children.size) {
                if (!children[childIndex].participatesInLayout()) {
                    childIndex += 1
                    continue
                }
                let child = children[childIndex]
                let x = rect.x + Float32(column) * (cellWidth + hGap)
                let measured = child.measure(ctx, Size(cellWidth, heights[row]))
                let width = if (child.acceptsStretch(Axis.Horizontal)) {cellWidth} else {measured.w}
                let height = if (child.acceptsStretch(Axis.Vertical)) {heights[row]} else {measured.h}
                child.layout(ctx, Rect(x, y, min(cellWidth, width), min(heights[row], height)))
                column += 1
                childIndex += 1
            }
            y += heights[row] + gapV(ctx)
            row += 1
        }
    }

    public func draw(ctx: UiContext): Unit { for (child in children) { child.draw(ctx) } }
    public func handle(ctx: UiContext, event: UiEvent): Bool { dispatchChildren(children, ctx, event) }
    public func focusableIds(): Array<String> { collectFocusableIds(children) }
    public func interactionOwnerIds(): Array<String> { collectInteractionOwnerIds(children) }

    private func columnsFor(ctx: UiContext, width: Float32): Int64 {
        adaptiveGridColumns(width, max(0.01, ctx.resolve(minCellWidth)), gapH(ctx),
            minColumns: minColumns, maxColumns: maxColumns)
    }

    private func gapH(ctx: UiContext): Float32 { max(0.0, ctx.resolve(horizontalGap)) }
    private func gapV(ctx: UiContext): Float32 { max(0.0, ctx.resolve(verticalGap)) }

    private func adaptiveRowHeights(ctx: UiContext, width: Float32, height: Float32,
        columns: Int64): Array<Float32> {
        let count = adaptiveParticipatingCount(children)
        let rows = (count + columns - 1) / columns
        let heights = Array<Float32>(rows, {_ => Float32(0.0)})
        let cellWidth = adaptiveCellWidth(width, gapH(ctx), columns)
        var i: Int64 = 0
        var activeIndex: Int64 = 0
        while (i < children.size) {
            if (!children[i].participatesInLayout()) { i += 1; continue }
            let row = activeIndex / columns
            heights[row] = max(heights[row], children[i].measure(ctx, Size(cellWidth, height)).h)
            i += 1
            activeIndex += 1
        }
        heights
    }
}

private func adaptiveCellWidth(width: Float32, gap: Float32, columns: Int64): Float32 {
    max(0.0, width - adaptiveGapExtent(columns, gap)) / Float32(columns)
}

private func adaptiveParticipatingCount(children: Array<Widget>): Int64 {
    var count: Int64 = 0
    for (child in children) { if (child.participatesInLayout()) { count += 1 } }
    count
}

private func adaptiveGapExtent(count: Int64, gap: Float32): Float32 {
    if (count <= 1) { 0.0 } else { Float32(count - 1) * gap }
}

private func adaptiveHeightSum(values: Array<Float32>): Float32 {
    var total: Float32 = 0.0
    for (value in values) { total += value }
    total
}
