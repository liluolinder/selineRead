package chui.text

import sdl.{Color, Key, Rect, Renderer, UiEvent}
import chui.core.{State, Theme, UiContext}

private func decorationTestStyle(
    foreground!: ?Color = None,
    background!: ?Color = None,
    underline!: ?Color = None,
    underlineShape!: TextAreaUnderlineShape = TextAreaUnderlineShape.Straight
): TextAreaDecorationStyle {
    TextAreaDecorationStyle(foreground: foreground, background: background, underline: underline,
        underlineShape: underlineShape)
}

private func drawDecoratedArea(
    text: State<String>,
    decorations: State<TextAreaDecorationSnapshot>,
    focused!: Bool = false,
    scroll!: ?State<Float32> = None,
    horizontalScroll!: ?State<Float32> = None,
    cursor!: ?State<Int64> = None,
    anchor!: ?State<Int64> = None
): (UiContext, Renderer) {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let area = TextArea(text, key: "decorated", scroll: scroll, horizontalScroll: horizontalScroll,
        cursor: cursor, anchor: anchor, decorations: Some(decorations))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 112.0))
    if (focused) {
        ctx.focus("decorated")
    }
    area.draw(ctx)
    (ctx, renderer)
}

@Test
func textAreaDecorationAndSelectionShareHorizontalCoordinatePlane(): Unit {
    let text = State<String>(
        "012345678901234567890123456789012345678901234567890123456789")
    let horizontal = State<Float32>(82.5)
    let foreground = Color.rgb(19, 71, 211)
    let background = Color.rgba(7, 31, 89, 73)
    let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(10, 12, decorationTestStyle(
            foreground: Some(foreground), background: Some(background)))
    ]))
    let (_, renderer) = drawDecoratedArea(text, decorations, horizontalScroll: Some(horizontal))

    // Recording-headless BODY metrics are 8.25px per ASCII byte. Byte 10 therefore lands
    // exactly at the 8px text origin after subtracting the shared 82.5px horizontal offset.
    var sawTranslatedBackground = false
    var sawTranslatedGlyph = false
    for (command in renderer.drawIr()) {
        let json = command.toJson()
        if (json.contains("\"r\":7,\"g\":31,\"b\":89,\"a\":73") &&
            json.contains("\"x\":8")) {
            sawTranslatedBackground = true
        }
        if (command.kind == "text" && json.contains("01") && json.contains("\"b\":211") &&
            json.contains("\"x\":8")) {
            sawTranslatedGlyph = true
        }
    }

    let selectionRenderer = Renderer.recordingHeadless()
    let selectionCtx = UiContext(selectionRenderer, Theme.light())
    drawTextAreaSelection(selectionCtx, Rect(8.0, 8.0, 304.0, 96.0),
        TextAreaContent(text.value, 12, 0.0, horizontalScroll: horizontal.value), 10, 12)
    var sawTranslatedSelection = false
    for (command in selectionRenderer.drawIr()) {
        let json = command.toJson()
        if (command.kind == "paint.fill" && json.contains("\"a\":115") &&
            json.contains("\"x\":8")) {
            sawTranslatedSelection = true
        }
    }

    @Expect(sawTranslatedBackground)
    @Expect(sawTranslatedGlyph)
    @Expect(sawTranslatedSelection)
}

@Test
func textAreaDecorationSnapshotDefensivelyCopiesInput(): Unit {
    let original = TextAreaDecoration(0, 1, decorationTestStyle(
        foreground: Some(Color.rgb(10, 20, 30))))
    let replacement = TextAreaDecoration(1, 2, decorationTestStyle(
        foreground: Some(Color.rgb(40, 50, 60))))
    let input = [original]
    let snapshot = TextAreaDecorationSnapshot(UInt64(7), input)

    input[0] = replacement
    let firstRead = snapshot.decorations()
    @Expect(firstRead[0].startByte, Int64(0))
    firstRead[0] = replacement
    @Expect(snapshot.decorations()[0].startByte, Int64(0))
}

@Test
func textAreaDecorationsUseLaterOverlapPrecedenceAndExactCjkBoundaries(): Unit {
    let text = State<String>("ab你cd")
    let red = Color.rgb(210, 30, 40)
    let blue = Color.rgb(30, 80, 220)
    let snapshot = TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(0, 5, decorationTestStyle(foreground: Some(red))),
        // Invalid continuation-byte start inside 你: ignored rather than normalized.
        TextAreaDecoration(3, 5, decorationTestStyle(foreground: Some(Color.rgb(1, 2, 3)))),
        // Later valid range wins for the CJK glyph and following c.
        TextAreaDecoration(2, 6, decorationTestStyle(foreground: Some(blue)))
    ])
    let (_, renderer) = drawDecoratedArea(text, State<TextAreaDecorationSnapshot>(snapshot))
    let commands = renderer.drawIr()
    var sawRedPrefix = false
    var sawBlueCjk = false
    var sawBlueSuffix = false
    var sawInvalidColor = false
    for (command in commands) {
        let json = command.toJson()
        if (command.kind == "text" && json.contains("ab") && json.contains("\"r\":210")) {
            sawRedPrefix = true
        }
        // The earlier range ends between 你 and c, so normalization keeps two deterministic
        // paint runs even though the later style is identical on both sides of that boundary.
        if (command.kind == "text" && json.contains("你") && json.contains("\"b\":220")) {
            sawBlueCjk = true
        }
        if (command.kind == "text" && json.contains("c") && json.contains("\"b\":220")) {
            sawBlueSuffix = true
        }
        if (json.contains("\"r\":1,\"g\":2,\"b\":3")) {
            sawInvalidColor = true
        }
    }
    @Expect(sawRedPrefix)
    @Expect(sawBlueCjk)
    @Expect(sawBlueSuffix)
    @Expect(!sawInvalidColor)
}

@Test
func textAreaDecorationsNormalizeOnlyTheVisibleLogicalLineWindow(): Unit {
    let text = State<String>("zero\none\ntwo\nthree\nfour\nfive")
    let hidden = Color.rgb(211, 17, 19)
    let visible = Color.rgb(23, 71, 223)
    let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(0, 4, decorationTestStyle(foreground: Some(hidden))),
        TextAreaDecoration(9, 12, decorationTestStyle(foreground: Some(visible)))
    ]))
    // Two 28px logical rows down: line "two" is the first visible row.
    let (_, renderer) = drawDecoratedArea(text, decorations,
        scroll: Some(State<Float32>(56.0)))
    var sawHidden = false
    var sawVisible = false
    for (command in renderer.drawIr()) {
        let json = command.toJson()
        sawHidden = sawHidden || json.contains("\"r\":211,\"g\":17,\"b\":19")
        sawVisible = sawVisible || json.contains("\"r\":23,\"g\":71,\"b\":223")
    }
    @Expect(!sawHidden)
    @Expect(sawVisible)
}

@Test
func staleTextAreaDecorationSnapshotFallsBackToPlainText(): Unit {
    let text = State<String>("alpha")
    let green = Color.rgb(12, 190, 70)
    let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(0, 5, decorationTestStyle(foreground: Some(green)))
    ]))
    text.value = "alpha!" // snapshot still names revision 0, so it must be ignored

    let (_, renderer) = drawDecoratedArea(text, decorations)
    var textCommands: Int64 = 0
    var sawGreen = false
    for (command in renderer.drawIr()) {
        if (command.kind == "text") {
            textCommands += 1
            sawGreen = sawGreen || command.toJson().contains("\"g\":190")
        }
    }
    @Expect(textCommands, Int64(1))
    @Expect(!sawGreen)
}

@Test
func textAreaDecorationLayeringKeepsSelectionGlyphUnderlineAndCaretOrder(): Unit {
    let text = State<String>("abcdef")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(2)
    let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(0, 6, decorationTestStyle(
            foreground: Some(Color.rgb(220, 230, 240)),
            background: Some(Color.rgba(7, 8, 9, 77)),
            underline: Some(Color.rgb(11, 12, 13))))
    ]))
    let (ctx, renderer) = drawDecoratedArea(text, decorations, focused: true,
        cursor: Some(cursor), anchor: Some(anchor))

    var backgroundIndex: Int64 = -1
    var selectionIndex: Int64 = -1
    var textIndex: Int64 = -1
    var underlineIndex: Int64 = -1
    var caretIndex: Int64 = -1
    var i: Int64 = 0
    for (command in renderer.drawIr()) {
        let json = command.toJson()
        if (json.contains("\"r\":7,\"g\":8,\"b\":9,\"a\":77")) {
            backgroundIndex = i
        } else if (command.kind == "paint.fill" && json.contains("\"a\":115")) {
            selectionIndex = i
        } else if (command.kind == "text" && json.contains("abcdef")) {
            textIndex = i
        } else if (command.kind == "paint.stroke-line" && json.contains("\"r\":11")) {
            underlineIndex = i
        } else if (command.kind == "paint.fill" && selectionIndex >= 0) {
            caretIndex = i
        }
        i += 1
    }
    @Expect(backgroundIndex >= 0)
    @Expect(backgroundIndex < selectionIndex)
    @Expect(selectionIndex < textIndex)
    @Expect(textIndex < underlineIndex)
    @Expect(underlineIndex < caretIndex)
    @Expect(ctx.textInputAnchorRect().isSome())
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(2))
    @Expect(text.value, "abcdef")
}

@Test
func textAreaEditingAndUndoRemainIndependentFromDecorations(): Unit {
    let text = State<String>("hi")
    let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(0, 2, decorationTestStyle(
            foreground: Some(Color.rgb(90, 120, 210))))
    ]))
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let area = TextArea(text, key: "editable-decoration", decorations: Some(decorations))
    area.layout(ctx, Rect(0.0, 0.0, 260.0, 100.0))
    ctx.focus("editable-decoration")

    @Expect(area.handle(ctx, UiEvent.TextInput("!")))
    @Expect(text.value, "hi!")
    area.undo()
    @Expect(text.value, "hi")
    area.redo()
    @Expect(text.value, "hi!")
    // The original snapshot is stale after edit/undo/redo assignments, but edit ownership stays intact.
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(text.value, "hi")
}

@Test
func textAreaWaveUnderlineIsDeterministicBoundedAndKeepsTextUntouched(): Unit {
    let text = State<String>("diagnostic_identifier")
    let underline = Color.rgb(220, 48, 64)
    let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(0, text.value.size, decorationTestStyle(
            underline: Some(underline), underlineShape: TextAreaUnderlineShape.Wave))
    ]))
    let (_, renderer) = drawDecoratedArea(text, decorations)

    var waveSegments: Int64 = 0
    for (command in renderer.drawIr()) {
        if (command.kind == "paint.stroke-line" && command.toJson().contains("\"r\":220")) {
            waveSegments += 1
        }
    }
    @Expect(waveSegments > Int64(2))
    @Expect(waveSegments <= Int64(256))
    @Expect(text.value, "diagnostic_identifier")
}
