package ignite.client

import ignite.api2 as api2
import ignite.security as security

class TransportErrorEnvelope {
    let family: String
    let phase: String
    let backendId: String
    let providerId: String
    let retryable: Bool
    let connectionConsumed: Bool
    let fallbackSuggested: Bool
    let causeCode: String
    let message: String

    init(
        family: String,
        phase: String,
        backendId: String,
        providerId: String,
        retryable: Bool,
        connectionConsumed: Bool,
        fallbackSuggested: Bool,
        causeCode: String,
        message: String
    ) {
        this.family = family
        this.phase = phase
        this.backendId = backendId
        this.providerId = providerId
        this.retryable = retryable
        this.connectionConsumed = connectionConsumed
        this.fallbackSuggested = fallbackSuggested
        this.causeCode = causeCode
        this.message = message
    }
}

func buildTransportErrorEnvelope(
    origin: api2.ClientCryptoException,
    phaseHint: String,
    canRetryMethod: Bool,
    selectionDecision!: ?TransportSelectionDecision = None
): TransportErrorEnvelope {
    let phase = if (phaseHint.size > 0) { phaseHint } else { "request_prepare" }
    let causeCode = mapClientCryptoErrorCauseCode(origin.code)
    let fallbackSuggested = (causeCode == "crypto_unavailable")
    let retryable = classifyTransportRetryable("CRYPTO", phase, causeCode, canRetryMethod, false)
    let backendId = if (let Some(selection) <- selectionDecision) {
        selection.selectedBackend
    } else {
        "stdx-http-client"
    }
    let providerId = if (let Some(selection) <- selectionDecision) {
        selection.providerId
    } else {
        "-"
    }
    TransportErrorEnvelope(
        "CRYPTO",
        phase,
        backendId,
        providerId,
        retryable,
        false,
        fallbackSuggested,
        causeCode,
        origin.message
    )
}

func buildTransportErrorEnvelope(
    origin: security.SecurityException,
    phaseHint: String,
    canRetryMethod: Bool,
    selectionDecision!: ?TransportSelectionDecision = None
): TransportErrorEnvelope {
    let family = mapSecurityErrorFamily(origin.code)
    let phase = mapSecurityErrorPhase(origin.code, phaseHint)
    let causeCode = mapSecurityErrorCauseCode(origin.code)
    let retryable = classifyTransportRetryable(family, phase, causeCode, canRetryMethod, false)
    let backendId = if (let Some(selection) <- selectionDecision) {
        selection.selectedBackend
    } else {
        "stdx-http-client"
    }
    let providerId = if (let Some(selection) <- selectionDecision) {
        selection.providerId
    } else {
        "-"
    }
    TransportErrorEnvelope(
        family,
        phase,
        backendId,
        providerId,
        retryable,
        false,
        false,
        causeCode,
        origin.message
    )
}

func buildTransportErrorEnvelope(
    origin: Exception,
    phaseHint: String,
    canRetryMethod: Bool,
    selectionDecision!: ?TransportSelectionDecision = None
): TransportErrorEnvelope {
    let family = classifyTransportErrorFamily(origin)
    let phase = classifyTransportErrorPhase(origin, phaseHint)
    let causeCode = classifyTransportErrorCauseCode(origin, family, phase)
    let connectionConsumed = classifyTransportConnectionConsumed(family, phase)
    let fallbackSuggested = classifyTransportFallbackSuggested(origin, family, phase, causeCode)
    let retryable = classifyTransportRetryable(family, phase, causeCode, canRetryMethod, connectionConsumed)
    let backendId = if (let Some(selection) <- selectionDecision) {
        selection.selectedBackend
    } else {
        "stdx-http-client"
    }
    let providerId = if (let Some(selection) <- selectionDecision) {
        selection.providerId
    } else {
        "-"
    }
    TransportErrorEnvelope(
        family,
        phase,
        backendId,
        providerId,
        retryable,
        connectionConsumed,
        fallbackSuggested,
        causeCode,
        origin.message
    )
}

func mapClientCryptoErrorCauseCode(code: api2.ClientCryptoErrorCode): String {
    match (code) {
        case api2.ClientCryptoErrorCode.CryptoUnavailable => "crypto_unavailable"
        case api2.ClientCryptoErrorCode.DecryptFailed => "decrypt_failed"
        case api2.ClientCryptoErrorCode.KeyNotFound => "key_not_found"
        case api2.ClientCryptoErrorCode.BadEnvelope => "bad_envelope"
    }
}

func mapSecurityErrorFamily(code: security.SecurityErrorCode): String {
    match (code) {
        case security.SecurityErrorCode.VerifyFailed => "TLS"
        case security.SecurityErrorCode.CryptoUnavailable => "CRYPTO"
        case _ => "SECURITY"
    }
}

func mapSecurityErrorPhase(code: security.SecurityErrorCode, phaseHint: String): String {
    if (phaseHint.size > 0) {
        return phaseHint
    }
    match (code) {
        case security.SecurityErrorCode.VerifyFailed => "verify"
        case _ => "security"
    }
}

func mapSecurityErrorCauseCode(code: security.SecurityErrorCode): String {
    match (code) {
        case security.SecurityErrorCode.VerifyFailed => "tls_verify_error"
        case security.SecurityErrorCode.CryptoUnavailable => "crypto_unavailable"
        case security.SecurityErrorCode.DecryptFailed => "decrypt_failed"
        case security.SecurityErrorCode.KeyNotFound => "key_not_found"
        case security.SecurityErrorCode.BadEnvelope => "bad_envelope"
    }
}

func formatTransportObservedError(
    envelope: TransportErrorEnvelope,
    durationMs: Int64,
    retryCount: Int64,
    fields: String,
    selectionDecision!: ?TransportSelectionDecision = None,
    fallbackRecord!: ?TransportFallbackDecisionRecord = None
): String {
    buildClientObserveSnapshot(
        envelope,
        durationMs,
        retryCount,
        fields,
        selectionDecision: selectionDecision,
        fallbackRecord: fallbackRecord
    ).toLogLine()
}

func buildSuccessfulObserveSnapshot(
    status: UInt16,
    durationMs: Int64,
    retryCount: Int64,
    fields: String,
    selectionDecision: TransportSelectionDecision
): ClientObserveSnapshot {
    ClientObserveSnapshot(
        "success",
        "NONE",
        "response",
        "-",
        selectionDecision.selectedBackend,
        selectionDecision.providerId,
        selectionDecision.cryptoProviderId,
        selectionDecision.publicPath,
        selectionDecision.riskLevel,
        selectionDecision.observabilityTags,
        false,
        false,
        false,
        retryCount,
        durationMs,
        if (fields.size == 0) { "-" } else { fields },
        status,
        "-",
        "-",
        "-",
        false,
        ""
    )
}

func buildClientObserveSnapshot(
    envelope: TransportErrorEnvelope,
    durationMs: Int64,
    retryCount: Int64,
    fields: String,
    selectionDecision!: ?TransportSelectionDecision = None,
    fallbackRecord!: ?TransportFallbackDecisionRecord = None
): ClientObserveSnapshot {
    let fieldText = if (fields.size == 0) { "-" } else { fields }
    let publicPath = if (let Some(selection) <- selectionDecision) {
        selection.publicPath
    } else {
        "-"
    }
    let riskLevel = if (let Some(selection) <- selectionDecision) {
        selection.riskLevel
    } else {
        "-"
    }
    let tags = if (let Some(selection) <- selectionDecision) {
        selection.observabilityTags
    } else {
        "-"
    }
    let cryptoProviderId = if (let Some(selection) <- selectionDecision) {
        selection.cryptoProviderId
    } else {
        "-"
    }
    let fallbackFrom = if (let Some(record) <- fallbackRecord) {
        record.fromBackend
    } else {
        "-"
    }
    let fallbackTo = if (let Some(record) <- fallbackRecord) {
        record.toBackend
    } else {
        "-"
    }
    let fallbackOutcome = if (let Some(record) <- fallbackRecord) {
        record.finalOutcome
    } else {
        "-"
    }
    let replayRequired = if (let Some(record) <- fallbackRecord) {
        record.requestReplayRequired
    } else {
        false
    }
    ClientObserveSnapshot(
        "error",
        envelope.family,
        envelope.phase,
        envelope.causeCode,
        envelope.backendId,
        envelope.providerId,
        cryptoProviderId,
        publicPath,
        riskLevel,
        tags,
        envelope.retryable,
        envelope.fallbackSuggested,
        envelope.connectionConsumed,
        retryCount,
        durationMs,
        fieldText,
        UInt16(0),
        fallbackFrom,
        fallbackTo,
        fallbackOutcome,
        replayRequired,
        envelope.message
    )
}


func classifyTransportErrorFamily(origin: Exception): String {
    let msg = origin.message.toAsciiLower()
    let hasCrypto = containsTransportStr(msg, "crypto")
    let hasDecrypt = containsTransportStr(msg, "decrypt")
    let hasEnvelope = containsTransportStr(msg, "envelope")
    if (hasCrypto || hasDecrypt || hasEnvelope) {
        return "CRYPTO"
    }
    if (containsTransportTimeoutHint(msg)) {
        return "TIMEOUT"
    }
    let hasTls = containsTransportStr(msg, "tls")
    let hasSsl = containsTransportStr(msg, "ssl")
    let hasHandshake = containsTransportStr(msg, "handshake")
    let hasX509 = containsTransportStr(msg, "x509")
    let hasCertificate = containsTransportStr(msg, "certificate")
    if (hasTls || hasSsl || hasHandshake || hasX509 || hasCertificate) {
        return "TLS"
    }
    let hasConnection = containsTransportStr(msg, "connection")
    let hasNetwork = containsTransportStr(msg, "network")
    let hasRefused = containsTransportStr(msg, "refused")
    let hasSocket = containsTransportStr(msg, "socket")
    if (hasConnection || hasNetwork || hasRefused || hasSocket) {
        return "NETWORK"
    }
    "UNKNOWN"
}

func classifyTransportErrorPhase(origin: Exception, phaseHint: String): String {
    if (phaseHint.size > 0) {
        return phaseHint
    }
    let msg = origin.message.toAsciiLower()
    if (containsTransportStr(msg, "tls must be configured") || containsTransportStr(msg, "https requests are sent")) {
        return "handshake"
    }
    if (containsTransportStr(msg, "handshake") || containsTransportStr(msg, "ssl")) {
        return "handshake"
    }
    if (containsTransportStr(msg, "certificate") || containsTransportStr(msg, "x509")) {
        return "verify"
    }
    if (containsTransportStr(msg, "read") && containsTransportTimeoutHint(msg)) {
        return "read"
    }
    if (containsTransportStr(msg, "write") && containsTransportTimeoutHint(msg)) {
        return "write"
    }
    if (
        containsTransportStr(msg, "connect") ||
        containsTransportStr(msg, "refused") ||
        containsTransportStr(msg, "socket") ||
        containsTransportStr(msg, "dial")
    ) {
        return "connect"
    }
    if (containsTransportTimeoutHint(msg)) {
        return "transport"
    }
    "unknown"
}

func classifyTransportErrorCauseCode(origin: Exception, family: String, phase: String): String {
    let msg = origin.message.toAsciiLower()
    if (family == "CRYPTO") {
        if (containsTransportStr(msg, "unavailable")) {
            return "crypto_unavailable"
        }
        if (containsTransportStr(msg, "decrypt")) {
            return "decrypt_failed"
        }
        return "crypto_error"
    }
    if (family == "TLS") {
        if (containsTransportStr(msg, "provider") && containsTransportStr(msg, "unavailable")) {
            return "provider_unavailable"
        }
        if (containsTransportStr(msg, "tls must be configured") || containsTransportStr(msg, "https requests are sent")) {
            return "tls_not_configured"
        }
        if (phase == "handshake") {
            return "tls_handshake_error"
        }
        if (phase == "verify" || containsTransportStr(msg, "certificate") || containsTransportStr(msg, "x509")) {
            return "tls_verify_error"
        }
        return "tls_error"
    }
    if (family == "TIMEOUT") {
        if (phase == "connect") {
            return "connect_timeout"
        }
        if (phase == "read") {
            return "read_timeout"
        }
        if (phase == "write") {
            return "write_timeout"
        }
        return "timeout_error"
    }
    if (family == "NETWORK") {
        if (containsTransportStr(msg, "refused")) {
            return "connection_refused"
        }
        return "connect_error"
    }
    "unknown_error"
}

func classifyTransportConnectionConsumed(family: String, phase: String): Bool {
    if (phase == "read" || phase == "write") {
        return true
    }
    if (family == "TIMEOUT" && phase == "transport") {
        return true
    }
    false
}

func classifyTransportFallbackSuggested(
    origin: Exception,
    family: String,
    phase: String,
    causeCode: String
): Bool {
    let msg = origin.message.toAsciiLower()
    if (causeCode == "crypto_unavailable") {
        return true
    }
    if (family == "TLS" && phase == "handshake" && causeCode == "tls_handshake_error") {
        return true
    }
    if (family == "TLS" && phase != "verify" && containsTransportStr(msg, "provider") && containsTransportStr(msg, "unavailable")) {
        return true
    }
    false
}

func classifyTransportRetryable(
    family: String,
    phase: String,
    causeCode: String,
    canRetryMethod: Bool,
    connectionConsumed: Bool
): Bool {
    if (!canRetryMethod) {
        return false
    }
    if (family == "NETWORK" && !connectionConsumed) {
        return true
    }
    if (family == "TLS" && phase == "handshake" && causeCode == "tls_handshake_error" && !connectionConsumed) {
        return true
    }
    if (family == "TIMEOUT" && phase == "connect") {
        return true
    }
    false
}

func containsTransportStr(hay: String, needle: String): Bool {
    let h = hay.toRuneArray()
    let n = needle.toRuneArray()
    if (n.size == 0) { return true }
    if (h.size < n.size) { return false }
    for (i in 0..=(h.size - n.size)) {
        var ok = true
        for (j in 0..n.size) {
            if (h[i + j] != n[j]) { ok = false; break }
        }
        if (ok) { return true }
    }
    false
}

func containsTransportTimeoutHint(msg: String): Bool {
    containsTransportStr(msg, "timeout") || containsTransportStr(msg, "timed out")
}
