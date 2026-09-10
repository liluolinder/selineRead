package sdl

@Test
func drawIrAsciiProjectsGeometryTextAndSymbolsDeterministically(): Unit {
    let commands = [
        DrawIrCommand("paint.fill", "", data: "\"x\":0,\"y\":0,\"width\":100,\"height\":50,\"color\":{\"r\":20,\"g\":20,\"b\":20,\"a\":255}"),
        DrawIrCommand("paint.stroke-line", "", data: "\"x1\":0,\"y1\":25,\"x2\":100,\"y2\":25,\"width\":1,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("paint.stroke-circle", "", data: "\"cx\":20,\"cy\":15,\"radius\":8,\"width\":1,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("text", "", data: "\"text\":\"HELLO\",\"x\":40,\"y\":10,\"pointSize\":12,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("symbol", "", data: "\"x\":60,\"y\":30,\"width\":30,\"height\":12,\"name\":\"play\"")
    ]
    let first = renderDrawIrAscii(commands, 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 40, rows: 12))
    let second = renderDrawIrAscii(commands, 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 40, rows: 12))
    @Expect(first, second)
    @Expect(first.contains("HELLO"))
    @Expect(first.contains("o"))
    @Expect(first.contains("[play]"))
    @Expect(first.contains("----------------------------------------"))
}

@Test
func drawIrAsciiOverlaysStableSemanticMarkersAndFunctionLegend(): Unit {
    let annotations = [
        DrawIrAsciiAnnotation(
            "toolbar.back",
            DrawIrAsciiAnnotationKind.Interactive,
            Rect(4.0, 4.0, 30.0, 18.0),
            component: "IconButton",
            role: "button",
            label: "Back",
            icon: "Icons.Back",
            action: "window.back()",
            shortcut: "Escape",
            state: "enabled"
        ),
        DrawIrAsciiAnnotation(
            "search",
            DrawIrAsciiAnnotationKind.Focus,
            Rect(40.0, 4.0, 50.0, 18.0),
            component: "TextField",
            role: "searchbox",
            label: "Search"
        ),
        DrawIrAsciiAnnotation(
            "preview",
            DrawIrAsciiAnnotationKind.Visual,
            Rect(4.0, 28.0, 86.0, 18.0),
            component: "Preview",
            label: "A \"quoted\"\nvalue"
        )
    ]
    let first = renderDrawIrAscii([], 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 50, rows: 12), annotations: annotations)
    let second = renderDrawIrAscii([], 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 50, rows: 12), annotations: annotations)
    @Expect(first, second)
    @Expect(first.contains("[$i1]"))
    @Expect(first.contains("<$f1>"))
    @Expect(first.contains("($v1)"))
    @Expect(first.contains("$i1 - \"IconButton#toolbar.back\""))
    @Expect(first.contains("action=\"window.back()\""))
    @Expect(first.contains("probe=\"press 19 13; release 19 13\""))
    @Expect(first.contains("label=\"A \\\"quoted\\\"\\nvalue\""))
}

@Test
func drawIrAsciiKeepsOverlappingTinyAnnotationsInTheLegend(): Unit {
    let annotations = [
        DrawIrAsciiAnnotation("first", DrawIrAsciiAnnotationKind.Interactive,
            Rect(0.0, 0.0, 2.0, 2.0), component: "Button"),
        DrawIrAsciiAnnotation("second", DrawIrAsciiAnnotationKind.Interactive,
            Rect(0.0, 0.0, 2.0, 2.0), component: "Button")
    ]
    let output = renderDrawIrAscii([], 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 20, rows: 8), annotations: annotations)
    @Expect(output.contains("$i1 - \"Button#first\""))
    @Expect(output.contains("$i2 - \"Button#second\""))
    @Expect(output.contains("Compact markers: [$N] action"))
    @Expect(output.contains("marker=legend-only"))
}
