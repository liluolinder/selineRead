package jinguissl.contract

import std.collection.ArrayList

private let PROVIDER_SMOKE_SUCCESS_HOSTNAME: String = "www." + "example.com"

public func contractMapToIgniteCryptoErrorCode(code: ContractErrorCode): ContractIgniteCryptoErrorCode {
    match (code) {
        case BadInput => ContractIgniteCryptoErrorCode.BadEnvelope
        case KeyNotFound => ContractIgniteCryptoErrorCode.KeyNotFound
        case VerifyFailed => ContractIgniteCryptoErrorCode.DecryptFailed
        case CryptoUnavailable => ContractIgniteCryptoErrorCode.CryptoUnavailable
        case ComplianceRejected => ContractIgniteCryptoErrorCode.CryptoUnavailable
        case Unsupported => ContractIgniteCryptoErrorCode.CryptoUnavailable
        case InternalError => ContractIgniteCryptoErrorCode.CryptoUnavailable
    }
}

public func contractMapExceptionToIgniteCryptoErrorCode(
    exception: ContractException
): ContractIgniteCryptoErrorCode {
    contractMapToIgniteCryptoErrorCode(exception.code)
}

public func contractDescribeProviderErrorCode(
    code: ContractErrorCode,
    phase!: ContractProviderErrorPhase = ContractProviderErrorPhase.ProviderRuntime,
    detail!: String = ""
): ContractProviderErrorDescriptor {
    let family = contractMapProviderErrorFamily(code, phase)
    let normalizedDetail = if (detail.trimAscii().size == 0) {
        "provider error: ${family.toString()}"
    } else {
        detail.trimAscii()
    }
    ContractProviderErrorDescriptor(
        "jinguissl",
        family,
        phase,
        contractProviderErrorIsRetryable(family),
        contractProviderErrorSuggestsFallback(family),
        normalizedDetail,
        code: Some(code),
        igniteCode: Some(contractMapToIgniteCryptoErrorCode(code))
    )
}

public func contractDescribeProviderContractException(
    exception: ContractException,
    phase!: ContractProviderErrorPhase = ContractProviderErrorPhase.ProviderRuntime
): ContractProviderErrorDescriptor {
    contractDescribeProviderErrorCode(
        exception.code,
        phase: phase,
        detail: exception.message
    )
}

public func contractRecommendProviderFallback(
    error: ContractProviderErrorDescriptor
): ContractProviderFallbackDecision {
    let fallbackTarget = if (error.fallbackSuggested) {
        "stdx"
    } else {
        ""
    }
    let mustSurface = match (error.family) {
        case ContractProviderErrorFamily.BadInput => true
        case ContractProviderErrorFamily.VerifyFailed => true
        case ContractProviderErrorFamily.KeyNotFound => true
        case ContractProviderErrorFamily.ComplianceRejected => true
        case ContractProviderErrorFamily.TlsPrecheckError => true
        case ContractProviderErrorFamily.TlsVerifyError => true
        case _ => false
    }
    ContractProviderFallbackDecision(
        error.providerId,
        error.fallbackSuggested,
        fallbackTarget,
        error.retryable,
        mustSurface,
        contractProviderFallbackReason(error)
    )
}

public enum ContractProviderSmokeFixtureCategory <: Equatable<ContractProviderSmokeFixtureCategory> & ToString {
    | Success
    | PrecheckFail
    | HandshakeFail
    | VerifyFail
    | ProviderUnavailable

    public operator func ==(right: ContractProviderSmokeFixtureCategory): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeFixtureCategory): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Success => 0
            case PrecheckFail => 1
            case HandshakeFail => 2
            case VerifyFail => 3
            case ProviderUnavailable => 4
        }
    }

    public func toString(): String {
        match (this) {
            case Success => "SUCCESS"
            case PrecheckFail => "PRECHECK_FAIL"
            case HandshakeFail => "HANDSHAKE_FAIL"
            case VerifyFail => "VERIFY_FAIL"
            case ProviderUnavailable => "PROVIDER_UNAVAILABLE"
        }
    }
}

public class ContractProviderSmokeFixtureInfo {
    public let providerId: String
    public let fixtureId: String
    public let category: ContractProviderSmokeFixtureCategory
    public let summary: String
    public let artifacts: Array<String>
    public let entrypoints: Array<String>
    public let expectedPhase: ?ContractProviderErrorPhase
    public let expectedCode: ?ContractErrorCode
    public let expectedFamily: ?ContractProviderErrorFamily
    public let notes: Array<String>

    public init(
        providerId: String,
        fixtureId: String,
        category: ContractProviderSmokeFixtureCategory,
        summary: String,
        artifacts: Array<String>,
        entrypoints: Array<String>,
        notes!: Array<String>,
        expectedPhase!: ?ContractProviderErrorPhase = None,
        expectedCode!: ?ContractErrorCode = None,
        expectedFamily!: ?ContractProviderErrorFamily = None
    ) {
        if (
            providerId.trimAscii().size == 0 ||
            fixtureId.trimAscii().size == 0 ||
            summary.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture string fields must not be empty"
            )
        }
        if (artifacts.size == 0 || entrypoints.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture artifacts and entrypoints must not be empty"
            )
        }
        this.providerId = providerId.trimAscii()
        this.fixtureId = fixtureId.trimAscii()
        this.category = category
        this.summary = summary.trimAscii()
        this.artifacts = artifacts.clone()
        this.entrypoints = entrypoints.clone()
        this.expectedPhase = expectedPhase
        this.expectedCode = expectedCode
        this.expectedFamily = expectedFamily
        this.notes = notes.clone()
    }
}

public enum ContractProviderSmokeExecutionMode <: Equatable<ContractProviderSmokeExecutionMode> & ToString {
    | PrecheckPath
    | VerifyPath
    | ProviderSelectionPath
    | MetadataOnly

    public operator func ==(right: ContractProviderSmokeExecutionMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeExecutionMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case PrecheckPath => 0
            case VerifyPath => 1
            case ProviderSelectionPath => 2
            case MetadataOnly => 3
        }
    }

    public func toString(): String {
        match (this) {
            case PrecheckPath => "PRECHECK_PATH"
            case VerifyPath => "VERIFY_PATH"
            case ProviderSelectionPath => "PROVIDER_SELECTION_PATH"
            case MetadataOnly => "METADATA_ONLY"
        }
    }
}

public class ContractProviderSmokeBaselineRequest {
    public let fixtureId: String

    public init(fixtureId: String) {
        if (fixtureId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke baseline request fixtureId must not be empty"
            )
        }
        this.fixtureId = fixtureId.trimAscii()
    }
}

public class ContractProviderSmokeBaselineReport {
    public let providerId: String
    public let fixture: ContractProviderSmokeFixtureInfo
    public let executionMode: ContractProviderSmokeExecutionMode
    public let expectedSuccess: Bool
    public let expectedDescriptor: ?ContractProviderErrorDescriptor
    public let expectedFallback: ?ContractProviderFallbackDecision
    public let capability: ContractProviderCapabilityRecord
    public let attachBoundary: ContractProviderServerAttachBoundary
    public let warnings: Array<String>

    public init(
        providerId: String,
        fixture: ContractProviderSmokeFixtureInfo,
        executionMode: ContractProviderSmokeExecutionMode,
        expectedSuccess: Bool,
        capability: ContractProviderCapabilityRecord,
        attachBoundary: ContractProviderServerAttachBoundary,
        warnings: Array<String>,
        expectedDescriptor!: ?ContractProviderErrorDescriptor = None,
        expectedFallback!: ?ContractProviderFallbackDecision = None
    ) {
        if (providerId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke baseline report providerId must not be empty"
            )
        }
        if (expectedSuccess) {
            match (expectedDescriptor) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline success report must not carry expected descriptor"
                    )
                case None => ()
            }
            match (expectedFallback) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline success report must not carry fallback decision"
                    )
                case None => ()
            }
        } else {
            match (expectedDescriptor) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline failure report must carry expected descriptor"
                    )
            }
            match (expectedFallback) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline failure report must carry fallback decision"
                    )
            }
        }
        this.providerId = providerId.trimAscii()
        this.fixture = fixture
        this.executionMode = executionMode
        this.expectedSuccess = expectedSuccess
        this.expectedDescriptor = expectedDescriptor
        this.expectedFallback = expectedFallback
        this.capability = capability
        this.attachBoundary = attachBoundary
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeBaselineOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeBaselineReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeBaselineReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke baseline outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke baseline outcome result must be empty when ok is false"
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

public class ContractProviderSmokeSuiteRequest {
    public let fixtureIds: Array<String>

    public init(fixtureIds!: Array<String> = []) {
        let normalized = ArrayList<String>()
        for (fixtureId in fixtureIds) {
            let trimmed = fixtureId.trimAscii()
            if (trimmed.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider smoke suite request fixtureIds must not contain empty values"
                )
            }
            normalized.add(trimmed)
        }
        this.fixtureIds = normalized.toArray()
    }
}

public class ContractProviderSmokeSuiteReport {
    public let providerId: String
    public let baselines: Array<ContractProviderSmokeBaselineReport>
    public let totalFixtureCount: Int64
    public let successFixtureCount: Int64
    public let failureFixtureCount: Int64
    public let precheckPathCount: Int64
    public let verifyPathCount: Int64
    public let providerSelectionPathCount: Int64
    public let metadataOnlyCount: Int64
    public let recommendedOrder: Array<String>
    public let capability: ContractProviderCapabilityRecord
    public let attachBoundary: ContractProviderServerAttachBoundary
    public let warnings: Array<String>

    public init(
        providerId: String,
        baselines: Array<ContractProviderSmokeBaselineReport>,
        totalFixtureCount: Int64,
        successFixtureCount: Int64,
        failureFixtureCount: Int64,
        precheckPathCount: Int64,
        verifyPathCount: Int64,
        providerSelectionPathCount: Int64,
        metadataOnlyCount: Int64,
        recommendedOrder: Array<String>,
        capability: ContractProviderCapabilityRecord,
        attachBoundary: ContractProviderServerAttachBoundary,
        warnings: Array<String>
    ) {
        if (providerId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report providerId must not be empty"
            )
        }
        if (baselines.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report must contain at least one baseline"
            )
        }
        if (recommendedOrder.size != baselines.size) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report recommended order must match baseline count"
            )
        }
        if (totalFixtureCount != Int64(baselines.size)) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report totalFixtureCount must match baseline count"
            )
        }
        if (successFixtureCount + failureFixtureCount != totalFixtureCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report success/failure counts must match totalFixtureCount"
            )
        }
        if (
            precheckPathCount +
            verifyPathCount +
            providerSelectionPathCount +
            metadataOnlyCount != totalFixtureCount
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite report execution-mode counts must match totalFixtureCount"
            )
        }
        this.providerId = providerId.trimAscii()
        this.baselines = baselines.clone()
        this.totalFixtureCount = totalFixtureCount
        this.successFixtureCount = successFixtureCount
        this.failureFixtureCount = failureFixtureCount
        this.precheckPathCount = precheckPathCount
        this.verifyPathCount = verifyPathCount
        this.providerSelectionPathCount = providerSelectionPathCount
        this.metadataOnlyCount = metadataOnlyCount
        this.recommendedOrder = recommendedOrder.clone()
        this.capability = capability
        this.attachBoundary = attachBoundary
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeSuiteOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeSuiteReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeSuiteReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke suite outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke suite outcome result must be empty when ok is false"
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

public class ContractProviderSmokeExecutableMaterial {
    public let leafPem: String
    public let intermediatePemBundle: String
    public let trustAnchorsPemBundle: String
    public let certificatePrivateKeyPem: String
    public let mismatchPrivateKeyPem: String
    public let successHostname: String
    public let mismatchHostname: String
    public let validationTime: String

    public init(
        leafPem: String,
        intermediatePemBundle: String,
        trustAnchorsPemBundle: String,
        certificatePrivateKeyPem: String,
        mismatchPrivateKeyPem!: String = "",
        successHostname!: String = PROVIDER_SMOKE_SUCCESS_HOSTNAME,
        mismatchHostname!: String = "api.policy.example",
        validationTime!: String = "230101000000Z"
    ) {
        if (
            leafPem.trimAscii().size == 0 ||
            intermediatePemBundle.trimAscii().size == 0 ||
            trustAnchorsPemBundle.trimAscii().size == 0 ||
            certificatePrivateKeyPem.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable material must include leaf, intermediate, trust anchor, and private key PEM"
            )
        }
        if (successHostname.trimAscii().size == 0 || mismatchHostname.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable material hostnames must not be empty"
            )
        }
        this.leafPem = leafPem.trimAscii()
        this.intermediatePemBundle = intermediatePemBundle.trimAscii()
        this.trustAnchorsPemBundle = trustAnchorsPemBundle.trimAscii()
        this.certificatePrivateKeyPem = certificatePrivateKeyPem.trimAscii()
        this.mismatchPrivateKeyPem = mismatchPrivateKeyPem.trimAscii()
        this.successHostname = successHostname.trimAscii()
        this.mismatchHostname = mismatchHostname.trimAscii()
        this.validationTime = validationTime.trimAscii()
    }

    public func certificateChainPemBundle(): String {
        "${leafPem}\n${intermediatePemBundle}"
    }
}

public class ContractProviderSmokeExecutableSuiteRequest {
    public let fixtureIds: Array<String>
    public let material: ?ContractProviderSmokeExecutableMaterial

    public init(
        fixtureIds!: Array<String> = [],
        material!: ?ContractProviderSmokeExecutableMaterial = None
    ) {
        let normalized = ArrayList<String>()
        for (fixtureId in fixtureIds) {
            let trimmed = fixtureId.trimAscii()
            if (trimmed.size == 0) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "provider smoke executable suite request fixtureIds must not contain empty values"
                )
            }
            normalized.add(trimmed)
        }
        this.fixtureIds = normalized.toArray()
        this.material = material
    }
}

public enum ContractProviderSmokeExecutableStatus <: Equatable<ContractProviderSmokeExecutableStatus> & ToString {
    | Passed
    | Failed
    | Skipped

    public operator func ==(right: ContractProviderSmokeExecutableStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractProviderSmokeExecutableStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Passed => 0
            case Failed => 1
            case Skipped => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Passed => "PASSED"
            case Failed => "FAILED"
            case Skipped => "SKIPPED"
        }
    }
}

public class ContractProviderSmokeExecutableResult {
    public let fixture: ContractProviderSmokeFixtureInfo
    public let executionMode: ContractProviderSmokeExecutionMode
    public let status: ContractProviderSmokeExecutableStatus
    public let message: String
    public let executedEntrypoints: Array<String>
    public let expectedCode: ?ContractErrorCode
    public let actualCode: ?ContractErrorCode
    public let expectedFamily: ?ContractProviderErrorFamily
    public let actualFamily: ?ContractProviderErrorFamily

    public init(
        fixture: ContractProviderSmokeFixtureInfo,
        executionMode: ContractProviderSmokeExecutionMode,
        status: ContractProviderSmokeExecutableStatus,
        message: String,
        executedEntrypoints!: Array<String> = [],
        expectedCode!: ?ContractErrorCode = None,
        actualCode!: ?ContractErrorCode = None,
        expectedFamily!: ?ContractProviderErrorFamily = None,
        actualFamily!: ?ContractProviderErrorFamily = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable result message must not be empty"
            )
        }
        if (status != ContractProviderSmokeExecutableStatus.Skipped && executedEntrypoints.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable non-skipped result must record at least one executed entrypoint"
            )
        }
        this.fixture = fixture
        this.executionMode = executionMode
        this.status = status
        this.message = message.trimAscii()
        this.executedEntrypoints = executedEntrypoints.clone()
        this.expectedCode = expectedCode
        this.actualCode = actualCode
        this.expectedFamily = expectedFamily
        this.actualFamily = actualFamily
    }
}

public class ContractProviderSmokeExecutableSuiteReport {
    public let providerId: String
    public let results: Array<ContractProviderSmokeExecutableResult>
    public let totalFixtureCount: Int64
    public let executedFixtureCount: Int64
    public let skippedFixtureCount: Int64
    public let passedFixtureCount: Int64
    public let failedFixtureCount: Int64
    public let verifyPathExecutedCount: Int64
    public let precheckPathExecutedCount: Int64
    public let providerSelectionPathExecutedCount: Int64
    public let metadataOnlySkippedCount: Int64
    public let warnings: Array<String>

    public init(
        providerId: String,
        results: Array<ContractProviderSmokeExecutableResult>,
        totalFixtureCount: Int64,
        executedFixtureCount: Int64,
        skippedFixtureCount: Int64,
        passedFixtureCount: Int64,
        failedFixtureCount: Int64,
        verifyPathExecutedCount: Int64,
        precheckPathExecutedCount: Int64,
        providerSelectionPathExecutedCount: Int64,
        metadataOnlySkippedCount: Int64,
        warnings: Array<String>
    ) {
        if (providerId.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable suite report providerId must not be empty"
            )
        }
        if (results.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable suite report must contain at least one result"
            )
        }
        if (Int64(results.size) != totalFixtureCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable suite report total count must match results"
            )
        }
        if (executedFixtureCount + skippedFixtureCount != totalFixtureCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable suite report executed/skipped counts must match total"
            )
        }
        if (passedFixtureCount + failedFixtureCount != executedFixtureCount) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable suite report pass/fail counts must match executed count"
            )
        }
        this.providerId = providerId.trimAscii()
        this.results = results.clone()
        this.totalFixtureCount = totalFixtureCount
        this.executedFixtureCount = executedFixtureCount
        this.skippedFixtureCount = skippedFixtureCount
        this.passedFixtureCount = passedFixtureCount
        this.failedFixtureCount = failedFixtureCount
        this.verifyPathExecutedCount = verifyPathExecutedCount
        this.precheckPathExecutedCount = precheckPathExecutedCount
        this.providerSelectionPathExecutedCount = providerSelectionPathExecutedCount
        this.metadataOnlySkippedCount = metadataOnlySkippedCount
        this.warnings = warnings.clone()
    }
}

public class ContractProviderSmokeExecutableSuiteOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractProviderSmokeExecutableSuiteReport

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractProviderSmokeExecutableSuiteReport = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke executable suite outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke executable suite outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke executable suite outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke executable suite outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke executable suite outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke executable suite outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "provider smoke executable suite outcome result must be empty when ok is false"
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

public func contractProviderSmokeFixtureCatalog(): Array<ContractProviderSmokeFixtureInfo> {
    let fixtures = ArrayList<ContractProviderSmokeFixtureInfo>()
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "success-x509-policy-chain",
            ContractProviderSmokeFixtureCategory.Success,
            "policy root + intermediate + leaf chain verifies cleanly for the bundled ${PROVIDER_SMOKE_SUCCESS_HOSTNAME} fixture",
            [
                "testdata/x509/policy_root.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "testdata/x509/policy_leaf_key_pkcs8.pem"
            ],
            [
                "contractVerifyServerCertificatePem(...)",
                "contractVerifyServerCertificateChainPem(...)",
                "contractTls13VerifyHttpServerFlightX25519(...)"
            ],
            notes: [
                "recommended baseline success smoke for provider-side X.509 verification wiring",
                "the bundled policy leaf fixture is issued to ${PROVIDER_SMOKE_SUCCESS_HOSTNAME}"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "precheck-cert-key-mismatch",
            ContractProviderSmokeFixtureCategory.PrecheckFail,
            "certificate chain and private key mismatch must fail before any TLS attach or handshake",
            [
                "testdata/x509/policy_leaf.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/rsa_2048_pkcs8.pem"
            ],
            [
                "contractValidateHttpServerTlsConfigInput(...)",
                "contractPrepareHttpServerTlsMaterial(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsPrecheck),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsPrecheckError),
            notes: [
                "maps provider failures into a deterministic precheck bucket for upper-layer startup smoke",
                "useful when the provider advertises server material preparation but not final listener attach"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "verify-hostname-mismatch",
            ContractProviderSmokeFixtureCategory.VerifyFail,
            "server certificate verification must reject a hostname outside the policy leaf SAN set",
            [
                "testdata/x509/policy_root.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "hostname: not.policy.example"
            ],
            [
                "contractVerifyServerCertificatePem(...)",
                "contractTryVerifyServerCertificateChainPem(...)",
                "contractTls13VerifyHttpServerFlightX25519(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsVerify),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsVerifyError),
            notes: [
                "primary verify-fail baseline for HTTP client and provider-facing certificate checks"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "verify-pin-mismatch",
            ContractProviderSmokeFixtureCategory.VerifyFail,
            "leaf certificate pin mismatch must be surfaced as a verification failure instead of a parse/config error",
            [
                "testdata/x509/policy_root.pem",
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "pin-policy: wrong-der-or-spki-pin"
            ],
            [
                "contractVerifyServerCertificatePem(...)",
                "contractComputeLeafPinsFromPem(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsVerify),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsVerifyError),
            notes: [
                "helps upper layers distinguish trust-policy failures from precheck/input failures"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "verify-untrusted-chain",
            ContractProviderSmokeFixtureCategory.VerifyFail,
            "peer chain without a matching trust anchor must stay in the verify-fail bucket instead of being treated as provider unavailability",
            [
                "testdata/x509/policy_intermediate.pem",
                "testdata/x509/policy_leaf.pem",
                "trust-anchor: missing-policy-root"
            ],
            [
                "contractVerifyServerCertificateChainPem(...)",
                "contractTryVerifyServerCertificateChainPem(...)",
                "contractVerifyHttpClientPeerCertificatePem(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsVerify),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsVerifyError),
            notes: [
                "represents a more realistic HTTPS peer verification failure than a synthetic parse error",
                "useful for provider selectors that want a trust-anchor-missing baseline"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "handshake-server-hello-decode",
            ContractProviderSmokeFixtureCategory.HandshakeFail,
            "server hello decode failure should be normalized into the handshake-fail bucket",
            [
                "inline: server hello decode failed",
                "operation: tls"
            ],
            [
                "contractDescribeProviderContractException(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.TlsHandshake),
            expectedCode: Some(ContractErrorCode.VerifyFailed),
            expectedFamily: Some(ContractProviderErrorFamily.TlsHandshakeError),
            notes: [
                "metadata fixture for provider adapters that need a deterministic handshake-failure baseline without mining test code"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "attach-stable-listener-unpublished",
            ContractProviderSmokeFixtureCategory.HandshakeFail,
            "server attach attempts that go beyond precheck/material preparation must currently fail closed because the stable listener attach contract is unpublished",
            [
                "scene: server",
                "requested-path: stable-listener-attach",
                "boundary: PRECHECK_ONLY"
            ],
            [
                "contractProviderServerAttachBoundary(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.ProviderRuntime),
            expectedCode: Some(ContractErrorCode.Unsupported),
            expectedFamily: Some(ContractProviderErrorFamily.Unsupported),
            notes: [
                "documents attach failure as a planning/runtime contract issue rather than a fake successful attach",
                "aligns with the public rule that server attach must stop in upper-layer glue such as lisi/stdx"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "provider-not-linked",
            ContractProviderSmokeFixtureCategory.ProviderUnavailable,
            "provider selection should surface an unavailable provider explicitly when the candidate is not linked or gated off",
            [
                "detail: provider not linked",
                "backend-hint: none"
            ],
            [
                "contractDescribeProviderErrorCode(...)",
                "contractRecommendProviderFallback(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.ProviderSelection),
            expectedCode: Some(ContractErrorCode.CryptoUnavailable),
            expectedFamily: Some(ContractProviderErrorFamily.ProviderUnavailable),
            notes: [
                "documents the intended fallback-to-stdx path when provider selection fails before runtime"
            ]
        )
    )
    fixtures.add(
        ContractProviderSmokeFixtureInfo(
            "jinguissl",
            "provider-experimental-gated-off",
            ContractProviderSmokeFixtureCategory.ProviderUnavailable,
            "provider selection should also surface unavailable when upper-layer policy keeps experimental jinguissl attach attempts disabled",
            [
                "scene: server",
                "allowExperimental: false",
                "candidate: jinguissl-provider-candidate"
            ],
            [
                "contractRecommendProviderFallback(...)"
            ],
            expectedPhase: Some(ContractProviderErrorPhase.ProviderSelection),
            expectedCode: Some(ContractErrorCode.CryptoUnavailable),
            expectedFamily: Some(ContractProviderErrorFamily.ProviderUnavailable),
            notes: [
                "represents the more realistic case where jinguissl is present but intentionally not selected as a stable path",
                "helps upper layers keep candidate-order visibility without presenting a failed selection as the default route"
            ]
        )
    )
    fixtures.toArray()
}

public func contractRequireProviderSmokeFixture(
    fixtureId: String
): ContractProviderSmokeFixtureInfo {
    let normalizedFixtureId = fixtureId.trimAscii()
    if (normalizedFixtureId.size == 0) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "provider smoke fixture id must not be empty"
        )
    }
    for (fixture in contractProviderSmokeFixtureCatalog()) {
        if (fixture.fixtureId == normalizedFixtureId) {
            return fixture
        }
    }
    throw ContractException(
        ContractErrorCode.BadInput,
        "unknown provider smoke fixture: ${normalizedFixtureId}"
    )
}

public func contractDescribeProviderSmokeBaseline(
    fixtureId: String
): ContractProviderSmokeBaselineReport {
    contractDescribeProviderSmokeBaselineRequest(
        ContractProviderSmokeBaselineRequest(fixtureId)
    )
}

public func contractDescribeProviderSmokeBaselineRequest(
    request: ContractProviderSmokeBaselineRequest
): ContractProviderSmokeBaselineReport {
    let fixture = contractRequireProviderSmokeFixture(request.fixtureId)
    let capability = contractProviderCapabilityRecord()
    let attachBoundary = contractProviderServerAttachBoundary()
    let executionMode = contractProviderSmokeExecutionModeForFixture(fixture)
    let warnings = contractProviderSmokeWarnings(
        fixture,
        executionMode,
        capability,
        attachBoundary
    )
    if (fixture.category == ContractProviderSmokeFixtureCategory.Success) {
        return ContractProviderSmokeBaselineReport(
            capability.providerId,
            fixture,
            executionMode,
            true,
            capability,
            attachBoundary,
            warnings
        )
    }
    let descriptor = contractDescribeProviderErrorCode(
        contractProviderSmokeExpectedCode(fixture),
        phase: contractProviderSmokeExpectedPhase(fixture),
        detail: "provider smoke baseline ${fixture.fixtureId}: ${fixture.summary}"
    )
    let fallback = contractRecommendProviderFallback(descriptor)
    ContractProviderSmokeBaselineReport(
        capability.providerId,
        fixture,
        executionMode,
        false,
        capability,
        attachBoundary,
        warnings,
        expectedDescriptor: Some(descriptor),
        expectedFallback: Some(fallback)
    )
}

public func contractTryDescribeProviderSmokeBaselineRequest(
    request: ContractProviderSmokeBaselineRequest
): ContractProviderSmokeBaselineOutcome {
    try {
        let result = contractDescribeProviderSmokeBaselineRequest(request)
        return ContractProviderSmokeBaselineOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeBaselineOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeProviderSmokeSuite(): ContractProviderSmokeSuiteReport {
    contractDescribeProviderSmokeSuiteRequest(ContractProviderSmokeSuiteRequest())
}

public func contractDescribeProviderSmokeSuiteRequest(
    request: ContractProviderSmokeSuiteRequest
): ContractProviderSmokeSuiteReport {
    let fixtureIds = contractProviderSmokeSuiteFixtureIds(request)
    let baselines = ArrayList<ContractProviderSmokeBaselineReport>()
    let recommendedOrder = ArrayList<String>()
    let warnings = ArrayList<String>()
    let capability = contractProviderCapabilityRecord()
    let attachBoundary = contractProviderServerAttachBoundary()
    var successFixtureCount: Int64 = 0
    var failureFixtureCount: Int64 = 0
    var precheckPathCount: Int64 = 0
    var verifyPathCount: Int64 = 0
    var providerSelectionPathCount: Int64 = 0
    var metadataOnlyCount: Int64 = 0
    for (fixtureId in fixtureIds) {
        let baseline = contractDescribeProviderSmokeBaseline(fixtureId)
        baselines.add(baseline)
        recommendedOrder.add(baseline.fixture.fixtureId)
        if (baseline.expectedSuccess) {
            successFixtureCount += 1
        } else {
            failureFixtureCount += 1
        }
        match (baseline.executionMode) {
            case ContractProviderSmokeExecutionMode.PrecheckPath =>
                precheckPathCount += 1
            case ContractProviderSmokeExecutionMode.VerifyPath =>
                verifyPathCount += 1
            case ContractProviderSmokeExecutionMode.ProviderSelectionPath =>
                providerSelectionPathCount += 1
            case ContractProviderSmokeExecutionMode.MetadataOnly =>
                metadataOnlyCount += 1
        }
        for (warning in baseline.warnings) {
            contractAppendUniqueString(warnings, warning)
        }
    }
    if (metadataOnlyCount > 0) {
        contractAppendUniqueString(
            warnings,
            "metadata-only smoke baselines should be asserted through contract descriptors instead of being counted as live handshake regressions"
        )
    }
    ContractProviderSmokeSuiteReport(
        capability.providerId,
        baselines.toArray(),
        Int64(baselines.size),
        successFixtureCount,
        failureFixtureCount,
        precheckPathCount,
        verifyPathCount,
        providerSelectionPathCount,
        metadataOnlyCount,
        recommendedOrder.toArray(),
        capability,
        attachBoundary,
        warnings.toArray()
    )
}

public func contractTryDescribeProviderSmokeSuiteRequest(
    request: ContractProviderSmokeSuiteRequest
): ContractProviderSmokeSuiteOutcome {
    try {
        let result = contractDescribeProviderSmokeSuiteRequest(request)
        return ContractProviderSmokeSuiteOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        return ContractProviderSmokeSuiteOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractRunProviderSmokeExecutableSuite(): ContractProviderSmokeExecutableSuiteReport {
    contractRunProviderSmokeExecutableSuiteRequest(ContractProviderSmokeExecutableSuiteRequest())
}

public func contractRunProviderSmokeExecutableSuiteRequest(
    request: ContractProviderSmokeExecutableSuiteRequest
): ContractProviderSmokeExecutableSuiteReport {
    let fixtureIds = contractProviderSmokeExecutableSuiteFixtureIds(request)
    let results = ArrayList<ContractProviderSmokeExecutableResult>()
    let warnings = ArrayList<String>()
    let capability = contractProviderCapabilityRecord()
    var executedFixtureCount: Int64 = 0
    var skippedFixtureCount: Int64 = 0
    var passedFixtureCount: Int64 = 0
    var failedFixtureCount: Int64 = 0
    var verifyPathExecutedCount: Int64 = 0
    var precheckPathExecutedCount: Int64 = 0
    var providerSelectionPathExecutedCount: Int64 = 0
    var metadataOnlySkippedCount: Int64 = 0
    for (fixtureId in fixtureIds) {
        let fixture = contractRequireProviderSmokeFixture(fixtureId)
        let result = contractRunProviderSmokeExecutableFixture(fixture, request.material)
        results.add(result)
        match (result.status) {
            case ContractProviderSmokeExecutableStatus.Passed =>
                executedFixtureCount += 1
                passedFixtureCount += 1
            case ContractProviderSmokeExecutableStatus.Failed =>
                executedFixtureCount += 1
                failedFixtureCount += 1
            case ContractProviderSmokeExecutableStatus.Skipped =>
                skippedFixtureCount += 1
        }
        if (result.status != ContractProviderSmokeExecutableStatus.Skipped) {
            match (result.executionMode) {
                case ContractProviderSmokeExecutionMode.VerifyPath =>
                    verifyPathExecutedCount += 1
                case ContractProviderSmokeExecutionMode.PrecheckPath =>
                    precheckPathExecutedCount += 1
                case ContractProviderSmokeExecutionMode.ProviderSelectionPath =>
                    providerSelectionPathExecutedCount += 1
                case ContractProviderSmokeExecutionMode.MetadataOnly => ()
            }
        } else if (result.executionMode == ContractProviderSmokeExecutionMode.MetadataOnly) {
            metadataOnlySkippedCount += 1
        }
        if (result.status == ContractProviderSmokeExecutableStatus.Skipped) {
            contractAppendUniqueString(warnings, result.message)
        }
    }
    if (metadataOnlySkippedCount > 0) {
        contractAppendUniqueString(
            warnings,
            "metadata-only provider smoke fixtures remain skipped by the executable runner until a stable live attach or TLS-flight seam is published"
        )
    }
    ContractProviderSmokeExecutableSuiteReport(
        capability.providerId,
        results.toArray(),
        Int64(results.size),
        executedFixtureCount,
        skippedFixtureCount,
        passedFixtureCount,
        failedFixtureCount,
        verifyPathExecutedCount,
        precheckPathExecutedCount,
        providerSelectionPathExecutedCount,
        metadataOnlySkippedCount,
        warnings.toArray()
    )
}

public func contractTryRunProviderSmokeExecutableSuiteRequest(
    request: ContractProviderSmokeExecutableSuiteRequest
): ContractProviderSmokeExecutableSuiteOutcome {
    try {
        let result = contractRunProviderSmokeExecutableSuiteRequest(request)
        ContractProviderSmokeExecutableSuiteOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractProviderSmokeExecutableSuiteOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

private func contractMapProviderErrorFamily(
    code: ContractErrorCode,
    phase: ContractProviderErrorPhase
): ContractProviderErrorFamily {
    match (code) {
        case ContractErrorCode.BadInput => ContractProviderErrorFamily.BadInput
        case ContractErrorCode.KeyNotFound => ContractProviderErrorFamily.KeyNotFound
        case ContractErrorCode.CryptoUnavailable =>
            if (
                phase == ContractProviderErrorPhase.ProviderSelection ||
                phase == ContractProviderErrorPhase.ProviderRuntime
            ) {
                ContractProviderErrorFamily.ProviderUnavailable
            } else {
                ContractProviderErrorFamily.CryptoUnavailable
            }
        case ContractErrorCode.ComplianceRejected => ContractProviderErrorFamily.ComplianceRejected
        case ContractErrorCode.Unsupported => ContractProviderErrorFamily.Unsupported
        case ContractErrorCode.InternalError => ContractProviderErrorFamily.InternalError
        case ContractErrorCode.VerifyFailed =>
            match (phase) {
                case ContractProviderErrorPhase.TlsPrecheck => ContractProviderErrorFamily.TlsPrecheckError
                case ContractProviderErrorPhase.TlsHandshake => ContractProviderErrorFamily.TlsHandshakeError
                case ContractProviderErrorPhase.TlsVerify => ContractProviderErrorFamily.TlsVerifyError
                case _ => ContractProviderErrorFamily.VerifyFailed
            }
    }
}

private func contractProviderErrorIsRetryable(family: ContractProviderErrorFamily): Bool {
    match (family) {
        case ContractProviderErrorFamily.TlsHandshakeError => true
        case _ => false
    }
}

private func contractProviderErrorSuggestsFallback(family: ContractProviderErrorFamily): Bool {
    match (family) {
        case ContractProviderErrorFamily.CryptoUnavailable => true
        case ContractProviderErrorFamily.Unsupported => true
        case ContractProviderErrorFamily.InternalError => true
        case ContractProviderErrorFamily.TlsHandshakeError => true
        case ContractProviderErrorFamily.ProviderUnavailable => true
        case _ => false
    }
}

private func contractProviderFallbackReason(error: ContractProviderErrorDescriptor): String {
    if (!error.fallbackSuggested) {
        return "surface ${error.family.toString()} to the caller and do not auto-fallback"
    }
    match (error.family) {
        case ContractProviderErrorFamily.ProviderUnavailable =>
            "provider is unavailable in the current runtime; prefer stdx fallback via lisi"
        case ContractProviderErrorFamily.Unsupported =>
            "requested capability is unsupported in jinguissl; prefer stdx fallback via lisi"
        case ContractProviderErrorFamily.CryptoUnavailable =>
            "crypto backend is unavailable; prefer stdx fallback via lisi"
        case ContractProviderErrorFamily.InternalError =>
            "provider hit an internal error; quarantine this provider and prefer stdx fallback"
        case ContractProviderErrorFamily.TlsHandshakeError =>
            "TLS handshake failed inside provider flow; retry cautiously or fall back to stdx"
        case _ =>
            "fallback is suggested by provider policy"
    }
}

private func contractProviderSmokeExecutionModeForFixture(
    fixture: ContractProviderSmokeFixtureInfo
): ContractProviderSmokeExecutionMode {
    match (fixture.category) {
        case ContractProviderSmokeFixtureCategory.PrecheckFail =>
            ContractProviderSmokeExecutionMode.PrecheckPath
        case ContractProviderSmokeFixtureCategory.VerifyFail =>
            ContractProviderSmokeExecutionMode.VerifyPath
        case ContractProviderSmokeFixtureCategory.Success =>
            ContractProviderSmokeExecutionMode.VerifyPath
        case ContractProviderSmokeFixtureCategory.ProviderUnavailable =>
            ContractProviderSmokeExecutionMode.ProviderSelectionPath
        case ContractProviderSmokeFixtureCategory.HandshakeFail =>
            ContractProviderSmokeExecutionMode.MetadataOnly
    }
}

private func contractProviderSmokeExpectedCode(
    fixture: ContractProviderSmokeFixtureInfo
): ContractErrorCode {
    match (fixture.expectedCode) {
        case Some(value) => value
        case None =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture ${fixture.fixtureId} does not define an expected code"
            )
    }
}

private func contractProviderSmokeExpectedPhase(
    fixture: ContractProviderSmokeFixtureInfo
): ContractProviderErrorPhase {
    match (fixture.expectedPhase) {
        case Some(value) => value
        case None =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture ${fixture.fixtureId} does not define an expected phase"
            )
    }
}

private func contractProviderSmokeExpectedFamily(
    fixture: ContractProviderSmokeFixtureInfo
): ContractProviderErrorFamily {
    match (fixture.expectedFamily) {
        case Some(value) => value
        case None =>
            throw ContractException(
                ContractErrorCode.BadInput,
                "provider smoke fixture ${fixture.fixtureId} does not define an expected family"
            )
    }
}

private func contractRunProviderSmokeExecutableFixture(
    fixture: ContractProviderSmokeFixtureInfo,
    material: ?ContractProviderSmokeExecutableMaterial
): ContractProviderSmokeExecutableResult {
    let executionMode = contractProviderSmokeExecutionModeForFixture(fixture)
    match (executionMode) {
        case ContractProviderSmokeExecutionMode.MetadataOnly =>
            return contractProviderSmokeExecutableSkip(
                fixture,
                executionMode,
                "fixture ${fixture.fixtureId} is metadata-only; no live handshake or attach execution is claimed"
            )
        case ContractProviderSmokeExecutionMode.ProviderSelectionPath =>
            return contractRunProviderSelectionSmokeFixture(fixture, executionMode)
        case ContractProviderSmokeExecutionMode.PrecheckPath =>
            match (material) {
                case Some(value) =>
                    return contractRunPrecheckSmokeFixture(fixture, executionMode, value)
                case None =>
                    return contractProviderSmokeExecutableSkip(
                        fixture,
                        executionMode,
                        "fixture ${fixture.fixtureId} requires executable PEM material"
                    )
            }
        case ContractProviderSmokeExecutionMode.VerifyPath =>
            match (material) {
                case Some(value) =>
                    return contractRunVerifySmokeFixture(fixture, executionMode, value)
                case None =>
                    return contractProviderSmokeExecutableSkip(
                        fixture,
                        executionMode,
                        "fixture ${fixture.fixtureId} requires executable PEM material"
                    )
            }
    }
}

private func contractRunVerifySmokeFixture(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    material: ContractProviderSmokeExecutableMaterial
): ContractProviderSmokeExecutableResult {
    match (fixture.fixtureId) {
        case "success-x509-policy-chain" =>
            try {
                let leafResult = contractVerifyServerCertificatePem(
                    material.leafPem,
                    material.trustAnchorsPemBundle,
                    intermediatesPemBundle: material.intermediatePemBundle,
                    hostname: material.successHostname,
                    validationTime: material.validationTime
                )
                let chainResult = contractVerifyServerCertificateChainPem(
                    material.certificateChainPemBundle(),
                    material.trustAnchorsPemBundle,
                    intermediatesPemBundle: material.intermediatePemBundle,
                    hostname: material.successHostname,
                    validationTime: material.validationTime
                )
                if (leafResult.chainLength <= 0 || chainResult.chainLength <= 0) {
                    return contractProviderSmokeExecutableFail(
                        fixture,
                        executionMode,
                        "success fixture returned an invalid verified chain length",
                        executedEntrypoints: [
                            "contractVerifyServerCertificatePem(...)",
                            "contractVerifyServerCertificateChainPem(...)"
                        ]
                    )
                }
                return contractProviderSmokeExecutablePass(
                    fixture,
                    executionMode,
                    "success fixture executed X.509 leaf and chain verification paths",
                    executedEntrypoints: [
                        "contractVerifyServerCertificatePem(...)",
                        "contractVerifyServerCertificateChainPem(...)"
                    ]
                )
            } catch (e: ContractException) {
                return contractProviderSmokeExecutableFail(
                    fixture,
                    executionMode,
                    "success fixture failed unexpectedly: ${e.message}",
                    executedEntrypoints: [
                        "contractVerifyServerCertificatePem(...)",
                        "contractVerifyServerCertificateChainPem(...)"
                    ],
                    actualCode: Some(e.code)
                )
            }
        case "verify-hostname-mismatch" =>
            try {
                _ = contractVerifyServerCertificatePem(
                    material.leafPem,
                    material.trustAnchorsPemBundle,
                    intermediatesPemBundle: material.intermediatePemBundle,
                    hostname: material.mismatchHostname,
                    validationTime: material.validationTime
                )
                return contractProviderSmokeExecutableFail(
                    fixture,
                    executionMode,
                    "hostname mismatch fixture unexpectedly verified",
                    executedEntrypoints: ["contractVerifyServerCertificatePem(...)"],
                    expectedCode: Some(contractProviderSmokeExpectedCode(fixture))
                )
            } catch (e: ContractException) {
                return contractProviderSmokeExpectedFailureResult(
                    fixture,
                    executionMode,
                    e,
                    "hostname mismatch fixture failed with the expected verification error",
                    ["contractVerifyServerCertificatePem(...)"]
                )
            }
        case "verify-pin-mismatch" =>
            let wrongPin = Array<Byte>(32, repeat: 0)
            try {
                _ = contractVerifyServerCertificatePem(
                    material.leafPem,
                    material.trustAnchorsPemBundle,
                    intermediatesPemBundle: material.intermediatePemBundle,
                    hostname: material.successHostname,
                    validationTime: material.validationTime,
                    pinPolicy: ContractX509PinPolicy(allowedLeafDerSha256: [wrongPin])
                )
                return contractProviderSmokeExecutableFail(
                    fixture,
                    executionMode,
                    "pin mismatch fixture unexpectedly verified",
                    executedEntrypoints: ["contractVerifyServerCertificatePem(...)"],
                    expectedCode: Some(contractProviderSmokeExpectedCode(fixture))
                )
            } catch (e: ContractException) {
                return contractProviderSmokeExpectedFailureResult(
                    fixture,
                    executionMode,
                    e,
                    "pin mismatch fixture failed with the expected verification error",
                    ["contractVerifyServerCertificatePem(...)"]
                )
            }
        case _ =>
            contractProviderSmokeExecutableSkip(
                fixture,
                executionMode,
                "fixture ${fixture.fixtureId} has no stable contract-local executable verify handler yet"
            )
    }
}

private func contractRunPrecheckSmokeFixture(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    material: ContractProviderSmokeExecutableMaterial
): ContractProviderSmokeExecutableResult {
    if (fixture.fixtureId != "precheck-cert-key-mismatch") {
        return contractProviderSmokeExecutableSkip(
            fixture,
            executionMode,
            "fixture ${fixture.fixtureId} has no stable contract-local executable precheck handler yet"
        )
    }
    if (material.mismatchPrivateKeyPem.size == 0) {
        return contractProviderSmokeExecutableSkip(
            fixture,
            executionMode,
            "fixture ${fixture.fixtureId} requires a mismatch private key PEM"
        )
    }
    try {
        _ = contractValidateHttpServerTlsConfigInput(
            material.certificateChainPemBundle(),
            material.mismatchPrivateKeyPem,
            alpnProtocols: ["h2", "http/1.1"],
            requireHttp2Alpn: true
        )
        return contractProviderSmokeExecutableFail(
            fixture,
            executionMode,
            "precheck mismatch fixture unexpectedly validated",
            executedEntrypoints: ["contractValidateHttpServerTlsConfigInput(...)"],
            expectedCode: Some(contractProviderSmokeExpectedCode(fixture))
        )
    } catch (e: ContractException) {
        return contractProviderSmokeExpectedFailureResult(
            fixture,
            executionMode,
            e,
            "precheck mismatch fixture failed with the expected TLS precheck error",
            ["contractValidateHttpServerTlsConfigInput(...)"]
        )
    }
}

private func contractRunProviderSelectionSmokeFixture(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode
): ContractProviderSmokeExecutableResult {
    let expectedCode = contractProviderSmokeExpectedCode(fixture)
    let expectedPhase = contractProviderSmokeExpectedPhase(fixture)
    let expectedFamily = contractProviderSmokeExpectedFamily(fixture)
    let descriptor = contractDescribeProviderErrorCode(
        expectedCode,
        phase: expectedPhase,
        detail: "provider smoke executable ${fixture.fixtureId}: ${fixture.summary}"
    )
    let fallback = contractRecommendProviderFallback(descriptor)
    if (descriptor.family != expectedFamily) {
        return contractProviderSmokeExecutableFail(
            fixture,
            executionMode,
            "provider selection descriptor family did not match expected family",
            executedEntrypoints: [
                "contractDescribeProviderErrorCode(...)",
                "contractRecommendProviderFallback(...)"
            ],
            expectedCode: Some(expectedCode),
            actualCode: Some(expectedCode),
            expectedFamily: Some(expectedFamily),
            actualFamily: Some(descriptor.family)
        )
    }
    if (!fallback.fallbackSuggested) {
        return contractProviderSmokeExecutableFail(
            fixture,
            executionMode,
            "provider selection fixture did not suggest fallback for unavailable provider",
            executedEntrypoints: [
                "contractDescribeProviderErrorCode(...)",
                "contractRecommendProviderFallback(...)"
            ],
            expectedCode: Some(expectedCode),
            actualCode: Some(expectedCode),
            expectedFamily: Some(expectedFamily),
            actualFamily: Some(descriptor.family)
        )
    }
    contractProviderSmokeExecutablePass(
        fixture,
        executionMode,
        "provider selection fixture executed descriptor and fallback decision helpers",
        executedEntrypoints: [
            "contractDescribeProviderErrorCode(...)",
            "contractRecommendProviderFallback(...)"
        ],
        expectedCode: Some(expectedCode),
        actualCode: Some(expectedCode),
        expectedFamily: Some(expectedFamily),
        actualFamily: Some(descriptor.family)
    )
}

private func contractProviderSmokeExpectedFailureResult(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    exception: ContractException,
    passMessage: String,
    executedEntrypoints: Array<String>
): ContractProviderSmokeExecutableResult {
    let expectedCode = contractProviderSmokeExpectedCode(fixture)
    let expectedPhase = contractProviderSmokeExpectedPhase(fixture)
    let expectedFamily = contractProviderSmokeExpectedFamily(fixture)
    let actualFamily = contractMapProviderErrorFamily(exception.code, expectedPhase)
    if (exception.code == expectedCode && actualFamily == expectedFamily) {
        return contractProviderSmokeExecutablePass(
            fixture,
            executionMode,
            passMessage,
            executedEntrypoints: executedEntrypoints,
            expectedCode: Some(expectedCode),
            actualCode: Some(exception.code),
            expectedFamily: Some(expectedFamily),
            actualFamily: Some(actualFamily)
        )
    }
    contractProviderSmokeExecutableFail(
        fixture,
        executionMode,
        "fixture ${fixture.fixtureId} failed with unexpected code ${exception.code.toString()}: ${exception.message}",
        executedEntrypoints: executedEntrypoints,
        expectedCode: Some(expectedCode),
        actualCode: Some(exception.code),
        expectedFamily: Some(expectedFamily),
        actualFamily: Some(actualFamily)
    )
}

private func contractProviderSmokeExecutablePass(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    message: String,
    executedEntrypoints!: Array<String>,
    expectedCode!: ?ContractErrorCode = None,
    actualCode!: ?ContractErrorCode = None,
    expectedFamily!: ?ContractProviderErrorFamily = None,
    actualFamily!: ?ContractProviderErrorFamily = None
): ContractProviderSmokeExecutableResult {
    ContractProviderSmokeExecutableResult(
        fixture,
        executionMode,
        ContractProviderSmokeExecutableStatus.Passed,
        message,
        executedEntrypoints: executedEntrypoints,
        expectedCode: expectedCode,
        actualCode: actualCode,
        expectedFamily: expectedFamily,
        actualFamily: actualFamily
    )
}

private func contractProviderSmokeExecutableFail(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    message: String,
    executedEntrypoints!: Array<String>,
    expectedCode!: ?ContractErrorCode = None,
    actualCode!: ?ContractErrorCode = None,
    expectedFamily!: ?ContractProviderErrorFamily = None,
    actualFamily!: ?ContractProviderErrorFamily = None
): ContractProviderSmokeExecutableResult {
    ContractProviderSmokeExecutableResult(
        fixture,
        executionMode,
        ContractProviderSmokeExecutableStatus.Failed,
        message,
        executedEntrypoints: executedEntrypoints,
        expectedCode: expectedCode,
        actualCode: actualCode,
        expectedFamily: expectedFamily,
        actualFamily: actualFamily
    )
}

private func contractProviderSmokeExecutableSkip(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    message: String
): ContractProviderSmokeExecutableResult {
    ContractProviderSmokeExecutableResult(
        fixture,
        executionMode,
        ContractProviderSmokeExecutableStatus.Skipped,
        message
    )
}

private func contractProviderSmokeWarnings(
    fixture: ContractProviderSmokeFixtureInfo,
    executionMode: ContractProviderSmokeExecutionMode,
    capability: ContractProviderCapabilityRecord,
    attachBoundary: ContractProviderServerAttachBoundary
): Array<String> {
    let warnings = ArrayList<String>()
    if (!capability.defaultEligible) {
        warnings.add("provider is not default HTTPS eligible in the current public release line")
    }
    if (!attachBoundary.stableAttach) {
        warnings.add("stable server attach is unavailable; keep smoke exercises within precheck, verify, or provider-selection boundaries")
    }
    match (executionMode) {
        case ContractProviderSmokeExecutionMode.MetadataOnly =>
            warnings.add("this smoke baseline is modeled through provider error normalization metadata rather than a live network handshake")
        case ContractProviderSmokeExecutionMode.ProviderSelectionPath =>
            warnings.add("provider-unavailable is an expected selection-path baseline and should not be counted as a functional regression by itself")
        case ContractProviderSmokeExecutionMode.VerifyPath =>
            if (!capability.supportsX509Verify) {
                warnings.add("provider does not currently advertise X.509 verify support for verify-path smoke")
            }
        case ContractProviderSmokeExecutionMode.PrecheckPath =>
            let attach = contractProviderAttachContractInfo()
            if (!attach.supportsTlsPrecheck) {
                warnings.add("provider does not currently advertise TLS precheck support for precheck-path smoke")
            }
    }
    if (fixture.entrypoints.size == 1 && fixture.entrypoints[0].contains("contractDescribeProvider")) {
        warnings.add("this baseline is descriptor-driven and should be exercised through contract-level error normalization helpers")
    }
    warnings.toArray()
}

private func contractProviderSmokeSuiteFixtureIds(
    request: ContractProviderSmokeSuiteRequest
): Array<String> {
    if (request.fixtureIds.size == 0) {
        let fixtureIds = ArrayList<String>()
        for (fixture in contractProviderSmokeFixtureCatalog()) {
            fixtureIds.add(fixture.fixtureId)
        }
        return fixtureIds.toArray()
    }
    request.fixtureIds.clone()
}

private func contractProviderSmokeExecutableSuiteFixtureIds(
    request: ContractProviderSmokeExecutableSuiteRequest
): Array<String> {
    if (request.fixtureIds.size == 0) {
        let fixtureIds = ArrayList<String>()
        for (fixture in contractProviderSmokeFixtureCatalog()) {
            fixtureIds.add(fixture.fixtureId)
        }
        return fixtureIds.toArray()
    }
    request.fixtureIds.clone()
}

private func contractAppendUniqueString(
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
