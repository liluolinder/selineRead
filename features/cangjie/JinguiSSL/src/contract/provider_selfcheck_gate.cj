package jinguissl.contract

import std.collection.ArrayList

public class ContractProviderSmokeSelfCheckPolicy {
    public let requireClientTls: Bool
    public let requireX509Verify: Bool
    public let requireTlsPrecheck: Bool
    public let requireSuccessBaseline: Bool
    public let requirePrecheckCoverage: Bool
    public let requireVerifyCoverage: Bool
    public let requireProviderSelectionCoverage: Bool
    public let requireHandshakeCoverage: Bool
    public let requireFallbackPlan: Bool
    public let requireStableServerAttach: Bool
    public let requireDefaultEligible: Bool
    public let requireLiveHandshakeCoverage: Bool

    public init(
        requireClientTls!: Bool = true,
        requireX509Verify!: Bool = true,
        requireTlsPrecheck!: Bool = true,
        requireSuccessBaseline!: Bool = true,
        requirePrecheckCoverage!: Bool = true,
        requireVerifyCoverage!: Bool = true,
        requireProviderSelectionCoverage!: Bool = true,
        requireHandshakeCoverage!: Bool = true,
        requireFallbackPlan!: Bool = true,
        requireStableServerAttach!: Bool = false,
        requireDefaultEligible!: Bool = false,
        requireLiveHandshakeCoverage!: Bool = false
    ) {
        this.requireClientTls = requireClientTls
        this.requireX509Verify = requireX509Verify
        this.requireTlsPrecheck = requireTlsPrecheck
        this.requireSuccessBaseline = requireSuccessBaseline
        this.requirePrecheckCoverage = requirePrecheckCoverage
        this.requireVerifyCoverage = requireVerifyCoverage
        this.requireProviderSelectionCoverage = requireProviderSelectionCoverage
        this.requireHandshakeCoverage = requireHandshakeCoverage
        this.requireFallbackPlan = requireFallbackPlan
        this.requireStableServerAttach = requireStableServerAttach
        this.requireDefaultEligible = requireDefaultEligible
        this.requireLiveHandshakeCoverage = requireLiveHandshakeCoverage
    }
}

public class ContractProviderSmokeSelfCheckReport {
    public let policy: ContractProviderSmokeSelfCheckPolicy
    public let suite: ContractProviderSmokeSuiteReport
    public let supportsClientTls: Bool
    public let supportsX509Verify: Bool
    public let supportsTlsPrecheck: Bool
    public let hasSuccessBaseline: Bool
    public let hasPrecheckCoverage: Bool
    public let hasVerifyCoverage: Bool
    public let hasProviderSelectionCoverage: Bool
    public let hasHandshakeCoverage: Bool
    public let hasLiveHandshakeCoverage: Bool
    public let hasFallbackPlanCoverage: Bool
    public let stableServerAttach: Bool
    public let defaultEligible: Bool
    public let overallReady: Bool
    public let warnings: Array<String>

    public init(
        policy: ContractProviderSmokeSelfCheckPolicy,
        suite: ContractProviderSmokeSuiteReport,
        supportsClientTls: Bool,
        supportsX509Verify: Bool,
        supportsTlsPrecheck: Bool,
        hasSuccessBaseline: Bool,
        hasPrecheckCoverage: Bool,
        hasVerifyCoverage: Bool,
        hasProviderSelectionCoverage: Bool,
        hasHandshakeCoverage: Bool,
        hasLiveHandshakeCoverage: Bool,
        hasFallbackPlanCoverage: Bool,
        stableServerAttach: Bool,
        defaultEligible: Bool,
        overallReady: Bool,
        warnings: Array<String>
    ) {
        this.policy = policy
        this.suite = suite
        this.supportsClientTls = supportsClientTls
        this.supportsX509Verify = supportsX509Verify
        this.supportsTlsPrecheck = supportsTlsPrecheck
        this.hasSuccessBaseline = hasSuccessBaseline
        this.hasPrecheckCoverage = hasPrecheckCoverage
        this.hasVerifyCoverage = hasVerifyCoverage
        this.hasProviderSelectionCoverage = hasProviderSelectionCoverage
        this.hasHandshakeCoverage = hasHandshakeCoverage
        this.hasLiveHandshakeCoverage = hasLiveHandshakeCoverage
        this.hasFallbackPlanCoverage = hasFallbackPlanCoverage
        this.stableServerAttach = stableServerAttach
        this.defaultEligible = defaultEligible
        this.overallReady = overallReady
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeSelfCheckOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeSelfCheckReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeSelfCheckReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke self-check outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke self-check outcome result must be empty when ok is false"
                    )
                case None => ()
            }
        }
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public enum ContractProviderSmokeProfile <: Equatable<ContractProviderSmokeProfile> & ToString {
    | ProviderCandidate
    | AttachPlanning
    | DefaultHttpsEligible
    | LiveAttachExperimental
    | ProductionStrict

    public operator func ==(right: ContractProviderSmokeProfile): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeProfile): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderCandidate => 0
            case AttachPlanning => 1
            case DefaultHttpsEligible => 2
            case LiveAttachExperimental => 3
            case ProductionStrict => 4
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderCandidate => "PROVIDER_CANDIDATE"
            case AttachPlanning => "ATTACH_PLANNING"
            case DefaultHttpsEligible => "DEFAULT_HTTPS_ELIGIBLE"
            case LiveAttachExperimental => "LIVE_ATTACH_EXPERIMENTAL"
            case ProductionStrict => "PRODUCTION_STRICT"
        }
    }
}

public class ContractProviderSmokeProfileTemplate {
    public let profile: ContractProviderSmokeProfile
    public let label: String
    public let policy: ContractProviderSmokeSelfCheckPolicy
    public let notes: Array<String>

    public init(
        profile: ContractProviderSmokeProfile,
        label: String,
        policy: ContractProviderSmokeSelfCheckPolicy,
        notes: Array<String>
    ) {
        if (label.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke profile label must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke profile notes must not be empty"
            )
        }
        this.profile = profile
        this.label = label.trimAscii()
        this.policy = ContractProviderSmokeSelfCheckPolicy(
            requireClientTls: policy.requireClientTls,
            requireX509Verify: policy.requireX509Verify,
            requireTlsPrecheck: policy.requireTlsPrecheck,
            requireSuccessBaseline: policy.requireSuccessBaseline,
            requirePrecheckCoverage: policy.requirePrecheckCoverage,
            requireVerifyCoverage: policy.requireVerifyCoverage,
            requireProviderSelectionCoverage: policy.requireProviderSelectionCoverage,
            requireHandshakeCoverage: policy.requireHandshakeCoverage,
            requireFallbackPlan: policy.requireFallbackPlan,
            requireStableServerAttach: policy.requireStableServerAttach,
            requireDefaultEligible: policy.requireDefaultEligible,
            requireLiveHandshakeCoverage: policy.requireLiveHandshakeCoverage
        )
        this.notes = notes.clone()
    }
}

public enum ContractProviderConsumptionPath <: Equatable<ContractProviderConsumptionPath> & ToString {
    | HttpClientTls
    | HttpServerAttachPlanning
    | HttpServerStableAttach
    | SshClientLibrary
    | SshServerLibrary

    public operator func ==(right: ContractProviderConsumptionPath): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderConsumptionPath): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case HttpClientTls => 0
            case HttpServerAttachPlanning => 1
            case HttpServerStableAttach => 2
            case SshClientLibrary => 3
            case SshServerLibrary => 4
        }
    }

    public func toString(): String {
        match (this) {
            case HttpClientTls => "HTTP_CLIENT_TLS"
            case HttpServerAttachPlanning => "HTTP_SERVER_ATTACH_PLANNING"
            case HttpServerStableAttach => "HTTP_SERVER_STABLE_ATTACH"
            case SshClientLibrary => "SSH_CLIENT_LIBRARY"
            case SshServerLibrary => "SSH_SERVER_LIBRARY"
        }
    }
}

public class ContractProviderConsumptionPathGuide {
    public let path: ContractProviderConsumptionPath
    public let label: String
    public let consumerKind: String
    public let attemptAllowed: Bool
    public let useProviderSelection: Bool
    public let requiresUpperLayerAttachGlue: Bool
    public let publishedContractPath: Bool
    public let suggestedSmokeProfile: ?ContractProviderSmokeProfile
    public let suggestedFallbackTarget: String
    public let attachPlanMeaning: String
    public let notes: Array<String>

    public init(
        path: ContractProviderConsumptionPath,
        label: String,
        consumerKind: String,
        attemptAllowed: Bool,
        useProviderSelection: Bool,
        requiresUpperLayerAttachGlue: Bool,
        publishedContractPath: Bool,
        attachPlanMeaning: String,
        notes: Array<String>,
        suggestedSmokeProfile!: ?ContractProviderSmokeProfile = None,
        suggestedFallbackTarget!: String = ""
    ) {
        if (
            label.trimAscii().size == 0 ||
            consumerKind.trimAscii().size == 0 ||
            attachPlanMeaning.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption path guide string fields must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption path guide notes must not be empty"
            )
        }
        this.path = path
        this.label = label.trimAscii()
        this.consumerKind = consumerKind.trimAscii()
        this.attemptAllowed = attemptAllowed
        this.useProviderSelection = useProviderSelection
        this.requiresUpperLayerAttachGlue = requiresUpperLayerAttachGlue
        this.publishedContractPath = publishedContractPath
        this.suggestedSmokeProfile = suggestedSmokeProfile
        this.suggestedFallbackTarget = suggestedFallbackTarget.trimAscii()
        this.attachPlanMeaning = attachPlanMeaning.trimAscii()
        this.notes = notes.clone()
    }
}

public enum ContractProviderFallbackCauseCode <: Equatable<ContractProviderFallbackCauseCode> & ToString {
    | ProviderUnavailable
    | TlsHandshakeError
    | TlsVerifyError
    | TlsPrecheckError
    | TlsNotConfigured
    | CryptoUnavailable

    public operator func ==(right: ContractProviderFallbackCauseCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderFallbackCauseCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderUnavailable => 0
            case TlsHandshakeError => 1
            case TlsVerifyError => 2
            case TlsPrecheckError => 3
            case TlsNotConfigured => 4
            case CryptoUnavailable => 5
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderUnavailable => "provider_unavailable"
            case TlsHandshakeError => "tls_handshake_error"
            case TlsVerifyError => "tls_verify_error"
            case TlsPrecheckError => "tls_precheck_error"
            case TlsNotConfigured => "tls_not_configured"
            case CryptoUnavailable => "crypto_unavailable"
        }
    }
}

public enum ContractProviderFallbackOutcome <: Equatable<ContractProviderFallbackOutcome> & ToString {
    | SuggestedOnly
    | NoAutoFallback
    | NoFallback
    | ManualReview

    public operator func ==(right: ContractProviderFallbackOutcome): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderFallbackOutcome): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case SuggestedOnly => 0
            case NoAutoFallback => 1
            case NoFallback => 2
            case ManualReview => 3
        }
    }

    public func toString(): String {
        match (this) {
            case SuggestedOnly => "SUGGESTED_ONLY"
            case NoAutoFallback => "NO_AUTO_FALLBACK"
            case NoFallback => "NO_FALLBACK"
            case ManualReview => "MANUAL_REVIEW"
        }
    }
}

public class ContractProviderFallbackOutcomeGuide {
    public let causeCode: ContractProviderFallbackCauseCode
    public let wireName: String
    public let family: ContractProviderErrorFamily
    public let phase: ContractProviderErrorPhase
    public let defaultOutcome: ContractProviderFallbackOutcome
    public let consumedConnectionOutcome: ContractProviderFallbackOutcome
    public let stableDefaultOutcome: ContractProviderFallbackOutcome
    public let suggestedFallbackTarget: String
    public let mustSurface: Bool
    public let notes: Array<String>

    public init(
        causeCode: ContractProviderFallbackCauseCode,
        wireName: String,
        family: ContractProviderErrorFamily,
        phase: ContractProviderErrorPhase,
        defaultOutcome: ContractProviderFallbackOutcome,
        consumedConnectionOutcome: ContractProviderFallbackOutcome,
        stableDefaultOutcome: ContractProviderFallbackOutcome,
        mustSurface: Bool,
        notes: Array<String>,
        suggestedFallbackTarget!: String = ""
    ) {
        if (wireName.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback outcome guide wireName must not be empty"
            )
        }
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback outcome guide notes must not be empty"
            )
        }
        this.causeCode = causeCode
        this.wireName = wireName.trimAscii()
        this.family = family
        this.phase = phase
        this.defaultOutcome = defaultOutcome
        this.consumedConnectionOutcome = consumedConnectionOutcome
        this.stableDefaultOutcome = stableDefaultOutcome
        this.suggestedFallbackTarget = suggestedFallbackTarget.trimAscii()
        this.mustSurface = mustSurface
        this.notes = notes.clone()
    }
}

public class ContractProviderFallbackResolutionRequest {
    public let causeCode: ContractProviderFallbackCauseCode
    public let connectionConsumed: Bool
    public let alreadyOnStableDefault: Bool

    public init(
        causeCode: ContractProviderFallbackCauseCode,
        connectionConsumed!: Bool = false,
        alreadyOnStableDefault!: Bool = false
    ) {
        this.causeCode = causeCode
        this.connectionConsumed = connectionConsumed
        this.alreadyOnStableDefault = alreadyOnStableDefault
    }
}

public class ContractProviderFallbackResolution {
    public let guide: ContractProviderFallbackOutcomeGuide
    public let finalOutcome: ContractProviderFallbackOutcome
    public let fallbackTarget: String
    public let shouldRecord: Bool
    public let mustSurface: Bool
    public let notes: Array<String>

    public init(
        guide: ContractProviderFallbackOutcomeGuide,
        finalOutcome: ContractProviderFallbackOutcome,
        notes: Array<String>,
        fallbackTarget!: String = "",
        shouldRecord!: Bool = true,
        mustSurface!: Bool = false
    ) {
        if (notes.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider fallback resolution notes must not be empty"
            )
        }
        this.guide = guide
        this.finalOutcome = finalOutcome
        this.fallbackTarget = fallbackTarget.trimAscii()
        this.shouldRecord = shouldRecord
        this.mustSurface = mustSurface
        this.notes = notes.clone()
    }
}

public enum ContractProviderConsumptionGateStatus <: Equatable<ContractProviderConsumptionGateStatus> & ToString {
    | ProviderCandidate
    | PlanningOnly
    | LibraryContract
    | Blocked

    public operator func ==(right: ContractProviderConsumptionGateStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderConsumptionGateStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProviderCandidate => 0
            case PlanningOnly => 1
            case LibraryContract => 2
            case Blocked => 3
        }
    }

    public func toString(): String {
        match (this) {
            case ProviderCandidate => "PROVIDER_CANDIDATE"
            case PlanningOnly => "PLANNING_ONLY"
            case LibraryContract => "LIBRARY_CONTRACT"
            case Blocked => "BLOCKED"
        }
    }
}

public class ContractProviderConsumptionGateReport {
    public let path: ContractProviderConsumptionPath
    public let guide: ContractProviderConsumptionPathGuide
    public let status: ContractProviderConsumptionGateStatus
    public let providerId: String
    public let selectedEntryId: String
    public let candidateOrder: Array<String>
    public let blockedCandidates: Array<String>
    public let publicPath: String
    public let releasePath: String
    public let riskLevel: String
    public let observabilityTags: Array<String>
    public let capability: ContractProviderCapabilityRecord
    public let attachBoundary: ContractProviderServerAttachBoundary
    public let smokeProfile: ?ContractProviderSmokeProfileTemplate
    public let smokeReadiness: ?ContractProviderSmokeSelfCheckReport
    public let readyNow: Bool
    public let fallbackTarget: String
    public let fallbackChain: Array<String>
    public let selectedReason: String
    public let warnings: Array<String>

    public init(
        path: ContractProviderConsumptionPath,
        guide: ContractProviderConsumptionPathGuide,
        status: ContractProviderConsumptionGateStatus,
        providerId: String,
        selectedEntryId: String,
        candidateOrder: Array<String>,
        blockedCandidates: Array<String>,
        publicPath: String,
        releasePath: String,
        riskLevel: String,
        observabilityTags: Array<String>,
        capability: ContractProviderCapabilityRecord,
        attachBoundary: ContractProviderServerAttachBoundary,
        readyNow: Bool,
        selectedReason: String,
        warnings: Array<String>,
        smokeProfile!: ?ContractProviderSmokeProfileTemplate = None,
        smokeReadiness!: ?ContractProviderSmokeSelfCheckReport = None,
        fallbackTarget!: String = "",
        fallbackChain!: Array<String> = []
    ) {
        if (path != guide.path) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report path must match guide.path"
            )
        }
        if (
            providerId.trimAscii().size == 0 ||
            publicPath.trimAscii().size == 0 ||
            releasePath.trimAscii().size == 0 ||
            riskLevel.trimAscii().size == 0 ||
            selectedReason.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report string fields must not be empty"
            )
        }
        if (candidateOrder.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report candidateOrder must not be empty"
            )
        }
        if (observabilityTags.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report observabilityTags must not be empty"
            )
        }
        let trimmedSelectedEntryId = selectedEntryId.trimAscii()
        if (readyNow) {
            if (trimmedSelectedEntryId.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report selectedEntryId must exist when readyNow is true"
                )
            }
            if (blockedCandidates.size > 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report blockedCandidates must be empty when readyNow is true"
                )
            }
        } else {
            if (trimmedSelectedEntryId.size > 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report selectedEntryId must be empty when readyNow is false"
                )
            }
            if (blockedCandidates.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider consumption gate report blockedCandidates must exist when readyNow is false"
                )
            }
        }
        if (warnings.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report warnings must not be empty"
            )
        }
        if (fallbackTarget.trimAscii().size == 0 && fallbackChain.size > 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate report fallbackChain must be empty when fallbackTarget is empty"
            )
        }
        match (smokeProfile) {
            case Some(_) =>
                match (smokeReadiness) {
                    case Some(_) => ()
                    case None =>
                        throw ContractException(
                            ContractErrorCode.BadInput,
                            "provider consumption gate report smokeReadiness must exist when smokeProfile is present"
                        )
                }
            case None =>
                match (smokeReadiness) {
                    case Some(_) =>
                        throw ContractException(
                            ContractErrorCode.BadInput,
                            "provider consumption gate report smokeReadiness must be empty when smokeProfile is absent"
                        )
                    case None => ()
                }
        }
        this.path = path
        this.guide = guide
        this.status = status
        this.providerId = providerId.trimAscii()
        this.selectedEntryId = trimmedSelectedEntryId
        this.candidateOrder = candidateOrder.clone()
        this.blockedCandidates = blockedCandidates.clone()
        this.publicPath = publicPath.trimAscii()
        this.releasePath = releasePath.trimAscii()
        this.riskLevel = riskLevel.trimAscii()
        this.observabilityTags = observabilityTags.clone()
        this.capability = capability
        this.attachBoundary = attachBoundary
        this.smokeProfile = smokeProfile
        this.smokeReadiness = smokeReadiness
        this.readyNow = readyNow
        this.fallbackTarget = fallbackTarget.trimAscii()
        this.fallbackChain = fallbackChain.clone()
        this.selectedReason = selectedReason.trimAscii()
        this.warnings = warnings.clone()
    }
}

public class ContractProviderConsumptionGateOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderConsumptionGateReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderConsumptionGateReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider consumption gate outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider consumption gate outcome result must be empty when ok is false"
                    )
                case None => ()
            }
        }
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public func contractProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckReport {
    let suite = contractDescribeProviderSmokeSuite()
    let capability = suite.capability
    let attach = contractProviderAttachContractInfo()
    let hasSuccessBaseline = suite.successFixtureCount > 0
    let hasPrecheckCoverage = suite.precheckPathCount > 0
    let hasVerifyCoverage = suite.verifyPathCount > 0
    let hasProviderSelectionCoverage = suite.providerSelectionPathCount > 0
    let hasHandshakeCoverage = suite.metadataOnlyCount > 0
    let hasLiveHandshakeCoverage = false
    var hasFallbackPlanCoverage = true
    for (baseline in suite.baselines) {
        if (!baseline.expectedSuccess) {
            match (baseline.expectedFallback) {
                case Some(_) => ()
                case None =>
                    hasFallbackPlanCoverage = false
            }
        }
    }
    let warnings = ArrayList<String>()
    for (warning in suite.warnings) {
        contractAppendUniqueGateString(warnings, warning)
    }
    let overallReady = contractProviderSmokeSelfCheckRequirement(
        warnings,
        policy,
        capability,
        attach,
        suite,
        hasSuccessBaseline,
        hasPrecheckCoverage,
        hasVerifyCoverage,
        hasProviderSelectionCoverage,
        hasHandshakeCoverage,
        hasLiveHandshakeCoverage,
        hasFallbackPlanCoverage
    )
    ContractProviderSmokeSelfCheckReport(
        policy,
        suite,
        capability.supportsClientTls,
        capability.supportsX509Verify,
        attach.supportsTlsPrecheck,
        hasSuccessBaseline,
        hasPrecheckCoverage,
        hasVerifyCoverage,
        hasProviderSelectionCoverage,
        hasHandshakeCoverage,
        hasLiveHandshakeCoverage,
        hasFallbackPlanCoverage,
        suite.attachBoundary.stableAttach,
        capability.defaultEligible,
        overallReady,
        warnings.toArray()
    )
}

public func contractRequireProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckReport {
    let report = contractProviderSmokeSelfCheck(policy: policy)
    if (!report.overallReady) {
        let detail = contractProviderSmokeSelfCheckFailureDetail(report)
        throw ContractException(ContractErrorCode.Unsupported, detail)
    }
    report
}

public func contractTryProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckOutcome {
    try {
        let result = contractProviderSmokeSelfCheck(policy: policy)
        return ContractProviderSmokeSelfCheckOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSelfCheckOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryRequireProviderSmokeSelfCheck(
    policy!: ContractProviderSmokeSelfCheckPolicy = ContractProviderSmokeSelfCheckPolicy()
): ContractProviderSmokeSelfCheckOutcome {
    try {
        let result = contractRequireProviderSmokeSelfCheck(policy: policy)
        return ContractProviderSmokeSelfCheckOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSelfCheckOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeProviderSmokeProfile(
    profile: ContractProviderSmokeProfile
): ContractProviderSmokeProfileTemplate {
    match (profile) {
        case ContractProviderSmokeProfile.ProviderCandidate =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "provider-candidate",
                ContractProviderSmokeSelfCheckPolicy(),
                [
                    "default public gate for the current release line",
                    "requires provider-candidate readiness but does not require stable attach or default HTTPS eligibility"
                ]
            )
        case ContractProviderSmokeProfile.AttachPlanning =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "attach-planning",
                ContractProviderSmokeSelfCheckPolicy(
                    requireProviderSelectionCoverage: false,
                    requireHandshakeCoverage: false,
                    requireFallbackPlan: true
                ),
                [
                    "optimized for teams that are still planning upper-layer attach integration",
                    "focuses on client TLS, X.509 verify, TLS precheck, success baseline, and fallback discipline"
                ]
            )
        case ContractProviderSmokeProfile.DefaultHttpsEligible =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "default-https-eligible",
                ContractProviderSmokeSelfCheckPolicy(
                    requireStableServerAttach: true,
                    requireDefaultEligible: true
                ),
                [
                    "intended for release gates that want to promote jinguissl beyond provider-candidate status",
                    "fails until stable server attach and default HTTPS eligibility become public facts"
                ]
            )
        case ContractProviderSmokeProfile.LiveAttachExperimental =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "live-attach-experimental",
                ContractProviderSmokeSelfCheckPolicy(
                    requireStableServerAttach: true,
                    requireLiveHandshakeCoverage: true
                ),
                [
                    "intended for experimental live attach validation work",
                    "requires a published stable attach path and a real handshake coverage baseline"
                ]
            )
        case ContractProviderSmokeProfile.ProductionStrict =>
            ContractProviderSmokeProfileTemplate(
                profile,
                "production-strict",
                ContractProviderSmokeSelfCheckPolicy(
                    requireStableServerAttach: true,
                    requireDefaultEligible: true,
                    requireLiveHandshakeCoverage: true
                ),
                [
                    "strictest provider gate for future production promotion",
                    "requires stable attach, default HTTPS eligibility, and live handshake coverage"
                ]
            )
    }
}

public func contractListProviderSmokeProfiles(): Array<ContractProviderSmokeProfileTemplate> {
    [
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.ProviderCandidate),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.AttachPlanning),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.DefaultHttpsEligible),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.LiveAttachExperimental),
        contractDescribeProviderSmokeProfile(ContractProviderSmokeProfile.ProductionStrict)
    ]
}

public func contractRequireProviderSmokeProfile(
    profile: ContractProviderSmokeProfile
): ContractProviderSmokeSelfCheckReport {
    let template = contractDescribeProviderSmokeProfile(profile)
    contractRequireProviderSmokeSelfCheck(policy: template.policy)
}

public func contractTryRequireProviderSmokeProfile(
    profile: ContractProviderSmokeProfile
): ContractProviderSmokeSelfCheckOutcome {
    try {
        let result = contractRequireProviderSmokeProfile(profile)
        return ContractProviderSmokeSelfCheckOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSelfCheckOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeProviderConsumptionPath(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionPathGuide {
    match (path) {
        case ContractProviderConsumptionPath.HttpClientTls =>
            ContractProviderConsumptionPathGuide(
                path,
                "http-client-tls",
                "provider-selection",
                true,
                true,
                false,
                true,
                "for HTTPS client paths, buildTlsAttachPlan(...) can be treated as a real provider attempt plan because client TLS verify/handshake are published contract surfaces; it still does not promote jinguissl to the default path",
                [
                    "client TLS may attempt jinguissl when upper-layer selection explicitly allows the provider-candidate path",
                    "verify failures should stay in tls_verify_error / no-auto-fallback instead of being silently downgraded"
                ],
                suggestedSmokeProfile: Some(ContractProviderSmokeProfile.ProviderCandidate),
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderConsumptionPath.HttpServerAttachPlanning =>
            ContractProviderConsumptionPathGuide(
                path,
                "http-server-attach-planning",
                "provider-planning",
                true,
                true,
                true,
                true,
                "for HTTPS server paths, buildTlsAttachPlan(...) currently means precheck, material preparation, and planning metadata only; final listener attach must stop in upper-layer glue such as lisi/stdx",
                [
                    "this is the correct public path for server-side jinguissl consumption today",
                    "candidate-order visibility is allowed here, but it must not be described as a default listener switch"
                ],
                suggestedSmokeProfile: Some(ContractProviderSmokeProfile.AttachPlanning),
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderConsumptionPath.HttpServerStableAttach =>
            ContractProviderConsumptionPathGuide(
                path,
                "http-server-stable-attach",
                "stable-server-attach",
                true,
                true,
                false,
                true,
                "a stable HTTPS listener attach attempt may use the published stable accepted-transport TLS1.3 X25519 contract path; full browser-grade HTTPS/H2 runtime closure remains a separate consumer/runtime concern",
                [
                    "this path is source-owned by JinguiSSL-contract and is safe for provider-gate selection",
                    "use stdx-default only as a manual fallback when the provider attach fails before connection consumption"
                ],
                suggestedSmokeProfile: Some(ContractProviderSmokeProfile.DefaultHttpsEligible),
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderConsumptionPath.SshClientLibrary =>
            ContractProviderConsumptionPathGuide(
                path,
                "ssh-client-library",
                "library-contract",
                true,
                false,
                false,
                true,
                "buildTlsAttachPlan(...) does not apply to SSH client runtime; consume SSH through jinguissl.contract.* handshake, host verification, and runtime bundle facades directly",
                [
                    "SSH client usage is a published library path rather than a stdx/listener provider attach path",
                    "host verification, runtime bundle, and rekey remain the intended stable consumption points"
                ]
            )
        case ContractProviderConsumptionPath.SshServerLibrary =>
            ContractProviderConsumptionPathGuide(
                path,
                "ssh-server-library",
                "library-contract",
                true,
                false,
                false,
                true,
                "buildTlsAttachPlan(...) does not apply to SSH server runtime; consume SSH server material, initial handshake, and runtime bundles directly through jinguissl.contract.*",
                [
                    "SSH server usage is already exposed as a stable library contract",
                    "this path does not depend on stdx TLS attach bridging"
                ]
            )
    }
}

public func contractListProviderConsumptionPaths(): Array<ContractProviderConsumptionPathGuide> {
    [
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.HttpClientTls),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.HttpServerAttachPlanning),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.HttpServerStableAttach),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.SshClientLibrary),
        contractDescribeProviderConsumptionPath(ContractProviderConsumptionPath.SshServerLibrary)
    ]
}

public func contractDescribeProviderFallbackOutcomeGuide(
    causeCode: ContractProviderFallbackCauseCode
): ContractProviderFallbackOutcomeGuide {
    match (causeCode) {
        case ContractProviderFallbackCauseCode.ProviderUnavailable =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.ProviderUnavailable,
                ContractProviderErrorPhase.ProviderSelection,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.NoFallback,
                false,
                [
                    "allow provider-candidate selection failures to fall back to the current stable default path",
                    "if the current selection is already stdx-default, record no-fallback instead of pretending a second automatic downgrade exists"
                ],
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderFallbackCauseCode.TlsHandshakeError =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.TlsHandshakeError,
                ContractProviderErrorPhase.TlsHandshake,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.ManualReview,
                ContractProviderFallbackOutcome.NoFallback,
                false,
                [
                    "handshake failures may allow cautious retry or fallback only when the connection was not consumed",
                    "once the connection is consumed, the outcome should move to manual-review instead of silent downgrade"
                ],
                suggestedFallbackTarget: "stdx-default"
            )
        case ContractProviderFallbackCauseCode.TlsVerifyError =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.TlsVerifyError,
                ContractProviderErrorPhase.TlsVerify,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                true,
                [
                    "certificate verification failures must remain operator-visible and should not be auto-fallen back",
                    "this is the expected bucket for hostname, pin, trust-anchor, and revocation failures"
                ]
            )
        case ContractProviderFallbackCauseCode.TlsPrecheckError =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.TlsPrecheckError,
                ContractProviderErrorPhase.TlsPrecheck,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                true,
                [
                    "TLS precheck/material preparation failures should be surfaced directly and must not auto-switch the default path",
                    "use this bucket for cert/key mismatch and similar input-contract failures"
                ]
            )
        case ContractProviderFallbackCauseCode.TlsNotConfigured =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.Unsupported,
                ContractProviderErrorPhase.TlsHandshake,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                ContractProviderFallbackOutcome.NoAutoFallback,
                true,
                [
                    "treat cleartext-or-unsupported peer paths as explicit no-auto-fallback failures",
                    "do not rewrite tls_not_configured into a successful provider attach story"
                ]
            )
        case ContractProviderFallbackCauseCode.CryptoUnavailable =>
            ContractProviderFallbackOutcomeGuide(
                causeCode,
                causeCode.toString(),
                ContractProviderErrorFamily.CryptoUnavailable,
                ContractProviderErrorPhase.ProviderRuntime,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.SuggestedOnly,
                ContractProviderFallbackOutcome.ManualReview,
                false,
                [
                    "crypto provider unavailability may suggest a return to the stable default path",
                    "if the stable default path is already active, escalate to manual-review instead of manufacturing another fallback"
                ],
                suggestedFallbackTarget: "stdx-default"
            )
    }
}

public func contractListProviderFallbackOutcomeGuides(): Array<ContractProviderFallbackOutcomeGuide> {
    [
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.ProviderUnavailable),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsHandshakeError),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsVerifyError),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsPrecheckError),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.TlsNotConfigured),
        contractDescribeProviderFallbackOutcomeGuide(ContractProviderFallbackCauseCode.CryptoUnavailable)
    ]
}

public func contractResolveProviderFallbackOutcome(
    request: ContractProviderFallbackResolutionRequest
): ContractProviderFallbackResolution {
    let guide = contractDescribeProviderFallbackOutcomeGuide(request.causeCode)
    let finalOutcome = if (request.connectionConsumed) {
        guide.consumedConnectionOutcome
    } else if (request.alreadyOnStableDefault) {
        guide.stableDefaultOutcome
    } else {
        guide.defaultOutcome
    }
    let fallbackTarget = if (finalOutcome == ContractProviderFallbackOutcome.SuggestedOnly) {
        guide.suggestedFallbackTarget
    } else {
        ""
    }
    let notes = ArrayList<String>()
    for (note in guide.notes) {
        notes.add(note)
    }
    match (finalOutcome) {
        case ContractProviderFallbackOutcome.SuggestedOnly =>
            notes.add("current result stays in suggested-only; upper layers may fall back to the stable default path if policy allows")
        case ContractProviderFallbackOutcome.NoAutoFallback =>
            notes.add("current result stays in no-auto-fallback; surface the error instead of auto-switching transport/provider")
        case ContractProviderFallbackOutcome.NoFallback =>
            notes.add("current result stays in no-fallback because no lower stable path remains to switch to")
        case ContractProviderFallbackOutcome.ManualReview =>
            notes.add("current result stays in manual-review; operator or higher-level retry logic must decide the next step")
    }
    ContractProviderFallbackResolution(
        guide,
        finalOutcome,
        notes.toArray(),
        fallbackTarget: fallbackTarget,
        shouldRecord: true,
        mustSurface: guide.mustSurface
    )
}

private func contractProviderConsumptionEntryId(
    path: ContractProviderConsumptionPath
): String {
    match (path) {
        case ContractProviderConsumptionPath.HttpClientTls => "jinguissl-provider-candidate"
        case ContractProviderConsumptionPath.HttpServerAttachPlanning => "jinguissl-provider-candidate"
        case ContractProviderConsumptionPath.HttpServerStableAttach => "jinguissl-provider-candidate"
        case ContractProviderConsumptionPath.SshClientLibrary => "jinguissl-library-direct"
        case ContractProviderConsumptionPath.SshServerLibrary => "jinguissl-library-direct"
    }
}

private func contractProviderConsumptionCandidateOrder(
    entryId: String,
    fallbackChain: Array<String>
): Array<String> {
    let order = ArrayList<String>()
    contractAppendUniqueGateString(order, entryId)
    for (fallback in fallbackChain) {
        contractAppendUniqueGateString(order, fallback)
    }
    order.toArray()
}

private func contractProviderConsumptionBlockedReason(
    guide: ContractProviderConsumptionPathGuide,
    smokeReadiness: ?ContractProviderSmokeSelfCheckReport
): String {
    if (!guide.publishedContractPath) {
        return "stable_attach_unpublished"
    }
    if (!guide.attemptAllowed) {
        return "attempt_not_allowed"
    }
    match (smokeReadiness) {
        case Some(value) =>
            if (!value.overallReady) {
                return "smoke_gate_not_ready"
            }
        case None => ()
    }
    "not_ready"
}

private func contractProviderConsumptionBlockedCandidates(
    entryId: String,
    guide: ContractProviderConsumptionPathGuide,
    smokeReadiness: ?ContractProviderSmokeSelfCheckReport,
    readyNow: Bool
): Array<String> {
    if (readyNow) {
        return []
    }
    ["${entryId}:${contractProviderConsumptionBlockedReason(guide, smokeReadiness)}"]
}

private func contractProviderConsumptionObservabilityTags(
    providerId: String,
    entryId: String,
    guide: ContractProviderConsumptionPathGuide,
    publicPath: String,
    releasePath: String,
    riskLevel: String,
    readyNow: Bool,
    selectedEntryId: String
): Array<String> {
    let tags = ArrayList<String>()
    let readyTag = if (readyNow) { "true" } else { "false" }
    let selectedTag = if (selectedEntryId.trimAscii().size > 0) {
        selectedEntryId.trimAscii()
    } else {
        "none"
    }
    let publishedTag = if (guide.publishedContractPath) { "true" } else { "false" }
    let providerSelectionTag = if (guide.useProviderSelection) { "true" } else { "false" }
    let attachGlueTag = if (guide.requiresUpperLayerAttachGlue) { "true" } else { "false" }
    contractAppendUniqueGateString(tags, "provider_id:${providerId}")
    contractAppendUniqueGateString(tags, "provider_entry:${entryId}")
    contractAppendUniqueGateString(tags, "selected_entry:${selectedTag}")
    contractAppendUniqueGateString(tags, "path:${guide.label}")
    contractAppendUniqueGateString(tags, "consumer_kind:${guide.consumerKind}")
    contractAppendUniqueGateString(tags, "public_path:${publicPath}")
    contractAppendUniqueGateString(tags, "release_path:${releasePath}")
    contractAppendUniqueGateString(tags, "risk_level:${riskLevel}")
    contractAppendUniqueGateString(tags, "ready_now:${readyTag}")
    contractAppendUniqueGateString(tags, "published_contract_path:${publishedTag}")
    contractAppendUniqueGateString(tags, "use_provider_selection:${providerSelectionTag}")
    contractAppendUniqueGateString(tags, "requires_upper_layer_attach_glue:${attachGlueTag}")
    tags.toArray()
}

public func contractDescribeProviderConsumptionGate(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionGateReport {
    let guide = contractDescribeProviderConsumptionPath(path)
    let capability = contractProviderCapabilityRecord()
    let attachBoundary = contractProviderServerAttachBoundary()
    let status = match (path) {
        case ContractProviderConsumptionPath.HttpClientTls =>
            ContractProviderConsumptionGateStatus.ProviderCandidate
        case ContractProviderConsumptionPath.HttpServerAttachPlanning =>
            ContractProviderConsumptionGateStatus.PlanningOnly
        case ContractProviderConsumptionPath.HttpServerStableAttach =>
            ContractProviderConsumptionGateStatus.ProviderCandidate
        case ContractProviderConsumptionPath.SshClientLibrary =>
            ContractProviderConsumptionGateStatus.LibraryContract
        case ContractProviderConsumptionPath.SshServerLibrary =>
            ContractProviderConsumptionGateStatus.LibraryContract
    }
    let publicPath = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate => "provider-candidate"
        case ContractProviderConsumptionGateStatus.PlanningOnly => "attach-planning"
        case ContractProviderConsumptionGateStatus.LibraryContract => "library-contract"
        case ContractProviderConsumptionGateStatus.Blocked => "blocked"
    }
    let releasePath = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate => "experimental-only"
        case ContractProviderConsumptionGateStatus.PlanningOnly => "experimental-only"
        case ContractProviderConsumptionGateStatus.LibraryContract => "library-direct"
        case ContractProviderConsumptionGateStatus.Blocked => "unsupported"
    }
    let riskLevel = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate => "medium"
        case ContractProviderConsumptionGateStatus.PlanningOnly => "medium"
        case ContractProviderConsumptionGateStatus.LibraryContract => "low"
        case ContractProviderConsumptionGateStatus.Blocked => "high"
    }
    let warnings = ArrayList<String>()
    for (note in guide.notes) {
        contractAppendUniqueGateString(warnings, note)
    }
    if (guide.requiresUpperLayerAttachGlue || !guide.publishedContractPath) {
        contractAppendUniqueGateString(warnings, attachBoundary.detail)
        for (reason in attachBoundary.unsupportedReasons) {
            contractAppendUniqueGateString(warnings, reason)
        }
    }
    if (!guide.publishedContractPath) {
        for (reason in capability.unsupportedReasons) {
            contractAppendUniqueGateString(warnings, reason)
        }
    }
    let smokeProfile: ?ContractProviderSmokeProfileTemplate = if (
        let Some(profile) <- guide.suggestedSmokeProfile
    ) {
        Some(contractDescribeProviderSmokeProfile(profile))
    } else {
        None
    }
    let smokeReadiness: ?ContractProviderSmokeSelfCheckReport = match (smokeProfile) {
        case Some(template) =>
            let readiness = contractProviderSmokeSelfCheck(policy: template.policy)
            for (note in template.notes) {
                contractAppendUniqueGateString(warnings, note)
            }
            for (warning in readiness.warnings) {
                contractAppendUniqueGateString(warnings, warning)
            }
            Some(readiness)
        case None => None
    }
    if (guide.suggestedFallbackTarget.trimAscii().size > 0) {
        contractAppendUniqueGateString(
            warnings,
            "preferred fallback target remains ${guide.suggestedFallbackTarget}"
        )
    }
    let fallbackChain = ArrayList<String>()
    if (guide.suggestedFallbackTarget.trimAscii().size > 0) {
        fallbackChain.add(guide.suggestedFallbackTarget)
    }
    let smokeReady = match (smokeReadiness) {
        case Some(value) => value.overallReady
        case None => true
    }
    let readyNow = guide.attemptAllowed && guide.publishedContractPath && smokeReady
    let providerId = capability.providerId
    let entryId = contractProviderConsumptionEntryId(path)
    let candidateOrder = contractProviderConsumptionCandidateOrder(
        entryId,
        fallbackChain.toArray()
    )
    let selectedEntryId = if (readyNow) { entryId } else { "" }
    let blockedCandidates = contractProviderConsumptionBlockedCandidates(
        entryId,
        guide,
        smokeReadiness,
        readyNow
    )
    let observabilityTags = contractProviderConsumptionObservabilityTags(
        providerId,
        entryId,
        guide,
        publicPath,
        releasePath,
        riskLevel,
        readyNow,
        selectedEntryId
    )
    let selectedReason = match (status) {
        case ContractProviderConsumptionGateStatus.ProviderCandidate =>
            if (smokeReady) {
                "path is published as a provider-candidate route; upper layers may attempt jinguissl through provider selection and keep stdx-default as the stable fallback target"
            } else {
                let smokeDetail = match (smokeReadiness) {
                    case Some(value) => contractProviderSmokeSelfCheckFailureDetail(value)
                    case None => "provider-candidate smoke profile is unavailable"
                }
                "path is a provider-candidate route, but the mapped smoke gate is not ready: ${smokeDetail}"
            }
        case ContractProviderConsumptionGateStatus.PlanningOnly =>
            if (smokeReady) {
                "path is published for precheck, material preparation, and attach planning only; upper-layer glue must complete the final listener attach"
            } else {
                let smokeDetail = match (smokeReadiness) {
                    case Some(value) => contractProviderSmokeSelfCheckFailureDetail(value)
                    case None => "attach-planning smoke profile is unavailable"
                }
                "path remains planning-only, but the mapped attach-planning smoke gate is not ready: ${smokeDetail}"
            }
        case ContractProviderConsumptionGateStatus.LibraryContract =>
            "path is published as a stable library contract and does not depend on provider-selection or stdx attach glue"
        case ContractProviderConsumptionGateStatus.Blocked =>
            let smokeDetail = match (smokeReadiness) {
                case Some(value) => contractProviderSmokeSelfCheckFailureDetail(value)
                case None => "default HTTPS eligibility is unavailable"
            }
            "path is currently blocked because stable HTTPS listener attach is not a published jinguissl contract: ${smokeDetail}"
    }
    ContractProviderConsumptionGateReport(
        path,
        guide,
        status,
        providerId,
        selectedEntryId,
        candidateOrder,
        blockedCandidates,
        publicPath,
        releasePath,
        riskLevel,
        observabilityTags,
        capability,
        attachBoundary,
        readyNow,
        selectedReason,
        warnings.toArray(),
        smokeProfile: smokeProfile,
        smokeReadiness: smokeReadiness,
        fallbackTarget: guide.suggestedFallbackTarget,
        fallbackChain: fallbackChain.toArray()
    )
}

public func contractListProviderConsumptionGates(): Array<ContractProviderConsumptionGateReport> {
    [
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpClientTls),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpServerAttachPlanning),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.HttpServerStableAttach),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.SshClientLibrary),
        contractDescribeProviderConsumptionGate(ContractProviderConsumptionPath.SshServerLibrary)
    ]
}

public func contractRequireProviderConsumptionGate(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionGateReport {
    let report = contractDescribeProviderConsumptionGate(path)
    if (!report.readyNow) {
        let warnings = ArrayList<String>()
        for (warning in report.warnings) {
            contractAppendUniqueGateString(warnings, warning)
        }
        if (report.fallbackTarget.trimAscii().size > 0) {
            contractAppendUniqueGateString(warnings, "suggested fallback target: ${report.fallbackTarget}")
        }
        let detail = contractJoinMessages(
            warnings.toArray(),
            "provider consumption gate ${report.publicPath} is not ready: ${report.selectedReason}; "
        )
        throw ContractException(ContractErrorCode.Unsupported, detail)
    }
    report
}

public func contractTryRequireProviderConsumptionGate(
    path: ContractProviderConsumptionPath
): ContractProviderConsumptionGateOutcome {
    try {
        let result = contractRequireProviderConsumptionGate(path)
        return ContractProviderConsumptionGateOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderConsumptionGateOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

private func contractProviderSmokeSelfCheckRequirement(
    warnings: ArrayList<String>,
    policy: ContractProviderSmokeSelfCheckPolicy,
    capability: ContractProviderCapabilityRecord,
    attach: ContractProviderAttachContractInfo,
    suite: ContractProviderSmokeSuiteReport,
    hasSuccessBaseline: Bool,
    hasPrecheckCoverage: Bool,
    hasVerifyCoverage: Bool,
    hasProviderSelectionCoverage: Bool,
    hasHandshakeCoverage: Bool,
    hasLiveHandshakeCoverage: Bool,
    hasFallbackPlanCoverage: Bool
): Bool {
    var overallReady = true
    if (capability.experimental) {
        contractAppendUniqueGateString(
            warnings,
            "provider remains experimental in the current public release line"
        )
    }
    if (policy.requireClientTls && (!capability.supportsClientTls || !attach.supportsClientTls)) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires client TLS facade support, but the published capability/attach contract is incomplete"
        )
        overallReady = false
    }
    if (policy.requireX509Verify && (!capability.supportsX509Verify || !attach.supportsX509Verify)) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires X.509 verify support, but the published capability/attach contract is incomplete"
        )
        overallReady = false
    }
    if (policy.requireTlsPrecheck && !attach.supportsTlsPrecheck) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires TLS precheck support, but the public attach contract does not advertise it"
        )
        overallReady = false
    }
    if (policy.requireSuccessBaseline && !hasSuccessBaseline) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires at least one success baseline fixture"
        )
        overallReady = false
    }
    if (policy.requirePrecheckCoverage && !hasPrecheckCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires at least one precheck-path smoke baseline"
        )
        overallReady = false
    }
    if (policy.requireVerifyCoverage && !hasVerifyCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires at least one verify-path smoke baseline"
        )
        overallReady = false
    }
    if (policy.requireProviderSelectionCoverage && !hasProviderSelectionCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires at least one provider-selection-path smoke baseline"
        )
        overallReady = false
    }
    if (policy.requireHandshakeCoverage && !hasHandshakeCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires at least one handshake coverage baseline"
        )
        overallReady = false
    }
    if (hasHandshakeCoverage && !hasLiveHandshakeCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check handshake coverage is currently metadata-only; a stable live attach path is not published yet"
        )
    }
    if (policy.requireLiveHandshakeCoverage && !hasLiveHandshakeCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires live handshake coverage, but the current suite only exposes metadata-only handshake baselines"
        )
        overallReady = false
    }
    if (policy.requireFallbackPlan && !hasFallbackPlanCoverage) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires fallback decisions for every non-success smoke baseline"
        )
        overallReady = false
    }
    if (
        policy.requireStableServerAttach &&
        (!capability.supportsServerTlsAttach || !attach.supportsServerTlsAttach || !suite.attachBoundary.stableAttach)
    ) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires stable server attach coverage, but the public boundary remains precheck-only"
        )
        overallReady = false
    }
    if (policy.requireDefaultEligible && !capability.defaultEligible) {
        contractAppendUniqueGateString(
            warnings,
            "provider smoke self-check requires default HTTPS eligibility, but the current release line keeps jinguissl provider-candidate only"
        )
        overallReady = false
    }
    overallReady
}

private func contractProviderSmokeSelfCheckFailureDetail(
    report: ContractProviderSmokeSelfCheckReport
): String {
    for (warning in report.warnings) {
        if (warning.contains("stable server attach")) {
            return warning
        }
    }
    for (warning in report.warnings) {
        if (warning.contains("default HTTPS eligibility")) {
            return warning
        }
    }
    for (warning in report.warnings) {
        if (warning.contains("live handshake coverage")) {
            return warning
        }
    }
    for (warning in report.warnings) {
        if (warning.contains("provider smoke self-check requires")) {
            return warning
        }
    }
    if (report.warnings.size > 0) {
        return report.warnings[0]
    }
    "provider smoke self-check policy requirements are not satisfied"
}

private func contractAppendUniqueGateString(
    values: ArrayList<String>,
    value: String
): Unit {
    for (existing in values) {
        if (existing == value) {
            return
        }
    }
    values.add(value)
}

private func contractJoinMessages(
    messages: Array<String>,
    prefix: String
): String {
    if (messages.size == 0) {
        return prefix.trimAscii()
    }
    var text = prefix
    var first = true
    for (message in messages) {
        if (first) {
            text = "${text}${message}"
            first = false
        } else {
            text = "${text}; ${message}"
        }
    }
    text
}
