/* Deterministic, windowless acceptance fixture for the no-wrap editor example. */
package chui_editor

import chui.*
import chui.kmode.macros.*

@CuiProbe["editor.no-wrap"]
func editorNoWrapProbe(script: String): String {
    let model = EditorModel()
    ComponentProbe("editor.no-wrap", width: 760.0, height: 560.0).run(script) {
        ProbeNode("editor-root", widgetType: "Editor",
            properties: [ProbeProperty("role", "code-editor-example")]) {
            editorView(model)
        }
    }
}
