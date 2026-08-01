package ohos_app_cangjie_entry

import ohos.ark_interop.JSContext
import ohos.ark_interop.JSModule
import ohos.ark_interop.*
import stdx.encoding.url.URL
import std.collection.HashMap


var globalcontext: Option<JSContext> = None

public var baseUrl: URL = URL.parse("http://39.96.218.120:8800")
public var header: HashMap<String, String> = HashMap<String, String>()


let _ = JSModule.registerModule {context, _ =>
    globalcontext = context
    header.add("X-API-Token", "433465d0bd698d0b64c260b78e1953f25169b7ce2a47f1a64233d29a061453cd")
}

public func run2JS(task: () -> Unit) {
    if (let Some(context) <- globalcontext) {
        context.postJSTask {
            context.newScope {
                task()
            }
        }
    }
}
