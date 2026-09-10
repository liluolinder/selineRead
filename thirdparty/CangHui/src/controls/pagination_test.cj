package chui.controls

import sdl.{MouseButton, Rect, Renderer, Size, UiEvent}
import chui.core.{InteractionSurface, State, Theme, UiContext}

// Row centre-y for a 34px-tall control laid at y=0.
private let PAGE_CY: Float32 = 17.0

private func paginationTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

@Test
func paginationItemsWindowsWithEllipsis(): Unit {
    @Expect(paginationItems(1, 0, 1), [0])
    @Expect(paginationItems(5, 2, 1), [0, 1, 2, 3, 4]) // few pages: all shown
    @Expect(paginationItems(20, 10, 1), [0, -1, 9, 10, 11, -1, 19]) // middle: gaps both sides
    @Expect(paginationItems(20, 0, 1), [0, 1, -1, 19]) // near the start: one gap on the right
    @Expect(paginationItems(20, 19, 1), [0, -1, 18, 19]) // near the end: one gap on the left
}

@Test
func clampPageClampsIntoRange(): Unit {
    @Expect(clampPage(-5, 10), 0)
    @Expect(clampPage(20, 10), 9)
    @Expect(clampPage(3, 10), 3)
}

@Test
func paginationPageClickJumps(): Unit {
    let ctx = paginationTestContext()
    let page = State<Int64>(5)
    let pag = Pagination(20, page, window: 1) // items [0, -1, 4, 5, 6, -1, 19]
    pag.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    // item 0 (page 1 displayed) sits at x 38..72; clicking it jumps to page 0.
    @Expect(pag.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 55.0, PAGE_CY)))
    @Expect(page.value, 5)
    @Expect(pag.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 55.0, PAGE_CY)))
    @Expect(page.value, 0)
}

@Test
func paginationPrevNextStepByOne(): Unit {
    let ctx = paginationTestContext()
    let back = State<Int64>(5)
    let pagBack = Pagination(20, back)
    pagBack.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    // The prev arrow occupies x 0..34.
    @Expect(pagBack.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 17.0, PAGE_CY)))
    @Expect(pagBack.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 17.0, PAGE_CY)))
    @Expect(back.value, 4)

    let fwd = State<Int64>(5)
    let pagFwd = Pagination(20, fwd) // items [0,-1,4,5,6,-1,19] → next arrow at x 304..338
    pagFwd.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    @Expect(pagFwd.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 321.0, PAGE_CY)))
    @Expect(pagFwd.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 321.0, PAGE_CY)))
    @Expect(fwd.value, 6)
}

@Test
func paginationArrowsClampAtEnds(): Unit {
    let ctx = paginationTestContext()
    let first = State<Int64>(0)
    let pagFirst = Pagination(20, first)
    pagFirst.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    // Prev at the first page is consumed but does not move before page 0.
    @Expect(pagFirst.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 17.0, PAGE_CY)))
    @Expect(first.value, 0)
}

@Test
func paginationEllipsisIsNotClickable(): Unit {
    let ctx = paginationTestContext()
    let page = State<Int64>(10)
    let pag = Pagination(20, page) // items [0, -1, 9, 10, 11, -1, 19]; item 1 is the ellipsis at x 76..110
    pag.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    @Expect(!pag.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 93.0, PAGE_CY)))
    @Expect(page.value, 10)
}

@Test
func paginationRefreshesItsWindowAfterExternalPageChange(): Unit {
    let ctx = paginationTestContext()
    let page = State<Int64>(0)
    let pag = Pagination(20, page, window: 1, key: "dynamic-window")
    pag.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    // Moving to page 11 (zero-based 10) must rebuild the visible window to
    // [0, -1, 9, 10, 11, -1, 19]. Page 12 then occupies x 190..224.
    page.value = 10
    @Expect(pag.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 207.0, PAGE_CY)))
    @Expect(pag.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 207.0, PAGE_CY)))
    @Expect(page.value, 11)
}

@Test
func paginationKeepsStableWidthAcrossWindowChanges(): Unit {
    let ctx = paginationTestContext()
    let first = Pagination(20, State<Int64>(0), window: 1, key: "first")
    let middle = Pagination(20, State<Int64>(10), window: 1, key: "middle")
    @Expect(first.measure(ctx, Size(800.0, 100.0)).w, middle.measure(ctx, Size(800.0, 100.0)).w)
}

@Test
func paginationPublishesItsPointerOwner(): Unit {
    let pagination = Pagination(5, State<Int64>(0), key: "pages")
    @Expect(pagination.interactionOwnerIds(), ["pages"])
}

@Test
func interactionSurfaceRejectsPointerOnlyBuiltInControl(): Unit {
    let surface = InteractionSurface(action: {=> ()}, key: Some("outer")) {
        Pagination(5, State<Int64>(0), key: "pages")
    }
    @Expect(surface.structuralDiagnostic(), Some("nested-interaction-owner: pages"))
}

@Test
func paginationMoveOutCancelsPageChange(): Unit {
    let ctx = paginationTestContext()
    let page = State<Int64>(5)
    let pag = Pagination(20, page, window: 1, key: "cancel")
    pag.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    @Expect(pag.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 55.0, PAGE_CY)))
    let _ = pag.handle(ctx, UiEvent.MouseMove(500.0, 100.0))
    @Expect(!pag.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 55.0, PAGE_CY)))
    @Expect(page.value, Int64(5))
}
