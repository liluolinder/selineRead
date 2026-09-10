package chui_layout_transition

import chui.*
import chui.kmode.macros.*

@CuiProbe["layout-transition.grid"]
func layoutTransitionGridProbe(script: String): String {
    let model = LayoutTransitionModel()
    ComponentProbe("layout-transition.grid", width: 780.0, height: 620.0,
        theme: layoutTransitionTheme()).run(script) {
        ProbeNode(
            "layout-transition-root",
            widgetType: "KeyedLayoutTransitionDemo",
            properties: [ProbeProperty("role", "layout-transition-fixture")],
            semantics: Some({=> [
                ProbeProperty("columns", model.columns.value.toString()),
                ProbeProperty("order", if (model.reversed.value) { "reverse" } else { "forward" })
            ]})
        ) {
            layoutTransitionView(model)
        }
    }
}
