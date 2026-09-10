package chui.controls

import sdl.{Color, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent}
import chui.core.{AnimationSpec, Animator, Bindable, CUI_SMALL_H, ComponentControlAppearance,
    ComponentControlKind, ComponentControlState, ComponentControlStyle, ControlContentEnvironment, ControlSemantics,
    CursorShape, Motion, Overlay, ScrollBar, ScrollMotion, ScrollOptions, SemanticActionKind, State, UiContext,
    Widget, resolveControlKey,
    advanceScrollMotion,
    applyWheelScroll, cancelScrollMotion, claimHoverIfInside, clampScrollOffset, drawSurface,
    drawVerticalScrollBar, emit, handlePointerClick, localState, recordControlSemantics, registerFocusable,
    resolveComponentControlAppearance, scrollBarGutter}

private let DROPDOWN_DEFAULT_W: Float32 = 190.0
private let DROPDOWN_POPUP_PAD: Float32 = 5.0
private let DROPDOWN_GAP: Float32 = 4.0
private let DROPDOWN_MARGIN: Float32 = 4.0
private let DROPDOWN_NO_PRESSED_ROW: Int64 = -1
private let DROPDOWN_CANCELLED_PRESSED_ROW: Int64 = -2

/*
 * A dropdown select: a closed box showing the current item, and, when opened, a popup list
 * floated above the tree via the interactive overlay. Clicking an item selects and closes;
 * clicking outside or pressing Escape dismisses; arrows move the highlight while open. Because
 * the popup is an overlay, its clicks are never stolen by whatever is drawn beneath it.
 *
 * A list taller than the space around the control scrolls inside the popup: mouse wheel, a
 * draggable scrollbar in the standard lane, and arrow keys that keep the highlight in view.
 * The popup opens on whichever side (below, else above) has room, with the selected row
 * scrolled into view.
 */
public class Dropdown <: Widget {
    private let id: String
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private let selectedFace: ?Widget
    private let open: State<Bool>
    // Identifies this control's popup on the overlay stack across per-frame rebuilds, so
    // closing removes exactly its own registration (a dialog beneath it stays open).
    private let overlayOwner: String
    // Scroll offset of the popup list, retained across the per-frame rebuild while open.
    private let popupScroll: State<Float32>
    private let popupBar: ScrollBar
    private let popupScrollMotion: ScrollMotion
    private var scrollPolicy = ScrollOptions.web()
    private let popupAnimator: Animator
    // Retained across rebuilt frames so a popup-row press can be cancelled permanently on move-out.
    private let popupPressedRow: State<Int64>
    private var customStyle: ?ComponentControlStyle
    private var semanticLabel: String
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None) {
        let ident = resolveControlKey(key, "Dropdown")
        this.id = ident
        this.items = items
        this.selected = selected
        this.selectedFace = None
        this.overlayOwner = "Dropdown:${ident}"
        this.open = localState<Bool>("Dropdown:${ident}:open") {false}
        this.popupScroll = localState<Float32>("Dropdown:${ident}:popupScroll") {0.0}
        this.popupBar = ScrollBar("Dropdown:${ident}:popupBar")
        this.popupScrollMotion = localState<ScrollMotion>("Dropdown:${ident}:popup-scroll-motion") {
            ScrollMotion(0.0)
        }.value
        this.popupAnimator = localState<Animator>("Dropdown:${ident}:popup-motion") {Animator(0.0)}.value
        this.popupPressedRow = localState<Int64>("Dropdown:${ident}:popup-pressed-row") {
            DROPDOWN_NO_PRESSED_ROW
        }
        this.customStyle = None
        this.semanticLabel = ""
        registerFocusable(ident)
        emit(this)
    }

    /** Creates a dropdown whose closed face is arbitrary decorative content. Popup rows remain strings. */
    public init(
        items: Array<String>,
        selected: Bindable<Int64>,
        key!: ?String = None,
        selectedContent!: (Int64, String) -> Unit
    ) {
        let ident = resolveControlKey(key, "Dropdown")
        this.id = ident
        this.items = items
        this.selected = selected
        registerFocusable(ident)
        let currentIndex = clampDropdownIndex(selected.value, items.size)
        let currentText = if (items.isEmpty()) { "—" } else { items[currentIndex] }
        this.selectedFace = Some(buildDecorativeControlChild {=> selectedContent(currentIndex, currentText)})
        this.overlayOwner = "Dropdown:${ident}"
        this.open = localState<Bool>("Dropdown:${ident}:open") {false}
        this.popupScroll = localState<Float32>("Dropdown:${ident}:popupScroll") {0.0}
        this.popupBar = ScrollBar("Dropdown:${ident}:popupBar")
        this.popupScrollMotion = localState<ScrollMotion>("Dropdown:${ident}:popup-scroll-motion") {
            ScrollMotion(0.0)
        }.value
        this.popupAnimator = localState<Animator>("Dropdown:${ident}:popup-motion") {Animator(0.0)}.value
        this.popupPressedRow = localState<Int64>("Dropdown:${ident}:popup-pressed-row") {
            DROPDOWN_NO_PRESSED_ROW
        }
        this.customStyle = None
        this.semanticLabel = ""
        emit(this)
    }

    /** Selects smooth/immediate wheel motion, wheel step, duration and easing for the popup list. */
    public func scrollOptions(value: ScrollOptions): Dropdown {
        scrollPolicy = value
        this
    }

    /** Overrides the component theme's state-aware control style. */
    public func controlStyle(value: ComponentControlStyle): Dropdown {
        customStyle = Some(value)
        this
    }

    /** Names this selection field for accessibility and headless semantic inspection. */
    public func accessibilityLabel(value: String): Dropdown {
        semanticLabel = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let spacing = ctx.theme.components.spacing
        let insets = ctx.resolve(spacing.controlPadding)
        let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
        let content = match (selectedFace) {
            case Some(value) => value.measure(ctx, Size(max(0.0, available.w - insets.horizontal() - 20.0),
                max(0.0, available.h - insets.vertical())))
            case None => Size(ctx.renderer.textWidth(currentLabel(), pointSize: pointSize),
                ctx.renderer.textHeight(pointSize: pointSize))
        }
        Size(min(available.w, max(DROPDOWN_DEFAULT_W, content.w + insets.horizontal() + 20.0)),
            min(available.h, max(spacing.controlMinHeight, content.h + insets.vertical())))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        match (selectedFace) {
            case Some(value) => value.layout(ctx, labelArea(ctx))
            case None => ()
        }
    }

    public func draw(ctx: UiContext): Unit {
        let appearance = currentAppearance(ctx)
        drawSurface(ctx, frame, appearance.surface)
        recordControlSemantics(ctx, frame, "Dropdown", ControlSemantics(
            "combobox",
            label: if (semanticLabel.isEmpty()) { currentLabel() } else { semanticLabel },
            value: currentLabel(),
            action: "Dropdown.open()",
            actionOwner: id,
            expanded: Some(open.value),
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))
        let content = labelArea(ctx)
        ctx.renderer.pushClip(content)
        match (selectedFace) {
            case Some(value) => ctx.withControlContentEnvironment(ControlContentEnvironment(
                appearance.foreground,
                role: "combobox",
                interactionOwner: id,
                selected: true,
                expanded: open.value,
                focused: ctx.hasFocus(id),
                hovered: ctx.isHovered(id),
                pressed: ctx.isPressed(id)
            )) {=> value.draw(ctx)}
            case None =>
                let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
                let textY = content.centerY() - ctx.renderer.textHeight(pointSize: pointSize) / 2.0
                ctx.renderer.text(currentLabel(), content.x, textY, appearance.foreground, pointSize: pointSize)
        }
        ctx.renderer.popClip()
        let popupProgress = popupAnimator.animate(ctx, target: if (open.value) { 1.0 } else { 0.0 },
            spec: AnimationSpec.automatic(duration: Motion.normal, easing: Motion.decelerate))
        drawChevron(ctx, popupProgress, appearance.indicator)

        // While open, register the popup as the interactive overlay: it is drawn on top and
        // gets events before the tree (see the shell's dispatch order).
        if (open.value || popupProgress > 0.001) {
            let popup = popupRect(ctx)
            if (open.value) {
                advanceScrollMotion(ctx, popupScrollMotion, popupScroll, contentHeight(), listHeight(popup),
                    scrollPolicy)
            }
            let visible = animatedPopupRect(popup, popupProgress)
            ctx.setOverlay(Overlay(handleEvent: {c, e => if (open.value) {
                handleOverlay(c, e, popup)
            } else {
                false
            }}, render: {c => drawPopup(c, popup, visible, popupProgress)}, owner: overlayOwner))
        } else {
            ctx.removeOverlay(overlayOwner)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let appearance = currentAppearance(ctx)
        if (handlePointerClick(ctx, event, frame, id, {=> openPopup(ctx)},
            inkRadius: appearance.focusRadius, inkColor: Some(appearance.ink))) {
            return true
        }
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Space, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Down, _) => return openIfFocused(ctx)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func openIfFocused(ctx: UiContext): Bool {
        if (ctx.hasFocus(id)) {
            openPopup(ctx)
            return true
        }
        false
    }

    // Opens the popup with the selected row scrolled into view (centred when the list is
    // long), so reopening never lands far from the current value.
    private func openPopup(ctx: UiContext): Unit {
        resetPopupPress(ctx)
        open.value = true
        let listH = listHeight(popupRect(ctx))
        let target = Float32(selected.value) * CUI_SMALL_H - (listH - CUI_SMALL_H) / 2.0
        popupScroll.value = clampScrollOffset(target, contentHeight(), listH)
        cancelScrollMotion(popupScrollMotion, popupScroll)
    }

    private func contentHeight(): Float32 {
        Float32(items.size) * CUI_SMALL_H
    }

    private func listHeight(popup: Rect): Float32 {
        max(0.0, popup.h - DROPDOWN_POPUP_PAD * 2.0)
    }

    /** The inner list area: the popup minus its top and bottom padding strips. */
    private func listRect(popup: Rect): Rect {
        Rect(popup.x, popup.y + DROPDOWN_POPUP_PAD, popup.w, listHeight(popup))
    }

    // The overlay event handler while the popup is open. Runs before the tree, so it can claim
    // clicks that land on the popup and dismiss on clicks that land elsewhere.
    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                resetPopupPress(ctx)
                if (popup.contains(x, y)) {
                    if (popupBar.press(ctx, listRect(popup), popupScroll, contentHeight(), listHeight(popup), x, y)) {
                        cancelScrollMotion(popupScrollMotion, popupScroll)
                        return true // the press grabbed the scrollbar; the popup stays open
                    }
                    let index = itemIndexAt(popup, y)
                    if (index >= 0 && index < items.size) {
                        let row = itemRectAt(popup, index)
                        if (row.contains(x, y)) {
                            popupPressedRow.value = index
                            let pressId = popupRowPressId(index)
                            ctx.press(pressId)
                            ctx.startInkRipple(pressId, row, x, y, color: Some(ctx.theme.inkColor()),
                                cornerRadius: ctx.theme.components.shape.resolvedSmall(ctx.theme))
                            return true
                        }
                    }
                }
                close(ctx) // dismiss on an outside click or a popup padding press
                true
            case UiEvent.MouseMove(x, y) =>
                // While the thumb is grabbed the move scrolls the list; hover falls through, though the
                // popup still claims the default cursor so a control beneath cannot set its shape through it.
                if (popup.contains(x, y)) {
                    ctx.claimHover(overlayOwner, CursorShape.Default)
                }
                let dragged = popupBar.drag(ctx, listRect(popup), popupScroll, contentHeight(), listHeight(popup), y)
                if (dragged) {
                    cancelScrollMotion(popupScrollMotion, popupScroll)
                    return true
                }
                let pressed = popupPressedRow.value
                if (pressed >= 0) {
                    let pressId = popupRowPressId(pressed)
                    if (ctx.isPressed(pressId) && !itemRectAt(popup, pressed).contains(x, y)) {
                        ctx.cancelPress(pressId)
                        ctx.cancelInkRipple(pressId)
                        popupPressedRow.value = DROPDOWN_CANCELLED_PRESSED_ROW
                    }
                    return true
                }
                false
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                let pressed = popupPressedRow.value
                if (pressed >= 0) {
                    let pressId = popupRowPressId(pressed)
                    let shouldSelect = ctx.isPressed(pressId) && itemRectAt(popup, pressed).contains(x, y)
                    ctx.cancelPress(pressId)
                    popupPressedRow.value = DROPDOWN_NO_PRESSED_ROW
                    if (shouldSelect) {
                        selected.value = pressed
                        close(ctx)
                    } else {
                        ctx.cancelInkRipple(pressId)
                    }
                    return true
                }
                if (pressed == DROPDOWN_CANCELLED_PRESSED_ROW) {
                    popupPressedRow.value = DROPDOWN_NO_PRESSED_ROW
                    return true
                }
                false
            case UiEvent.MouseWheel(_, wheelY, x, y) =>
                if (popup.contains(x, y)) {
                    applyWheelScroll(ctx, popupScrollMotion, popupScroll, wheelY, contentHeight(), listHeight(popup),
                        scrollPolicy)
                    return true
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Space, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                moveHighlight(1, popup)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                moveHighlight(-1, popup)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit and let the shell's Tab traversal move focus on
                false
            case _ => false
        }
    }

    private func close(ctx: UiContext): Unit {
        resetPopupPress(ctx)
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    private func resetPopupPress(ctx: UiContext): Unit {
        let pressed = popupPressedRow.value
        if (pressed >= 0) {
            let pressId = popupRowPressId(pressed)
            ctx.cancelPress(pressId)
            ctx.cancelInkRipple(pressId)
        }
        if (pressed != DROPDOWN_NO_PRESSED_ROW) {
            popupPressedRow.value = DROPDOWN_NO_PRESSED_ROW
        }
    }

    private func popupRowPressId(index: Int64): String {
        "${overlayOwner}:row:${index}"
    }

    private func moveHighlight(delta: Int64, popup: Rect): Unit {
        if (items.isEmpty()) {
            return
        }
        // Clamp the current index into range before stepping (matching SegmentedControl/TabView),
        // so the move is relative to the displayed selection and the addition cannot overflow.
        selected.value = clampDropdownIndex(clampDropdownIndex(selected.value, items.size) + delta, items.size)
        revealRow(selected.value, popup)
    }

    // Scrolls just enough to keep the highlighted row visible — the reveal convention
    // shared with ListView and Table keyboard navigation.
    private func revealRow(index: Int64, popup: Rect): Unit {
        let listH = listHeight(popup)
        let rowTop = Float32(index) * CUI_SMALL_H
        var next = popupScroll.value
        if (rowTop < next) {
            next = rowTop
        }
        if (rowTop + CUI_SMALL_H > next + listH) {
            next = rowTop + CUI_SMALL_H - listH
        }
        let clamped = clampScrollOffset(next, contentHeight(), listH)
        if (clamped != popupScroll.value) {
            popupScroll.value = clamped
        }
        // Keyboard navigation owns the visible row even when no offset write was needed.
        // Cancel a retained wheel target so it cannot move the highlight away next frame.
        cancelScrollMotion(popupScrollMotion, popupScroll)
    }

    // Maps a pointer y inside the popup to an item index, honouring the scroll offset.
    // The padding strips above and below the list hit nothing (-1).
    private func itemIndexAt(popup: Rect, y: Float32): Int64 {
        if (y < popup.y + DROPDOWN_POPUP_PAD || y >= popup.bottom() - DROPDOWN_POPUP_PAD) {
            return -1
        }
        Int64((y - popup.y - DROPDOWN_POPUP_PAD + popupScroll.value) / CUI_SMALL_H)
    }

    private func itemRectAt(popup: Rect, index: Int64): Rect {
        let listH = listHeight(popup)
        let gutter: Float32 = if (contentHeight() > listH) {
            scrollBarGutter()
        } else {
            0.0
        }
        Rect(popup.x + 4.0,
            popup.y + DROPDOWN_POPUP_PAD + Float32(index) * CUI_SMALL_H - popupScroll.value,
            max(0.0, popup.w - 8.0 - gutter), CUI_SMALL_H)
    }

    /*
     * Anchors the popup below the control, flipping above when only the space above fits the
     * whole list. When neither side fits, it opens on the roomier side at that side's height
     * and the list scrolls inside (see drawPopup).
     */
    private func popupRect(ctx: UiContext): Rect {
        let fullHeight = contentHeight() + DROPDOWN_POPUP_PAD * 2.0
        let below = max(0.0, ctx.viewportHeight - DROPDOWN_MARGIN - (frame.bottom() + DROPDOWN_GAP))
        let above = max(0.0, frame.y - DROPDOWN_GAP - DROPDOWN_MARGIN)
        if (fullHeight <= below) {
            return Rect(frame.x, frame.bottom() + DROPDOWN_GAP, frame.w, fullHeight)
        }
        if (fullHeight <= above) {
            return Rect(frame.x, frame.y - DROPDOWN_GAP - fullHeight, frame.w, fullHeight)
        }
        let height = max(CUI_SMALL_H + DROPDOWN_POPUP_PAD * 2.0, max(below, above))
        if (below >= above) {
            Rect(frame.x, frame.bottom() + DROPDOWN_GAP, frame.w, height)
        } else {
            Rect(frame.x, frame.y - DROPDOWN_GAP - height, frame.w, height)
        }
    }

    private func drawPopup(ctx: UiContext, popup: Rect, visible: Rect, progress: Float32): Unit {
        if (visible.h <= 0.001) {
            return
        }
        drawSurface(ctx, visible, popupSurface(ctx))
        let contentH = contentHeight()
        let listH = listHeight(popup)
        let list = listRect(popup)
        // The item set can change while open; keep the retained offset within range.
        let offset = clampScrollOffset(popupScroll.value, contentH, listH)
        if (offset != popupScroll.value) {
            popupScroll.value = offset
            cancelScrollMotion(popupScrollMotion, popupScroll)
        }
        ctx.renderer.pushClip(visible)
        ctx.renderer.pushClip(list)
        var i = Int64(offset / CUI_SMALL_H)
        var y = list.y - (offset - Float32(i) * CUI_SMALL_H)
        while (i < items.size && y < list.bottom()) {
            let row = itemRectAt(popup, i)
            if (i == selected.value) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.components.shape.resolvedSmall(ctx.theme),
                    ctx.theme.accent)
                drawRowLabel(ctx, items[i], row, ctx.theme.accentText)
            } else if (row.contains(ctx.mouseX, ctx.mouseY)) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.components.shape.resolvedSmall(ctx.theme),
                    ctx.theme.fieldActive)
                drawRowLabel(ctx, items[i], row, ctx.theme.text)
            } else {
                drawRowLabel(ctx, items[i], row, ctx.theme.text)
            }
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
        ctx.renderer.popClip()
        if (progress > 0.85) {
            drawVerticalScrollBar(ctx, list, offset, contentH, listH, active: popupBar.dragging(ctx))
        }
    }

    // A down chevron drawn as two strokes, so it never depends on a font glyph.
    private func drawChevron(ctx: UiContext, progress: Float32, color: Color): Unit {
        let cx = frame.right() - 18.0
        let cy = frame.centerY()
        let pen = Pen(width: 1.6, color: color)
        let tipY = cy + 2.5 - 5.0 * progress
        let edgeY = cy - 2.0 + 4.0 * progress
        ctx.renderer.strokeLine(cx - 4.0, edgeY, cx, tipY, pen)
        ctx.renderer.strokeLine(cx, tipY, cx + 4.0, edgeY, pen)
    }

    private func drawRowLabel(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
        let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
        let textY = row.centerY() - ctx.renderer.textHeight(pointSize: pointSize) / 2.0
        ctx.renderer.text(text, row.x + 8.0, textY, color, pointSize: pointSize)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge,
            radius: ctx.theme.components.shape.resolvedControl(ctx.theme),
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }

    private func animatedPopupRect(popup: Rect, progress: Float32): Rect {
        let eased = max(0.0, min(1.0, progress))
        let height = popup.h * eased
        if (popup.y >= frame.bottom()) {
            Rect(popup.x, popup.y, popup.w, height)
        } else {
            Rect(popup.x, popup.bottom() - height, popup.w, height)
        }
    }

    private func currentLabel(): String {
        if (items.isEmpty()) {
            "—"
        } else {
            items[clampDropdownIndex(selected.value, items.size)]
        }
    }

    public func isFlexible(): Bool {
        false
    }

    private func labelArea(ctx: UiContext): Rect {
        let insets = ctx.resolve(ctx.theme.components.spacing.controlPadding)
        Rect(frame.x + insets.left, frame.y + insets.top,
            max(0.0, frame.w - insets.horizontal() - 20.0),
            max(0.0, frame.h - insets.vertical()))
    }

    private func currentAppearance(ctx: UiContext): ComponentControlAppearance {
        resolveComponentControlAppearance(ctx.theme, ComponentControlKind.Dropdown,
            ComponentControlState(
                hover: if (ctx.isHovered(id)) { 1.0 } else { 0.0 },
                press: if (ctx.isPressed(id)) { 1.0 } else { 0.0 },
                focused: ctx.hasFocus(id),
                selected: false,
                expanded: open.value
            ), styleOverride: customStyle)
    }
}

private func clampDropdownIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0) {
        0
    } else if (index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
