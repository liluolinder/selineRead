package chui.core

import sdl.Rect

@Test
func uiHealthAuditFindsSmallStretchedUnlabelledOverlapAndOverflow(): Unit {
    let snapshot = DesignSnapshot("health.fixture",
        DesignSnapshotEnvironment("headless", 300.0, 200.0), [
            DesignSnapshotNode("screen", DesignSnapshotNodeKind.Screen,
                Rect(0.0, 0.0, 300.0, 200.0), role: "screen"),
            DesignSnapshotNode("tiny-icon", DesignSnapshotNodeKind.Component,
                Rect(8.0, 8.0, 20.0, 20.0), parentId: "screen", widgetType: "IconButton",
                role: "button", states: [DesignSnapshotProperty("actions", "activate")]),
            DesignSnapshotNode("overlap", DesignSnapshotNodeKind.Component,
                Rect(18.0, 8.0, 40.0, 36.0), parentId: "screen", widgetType: "Button",
                role: "button", label: "Open", states: [DesignSnapshotProperty("actions", "activate")]),
            DesignSnapshotNode("stretched", DesignSnapshotNodeKind.Component,
                Rect(8.0, 70.0, 160.0, 90.0), parentId: "screen", widgetType: "Button",
                role: "button", label: "Connect", states: [DesignSnapshotProperty("actions", "activate")]),
            DesignSnapshotNode("outside", DesignSnapshotNodeKind.Component,
                Rect(280.0, 180.0, 40.0, 40.0), parentId: "screen", widgetType: "Label")
        ])
    let report = UiHealthAudit.analyze(snapshot)
    let json = report.toJson()
    @Expect(!report.passed())
    @Expect(json.contains("CHUI-AUDIT-TARGET-SMALL"))
    @Expect(json.contains("CHUI-AUDIT-TARGET-STRETCHED"))
    @Expect(json.contains("CHUI-AUDIT-ICON-LABEL-MISSING"))
    @Expect(json.contains("CHUI-AUDIT-SIBLING-OVERLAP"))
    @Expect(json.contains("CHUI-AUDIT-CONTENT-OUTSIDE-OWNER"))
    @Expect(json.contains("CHUI-AUDIT-FOCUS-ORDER-AMBIGUOUS"))
}

@Test
func uiHealthAuditDistinguishesClippingAndCollectionOverflow(): Unit {
    let snapshot = DesignSnapshot("overflow.fixture",
        DesignSnapshotEnvironment("headless", 200.0, 100.0), [
            DesignSnapshotNode("row", DesignSnapshotNodeKind.Component,
                Rect(0.0, 0.0, 100.0, 40.0), widgetType: "Row",
                states: [DesignSnapshotProperty("clipPolicy", "shape")]),
            DesignSnapshotNode("tail", DesignSnapshotNodeKind.Component,
                Rect(80.0, 0.0, 40.0, 40.0), parentId: "row", order: 1,
                widgetType: "Label", label: "Tail")
        ])
    let json = UiHealthAudit.analyze(snapshot).toJson()
    @Expect(json.contains("CHUI-AUDIT-CLIPPED-DESCENDANT"))
    @Expect(json.contains("CHUI-AUDIT-COLLECTION-OVERFLOW"))
}

@Test
func uiHealthAuditKeepsCleanControlGreenAndReportsMovementAsInfo(): Unit {
    let before = DesignSnapshot("clean", DesignSnapshotEnvironment("headless", 200.0, 100.0), [
        DesignSnapshotNode("screen", DesignSnapshotNodeKind.Screen, Rect(0.0, 0.0, 200.0, 100.0)),
        DesignSnapshotNode("save", DesignSnapshotNodeKind.Component, Rect(8.0, 8.0, 44.0, 36.0),
            parentId: "screen", widgetType: "IconButton", role: "button", label: "Save",
            states: [DesignSnapshotProperty("actions", "activate")])
    ])
    let after = DesignSnapshot("clean", DesignSnapshotEnvironment("headless", 200.0, 100.0), [
        DesignSnapshotNode("screen", DesignSnapshotNodeKind.Screen, Rect(0.0, 0.0, 200.0, 100.0)),
        DesignSnapshotNode("save", DesignSnapshotNodeKind.Component, Rect(12.0, 8.0, 44.0, 36.0),
            parentId: "screen", widgetType: "IconButton", role: "button", label: "Save",
            states: [DesignSnapshotProperty("actions", "activate")])
    ])
    @Expect(UiHealthAudit.analyze(before).passed())
    let changed = UiHealthAudit.analyzeChange(before, after)
    @Expect(changed.passed())
    @Expect(changed.toJson().contains("CHUI-AUDIT-GEOMETRY-CHANGED"))
}
