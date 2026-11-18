@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

import zlibraryAPI4CJ.*
import ohos.prompt_action.PromptAction

// ---------------------------------------------------------------------------
// Shared view-model helpers (error text + toast). Package-level so every
// category view model can use them without depending on the root shell.
// ---------------------------------------------------------------------------

public func formatZlibError(err: ZlibError): String {
    match (err.kind) {
        case ZlibErrorKind.NotLoggedIn => "需要登录：${err.serverMessage}"
        case ZlibErrorKind.NotFound => "未找到资源：${err.serverMessage}"
        case ZlibErrorKind.Forbidden => "站点拒绝了请求，请在设置中更换可用域名，或登录后重试"
        case ZlibErrorKind.Cangjie => "网络或文件错误：${err.message}"
        case ZlibErrorKind.BadResponse => "站点返回异常响应（可能被风控），请更换域名重试"
        case ZlibErrorKind.Closed => "客户端已关闭，请重新进入页面"
        case _ => err.message
    }
}

public func toast(message: String): Unit {
    PromptAction.showToast(message: message, duration: 1800)
}
