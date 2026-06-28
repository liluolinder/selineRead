package ignite.client

import ignite.api2 as api2
import ignite.security as security

class TransportSelectionDecision {
    let candidateOrder: String
    let selectedBackend: String
    let selectedReason: String
    let fallbackChain: String
    let riskLevel: String
    let publicPath: String
    let providerId: String
    let cryptoProviderId: String
    let observabilityTags: String
    let contractSelectedBackend: String
    let contractFallbackBackend: String

    init(
        candidateOrder: String,
        selectedBackend: String,
        selectedReason: String,
        fallbackChain: String,
        riskLevel: String,
        publicPath: String,
        providerId: String,
        cryptoProviderId: String,
        observabilityTags: String,
        contractSelectedBackend: String,
        contractFallbackBackend: String
    ) {
        this.candidateOrder = candidateOrder
        this.selectedBackend = selectedBackend
        this.selectedReason = selectedReason
        this.fallbackChain = fallbackChain
        this.riskLevel = riskLevel
        this.publicPath = publicPath
        this.providerId = providerId
        this.cryptoProviderId = cryptoProviderId
        this.observabilityTags = observabilityTags
        this.contractSelectedBackend = contractSelectedBackend
        this.contractFallbackBackend = contractFallbackBackend
    }
}

class TransportFallbackDecisionRecord {
    let fromBackend: String
    let toBackend: String
    let triggerFamily: String
    let triggerPhase: String
    let safeToRetry: Bool
    let requestReplayRequired: Bool
    let visibility: String
    let finalOutcome: String

    init(
        fromBackend: String,
        toBackend: String,
        triggerFamily: String,
        triggerPhase: String,
        safeToRetry: Bool,
        requestReplayRequired: Bool,
        visibility: String,
        finalOutcome: String
    ) {
        this.fromBackend = fromBackend
        this.toBackend = toBackend
        this.triggerFamily = triggerFamily
        this.triggerPhase = triggerPhase
        this.safeToRetry = safeToRetry
        this.requestReplayRequired = requestReplayRequired
        this.visibility = visibility
        this.finalOutcome = finalOutcome
    }
}

func buildClientTransportSelectionDecision(
    targetUrl: String,
    x509Verify: ?security.X509VerifyOption,
    requestCryptoConfig!: ?api2.ClientCryptoConfig = None,
    requiresMultipart!: Bool = false,
    preferredBackendHint!: String = "",
    allowExperimental!: Bool = false
): TransportSelectionDecision {
    let scheme = detectTransportScheme(targetUrl)
    let cryptoProviderId = describeCryptoProvider(requestCryptoConfig)
    let contractRequest = api2.BackendSelectionRequest(
        "client",
        scheme,
        false,
        requiresMultipart,
        isX509Enabled(x509Verify),
        preferredBackendHint,
        allowExperimental,
        0,
        "sni=" + extractTransportHost(targetUrl)
    )
    let contractDecision = api2.selectBackend(contractRequest)
    let tlsPlan = api2.buildTlsAttachPlan(contractRequest, contractDecision)

    TransportSelectionDecision(
        joinStringArray(contractDecision.candidateOrder),
        normalizeBackendId(contractDecision.selectedBackend),
        contractDecision.selectedReason,
        firstNormalizedFallback(contractDecision.fallbackChain),
        adaptRiskLevel(contractDecision.riskLevel, scheme, x509Verify, cryptoProviderId),
        contractDecision.publicPath,
        normalizeProviderId(tlsPlan.providerId, scheme),
        cryptoProviderId,
        buildObserveTags(scheme, x509Verify, cryptoProviderId),
        contractDecision.selectedBackend,
        firstStringOrDash(contractDecision.fallbackChain)
    )
}

func buildSuggestedFallbackDecisionRecord(
    selection: TransportSelectionDecision,
    envelope: TransportErrorEnvelope
): ?TransportFallbackDecisionRecord {
    if (!envelope.fallbackSuggested) {
        return None
    }
    if (envelope.family == "CRYPTO" && envelope.causeCode == "crypto_unavailable") {
        let fromBackend = selection.selectedBackend + "@" + cryptoProviderOrUnknown(selection)
        let fallbackToStdx = selection.cryptoProviderId != "crypto:stdx-fallback"
        return Some(
            TransportFallbackDecisionRecord(
                fromBackend,
                if (fallbackToStdx) {
                    selection.selectedBackend + "@crypto:stdx-fallback"
                } else {
                    selection.selectedBackend + "@crypto:manual-review"
                },
                envelope.family,
                envelope.phase,
                envelope.retryable,
                envelope.connectionConsumed,
                "internal-only",
                if (fallbackToStdx) { "suggested-only" } else { "manual-review" }
            )
        )
    }

    let triggerFamily = mapEnvelopeToTransportFallbackFamily(envelope)
    if (triggerFamily.size == 0) {
        return None
    }

    let contractRecord = api2.decideFallback(
        if (selection.contractSelectedBackend.size > 0) {
            selection.contractSelectedBackend
        } else {
            "stdx-default"
        },
        triggerFamily,
        envelope.phase.toAsciiUpper(),
        envelope.connectionConsumed
    )
    return adaptContractFallbackRecord(selection, contractRecord)
}

func detectTransportScheme(targetUrl: String): String {
    let lower = targetUrl.trimAscii().toAsciiLower()
    if (startsWithTransportDecision(lower, "https://")) {
        return "https"
    }
    if (startsWithTransportDecision(lower, "http://")) {
        return "http"
    }
    "unknown"
}

func isX509Enabled(option: ?security.X509VerifyOption): Bool {
    if (let Some(value) <- option) {
        return value.enabled
    }
    false
}

func describeCryptoProvider(config: ?api2.ClientCryptoConfig): String {
    if (let Some(value) <- config) {
        return "crypto:" + value.providerKind.toString()
    }
    "-"
}

func cryptoProviderOrUnknown(selection: TransportSelectionDecision): String {
    if (selection.cryptoProviderId == "-") {
        return "crypto:unknown"
    }
    selection.cryptoProviderId
}

func startsWithTransportDecision(text: String, prefix: String): Bool {
    let a = text.toRuneArray()
    let b = prefix.toRuneArray()
    if (a.size < b.size) {
        return false
    }
    for (i in 0..b.size) {
        if (a[i] != b[i]) {
            return false
        }
    }
    true
}

func joinStringArray(values: Array<String>): String {
    if (values.size == 0) {
        return "-"
    }
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += ","
        }
        first = false
        out += value
    }
    out
}

func normalizeBackendId(raw: String): String {
    if (raw == "stdx-default") {
        return "stdx-http-client"
    }
    raw
}

func normalizeProviderId(raw: String, scheme: String): String {
    if (scheme != "https" || raw.size == 0) {
        return "-"
    }
    if (raw == "stdx") {
        return "tls:stdx-default"
    }
    if (raw == "jinguissl") {
        return "tls:jinguissl"
    }
    "tls:" + raw
}

func firstNormalizedFallback(values: Array<String>): String {
    let first = firstStringOrDash(values)
    if (first == "-") {
        return "-"
    }
    normalizeBackendId(first)
}

func firstStringOrDash(values: Array<String>): String {
    if (values.size == 0) {
        return "-"
    }
    values[0]
}

func adaptRiskLevel(
    contractRisk: String,
    scheme: String,
    x509Verify: ?security.X509VerifyOption,
    cryptoProviderId: String
): String {
    if (scheme == "https" || isX509Enabled(x509Verify) || cryptoProviderId != "-") {
        if (contractRisk == "high") {
            return "high"
        }
        return "medium"
    }
    contractRisk
}

func buildObserveTags(
    scheme: String,
    x509Verify: ?security.X509VerifyOption,
    cryptoProviderId: String
): String {
    var tags = "scene=client,scheme=${scheme}"
    if (cryptoProviderId != "-") {
        tags += ",cryptoProvider=${cryptoProviderId}"
    }
    if (isX509Enabled(x509Verify)) {
        tags += ",x509=enabled"
    }
    tags
}

func extractTransportHost(targetUrl: String): String {
    let scheme = detectTransportScheme(targetUrl)
    if (scheme == "unknown") {
        return ""
    }
    let start = if (scheme == "https") { 8 } else { 7 }
    let runes = targetUrl.toRuneArray()
    if (runes.size <= start) {
        return ""
    }
    var authority = ""
    var index = start
    while (index < runes.size) {
        let ch = runes[index]
        if (ch == r'/' || ch == r'?' || ch == r'#') {
            break
        }
        authority += ch.toString()
        index += 1
    }
    if (authority.size == 0) {
        return ""
    }
    let authorityRunes = authority.toRuneArray()
    if (authorityRunes[0] == r'[') {
        return authority
    }
    let parts = authority.split(":")
    if (parts.size == 0) {
        return authority
    }
    parts[0].trimAscii()
}

func mapEnvelopeToTransportFallbackFamily(envelope: TransportErrorEnvelope): String {
    if (envelope.causeCode == "provider_unavailable") {
        return "PROVIDER_UNAVAILABLE"
    }
    if (envelope.causeCode == "tls_handshake_error") {
        return "TLS_HANDSHAKE_ERROR"
    }
    if (envelope.causeCode == "tls_verify_error") {
        return "TLS_VERIFY_ERROR"
    }
    if (envelope.causeCode == "tls_not_configured") {
        return "UNSUPPORTED"
    }
    ""
}

func adaptContractFallbackRecord(
    selection: TransportSelectionDecision,
    contractRecord: api2.FallbackDecisionRecord
): ?TransportFallbackDecisionRecord {
    let fromBackend = normalizeFallbackBackendValue(contractRecord.fromBackend)
    let toBackend = normalizeFallbackBackendValue(contractRecord.toBackend)

    if (contractRecord.finalOutcome == "NO_AUTO_FALLBACK") {
        return Some(
            TransportFallbackDecisionRecord(
                fromBackend,
                toBackend,
                contractRecord.triggerFamily,
                contractRecord.triggerPhase,
                contractRecord.safeToRetry,
                contractRecord.requestReplayRequired,
                "public-error",
                "no-auto-fallback"
            )
        )
    }

    if (toBackend == "-" && contractRecord.triggerFamily == "PROVIDER_UNAVAILABLE") {
        return Some(
            TransportFallbackDecisionRecord(
                if (selection.providerId == "-") {
                    fromBackend
                } else {
                    fromBackend + "@" + selection.providerId
                },
                "-",
                contractRecord.triggerFamily,
                contractRecord.triggerPhase,
                contractRecord.safeToRetry,
                contractRecord.requestReplayRequired,
                "internal-only",
                "no-fallback"
            )
        )
    }

    if (toBackend == "-") {
        return None
    }

    return Some(
        TransportFallbackDecisionRecord(
            if (selection.providerId == "-") {
                fromBackend
            } else {
                fromBackend + "@" + selection.providerId
            },
            toBackend,
            contractRecord.triggerFamily,
            contractRecord.triggerPhase,
            contractRecord.safeToRetry,
            contractRecord.requestReplayRequired,
            "internal-only",
            "suggested-only"
        )
    )
}

func normalizeFallbackBackendValue(raw: String): String {
    if (raw.size == 0) {
        return "-"
    }
    return normalizeBackendId(raw)
}
