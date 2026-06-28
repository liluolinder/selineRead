package ignite.middleware

import ignite.{Handler, Ctx}
import ignite.governance.*
import std.collection.ArrayList
import std.time.DateTime
import std.sync.Mutex

let _kmodeLegacyOpenWarningMutex = Mutex()
let _kmodeLegacyOpenWarningHistory = ArrayList<String>()

/// kmode（调试模式）中间件：当 kmode 为 true 时，在请求上下文中设置 local "kmode"="true"，
/// 便于后续 Handler 或中间件识别并做额外调试输出。需配合 Config.kmode 使用；启动后 Banner 等由 Config.kmode 控制。
///
/// `kmodeMiddleware(Bool)` 现在只保留为 loopback-only 的 legacy-open 兼容通道：
/// 它仍然省略 Header Key，但不再默认对所有来源开放。
public func kmodeMiddleware(kmode: Bool): Handler {
    let policy = KModePolicy(
        enabled: kmode,
        legacyOpen: true,
        allowIPs: ["127.0.0.1", "::1"],
        capabilities: [Diag, Read, Write, Admin]
    )
    kmodeMiddleware(policy)
}

public func kmodeMiddleware(policy: KModePolicy): Handler {
    emitKModeLegacyOpenWarningIfNeeded(policy)
    let auditCfg = AuditConfig(level: 5)
    { ctx: Ctx =>
        if (!policy.enabled) {
            ctx.next()
            return
        }

        if (policy.legacyOpen) {
            if (!policy.ipAllowed(ctx.ip)) {
                ctx.next()
                return
            }
            ctx.setLocal("kmode", "true")
            ctx.setLocal("kmode_caps", policy.capabilitiesString())
            ctx.next()
            return
        }

        let attempted = (ctx.header(policy.headerName) ?? "").size > 0
        if (!attempted) {
            ctx.next()
            return
        }

        let authOk = policy.authorize(ctx)
        let event = AuditEvent()
        event.timestamp = DateTime.now().toString()
        event.requestId = ctx.getLocal("request_id") ?? (ctx.header("X-Request-ID") ?? "-")
        event.actor = ctx.header("X-Actor-ID") ?? "anonymous"
        event.ip = ctx.ip
        event.route = ctx.path
        event.action = "KMODE_AUTH"
        event.kmode = authOk
        event.session = ctx.getLocal("session_id") ?? "-"
        if (authOk) {
            event.result = "allow"
            event.detail = "kmode granted"
            event.riskLevel = 4
            ctx.setLocal("kmode", "true")
            ctx.setLocal("kmode_caps", policy.capabilitiesString())
            emitAudit(event, config: auditCfg)
            ctx.next()
        } else {
            event.result = "deny"
            event.detail = "kmode denied: invalid key or source ip"
            event.riskLevel = 2
            emitAudit(event, config: auditCfg)
            ctx.status(403).sendString("Forbidden - Invalid KMode policy")
        }
    }
}

func emitKModeLegacyOpenWarningIfNeeded(policy: KModePolicy): Unit {
    match (policy.legacyOpenWarning()) {
        case Some(message) =>
            var shouldPrint = false
            synchronized(_kmodeLegacyOpenWarningMutex) {
                shouldPrint = true
                for (seen in _kmodeLegacyOpenWarningHistory) {
                    if (seen == message) {
                        shouldPrint = false
                        break
                    }
                }
                if (shouldPrint) {
                    _kmodeLegacyOpenWarningHistory.add(message)
                }
            }
            if (shouldPrint) {
                println(message)
            }
        case None => ()
    }
}
