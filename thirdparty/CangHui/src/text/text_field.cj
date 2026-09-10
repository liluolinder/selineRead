package chui.text

import sdl.{FontSizes, Key, MouseButton, Rect, Size, UiEvent}
import sdl.input.{Clipboard, Keyboard}
import chui.core.{Bindable, ControlSemantics, CUI_CONTROL_H, CursorShape, SemanticActionKind, State, UiContext,
    Widget, claimHoverIfInside, emit, localState, recordControlSemantics, registerFocusable, resolveControlKey}

// SDL reports letter keys as their uppercase ASCII code, so the editing shortcuts read as
// the familiar Ctrl+letter table.
private let LETTER_A: UInt8 = 65
private let LETTER_C: UInt8 = 67
private let LETTER_V: UInt8 = 86
private let LETTER_X: UInt8 = 88
private let LETTER_Y: UInt8 = 89
private let LETTER_Z: UInt8 = 90

/*
 * A single-line text editor bound to a `Bindable<String>`. The caret and selection anchor are BYTE
 * offsets into the UTF-8 text, not character counts; a caller supplying its own `cursor`/`anchor`
 * states must keep them on rune boundaries and move the pair together, or the stale anchor spans a
 * selection the user never made. Editing follows the desktop conventions: mouse and double-click-word
 * selection, the Ctrl+A/C/X/V/Z/Y table, grouped undo, and a horizontal follow window that keeps the
 * caret visible. Caret, selection, and scroll state are retained across the per-frame rebuild under
 * the control identity; `editable: false` renders read-only and stays out of Tab traversal.
 */
public class TextField <: Widget {
    private let id: String
    private let text: Bindable<String>
    private var placeholderText: String
    private var semanticLabel: String
    private var cursorStateValue: State<Int64>
    private var anchorStateValue: State<Int64>
    private let history: UndoHistory
    // Horizontal follow window: how many pixels the text is slid left so the caret stays
    // inside the field's inner width. Retained across rebuilds; recomputed each draw.
    private let xOffset: State<Float32>
    private var autofocusRequested = false
    private let autofocusDone: State<Bool>
    private let isEditable: Bool
    private var secureEntryEnabled = false
    private var frame = Rect.zero()
    // 可选提交回调：按下回车时触发（如搜索框回车即搜索）
    private var submitHandler: Option<() -> Unit> = None

    public init(
        text: Bindable<String>,
        key!: ?String = None,
        cursor!: ?State<Int64> = None,
        anchor!: ?State<Int64> = None,
        editable!: Bool = true,
        placeholder!: String = ""
    ) {
        let ident = resolveControlKey(key, "TextField")
        this.id = ident
        this.text = text
        this.placeholderText = placeholder
        this.semanticLabel = ""
        this.isEditable = editable
        this.cursorStateValue = match (cursor) {
            case Some(value) => value
            case None => localState<Int64>("TextField:${ident}:cursor") {text.value.size}
        }
        // The anchor starts collapsed on the caret; defaulting it to the text end instead
        // would present a phantom selection whenever the caret begins elsewhere. A composing
        // widget (e.g. ComboBox) may own both caret and anchor so it can reset the selection.
        let caretStart = cursorStateValue.value
        this.anchorStateValue = match (anchor) {
            case Some(value) => value
            case None => localState<Int64>("TextField:${ident}:anchor") {caretStart}
        }
        this.history = localState<UndoHistory>("TextField:${ident}:history") {UndoHistory()}.value
        this.xOffset = localState<Float32>("TextField:${ident}:xoff") {0.0}
        this.autofocusDone = localState<Bool>("TextField:${ident}:autofocused") {false}
        // A read-only field is not an editing stop, so it stays out of Tab traversal (mirrors TextArea).
        if (editable) {
            registerFocusable(ident)
        }
        emit(this)
    }

    /** Claims keyboard focus the first time the field appears (e.g. a search box or dialog). */
    public func autofocus(): TextField {
        autofocusRequested = true
        this
    }

    /** Sets the dim hint shown while the field is empty; does not change editing. */
    public func placeholder(value: String): TextField {
        placeholderText = value
        this
    }

    /** Overrides the semantic name without changing the rendered value or hint. */
    public func accessibilityLabel(value: String): TextField {
        semanticLabel = value
        this
    }

    /**
     * Masks the rendered value and keeps credential bytes out of semantics,
     * clipboard copy/cut and retained undo/redo history.
     *
     * The caller still owns the bound value and must clear it after handing the
     * credential to its provider. Managed String storage is not a zeroizable
     * secret container.
     */
    public func secureEntry(): TextField {
        secureEntryEnabled = true
        this
    }

    /** Registers a callback fired when Enter is pressed while the field has focus. */
    public func onSubmit(handler: () -> Unit): TextField {
        submitHandler = Some(handler)
        this
    }

    /** Reverts the last edit group; also bound to Ctrl+Z. */
    public func undo(): Unit {
        if (secureEntryEnabled) {
            return
        }
        match (history.undo(snapshot())) {
            case Some(state) => applySnapshot(state)
            case None => ()
        }
    }

    /** Reapplies the last undone edit; also bound to Ctrl+Y / Ctrl+Shift+Z. */
    public func redo(): Unit {
        if (secureEntryEnabled) {
            return
        }
        match (history.redo(snapshot())) {
            case Some(state) => applySnapshot(state)
            case None => ()
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let edit = editState()
        edit.normalizeCursor()
        let visibleText = if (secureEntryEnabled) { secureMask(text.value) } else { text.value }
        let visibleCursor = if (secureEntryEnabled) {
            secureDisplayOffset(text.value, cursorStateValue.value)
        } else {
            cursorStateValue.value
        }
        recordControlSemantics(ctx, frame, "TextField", ControlSemantics(
            if (secureEntryEnabled) { "password" } else { "textfield" },
            label: semanticLabel,
            value: if (secureEntryEnabled) { "" } else { text.value },
            placeholder: placeholderText,
            action: if (isEditable) { "TextField.edit()" } else { "" },
            shortcut: if (isEditable) { "TextInput" } else { "" },
            actionOwner: id,
            readOnly: Some(!isEditable),
            typedActions: if (isEditable) { [SemanticActionKind.Focus] } else { [] }
        ))
        drawTextBoxChrome(ctx, frame, id)
        // Values longer than the field must not paint past its surface; selection, text and
        // caret are clipped together, and all three share the same follow shift.
        let shift = followCursorShift(ctx, visibleText, visibleCursor)
        ctx.renderer.pushClip(frame.inset(2.0))
        if (ctx.hasFocus(id)) {
            let selectionStart = if (secureEntryEnabled) {
                secureDisplayOffset(text.value, edit.selectionStart())
            } else {
                edit.selectionStart()
            }
            let selectionEnd = if (secureEntryEnabled) {
                secureDisplayOffset(text.value, edit.selectionEnd())
            } else {
                edit.selectionEnd()
            }
            drawTextFieldSelection(ctx, frame, visibleText, selectionStart, selectionEnd, xShift: shift)
        }
        if (text.value.isEmpty() && !placeholderText.isEmpty()) {
            drawTextFieldPlaceholder(ctx, frame, placeholderText, shift)
        } else {
            drawTextFieldText(ctx, frame, visibleText, shift)
        }
        drawTextFieldCursor(ctx, frame, id, visibleText, visibleCursor, xShift: shift)
        ctx.renderer.popClip()
    }

    /*
     * Horizontal caret follow. Values wider than the field slide left so the caret stays
     * visible: the window moves only when the caret leaves it (the usual desktop feel) and
     * is clamped so the text's tail never detaches from the right edge. Runs in draw, so
     * every way the caret moves — keys, clicks, undo, an external state write — is followed.
     */
    private func followCursorShift(ctx: UiContext, visibleText: String, visibleCursor: Int64): Float32 {
        let innerW = max(1.0, frame.w - 16.0)
        let position = normalizedTextCursor(visibleText, visibleCursor)
        let caretX = ctx.renderer.textWidth(visibleText[0..position], pointSize: FontSizes.BODY)
        let textW = ctx.renderer.textWidth(visibleText, pointSize: FontSizes.BODY)
        var shift = min(xOffset.value, max(0.0, textW - innerW))
        if (caretX < shift) {
            shift = caretX
        } else if (caretX > shift + innerW) {
            shift = caretX - innerW
        }
        if (shift != xOffset.value) {
            xOffset.value = shift
        }
        shift
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // A read-only field is not an editing target, so it does not request the text cursor.
        if (isEditable) {
            claimHoverIfInside(ctx, event, frame, id, CursorShape.Text)
        }
        let edit = editState()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => return pressAt(ctx, edit, x, y)
            case UiEvent.MouseMove(x, _) =>
                if (ctx.isDragging(id) && ctx.leftMouseDown) {
                    edit.extendTo(sourceCursorForPoint(ctx, x))
                    return true
                }
            case UiEvent.TextInput(value) => return recordedEdit(ctx, {=> edit.insert(value)})
            case UiEvent.KeyDown(Key.Backspace, _) => return recordedEdit(ctx, {=> edit.backspace()})
            case UiEvent.KeyDown(Key.Delete, _) => return recordedEdit(ctx, {=> edit.deleteForward()})
            case UiEvent.KeyDown(Key.Left, _) => return navigate(ctx, {=> edit.moveLeft()}, {=> edit.extendLeft()})
            case UiEvent.KeyDown(Key.Right, _) => return navigate(ctx, {=> edit.moveRight()}, {=> edit.extendRight()})
            case UiEvent.KeyDown(Key.Home, _) => return navigate(ctx, {=> edit.moveToStart()}, {=> edit.extendToStart()})
            case UiEvent.KeyDown(Key.End, _) => return navigate(ctx, {=> edit.moveToEnd()}, {=> edit.extendToEnd()})
            case UiEvent.KeyDown(Key.Letter(code), _) => return shortcut(ctx, edit, code)
            case UiEvent.KeyDown(Key.Enter, _) =>
                // 回车提交：注册了回调则消费事件，否则保持默认行为
                match (submitHandler) {
                    case Some(handler) =>
                        handler()
                        return true
                    case None => ()
                }
            case UiEvent.Frame(_) =>
                // One-time initial focus, applied after the frame's pointer events so a stray
                // startup click cannot cancel it; later frames leave focus to the user.
                if (autofocusRequested && !autofocusDone.value) {
                    ctx.focus(id, viaKeyboard: true) // autofocus expects typing, so show the ring
                    autofocusDone.value = true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func editState(): TextEditState {
        TextEditState(text, cursor: Some(cursorStateValue), anchor: Some(anchorStateValue))
    }

    private func pressAt(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            ctx.focus(id)
            let offset = sourceCursorForPoint(ctx, x)
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

    // Runs a mutating action while focused and records it for undo. The before/after text
    // comparison means a no-op edit (e.g. Backspace at position 0) adds no undo step.
    private func recordedEdit(ctx: UiContext, action: () -> Unit): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        if (secureEntryEnabled) {
            action()
            return true
        }
        let before = snapshot()
        action()
        if (text.value != before.text) {
            history.commit(before, ctx.frame.elapsedMs)
        }
        true
    }

    private func snapshot(): TextSnapshot {
        TextSnapshot(text.value, cursorStateValue.value, anchorStateValue.value)
    }

    private func applySnapshot(state: TextSnapshot): Unit {
        text.value = state.text
        cursorStateValue.value = state.cursor
        anchorStateValue.value = state.anchor
    }

    // Held Shift extends the selection; a plain arrow collapses it.
    private func navigate(ctx: UiContext, moveCaret: () -> Unit, growSelection: () -> Unit): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        if (Keyboard.modifiers().shift) {
            growSelection()
        } else {
            moveCaret()
        }
        history.breakGroup() // edits before and after a caret jump undo separately
        true
    }

    private func shortcut(ctx: UiContext, edit: TextEditState, code: UInt8): Bool {
        if (!ctx.hasFocus(id) || !Keyboard.modifiers().command) {
            return false
        }
        if (code == LETTER_A) {
            edit.selectAll()
            return true
        } else if (code == LETTER_C) {
            if (secureEntryEnabled) {
                return true
            }
            copySelection(edit)
            return true
        } else if (code == LETTER_X) {
            if (secureEntryEnabled) {
                return true
            }
            return recordedEdit(ctx, {=> if (copySelection(edit)) {
                let _ = edit.deleteSelection()
            }})
        } else if (code == LETTER_V) {
            return recordedEdit(ctx, {=> pasteClipboard(edit)})
        } else if (code == LETTER_Z) {
            if (secureEntryEnabled) {
                return true
            }
            if (Keyboard.modifiers().shift) {
                redo()
            } else {
                undo()
            }
            return true
        } else if (code == LETTER_Y) {
            if (secureEntryEnabled) {
                return true
            }
            redo()
            return true
        }
        false
    }

    // Clipboard access can fail where there is no desktop session; treat it as best-effort
    // so a copy or paste never crashes the field.
    private func copySelection(edit: TextEditState): Bool {
        if (secureEntryEnabled) {
            return false
        }
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
                edit.insert(flattenLines(clip)) // a single-line field keeps its value on one row
            }
        } catch (_: Exception) {
            ()
        }
    }

    private func sourceCursorForPoint(ctx: UiContext, x: Float32): Int64 {
        if (!secureEntryEnabled) {
            return textFieldCursorForPoint(ctx, frame, text.value, x, xShift: xOffset.value)
        }
        let visible = secureMask(text.value)
        let displayOffset = textFieldCursorForPoint(ctx, frame, visible, x, xShift: xOffset.value)
        secureSourceOffset(text.value, displayOffset)
    }
}

private let SECURE_MASK_GLYPH: String = "•"

private func secureMask(value: String): String {
    let builder = StringBuilder()
    var cursor: Int64 = 0
    while (cursor < value.size) {
        builder.append(SECURE_MASK_GLYPH)
        cursor = nextTextBoundary(value, cursor)
    }
    builder.toString()
}

private func secureDisplayOffset(value: String, sourceOffset: Int64): Int64 {
    let target = normalizedTextCursor(value, sourceOffset)
    var cursor: Int64 = 0
    var displayOffset: Int64 = 0
    while (cursor < target) {
        displayOffset += SECURE_MASK_GLYPH.size
        cursor = nextTextBoundary(value, cursor)
    }
    displayOffset
}

private func secureSourceOffset(value: String, displayOffset: Int64): Int64 {
    let visible = secureMask(value)
    let target = normalizedTextCursor(visible, displayOffset)
    var visibleCursor: Int64 = 0
    var sourceCursor: Int64 = 0
    while (visibleCursor < target && sourceCursor < value.size) {
        visibleCursor = nextTextBoundary(visible, visibleCursor)
        sourceCursor = nextTextBoundary(value, sourceCursor)
    }
    sourceCursor
}

// Collapses any line breaks so pasted multi-line text stays on the field's single row:
// newlines become spaces and stray carriage returns are dropped.
private func flattenLines(value: String): String {
    let builder = StringBuilder()
    var firstLine = true
    for (line in value.split("\n")) {
        if (!firstLine) {
            builder.append(" ")
        }
        firstLine = false
        for (chunk in line.split("\r")) {
            builder.append(chunk)
        }
    }
    builder.toString()
}

private func drawTextFieldText(ctx: UiContext, frame: Rect, text: String, xShift: Float32): Unit {
    let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
    ctx.renderer.text(text, frame.x + 8.0 - xShift, textY, ctx.theme.text, pointSize: FontSizes.BODY)
}

private func drawTextFieldPlaceholder(ctx: UiContext, frame: Rect, text: String, xShift: Float32): Unit {
    let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
    ctx.renderer.text(text, frame.x + 8.0 - xShift, textY, ctx.theme.mutedText, pointSize: FontSizes.BODY)
}
