/*
 * 发布说明入口：组装模型与窗口。
 */
package chui_richtext

import chui.{DesktopApp, WindowSpec}

main(): Unit {
    let model = RichTextModel()
    let app = DesktopApp(WindowSpec("CangHui 发布说明", 680, 760, scale: 1.5), theme: richtextTheme())
    app.run {
        richtextView(model)
    }
}
