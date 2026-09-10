package chui.text

import chui.core.{ComponentProbe, State, VStack}

@Test
func textAreaSemanticsExposeNameValueFocusEditabilityAndByteSelection(): Unit {
    let text = State<String>("a你b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let report = ComponentProbe("test.textarea-accessibility", width: 360.0, height: 120.0)
        .run("focus semantic-area") {
            VStack {
                TextArea(text, key: "semantic-area", cursor: Some(cursor), anchor: Some(anchor))
                    .accessibilityLabel("Source editor")
            }
        }

    @Expect(report.contains("\"role\":\"textarea\""))
    @Expect(report.contains("\"label\":\"Source editor\""))
    @Expect(report.contains("\"value\":\"a你b\""))
    @Expect(report.contains("\"focused\":\"true\""))
    @Expect(report.contains("\"editable\":\"true\""))
    @Expect(report.contains("\"selectionStart\":\"1\""))
    @Expect(report.contains("\"selectionEnd\":\"4\""))
}

@Test
func readOnlyTextAreaSemanticsKeepValueButExposeNoEditingAction(): Unit {
    let report = ComponentProbe("test.textarea-readonly-accessibility", width: 320.0, height: 100.0)
        .run("") {
            TextArea(State<String>("logs"), key: "read-only-area", editable: false)
                .accessibilityLabel("Build output")
        }

    @Expect(report.contains("\"readonly\":\"true\""))
    @Expect(report.contains("\"editable\":\"false\""))
    @Expect(report.contains("\"value\":\"logs\""))
    @Expect(!report.contains("\"action\":\"TextArea.edit()\""))
}
