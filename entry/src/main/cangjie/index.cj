package ohos_app_cangjie_entry

import ohos.ark_interop_advance.*
import stdx.encoding.url.URL
import std.collection.HashMap
import linderHttp.Headers

var globalcontext: Option<JSContext> = None

public var baseUrl: URL = URL.parse("http://39.96.218.120:8800")
public var header: HashMap<String, String> = HashMap<String, String>()


let _ = JSModule.registerModule {context, _ =>
    globalcontext = context
    header.add("X-API-Token", "433465d0bd698d0b64c260b78e1953f25169b7ce2a47f1a64233d29a061453cd")
}

/**
 * 全局 [header] 映射 → linderHttp 的 `Headers`。
 *
 * 新版 linderHttp 的请求入口只接受 `Headers`（大小写不敏感、支持多值），
 * 不再接受裸 `HashMap`，所以传请求头之前要过这一道。
 */
public func requestHeaders(): Headers {
    let result = Headers()
    for ((name, value) in header) {
        result.set(name, value)
    }
    result
}

public func run2JS(task: () -> Unit) {
    if (let Some(context) <- globalcontext) {
        context.postJSTask {
            task()
        }
    }
}
