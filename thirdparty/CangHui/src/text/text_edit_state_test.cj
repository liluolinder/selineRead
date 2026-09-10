package chui.text

import sdl.{Key, MouseButton, Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}
import chui.core.{CursorShape, ScrollOptions, State, StateStore, Theme, UiContext, buildRoot}

private func textTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func textAreaScrollbarThumbDragScrollsAndTakesPriorityOverTextDrag(): Unit {
    let ctx = textTestContext()
    let text = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten")
    let scroll = State<Float32>(0.0)
    let area = TextArea(text, key: "notes", scroll: Some(scroll))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    // Press in the scrollbar lane (right edge), not the text — then drag the thumb down.
    @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 195.0, 6.0)))
    ctx.leftMouseDown = true
    @Expect(area.handle(ctx, UiEvent.MouseMove(195.0, 70.0)))
    @Expect(scroll.value > Float32(0.0))
    @Expect(text.value, "one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten") // dragging the bar never edits
}

@Test
func editableTextAreaRequestsTextCursorButReadOnlyDoesNot(): Unit {
    let editableCtx = textTestContext()
    let editable = TextArea(State<String>("hi"), key: "editable")
    editable.layout(editableCtx, Rect(0.0, 0.0, 200.0, 120.0))
    editableCtx.beginHoverTest()
    let _ = editable.handle(editableCtx, UiEvent.MouseMove(20.0, 20.0))
    editableCtx.settleHover()
    @Expect(editableCtx.desiredCursor() == CursorShape.Text)

    let readOnlyCtx = textTestContext()
    let readOnly = TextArea(State<String>("hi"), key: "readonly", editable: false)
    readOnly.layout(readOnlyCtx, Rect(0.0, 0.0, 200.0, 120.0))
    readOnlyCtx.beginHoverTest()
    let _ = readOnly.handle(readOnlyCtx, UiEvent.MouseMove(20.0, 20.0))
    readOnlyCtx.settleHover()
    @Expect(readOnlyCtx.desiredCursor() == CursorShape.Default)
}

@Test
func editableTextAreaJoinsFocusRingButReadOnlyDoesNot(): Unit {
    let editableStore = StateStore()
    let _ = buildRoot({=> TextArea(State<String>("hi"), key: "editable")}, editableStore)
    @Expect(editableStore.focusRing().size, 1)

    let readOnlyStore = StateStore()
    let _ = buildRoot({=> TextArea(State<String>("hi"), key: "readonly", editable: false)}, readOnlyStore)
    @Expect(readOnlyStore.focusRing().size, 0)
}

@Test
func textAreaChromeNoneOmitsFieldSurfaceButKeepsText(): Unit {
    let fieldRenderer = Renderer.recordingHeadless()
    let field = TextArea(State<String>("1\n2"), key: "field")
    let fieldCtx = UiContext(fieldRenderer, Theme.light())
    field.layout(fieldCtx, Rect(0.0, 0.0, 80.0, 80.0))
    field.draw(fieldCtx)

    let plainRenderer = Renderer.recordingHeadless()
    let plain = TextArea(State<String>("1\n2"), key: "plain", editable: false,
        chrome: TextAreaChrome.None)
    let plainCtx = UiContext(plainRenderer, Theme.light())
    plain.layout(plainCtx, Rect(0.0, 0.0, 80.0, 80.0))
    plain.draw(plainCtx)

    var fieldSurfaces: Int64 = 0
    var plainSurfaces: Int64 = 0
    var plainText: Int64 = 0
    for (command in fieldRenderer.drawIr()) {
        if (command.kind == "paint.fill-rounded-rect") {
            fieldSurfaces += 1
        }
    }
    for (command in plainRenderer.drawIr()) {
        if (command.kind == "paint.fill-rounded-rect") {
            plainSurfaces += 1
        }
        if (command.kind == "text") {
            plainText += 1
        }
    }
    @Expect(fieldSurfaces > plainSurfaces)
    @Expect(plainText, Int64(2))
}

@Test
func textAreaWheelUpdatesSharedScrollState(): Unit {
    let ctx = textTestContext()
    let text = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight")
    let scroll = State<Float32>(0.0)
    let area = TextArea(text, key: "notes", scroll: Some(scroll))
        .scrollOptions(ScrollOptions.immediate())

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))

    @Expect(area.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
}

@Test
func textAreaHorizontalWheelUpdatesSharedOffset(): Unit {
    let ctx = textTestContext()
    let text = State<String>("0123456789012345678901234567890123456789")
    let horizontal = State<Float32>(0.0)
    let area = TextArea(text, key: "code", horizontalScroll: Some(horizontal),
        wrapMode: TextAreaWrapMode.NoWrap).scrollOptions(ScrollOptions.immediate())
    area.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))

    @Expect(area.handle(ctx, UiEvent.MouseWheel(1.0, 0.0, 12.0, 12.0)))
    @Expect(horizontal.value, Float32(72.0))
}

@Test
func textAreaHorizontalThumbDragTakesPriorityOverSelection(): Unit {
    let ctx = textTestContext()
    let text = State<String>("01234567890123456789012345678901234567890123456789")
    let horizontal = State<Float32>(0.0)
    let cursor = State<Int64>(0)
    let area = TextArea(text, key: "code", horizontalScroll: Some(horizontal), cursor: Some(cursor))
    area.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))

    // The horizontal bar occupies the bottom 6px track. Dragging it must never move the caret.
    @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 95.0)))
    ctx.leftMouseDown = true
    @Expect(area.handle(ctx, UiEvent.MouseMove(120.0, 95.0)))
    @Expect(horizontal.value > Float32(0.0))
    @Expect(cursor.value, Int64(0))
}

@Test
func textAreaHorizontalHitTestAddsTheSharedOffset(): Unit {
    let ctx = textTestContext()
    let text = State<String>("0123456789012345678901234567890123456789")
    let horizontal = State<Float32>(82.5)
    let cursor = State<Int64>(0)
    let anchor = State<Int64>(0)
    let area = TextArea(text, key: "code", horizontalScroll: Some(horizontal),
        cursor: Some(cursor), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    area.draw(ctx)

    // Headless BODY metrics are 8.25px per ASCII byte. At x=8 (the text origin), an
    // 82.5px horizontal offset therefore selects byte 10 rather than byte 0.
    @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 12.0)))
    @Expect(cursor.value, Int64(10))
}

@Test
func textAreaNoWrapKeepsOneVisualRowPerLogicalUtf8Line(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let text = State<String>(
        "long_ascii_source_line_0123456789\n中文长行不会按视口折成额外行\n\t\tTabbedSourceLine")
    let horizontal = State<Float32>(9999.0)
    let area = TextArea(text, key: "code", horizontalScroll: Some(horizontal),
        wrapMode: TextAreaWrapMode.NoWrap)
    area.layout(ctx, Rect(0.0, 0.0, 72.0, 120.0))
    area.draw(ctx)

    var textRows: Int64 = 0
    for (command in renderer.drawIr()) {
        if (command.kind == "text") {
            textRows += 1
        }
    }
    @Expect(textRows, Int64(3))
    @Expect(horizontal.value > Float32(0.0))
    @Expect(horizontal.value < Float32(9999.0))
}

@Test
func textAreaCaretRevealKeepsCjkImeAnchorInsideHorizontalViewport(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let text = State<String>("你你你你你你你你你你你你你你你你你你你你")
    let cursor = State<Int64>(text.value.size)
    let anchor = State<Int64>(text.value.size)
    let horizontal = State<Float32>(0.0)
    let area = TextArea(text, key: "code", horizontalScroll: Some(horizontal),
        cursor: Some(cursor), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    ctx.focus("code")

    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(horizontal.value > Float32(0.0))
    area.draw(ctx)
    match (ctx.textInputAnchorRect()) {
        case Some(rect) =>
            @Expect(rect.x >= Float32(8.0))
            @Expect(rect.x <= Float32(112.0))
        case None => @Expect(false)
    }
}

@Test
func textEditStateInsertsAndDeletesAtUtf8Boundaries(): Unit {
    let edit = TextEditState("a你b")

    edit.moveTo(1)
    edit.moveRight()
    edit.backspace()

    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textEditStateDeleteForwardRemovesWholeRune(): Unit {
    let edit = TextEditState("a你b")

    edit.moveTo(1)
    edit.deleteForward()

    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textEditStateMovesBetweenLinesWithColumn(): Unit {
    let edit = TextEditState("abc\nde\nfghi")

    edit.moveTo(5)
    edit.moveLineDown()
    @Expect(edit.cursor.value, Int64(8))

    edit.moveLineUp()
    edit.moveLineUp()
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textFieldUsesExternalCursorState(): Unit {
    let ctx = textTestContext()
    let text = State<String>("abc")
    let cursor = State<Int64>(1)
    let field = TextField(text, key: "field", cursor: Some(cursor))

    field.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    ctx.focus("field")

    @Expect(field.handle(ctx, UiEvent.TextInput("X")))
    @Expect(text.value, "aXbc")
    @Expect(cursor.value, Int64(2))

    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(text.value, "Xbc")
    @Expect(cursor.value, Int64(0))
}

@Test
func textAreaReadOnlyStillMovesCursor(): Unit {
    let ctx = textTestContext()
    let text = State<String>("abc")
    let cursor = State<Int64>(2)
    let area = TextArea(text, key: "output", cursor: Some(cursor), editable: false)

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 80.0))
    ctx.focus("output")

    @Expect(!area.handle(ctx, UiEvent.TextInput("X")))
    @Expect(!area.handle(ctx, UiEvent.KeyDown(Key.Delete, false)))
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(text.value, "abc")
    @Expect(cursor.value, Int64(1))
}

@Test
func textFieldImplicitCursorSurvivesKeyedRebuild(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let text = State<String>("abc")

    let first = buildRoot({=> TextField(text, key: "remembered.field")}, store)
    first.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    let _ = first.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 170.0, 10.0))
    let _ = first.handle(ctx, UiEvent.KeyDown(Key.Left, false))

    let second = buildRoot({=> TextField(text, key: "remembered.field")}, store)
    second.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    let _ = second.handle(ctx, UiEvent.TextInput("X"))

    @Expect(text.value, "abXc")
}

@Test
func textAreaImePreeditStaysNonDurableAndCommitsOneUtf8Replacement(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let text = State<String>("ab你cd")
    let cursor = State<Int64>(5)
    let anchor = State<Int64>(2)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "ime-area", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 240.0, 90.0))
    ctx.focus("ime-area")

    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Update, text: "pin", selectionStart: 3, selectionLength: 0,
        replacementStartByte: 2, replacementEndByte: 5))))
    @Expect(text.value, "ab你cd")
    @Expect(composition.value.active)
    @Expect(composition.value.preedit, "pin")
    area.draw(ctx)
    var sawPreedit = false
    var sawUnderline = false
    for (command in renderer.drawIr()) {
        sawPreedit = sawPreedit || (command.kind == "text" && command.toJson().contains("pin"))
        sawUnderline = sawUnderline || command.kind == "paint.stroke-line"
    }
    @Expect(sawPreedit)
    @Expect(sawUnderline)
    @Expect(ctx.textInputAnchorRect().isSome())

    @Expect(area.handle(ctx, UiEvent.TextInput("拼")))
    @Expect(text.value, "ab拼cd")
    @Expect(cursor.value, Int64(5))
    @Expect(anchor.value, Int64(5))
    @Expect(!composition.value.active)
    area.undo()
    @Expect(text.value, "ab你cd")
}

@Test
func textAreaRejectsCompositionFromStaleFocusAndDocumentRevision(): Unit {
    let ctx = textTestContext()
    let text = State<String>("hello")
    let cursor = State<Int64>(text.value.size)
    let anchor = State<Int64>(text.value.size)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "stale-ime", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 220.0, 80.0))

    @Expect(!area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Update, text: "x"))))
    @Expect(!composition.value.active)

    ctx.focus("stale-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Update, text: "候选"))))
    text.value = "external"
    cursor.value = text.value.size
    anchor.value = text.value.size
    @Expect(area.handle(ctx, UiEvent.TextInput("定")))
    // The old replacement range is revision-bound; after an external write, the current
    // normalized caret owns the commit rather than replaying a stale document range.
    @Expect(text.value, "external定")
    @Expect(!composition.value.active)
}

@Test
func textAreaCompositionBeginUpdateCancelAndTypedCommitAreOneBoundedTransaction(): Unit {
    let ctx = textTestContext()
    let text = State<String>("a你b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "phase-ime", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 220.0, 80.0))
    ctx.focus("phase-ime")

    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "n", selectionStart: 1, selectionLength: 0))))
    @Expect(text.value, "a你b")
    @Expect(composition.value.replacementStartByte, Int64(1))
    @Expect(composition.value.replacementEndByte, Int64(4))
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Update, text: "ni", selectionStart: 2, selectionLength: 0))))
    @Expect(composition.value.preedit, "ni")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Cancel))))
    @Expect(!composition.value.active)
    @Expect(text.value, "a你b")

    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "pin", replacementStartByte: 1,
        replacementEndByte: 4))))
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Commit, text: "拼"))))
    @Expect(text.value, "a拼b")
    @Expect(!composition.value.active)
}

@Test
func textAreaRejectsCompositionRangesOutsideExactUtf8Boundaries(): Unit {
    let ctx = textTestContext()
    let text = State<String>("a你b")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "invalid-ime", composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 220.0, 80.0))
    ctx.focus("invalid-ime")

    @Expect(!area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "x", replacementStartByte: 2,
        replacementEndByte: 4))))
    @Expect(!composition.value.active)
    @Expect(text.value, "a你b")
    @Expect(!area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Update, text: "x", replacementStartByte: 1,
        replacementEndByte: 99))))
    @Expect(!composition.value.active)
}
