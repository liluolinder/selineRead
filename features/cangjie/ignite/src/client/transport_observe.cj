package ignite.client

import ignite.escapeJsonText

public class ClientObserveSnapshot {
    public let outcome: String
    public let errorClass: String
    public let phase: String
    public let causeCode: String
    public let backendId: String
    public let providerId: String
    public let cryptoProviderId: String
    public let publicPath: String
    public let riskLevel: String
    public let transportTags: String
    public let retryable: Bool
    public let fallbackSuggested: Bool
    public let connectionConsumed: Bool
    public let retryCount: Int64
    public let durationMs: Int64
    public let fields: String
    public let responseStatus: UInt16
    public let fallbackFrom: String
    public let fallbackTo: String
    public let fallbackOutcome: String
    public let replayRequired: Bool
    public let cause: String

    public init(
        outcome: String,
        errorClass: String,
        phase: String,
        causeCode: String,
        backendId: String,
        providerId: String,
        cryptoProviderId: String,
        publicPath: String,
        riskLevel: String,
        transportTags: String,
        retryable: Bool,
        fallbackSuggested: Bool,
        connectionConsumed: Bool,
        retryCount: Int64,
        durationMs: Int64,
        fields: String,
        responseStatus: UInt16,
        fallbackFrom: String,
        fallbackTo: String,
        fallbackOutcome: String,
        replayRequired: Bool,
        cause: String
    ) {
        this.outcome = outcome
        this.errorClass = errorClass
        this.phase = phase
        this.causeCode = causeCode
        this.backendId = backendId
        this.providerId = providerId
        this.cryptoProviderId = cryptoProviderId
        this.publicPath = publicPath
        this.riskLevel = riskLevel
        this.transportTags = transportTags
        this.retryable = retryable
        this.fallbackSuggested = fallbackSuggested
        this.connectionConsumed = connectionConsumed
        this.retryCount = retryCount
        this.durationMs = durationMs
        this.fields = fields
        this.responseStatus = responseStatus
        this.fallbackFrom = fallbackFrom
        this.fallbackTo = fallbackTo
        this.fallbackOutcome = fallbackOutcome
        this.replayRequired = replayRequired
        this.cause = cause
    }

    public func toJson(): String {
        #"{"outcome":"# + "\"" + observeEscapeJson(outcome) + "\"" +
        #","errorClass":"# + "\"" + observeEscapeJson(errorClass) + "\"" +
        #","phase":"# + "\"" + observeEscapeJson(phase) + "\"" +
        #","causeCode":"# + "\"" + observeEscapeJson(causeCode) + "\"" +
        #","backendId":"# + "\"" + observeEscapeJson(backendId) + "\"" +
        #","providerId":"# + "\"" + observeEscapeJson(providerId) + "\"" +
        #","cryptoProviderId":"# + "\"" + observeEscapeJson(cryptoProviderId) + "\"" +
        #","publicPath":"# + "\"" + observeEscapeJson(publicPath) + "\"" +
        #","riskLevel":"# + "\"" + observeEscapeJson(riskLevel) + "\"" +
        #","transportTags":"# + "\"" + observeEscapeJson(transportTags) + "\"" +
        #","retryable":"# + observeBoolToJson(retryable) +
        #","fallbackSuggested":"# + observeBoolToJson(fallbackSuggested) +
        #","connectionConsumed":"# + observeBoolToJson(connectionConsumed) +
        #","retryCount":"# + "${retryCount}" +
        #","durationMs":"# + "${durationMs}" +
        #","fields":"# + "\"" + observeEscapeJson(fields) + "\"" +
        #","responseStatus":"# + "${responseStatus}" +
        #","fallbackFrom":"# + "\"" + observeEscapeJson(fallbackFrom) + "\"" +
        #","fallbackTo":"# + "\"" + observeEscapeJson(fallbackTo) + "\"" +
        #","fallbackOutcome":"# + "\"" + observeEscapeJson(fallbackOutcome) + "\"" +
        #","replayRequired":"# + observeBoolToJson(replayRequired) +
        #","cause":"# + "\"" + observeEscapeJson(cause) + "\"" +
        #"}"#
    }

    public func toLogLine(): String {
        if (outcome == "success") {
            return "[ignite.client.observe] outcome=success status=${responseStatus} backendId=${backendId} providerId=${providerId} cryptoProviderId=${cryptoProviderId} publicPath=${publicPath} riskLevel=${riskLevel} transportTags=${transportTags} retryCount=${retryCount} durationMs=${durationMs} fields=${normalizedObserveFields(fields)}"
        }

        var text = "[ignite.client.observe] errorClass=${errorClass} phase=${phase} causeCode=${causeCode} backendId=${backendId} providerId=${providerId} cryptoProviderId=${cryptoProviderId} publicPath=${publicPath} riskLevel=${riskLevel} transportTags=${transportTags} retryable=${retryable} fallbackSuggested=${fallbackSuggested} connectionConsumed=${connectionConsumed} retryCount=${retryCount} durationMs=${durationMs} fields=${normalizedObserveFields(fields)}"
        if (fallbackOutcome != "-") {
            text += " fallbackFrom=${fallbackFrom} fallbackTo=${fallbackTo} fallbackOutcome=${fallbackOutcome} replayRequired=${replayRequired}"
        }
        text += "; cause=${cause}"
        text
    }
}

func observeBoolToJson(value: Bool): String {
    if (value) { "true" } else { "false" }
}

func observeEscapeJson(value: String): String {
    escapeJsonText(value)
}

func normalizedObserveFields(fields: String): String {
    if (fields.size == 0) {
        return "-"
    }
    fields
}
