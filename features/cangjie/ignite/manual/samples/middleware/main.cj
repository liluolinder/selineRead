import ignite.*
import ignite.middleware.*

main() {
    let app = App(config: Config(appName: "ignite-sample-middleware"))

    let loggerConfig = LoggerConfig()
    loggerConfig.enableEntityLog = true
    loggerConfig.linuxStyle = false
    loggerConfig.enableSelfCheck = false

    let corsConfig = CorsConfig()
    corsConfig.exposeHeaders = "ETag,X-Request-ID"
    corsConfig.maxAge = 600

    let compressConfig = CompressConfig()
    compressConfig.minBytes = 32
    compressConfig.skipIfNoGain = false

    app.use(requestIdMiddleware())
    app.use(corsMiddleware(config: corsConfig))
    app.use(loggerMiddleware(config: loggerConfig))
    app.use(etagMiddleware())
    app.use(compressMiddleware(config: compressConfig))

    app.get("/", { ctx =>
        _ = ctx.redirect("/api/health")
    })

    let api = app.group("/api")
    api.get("/health", { ctx =>
        let requestId = ctx.getLocal("request_id") ?? "-"
        _ = ctx.json(healthJson(requestId))
    })
    api.get("/blob", { ctx =>
        _ = ctx.sendString(buildBlob())
    })

    println("[sample/middleware] listening on http://127.0.0.1:18813")
    println("[sample/middleware] try: curl -i http://127.0.0.1:18813/api/health")
    println("[sample/middleware] try: curl -i -H 'Accept-Encoding: gzip, deflate' http://127.0.0.1:18813/api/blob")
    println("[sample/middleware] try: curl -i -X OPTIONS http://127.0.0.1:18813/api/blob")
    app.listen("127.0.0.1", 18813)
}

func buildBlob(): String {
    var out = ""
    var i: Int64 = 0
    while (i < 8) {
        if (i > 0) {
            out += "|"
        }
        out += "ignite-middleware-sample-payload"
        i += 1
    }
    out
}

func healthJson(requestId: String): String {
    "{\"ok\":true,\"service\":\"middleware-sample\",\"requestId\":\"" + requestId + "\"}"
}
