package chui.core

import sdl.{Color, DrawIrAsciiAnnotationKind, Rect, Size, UiEvent}

func buttonProbeReport(script: String): String {
    let clicks = State<Int64>(0)
    ComponentProbe("test.button", width: 240.0, height: 100.0).run(script) {
        ProbeNode("root", widgetType: "VStack") {
            VStack(padding: LengthInsets(12.vp)) {
                Button("Probe", probedAction("button.click", { => clicks.value += 1 }), role: ButtonRole.Primary)
                    .key("button")
                    .probe("button", "Button", [
                        ProbeProperty("role", "button"),
                        ProbeProperty("label", "Probe"),
                        ProbeProperty("action", "button.click()"),
                        ProbeProperty("shortcut", "Enter|Space")
                    ], { => [
                        ProbeProperty("clicks", clicks.value.toString()),
                        ProbeProperty("selected", (clicks.value > 0).toString())
                    ] })
            }
        }
    }
}

@Test
func componentProbeIsDeterministicAndCapturesBehavior(): Unit {
    let script = "move-in 60 30\n" +
        "assert state button hover true\n" +
        "press 60 30\n" +
        "advance 60\n" +
        "assert animation button animator between 0.8 0.9\n" +
        "release 60 30\n" +
        "assert activation button.click 1\n" +
        "assert property button clicks 1\n" +
        "assert draw text 1"
    let first = buttonProbeReport(script)
    let second = buttonProbeReport(script)
    @Expect(first, second)
    @Expect(first.contains("\"protocol\":\"cui.probe.v0\""))
    @Expect(first.contains("\"ok\":true"))
    @Expect(first.contains("\"scope\":\"button\""))
    @Expect(first.contains("\"activations\":[\"button.click\"]"))
}

@Test
func componentProbePreservesMoveOutCancellation(): Unit {
    let report = buttonProbeReport(
        "move-in 60 30\npress 60 30\nmove-out 230 90\nrelease 230 90\n" +
        "assert activation button.click 0\nassert property button clicks 0"
    )
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"command\":\"release 230 90\",\"consumed\":false"))
}

@Test
func componentProbeRejectsDuplicateNodeIds(): Unit {
    let report = ComponentProbe("test.duplicate", width: 100.0, height: 100.0).run("") {
        VStack {
            ProbeNode("same") { Label("one") }
            ProbeNode("same") { Label("two") }
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("duplicate component probe node id"))
}

@Test
func componentProbeCanRenderTheLatestDrawIrAsAscii(): Unit {
    let report = ComponentProbe("test.ascii", width: 200.0, height: 80.0).run("@cui-ascii 40 10") {
        Button("ASCII", { => }).key("ascii-button").probe("button", "Button", [
            ProbeProperty("role", "button"),
            ProbeProperty("label", "ASCII"),
            ProbeProperty("action", "button.click()")
        ])
    }
    @Expect(report.contains("CangHui headless Draw IR 200.000000x80.000000 -> 40x10"))
    @Expect(report.contains("ASCII"))
    @Expect(report.contains("[$i1]"))
    @Expect(report.contains("$i1 - \"Button#button\""))
    @Expect(report.contains("action=\"button.click()\""))
    @Expect(!report.contains("\"drawIr\""))
}

@Test
func componentProbeExportsDeterministicDesignSnapshot(): Unit {
    let first = ComponentProbe("test.design", width: 120.0, height: 60.0).run("@cui-design-snapshot") {
        Button("Save", { => }).key("save").probe("save", "Button", [
            ProbeProperty("role", "button"),
            ProbeProperty("label", "Save"),
            ProbeProperty("action", "save()")
        ])
    }
    let second = ComponentProbe("test.design", width: 120.0, height: 60.0).run("@cui-design-snapshot") {
        Button("Save", { => }).key("save").probe("save", "Button", [
            ProbeProperty("role", "button"),
            ProbeProperty("label", "Save"),
            ProbeProperty("action", "save()")
        ])
    }
    @Expect(first, second)
    @Expect(first.contains("\"protocol\":\"canghui.design-snapshot/v1\""))
    @Expect(first.contains("\"id\":\"save\""))
    @Expect(first.contains("\"scope\":\"save\""))
}

@Test
func componentProbeExportsDeterministicUiHealthAudit(): Unit {
    let report = ComponentProbe("health.button", width: 120.0, height: 80.0).run(
        "@cui-ui-audit warning") {
        Button("Save", {=> ()}).key("save").probe("save", "Button", [
            ProbeProperty("role", "button"), ProbeProperty("label", "Save"),
            ProbeProperty("actionOwner", "save")
        ]).width(80.0).height(36.0)
    }
    @Expect(report.contains("\"protocol\":\"canghui.ui-health/v1\""))
    @Expect(report.contains("\"passed\":true"))
}

private class SemanticRegionProbe <: Widget {
    private var frame = Rect.zero()

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fill(frame, Color.rgb(20, 20, 20))
        probeSemanticRegions { => [
            ProbeSemanticRegion(
                "custom.play",
                DrawIrAsciiAnnotationKind.Interactive,
                Rect(frame.x + 10.0, frame.y + 10.0, 40.0, 30.0),
                widgetType: "IconButton",
                properties: [
                    ProbeProperty("role", "button"),
                    ProbeProperty("icon", "Icons.Play"),
                    ProbeProperty("label", "Play"),
                    ProbeProperty("action", "player.play()"),
                    ProbeProperty("shortcut", "Space")
                ]
            )
        ] }
    }

    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func componentProbeCapturesCustomDrawnSemanticRegions(): Unit {
    let json = ComponentProbe("test.regions", width: 120.0, height: 60.0).run("") {
        let widget = SemanticRegionProbe()
        emit(widget)
    }
    @Expect(json.contains("\"regions\":[{\"id\":\"custom.play\""))
    @Expect(json.contains("\"kind\":\"interactive\""))

    let ascii = ComponentProbe("test.regions", width: 120.0, height: 60.0).run("@cui-ascii 40 10") {
        let widget = SemanticRegionProbe()
        emit(widget)
    }
    @Expect(ascii.contains("[$i1]"))
    @Expect(ascii.contains("Icons.Play"))
    @Expect(ascii.contains("player.play()"))
    @Expect(ascii.contains("probe=\"press 30 25; release 30 25\""))
}

@Test
func componentProbeKeepsInputNodesInTheFocusMarkerFamily(): Unit {
    let ascii = ComponentProbe("test.focus", width: 200.0, height: 60.0).run("@cui-ascii 40 10") {
        ProbeNode("search", widgetType: "TextField", properties: [
            ProbeProperty("role", "searchbox"),
            ProbeProperty("label", "Search"),
            ProbeProperty("action", "search.submit()"),
            ProbeProperty("shortcut", "Enter")
        ]) {
            Label("Search")
        }
    }
    @Expect(ascii.contains("<$f1>"))
    @Expect(ascii.contains("$f1 - \"TextField#search\""))
    @Expect(!ascii.contains("$i1 - \"TextField#search\""))
}

@Test
func componentProbeRejectsSemanticRegionIdsThatCollideWithNodes(): Unit {
    let report = ComponentProbe("test.region-collision", width: 120.0, height: 60.0).run("") {
        ProbeNode("custom.play") {
            let widget = SemanticRegionProbe()
            emit(widget)
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("duplicate component probe semantic region id: custom.play"))
}

@Test
func disabledAutomaticControlSemanticsRemoveActionsAndExposeState(): Unit {
    let report = ComponentProbe("test.disabled-automatic-semantics", width: 260.0, height: 120.0).run("") {
        Button("Disabled", {=> ()}).key("disabled-button").enabled(false)
    }
    @Expect(report.contains("\"id\":\"control-semantic:disabled-button\""))
    @Expect(report.contains("\"disabled\":\"true\""))
    @Expect(report.contains("\"enabled\":\"false\""))
    @Expect(!report.contains("Button.activate()"))
    @Expect(!report.contains("Enter|Space"))
}

@Test
func disabledExplicitProbeTruthDoesNotDependOnModifierOrder(): Unit {
    let report = ComponentProbe("test.disabled-explicit-order", width: 320.0, height: 140.0).run("") {
        VStack {
            Button("Probe first", {=> ()}).key("probe-first")
                .probe("probe-first", "Button", [
                    ProbeProperty("role", "button"),
                    ProbeProperty("action", "probe-first.activate()"),
                    ProbeProperty("shortcut", "Enter|Space")
                ]).enabled(false)
            Button("Enabled first", {=> ()}).key("enabled-first").enabled(false)
                .probe("enabled-first", "Button", [
                    ProbeProperty("role", "button"),
                    ProbeProperty("action", "enabled-first.activate()"),
                    ProbeProperty("shortcut", "Enter|Space")
                ])
        }
    }
    @Expect(report.contains("\"id\":\"probe-first\""))
    @Expect(report.contains("\"id\":\"enabled-first\""))
    @Expect(report.contains("\"disabled\":\"true\""))
    @Expect(!report.contains("probe-first.activate()"))
    @Expect(!report.contains("enabled-first.activate()"))
    @Expect(!report.contains("Enter|Space"))
}

@Test
func disabledContainerPropagatesToDescendantControlSemantics(): Unit {
    let report = ComponentProbe("test.disabled-container-semantics", width: 320.0, height: 140.0).run("") {
        VStack {
            Button("First", {=> ()}).key("disabled-first")
            Button("Second", {=> ()}).key("disabled-second")
        }.enabled(false)
    }
    @Expect(report.contains("control-semantic:disabled-first"))
    @Expect(report.contains("control-semantic:disabled-second"))
    @Expect(!report.contains("Button.activate()"))
    @Expect(!report.contains("Enter|Space"))
}
