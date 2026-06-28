package ignite.governance

import ignite.escapeJsonText
import std.time.DateTime
import std.random.Random

public class AuditEvent {
    public var eventId: String = generateEventId()
    public var requestId: String = "-"
    public var timestamp: String = DateTime.now().toString()
    public var actor: String = "anonymous"
    public var ip: String = "-"
    public var route: String = "-"
    public var action: String = "-"
    public var result: String = "allow"
    public var riskLevel: Int64 = 5
    public var kmode: Bool = false
    public var session: String = "-"
    public var statusCode: UInt16 = 200
    public var latencyMs: Int64 = 0
    public var detail: String = ""
    public var guardEvent: String = ""
    public var guardExitCause: String = ""
    public var securityEvent: String = ""
    public var securityCode: String = ""
    public var securitySource: String = ""

    public init() {}

    public func toJson(): String {
        #"{"eventId":"# + "\"" + escapeJson(eventId) + "\"" +
        #","requestId":"# + "\"" + escapeJson(requestId) + "\"" +
        #","timestamp":"# + "\"" + escapeJson(timestamp) + "\"" +
        #","actor":"# + "\"" + escapeJson(actor) + "\"" +
        #","ip":"# + "\"" + escapeJson(ip) + "\"" +
        #","route":"# + "\"" + escapeJson(route) + "\"" +
        #","action":"# + "\"" + escapeJson(action) + "\"" +
        #","result":"# + "\"" + escapeJson(result) + "\"" +
        #","riskLevel":"# + "${riskLevel}" +
        #","kmode":"# + boolToJson(kmode) +
        #","session":"# + "\"" + escapeJson(session) + "\"" +
        #","statusCode":"# + "${statusCode}" +
        #","latencyMs":"# + "${latencyMs}" +
        #","detail":"# + "\"" + escapeJson(detail) + "\"" +
        #","guardEvent":"# + "\"" + escapeJson(guardEvent) + "\"" +
        #","guardExitCause":"# + "\"" + escapeJson(guardExitCause) + "\"" +
        #","securityEvent":"# + "\"" + escapeJson(securityEvent) + "\"" +
        #","securityCode":"# + "\"" + escapeJson(securityCode) + "\"" +
        #","securitySource":"# + "\"" + escapeJson(securitySource) + "\"" +
        #"}"#
    }
}

public class AuditConfig {
    public var enabled: Bool = true
    public var linuxStyle: Bool = true
    public var redactSensitiveFields: Bool = true
    public var level: Int64 = 6
    public var levelPolicy: LoggerLevelPolicy = LoggerLevelPolicy()
    public var output: (String) -> Unit = { msg => println(msg) }

    public init(
        enabled!: Bool = true,
        linuxStyle!: Bool = true,
        redactSensitiveFields!: Bool = true,
        level!: Int64 = 6,
        levelPolicy!: LoggerLevelPolicy = LoggerLevelPolicy(),
        output!: (String) -> Unit = { msg => println(msg) }
    ) {
        this.enabled = enabled
        this.linuxStyle = linuxStyle
        this.redactSensitiveFields = redactSensitiveFields
        this.level = clampLevel(level)
        this.levelPolicy = levelPolicy
        this.output = output
    }
}

public func emitAudit(event: AuditEvent, config!: AuditConfig = AuditConfig()): Unit {
    if (!config.enabled) { return }
    if (!config.levelPolicy.shouldLog(config.level, event.kmode)) { return }

    let payload = if (config.redactSensitiveFields) {
        redactEvent(event).toJson()
    } else {
        event.toJson()
    }
    if (config.linuxStyle) {
        let guardExtra = guardLineSuffix(event)
        let secExtra = securityLineSuffix(event)
        let line = linuxLogLine(
            event.timestamp,
            config.level,
            event.requestId,
            "audit action=${event.action} result=${event.result} risk=${event.riskLevel} status=${event.statusCode} latency=${event.latencyMs}ms route=${event.route} actor=${event.actor}${guardExtra}${secExtra}",
            event.kmode
        )
        config.output(line)
    }
    config.output(payload)
}

func redactEvent(event: AuditEvent): AuditEvent {
    let out = AuditEvent()
    out.eventId = event.eventId
    out.requestId = event.requestId
    out.timestamp = event.timestamp
    out.actor = redactSensitive(event.actor)
    out.ip = event.ip
    out.route = event.route
    out.action = event.action
    out.result = event.result
    out.riskLevel = event.riskLevel
    out.kmode = event.kmode
    out.session = redactSensitive(event.session)
    out.statusCode = event.statusCode
    out.latencyMs = event.latencyMs
    out.detail = redactSensitive(event.detail)
    out.guardEvent = event.guardEvent
    out.guardExitCause = event.guardExitCause
    out.securityEvent = event.securityEvent
    out.securityCode = event.securityCode
    out.securitySource = event.securitySource
    out
}

func guardLineSuffix(event: AuditEvent): String {
    if (event.guardEvent.size == 0) {
        return ""
    }
    let exitCausePart = if (event.guardExitCause.size > 0) {
        " guardExitCause=${event.guardExitCause}"
    } else {
        ""
    }
    " guardEvent=${event.guardEvent}${exitCausePart}"
}

func securityLineSuffix(event: AuditEvent): String {
    if (event.securityEvent.size == 0) {
        return ""
    }
    let codePart = if (event.securityCode.size > 0) {
        " securityCode=${event.securityCode}"
    } else {
        ""
    }
    let sourcePart = if (event.securitySource.size > 0) {
        " securitySource=${event.securitySource}"
    } else {
        ""
    }
    " securityEvent=${event.securityEvent}${codePart}${sourcePart}"
}

func generateEventId(): String {
    let rng = Random()
    let hex = "0123456789abcdef".toRuneArray()
    var s = "evt_"
    for (_ in 0..16) {
        s += hex[Int64(rng.nextUInt64() % 16)].toString()
    }
    s
}

func boolToJson(b: Bool): String {
    if (b) { "true" } else { "false" }
}

func escapeJson(s: String): String {
    escapeJsonText(s)
}

public func riskByStatus(status: UInt16): Int64 {
    let s = Int64(status)
    if (s >= 500) { return 2 }
    if (s >= 400) { return 3 }
    if (s >= 300) { return 5 }
    6
}

public func auditAction(method: String, path: String): String {
    method + " " + path
}
