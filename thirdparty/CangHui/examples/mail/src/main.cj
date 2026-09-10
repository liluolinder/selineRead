/*
 * 邮件客户端入口：组装模型与窗口。
 */
package chui_mail

import chui.{DesktopApp, WindowSpec}

main(): Unit {
    let model = MailModel()
    let app = DesktopApp(WindowSpec("CangHui 邮件客户端", 860, 620, scale: 1.5), theme: mailTheme())
    app.run {
        mailView(model)
    }
}
