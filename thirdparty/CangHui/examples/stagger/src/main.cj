/*
 * CangHui 示例：交错入场。
 *
 * 演示 `Animator`/`Reveal` 的 `delay`（CSS transition-delay 的对应物）：给每行一个「行号 × 步进」的等待，
 * 整组便从「一起弹出」变成「依次落位」的瀑布。综合演示交错动效 + 缓动曲线 + 状态绑定。
 */
package chui_stagger

import chui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = StaggerModel()
    let app = DesktopApp(WindowSpec("CangHui 交错入场", 620, 600, scale: 1.5), theme: staggerTheme())
    app.setMinimumSize(520, 480)
    app.run {
        staggerView(model)
    }
    return 0
}
