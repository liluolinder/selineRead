package ignite.middleware

import ignite.{Handler, Ctx}

public class RequestIdConfig {
    public var headerName: String = "X-Request-ID"
    public var contextKey: String = "request_id"
    public var generator: ?(() -> String) = None

    public init(
        headerName!: String = "X-Request-ID",
        contextKey!: String = "request_id",
        generator!: ?(() -> String) = None
    ) {
        this.headerName = headerName
        this.contextKey = contextKey
        this.generator = generator
    }
}

public func requestIdMiddleware(config!: RequestIdConfig = RequestIdConfig()): Handler {
    { ctx: Ctx =>
        var reqId = ctx.header(config.headerName) ?? ""
        if (reqId.size == 0) {
            if (let Some(gen) <- config.generator) {
                reqId = gen()
            } else {
                reqId = generateUUID()
            }
        }
        ctx.setHeader(config.headerName, reqId)
        ctx.setLocal(config.contextKey, reqId)
        ctx.next()
    }
}

func generateUUID(): String {
    let hex = generateRandomHex(32)
    let r = hex.toRuneArray()
    var uuid = ""
    for (i in 0..8) { uuid += r[i].toString() }
    uuid += "-"
    for (i in 8..12) { uuid += r[i].toString() }
    uuid += "-4"
    for (i in 13..16) { uuid += r[i].toString() }
    uuid += "-"
    for (i in 16..20) { uuid += r[i].toString() }
    uuid += "-"
    for (i in 20..32) { uuid += r[i].toString() }
    uuid
}
