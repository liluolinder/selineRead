package chui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import chui.core.{State, Theme, UiContext}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func tableCustomCellPainterFollowsDisplayOrder(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let painted = State<String>("")
    let painter: (UiContext, Int64, String, Rect) -> Unit = {
        _, row, value, cell =>
        painted.value = painted.value + "(${row}:${value}@${Int64(cell.x)})"
    }
    let columns: Array<TableColumn> = [
        TableColumn("名称", 100.0),
        TableColumn("进度", 120.0, numeric: true, cell: painter)
    ]
    let rows: Array<Array<String>> = [["乙", "30%"], ["甲", "90%"], ["丙", "60%"]]
    let table = Table(columns, rows, selected, key: "cells")
    table.layout(ctx, Rect(0.0, 0.0, 260.0, 200.0))

    table.draw(ctx)
    @Expect(painted.value, "(0:30%@100)(1:90%@100)(2:60%@100)")

    // Sort by the progress column (numeric ascending): the painter runs in the new display
    // order, each invocation still pairing an original row index with its own value.
    let _ = table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 10.0))
    painted.value = ""
    table.draw(ctx)
    @Expect(painted.value, "(0:30%@100)(2:60%@100)(1:90%@100)")
}

// SegmentedControl joins the focus ring: Left/Right switch the selected segment while it
// holds focus (clamped at the ends) and pass through untouched otherwise.
@Test
func tableSortsNumericColumnByValue(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0), TableColumn("负载", 80.0, numeric: true)]
    // original indices — 0:"10", 1:"9", 2:"100"; numeric order is 9 < 10 < 100.
    let rows = [["B", "10"], ["A", "9"], ["C", "100"]]
    let table = Table(columns, rows, selected, key: "servers")
    table.layout(ctx, Rect(0.0, 0.0, 200.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0))) // sort by 负载, asc
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1)) // smallest load "9" — lexical sort would pick "10" (index 0)
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(2)) // largest load "100"

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0))) // toggle to desc
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(2)) // largest first
}

// A text sort reorders the display, but the selection follows its row (stored by original index),
// and Up/Down move through the sorted order.
@Test
func tableSelectionFollowsRowAcrossSort(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0) // original row 0 = "B"
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "names")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C
    @Expect(selected.value, Int64(0)) // still the "B" row, now at display position 1

    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(2)) // "C"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, Int64(0)) // back to "B"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, Int64(1)) // "A" at the top
}

// A press on a body row selects the row shown there, mapping the display position back through
// the active sort to the original index.
@Test
func tableRowClickSelectsThroughSort(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "names2")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C
    // Body starts at y=32 with 28px rows; display pos 0 = "A" (original index 1).
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 40.0)))
    @Expect(selected.value, Int64(1))
    // Display pos 2 = "C" (original index 2).
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 100.0)))
    @Expect(selected.value, Int64(2))
}

// A selection moved from outside the list (e.g. app-level key routing) must still scroll into
// view on the next draw, and a redraw with unchanged selection must not move the scroll (no bounce).
@Test
func tableDownFromNoSelectionSelectsFirstRow(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "names3")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))
    ctx.focus("names3")

    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(0)) // unsorted display position 0 = original index 0
}

// The sort-order cache must still reflect live cell edits: after sorting, editing a cell so a
// different row sorts first must change the order on the next frame. This guards the cache's
// invalidation — a stale cache would keep the old order and select the wrong row.
@Test
func tableSortCacheReflectsCellEdits(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "editcache")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    // Sort ascending: A(1), B(0), C(2). Home selects the first, "A" = original index 1.
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0)))
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1))

    // Edit the data in place so "A" becomes "Z"; ascending order is now B(0), C(2), Z(1).
    rows[1][0] = "Z"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(0)) // first is now "B" = original index 0, not the stale "A" (1)

    // And End reflects the edit too: largest is now "Z" = original index 1.
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(1))
}

// A row-count change must invalidate the cached order rather than index past the new bounds.
@Test
func tableSortCacheHandlesRowCountChange(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"], ["D"]]
    let table = Table(columns, rows, selected, key: "countcache")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C,D
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(3)) // "D" = original index 3

    // A shorter dataset through the same table id: End must land within the new bounds.
    let shorter = [["B"], ["A"]]
    let table2 = Table(columns, shorter, selected, key: "countcache")
    table2.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))
    @Expect(table2.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0)))
    @Expect(table2.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(0)) // sorted A,B -> last is "B" = original index 0
}

struct TestServer {
    let name: String
    let load: Int64

    init(name: String, load: Int64) {
        this.name = name
        this.load = load
    }
}

// `Table.of` builds a table from typed data via per-column value extractors; sorting and selection
// then work exactly as for the raw string form, so no hand-built string matrix is needed.
@Test
func tableOfSortsThroughTypedExtractors(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let servers = [TestServer("B", 10), TestServer("A", 9), TestServer("C", 100)]
    let table = Table.of<TestServer>(servers, [
        DataColumn<TestServer>("名称", 120.0) {s => s.name},
        DataColumn<TestServer>("负载", 80.0, numeric: true) {s => "${s.load}"}
    ], selected, key: "of.table")
    table.layout(ctx, Rect(0.0, 0.0, 220.0, 200.0))

    // Sort by the numeric 负载 column (x in [120, 200)); Home selects the smallest load.
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0)))
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1)) // "A"/load 9 = original index 1 (numeric, not lexical)
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(2)) // "C"/load 100 = original index 2
}

// ListView/SegmentedControl/TabView now accept an optional explicit id (previously auto-only, so
// their identity was unaddressable); when given, it becomes the control's focus/state identity.
