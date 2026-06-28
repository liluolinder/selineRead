package ignite.middleware

import ignite.{Handler, Ctx}
import std.time.{MonoTime, DateTime}

public class AccessLogConfig {
    public var output: (String) -> Unit = { msg => println(msg) }
    public var timeFormat: String = "yyyy-MM-dd HH:mm:ss"
    public var enableLatency: Bool = true
    public var enableIP: Bool = true
    public var enableUserAgent: Bool = false

    public init(
        output!: (String) -> Unit = { msg => println(msg) },
        timeFormat!: String = "yyyy-MM-dd HH:mm:ss",
        enableLatency!: Bool = true,
        enableIP!: Bool = true,
        enableUserAgent!: Bool = false
    ) {
        this.output = output
        this.timeFormat = timeFormat
        this.enableLatency = enableLatency
        this.enableIP = enableIP
        this.enableUserAgent = enableUserAgent
    }
}

public func accessLogMiddleware(config!: AccessLogConfig = AccessLogConfig()): Handler {
    { ctx: Ctx =>
        let start = MonoTime.now()
        let method = ctx.method
        let path = ctx.path
        let ip = ctx.ip

        ctx.next()

        let elapsed = MonoTime.now() - start
        let latencyMs = elapsed.toMilliseconds()
        let timestamp = DateTime.now().toString()

        var log = "${timestamp} | ${method} ${path}"
        if (config.enableIP) {
            log = "${timestamp} | ${ip} | ${method} ${path}"
        }
        if (config.enableLatency) {
            log += " | ${latencyMs}ms"
        }
        if (config.enableUserAgent) {
            let ua = ctx.header("user-agent") ?? "-"
            log += " | ${ua}"
        }
        log = appendAccessLogProxyFields(
            log,
            ctx.getLocal(IGNITE_PROXY_REQUEST_BODY_MODE_LOCAL_KEY) ?? "",
            ctx.getLocal(IGNITE_PROXY_REQUEST_BODY_BYTES_LOCAL_KEY) ?? "",
            ctx.getLocal(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_LOCAL_KEY) ?? "",
            ctx.getLocal(IGNITE_PROXY_RESPONSE_BODY_MODE_LOCAL_KEY) ?? "",
            ctx.getLocal(IGNITE_PROXY_RESPONSE_BODY_BYTES_LOCAL_KEY) ?? "",
            ctx.getLocal(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_LOCAL_KEY) ?? "",
            ctx.getLocal(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_LOCAL_KEY) ?? ""
        )
        config.output(log)
    }
}

func appendAccessLogProxyFields(
    log: String,
    proxyBodyMode: String,
    proxyBodyBytes: String,
    proxyBodyLimitBytes: String,
    proxyResponseBodyMode: String,
    proxyResponseBodyBytes: String,
    proxyDownstreamBodyMode: String,
    proxyDownstreamBodyBytes: String
): String {
    var out = log
    out = appendAccessLogField(out, "proxyBodyMode", proxyBodyMode)
    out = appendAccessLogField(out, "proxyBodyBytes", proxyBodyBytes)
    out = appendAccessLogField(out, "proxyBodyLimitBytes", proxyBodyLimitBytes)
    out = appendAccessLogField(out, "proxyResponseBodyMode", proxyResponseBodyMode)
    out = appendAccessLogField(out, "proxyResponseBodyBytes", proxyResponseBodyBytes)
    out = appendAccessLogField(out, "proxyDownstreamBodyMode", proxyDownstreamBodyMode)
    out = appendAccessLogField(out, "proxyDownstreamBodyBytes", proxyDownstreamBodyBytes)
    out
}

func appendAccessLogField(log: String, key: String, value: String): String {
    if (value.trimAscii().size == 0) {
        return log
    }
    log + " | ${key}=${value}"
}
