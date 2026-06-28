package ignite.api2

import std.collection.ArrayList

/// Temporary Ignite-owned home for the currently consumed transport policy surface.
/// This keeps Ignite off the direct `lisi` sibling dependency while preserving the
/// same selection/fallback semantics until a later extraction packet is opened.

public struct BackendCapabilityRecord {
    public let backendId: String
    public let backendFamily: String
    public let platformScope: String
    public let cjScope: String
    public let supportsTls: Bool
    public let supportsX509Verify: Bool
    public let supportsStreaming: Bool
    public let supportsMultipart: Bool
    public let supportsConnectionReuse: Bool
    public let experimental: Bool
    public let defaultEligible: Bool
    public let unsupportedReasons: Array<String>
    public let notes: Array<String>

    public init(
        backendId: String,
        backendFamily: String,
        platformScope: String,
        cjScope: String,
        supportsTls: Bool,
        supportsX509Verify: Bool,
        supportsStreaming: Bool,
        supportsMultipart: Bool,
        supportsConnectionReuse: Bool,
        experimental: Bool,
        defaultEligible: Bool,
        unsupportedReasons: Array<String>,
        notes: Array<String>
    ) {
        this.backendId = backendId
        this.backendFamily = backendFamily
        this.platformScope = platformScope
        this.cjScope = cjScope
        this.supportsTls = supportsTls
        this.supportsX509Verify = supportsX509Verify
        this.supportsStreaming = supportsStreaming
        this.supportsMultipart = supportsMultipart
        this.supportsConnectionReuse = supportsConnectionReuse
        this.experimental = experimental
        this.defaultEligible = defaultEligible
        this.unsupportedReasons = unsupportedReasons
        this.notes = notes
    }
}

public struct BackendSelectionRequest {
    public let scene: String
    public let scheme: String
    public let requiresStreaming: Bool
    public let requiresMultipart: Bool
    public let requiresX509Verify: Bool
    public let preferredBackendHint: String
    public let allowExperimental: Bool
    public let retryAttempt: Int64
    public let runtimeHint: String

    public init(
        scene: String,
        scheme: String,
        requiresStreaming: Bool,
        requiresMultipart: Bool,
        requiresX509Verify: Bool,
        preferredBackendHint: String,
        allowExperimental: Bool,
        retryAttempt: Int64,
        runtimeHint: String
    ) {
        this.scene = scene
        this.scheme = scheme
        this.requiresStreaming = requiresStreaming
        this.requiresMultipart = requiresMultipart
        this.requiresX509Verify = requiresX509Verify
        this.preferredBackendHint = preferredBackendHint
        this.allowExperimental = allowExperimental
        this.retryAttempt = retryAttempt
        this.runtimeHint = runtimeHint
    }
}

public struct BackendSelectionDecision {
    public let candidateOrder: Array<String>
    public let selectedBackend: String
    public let selectedReason: String
    public let fallbackChain: Array<String>
    public let blockedCandidates: Array<String>
    public let riskLevel: String
    public let publicPath: String
    public let observabilityTags: Array<String>

    public init(
        candidateOrder: Array<String>,
        selectedBackend: String,
        selectedReason: String,
        fallbackChain: Array<String>,
        blockedCandidates: Array<String>,
        riskLevel: String,
        publicPath: String,
        observabilityTags: Array<String>
    ) {
        this.candidateOrder = candidateOrder
        this.selectedBackend = selectedBackend
        this.selectedReason = selectedReason
        this.fallbackChain = fallbackChain
        this.blockedCandidates = blockedCandidates
        this.riskLevel = riskLevel
        this.publicPath = publicPath
        this.observabilityTags = observabilityTags
    }
}

public struct TlsAttachPlan {
    public let tlsEnabled: Bool
    public let providerId: String
    public let verifyMode: String
    public let sniHost: String
    public let x509Profile: String
    public let handshakeTimeoutMs: Int64
    public let canFallback: Bool
    public let fallbackReason: String

    public init(
        tlsEnabled: Bool,
        providerId: String,
        verifyMode: String,
        sniHost: String,
        x509Profile: String,
        handshakeTimeoutMs: Int64,
        canFallback: Bool,
        fallbackReason: String
    ) {
        this.tlsEnabled = tlsEnabled
        this.providerId = providerId
        this.verifyMode = verifyMode
        this.sniHost = sniHost
        this.x509Profile = x509Profile
        this.handshakeTimeoutMs = handshakeTimeoutMs
        this.canFallback = canFallback
        this.fallbackReason = fallbackReason
    }
}

public struct FallbackDecisionRecord {
    public let fromBackend: String
    public let toBackend: String
    public let triggerFamily: String
    public let triggerPhase: String
    public let safeToRetry: Bool
    public let requestReplayRequired: Bool
    public let visibility: String
    public let finalOutcome: String

    public init(
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

public func builtInBackendCapabilities(): Array<BackendCapabilityRecord> {
    [
        stableDefaultBackendCapability(),
        jinguisslProviderCandidateCapability(),
    ]
}

public func selectBackend(request: BackendSelectionRequest): BackendSelectionDecision {
    selectBackend(request, builtInBackendCapabilities())
}

public func selectBackend(
    request: BackendSelectionRequest,
    capabilities: Array<BackendCapabilityRecord>
): BackendSelectionDecision {
    let ordered = orderCapabilities(capabilities, request.preferredBackendHint)
    let candidateOrder = extractBackendIds(ordered)

    var blocked = ArrayList<String>()
    for (capability in ordered) {
        if (let Some(reason) <- unsupportedReason(capability, request)) {
            blocked.add("${capability.backendId}:${reason}")
            continue
        }

        let selectedReason = resolveSelectedReason(capability, request, blocked.toArray())
        let fallbackChain = fallbackChainFor(capability, ordered)
        let publicPath = publicPathFor(capability)
        let riskLevel = riskLevelFor(capability)
        let observabilityTags = buildObservabilityTags(request, capability.backendId, publicPath, riskLevel)
        return BackendSelectionDecision(
            candidateOrder,
            capability.backendId,
            selectedReason,
            fallbackChain,
            blocked.toArray(),
            riskLevel,
            publicPath,
            observabilityTags
        )
    }

    BackendSelectionDecision(
        candidateOrder,
        "",
        "unsupported_request",
        [],
        blocked.toArray(),
        "high",
        "unsupported",
        buildUnsupportedTags(request)
    )
}

public func buildTlsAttachPlan(
    request: BackendSelectionRequest,
    decision: BackendSelectionDecision
): TlsAttachPlan {
    buildTlsAttachPlan(request, decision, readSniHost(request))
}

public func buildTlsAttachPlan(
    request: BackendSelectionRequest,
    decision: BackendSelectionDecision,
    sniHost: String
): TlsAttachPlan {
    let tlsEnabled = isHttpsScheme(request.scheme)
    let providerId = providerIdFor(decision.selectedBackend)
    let verifyMode = if (request.requiresX509Verify) { "STRICT" } else { "BEST_EFFORT" }
    let x509Profile = if (request.requiresX509Verify) { "STRICT_X509" } else { "OPTIONAL_X509" }
    let handshakeTimeoutMs = if (normalizeScene(request.scene) == "server") { 15000 } else { 10000 }
    let fallbackReason = tlsFallbackReason(request, providerId, tlsEnabled)
    TlsAttachPlan(
        tlsEnabled,
        providerId,
        verifyMode,
        sniHost,
        x509Profile,
        handshakeTimeoutMs,
        fallbackReason.size > 0,
        fallbackReason
    )
}

public func decideFallback(
    fromBackend: String,
    triggerFamily: String,
    triggerPhase: String
): FallbackDecisionRecord {
    decideFallback(fromBackend, triggerFamily, triggerPhase, false)
}

public func decideFallback(
    fromBackend: String,
    triggerFamily: String,
    triggerPhase: String,
    connectionConsumed: Bool
): FallbackDecisionRecord {
    let family = normalizeTriggerFamily(triggerFamily)
    let defaultBackend = stableDefaultBackendId()
    let fallbackBackend = if (fromBackend != defaultBackend && canRecommendFallbackBackend(family)) {
        defaultBackend
    } else {
        ""
    }

    if (family == "PROVIDER_UNAVAILABLE" || family == "CRYPTO_UNAVAILABLE" || family == "UNSUPPORTED") {
        return FallbackDecisionRecord(
            fromBackend,
            fallbackBackend,
            family,
            triggerPhase,
            !connectionConsumed,
            connectionConsumed,
            "operator-visible",
            if (fallbackBackend.size > 0) { "FALLBACK_TO_STABLE_DEFAULT" } else { "NO_ALTERNATIVE_BACKEND" }
        )
    }

    if (family == "TLS_HANDSHAKE_ERROR") {
        return FallbackDecisionRecord(
            fromBackend,
            fallbackBackend,
            family,
            triggerPhase,
            !connectionConsumed,
            connectionConsumed,
            "operator-visible",
            if (connectionConsumed) {
                "MANUAL_RETRY_REQUIRED"
            } else if (fallbackBackend.size > 0) {
                "RETRYABLE_FALLBACK_CANDIDATE"
            } else {
                "RETRYABLE_NO_FALLBACK"
            }
        )
    }

    if (
        family == "TLS_VERIFY_ERROR" ||
        family == "TLS_PRECHECK_ERROR" ||
        family == "PRECHECK_REJECTED" ||
        family == "BAD_INPUT" ||
        family == "COMPLIANCE_REJECTED"
    ) {
        return FallbackDecisionRecord(
            fromBackend,
            "",
            family,
            triggerPhase,
            false,
            false,
            "public-error",
            "NO_AUTO_FALLBACK"
        )
    }

    FallbackDecisionRecord(
        fromBackend,
        "",
        family,
        triggerPhase,
        false,
        connectionConsumed,
        "observe-only",
        "NO_DECISION"
    )
}

func stableDefaultBackendCapability(): BackendCapabilityRecord {
    BackendCapabilityRecord(
        stableDefaultBackendId(),
        "stdx",
        "cross-platform",
        "cj>=1.0.0",
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        [],
        ["CURRENT_STABLE_DEFAULT_PATH"]
    )
}

func jinguisslProviderCandidateCapability(): BackendCapabilityRecord {
    BackendCapabilityRecord(
        "jinguissl-provider-candidate",
        "jinguissl",
        "provider-candidate",
        "cj>=1.0.0",
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        ["SERVER_ATTACH_PRECHECK_ONLY"],
        ["PROVIDER_CANDIDATE", "NOT_DEFAULT_HTTPS_LISTENER", "RETURN_TO_STABLE_DEFAULT_PATH"]
    )
}

func stableDefaultBackendId(): String {
    "stdx-default"
}

func normalizeScene(raw: String): String {
    raw.trimAscii().toAsciiLower()
}

func isHttpsScheme(raw: String): Bool {
    raw.trimAscii().toAsciiLower() == "https"
}

func normalizeTriggerFamily(raw: String): String {
    raw.trimAscii().toAsciiUpper()
}

func canRecommendFallbackBackend(family: String): Bool {
    family == "PROVIDER_UNAVAILABLE" || family == "CRYPTO_UNAVAILABLE" || family == "UNSUPPORTED" || family == "TLS_HANDSHAKE_ERROR"
}

func orderCapabilities(
    capabilities: Array<BackendCapabilityRecord>,
    preferredBackendHint: String
): Array<BackendCapabilityRecord> {
    var ordered = ArrayList<BackendCapabilityRecord>()
    let trimmedHint = preferredBackendHint.trimAscii()

    if (trimmedHint.size > 0) {
        for (capability in capabilities) {
            if (capability.backendId == trimmedHint) {
                appendCapabilityIfMissing(ordered, capability)
            }
        }
    }

    for (capability in capabilities) {
        if (capability.defaultEligible && !capability.experimental) {
            appendCapabilityIfMissing(ordered, capability)
        }
    }

    for (capability in capabilities) {
        if (!(capability.defaultEligible && !capability.experimental)) {
            appendCapabilityIfMissing(ordered, capability)
        }
    }

    ordered.toArray()
}

func appendCapabilityIfMissing(
    list: ArrayList<BackendCapabilityRecord>,
    capability: BackendCapabilityRecord
): Unit {
    for (existing in list) {
        if (existing.backendId == capability.backendId) {
            return
        }
    }
    list.add(capability)
}

func extractBackendIds(capabilities: Array<BackendCapabilityRecord>): Array<String> {
    var ids = ArrayList<String>()
    for (capability in capabilities) {
        ids.add(capability.backendId)
    }
    ids.toArray()
}

func unsupportedReason(
    capability: BackendCapabilityRecord,
    request: BackendSelectionRequest
): ?String {
    if (normalizeScene(request.scene) == "server" && capability.backendId == "jinguissl-provider-candidate") {
        return Some("SERVER_ATTACH_PRECHECK_ONLY")
    }

    if (!request.allowExperimental && capability.experimental) {
        return Some("EXPERIMENTAL_DISABLED")
    }

    if (isHttpsScheme(request.scheme) && !capability.supportsTls) {
        return Some("TLS_UNSUPPORTED")
    }

    if (request.requiresX509Verify && !capability.supportsX509Verify) {
        return Some("X509_VERIFY_UNSUPPORTED")
    }

    if (request.requiresStreaming && !capability.supportsStreaming) {
        return Some("STREAMING_UNSUPPORTED")
    }

    if (request.requiresMultipart && !capability.supportsMultipart) {
        return Some("MULTIPART_UNSUPPORTED")
    }

    None
}

func resolveSelectedReason(
    capability: BackendCapabilityRecord,
    request: BackendSelectionRequest,
    blockedCandidates: Array<String>
): String {
    if (request.preferredBackendHint.trimAscii() == capability.backendId) {
        return "preferred_backend_hint"
    }

    if (capability.defaultEligible && blockedCandidates.size > 0) {
        return "fallback_to_stable_default"
    }

    if (capability.defaultEligible) {
        return "stable_default_path"
    }

    if (capability.experimental) {
        return "experimental_allowed"
    }

    "first_supported_candidate"
}

func fallbackChainFor(
    selected: BackendCapabilityRecord,
    ordered: Array<BackendCapabilityRecord>
): Array<String> {
    var chain = ArrayList<String>()
    if (selected.experimental) {
        for (capability in ordered) {
            if (capability.defaultEligible && !capability.experimental) {
                chain.add(capability.backendId)
            }
        }
    }
    chain.toArray()
}

func publicPathFor(capability: BackendCapabilityRecord): String {
    if (capability.defaultEligible && !capability.experimental) {
        return "stable-default"
    }
    if (capability.experimental) {
        return "experimental-only"
    }
    "unsupported"
}

func riskLevelFor(capability: BackendCapabilityRecord): String {
    if (capability.defaultEligible && !capability.experimental) {
        return "low"
    }
    if (capability.experimental) {
        return "medium"
    }
    "high"
}

func buildObservabilityTags(
    request: BackendSelectionRequest,
    backendId: String,
    publicPath: String,
    riskLevel: String
): Array<String> {
    [
        "scene:${normalizeScene(request.scene)}",
        "scheme:${request.scheme.trimAscii().toAsciiLower()}",
        "selected_backend:${backendId}",
        "public_path:${publicPath}",
        "risk_level:${riskLevel}",
    ]
}

func buildUnsupportedTags(request: BackendSelectionRequest): Array<String> {
    [
        "scene:${normalizeScene(request.scene)}",
        "scheme:${request.scheme.trimAscii().toAsciiLower()}",
        "public_path:unsupported",
        "risk_level:high",
    ]
}

func providerIdFor(selectedBackend: String): String {
    if (selectedBackend == "jinguissl-provider-candidate") {
        return "jinguissl"
    }
    if (selectedBackend.size > 0) {
        return "stdx"
    }
    ""
}

func readSniHost(request: BackendSelectionRequest): String {
    let hint = request.runtimeHint.trimAscii()
    if (hint.size == 0) {
        return ""
    }
    if (hint.contains("sni=")) {
        let parts = hint.split("sni=")
        if (parts.size > 1) {
            return parts[1].trimAscii()
        }
    }
    hint
}

func tlsFallbackReason(
    request: BackendSelectionRequest,
    providerId: String,
    tlsEnabled: Bool
): String {
    if (!tlsEnabled || providerId.size == 0) {
        return ""
    }

    if (providerId == "jinguissl" && normalizeScene(request.scene) == "server") {
        return "PRECHECK_ONLY:return_to_stable_default"
    }

    if (providerId == "jinguissl") {
        return "PROVIDER_CANDIDATE:return_to_stable_default"
    }

    ""
}
