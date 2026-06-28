package jinguissl.contract

import std.collection.ArrayList
import jinguissl_core.crypto.aes.{
    AesEngine,
    AesEngineKind,
    AesHardwareMountPoint,
    AesHardwareRoadmapEntry,
    AesNativeBridgeCallShape,
    AesNativeBridgeContract,
    AesNativeBridgeSpec,
    AesHardwareProbe,
    aesDefaultHardwareBackendHint,
    aesHardwareRoadmap,
    aesListHardwareMountPoints,
    aesNativeBridgeDescribeCallShape,
    aesOpenNativeBridge,
    aesProbeHardware,
    aesResolveEngine,
    aesResolveEngineWithNativeBridge
}
import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}

public class ContractAesHardwareMountPointInfo {
    public let backend: String
    public let available: Bool
    public let accelerated: Bool
    public let detected: Bool
    public let detail: String

    public init(
        backend: String,
        available: Bool,
        accelerated: Bool,
        detected: Bool,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware mount point backend must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware mount point detail must not be empty")
        }
        this.backend = backend.trimAscii()
        this.available = available
        this.accelerated = accelerated
        this.detected = detected
        this.detail = detail.trimAscii()
    }
}

public class ContractAesHardwareProbeInfo {
    public let available: Bool
    public let backend: String
    public let accelerated: Bool
    public let detail: String

    public init(
        available: Bool,
        backend: String,
        accelerated: Bool,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware probe backend must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES hardware probe detail must not be empty")
        }
        this.available = available
        this.backend = backend.trimAscii()
        this.accelerated = accelerated
        this.detail = detail.trimAscii()
    }
}

public class ContractAesHardwareRoadmapEntry {
    public let architecture: String
    public let backend: String
    public let status: String
    public let targetVersion: String
    public let detail: String

    public init(
        architecture: String,
        backend: String,
        status: String,
        targetVersion: String,
        detail: String
    ) {
        if (
            architecture.trimAscii().size == 0 ||
            backend.trimAscii().size == 0 ||
            status.trimAscii().size == 0 ||
            targetVersion.trimAscii().size == 0 ||
            detail.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES hardware roadmap entry fields must not be empty"
            )
        }
        this.architecture = architecture.trimAscii()
        this.backend = backend.trimAscii()
        this.status = status.trimAscii()
        this.targetVersion = targetVersion.trimAscii()
        this.detail = detail.trimAscii()
    }
}

public enum ContractAesEngineKind <: Equatable<ContractAesEngineKind> & ToString {
    | Auto
    | Software
    | Hardware

    public operator func ==(right: ContractAesEngineKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractAesEngineKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Auto => 0
            case Software => 1
            case Hardware => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Auto => "AUTO"
            case Software => "SOFTWARE"
            case Hardware => "HARDWARE"
        }
    }
}

public class ContractAesEngineInfo {
    public let requested: ContractAesEngineKind
    public let active: ContractAesEngineKind
    public let backend: String
    public let accelerated: Bool
    public let detail: String

    public init(
        requested: ContractAesEngineKind,
        active: ContractAesEngineKind,
        backend: String,
        accelerated: Bool,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES engine backend must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES engine detail must not be empty")
        }
        this.requested = requested
        this.active = active
        this.backend = backend.trimAscii()
        this.accelerated = accelerated
        this.detail = detail.trimAscii()
    }
}

public class ContractAesEngineResolveOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractAesEngineInfo

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractAesEngineInfo = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES engine resolve outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES engine resolve outcome result must be empty when ok is false"
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

public class ContractAesNativeBridgeSpec {
    public let backend: String
    public let libraryPath: String
    public let symbolPrefix: String
    public let abiVersion: Int64

    public init(
        backend: String,
        libraryPath!: String = "",
        symbolPrefix!: String = "jinguissl_aes",
        abiVersion!: Int64 = 1
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge backend must not be empty")
        }
        if (symbolPrefix.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge symbol prefix must not be empty")
        }
        if (abiVersion <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge ABI version must be positive")
        }
        this.backend = backend.trimAscii()
        this.libraryPath = libraryPath.trimAscii()
        this.symbolPrefix = symbolPrefix.trimAscii()
        this.abiVersion = abiVersion
    }
}

public class ContractAesNativeBridgeContractInfo {
    public let backend: String
    public let abiVersion: Int64
    public let expandKeySymbol: String
    public let encryptBlocksSymbol: String
    public let decryptBlocksSymbol: String
    public let ghashMulSymbol: String
    public let detail: String

    public init(
        backend: String,
        abiVersion: Int64,
        expandKeySymbol: String,
        encryptBlocksSymbol: String,
        decryptBlocksSymbol: String,
        ghashMulSymbol: String,
        detail: String
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge contract backend must not be empty")
        }
        if (
            expandKeySymbol.trimAscii().size == 0 ||
            encryptBlocksSymbol.trimAscii().size == 0 ||
            decryptBlocksSymbol.trimAscii().size == 0 ||
            ghashMulSymbol.trimAscii().size == 0 ||
            detail.trimAscii().size == 0
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES native bridge contract symbol/detail fields must not be empty"
            )
        }
        this.backend = backend.trimAscii()
        this.abiVersion = abiVersion
        this.expandKeySymbol = expandKeySymbol.trimAscii()
        this.encryptBlocksSymbol = encryptBlocksSymbol.trimAscii()
        this.decryptBlocksSymbol = decryptBlocksSymbol.trimAscii()
        this.ghashMulSymbol = ghashMulSymbol.trimAscii()
        this.detail = detail.trimAscii()
    }
}

public class ContractAesNativeBridgeCallShapeInfo {
    public let backend: String
    public let abiVersion: Int64
    public let keyBytes: Int64
    public let roundCount: Int64
    public let roundKeyWordCount: Int64
    public let expandedKeyBlobBytes: Int64
    public let blockBytes: Int64
    public let requiresBlockAlignedPayload: Bool

    public init(
        backend: String,
        abiVersion: Int64,
        keyBytes: Int64,
        roundCount: Int64,
        roundKeyWordCount: Int64,
        expandedKeyBlobBytes: Int64,
        blockBytes: Int64,
        requiresBlockAlignedPayload: Bool
    ) {
        if (backend.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES native bridge call-shape backend must not be empty")
        }
        if (keyBytes <= 0 || roundCount <= 0 || roundKeyWordCount <= 0 || expandedKeyBlobBytes <= 0 || blockBytes <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES native bridge call-shape numeric fields must be positive"
            )
        }
        this.backend = backend.trimAscii()
        this.abiVersion = abiVersion
        this.keyBytes = keyBytes
        this.roundCount = roundCount
        this.roundKeyWordCount = roundKeyWordCount
        this.expandedKeyBlobBytes = expandedKeyBlobBytes
        this.blockBytes = blockBytes
        this.requiresBlockAlignedPayload = requiresBlockAlignedPayload
    }
}

public class ContractAesNativeBridgeDiagnostics {
    public let spec: ContractAesNativeBridgeSpec
    public let probe: ContractAesHardwareProbeInfo
    public let engine: ContractAesEngineInfo
    public let contract: ContractAesNativeBridgeContractInfo

    public init(
        spec: ContractAesNativeBridgeSpec,
        probe: ContractAesHardwareProbeInfo,
        engine: ContractAesEngineInfo,
        contract: ContractAesNativeBridgeContractInfo
    ) {
        this.spec = ContractAesNativeBridgeSpec(
            spec.backend,
            libraryPath: spec.libraryPath,
            symbolPrefix: spec.symbolPrefix,
            abiVersion: spec.abiVersion
        )
        this.probe = probe
        this.engine = engine
        this.contract = contract
    }
}

public class ContractAesNativeBridgeDiagnosticsOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractAesNativeBridgeDiagnostics

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractAesNativeBridgeDiagnostics = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES native bridge diagnostics outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "AES native bridge diagnostics outcome result must be empty when ok is false"
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

public enum ContractAesBackendReadiness <: Equatable<ContractAesBackendReadiness> & ToString {
    | AcceleratedReady
    | BridgeReady
    | SoftwareOnly
    | Unavailable

    public operator func ==(right: ContractAesBackendReadiness): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractAesBackendReadiness): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AcceleratedReady => 0
            case BridgeReady => 1
            case SoftwareOnly => 2
            case Unavailable => 3
        }
    }

    public func toString(): String {
        match (this) {
            case AcceleratedReady => "ACCELERATED_READY"
            case BridgeReady => "BRIDGE_READY"
            case SoftwareOnly => "SOFTWARE_ONLY"
            case Unavailable => "UNAVAILABLE"
        }
    }
}

public class ContractAesBackendRecommendation {
    public let backendHint: String
    public let readiness: ContractAesBackendReadiness
    public let accelerated: Bool
    public let reason: String

    public init(
        backendHint: String,
        readiness: ContractAesBackendReadiness,
        accelerated: Bool,
        reason: String
    ) {
        if (backendHint.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES backend recommendation hint must not be empty")
        }
        if (reason.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES backend recommendation reason must not be empty")
        }
        this.backendHint = backendHint.trimAscii()
        this.readiness = readiness
        this.accelerated = accelerated
        this.reason = reason.trimAscii()
    }
}

public class ContractAesStartupSelfCheckReport {
    public let defaultBackendHint: String
    public let effectiveBackendHint: String
    public let recommendation: ContractAesBackendRecommendation
    public let selectedEngine: ContractAesEngineInfo
    public let acceleratedBackendReady: Bool
    public let mountPoints: Array<ContractAesHardwareMountPointInfo>
    public let diagnostics: ?ContractAesNativeBridgeDiagnostics

    public init(
        defaultBackendHint: String,
        effectiveBackendHint: String,
        recommendation: ContractAesBackendRecommendation,
        selectedEngine: ContractAesEngineInfo,
        acceleratedBackendReady: Bool,
        mountPoints: Array<ContractAesHardwareMountPointInfo>,
        diagnostics!: ?ContractAesNativeBridgeDiagnostics = None
    ) {
        if (effectiveBackendHint.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES startup self-check effective backend hint must not be empty")
        }
        if (mountPoints.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "AES startup self-check mount points must not be empty")
        }
        this.defaultBackendHint = defaultBackendHint.trimAscii()
        this.effectiveBackendHint = effectiveBackendHint.trimAscii()
        this.recommendation = recommendation
        this.selectedEngine = selectedEngine
        this.acceleratedBackendReady = acceleratedBackendReady
        this.mountPoints = mountPoints.clone()
        this.diagnostics = diagnostics
    }
}

public class ContractAesCurrentReleasePlanReport {
    public let currentReleaseSeries: String
    public let primaryBackend: String
    public let primaryArchitectures: Array<String>
    public let deferredBackends: Array<String>
    public let reservedBackends: Array<String>
    public let startup: ContractAesStartupSelfCheckReport
    public let usingPrimaryBackend: Bool
    public let primaryBackendAvailable: Bool
    public let warnings: Array<String>

    public init(
        currentReleaseSeries: String,
        primaryBackend: String,
        primaryArchitectures: Array<String>,
        deferredBackends: Array<String>,
        reservedBackends: Array<String>,
        startup: ContractAesStartupSelfCheckReport,
        usingPrimaryBackend: Bool,
        primaryBackendAvailable: Bool,
        warnings: Array<String>
    ) {
        if (currentReleaseSeries.trimAscii().size == 0 || primaryBackend.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES current release plan report release series and primary backend must not be empty"
            )
        }
        if (primaryArchitectures.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "AES current release plan report primary architectures must not be empty"
            )
        }
        this.currentReleaseSeries = currentReleaseSeries.trimAscii()
        this.primaryBackend = primaryBackend.trimAscii()
        this.primaryArchitectures = primaryArchitectures.clone()
        this.deferredBackends = deferredBackends.clone()
        this.reservedBackends = reservedBackends.clone()
        this.startup = startup
        this.usingPrimaryBackend = usingPrimaryBackend
        this.primaryBackendAvailable = primaryBackendAvailable
        this.warnings = warnings.clone()
    }
}

public func contractAesListHardwareMountPoints(): Array<ContractAesHardwareMountPointInfo> {
    let mounts = aesListHardwareMountPoints()
    let converted = ArrayList<ContractAesHardwareMountPointInfo>()
    for (mount in mounts) {
        converted.add(contractFromAesHardwareMountPoint(mount))
    }
    converted.toArray()
}

public func contractAesHardwareRoadmap(): Array<ContractAesHardwareRoadmapEntry> {
    let entries = aesHardwareRoadmap()
    let converted = ArrayList<ContractAesHardwareRoadmapEntry>()
    for (entry in entries) {
        converted.add(contractFromAesHardwareRoadmapEntry(entry))
    }
    converted.toArray()
}

public func contractAesDefaultHardwareBackendHint(): String {
    aesDefaultHardwareBackendHint()
}

public func contractAesProbeHardware(backendHint!: String = ""): ContractAesHardwareProbeInfo {
    contractFromAesHardwareProbe(aesProbeHardware(backendHint: backendHint))
}

public func contractResolveAesEngine(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesEngineInfo {
    try {
        contractFromAesEngine(
            aesResolveEngine(
                requested: contractToAesEngineKind(requestedEngine),
                hardwareHint: backendHint
            )
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapAesCryptoExceptionToErrorCode(e),
            "AES engine resolve failed: ${e.message}"
        )
    }
}

public func contractTryResolveAesEngine(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesEngineResolveOutcome {
    try {
        let result = contractResolveAesEngine(requestedEngine: requestedEngine, backendHint: backendHint)
        ContractAesEngineResolveOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractAesEngineResolveOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractRequireAesAcceleratedBackend(
    backendHint!: String = ""
): ContractAesHardwareProbeInfo {
    let probe = contractAesProbeHardware(backendHint: backendHint)
    if (!probe.available || !probe.accelerated) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "AES accelerated backend is required: ${probe.detail}"
        )
    }
    probe
}

public func contractInspectAesNativeBridge(
    spec: ContractAesNativeBridgeSpec,
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto
): ContractAesNativeBridgeDiagnostics {
    try {
        let innerSpec = contractToAesNativeBridgeSpec(spec)
        let handle = aesOpenNativeBridge(innerSpec)
        let engine = aesResolveEngineWithNativeBridge(
            innerSpec,
            requested: contractToAesEngineKind(requestedEngine)
        )
        ContractAesNativeBridgeDiagnostics(
            spec,
            contractFromAesHardwareProbe(handle.probe),
            contractFromAesEngine(engine),
            contractFromAesNativeBridgeContract(handle.contract)
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapAesCryptoExceptionToErrorCode(e),
            "AES native bridge inspection failed: ${e.message}"
        )
    }
}

public func contractTryInspectAesNativeBridge(
    spec: ContractAesNativeBridgeSpec,
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto
): ContractAesNativeBridgeDiagnosticsOutcome {
    try {
        let result = contractInspectAesNativeBridge(spec, requestedEngine: requestedEngine)
        ContractAesNativeBridgeDiagnosticsOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractAesNativeBridgeDiagnosticsOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractDescribeAesNativeBridgeCallShape(
    spec: ContractAesNativeBridgeSpec,
    keyBytes: Int64
): ContractAesNativeBridgeCallShapeInfo {
    try {
        let innerSpec = contractToAesNativeBridgeSpec(spec)
        let handle = aesOpenNativeBridge(innerSpec)
        contractFromAesNativeBridgeCallShape(aesNativeBridgeDescribeCallShape(handle, keyBytes))
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapAesCryptoExceptionToErrorCode(e),
            "AES native bridge call-shape describe failed: ${e.message}"
        )
    }
}

public func contractRecommendAesBackend(): ContractAesBackendRecommendation {
    let mounts = contractAesListHardwareMountPoints()
    let armv8 = contractFindAesMountPoint(mounts, "armv8-ce")
    match (armv8) {
        case Some(value) =>
            if (value.available && value.accelerated) {
                return ContractAesBackendRecommendation(
                    "armv8-ce",
                    ContractAesBackendReadiness.AcceleratedReady,
                    true,
                    "ARMv8 CE native backend is available and accelerated on current runtime"
                )
            }
        case None => ()
    }

    let shim = contractFindAesMountPoint(mounts, "shim")
    match (shim) {
        case Some(value) =>
            if (value.available) {
                return ContractAesBackendRecommendation(
                    "shim",
                    ContractAesBackendReadiness.BridgeReady,
                    false,
                    "software shim backend is available for bridge-path validation but does not provide hardware acceleration"
                )
            }
        case None => ()
    }

    ContractAesBackendRecommendation(
        "none",
        ContractAesBackendReadiness.Unavailable,
        false,
        "no AES hardware backend is currently available; software AES remains usable"
    )
}

public func contractAesStartupSelfCheck(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesStartupSelfCheckReport {
    let mounts = contractAesListHardwareMountPoints()
    let recommendation = contractRecommendAesBackend()
    let defaultHint = contractAesDefaultHardwareBackendHint().trimAscii()
    let overrideHint = backendHint.trimAscii()
    let effectiveHint = if (overrideHint.size > 0) {
        overrideHint
    } else if (defaultHint.size > 0) {
        defaultHint
    } else {
        recommendation.backendHint
    }
    let selectedEngine = contractResolveAesEngine(requestedEngine: requestedEngine, backendHint: effectiveHint)
    let diagnostics: ?ContractAesNativeBridgeDiagnostics = if (selectedEngine.backend == "none") {
        None
    } else {
        Some(
            contractInspectAesNativeBridge(
                ContractAesNativeBridgeSpec(selectedEngine.backend),
                requestedEngine: requestedEngine
            )
        )
    }
    ContractAesStartupSelfCheckReport(
        defaultHint,
        effectiveHint,
        recommendation,
        selectedEngine,
        selectedEngine.accelerated,
        mounts,
        diagnostics: diagnostics
    )
}

public func contractAesCurrentReleasePlan(
    requestedEngine!: ContractAesEngineKind = ContractAesEngineKind.Auto,
    backendHint!: String = ""
): ContractAesCurrentReleasePlanReport {
    let startup = contractAesStartupSelfCheck(
        requestedEngine: requestedEngine,
        backendHint: backendHint
    )
    let roadmap = contractAesHardwareRoadmap()
    let primaryBackend = contractFindPrimaryAesRoadmapBackend(roadmap)
    let primaryArchitectures = contractCollectAesRoadmapArchitectures(
        roadmap,
        "PRIMARY_ACTIVE"
    )
    let deferredBackends = contractCollectAesRoadmapBackendsByPrefix(
        roadmap,
        "DEFERRED"
    )
    let reservedBackends = contractCollectAesRoadmapBackendsByPrefix(
        roadmap,
        "RESERVED"
    )
    let primaryMount = contractFindAesMountPoint(startup.mountPoints, primaryBackend)
    let primaryBackendAvailable = match (primaryMount) {
        case Some(value) => value.available && value.accelerated
        case None => false
    }
    let usingPrimaryBackend = startup.selectedEngine.backend == primaryBackend && startup.selectedEngine.accelerated
    let warnings = ArrayList<String>()
    if (!primaryBackendAvailable) {
        warnings.add("current release primary backend is unavailable on this runtime")
    }
    if (!usingPrimaryBackend) {
        warnings.add("selected AES backend is not the current 0.6 primary backend")
    }
    if (contractContainsAesString(deferredBackends, "aesni")) {
        warnings.add("x86_64 AES-NI remains deferred to 0.7 in the current release plan")
    }
    if (reservedBackends.size > 0) {
        warnings.add("loongarch64/riscv64 backends remain reserved skeletons in the current release plan")
    }
    ContractAesCurrentReleasePlanReport(
        "0.6",
        primaryBackend,
        primaryArchitectures,
        deferredBackends,
        reservedBackends,
        startup,
        usingPrimaryBackend,
        primaryBackendAvailable,
        warnings.toArray()
    )
}

public func contractRequireAesCurrentReleasePrimaryBackend(
    backendHint!: String = ""
): ContractAesCurrentReleasePlanReport {
    let report = contractAesCurrentReleasePlan(
        requestedEngine: ContractAesEngineKind.Hardware,
        backendHint: backendHint
    )
    if (!report.primaryBackendAvailable) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "current release primary backend is unavailable: ${report.primaryBackend}"
        )
    }
    if (!report.usingPrimaryBackend) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "current release requires primary backend ${report.primaryBackend}, but selected backend is ${report.startup.selectedEngine.backend}"
        )
    }
    report
}

private func contractFromAesHardwareMountPoint(
    mount: AesHardwareMountPoint
): ContractAesHardwareMountPointInfo {
    ContractAesHardwareMountPointInfo(
        mount.backend,
        mount.available,
        mount.accelerated,
        mount.detected,
        mount.detail
    )
}

private func contractFromAesHardwareProbe(
    probe: AesHardwareProbe
): ContractAesHardwareProbeInfo {
    ContractAesHardwareProbeInfo(
        probe.available,
        probe.backend,
        probe.accelerated,
        probe.detail
    )
}

private func contractFromAesHardwareRoadmapEntry(
    entry: AesHardwareRoadmapEntry
): ContractAesHardwareRoadmapEntry {
    ContractAesHardwareRoadmapEntry(
        entry.architecture,
        entry.backend,
        entry.status,
        entry.targetVersion,
        entry.detail
    )
}

private func contractFromAesEngineKind(kind: AesEngineKind): ContractAesEngineKind {
    match (kind) {
        case AUTO => ContractAesEngineKind.Auto
        case SOFTWARE => ContractAesEngineKind.Software
        case HARDWARE => ContractAesEngineKind.Hardware
    }
}

private func contractToAesEngineKind(kind: ContractAesEngineKind): AesEngineKind {
    match (kind) {
        case ContractAesEngineKind.Auto => AesEngineKind.AUTO
        case ContractAesEngineKind.Software => AesEngineKind.SOFTWARE
        case ContractAesEngineKind.Hardware => AesEngineKind.HARDWARE
    }
}

private func contractFromAesEngine(engine: AesEngine): ContractAesEngineInfo {
    ContractAesEngineInfo(
        contractFromAesEngineKind(engine.requested),
        contractFromAesEngineKind(engine.active),
        engine.backend,
        engine.accelerated,
        engine.detail
    )
}

private func contractToAesNativeBridgeSpec(spec: ContractAesNativeBridgeSpec): AesNativeBridgeSpec {
    AesNativeBridgeSpec(
        spec.backend,
        spec.libraryPath,
        symbolPrefix: spec.symbolPrefix,
        abiVersion: spec.abiVersion
    )
}

private func contractFromAesNativeBridgeContract(
    contract: AesNativeBridgeContract
): ContractAesNativeBridgeContractInfo {
    ContractAesNativeBridgeContractInfo(
        contract.backend,
        contract.abiVersion,
        contract.expandKeySymbol,
        contract.encryptBlocksSymbol,
        contract.decryptBlocksSymbol,
        contract.ghashMulSymbol,
        contract.detail
    )
}

private func contractFromAesNativeBridgeCallShape(
    shape: AesNativeBridgeCallShape
): ContractAesNativeBridgeCallShapeInfo {
    ContractAesNativeBridgeCallShapeInfo(
        shape.backend,
        shape.abiVersion,
        shape.keyBytes,
        shape.roundCount,
        shape.roundKeyWordCount,
        shape.expandedKeyBlobBytes,
        shape.blockBytes,
        shape.requiresBlockAlignedPayload
    )
}

private func contractFindAesMountPoint(
    mounts: Array<ContractAesHardwareMountPointInfo>,
    backend: String
): ?ContractAesHardwareMountPointInfo {
    for (mount in mounts) {
        if (mount.backend == backend) {
            return Some(mount)
        }
    }
    None
}

private func contractFindPrimaryAesRoadmapBackend(
    roadmap: Array<ContractAesHardwareRoadmapEntry>
): String {
    for (entry in roadmap) {
        if (entry.status == "PRIMARY_ACTIVE") {
            return entry.backend
        }
    }
    throw ContractException(
        ContractErrorCode.InternalError,
        "AES roadmap does not define a primary active backend"
    )
}

private func contractCollectAesRoadmapArchitectures(
    roadmap: Array<ContractAesHardwareRoadmapEntry>,
    status: String
): Array<String> {
    let values = ArrayList<String>()
    for (entry in roadmap) {
        if (entry.status == status) {
            values.add(entry.architecture)
        }
    }
    values.toArray()
}

private func contractCollectAesRoadmapBackendsByPrefix(
    roadmap: Array<ContractAesHardwareRoadmapEntry>,
    statusPrefix: String
): Array<String> {
    let values = ArrayList<String>()
    for (entry in roadmap) {
        if (entry.status.startsWith(statusPrefix)) {
            values.add(entry.backend)
        }
    }
    values.toArray()
}

private func contractContainsAesString(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

private func contractMapAesCryptoErrorCode(code: CryptoErrorCode): ContractErrorCode {
    match (code) {
        case InvalidArgument => ContractErrorCode.BadInput
        case OutOfBounds => ContractErrorCode.BadInput
        case ParseError => ContractErrorCode.VerifyFailed
        case ComplianceRejected => ContractErrorCode.ComplianceRejected
        case Unsupported => ContractErrorCode.Unsupported
        case InternalError => ContractErrorCode.InternalError
        case _ => ContractErrorCode.InternalError
    }
}

private func contractMapAesCryptoExceptionToErrorCode(exception: CryptoException): ContractErrorCode {
    contractMapAesCryptoErrorCode(exception.code)
}
