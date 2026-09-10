package chui.core

import sdl.{DrawIrCommand, Rect}

private func designSnapshotFixture(theme: String, moved!: Bool = false): DesignSnapshot {
    let semantics = SemanticTreeSnapshot("main", UInt64(3), [
        SemanticNode("save", Rect(if (moved) {12.0} else {8.0}, 8.0, 44.0, 36.0),
            "IconButton", "button", label: "Save", actions: [SemanticActionKind.Activate]),
        SemanticNode("editor", Rect(8.0, 52.0, 300.0, 180.0), "TextArea", "textarea",
            order: 1, label: "Source", value: "let x = 1", focused: Some(true), editable: Some(true),
            selectionStart: Some(Int64(9)), selectionEnd: Some(Int64(9)), actions: [SemanticActionKind.Focus])
    ])
    DesignSnapshot.fromSemantics(
        "studio.main",
        DesignSnapshotEnvironment("headless", 320.0, 240.0, theme: theme, locale: "zh-CN"),
        semantics,
        drawIr: [
            DrawIrCommand("paint.fill", "save", data: "\"x\":8,\"y\":8,\"width\":44,\"height\":36,\"color\":{\"r\":20,\"g\":20,\"b\":20,\"a\":255}"),
            DrawIrCommand("text", "editor", data: "\"text\":\"let x = 1\",\"x\":8,\"y\":52")
        ],
        states: [DesignSnapshotProperty("mode", "normal"), DesignSnapshotProperty("authToken", "must-not-leak")],
        inputDigest: "fixture:3")
}

@Test
func designSnapshotIsCanonicalBoundedAndRedactsSensitiveState(): Unit {
    let first = designSnapshotFixture("dark")
    let second = designSnapshotFixture("dark")
    @Expect(first.toJson(), second.toJson())
    @Expect(first.contentDigest, second.contentDigest)
    @Expect(first.toJson().contains("\"protocol\":\"canghui.design-snapshot/v1\""))
    @Expect(first.toJson().contains("\"kind\":\"screen\""))
    @Expect(first.toJson().contains("\"kind\":\"component\""))
    @Expect(first.toJson().contains("[redacted]"))
    @Expect(!first.toJson().contains("must-not-leak"))
}

@Test
func designSnapshotDiffSeparatesGeometryStateAndDrawEvidence(): Unit {
    let before = designSnapshotFixture("dark")
    let after = designSnapshotFixture("light", moved: true)
    let diff = after.diff(before)
    @Expect(diff.geometry.size, 1)
    @Expect(diff.geometry[0], "save")
    @Expect(diff.structure.isEmpty())
    @Expect(diff.draw.isEmpty())
    @Expect(diff.fromDigest != diff.toDigest)
}

@Test
func designSnapshotRejectsOrphanAndFilesystemIdentity(): Unit {
    var orphanRejected = false
    try {
        let _ = DesignSnapshot("bad", DesignSnapshotEnvironment("headless", 10.0, 10.0), [
            DesignSnapshotNode("child", DesignSnapshotNodeKind.Component, Rect.zero(), parentId: "missing")
        ])
    } catch (_: IllegalArgumentException) { orphanRejected = true }
    @Expect(orphanRejected)

    var pathRejected = false
    try {
        let _ = DesignSnapshot("/tmp/private", DesignSnapshotEnvironment("headless", 10.0, 10.0), [])
    } catch (_: IllegalArgumentException) { pathRejected = true }
    @Expect(pathRejected)
}

@Test
func designSnapshotRepresentsEveryLayerAndEmptyErrorRecoveryAnimatedStates(): Unit {
    let environment = DesignSnapshotEnvironment(
        "headless", 640.0, 480.0, theme: "dark", reducedMotion: false)
    let empty = DesignSnapshot("fixture.empty", environment, [])
    @Expect(empty.nodes.isEmpty())

    let error = DesignSnapshot("fixture.error", environment, [
        DesignSnapshotNode("document", DesignSnapshotNodeKind.Document, Rect.zero()),
        DesignSnapshotNode("page", DesignSnapshotNodeKind.Page, Rect.zero(), parentId: "document"),
        DesignSnapshotNode("state", DesignSnapshotNodeKind.State, Rect.zero(), parentId: "page",
            states: [DesignSnapshotProperty("phase", "error")]),
        DesignSnapshotNode("screen", DesignSnapshotNodeKind.Screen,
            Rect(0.0, 0.0, 640.0, 480.0), parentId: "state"),
        DesignSnapshotNode("region", DesignSnapshotNodeKind.Region,
            Rect(20.0, 20.0, 600.0, 440.0), parentId: "screen"),
        DesignSnapshotNode("component", DesignSnapshotNodeKind.Component,
            Rect(32.0, 32.0, 240.0, 80.0), parentId: "region", role: "alert",
            states: [DesignSnapshotProperty("recoverable", "true")]),
        DesignSnapshotNode("atomic", DesignSnapshotNodeKind.Atomic,
            Rect(44.0, 44.0, 120.0, 24.0), parentId: "component", widgetType: "Label")
    ], states: [
        DesignSnapshotProperty("recovery", "pending"),
        DesignSnapshotProperty("animation.progress", "0.35")
    ])
    let json = error.toJson()
    for (kind in ["document", "page", "state", "screen", "region", "component", "atomic"]) {
        @Expect(json.contains("\"kind\":\"${kind}\""))
    }
    @Expect(json.contains("\"key\":\"phase\",\"value\":\"error\""))
    @Expect(json.contains("\"key\":\"recovery\",\"value\":\"pending\""))
    @Expect(json.contains("\"key\":\"animation.progress\",\"value\":\"0.35\""))

    let recovered = DesignSnapshot("fixture.error", environment, error.nodes,
        states: [DesignSnapshotProperty("recovery", "complete"),
            DesignSnapshotProperty("animation.progress", "1.0")])
    let diff = recovered.diff(error)
    @Expect(diff.state, ["$snapshot"])
}
