package chui.desktop

@When[debug]
@Test
func debugUiScriptParserKeepsOnlyBoundedCommands(): Unit {
    let commands = parseDebugUiScript("click 12 20\n\n focus field \n")

    @Expect(commands.size, 2)
    @Expect(commands[0], "click 12 20")
    @Expect(commands[1], "focus field")
}

@When[debug]
@Test
func debugUiObservationDiffReportsFocusAndNodeChanges(): Unit {
    let before = DebugUiObservation(UInt64(1), 640, 480, "first", ["first"], ["first"])
    let after = DebugUiObservation(UInt64(2), 640, 480, "second", ["second"], ["second", "event"])

    let diff = after.diffJson(before)

    @Expect(diff.contains("\"changed\":true"))
    @Expect(diff.contains("\"added\":[\"second\"]"))
    @Expect(diff.contains("\"removed\":[\"first\"]"))
    @Expect(diff.contains("\"interactive\":{\"added\":[\"second\",\"event\"]"))
}
