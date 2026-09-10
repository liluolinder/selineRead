/*
 * CangHui 示例：可点击链接。
 *
 * 演示 `RichSpan` 的可点击链接：一条活动通知里，人名、文件、频道等以彩色下划线链接呈现（`RichSpan.onTap`），
 * 鼠标悬停变手型光标，点击运行回调——这里把被点链接显示到底部详情条。综合演示富文本内联交互 + 状态绑定。
 */
package chui_links

import chui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = LinksModel()
    let app = DesktopApp(WindowSpec("CangHui 可点击链接", 620, 600, scale: 1.5), theme: linksTheme())
    app.setMinimumSize(520, 480)
    app.run {
        linksView(model)
    }
    return 0
}
