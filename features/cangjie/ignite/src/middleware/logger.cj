package ignite.middleware

import ignite.{Handler, Ctx, escapeJsonText}
import ignite.governance.*
import std.time.{MonoTime, DateTime}

/// Logger 接口：可由用户自定义实现并注入到 LoggerConfig，实现可覆写。
public interface Logger {
    func log(message: String): Unit
}

/// 默认 Logger 实现，可覆写 output 或子类覆写 log 以自定义输出。
public class DefaultLogger <: Logger {
    public var output: (String) -> Unit = { msg => println(msg) }

    public init(output!: (String) -> Unit = { msg => println(msg) }) {
        this.output = output
    }

    public override func log(message: String): Unit {
        output(message)
    }
}

/// 实体日志条目，用于 enableEntityLog 时的结构化记录。
public struct LogEntry {
    public let method: String
    public let path: String
    public let latencyMs: Int64

    public init(method: String, path: String, latencyMs: Int64) {
        this.method = method
        this.path = path
        this.latencyMs = latencyMs
    }
}

public class LoggerConfig {
    public var format: String = "[method] path - status latency"
    public var timeFormat: String = "ms"
    /// 使用接口 Logger，默认 DefaultLogger；可注入自定义实现。
    public var logger: Logger = DefaultLogger()
    /// 为 true 时以实体形式记录（method=GET path=/ latencyMs=...），否则为单行 [method] path latencyMs。
    public var enableEntityLog: Bool = false
    /// 0~9 十级语义，默认 6=INFO。
    public var level: Int64 = 6
    /// 默认普通模式输出 0~6，kmode 输出 0~9。
    public var levelPolicy: LoggerLevelPolicy = LoggerLevelPolicy()
    /// 类 Linux 风格输出（带颜色和请求标识）。
    public var linuxStyle: Bool = true
    /// 为 true 时按 JSON Line 输出，便于对接 ELK/Loki。
    public var jsonLine: Bool = false
    /// 脱敏敏感字段。
    public var redactSensitiveFields: Bool = true
    /// 自检与统计。
    public var enableSelfCheck: Bool = true
    public var selfCheckEvery: Int64 = 100

    public init(logger!: Logger = DefaultLogger(), enableEntityLog!: Bool = false) {
        this.logger = logger
        this.enableEntityLog = enableEntityLog
    }

    /// 兼容旧用法：仅传 output 时使用 DefaultLogger(output)。
    public init(output!: (String) -> Unit, enableEntityLog!: Bool = false) {
        this.logger = DefaultLogger(output: output)
        this.enableEntityLog = enableEntityLog
    }
}

class LoggerHealthState {
    var total: Int64 = 0
    var writeFail: Int64 = 0
    var dropped: Int64 = 0
    var maxLatencyMs: Int64 = 0
}

public func loggerMiddleware(config!: LoggerConfig = LoggerConfig()): Handler {
    let state = LoggerHealthState()

    func safeLog(raw: String): Unit {
        let msg = if (config.redactSensitiveFields) {
            redactSensitive(raw)
        } else {
            raw
        }
        try {
            config.logger.log(msg)
        } catch (_: Exception) {
            state.writeFail += 1
            println("[Ignite Logger] write failed, fallback stdout: " + msg)
        }
    }

    func emitSelfCheck(kmode: Bool): Unit {
        if (!config.enableSelfCheck || config.selfCheckEvery <= 0) { return }
        if (state.total % config.selfCheckEvery != 0) { return }
        let line = linuxLogLine(
            DateTime.now().toString(),
            5,
            "-",
            "logger-selfcheck total=${state.total} writeFail=${state.writeFail} dropped=${state.dropped} maxLatencyMs=${state.maxLatencyMs}",
            kmode
        )
        safeLog(line)
    }

    { ctx: Ctx =>
        let start = MonoTime.now()
        let method = ctx.method
        let path = ctx.path

        ctx.next()

        let elapsed = MonoTime.now() - start
        let latencyMs = elapsed.toMilliseconds()
        if (latencyMs > state.maxLatencyMs) {
            state.maxLatencyMs = latencyMs
        }

        let status = ctx.responseStatus
        let requestId = ctx.getLocal("request_id") ?? (ctx.header("X-Request-ID") ?? "-")
        let kmode = (ctx.getLocal("kmode") ?? "false") == "true"
        let level = clampLevel(config.level)
        if (!config.levelPolicy.shouldLog(level, kmode)) {
            state.dropped += 1
            return
        }

        state.total += 1
        let baseMsg = if (config.enableEntityLog) {
            "method=${method} path=${path} status=${status} latencyMs=${latencyMs}"
        } else {
            "[${method}] ${path} ${status} ${latencyMs}ms"
        }
        let proxyBodyMode = ctx.getLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY) ?? ""
        let proxyBodyBytes = ctx.getLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY) ?? ""
        let proxyBodyLimitBytes = ctx.getLocal(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY) ?? ""
        let proxyResponseBodyMode = ctx.getLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY) ?? ""
        let proxyResponseBodyBytes = ctx.getLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY) ?? ""
        let proxyDownstreamBodyMode = ctx.getLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY) ?? ""
        let proxyDownstreamBodyBytes = ctx.getLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY) ?? ""
        let message = appendProxyLogSuffix(
            baseMsg,
            proxyBodyMode,
            proxyBodyBytes,
            proxyBodyLimitBytes,
            proxyResponseBodyMode,
            proxyResponseBodyBytes,
            proxyDownstreamBodyMode,
            proxyDownstreamBodyBytes
        )
        let ts = DateTime.now().toString()
        if (config.jsonLine) {
            safeLog(
                toJsonLogLine(
                    ts,
                    level,
                    requestId,
                    method,
                    path,
                    status,
                    latencyMs,
                    kmode,
                    message,
                    proxyBodyMode,
                    proxyBodyBytes,
                    proxyBodyLimitBytes,
                    proxyResponseBodyMode,
                    proxyResponseBodyBytes,
                    proxyDownstreamBodyMode,
                    proxyDownstreamBodyBytes
                )
            )
        } else {
            if (config.enableEntityLog) {
                if (config.linuxStyle) {
                    let line = linuxLogLine(ts, level, requestId, message, kmode)
                    safeLog(line)
                } else {
                    safeLog(message)
                }
            } else {
                if (config.linuxStyle) {
                    let line = linuxLogLine(ts, level, requestId, message, kmode)
                    safeLog(line)
                } else {
                    safeLog(message)
                }
            }
        }
        emitSelfCheck(kmode)
    }
}

func toJsonLogLine(
    timestamp: String,
    level: Int64,
    requestId: String,
    method: String,
    path: String,
    status: UInt16,
    latencyMs: Int64,
    kmode: Bool,
    message: String,
    proxyBodyMode: String,
    proxyBodyBytes: String,
    proxyBodyLimitBytes: String,
    proxyResponseBodyMode: String,
    proxyResponseBodyBytes: String,
    proxyDownstreamBodyMode: String,
    proxyDownstreamBodyBytes: String
): String {
    let proxyJson = buildProxyLogJsonFields(
        proxyBodyMode,
        proxyBodyBytes,
        proxyBodyLimitBytes,
        proxyResponseBodyMode,
        proxyResponseBodyBytes,
        proxyDownstreamBodyMode,
        proxyDownstreamBodyBytes
    )
    #"{"timestamp":""# + escapeJsonLog(timestamp) +
        #"","level":"# + level.toString() +
        #","levelName":""# + escapeJsonLog(levelName(level)) +
        #"","requestId":""# + escapeJsonLog(requestId) +
        #"","method":""# + escapeJsonLog(method) +
        #"","path":""# + escapeJsonLog(path) +
        #"","status":"# + status.toString() +
        #","latencyMs":"# + latencyMs.toString() +
        #","kmode":"# + kmode.toString() +
        #","message":""# + escapeJsonLog(message) + #"""# +
        proxyJson +
        #"}"#
}

func escapeJsonLog(input: String): String {
    escapeJsonText(input)
}

func appendProxyLogSuffix(
    baseMsg: String,
    proxyBodyMode: String,
    proxyBodyBytes: String,
    proxyBodyLimitBytes: String,
    proxyResponseBodyMode: String,
    proxyResponseBodyBytes: String,
    proxyDownstreamBodyMode: String,
    proxyDownstreamBodyBytes: String
): String {
    var message = baseMsg
    message = appendProxyLogPart(message, "proxyBodyMode", proxyBodyMode)
    message = appendProxyLogPart(message, "proxyBodyBytes", proxyBodyBytes)
    message = appendProxyLogPart(message, "proxyBodyLimitBytes", proxyBodyLimitBytes)
    message = appendProxyLogPart(message, "proxyResponseBodyMode", proxyResponseBodyMode)
    message = appendProxyLogPart(message, "proxyResponseBodyBytes", proxyResponseBodyBytes)
    message = appendProxyLogPart(message, "proxyDownstreamBodyMode", proxyDownstreamBodyMode)
    message = appendProxyLogPart(message, "proxyDownstreamBodyBytes", proxyDownstreamBodyBytes)
    message
}

func appendProxyLogPart(message: String, key: String, value: String): String {
    if (value.trimAscii().size == 0) {
        return message
    }
    message + " ${key}=${value}"
}

func buildProxyLogJsonFields(
    proxyBodyMode: String,
    proxyBodyBytes: String,
    proxyBodyLimitBytes: String,
    proxyResponseBodyMode: String,
    proxyResponseBodyBytes: String,
    proxyDownstreamBodyMode: String,
    proxyDownstreamBodyBytes: String
): String {
    var out = ""
    out += buildOptionalJsonLogField("proxyBodyMode", proxyBodyMode)
    out += buildOptionalJsonLogField("proxyBodyBytes", proxyBodyBytes)
    out += buildOptionalJsonLogField("proxyBodyLimitBytes", proxyBodyLimitBytes)
    out += buildOptionalJsonLogField("proxyResponseBodyMode", proxyResponseBodyMode)
    out += buildOptionalJsonLogField("proxyResponseBodyBytes", proxyResponseBodyBytes)
    out += buildOptionalJsonLogField("proxyDownstreamBodyMode", proxyDownstreamBodyMode)
    out += buildOptionalJsonLogField("proxyDownstreamBodyBytes", proxyDownstreamBodyBytes)
    out
}

func buildOptionalJsonLogField(fieldName: String, value: String): String {
    if (value.trimAscii().size == 0) {
        return ""
    }
    ",\"" + escapeJsonLog(fieldName) + "\":\"" + escapeJsonLog(value) + "\""
}
