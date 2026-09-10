package chui_layout_transition

import chui.{DesktopApp, WindowSpec, runKModeStdioIfRequested}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let model = LayoutTransitionModel()
    let app = DesktopApp(
        WindowSpec("CangHui · Keyed Layout Transition", 780, 620, scale: 1.25),
        theme: layoutTransitionTheme()
    )
    app.setMinimumSize(620, 500)
    app.run { layoutTransitionView(model) }
    return 0
}
