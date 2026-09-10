package chui.text

import sdl.{Color, FontSizes, Key, MouseButton, Pen, Point, Rect, Size, TextCompositionEvent,
    TextCompositionPhase, UiEvent}
import sdl.input.{Clipboard, Keyboard}
import chui.core.{Bindable, ControlSemantics, CUI_SMALL_H, CursorShape, HScrollBar, ScrollBar, ScrollMotion,
    ScrollOptions, SemanticActionKind, maxScrollOffset, Observable, State, UiContext, Widget, advanceScrollMotion,
    applyWheelScroll, cancelScrollMotion, claimHoverIfInside, clampScrollOffset, drawHorizontalScrollBar,
    drawSurface, drawVerticalScrollBar, emit, localState, recordControlSemantics, registerFocusable,
    resolveControlKey, scrollLineIndex, scrollLineRemainder}

// SDL reports letter keys as their uppercase ASCII code (see the Ctrl+letter shortcuts).
private let AREA_LETTER_A: UInt8 = 65
private let AREA_LETTER_C: UInt8 = 67
private let AREA_LETTER_V: UInt8 = 86
private let AREA_LETTER_X: UInt8 = 88
private let AREA_LETTER_Y: UInt8 = 89
private let AREA_LETTER_Z: UInt8 = 90

/** Controls whether a TextArea paints its ordinary field surface. */
public enum TextAreaChrome {
    | Field
    | None
}

/** Controls how logical lines map to visual rows. Soft wrapping is intentionally not implied. */
public enum TextAreaWrapMode {
    | NoWrap
}

/** A non-durable IME preedit transaction owned by one TextArea identity. */
public struct TextCompositionSnapshot {
    public let active: Bool
    public let preedit: String
    /** Selected/caret range inside `preedit`, counted in UTF-8 characters. */
    public let selectionStart: Int64
    public let selectionLength: Int64
    /** Half-open exact UTF-8 byte range in the durable document. */
    public let replacementStartByte: Int64
    public let replacementEndByte: Int64
    public let documentRevision: UInt64
    public let generation: UInt64

    public init(
        active!: Bool = false,
        preedit!: String = "",
        selectionStart!: Int64 = 0,
        selectionLength!: Int64 = 0,
        replacementStartByte!: Int64 = 0,
        replacementEndByte!: Int64 = 0,
        documentRevision!: UInt64 = UInt64(0),
        generation!: UInt64 = UInt64(0)
    ) {
        this.active = active
        this.preedit = preedit
        this.selectionStart = max(Int64(0), selectionStart)
        this.selectionLength = max(Int64(0), selectionLength)
        this.replacementStartByte = max(Int64(0), replacementStartByte)
        this.replacementEndByte = max(this.replacementStartByte, replacementEndByte)
        this.documentRevision = documentRevision
        this.generation = generation
    }
}

private let TEXT_AREA_CARET_RESERVE: Float32 = 2.0

/*
 * Caches a document's line split so scrolling does not re-split the whole text every frame. Keyed
 * by the text's revision: an edit bumps the revision (see Observable.revision), which refreshes the
 * split on next access, so the cache never serves stale lines. Splitting is already the fast
 * primitive here (stdlib split beats a hand-rolled byte scan), so the win is not re-doing it.
 */
class TextLineCache {
    private var cachedRevision: UInt64 = 0
    private var cachedLines: Array<String> = []
    private var hasValue = false
    private var cachedWidthRevision: UInt64 = 0
    private var cachedMetricWidth: Float32 = -1.0
    private var cachedMetricHeight: Float32 = -1.0
    private var cachedMaxWidth: Float32 = 0.0
    private var hasWidth = false

    func lines(text: String, revision: UInt64): Array<String> {
        if (!hasValue || revision != cachedRevision) {
            cachedLines = text.split("\n")
            cachedRevision = revision
            hasValue = true
        }
        cachedLines
    }

    /*
     * Measures all logical lines only when the document or active font metrics change. The compact
     * mixed-script probe distinguishes common font/DPI changes without making the renderer expose
     * a backend-specific font identity.
     */
    func maxLineWidth(ctx: UiContext, lines: Array<String>, revision: UInt64): Float32 {
        let metricWidth = ctx.renderer.textWidth("M你\t", pointSize: FontSizes.BODY)
        let metricHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
        if (!hasWidth || revision != cachedWidthRevision || metricWidth != cachedMetricWidth ||
            metricHeight != cachedMetricHeight) {
            var widest: Float32 = 0.0
            for (line in lines) {
                widest = max(widest, ctx.renderer.textWidth(line, pointSize: FontSizes.BODY))
            }
            cachedMaxWidth = widest + TEXT_AREA_CARET_RESERVE
            cachedWidthRevision = revision
            cachedMetricWidth = metricWidth
            cachedMetricHeight = metricHeight
            hasWidth = true
        }
        cachedMaxWidth
    }
}

/*
 * A no-wrap multi-line text editor bound to a `Bindable<String>`, with dual-axis scrolling.
 * As in `TextField`, the caret and selection anchor are BYTE offsets into the UTF-8 text; an owner
 * that moves the cursor from outside (loading a file, a programmatic paste) must move the anchor with
 * it, or the next keystroke replaces a selection the user never made. The document's line split is
 * cached by the text's revision; the widest line is cached by revision and font metrics, so
 * scrolling neither re-splits nor re-measures the whole document every frame.
 * `editable: false` renders read-only and stays out of Tab traversal.
 */
public class TextArea <: Widget {
    private let id: String
    private let text: Bindable<String>
    private var scrollStateValue: State<Float32>
    private var horizontalScrollStateValue: State<Float32>
    private var cursorStateValue: State<Int64>
    private var anchorStateValue: State<Int64>
    private var compositionStateValue: State<TextCompositionSnapshot>
    private var isEditable: Bool
    private var semanticLabel: String
    private var chromeMode: TextAreaChrome
    private var wrapModeValue: TextAreaWrapMode
    private var showsVerticalScrollBar = true
    private var showsHorizontalScrollBar = true
    private let scrollBar: ScrollBar
    private let hScrollBar: HScrollBar
    private let scrollMotion: ScrollMotion
    private let horizontalScrollMotion: ScrollMotion
    private var scrollPolicy = ScrollOptions.web()
    private let history: UndoHistory
    private let lineCache: TextLineCache
    private let decorationCache: TextAreaDecorationCache
    private var decorationSource: ?Observable<TextAreaDecorationSnapshot>
    private var autofocusRequested = false
    private let autofocusDone: State<Bool>
    private let lastObservedCursor: State<Int64>
    private var frame = Rect.zero()

    public init(
        text: Bindable<String>,
        key!: ?String = None,
        scroll!: ?State<Float32> = None,
        horizontalScroll!: ?State<Float32> = None,
        cursor!: ?State<Int64> = None,
        anchor!: ?State<Int64> = None,
        composition!: ?State<TextCompositionSnapshot> = None,
        editable!: Bool = true,
        chrome!: TextAreaChrome = TextAreaChrome.Field,
        wrapMode!: TextAreaWrapMode = TextAreaWrapMode.NoWrap,
        decorations!: ?Observable<TextAreaDecorationSnapshot> = None
    ) {
        let ident = resolveControlKey(key, "TextArea")
        this.id = ident
        this.text = text
        let initialScroll = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("TextArea:${ident}:scroll") {0.0}
        }
        this.scrollStateValue = initialScroll
        let initialHorizontalScroll = match (horizontalScroll) {
            case Some(value) => value
            case None => localState<Float32>("TextArea:${ident}:horizontal-scroll") {0.0}
        }
        this.horizontalScrollStateValue = initialHorizontalScroll
        this.cursorStateValue = match (cursor) {
            case Some(value) => value
            case None => localState<Int64>("TextArea:${ident}:cursor") {text.value.size}
        }
        // The anchor starts collapsed on the caret so no phantom selection appears. A caller
        // that owns the cursor and moves it from outside (loading a file, a programmatic
        // paste) must own the anchor too and move both together — otherwise the stale anchor
        // spans a selection the user never made, and the next keystroke replaces it.
        let caretStart = cursorStateValue.value
        this.anchorStateValue = match (anchor) {
            case Some(value) => value
            case None => localState<Int64>("TextArea:${ident}:anchor") {caretStart}
        }
        this.compositionStateValue = match (composition) {
            case Some(value) => value
            case None => localState<TextCompositionSnapshot>("TextArea:${ident}:composition") {
                TextCompositionSnapshot()
            }
        }
        this.isEditable = editable
        this.semanticLabel = ""
        this.chromeMode = chrome
        this.wrapModeValue = wrapMode
        this.scrollBar = ScrollBar("TextArea:${ident}:thumb")
        this.hScrollBar = HScrollBar("TextArea:${ident}:horizontal-thumb")
        this.scrollMotion = localState<ScrollMotion>("TextArea:${ident}:scroll-motion") {
            ScrollMotion(initialScroll.value)
        }.value
        this.horizontalScrollMotion = localState<ScrollMotion>("TextArea:${ident}:horizontal-scroll-motion") {
            ScrollMotion(initialHorizontalScroll.value)
        }.value
        this.history = localState<UndoHistory>("TextArea:${ident}:history") {UndoHistory()}.value
        this.lineCache = localState<TextLineCache>("TextArea:${ident}:lines") {TextLineCache()}.value
        this.decorationCache = localState<TextAreaDecorationCache>("TextArea:${ident}:decorations") {
            TextAreaDecorationCache()
        }.value
        this.decorationSource = decorations
        this.autofocusDone = localState<Bool>("TextArea:${ident}:autofocused") {false}
        this.lastObservedCursor = localState<Int64>("TextArea:${ident}:last-observed-cursor") {-1}
        // A read-only text area is not an editing stop, so it stays out of Tab traversal.
        if (editable) {
            registerFocusable(ident)
        }
        emit(this)
    }

    /** Selects smooth/immediate wheel motion, wheel step, duration and easing. */
    public func scrollOptions(value: ScrollOptions): TextArea {
        scrollPolicy = value
        this
    }

    /** Selects ordinary field chrome or a chrome-free surface for embedded editor parts. */
    public func chrome(value: TextAreaChrome): TextArea {
        chromeMode = value
        this
    }

    /** Uses an externally owned horizontal offset, enabling restoration and editor coordination. */
    public func horizontalScrollState(value: State<Float32>): TextArea {
        horizontalScrollStateValue = value
        this
    }

    /** Selects the logical-line layout contract; currently only explicit no-wrap is supported. */
    public func wrapMode(value: TextAreaWrapMode): TextArea {
        wrapModeValue = value
        this
    }

    /** Shows or hides the vertical indicator without disabling vertical scrolling. */
    public func verticalScrollBar(visible: Bool): TextArea {
        showsVerticalScrollBar = visible
        this
    }

    /** Shows or hides the horizontal indicator without disabling horizontal scrolling. */
    public func horizontalScrollBar(visible: Bool): TextArea {
        showsHorizontalScrollBar = visible
        this
    }

    /** Applies immutable, revision-bound paint decorations without taking text/edit ownership. */
    public func decorations(value: Observable<TextAreaDecorationSnapshot>): TextArea {
        decorationSource = Some(value)
        this
    }

    /** Overrides the semantic name without changing the rendered document. */
    public func accessibilityLabel(value: String): TextArea {
        semanticLabel = value
        this
    }

    /** Claims keyboard focus the first time an editable area appears (e.g. a compose box). */
    public func autofocus(): TextArea {
        autofocusRequested = true
        this
    }

    /** Reverts the last edit group; also bound to Ctrl+Z. */
    public func undo(): Unit {
        match (history.undo(snapshot())) {
            case Some(state) => applySnapshot(state)
            case None => ()
        }
    }

    /** Reapplies the last undone edit; also bound to Ctrl+Y / Ctrl+Shift+Z. */
    public func redo(): Unit {
        match (history.redo(snapshot())) {
            case Some(state) => applySnapshot(state)
            case None => ()
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let docLines = lines()
        let viewport = textViewport(rect)
        advanceScrollMotion(ctx, scrollMotion, scrollStateValue, textContentHeight(docLines), viewport.h, scrollPolicy)
        advanceScrollMotion(ctx, horizontalScrollMotion, horizontalScrollStateValue,
            contentWidth(ctx, docLines), viewport.w, scrollPolicy)
    }

    // The document split into lines, cached by text revision so scrolling never re-splits per frame.
    private func lines(): Array<String> {
        lineCache.lines(text.value, text.revision)
    }

    private func contentWidth(ctx: UiContext, docLines: Array<String>): Float32 {
        lineCache.maxLineWidth(ctx, docLines, text.revision)
    }

    public func draw(ctx: UiContext): Unit {
        let edit = editState()
        edit.normalizeCursor()
        if (!ctx.hasFocus(id) && compositionStateValue.value.active) {
            clearComposition()
        }
        recordControlSemantics(ctx, frame, "TextArea", ControlSemantics(
            "textarea",
            label: semanticLabel,
            value: text.value,
            action: if (isEditable) { "TextArea.edit()" } else { "" },
            shortcut: if (isEditable) { "TextInput" } else { "" },
            actionOwner: id,
            readOnly: Some(!isEditable),
            focused: Some(ctx.hasFocus(id)),
            editable: Some(isEditable),
            selectionStart: Some(edit.selectionStart()),
            selectionEnd: Some(edit.selectionEnd()),
            typedActions: if (isEditable) { [SemanticActionKind.Focus] } else { [] }
        ))
        let docLines = lines()
        let viewport = textViewport(frame)
        let contentW = contentWidth(ctx, docLines)
        // Clamp writes only on change: draw runs every frame, and the offset may be an
        // externally owned state whose observers should not fire for no-op writes.
        let clampedScroll = clampScrollOffset(scrollStateValue.value, textContentHeight(docLines),
            viewport.h)
        if (clampedScroll != scrollStateValue.value) {
            scrollStateValue.value = clampedScroll
            cancelScrollMotion(scrollMotion, scrollStateValue)
        }
        let clampedHorizontalScroll = clampScrollOffset(horizontalScrollStateValue.value, contentW, viewport.w)
        if (clampedHorizontalScroll != horizontalScrollStateValue.value) {
            horizontalScrollStateValue.value = clampedHorizontalScroll
            cancelScrollMotion(horizontalScrollMotion, horizontalScrollStateValue)
        }
        if (ctx.hasFocus(id) && cursorStateValue.value != lastObservedCursor.value) {
            revealCaret(ctx, contentW, viewport)
        }
        let content = TextAreaContent(text.value, cursorStateValue.value, scrollStateValue.value,
            horizontalScroll: horizontalScrollStateValue.value)
        let firstLine = scrollLineIndex(content.scroll)
        let lastLine = firstLine + Int64(viewport.h / CUI_SMALL_H) + 2
        let decorationRuns = decorationCache.visibleRuns(text.value, text.revision, decorationSource,
            firstLine, lastLine)
        drawTextAreaBox(ctx, frame, id, content, docLines, edit.selectionStart(), edit.selectionEnd(),
            ctx.hasFocus(id), showsVerticalScrollBar, showsHorizontalScrollBar, scrollBar.dragging(ctx),
            hScrollBar.dragging(ctx), chromeMode, wrapModeValue, decorationRuns,
            compositionStateValue.value, text.revision, contentW)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // A read-only area is not an editing target, so it does not request the text cursor.
        if (isEditable) {
            claimHoverIfInside(ctx, event, frame, id, CursorShape.Text)
        }
        let edit = editState()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let docLines = lines()
                let viewport = textViewport(frame)
                if (showsVerticalScrollBar && scrollBar.press(ctx, frame, scrollStateValue, textContentHeight(docLines),
                    viewport.h, x, y)) {
                    cancelScrollMotion(scrollMotion, scrollStateValue)
                    return true
                }
                if (showsHorizontalScrollBar && hScrollBar.press(ctx, frame, horizontalScrollStateValue,
                    contentWidth(ctx, docLines), viewport.w, x, y)) {
                    cancelScrollMotion(horizontalScrollMotion, horizontalScrollStateValue)
                    return true
                }
                return pressAt(ctx, edit, x, y)
            case UiEvent.MouseMove(x, y) =>
                if (showsVerticalScrollBar && scrollBar.drag(ctx, frame, scrollStateValue, textContentHeight(lines()),
                    textViewport(frame).h, y)) {
                    cancelScrollMotion(scrollMotion, scrollStateValue)
                    return true
                }
                if (showsHorizontalScrollBar && hScrollBar.drag(ctx, frame, horizontalScrollStateValue,
                    contentWidth(ctx, lines()), textViewport(frame).w, x)) {
                    cancelScrollMotion(horizontalScrollMotion, horizontalScrollStateValue)
                    return true
                }
                if (ctx.isDragging(id) && ctx.leftMouseDown) {
                    edit.extendTo(pointOffset(ctx, x, y))
                    return true
                }
            case UiEvent.MouseWheel(wheelX, wheelY, pointerX, pointerY) =>
                // Content that fits leaves the wheel to an enclosing scroller (no dead zone).
                let docLines = lines()
                let viewport = textViewport(frame)
                let contentW = contentWidth(ctx, docLines)
                if (frame.contains(pointerX, pointerY) && wheelX != 0.0 &&
                    maxScrollOffset(contentW, viewport.w) > 0.0) {
                    applyWheelScroll(ctx, horizontalScrollMotion, horizontalScrollStateValue, -wheelX,
                        contentW, viewport.w, scrollPolicy)
                    return true
                }
                if (frame.contains(pointerX, pointerY) && Keyboard.modifiers().shift && wheelY != 0.0 &&
                    maxScrollOffset(contentW, viewport.w) > 0.0) {
                    applyWheelScroll(ctx, horizontalScrollMotion, horizontalScrollStateValue, wheelY,
                        contentW, viewport.w, scrollPolicy)
                    return true
                }
                let contentH = textContentHeight(docLines)
                if (frame.contains(pointerX, pointerY) && maxScrollOffset(contentH, viewport.h) > 0.0) {
                    applyWheelScroll(ctx, scrollMotion, scrollStateValue, wheelY, contentH, viewport.h, scrollPolicy)
                    return true
                }
            case UiEvent.TextComposition(value) => return handleComposition(ctx, edit, value)
            case UiEvent.TextInput(value) => return commitComposition(ctx, edit, value)
            case UiEvent.KeyDown(Key.Enter, _) => return recordedEdit(ctx, {=> edit.insert("\n")})
            case UiEvent.KeyDown(Key.Backspace, _) => return recordedEdit(ctx, {=> edit.backspace()})
            case UiEvent.KeyDown(Key.Delete, _) => return recordedEdit(ctx, {=> edit.deleteForward()})
            case UiEvent.KeyDown(Key.Left, _) => return navigate(ctx, {=> edit.moveLeft()}, {=> edit.extendLeft()})
            case UiEvent.KeyDown(Key.Right, _) => return navigate(ctx, {=> edit.moveRight()}, {=> edit.extendRight()})
            case UiEvent.KeyDown(Key.Up, _) => return navigate(ctx, {=> edit.moveLineUp()}, {=> edit.extendLineUp()})
            case UiEvent.KeyDown(Key.Down, _) => return navigate(ctx, {=> edit.moveLineDown()}, {=> edit.extendLineDown()})
            case UiEvent.KeyDown(Key.Home, _) => return navigate(ctx, {=> edit.moveToLineStart()},
                {=> edit.extendToLineStart()})
            case UiEvent.KeyDown(Key.End, _) => return navigate(ctx, {=> edit.moveToLineEnd()},
                {=> edit.extendToLineEnd()})
            case UiEvent.KeyDown(Key.Letter(code), _) => return shortcut(ctx, edit, code)
            case UiEvent.Frame(_) =>
                // One-time initial focus for an editable area, applied after the frame's pointer
                // events so a stray startup click cannot cancel it; mirrors TextField.
                if (autofocusRequested && isEditable && !autofocusDone.value) {
                    ctx.focus(id, viaKeyboard: true)
                    autofocusDone.value = true
                }
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableId(): ?String {
        // A read-only area never registered, so there is nothing for `.enabled` to remove.
        if (isEditable) {
            Some(id)
        } else {
            None
        }
    }

    private func editState(): TextEditState {
        TextEditState(text, cursor: Some(cursorStateValue), anchor: Some(anchorStateValue))
    }

    // Runs a mutating action while focused and editable, recording it for undo. The
    // before/after text comparison means a no-op edit adds no undo step.
    private func recordedEdit(ctx: UiContext, action: () -> Unit): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        let before = snapshot()
        action()
        if (text.value != before.text) {
            history.commit(before, ctx.frame.elapsedMs)
        }
        clearComposition()
        revealCaret(ctx)
        true
    }

    private func handleComposition(ctx: UiContext, edit: TextEditState, event: TextCompositionEvent): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        let replacementUnset = event.replacementStartByte == -1 && event.replacementEndByte == -1
        if (!replacementUnset &&
            !validCompositionReplacement(event.replacementStartByte, event.replacementEndByte)) {
            return false
        }
        match (event.phase) {
            case TextCompositionPhase.Cancel =>
                clearComposition()
                return true
            case TextCompositionPhase.Commit => return commitComposition(ctx, edit, event.text)
            case TextCompositionPhase.Begin => publishComposition(edit, event, true)
            case TextCompositionPhase.Update => publishComposition(edit, event, false)
        }
        ctx.requestFrame()
        true
    }

    private func publishComposition(
        edit: TextEditState,
        event: TextCompositionEvent,
        captureCurrentRange: Bool
    ): Unit {
        let previous = compositionStateValue.value
        var start = edit.selectionStart()
        var end = edit.selectionEnd()
        if (!captureCurrentRange && previous.active) {
            start = previous.replacementStartByte
            end = previous.replacementEndByte
        }
        if (validCompositionReplacement(event.replacementStartByte, event.replacementEndByte)) {
            start = event.replacementStartByte
            end = event.replacementEndByte
        }
        let characterCount = utf8CharacterCount(event.text)
        let selectionStart = if (event.selectionStart < 0) {
            characterCount
        } else {
            min(event.selectionStart, characterCount)
        }
        let selectionLength = if (event.selectionLength < 0) {
            Int64(0)
        } else {
            min(event.selectionLength, characterCount - selectionStart)
        }
        compositionStateValue.value = TextCompositionSnapshot(
            active: true,
            preedit: event.text,
            selectionStart: selectionStart,
            selectionLength: selectionLength,
            replacementStartByte: start,
            replacementEndByte: end,
            documentRevision: text.revision,
            generation: previous.generation + UInt64(1)
        )
    }

    private func commitComposition(ctx: UiContext, edit: TextEditState, value: String): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        let composition = compositionStateValue.value
        if (composition.active && composition.documentRevision == text.revision &&
            validCompositionReplacement(composition.replacementStartByte, composition.replacementEndByte)) {
            cursorStateValue.value = composition.replacementEndByte
            anchorStateValue.value = composition.replacementStartByte
        }
        return recordedEdit(ctx, {=> edit.insert(value)})
    }

    private func validCompositionReplacement(start: Int64, end: Int64): Bool {
        start >= 0 && end >= start && end <= text.value.size &&
            normalizedTextCursor(text.value, start) == start && normalizedTextCursor(text.value, end) == end
    }

    private func clearComposition(): Unit {
        let previous = compositionStateValue.value
        if (previous.active || !previous.preedit.isEmpty()) {
            compositionStateValue.value = TextCompositionSnapshot(generation: previous.generation + UInt64(1))
        }
    }

    private func snapshot(): TextSnapshot {
        TextSnapshot(text.value, cursorStateValue.value, anchorStateValue.value)
    }

    private func applySnapshot(state: TextSnapshot): Unit {
        clearComposition()
        text.value = state.text
        cursorStateValue.value = state.cursor
        anchorStateValue.value = state.anchor
        revealCaretLine() // draw performs the metric-aware horizontal reveal after undo/redo
    }

    /*
     * Vertical caret follow: keeps the caret's line inside the viewport after keyboard
     * edits and navigation, scrolling the minimal distance (top-align when above, bottom-
     * align when below). Pointer paths need no follow — the pointer is already in view.
     */
    private func revealCaretLine(): Unit {
        let viewportH = textViewport(frame).h
        if (viewportH <= 0.0) {
            return
        }
        let position = normalizedTextCursor(text.value, cursorStateValue.value)
        let rowTop = Float32(textCursorLineIndex(text.value, position)) * CUI_SMALL_H
        var scroll = scrollStateValue.value
        if (rowTop < scroll) {
            scroll = rowTop
        } else if (rowTop + CUI_SMALL_H > scroll + viewportH) {
            scroll = rowTop + CUI_SMALL_H - viewportH
        }
        let clamped = clampScrollOffset(scroll, textContentHeight(lines()), viewportH)
        if (clamped != scrollStateValue.value) {
            scrollStateValue.value = clamped
        }
        cancelScrollMotion(scrollMotion, scrollStateValue)
    }

    private func revealCaret(ctx: UiContext): Unit {
        let docLines = lines()
        let viewport = textViewport(frame)
        revealCaret(ctx, contentWidth(ctx, docLines), viewport)
    }

    private func revealCaret(ctx: UiContext, contentW: Float32, viewport: Rect): Unit {
        if (viewport.w <= 0.0 || viewport.h <= 0.0) {
            return
        }
        revealCaretLine()
        let position = normalizedTextCursor(text.value, cursorStateValue.value)
        let lineStart = lineStartBeforeOrAt(text.value, position)
        let caretX = ctx.renderer.textWidth(text.value[lineStart..position], pointSize: FontSizes.BODY)
        var offset = horizontalScrollStateValue.value
        if (caretX < offset) {
            offset = caretX
        } else if (caretX + TEXT_AREA_CARET_RESERVE > offset + viewport.w) {
            offset = caretX + TEXT_AREA_CARET_RESERVE - viewport.w
        }
        let clamped = clampScrollOffset(offset, contentW, viewport.w)
        if (clamped != horizontalScrollStateValue.value) {
            horizontalScrollStateValue.value = clamped
        }
        cancelScrollMotion(horizontalScrollMotion, horizontalScrollStateValue)
        lastObservedCursor.value = position
    }

    private func pointOffset(ctx: UiContext, x: Float32, y: Float32): Int64 {
        textAreaCursorForPoint(ctx, frame, TextAreaContent(text.value, cursorStateValue.value,
            scrollStateValue.value, horizontalScroll: horizontalScrollStateValue.value), Point(x, y))
    }

    private func pressAt(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            clearComposition()
            ctx.focus(id)
            let offset = pointOffset(ctx, x, y)
            if (ctx.clickCount == 2) {
                edit.selectWordAt(offset)
            } else if (ctx.clickCount >= 3) {
                edit.selectLineAt(offset)
            } else {
                edit.moveTo(offset)
                ctx.beginDrag(id) // a press-drag extends the selection (see MouseMove)
            }
            history.breakGroup() // edits before and after a caret jump undo separately
            return true
        }
        false
    }

    // Held Shift extends the selection; plain navigation collapses it. Navigation stays
    // available in read-only mode so text can be selected for copying.
    private func navigate(ctx: UiContext, moveCaret: () -> Unit, growSelection: () -> Unit): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        clearComposition()
        if (Keyboard.modifiers().shift) {
            growSelection()
        } else {
            moveCaret()
        }
        history.breakGroup() // edits before and after a caret jump undo separately
        revealCaret(ctx)
        true
    }

    private func shortcut(ctx: UiContext, edit: TextEditState, code: UInt8): Bool {
        if (!ctx.hasFocus(id) || !Keyboard.modifiers().command) {
            return false
        }
        if (code == AREA_LETTER_A) {
            edit.selectAll()
            return true
        } else if (code == AREA_LETTER_C) {
            let _ = copySelection(edit)
            return true
        } else if (code == AREA_LETTER_X) {
            if (isEditable) {
                return recordedEdit(ctx, {=> if (copySelection(edit)) {
                    let _ = edit.deleteSelection()
                }})
            }
            let _ = copySelection(edit) // read-only: cut degrades to copy
            return true
        } else if (code == AREA_LETTER_V) {
            if (isEditable) {
                return recordedEdit(ctx, {=> pasteClipboard(edit)})
            }
            return true
        } else if (code == AREA_LETTER_Z) {
            if (isEditable) {
                if (Keyboard.modifiers().shift) {
                    redo()
                } else {
                    undo()
                }
            }
            return true
        } else if (code == AREA_LETTER_Y) {
            if (isEditable) {
                redo()
            }
            return true
        }
        false
    }

    // Clipboard access can fail without a desktop session; treat it as best-effort.
    private func copySelection(edit: TextEditState): Bool {
        if (!edit.hasSelection()) {
            return false
        }
        try {
            Clipboard.setText(edit.selectedText())
            true
        } catch (_: Exception) {
            false
        }
    }

    private func pasteClipboard(edit: TextEditState): Unit {
        try {
            let clip = Clipboard.getText()
            if (clip.size > 0) {
                // Line breaks are kept (this is the multi-line control), but Windows CRLF is
                // normalised: a raw \r at each line end breaks End/Backspace and measurement.
                edit.insert(clip.replace("\r\n", "\n").replace("\r", "\n"))
            }
        } catch (_: Exception) {
            ()
        }
    }
}

private func drawTextAreaBox(
    ctx: UiContext,
    frame: Rect,
    id: String,
    content: TextAreaContent,
    lines: Array<String>,
    selStart: Int64,
    selEnd: Int64,
    focused: Bool,
    showVerticalScrollBar: Bool,
    showHorizontalScrollBar: Bool,
    barActive: Bool,
    horizontalBarActive: Bool,
    chrome: TextAreaChrome,
    wrapMode: TextAreaWrapMode,
    decorations: Array<TextAreaDecorationRun>,
    composition: TextCompositionSnapshot,
    documentRevision: UInt64,
    contentW: Float32
): Unit {
    match (chrome) {
        case TextAreaChrome.Field => drawTextBoxChrome(ctx, frame, id)
        case TextAreaChrome.None => ()
    }
    let viewport = textViewport(frame)
    ctx.renderer.pushClip(viewport)
    drawTextAreaDecorationBackgrounds(ctx, viewport, content, decorations)
    if (focused) {
        drawTextAreaSelection(ctx, viewport, content, selStart, selEnd)
    }
    match (wrapMode) {
        case TextAreaWrapMode.NoWrap =>
            if (decorations.isEmpty()) {
                drawLines(ctx, viewport, lines, content.scroll, content.horizontalScroll)
            } else {
                drawDecoratedLines(ctx, viewport, content, decorations)
            }
    }
    drawTextAreaCursor(ctx, viewport, id, content)
    drawTextAreaComposition(ctx, viewport, id, content, composition, documentRevision)
    ctx.renderer.popClip()
    if (showVerticalScrollBar) {
        drawVerticalScrollBar(ctx, frame, content.scroll, textContentHeight(lines), viewport.h, active: barActive)
    }
    if (showHorizontalScrollBar) {
        drawHorizontalScrollBar(ctx, frame, content.horizontalScroll, contentW, viewport.w,
            active: horizontalBarActive)
    }
}

private func drawTextAreaComposition(
    ctx: UiContext,
    viewport: Rect,
    id: String,
    content: TextAreaContent,
    composition: TextCompositionSnapshot,
    documentRevision: UInt64
): Unit {
    if (!ctx.hasFocus(id) || !composition.active || composition.preedit.isEmpty() ||
        composition.documentRevision != documentRevision) {
        return
    }
    let start = composition.replacementStartByte
    if (start < 0 || start > content.text.size || normalizedTextCursor(content.text, start) != start) {
        return
    }
    let visible = composition.preedit.replace("\r\n", " ").replace("\r", " ").replace("\n", " ")
    let line = textCursorLineIndex(content.text, start)
    let lineStart = lineStartBeforeOrAt(content.text, start)
    let x = viewport.x - content.horizontalScroll +
        ctx.renderer.textWidth(content.text[lineStart..start], pointSize: FontSizes.BODY)
    let y = viewport.y + Float32(line) * CUI_SMALL_H - content.scroll
    let width = ctx.renderer.textWidth(visible, pointSize: FontSizes.BODY)
    let lineHeight = min(ctx.renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H)
    if (y + lineHeight < viewport.y || y > viewport.bottom() || x > viewport.right()) {
        return
    }
    ctx.renderer.text(visible, x, y, ctx.theme.text, pointSize: FontSizes.BODY)
    if (width > 0.0) {
        ctx.renderer.strokeLine(x, y + lineHeight - 1.0, x + width, y + lineHeight - 1.0,
            Pen(width: 1.0, color: ctx.theme.accent))
    }
    let caretCharacters = composition.selectionStart + composition.selectionLength
    let caretByte = utf8ByteOffsetAfterCharacters(visible, caretCharacters)
    let caretX = x + ctx.renderer.textWidth(visible[0..caretByte], pointSize: FontSizes.BODY)
    let caret = Rect(caretX, y, TEXT_AREA_CARET_RESERVE, lineHeight)
    ctx.setTextInputAnchor(caret)
    ctx.requestFrame()
}

private func utf8CharacterCount(value: String): Int64 {
    var count: Int64 = 0
    var cursor: Int64 = 0
    while (cursor < value.size) {
        cursor = nextTextBoundary(value, cursor)
        count += 1
    }
    count
}

private func utf8ByteOffsetAfterCharacters(value: String, characters: Int64): Int64 {
    let target = max(Int64(0), characters)
    var count: Int64 = 0
    var cursor: Int64 = 0
    while (cursor < value.size && count < target) {
        cursor = nextTextBoundary(value, cursor)
        count += 1
    }
    cursor
}

private func drawTextAreaDecorationBackgrounds(
    ctx: UiContext,
    viewport: Rect,
    content: TextAreaContent,
    decorations: Array<TextAreaDecorationRun>
): Unit {
    let lineHeight = min(ctx.renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H)
    for (run in decorations) {
        match (run.style.background) {
            case Some(color) =>
                let x = textAreaDecorationX(ctx, viewport, content.text, run.lineStart, run.startByte,
                    content.horizontalScroll)
                let width = ctx.renderer.textWidth(content.text[run.startByte..run.endByte],
                    pointSize: FontSizes.BODY)
                let y = viewport.y + Float32(run.lineIndex) * CUI_SMALL_H - content.scroll
                if (width > 0.0) {
                    ctx.renderer.fill(Rect(x, y, width, lineHeight), color)
                }
            case None => ()
        }
    }
}

private func drawDecoratedLines(
    ctx: UiContext,
    viewport: Rect,
    content: TextAreaContent,
    decorations: Array<TextAreaDecorationRun>
): Unit {
    var lineIndex = scrollLineIndex(content.scroll)
    var lineStart = startOfTextLine(content.text, lineIndex)
    var y = viewport.y - scrollLineRemainder(content.scroll)
    var runIndex: Int64 = 0
    while (lineStart <= content.text.size && y < viewport.bottom()) {
        let lineEnd = lineEndAfterOrAt(content.text, lineStart)
        var cursor = lineStart
        while (runIndex < decorations.size && decorations[runIndex].lineIndex < lineIndex) {
            runIndex += 1
        }
        var currentRun = runIndex
        while (currentRun < decorations.size && decorations[currentRun].lineIndex == lineIndex) {
            let run = decorations[currentRun]
            if (cursor < run.startByte) {
                drawTextAreaSlice(ctx, viewport, content.text, lineStart, cursor, run.startByte, y,
                    ctx.theme.text, None, TextAreaUnderlineShape.Straight, content.horizontalScroll)
            }
            let foreground = match (run.style.foreground) {
                case Some(color) => color
                case None => ctx.theme.text
            }
            drawTextAreaSlice(ctx, viewport, content.text, lineStart, run.startByte, run.endByte, y,
                foreground, run.style.underline, run.style.underlineShape, content.horizontalScroll)
            cursor = run.endByte
            currentRun += 1
        }
        if (cursor < lineEnd || lineStart == lineEnd) {
            drawTextAreaSlice(ctx, viewport, content.text, lineStart, cursor, lineEnd, y,
                ctx.theme.text, None, TextAreaUnderlineShape.Straight, content.horizontalScroll)
        }
        runIndex = currentRun
        if (lineEnd >= content.text.size) {
            break
        }
        lineStart = nextTextBoundary(content.text, lineEnd)
        lineIndex += 1
        y += CUI_SMALL_H
    }
}

private func drawTextAreaSlice(
    ctx: UiContext,
    viewport: Rect,
    text: String,
    lineStart: Int64,
    start: Int64,
    end: Int64,
    y: Float32,
    foreground: Color,
    underline: ?Color,
    underlineShape: TextAreaUnderlineShape,
    horizontalScroll: Float32
): Unit {
    let value = text[start..end]
    let x = textAreaDecorationX(ctx, viewport, text, lineStart, start, horizontalScroll)
    ctx.renderer.text(value, x, y, foreground, pointSize: FontSizes.BODY)
    match (underline) {
        case Some(color) =>
            let width = ctx.renderer.textWidth(value, pointSize: FontSizes.BODY)
            if (width > 0.0) {
                let lineHeight = min(ctx.renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H)
                drawTextAreaUnderline(ctx, x, y + lineHeight - 1.0, width, color, underlineShape)
            }
        case None => ()
    }
}

private func drawTextAreaUnderline(
    ctx: UiContext,
    x: Float32,
    baseline: Float32,
    width: Float32,
    color: Color,
    shape: TextAreaUnderlineShape
): Unit {
    let pen = Pen(width: 1.0, color: color)
    match (shape) {
        case TextAreaUnderlineShape.Straight =>
            ctx.renderer.strokeLine(x, baseline, x + width, baseline, pen)
        case TextAreaUnderlineShape.Wave =>
            // Keep Draw IR bounded for very long diagnostics while still spanning the exact run.
            let step = max(Float32(3.0), width / Float32(256.0))
            let amplitude = Float32(1.5)
            var currentX = x
            var currentY = baseline
            var rising = true
            var segments: Int64 = 0
            while (currentX < x + width && segments < Int64(256)) {
                let nextX = if (segments == Int64(255)) {
                    x + width
                } else {
                    min(x + width, currentX + step)
                }
                let nextY = if (rising) { baseline - amplitude } else { baseline + amplitude }
                ctx.renderer.strokeLine(currentX, currentY, nextX, nextY, pen)
                currentX = nextX
                currentY = nextY
                rising = !rising
                segments += 1
            }
    }
}

private func textAreaDecorationX(
    ctx: UiContext,
    viewport: Rect,
    text: String,
    lineStart: Int64,
    offset: Int64,
    horizontalScroll: Float32
): Float32 {
    viewport.x - horizontalScroll +
        ctx.renderer.textWidth(text[lineStart..offset], pointSize: FontSizes.BODY)
}

internal func drawTextBoxChrome(ctx: UiContext, frame: Rect, id: String): Unit {
    drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
}

private func drawLines(ctx: UiContext, rect: Rect, lines: Array<String>, scroll: Float32,
    horizontalScroll: Float32): Unit {
    var i = scrollLineIndex(scroll)
    var y = rect.y - scrollLineRemainder(scroll)
    while (i < lines.size && y < rect.bottom()) {
        ctx.renderer.text(lines[i], rect.x - horizontalScroll, y, ctx.theme.text, pointSize: FontSizes.BODY)
        y += CUI_SMALL_H
        i += 1
    }
}

private func textContentHeight(lines: Array<String>): Float32 {
    Float32(lines.size) * CUI_SMALL_H
}

private func textViewport(frame: Rect): Rect {
    textInputViewport(frame)
}
