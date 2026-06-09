package ohos_app_cangjie_entry

import ohos.ark_interop.JSContext
import ohos.ark_interop.JSModule
import ohos.ark_interop_macro.*
import ohos.ark_interop.*
import selineWebdav.startWebDavWithAuth
import stdx.logger.{SimpleLogger}
import stdx.log.{setGlobalLogger}
import std.io.OutputStream
import stdx.log.LogLevel
import stdx.log.Logger
import stdx.log.Attr
import stdx.log.LogRecord
import std.time.DateTime
import ohos.hilog.Hilog

var globalcontext: Option<JSContext> = None

let _ = JSModule.registerModule {context, _ => globalcontext = context}

public func run2JS(task: () -> Unit) {
    if (let Some(context) <- globalcontext) {
        context.postJSTask {
            context.newScope {
                task()
            }
        }
    }
}
