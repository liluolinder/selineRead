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

let _ = JSModule.registerModule {
    context, _ =>
        globalcontext = context
        let tl = LinderLogger()
        tl.level = LogLevel.TRACE
        setGlobalLogger(tl)
}

public class LinderLogger <: Logger {
    private let domain: UInt32 = 114514
    private let tag: String = 'LinderLogger'
    private var _level: LogLevel = LogLevel.ALL
    private var _closed: Bool = false

    public mut prop level: LogLevel {
        get() { _level }
        set(v) { _level = v }
    }

    public func log(level: LogLevel, message: String, attrs: Array<Attr>): Unit {
        if (this.enabled(level)) {
            let record = LogRecord(DateTime.now(), level, message, attrs)
            log(record)
        }
    }

    public func log(level: LogLevel, message: () -> String, attrs: Array<Attr>): Unit {
        if (this.enabled(level)) {
            let record = LogRecord(DateTime.now(), level, message(), attrs)
            log(record)
        }
    }

    public func log(record: LogRecord): Unit {
        if (_closed || record.level < _level) {
            return
        }

        let levelName = record.level.name
        let msg = "[${levelName}] ${record.message}"

        if (record.level == LogLevel.ERROR) {
            Hilog.error(domain, tag, msg)
        } else if (record.level == LogLevel.WARN) {
            Hilog.warn(domain, tag, msg)
        } else if (record.level == LogLevel.INFO) {
            Hilog.info(domain, tag, msg)
        } else {
            Hilog.debug(domain, tag, msg)
        }
    }

    public func withAttrs(attrs: Array<Attr>): Logger {
        this
    }

    public func close(): Unit {
        _closed = true
    }

    public func isClosed(): Bool {
        _closed
    }
}