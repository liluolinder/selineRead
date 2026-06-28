package jinguissl_core.crypto.aes

import std.env.getVariable
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.secureCopyInto

public enum AesMode <: Equatable<AesMode> & ToString {
    /** @deprecated ECB mode is not semantically secure. Use GCM or CBC. */
    | ECB
    | CBC
    | CTR
    | GCM

    public operator func ==(right: AesMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: AesMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ECB => 0
            case CBC => 1
            case CTR => 2
            case GCM => 3
        }
    }

    public func toString(): String {
        match (this) {
            case ECB => "AES-ECB"
            case CBC => "AES-CBC"
            case CTR => "AES-CTR"
            case GCM => "AES-GCM"
        }
    }
}

public enum AesEngineKind <: Equatable<AesEngineKind> & ToString {
    | AUTO
    /** @deprecated Software AES is vulnerable to cache-timing side channels. Use HARDWARE when possible. */
    | SOFTWARE
    | HARDWARE

    public operator func ==(right: AesEngineKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: AesEngineKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AUTO => 0
            case SOFTWARE => 1
            case HARDWARE => 2
        }
    }

    public func toString(): String {
        match (this) {
            case AUTO => "AUTO"
            case SOFTWARE => "SOFTWARE"
            case HARDWARE => "HARDWARE"
        }
    }
}

private let GHASH_TABLE_BYTES: Int64 = 16
private let GHASH_TABLE_STRIDE: Int64 = 256
private let GHASH_TABLE_SIZE: Int64 = GHASH_TABLE_BYTES * GHASH_TABLE_STRIDE
private let AES_HW_BACKEND_ENV: String = "JINGUISSL_AES_HW_BACKEND"
private let AES_HW_BACKEND_NONE: String = "none"
private let AES_HW_BACKEND_SHIM: String = "shim"
private let AES_HW_BACKEND_AESNI: String = "aesni"
private let AES_HW_BACKEND_ARMV8_CE: String = "armv8-ce"
private let AES_HW_BACKEND_LOONGARCH64_RESERVED: String = "loongarch64-reserved"
private let AES_HW_BACKEND_RISCV64_RESERVED: String = "riscv64-reserved"
private let AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES: Int64 = 12
private let AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_0: UInt8 = UInt8(0x4a)
private let AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_1: UInt8 = UInt8(0x4b)
private let AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_2: UInt8 = UInt8(0x41)
private let AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_3: UInt8 = UInt8(0x31)
private let AES_NATIVE_BRIDGE_KEY_BLOB_FLAG_RAW_KEY: UInt8 = UInt8(1)
private let CC_STATUS_SUCCESS: Int32 = Int32(0)
private let CC_STATUS_PARAM_ERROR: Int32 = Int32(-4300)
private let CC_STATUS_ALIGNMENT_ERROR: Int32 = Int32(-4303)
private let CC_STATUS_DECODE_ERROR: Int32 = Int32(-4304)
private let CC_STATUS_UNIMPLEMENTED: Int32 = Int32(-4305)
private let CC_STATUS_UNSPECIFIED_ERROR: Int32 = Int32(-4308)
private let CC_STATUS_KEY_SIZE_ERROR: Int32 = Int32(-4310)
private let CC_STATUS_INVALID_KEY: Int32 = Int32(-4311)
private let CC_OPERATION_ENCRYPT: UInt32 = UInt32(0)
private let CC_OPERATION_DECRYPT: UInt32 = UInt32(1)
private let CC_ALGORITHM_AES: UInt32 = UInt32(0)
private let CC_OPTION_ECB_MODE: UInt32 = UInt32(0x0002)

@When[os == "macOS"]
foreign func CCCrypt(
    op: UInt32,
    alg: UInt32,
    options: UInt32,
    key: CPointer<UInt8>,
    keyLength: UIntNative,
    iv: CPointer<UInt8>,
    dataIn: CPointer<UInt8>,
    dataInLength: UIntNative,
    dataOut: CPointer<UInt8>,
    dataOutAvailable: UIntNative,
    dataOutMoved: CPointer<UIntNative>
): Int32

@When[os == "macOS"]
foreign func CCCryptorGCMOneshotEncrypt(
    alg: UInt32,
    key: CPointer<UInt8>,
    keyLength: UIntNative,
    iv: CPointer<UInt8>,
    ivLen: UIntNative,
    aad: CPointer<UInt8>,
    aadLen: UIntNative,
    dataIn: CPointer<UInt8>,
    dataInLength: UIntNative,
    dataOut: CPointer<UInt8>,
    tagOut: CPointer<UInt8>,
    tagLength: UIntNative
): Int32

@When[os == "macOS"]
foreign func CCCryptorGCMOneshotDecrypt(
    alg: UInt32,
    key: CPointer<UInt8>,
    keyLength: UIntNative,
    iv: CPointer<UInt8>,
    ivLen: UIntNative,
    aad: CPointer<UInt8>,
    aadLen: UIntNative,
    dataIn: CPointer<UInt8>,
    dataInLength: UIntNative,
    dataOut: CPointer<UInt8>,
    tagIn: CPointer<UInt8>,
    tagLength: UIntNative
): Int32

public class AesHardwareMountPoint {
    public let backend: String
    public let available: Bool
    public let accelerated: Bool
    public let detected: Bool
    public let detail: String

    public init(backend: String, available: Bool, accelerated: Bool, detected: Bool, detail: String) {
        this.backend = backend
        this.available = available
        this.accelerated = accelerated
        this.detected = detected
        this.detail = detail
    }
}

public class AesHardwareRoadmapEntry {
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
        this.architecture = architecture
        this.backend = backend
        this.status = status
        this.targetVersion = targetVersion
        this.detail = detail
    }
}

public class AesNativeBridgeSpec {
    public let backend: String
    public let libraryPath: String
    public let symbolPrefix: String
    public let abiVersion: Int64

    public init(
        backend: String,
        libraryPath: String,
        symbolPrefix!: String = "jinguissl_aes",
        abiVersion!: Int64 = 1
    ) {
        let normalizedBackend = normalizeAesBridgeBackend(backend)
        if (!isValidAesBridgeBackend(normalizedBackend)) {
            throw CryptoException(InvalidArgument, "unsupported AES native bridge backend: ${backend}")
        }
        let normalizedLibraryPath = libraryPath.trimAscii()
        if (backendRequiresExternalLibrary(normalizedBackend) && normalizedLibraryPath.size == 0) {
            throw CryptoException(InvalidArgument, "native bridge library path must not be empty")
        }
        let normalizedSymbolPrefix = symbolPrefix.trimAscii()
        if (normalizedSymbolPrefix.size == 0) {
            throw CryptoException(InvalidArgument, "native bridge symbol prefix must not be empty")
        }
        if (abiVersion <= 0) {
            throw CryptoException(InvalidArgument, "native bridge ABI version must be positive")
        }
        this.backend = normalizedBackend
        this.libraryPath = normalizedLibraryPath
        this.symbolPrefix = normalizedSymbolPrefix
        this.abiVersion = abiVersion
    }
}

public class AesNativeBridgeContract {
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
        this.backend = backend
        this.abiVersion = abiVersion
        this.expandKeySymbol = expandKeySymbol
        this.encryptBlocksSymbol = encryptBlocksSymbol
        this.decryptBlocksSymbol = decryptBlocksSymbol
        this.ghashMulSymbol = ghashMulSymbol
        this.detail = detail
    }
}

public class AesNativeBridgeCallShape {
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
        this.backend = backend
        this.abiVersion = abiVersion
        this.keyBytes = keyBytes
        this.roundCount = roundCount
        this.roundKeyWordCount = roundKeyWordCount
        this.expandedKeyBlobBytes = expandedKeyBlobBytes
        this.blockBytes = blockBytes
        this.requiresBlockAlignedPayload = requiresBlockAlignedPayload
    }
}

public class AesNativeBridgeHandle {
    public let spec: AesNativeBridgeSpec
    public let contract: AesNativeBridgeContract
    public let probe: AesHardwareProbe

    public init(spec: AesNativeBridgeSpec) {
        this.spec = spec
        this.contract = aesBuildNativeBridgeContract(spec)
        this.probe = aesProbeHardwareWithNativeBridge(spec)
    }
}

public class AesHardwareProbe {
    public let available: Bool
    public let backend: String
    public let accelerated: Bool
    public let detail: String

    public init(available: Bool, backend: String, accelerated: Bool, detail: String) {
        this.available = available
        this.backend = backend
        this.accelerated = accelerated
        this.detail = detail
    }
}

public class AesEngine {
    public let requested: AesEngineKind
    public let active: AesEngineKind
    public let backend: String
    public let accelerated: Bool
    public let detail: String

    public init(requested!: AesEngineKind = AUTO, hardwareHint!: String = "") {
        this.requested = requested
        let probe = aesProbeHardware(backendHint: hardwareHint)
        this.active = resolveAesEngineKind(requested, probe)
        this.backend = probe.backend
        this.accelerated = probe.accelerated
        this.detail = probe.detail
    }
}

public class AesKeySchedule {
    public let engine: AesEngine
    public let key: Array<Byte>
    public let roundKeys: Array<UInt32>
    public let nr: Int64

    public init(key: Array<Byte>, requestedEngine!: AesEngineKind = AUTO, hardwareHint!: String = "") {
        this.engine = aesResolveEngine(requested: requestedEngine, hardwareHint: hardwareHint)
        this.key = key.clone()
        let (words, rounds) = expandRoundKeys(key)
        this.roundKeys = words
        this.nr = rounds
    }
}

public class AesGcmContext {
    public let schedule: AesKeySchedule
    public let engine: AesEngine
    public let hashSubkey: Array<Byte>
    public let hashSubkeyHi: UInt64
    public let hashSubkeyLo: UInt64
    public let ghashTableHi: Array<UInt64>
    public let ghashTableLo: Array<UInt64>

    public init(key: Array<Byte>, requestedEngine!: AesEngineKind = AUTO, hardwareHint!: String = "") {
        let schedule = AesKeySchedule(key, requestedEngine: requestedEngine, hardwareHint: hardwareHint)
        this.schedule = schedule
        this.engine = schedule.engine
        this.hashSubkey = encryptBlockWithSchedule(zeroBlock(), schedule.roundKeys, schedule.nr)
        let (hHi, hLo) = readU64PairBE(this.hashSubkey)
        this.hashSubkeyHi = hHi
        this.hashSubkeyLo = hLo
        let (tableHi, tableLo) = buildGhashTable(hHi, hLo)
        this.ghashTableHi = tableHi
        this.ghashTableLo = tableLo
    }

    public init(schedule: AesKeySchedule) {
        this.schedule = schedule
        this.engine = schedule.engine
        this.hashSubkey = encryptBlockWithSchedule(zeroBlock(), schedule.roundKeys, schedule.nr)
        let (hHi, hLo) = readU64PairBE(this.hashSubkey)
        this.hashSubkeyHi = hHi
        this.hashSubkeyLo = hLo
        let (tableHi, tableLo) = buildGhashTable(hHi, hLo)
        this.ghashTableHi = tableHi
        this.ghashTableLo = tableLo
    }
}

public func aesProbeHardware(backendHint!: String = ""): AesHardwareProbe {
    let source = normalizeAesBridgeBackend(resolveAesHardwareBackendHint(backendHint))
    if (source.size == 0 || source == "off" || source == AES_HW_BACKEND_NONE || source == "software") {
        return AesHardwareProbe(
            false,
            AES_HW_BACKEND_NONE,
            false,
            "AES hardware backend is disabled (set ${AES_HW_BACKEND_ENV}=armv8-ce for native backend)"
        )
    }
    if (source == AES_HW_BACKEND_SHIM || source == "software-shim" || source == "armv8-shim") {
        return AesHardwareProbe(
            true,
            AES_HW_BACKEND_SHIM,
            false,
            "AES hardware shim backend is enabled; crypto core remains software"
        )
    }
    if (source == "aesni-shim") {
        return AesHardwareProbe(
            true,
            AES_HW_BACKEND_AESNI,
            false,
            "AES-NI native bridge shim is selected; backend dispatch path is active and crypto core remains software"
        )
    }
    if (source == "armv8-ce-shim") {
        return AesHardwareProbe(
            true,
            AES_HW_BACKEND_ARMV8_CE,
            false,
            "ARMv8 CE native bridge shim is selected; backend dispatch path is active and crypto core remains software"
        )
    }
    if (source == AES_HW_BACKEND_AESNI || source == "x86-aesni" || source == "aes-ni") {
        return AesHardwareProbe(
            false,
            AES_HW_BACKEND_NONE,
            false,
            "AES-NI mount point is recognized but native backend is not wired yet; use ${AES_HW_BACKEND_ENV}=aesni-shim for integration tests"
        )
    }
    if (source == AES_HW_BACKEND_ARMV8_CE || source == "armv8" || source == "armv8ce") {
        if (aesArmv8CeBackendReady()) {
            return AesHardwareProbe(
                true,
                AES_HW_BACKEND_ARMV8_CE,
                true,
                "ARMv8 CE backend is active via CommonCrypto native bridge"
            )
        }
        return AesHardwareProbe(false, AES_HW_BACKEND_NONE, false, "ARMv8 CE backend is unavailable on current runtime")
    }
    if (source == AES_HW_BACKEND_LOONGARCH64_RESERVED) {
        return AesHardwareProbe(
            false,
            AES_HW_BACKEND_LOONGARCH64_RESERVED,
            false,
            "LoongArch64 AES backend is reserved as a future skeleton and is not implemented in 0.6"
        )
    }
    if (source == AES_HW_BACKEND_RISCV64_RESERVED) {
        return AesHardwareProbe(
            false,
            AES_HW_BACKEND_RISCV64_RESERVED,
            false,
            "RISC-V64 AES backend is reserved as a future skeleton and is not implemented in 0.6"
        )
    }
    AesHardwareProbe(false, AES_HW_BACKEND_NONE, false, "unsupported AES hardware backend hint: ${source}")
}

public func aesBuildNativeBridgeContract(spec: AesNativeBridgeSpec): AesNativeBridgeContract {
    let prefix = spec.symbolPrefix
    AesNativeBridgeContract(
        spec.backend,
        spec.abiVersion,
        "${prefix}_expand_key",
        "${prefix}_encrypt_blocks",
        "${prefix}_decrypt_blocks",
        "${prefix}_ghash_mul",
        "ABI v${spec.abiVersion}: expand key + block batch + ghash-mul entry points"
    )
}

public func aesProbeHardwareWithNativeBridge(spec: AesNativeBridgeSpec): AesHardwareProbe {
    let hint = nativeBridgeBackendHint(spec.backend)
    aesProbeHardware(backendHint: hint)
}

public func aesResolveEngineWithNativeBridge(
    spec: AesNativeBridgeSpec,
    requested!: AesEngineKind = AUTO
): AesEngine {
    let hint = nativeBridgeBackendHint(spec.backend)
    aesResolveEngine(requested: requested, hardwareHint: hint)
}

public func aesOpenNativeBridge(spec: AesNativeBridgeSpec): AesNativeBridgeHandle {
    AesNativeBridgeHandle(spec)
}

public func aesNativeBridgeDescribeCallShape(
    handle: AesNativeBridgeHandle,
    keyBytes: Int64
): AesNativeBridgeCallShape {
    let rounds = expectedRoundsFromAesKeyBytes(keyBytes)
    let words = 4 * (rounds + 1)
    let blobBytes = if (handle.probe.accelerated && handle.spec.backend == AES_HW_BACKEND_ARMV8_CE) {
        AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + keyBytes
    } else {
        AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + words * 4
    }
    AesNativeBridgeCallShape(
        handle.spec.backend,
        handle.contract.abiVersion,
        keyBytes,
        rounds,
        words,
        blobBytes,
        AES_BLOCK_SIZE,
        true
    )
}

public func aesNativeBridgeExpandKey(handle: AesNativeBridgeHandle, key: Array<Byte>): Array<Byte> {
    if (handle.probe.accelerated && handle.spec.backend == AES_HW_BACKEND_ARMV8_CE) {
        return encodeNativeBridgeRawKeyBlob(handle.contract, key)
    }
    let (roundKeys, nr) = expandRoundKeys(key)
    encodeNativeBridgeExpandedKeyBlob(handle.contract, key.size, roundKeys, nr)
}

/**
 * aesNativeBridgeEncryptBlocks.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesNativeBridgeEncryptBlocks(
    handle: AesNativeBridgeHandle,
    expandedKeyBlob: Array<Byte>,
    plaintextBlocks: Array<Byte>
): Array<Byte> {
    if ((plaintextBlocks.size % AES_BLOCK_SIZE) != 0) {
        throw CryptoException(InvalidArgument, "native bridge encrypt input must be block aligned")
    }
    if (handle.probe.accelerated && handle.spec.backend == AES_HW_BACKEND_ARMV8_CE) {
        let key = decodeNativeBridgeRawKeyBlob(handle.contract, expandedKeyBlob)
        return aesArmv8CeCryptBlocks(key, plaintextBlocks, false)
    }
    let (roundKeys, nr) = decodeNativeBridgeExpandedKeyBlob(handle.contract, expandedKeyBlob)
    cryptBlocksWithSchedule(roundKeys, nr, plaintextBlocks, decrypt: false)
}

/**
 * aesNativeBridgeDecryptBlocks.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesNativeBridgeDecryptBlocks(
    handle: AesNativeBridgeHandle,
    expandedKeyBlob: Array<Byte>,
    ciphertextBlocks: Array<Byte>
): Array<Byte> {
    if ((ciphertextBlocks.size % AES_BLOCK_SIZE) != 0) {
        throw CryptoException(InvalidArgument, "native bridge decrypt input must be block aligned")
    }
    if (handle.probe.accelerated && handle.spec.backend == AES_HW_BACKEND_ARMV8_CE) {
        let key = decodeNativeBridgeRawKeyBlob(handle.contract, expandedKeyBlob)
        return aesArmv8CeCryptBlocks(key, ciphertextBlocks, true)
    }
    let (roundKeys, nr) = decodeNativeBridgeExpandedKeyBlob(handle.contract, expandedKeyBlob)
    cryptBlocksWithSchedule(roundKeys, nr, ciphertextBlocks, decrypt: true)
}

/**
 * aesNativeBridgeGhashMul.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesNativeBridgeGhashMul(
    handle: AesNativeBridgeHandle,
    hashSubkey: Array<Byte>,
    value: Array<Byte>
): Array<Byte> {
    if (handle.contract.abiVersion <= 0) {
        throw CryptoException(InternalError, "invalid native bridge contract ABI version")
    }
    requireBlock(hashSubkey, "native bridge GHASH key")
    requireBlock(value, "native bridge GHASH input")
    let out = value.clone()
    gfMul128InPlace(out, hashSubkey)
    out
}

public func aesListHardwareMountPoints(): Array<AesHardwareMountPoint> {
    let armv8Ready = aesArmv8CeBackendReady()
    [
        AesHardwareMountPoint(
            AES_HW_BACKEND_AESNI,
            false,
            false,
            false,
            "placeholder mount point reserved for x86_64 backend wiring; deferred to 0.7"
        ),
        AesHardwareMountPoint(
            AES_HW_BACKEND_ARMV8_CE,
            armv8Ready,
            armv8Ready,
            armv8Ready,
            if (armv8Ready) {
                "ARMv8 CE backend active via CommonCrypto native bridge; current 0.6 priority path"
            } else {
                "ARMv8 CE backend unavailable on current runtime; current 0.6 priority path"
            }
        ),
        AesHardwareMountPoint(
            AES_HW_BACKEND_SHIM,
            true,
            false,
            true,
            "software shim mount point for Stage6.2 backend integration testing"
        ),
        AesHardwareMountPoint(
            AES_HW_BACKEND_LOONGARCH64_RESERVED,
            false,
            false,
            false,
            "reserved skeleton mount point for future LoongArch64 backend design"
        ),
        AesHardwareMountPoint(
            AES_HW_BACKEND_RISCV64_RESERVED,
            false,
            false,
            false,
            "reserved skeleton mount point for future RISC-V64 backend design"
        )
    ]
}

public func aesHardwareRoadmap(): Array<AesHardwareRoadmapEntry> {
    [
        AesHardwareRoadmapEntry(
            "aarch64",
            AES_HW_BACKEND_ARMV8_CE,
            "PRIMARY_ACTIVE",
            "0.6",
            "current priority path for real hardware-backed AES delivery"
        ),
        AesHardwareRoadmapEntry(
            "x86_64",
            AES_HW_BACKEND_AESNI,
            "DEFERRED_0_7",
            "0.7",
            "reserved mount point exists, but native AES-NI wiring is intentionally deferred"
        ),
        AesHardwareRoadmapEntry(
            "loongarch64",
            AES_HW_BACKEND_LOONGARCH64_RESERVED,
            "RESERVED_SKELETON",
            "post-0.7",
            "skeleton reserved for future backend design without active wiring in 0.6"
        ),
        AesHardwareRoadmapEntry(
            "riscv64",
            AES_HW_BACKEND_RISCV64_RESERVED,
            "RESERVED_SKELETON",
            "post-0.7",
            "skeleton reserved for future backend design without active wiring in 0.6"
        )
    ]
}

public func aesDefaultHardwareBackendHint(): String {
    resolveAesHardwareBackendHint("")
}

public func aesResolveEngine(requested!: AesEngineKind = AUTO, hardwareHint!: String = ""): AesEngine {
    AesEngine(requested: requested, hardwareHint: hardwareHint)
}

public func aesCurrentEngineKind(requested!: AesEngineKind = AUTO, hardwareHint!: String = ""): AesEngineKind {
    aesResolveEngine(requested: requested, hardwareHint: hardwareHint).active
}

public func aesHardwareAvailable(hardwareHint!: String = ""): Bool {
    aesProbeHardware(backendHint: hardwareHint).available
}

public func aesPrepareKey(
    key: Array<Byte>,
    requestedEngine!: AesEngineKind = AUTO,
    hardwareHint!: String = ""
): AesKeySchedule {
    AesKeySchedule(key, requestedEngine: requestedEngine, hardwareHint: hardwareHint)
}

public func aesNewGcmContext(
    key: Array<Byte>,
    requestedEngine!: AesEngineKind = AUTO,
    hardwareHint!: String = ""
): AesGcmContext {
    AesGcmContext(key, requestedEngine: requestedEngine, hardwareHint: hardwareHint)
}

public func aesAlgorithmName(mode: AesMode): String {
    mode.toString()
}

public func requireAesAllowed(profile: FipsProfile, mode: AesMode): Unit {
    profile.requireAllowed(aesAlgorithmName(mode))
}

private func normalizeAesBridgeBackend(name: String): String {
    let normalized = name.trimAscii().toAsciiLower()
    if (normalized == "x86-aesni" || normalized == "aes-ni") {
        return AES_HW_BACKEND_AESNI
    }
    if (normalized == "armv8" || normalized == "armv8ce") {
        return AES_HW_BACKEND_ARMV8_CE
    }
    if (normalized == "software-shim" || normalized == "armv8-shim") {
        return AES_HW_BACKEND_SHIM
    }
    if (normalized == "loongarch64" || normalized == "loongarch" || normalized == "la64") {
        return AES_HW_BACKEND_LOONGARCH64_RESERVED
    }
    if (normalized == "riscv64" || normalized == "riscv" || normalized == "rv64") {
        return AES_HW_BACKEND_RISCV64_RESERVED
    }
    normalized
}

private func isValidAesBridgeBackend(backend: String): Bool {
    backend == AES_HW_BACKEND_AESNI || backend == AES_HW_BACKEND_ARMV8_CE || backend == AES_HW_BACKEND_SHIM
}

private func backendRequiresExternalLibrary(backend: String): Bool {
    let normalized = normalizeAesBridgeBackend(backend)
    normalized == AES_HW_BACKEND_AESNI
}

private func nativeBridgeBackendHint(backend: String): String {
    let normalized = normalizeAesBridgeBackend(backend)
    if (normalized == AES_HW_BACKEND_AESNI) {
        return "aesni-shim"
    }
    if (normalized == AES_HW_BACKEND_ARMV8_CE) {
        return AES_HW_BACKEND_ARMV8_CE
    }
    if (normalized == AES_HW_BACKEND_SHIM) {
        return AES_HW_BACKEND_SHIM
    }
    AES_HW_BACKEND_NONE
}

private func resolveAesEngineKind(requested: AesEngineKind, probe: AesHardwareProbe): AesEngineKind {
    match (requested) {
        case AUTO =>
            if (probe.available) {
                HARDWARE
            } else {
                SOFTWARE
            }
        case SOFTWARE => SOFTWARE
        case HARDWARE =>
            if (!probe.available) {
                throw CryptoException(Unsupported, probe.detail)
            }
            HARDWARE
    }
}

private func resolveAesHardwareBackendHint(backendHint: String): String {
    let trimmedHint = backendHint.trimAscii().toAsciiLower()
    if (trimmedHint.size > 0) {
        return trimmedHint
    }
    let envHint = (getVariable(AES_HW_BACKEND_ENV) ?? "").trimAscii().toAsciiLower()
    if (envHint.size > 0) {
        return envHint
    }
    resolveAutomaticAesHardwareBackendHint()
}

@When[os == "macOS" && arch == "aarch64"]
private func resolveAutomaticAesHardwareBackendHint(): String {
    AES_HW_BACKEND_ARMV8_CE
}

@When[os != "macOS" || arch != "aarch64"]
private func resolveAutomaticAesHardwareBackendHint(): String {
    ""
}

private func aesArmv8CeBackendReady(): Bool {
    let key = Array<Byte>(16, repeat: 0)
    let iv = Array<Byte>(12, repeat: 0)
    let input = Array<Byte>(16, repeat: 0)
    let output = Array<Byte>(16, repeat: 0)
    let tag = Array<Byte>(16, repeat: 0)
    aesArmv8CeGcmEncryptRaw(key, iv, [], input, output, tag) == CC_STATUS_SUCCESS
}

private func aesUseNativeArmv8Ce(engine: AesEngine): Bool {
    engine.active == HARDWARE && engine.backend == AES_HW_BACKEND_ARMV8_CE && engine.accelerated
}

private func throwCommonCryptoFailure(operation: String, status: Int32): Unit {
    if (
        status == CC_STATUS_DECODE_ERROR ||
        status == CC_STATUS_ALIGNMENT_ERROR ||
        status == CC_STATUS_UNSPECIFIED_ERROR
    ) {
        throw CryptoException(InvalidArgument, "${operation} failed: authentication tag mismatch")
    }
    if (
        status == CC_STATUS_PARAM_ERROR ||
        status == CC_STATUS_KEY_SIZE_ERROR ||
        status == CC_STATUS_INVALID_KEY
    ) {
        throw CryptoException(InvalidArgument, "${operation} failed with CommonCrypto status ${status}")
    }
    if (status == CC_STATUS_UNIMPLEMENTED) {
        throw CryptoException(Unsupported, "${operation} is unavailable on current runtime")
    }
    throw CryptoException(InternalError, "${operation} failed with CommonCrypto status ${status}")
}

public unsafe func aesArmv8CeGcmEncryptPointers(
    key: CPointer<UInt8>,
    keyLength: Int64,
    iv: CPointer<UInt8>,
    ivLength: Int64,
    aad: CPointer<UInt8>,
    aadLength: Int64,
    input: CPointer<UInt8>,
    inputLength: Int64,
    output: CPointer<UInt8>,
    tag: CPointer<UInt8>,
    tagLength: Int64
): Int32 {
    if (key.isNull() || iv.isNull() || output.isNull() || tag.isNull()) {
        return CC_STATUS_PARAM_ERROR
    }
    if (inputLength > 0 && input.isNull()) {
        return CC_STATUS_PARAM_ERROR
    }
    if (aadLength > 0 && aad.isNull()) {
        return CC_STATUS_PARAM_ERROR
    }
    if (inputLength < 0 || aadLength < 0 || ivLength <= 0 || tagLength <= 0 || tagLength > 16) {
        return CC_STATUS_PARAM_ERROR
    }
    _ = expectedNkFromAesKeyBytes(keyLength)
    aesArmv8CeGcmEncryptRawPointers(key, keyLength, iv, ivLength, aad, aadLength, input, inputLength, output, tag, tagLength)
}

public unsafe func aesArmv8CeGcmDecryptPointers(
    key: CPointer<UInt8>,
    keyLength: Int64,
    iv: CPointer<UInt8>,
    ivLength: Int64,
    aad: CPointer<UInt8>,
    aadLength: Int64,
    input: CPointer<UInt8>,
    inputLength: Int64,
    tag: CPointer<UInt8>,
    tagLength: Int64,
    output: CPointer<UInt8>
): Int32 {
    if (key.isNull() || iv.isNull() || output.isNull() || tag.isNull()) {
        return CC_STATUS_PARAM_ERROR
    }
    if (inputLength > 0 && input.isNull()) {
        return CC_STATUS_PARAM_ERROR
    }
    if (aadLength > 0 && aad.isNull()) {
        return CC_STATUS_PARAM_ERROR
    }
    if (inputLength < 0 || aadLength < 0 || ivLength <= 0 || tagLength <= 0 || tagLength > 16) {
        return CC_STATUS_PARAM_ERROR
    }
    _ = expectedNkFromAesKeyBytes(keyLength)
    aesArmv8CeGcmDecryptRawPointers(key, keyLength, iv, ivLength, aad, aadLength, input, inputLength, tag, tagLength, output)
}

@When[os == "macOS"]
private unsafe func aesArmv8CeGcmEncryptRawPointers(
    key: CPointer<UInt8>,
    keyLength: Int64,
    iv: CPointer<UInt8>,
    ivLength: Int64,
    aad: CPointer<UInt8>,
    aadLength: Int64,
    input: CPointer<UInt8>,
    inputLength: Int64,
    output: CPointer<UInt8>,
    tag: CPointer<UInt8>,
    tagLength: Int64
): Int32 {
    CCCryptorGCMOneshotEncrypt(
        CC_ALGORITHM_AES,
        key,
        UIntNative(keyLength),
        iv,
        UIntNative(ivLength),
        aad,
        UIntNative(aadLength),
        input,
        UIntNative(inputLength),
        output,
        tag,
        UIntNative(tagLength)
    )
}

@When[os != "macOS"]
private unsafe func aesArmv8CeGcmEncryptRawPointers(
    key: CPointer<UInt8>,
    keyLength: Int64,
    iv: CPointer<UInt8>,
    ivLength: Int64,
    aad: CPointer<UInt8>,
    aadLength: Int64,
    input: CPointer<UInt8>,
    inputLength: Int64,
    output: CPointer<UInt8>,
    tag: CPointer<UInt8>,
    tagLength: Int64
): Int32 {
    let _ = key
    let _ = keyLength
    let _ = iv
    let _ = ivLength
    let _ = aad
    let _ = aadLength
    let _ = input
    let _ = inputLength
    let _ = output
    let _ = tag
    let _ = tagLength
    CC_STATUS_UNIMPLEMENTED
}

@When[os == "macOS"]
private unsafe func aesArmv8CeGcmDecryptRawPointers(
    key: CPointer<UInt8>,
    keyLength: Int64,
    iv: CPointer<UInt8>,
    ivLength: Int64,
    aad: CPointer<UInt8>,
    aadLength: Int64,
    input: CPointer<UInt8>,
    inputLength: Int64,
    tag: CPointer<UInt8>,
    tagLength: Int64,
    output: CPointer<UInt8>
): Int32 {
    CCCryptorGCMOneshotDecrypt(
        CC_ALGORITHM_AES,
        key,
        UIntNative(keyLength),
        iv,
        UIntNative(ivLength),
        aad,
        UIntNative(aadLength),
        input,
        UIntNative(inputLength),
        output,
        tag,
        UIntNative(tagLength)
    )
}

@When[os != "macOS"]
private unsafe func aesArmv8CeGcmDecryptRawPointers(
    key: CPointer<UInt8>,
    keyLength: Int64,
    iv: CPointer<UInt8>,
    ivLength: Int64,
    aad: CPointer<UInt8>,
    aadLength: Int64,
    input: CPointer<UInt8>,
    inputLength: Int64,
    tag: CPointer<UInt8>,
    tagLength: Int64,
    output: CPointer<UInt8>
): Int32 {
    let _ = key
    let _ = keyLength
    let _ = iv
    let _ = ivLength
    let _ = aad
    let _ = aadLength
    let _ = input
    let _ = inputLength
    let _ = tag
    let _ = tagLength
    let _ = output
    CC_STATUS_UNIMPLEMENTED
}

private func aesGcmEncryptWithArmv8Ce(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad: Array<Byte>,
    tagLen: Int64
): (Array<Byte>, Array<Byte>) {
    let ciphertext = Array<Byte>(plaintext.size, repeat: 0)
    let tag = Array<Byte>(tagLen, repeat: 0)
    let status = aesArmv8CeGcmEncryptRaw(ctx.schedule.key, iv, aad, plaintext, ciphertext, tag)
    if (status != CC_STATUS_SUCCESS) {
        throwCommonCryptoFailure("AES-GCM native encrypt", status)
    }
    (ciphertext, tag)
}

private func aesGcmDecryptWithArmv8Ce(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad: Array<Byte>
): Array<Byte> {
    let plaintext = Array<Byte>(ciphertext.size, repeat: 0)
    let status = aesArmv8CeGcmDecryptRaw(ctx.schedule.key, iv, aad, ciphertext, tag, plaintext)
    if (status != CC_STATUS_SUCCESS) {
        throwCommonCryptoFailure("AES-GCM native decrypt", status)
    }
    plaintext
}

private func aesGcmEncryptIntoWithArmv8Ce(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad: Array<Byte>,
    ciphertextOut: Array<Byte>,
    tagOut: Array<Byte>,
    tagLen: Int64
): Unit {
    if (ciphertextOut.size != plaintext.size) {
        throw CryptoException(InvalidArgument, "AES-GCM output length mismatch")
    }
    if (tagOut.size < tagLen) {
        throw CryptoException(InvalidArgument, "AES-GCM tag output is too short")
    }
    unsafe {
        var keyRaw = acquireArrayRawData<Byte>(ctx.schedule.key)
        var ivRaw = acquireArrayRawData<Byte>(iv)
        var aadRaw = acquireArrayRawData<Byte>(aad)
        var inputRaw = acquireArrayRawData<Byte>(plaintext)
        var outputRaw = acquireArrayRawData<Byte>(ciphertextOut)
        var tagRaw = acquireArrayRawData<Byte>(tagOut)
        try {
            let status = aesArmv8CeGcmEncryptPointers(
                keyRaw.pointer,
                ctx.schedule.key.size,
                ivRaw.pointer,
                iv.size,
                aadRaw.pointer,
                aad.size,
                inputRaw.pointer,
                plaintext.size,
                outputRaw.pointer,
                tagRaw.pointer,
                tagLen
            )
            if (status != CC_STATUS_SUCCESS) {
                throwCommonCryptoFailure("AES-GCM native encrypt", status)
            }
        } finally {
            releaseArrayRawData<Byte>(tagRaw)
            releaseArrayRawData<Byte>(outputRaw)
            releaseArrayRawData<Byte>(inputRaw)
            releaseArrayRawData<Byte>(aadRaw)
            releaseArrayRawData<Byte>(ivRaw)
            releaseArrayRawData<Byte>(keyRaw)
        }
    }
}

private func aesGcmDecryptIntoWithArmv8Ce(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad: Array<Byte>,
    plaintextOut: Array<Byte>
): Unit {
    if (plaintextOut.size != ciphertext.size) {
        throw CryptoException(InvalidArgument, "AES-GCM output length mismatch")
    }
    unsafe {
        var keyRaw = acquireArrayRawData<Byte>(ctx.schedule.key)
        var ivRaw = acquireArrayRawData<Byte>(iv)
        var aadRaw = acquireArrayRawData<Byte>(aad)
        var inputRaw = acquireArrayRawData<Byte>(ciphertext)
        var outputRaw = acquireArrayRawData<Byte>(plaintextOut)
        var tagRaw = acquireArrayRawData<Byte>(tag)
        try {
            let status = aesArmv8CeGcmDecryptPointers(
                keyRaw.pointer,
                ctx.schedule.key.size,
                ivRaw.pointer,
                iv.size,
                aadRaw.pointer,
                aad.size,
                inputRaw.pointer,
                ciphertext.size,
                tagRaw.pointer,
                tag.size,
                outputRaw.pointer
            )
            if (status != CC_STATUS_SUCCESS) {
                throwCommonCryptoFailure("AES-GCM native decrypt", status)
            }
        } finally {
            releaseArrayRawData<Byte>(tagRaw)
            releaseArrayRawData<Byte>(outputRaw)
            releaseArrayRawData<Byte>(inputRaw)
            releaseArrayRawData<Byte>(aadRaw)
            releaseArrayRawData<Byte>(ivRaw)
            releaseArrayRawData<Byte>(keyRaw)
        }
    }
}

private func aesArmv8CeCryptBlocks(
    key: Array<Byte>,
    input: Array<Byte>,
    decrypt: Bool
): Array<Byte> {
    let output = Array<Byte>(input.size, repeat: 0)
    let status = aesArmv8CeEcbCryptRaw(key, input, output, decrypt)
    if (status != CC_STATUS_SUCCESS) {
        throwCommonCryptoFailure(
            if (decrypt) {
                "AES-ECB native decrypt"
            } else {
                "AES-ECB native encrypt"
            },
            status
        )
    }
    output
}

@When[os == "macOS"]
private func aesArmv8CeGcmEncryptRaw(
    key: Array<Byte>,
    iv: Array<Byte>,
    aad: Array<Byte>,
    input: Array<Byte>,
    output: Array<Byte>,
    tag: Array<Byte>
): Int32 {
    if (input.size != output.size) {
        throw CryptoException(InvalidArgument, "AES-GCM native output length mismatch")
    }
    _ = expectedNkFromAesKeyBytes(key.size)
    unsafe {
        var keyRaw = acquireArrayRawData<Byte>(key)
        var ivRaw = acquireArrayRawData<Byte>(iv)
        var aadRaw = acquireArrayRawData<Byte>(aad)
        var inputRaw = acquireArrayRawData<Byte>(input)
        var outputRaw = acquireArrayRawData<Byte>(output)
        var tagRaw = acquireArrayRawData<Byte>(tag)
        try {
            return aesArmv8CeGcmEncryptPointers(
                keyRaw.pointer,
                key.size,
                ivRaw.pointer,
                iv.size,
                aadRaw.pointer,
                aad.size,
                inputRaw.pointer,
                input.size,
                outputRaw.pointer,
                tagRaw.pointer,
                tag.size
            )
        } finally {
            releaseArrayRawData<Byte>(tagRaw)
            releaseArrayRawData<Byte>(outputRaw)
            releaseArrayRawData<Byte>(inputRaw)
            releaseArrayRawData<Byte>(aadRaw)
            releaseArrayRawData<Byte>(ivRaw)
            releaseArrayRawData<Byte>(keyRaw)
        }
    }
}

@When[os != "macOS"]
private func aesArmv8CeGcmEncryptRaw(
    key: Array<Byte>,
    iv: Array<Byte>,
    aad: Array<Byte>,
    input: Array<Byte>,
    output: Array<Byte>,
    tag: Array<Byte>
): Int32 {
    let _ = key
    let _ = iv
    let _ = aad
    let _ = input
    let _ = output
    let _ = tag
    CC_STATUS_UNIMPLEMENTED
}

@When[os == "macOS"]
private func aesArmv8CeGcmDecryptRaw(
    key: Array<Byte>,
    iv: Array<Byte>,
    aad: Array<Byte>,
    input: Array<Byte>,
    tag: Array<Byte>,
    output: Array<Byte>
): Int32 {
    if (input.size != output.size) {
        throw CryptoException(InvalidArgument, "AES-GCM native output length mismatch")
    }
    _ = expectedNkFromAesKeyBytes(key.size)
    unsafe {
        var keyRaw = acquireArrayRawData<Byte>(key)
        var ivRaw = acquireArrayRawData<Byte>(iv)
        var aadRaw = acquireArrayRawData<Byte>(aad)
        var inputRaw = acquireArrayRawData<Byte>(input)
        var outputRaw = acquireArrayRawData<Byte>(output)
        var tagRaw = acquireArrayRawData<Byte>(tag)
        try {
            return aesArmv8CeGcmDecryptPointers(
                keyRaw.pointer,
                key.size,
                ivRaw.pointer,
                iv.size,
                aadRaw.pointer,
                aad.size,
                inputRaw.pointer,
                input.size,
                tagRaw.pointer,
                tag.size,
                outputRaw.pointer
            )
        } finally {
            releaseArrayRawData<Byte>(tagRaw)
            releaseArrayRawData<Byte>(outputRaw)
            releaseArrayRawData<Byte>(inputRaw)
            releaseArrayRawData<Byte>(aadRaw)
            releaseArrayRawData<Byte>(ivRaw)
            releaseArrayRawData<Byte>(keyRaw)
        }
    }
}

@When[os != "macOS"]
private func aesArmv8CeGcmDecryptRaw(
    key: Array<Byte>,
    iv: Array<Byte>,
    aad: Array<Byte>,
    input: Array<Byte>,
    tag: Array<Byte>,
    output: Array<Byte>
): Int32 {
    let _ = key
    let _ = iv
    let _ = aad
    let _ = input
    let _ = tag
    let _ = output
    CC_STATUS_UNIMPLEMENTED
}

@When[os == "macOS"]
private func aesArmv8CeEcbCryptRaw(
    key: Array<Byte>,
    input: Array<Byte>,
    output: Array<Byte>,
    decrypt: Bool
): Int32 {
    if (input.size != output.size) {
        throw CryptoException(InvalidArgument, "AES-ECB native output length mismatch")
    }
    if ((input.size % AES_BLOCK_SIZE) != 0) {
        throw CryptoException(InvalidArgument, "AES-ECB native input must be block aligned")
    }
    _ = expectedNkFromAesKeyBytes(key.size)
    unsafe {
        let moved = LibC.malloc<UIntNative>(count: 1)
        if (moved.isNull()) {
            throw CryptoException(InternalError, "AES-ECB native call failed due to memory allocation error")
        }

        var keyRaw = acquireArrayRawData<Byte>(key)
        var inputRaw = acquireArrayRawData<Byte>(input)
        var outputRaw = acquireArrayRawData<Byte>(output)
        try {
            moved.write(UIntNative(0))
            let status = CCCrypt(
                if (decrypt) {
                    CC_OPERATION_DECRYPT
                } else {
                    CC_OPERATION_ENCRYPT
                },
                CC_ALGORITHM_AES,
                CC_OPTION_ECB_MODE,
                keyRaw.pointer,
                UIntNative(key.size),
                CPointer<UInt8>(),
                inputRaw.pointer,
                UIntNative(input.size),
                outputRaw.pointer,
                UIntNative(output.size),
                moved
            )
            if (status != CC_STATUS_SUCCESS) {
                return status
            }
            if (Int64(moved.read()) != output.size) {
                return CC_STATUS_PARAM_ERROR
            }
            CC_STATUS_SUCCESS
        } finally {
            releaseArrayRawData<Byte>(outputRaw)
            releaseArrayRawData<Byte>(inputRaw)
            releaseArrayRawData<Byte>(keyRaw)
            LibC.free<UIntNative>(moved)
        }
    }
}

@When[os != "macOS"]
private func aesArmv8CeEcbCryptRaw(
    key: Array<Byte>,
    input: Array<Byte>,
    output: Array<Byte>,
    decrypt: Bool
): Int32 {
    let _ = key
    let _ = input
    let _ = output
    let _ = decrypt
    CC_STATUS_UNIMPLEMENTED
}

/**
 * pkcs7Pad.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func pkcs7Pad(input: Array<Byte>, blockSize!: Int64 = AES_BLOCK_SIZE): Array<Byte> {
    if (blockSize <= 0 || blockSize > 255) {
        throw CryptoException(InvalidArgument, "invalid block size")
    }
    let padding = blockSize - (input.size % blockSize)
    let out = Array<Byte>(input.size + padding, repeat: 0)
    secureCopyInto(input, out)
    var i = input.size
    while (i < out.size) {
        out[i] = UInt8(padding)
        i += 1
    }
    out
}

/**
 * pkcs7Unpad.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func pkcs7Unpad(input: Array<Byte>, blockSize!: Int64 = AES_BLOCK_SIZE): Array<Byte> {
    if (blockSize <= 0 || blockSize > 255) {
        throw CryptoException(InvalidArgument, "invalid block size")
    }
    if (input.size == 0 || (input.size % blockSize) != 0) {
        throw CryptoException(ParseError, "invalid PKCS7 length")
    }

    let pad = Int64(UInt8(input[input.size - 1]))
    if (pad <= 0 || pad > blockSize || pad > input.size) {
        throw CryptoException(ParseError, "invalid PKCS7 padding")
    }

    var i = input.size - pad
    while (i < input.size) {
        if (UInt8(input[i]) != UInt8(pad)) {
            throw CryptoException(ParseError, "invalid PKCS7 padding")
        }
        i += 1
    }

    input[..input.size - pad]
}

/**
 * aesEcbEncrypt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesEcbEncrypt(key: Array<Byte>, plaintext: Array<Byte>, pkcs7!: Bool = false): Array<Byte> {
    let input = if (pkcs7) {
        pkcs7Pad(plaintext)
    } else {
        if ((plaintext.size % AES_BLOCK_SIZE) != 0) {
            throw CryptoException(InvalidArgument, "ECB plaintext must be a multiple of block size")
        }
        plaintext
    }

    let (roundKeys, nr) = expandRoundKeys(key)
    let out = Array<Byte>(input.size, repeat: 0)
    let inBlock = zeroBlock()
    let outBlock = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < input.size) {
        copyBlockFromOffsetUnchecked(input, offset, inBlock)
        encryptBlockWithScheduleIntoUnchecked(inBlock, roundKeys, nr, outBlock)
        copyBlockToOffsetUnchecked(outBlock, out, offset)
        offset += AES_BLOCK_SIZE
    }
    out
}

public func aesEcbEncryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    plaintext: Array<Byte>,
    pkcs7!: Bool = false
): Array<Byte> {
    requireAesAllowed(profile, ECB)
    aesEcbEncrypt(key, plaintext, pkcs7: pkcs7)
}

/**
 * aesEcbDecrypt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesEcbDecrypt(key: Array<Byte>, ciphertext: Array<Byte>, pkcs7!: Bool = false): Array<Byte> {
    if ((ciphertext.size % AES_BLOCK_SIZE) != 0) {
        throw CryptoException(InvalidArgument, "ECB ciphertext must be a multiple of block size")
    }

    let (roundKeys, nr) = expandRoundKeys(key)
    let out = Array<Byte>(ciphertext.size, repeat: 0)
    let inBlock = zeroBlock()
    let outBlock = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < ciphertext.size) {
        copyBlockFromOffsetUnchecked(ciphertext, offset, inBlock)
        decryptBlockWithScheduleIntoUnchecked(inBlock, roundKeys, nr, state, outBlock)
        copyBlockToOffsetUnchecked(outBlock, out, offset)
        offset += AES_BLOCK_SIZE
    }

    if (pkcs7) {
        return pkcs7Unpad(out)
    }
    out
}

public func aesEcbDecryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    ciphertext: Array<Byte>,
    pkcs7!: Bool = false
): Array<Byte> {
    requireAesAllowed(profile, ECB)
    aesEcbDecrypt(key, ciphertext, pkcs7: pkcs7)
}

/**
 * aesCbcEncrypt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesCbcEncrypt(
    key: Array<Byte>,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    pkcs7!: Bool = false
): Array<Byte> {
    requireBlock(iv, "CBC iv")

    let input = if (pkcs7) {
        pkcs7Pad(plaintext)
    } else {
        if ((plaintext.size % AES_BLOCK_SIZE) != 0) {
            throw CryptoException(InvalidArgument, "CBC plaintext must be a multiple of block size")
        }
        plaintext
    }

    let (roundKeys, nr) = expandRoundKeys(key)
    let out = Array<Byte>(input.size, repeat: 0)
    var prev = iv.clone()
    let workBlock = zeroBlock()
    let outBlock = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < input.size) {
        xorInputBlockWithPrevUnchecked(input, offset, prev, workBlock)
        encryptBlockWithScheduleIntoUnchecked(workBlock, roundKeys, nr, outBlock)
        copyBlockToOffsetUnchecked(outBlock, out, offset)
        secureCopyInto(outBlock, prev)
        offset += AES_BLOCK_SIZE
    }

    out
}

public func aesCbcEncryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    pkcs7!: Bool = false
): Array<Byte> {
    requireAesAllowed(profile, CBC)
    aesCbcEncrypt(key, iv, plaintext, pkcs7: pkcs7)
}

/**
 * aesCbcDecrypt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesCbcDecrypt(
    key: Array<Byte>,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    pkcs7!: Bool = false
): Array<Byte> {
    requireBlock(iv, "CBC iv")
    if ((ciphertext.size % AES_BLOCK_SIZE) != 0) {
        throw CryptoException(InvalidArgument, "CBC ciphertext must be a multiple of block size")
    }

    let (roundKeys, nr) = expandRoundKeys(key)
    let out = Array<Byte>(ciphertext.size, repeat: 0)
    var prev = iv.clone()
    let inBlock = zeroBlock()
    let outBlock = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < ciphertext.size) {
        copyBlockFromOffsetUnchecked(ciphertext, offset, inBlock)
        decryptBlockWithScheduleIntoUnchecked(inBlock, roundKeys, nr, state, outBlock)
        xorWithPrevToOutputUnchecked(outBlock, prev, out, offset)
        secureCopyInto(inBlock, prev)
        offset += AES_BLOCK_SIZE
    }

    if (pkcs7) {
        return pkcs7Unpad(out)
    }
    out
}

public func aesCbcDecryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    pkcs7!: Bool = false
): Array<Byte> {
    requireAesAllowed(profile, CBC)
    aesCbcDecrypt(key, iv, ciphertext, pkcs7: pkcs7)
}

public func aesCtrCrypt(key: Array<Byte>, counterBlock: Array<Byte>, input: Array<Byte>): Array<Byte> {
    requireBlock(counterBlock, "CTR counter")
    let (roundKeys, nr) = expandRoundKeys(key)
    ctrCryptWithSchedule(roundKeys, nr, counterBlock, input)
}

public func aesCtrCryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    counterBlock: Array<Byte>,
    input: Array<Byte>
): Array<Byte> {
    requireAesAllowed(profile, CTR)
    aesCtrCrypt(key, counterBlock, input)
}

/**
 * aesGcmEncrypt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesGcmEncrypt(
    key: Array<Byte>,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): (Array<Byte>, Array<Byte>) {
    if (tagLen <= 0 || tagLen > 16) {
        throw CryptoException(InvalidArgument, "invalid GCM tag length")
    }
    let ctx = AesGcmContext(key)
    aesGcmEncryptWithContext(ctx, iv, plaintext, aad: aad, tagLen: tagLen)
}

/**
 * aesGcmEncryptWithContext.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesGcmEncryptWithContext(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): (Array<Byte>, Array<Byte>) {
    if (tagLen <= 0 || tagLen > 16) {
        throw CryptoException(InvalidArgument, "invalid GCM tag length")
    }
    if (aesUseNativeArmv8Ce(ctx.engine)) {
        return aesGcmEncryptWithArmv8Ce(ctx, iv, plaintext, aad, tagLen)
    }

    let ciphertext = Array<Byte>(plaintext.size, repeat: 0)
    let fullTag = Array<Byte>(tagLen, repeat: 0)
    aesGcmEncryptWithContextSoftwareInto(ctx, iv, plaintext, aad, ciphertext, fullTag, tagLen)
    (ciphertext, fullTag)
}

public func aesGcmEncryptInto(
    key: Array<Byte>,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    ciphertextOut: Array<Byte>,
    tagOut: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): Unit {
    let ctx = AesGcmContext(key)
    aesGcmEncryptIntoWithContext(ctx, iv, plaintext, ciphertextOut, tagOut, aad: aad, tagLen: tagLen)
}

/**
 * aesGcmEncryptIntoWithContext.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesGcmEncryptIntoWithContext(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    ciphertextOut: Array<Byte>,
    tagOut: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): Unit {
    if (tagLen <= 0 || tagLen > 16) {
        throw CryptoException(InvalidArgument, "invalid GCM tag length")
    }
    if (ciphertextOut.size != plaintext.size) {
        throw CryptoException(InvalidArgument, "AES-GCM output length mismatch")
    }
    if (tagOut.size < tagLen) {
        throw CryptoException(InvalidArgument, "AES-GCM tag output is too short")
    }

    if (aesUseNativeArmv8Ce(ctx.engine)) {
        aesGcmEncryptIntoWithArmv8Ce(ctx, iv, plaintext, aad, ciphertextOut, tagOut, tagLen)
        return
    }

    aesGcmEncryptWithContextSoftwareInto(ctx, iv, plaintext, aad, ciphertextOut, tagOut, tagLen)
}

public func aesGcmEncryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): (Array<Byte>, Array<Byte>) {
    requireAesAllowed(profile, GCM)
    aesGcmEncrypt(key, iv, plaintext, aad: aad, tagLen: tagLen)
}

public func aesGcmEncryptWithContextChecked(
    profile: FipsProfile,
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): (Array<Byte>, Array<Byte>) {
    requireAesAllowed(profile, GCM)
    aesGcmEncryptWithContext(ctx, iv, plaintext, aad: aad, tagLen: tagLen)
}

public func aesGcmEncryptIntoChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    ciphertextOut: Array<Byte>,
    tagOut: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): Unit {
    requireAesAllowed(profile, GCM)
    aesGcmEncryptInto(key, iv, plaintext, ciphertextOut, tagOut, aad: aad, tagLen: tagLen)
}

public func aesGcmEncryptIntoWithContextChecked(
    profile: FipsProfile,
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    ciphertextOut: Array<Byte>,
    tagOut: Array<Byte>,
    aad!: Array<Byte> = [],
    tagLen!: Int64 = 16
): Unit {
    requireAesAllowed(profile, GCM)
    aesGcmEncryptIntoWithContext(ctx, iv, plaintext, ciphertextOut, tagOut, aad: aad, tagLen: tagLen)
}

/**
 * aesGcmDecrypt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesGcmDecrypt(
    key: Array<Byte>,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    if (tag.size <= 0 || tag.size > 16) {
        throw CryptoException(InvalidArgument, "invalid GCM tag length")
    }
    let ctx = AesGcmContext(key)
    aesGcmDecryptWithContext(ctx, iv, ciphertext, tag, aad: aad)
}

/**
 * aesGcmDecryptWithContext.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesGcmDecryptWithContext(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    if (tag.size <= 0 || tag.size > 16) {
        throw CryptoException(InvalidArgument, "invalid GCM tag length")
    }
    if (aesUseNativeArmv8Ce(ctx.engine)) {
        return aesGcmDecryptWithArmv8Ce(ctx, iv, ciphertext, tag, aad)
    }

    let j0 = gcmJ0WithTable(ctx.ghashTableHi, ctx.ghashTableLo, iv)
    var sHi: UInt64 = 0
    var sLo: UInt64 = 0
    let (aadHi, aadLo) = ghashUpdatePairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo, aad)
    sHi = aadHi
    sLo = aadLo
    let (cipherHi, cipherLo) = ghashUpdatePairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo, ciphertext)
    sHi = cipherHi
    sLo = cipherLo
    let (hashHi, hashLo) = ghashFinalizePairWithTable(
        sHi,
        sLo,
        aad.size,
        ciphertext.size,
        ctx.ghashTableHi,
        ctx.ghashTableLo
    )
    let expectedMask = encryptBlockWithSchedule(j0, ctx.schedule.roundKeys, ctx.schedule.nr)
    let expectedHi = decodeUInt64BE(expectedMask, 0) ^ hashHi
    let expectedLo = decodeUInt64BE(expectedMask, 8) ^ hashLo
    if (!constantTimeTagEqualsPair(tag, expectedHi, expectedLo)) {
        throw CryptoException(InvalidArgument, "GCM tag mismatch")
    }

    var counter = j0.clone()
    incrementCounter32Unchecked(counter)
    ctrCryptWithScheduleInc32(ctx.schedule.roundKeys, ctx.schedule.nr, counter, ciphertext)
}

public func aesGcmDecryptInto(
    key: Array<Byte>,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    plaintextOut: Array<Byte>,
    aad!: Array<Byte> = []
): Unit {
    let ctx = AesGcmContext(key)
    aesGcmDecryptIntoWithContext(ctx, iv, ciphertext, tag, plaintextOut, aad: aad)
}

/**
 * aesGcmDecryptIntoWithContext.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func aesGcmDecryptIntoWithContext(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    plaintextOut: Array<Byte>,
    aad!: Array<Byte> = []
): Unit {
    if (tag.size <= 0 || tag.size > 16) {
        throw CryptoException(InvalidArgument, "invalid GCM tag length")
    }
    if (plaintextOut.size != ciphertext.size) {
        throw CryptoException(InvalidArgument, "AES-GCM output length mismatch")
    }

    if (aesUseNativeArmv8Ce(ctx.engine)) {
        aesGcmDecryptIntoWithArmv8Ce(ctx, iv, ciphertext, tag, aad, plaintextOut)
        return
    }

    let j0 = gcmJ0WithTable(ctx.ghashTableHi, ctx.ghashTableLo, iv)
    var sHi: UInt64 = 0
    var sLo: UInt64 = 0
    let (aadHi, aadLo) = ghashUpdatePairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo, aad)
    sHi = aadHi
    sLo = aadLo
    let (cipherHi, cipherLo) = ghashUpdatePairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo, ciphertext)
    sHi = cipherHi
    sLo = cipherLo
    let (hashHi, hashLo) = ghashFinalizePairWithTable(
        sHi,
        sLo,
        aad.size,
        ciphertext.size,
        ctx.ghashTableHi,
        ctx.ghashTableLo
    )
    let expectedMask = encryptBlockWithSchedule(j0, ctx.schedule.roundKeys, ctx.schedule.nr)
    let expectedHi = decodeUInt64BE(expectedMask, 0) ^ hashHi
    let expectedLo = decodeUInt64BE(expectedMask, 8) ^ hashLo
    if (!constantTimeTagEqualsPair(tag, expectedHi, expectedLo)) {
        throw CryptoException(InvalidArgument, "GCM tag mismatch")
    }

    var counter = j0.clone()
    incrementCounter32Unchecked(counter)
    ctrCryptWithScheduleInc32Into(ctx.schedule.roundKeys, ctx.schedule.nr, counter, ciphertext, plaintextOut)
}

public func aesGcmDecryptChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    requireAesAllowed(profile, GCM)
    aesGcmDecrypt(key, iv, ciphertext, tag, aad: aad)
}

public func aesGcmDecryptWithContextChecked(
    profile: FipsProfile,
    ctx: AesGcmContext,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    aad!: Array<Byte> = []
): Array<Byte> {
    requireAesAllowed(profile, GCM)
    aesGcmDecryptWithContext(ctx, iv, ciphertext, tag, aad: aad)
}

public func aesGcmDecryptIntoChecked(
    profile: FipsProfile,
    key: Array<Byte>,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    plaintextOut: Array<Byte>,
    aad!: Array<Byte> = []
): Unit {
    requireAesAllowed(profile, GCM)
    aesGcmDecryptInto(key, iv, ciphertext, tag, plaintextOut, aad: aad)
}

public func aesGcmDecryptIntoWithContextChecked(
    profile: FipsProfile,
    ctx: AesGcmContext,
    iv: Array<Byte>,
    ciphertext: Array<Byte>,
    tag: Array<Byte>,
    plaintextOut: Array<Byte>,
    aad!: Array<Byte> = []
): Unit {
    requireAesAllowed(profile, GCM)
    aesGcmDecryptIntoWithContext(ctx, iv, ciphertext, tag, plaintextOut, aad: aad)
}

public func aesBlockEncrypt(key: Array<Byte>, block: Array<Byte>): Array<Byte> {
    requireBlock(block, "AES block")
    let (roundKeys, nr) = expandRoundKeys(key)
    encryptBlockWithSchedule(block, roundKeys, nr)
}

public func aesBlockDecrypt(key: Array<Byte>, block: Array<Byte>): Array<Byte> {
    requireBlock(block, "AES block")
    let (roundKeys, nr) = expandRoundKeys(key)
    decryptBlockWithSchedule(block, roundKeys, nr)
}

private func expectedNkFromAesKeyBytes(keyBytes: Int64): Int64 {
    match (keyBytes) {
        case 16 => 4
        case 24 => 6
        case 32 => 8
        case _ =>
            throw CryptoException(InvalidArgument, "AES key length must be 16/24/32 bytes")
    }
}

private func expectedRoundsFromAesKeyBytes(keyBytes: Int64): Int64 {
    expectedNkFromAesKeyBytes(keyBytes) + 6
}

@OverflowWrapping
private func expandRoundKeys(key: Array<Byte>): (Array<UInt32>, Int64) {
    let nk = expectedNkFromAesKeyBytes(key.size)

    let nr = nk + 6
    let totalWords = 4 * (nr + 1)
    let words = Array<UInt32>(totalWords, repeat: UInt32(0))

    var i = 0
    while (i < nk) {
        words[i] = packWordBE(key, i * 4)
        i += 1
    }

    while (i < totalWords) {
        var temp = words[i - 1]
        if ((i % nk) == 0) {
            temp = subWord(rotWord(temp)) ^ RCON[(i / nk) - 1]
        } else if (nk > 6 && (i % nk) == 4) {
            temp = subWord(temp)
        }
        words[i] = words[i - nk] ^ temp
        i += 1
    }

    (words, nr)
}

@OverflowWrapping
private func encryptBlockWithSchedule(block: Array<Byte>, words: Array<UInt32>, nr: Int64): Array<Byte> {
    requireBlock(block, "AES block")
    let out = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))
    encryptBlockWithScheduleInto(block, words, nr, state, out)
    out
}

@OverflowWrapping
private func encryptBlockWithScheduleInto(
    block: Array<Byte>,
    words: Array<UInt32>,
    nr: Int64,
    state: Array<UInt8>,
    out: Array<Byte>
): Unit {
    requireBlock(block, "AES block")
    if (state.size != AES_BLOCK_SIZE || out.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES scratch length must be 16 bytes")
    }
    encryptBlockWithScheduleIntoUnchecked(block, words, nr, out)
}

@OverflowWrapping
private func encryptBlockWithScheduleIntoUnchecked(
    block: Array<Byte>,
    words: Array<UInt32>,
    nr: Int64,
    out: Array<Byte>
): Unit {
    var s0 = packWordBE(block, 0) ^ words[0]
    var s1 = packWordBE(block, 4) ^ words[1]
    var s2 = packWordBE(block, 8) ^ words[2]
    var s3 = packWordBE(block, 12) ^ words[3]

    var round = 1
    while (round < nr) {
        let t0 = TE0[wordByteIndex(s0, 24)] ^
            TE3[wordByteIndex(s1, 16)] ^
            TE2[wordByteIndex(s2, 8)] ^
            TE1[wordByteIndex(s3, 0)] ^
            words[round * 4]

        let t1 = TE0[wordByteIndex(s1, 24)] ^
            TE3[wordByteIndex(s2, 16)] ^
            TE2[wordByteIndex(s3, 8)] ^
            TE1[wordByteIndex(s0, 0)] ^
            words[round * 4 + 1]

        let t2 = TE0[wordByteIndex(s2, 24)] ^
            TE3[wordByteIndex(s3, 16)] ^
            TE2[wordByteIndex(s0, 8)] ^
            TE1[wordByteIndex(s1, 0)] ^
            words[round * 4 + 2]

        let t3 = TE0[wordByteIndex(s3, 24)] ^
            TE3[wordByteIndex(s0, 16)] ^
            TE2[wordByteIndex(s1, 8)] ^
            TE1[wordByteIndex(s2, 0)] ^
            words[round * 4 + 3]

        s0 = t0
        s1 = t1
        s2 = t2
        s3 = t3
        round += 1
    }

    let final0 = (
        (UInt32(SBOX[wordByteIndex(s0, 24)]) << 24) |
        (UInt32(SBOX[wordByteIndex(s1, 16)]) << 16) |
        (UInt32(SBOX[wordByteIndex(s2, 8)]) << 8) |
        UInt32(SBOX[wordByteIndex(s3, 0)])
    ) ^ words[nr * 4]

    let final1 = (
        (UInt32(SBOX[wordByteIndex(s1, 24)]) << 24) |
        (UInt32(SBOX[wordByteIndex(s2, 16)]) << 16) |
        (UInt32(SBOX[wordByteIndex(s3, 8)]) << 8) |
        UInt32(SBOX[wordByteIndex(s0, 0)])
    ) ^ words[nr * 4 + 1]

    let final2 = (
        (UInt32(SBOX[wordByteIndex(s2, 24)]) << 24) |
        (UInt32(SBOX[wordByteIndex(s3, 16)]) << 16) |
        (UInt32(SBOX[wordByteIndex(s0, 8)]) << 8) |
        UInt32(SBOX[wordByteIndex(s1, 0)])
    ) ^ words[nr * 4 + 2]

    let final3 = (
        (UInt32(SBOX[wordByteIndex(s3, 24)]) << 24) |
        (UInt32(SBOX[wordByteIndex(s0, 16)]) << 16) |
        (UInt32(SBOX[wordByteIndex(s1, 8)]) << 8) |
        UInt32(SBOX[wordByteIndex(s2, 0)])
    ) ^ words[nr * 4 + 3]

    storeWordBE(out, 0, final0)
    storeWordBE(out, 4, final1)
    storeWordBE(out, 8, final2)
    storeWordBE(out, 12, final3)
}

@OverflowWrapping
private func decryptBlockWithSchedule(block: Array<Byte>, words: Array<UInt32>, nr: Int64): Array<Byte> {
    requireBlock(block, "AES block")
    let out = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))
    decryptBlockWithScheduleInto(block, words, nr, state, out)
    out
}

@OverflowWrapping
private func decryptBlockWithScheduleInto(
    block: Array<Byte>,
    words: Array<UInt32>,
    nr: Int64,
    state: Array<UInt8>,
    out: Array<Byte>
): Unit {
    requireBlock(block, "AES block")
    if (state.size != AES_BLOCK_SIZE || out.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES scratch length must be 16 bytes")
    }
    decryptBlockWithScheduleIntoUnchecked(block, words, nr, state, out)
}

@OverflowWrapping
private func decryptBlockWithScheduleIntoUnchecked(
    block: Array<Byte>,
    words: Array<UInt32>,
    nr: Int64,
    state: Array<UInt8>,
    out: Array<Byte>
): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        state[i] = UInt8(block[i])
        i += 1
    }

    addRoundKey(state, words, nr)

    var round = nr - 1
    while (round > 0) {
        invShiftRows(state)
        invSubBytes(state)
        addRoundKey(state, words, round)
        invMixColumns(state)
        round -= 1
    }

    invShiftRows(state)
    invSubBytes(state)
    addRoundKey(state, words, 0)

    i = 0
    while (i < AES_BLOCK_SIZE) {
        out[i] = state[i]
        i += 1
    }
}

private func cryptBlocksWithSchedule(
    roundKeys: Array<UInt32>,
    nr: Int64,
    input: Array<Byte>,
    decrypt!: Bool = false
): Array<Byte> {
    if ((input.size % AES_BLOCK_SIZE) != 0) {
        throw CryptoException(InvalidArgument, "native bridge block payload must be a multiple of 16 bytes")
    }
    let out = Array<Byte>(input.size, repeat: 0)
    let inBlock = zeroBlock()
    let outBlock = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < input.size) {
        copyBlockFromOffsetUnchecked(input, offset, inBlock)
        if (decrypt) {
            decryptBlockWithScheduleIntoUnchecked(inBlock, roundKeys, nr, state, outBlock)
        } else {
            encryptBlockWithScheduleIntoUnchecked(inBlock, roundKeys, nr, outBlock)
        }
        copyBlockToOffsetUnchecked(outBlock, out, offset)
        offset += AES_BLOCK_SIZE
    }
    out
}

private func encodeNativeBridgeRawKeyBlob(contract: AesNativeBridgeContract, key: Array<Byte>): Array<Byte> {
    validateNativeBridgeAbiVersion(contract.abiVersion)
    _ = expectedNkFromAesKeyBytes(key.size)

    let out = Array<Byte>(AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + key.size, repeat: 0)
    out[0] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_0
    out[1] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_1
    out[2] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_2
    out[3] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_3
    out[4] = UInt8(contract.abiVersion)
    out[5] = UInt8(key.size)
    out[6] = UInt8(0)
    out[7] = AES_NATIVE_BRIDGE_KEY_BLOB_FLAG_RAW_KEY
    storeWordBE(out, 8, UInt32(key.size))

    var i = 0
    while (i < key.size) {
        out[AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + i] = key[i]
        i += 1
    }
    out
}

private func decodeNativeBridgeRawKeyBlob(contract: AesNativeBridgeContract, blob: Array<Byte>): Array<Byte> {
    validateNativeBridgeAbiVersion(contract.abiVersion)
    if (blob.size < AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES) {
        throw CryptoException(InvalidArgument, "native bridge raw-key blob is too short")
    }
    if (
        UInt8(blob[0]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_0 ||
        UInt8(blob[1]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_1 ||
        UInt8(blob[2]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_2 ||
        UInt8(blob[3]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_3
    ) {
        throw CryptoException(ParseError, "native bridge raw-key blob magic mismatch")
    }

    let abiVersion = Int64(UInt8(blob[4]))
    if (abiVersion != contract.abiVersion) {
        throw CryptoException(Unsupported, "native bridge raw-key ABI mismatch")
    }
    let keyBytes = Int64(UInt8(blob[5]))
    _ = expectedNkFromAesKeyBytes(keyBytes)
    if (UInt8(blob[6]) != UInt8(0)) {
        throw CryptoException(ParseError, "native bridge raw-key rounds marker is invalid")
    }
    if (UInt8(blob[7]) != AES_NATIVE_BRIDGE_KEY_BLOB_FLAG_RAW_KEY) {
        throw CryptoException(ParseError, "native bridge raw-key flag is invalid")
    }

    let payloadBytes = Int64(packWordBE(blob, 8))
    if (payloadBytes != keyBytes) {
        throw CryptoException(ParseError, "native bridge raw-key payload size mismatch")
    }
    let expectedSize = AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + payloadBytes
    if (blob.size != expectedSize) {
        throw CryptoException(ParseError, "native bridge raw-key blob length mismatch")
    }

    let key = Array<Byte>(keyBytes, repeat: 0)
    var i = 0
    while (i < keyBytes) {
        key[i] = blob[AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + i]
        i += 1
    }
    key
}

private func encodeNativeBridgeExpandedKeyBlob(
    contract: AesNativeBridgeContract,
    keyBytes: Int64,
    roundKeys: Array<UInt32>,
    rounds: Int64
): Array<Byte> {
    validateNativeBridgeAbiVersion(contract.abiVersion)
    let expectedRounds = expectedRoundsFromAesKeyBytes(keyBytes)
    if (rounds != expectedRounds) {
        throw CryptoException(InvalidArgument, "native bridge key schedule rounds mismatch")
    }
    let expectedWordCount = expectedRoundKeyWordCount(rounds)
    if (roundKeys.size != expectedWordCount) {
        throw CryptoException(InvalidArgument, "native bridge round-key word count mismatch")
    }

    let out = Array<Byte>(AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + expectedWordCount * 4, repeat: 0)
    out[0] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_0
    out[1] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_1
    out[2] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_2
    out[3] = AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_3
    out[4] = UInt8(contract.abiVersion)
    out[5] = UInt8(keyBytes)
    out[6] = UInt8(rounds)
    out[7] = UInt8(0)
    storeWordBE(out, 8, UInt32(expectedWordCount))

    var i = 0
    while (i < expectedWordCount) {
        let offset = AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + i * 4
        storeWordBE(out, offset, roundKeys[i])
        i += 1
    }
    out
}

private func decodeNativeBridgeExpandedKeyBlob(
    contract: AesNativeBridgeContract,
    blob: Array<Byte>
): (Array<UInt32>, Int64) {
    validateNativeBridgeAbiVersion(contract.abiVersion)
    if (blob.size < AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES) {
        throw CryptoException(InvalidArgument, "native bridge expanded-key blob is too short")
    }
    if (
        UInt8(blob[0]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_0 ||
        UInt8(blob[1]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_1 ||
        UInt8(blob[2]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_2 ||
        UInt8(blob[3]) != AES_NATIVE_BRIDGE_KEY_BLOB_MAGIC_3
    ) {
        throw CryptoException(ParseError, "native bridge expanded-key blob magic mismatch")
    }

    let abiVersion = Int64(UInt8(blob[4]))
    if (abiVersion != contract.abiVersion) {
        throw CryptoException(Unsupported, "native bridge expanded-key ABI mismatch")
    }
    let keyBytes = Int64(UInt8(blob[5]))
    let rounds = Int64(UInt8(blob[6]))
    if (UInt8(blob[7]) != UInt8(0)) {
        throw CryptoException(ParseError, "native bridge expanded-key blob header is invalid")
    }

    let expectedRounds = expectedRoundsFromAesKeyBytes(keyBytes)
    if (rounds != expectedRounds) {
        throw CryptoException(ParseError, "native bridge expanded-key rounds mismatch")
    }

    let expectedWordCount = expectedRoundKeyWordCount(rounds)
    let wordCount = Int64(packWordBE(blob, 8))
    if (wordCount != expectedWordCount) {
        throw CryptoException(ParseError, "native bridge expanded-key word count mismatch")
    }

    let expectedSize = AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + wordCount * 4
    if (blob.size != expectedSize) {
        throw CryptoException(ParseError, "native bridge expanded-key blob length mismatch")
    }

    let words = Array<UInt32>(wordCount, repeat: UInt32(0))
    var i = 0
    while (i < wordCount) {
        let offset = AES_NATIVE_BRIDGE_KEY_BLOB_HEADER_BYTES + i * 4
        words[i] = packWordBE(blob, offset)
        i += 1
    }
    (words, rounds)
}

private func expectedRoundKeyWordCount(rounds: Int64): Int64 {
    4 * (rounds + 1)
}

private func validateNativeBridgeAbiVersion(abiVersion: Int64): Unit {
    if (abiVersion <= 0 || abiVersion > 255) {
        throw CryptoException(Unsupported, "unsupported native bridge ABI version")
    }
}

private func requireBlock(input: Array<Byte>, name: String): Unit {
    if (input.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "${name} length must be 16 bytes")
    }
}

@OverflowWrapping
private func packWordBE(input: Array<Byte>, offset: Int64): UInt32 {
    (UInt32(UInt8(input[offset])) << 24) |
    (UInt32(UInt8(input[offset + 1])) << 16) |
    (UInt32(UInt8(input[offset + 2])) << 8) |
    UInt32(UInt8(input[offset + 3]))
}

private func storeWordBE(output: Array<Byte>, offset: Int64, word: UInt32): Unit {
    output[offset] = UInt8((word >> 24) & UInt32(0xff))
    output[offset + 1] = UInt8((word >> 16) & UInt32(0xff))
    output[offset + 2] = UInt8((word >> 8) & UInt32(0xff))
    output[offset + 3] = UInt8(word & UInt32(0xff))
}

private func wordByteIndex(word: UInt32, shift: Int64): Int64 {
    Int64(UInt8((word >> shift) & UInt32(0xff)))
}

@OverflowWrapping
private func rotWord(v: UInt32): UInt32 {
    (v << 8) | (v >> 24)
}

private func subWord(v: UInt32): UInt32 {
    let b0 = SBOX[Int64(UInt8((v >> 24) & UInt32(0xff)))]
    let b1 = SBOX[Int64(UInt8((v >> 16) & UInt32(0xff)))]
    let b2 = SBOX[Int64(UInt8((v >> 8) & UInt32(0xff)))]
    let b3 = SBOX[Int64(UInt8(v & UInt32(0xff)))]

    (UInt32(b0) << 24) | (UInt32(b1) << 16) | (UInt32(b2) << 8) | UInt32(b3)
}

private func addRoundKey(state: Array<UInt8>, words: Array<UInt32>, round: Int64): Unit {
    var c = 0
    while (c < 4) {
        let word = words[round * 4 + c]
        let i = c * 4
        state[i] = state[i] ^ UInt8((word >> 24) & UInt32(0xff))
        state[i + 1] = state[i + 1] ^ UInt8((word >> 16) & UInt32(0xff))
        state[i + 2] = state[i + 2] ^ UInt8((word >> 8) & UInt32(0xff))
        state[i + 3] = state[i + 3] ^ UInt8(word & UInt32(0xff))
        c += 1
    }
}

private func subBytes(state: Array<UInt8>): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        state[i] = SBOX[Int64(state[i])]
        i += 1
    }
}

private func invSubBytes(state: Array<UInt8>): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        state[i] = INV_SBOX[Int64(state[i])]
        i += 1
    }
}

private func shiftRows(state: Array<UInt8>): Unit {
    let t1 = state[1]
    state[1] = state[5]
    state[5] = state[9]
    state[9] = state[13]
    state[13] = t1

    let t2 = state[2]
    let t6 = state[6]
    state[2] = state[10]
    state[6] = state[14]
    state[10] = t2
    state[14] = t6

    let t15 = state[15]
    state[15] = state[11]
    state[11] = state[7]
    state[7] = state[3]
    state[3] = t15
}

private func invShiftRows(state: Array<UInt8>): Unit {
    let t13 = state[13]
    state[13] = state[9]
    state[9] = state[5]
    state[5] = state[1]
    state[1] = t13

    let t2 = state[2]
    let t6 = state[6]
    state[2] = state[10]
    state[6] = state[14]
    state[10] = t2
    state[14] = t6

    let t3 = state[3]
    state[3] = state[7]
    state[7] = state[11]
    state[11] = state[15]
    state[15] = t3
}

@OverflowWrapping
private func mixColumns(state: Array<UInt8>): Unit {
    var c = 0
    while (c < 4) {
        let i = c * 4
        let s0 = state[i]
        let s1 = state[i + 1]
        let s2 = state[i + 2]
        let s3 = state[i + 3]
        let t = s0 ^ s1 ^ s2 ^ s3

        state[i] = s0 ^ t ^ xtime(s0 ^ s1)
        state[i + 1] = s1 ^ t ^ xtime(s1 ^ s2)
        state[i + 2] = s2 ^ t ^ xtime(s2 ^ s3)
        state[i + 3] = s3 ^ t ^ xtime(s3 ^ s0)
        c += 1
    }
}

@OverflowWrapping
private func invMixColumns(state: Array<UInt8>): Unit {
    var c = 0
    while (c < 4) {
        let i = c * 4
        let s0 = state[i]
        let s1 = state[i + 1]
        let s2 = state[i + 2]
        let s3 = state[i + 3]
        let u = xtime(xtime(s0 ^ s2))
        let v = xtime(xtime(s1 ^ s3))
        state[i] = s0 ^ u
        state[i + 1] = s1 ^ v
        state[i + 2] = s2 ^ u
        state[i + 3] = s3 ^ v
        c += 1
    }
    mixColumns(state)
}

@OverflowWrapping
private func xtime(x: UInt8): UInt8 {
    let hi = x & UInt8(0x80)
    let shifted = x << 1
    if (hi != UInt8(0)) {
        return shifted ^ UInt8(0x1b)
    }
    shifted
}

private func zeroBlock(): Array<Byte> {
    Array<Byte>(AES_BLOCK_SIZE, repeat: 0)
}

private func xorBlock(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    if (left.size != right.size) {
        throw CryptoException(InvalidArgument, "xorBlock length mismatch")
    }
    let out = Array<Byte>(left.size, repeat: 0)
    var i = 0
    while (i < left.size) {
        out[i] = UInt8(left[i]) ^ UInt8(right[i])
        i += 1
    }
    out
}

private func xorBlockInPlace(dst: Array<Byte>, src: Array<Byte>): Unit {
    if (dst.size != src.size) {
        throw CryptoException(InvalidArgument, "xorBlock length mismatch")
    }
    var i = 0
    while (i < dst.size) {
        dst[i] = UInt8(dst[i]) ^ UInt8(src[i])
        i += 1
    }
}

private func copyBlockFromOffset(src: Array<Byte>, offset: Int64, dst: Array<Byte>): Unit {
    if (dst.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES block scratch length must be 16 bytes")
    }
    if (offset < 0 || (offset + AES_BLOCK_SIZE) > src.size) {
        throw CryptoException(OutOfBounds, "source block offset out of bounds")
    }
    copyBlockFromOffsetUnchecked(src, offset, dst)
}

private func copyBlockFromOffsetUnchecked(src: Array<Byte>, offset: Int64, dst: Array<Byte>): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        dst[i] = src[offset + i]
        i += 1
    }
}

private func copyBlockToOffset(src: Array<Byte>, dst: Array<Byte>, offset: Int64): Unit {
    if (src.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES block scratch length must be 16 bytes")
    }
    if (offset < 0 || (offset + AES_BLOCK_SIZE) > dst.size) {
        throw CryptoException(OutOfBounds, "destination block offset out of bounds")
    }
    copyBlockToOffsetUnchecked(src, dst, offset)
}

private func copyBlockToOffsetUnchecked(src: Array<Byte>, dst: Array<Byte>, offset: Int64): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        dst[offset + i] = src[i]
        i += 1
    }
}

private func xorInputBlockWithPrev(input: Array<Byte>, offset: Int64, prev: Array<Byte>, out: Array<Byte>): Unit {
    if (prev.size != AES_BLOCK_SIZE || out.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES block scratch length must be 16 bytes")
    }
    if (offset < 0 || (offset + AES_BLOCK_SIZE) > input.size) {
        throw CryptoException(OutOfBounds, "input block offset out of bounds")
    }
    xorInputBlockWithPrevUnchecked(input, offset, prev, out)
}

private func xorInputBlockWithPrevUnchecked(input: Array<Byte>, offset: Int64, prev: Array<Byte>, out: Array<Byte>): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        out[i] = UInt8(input[offset + i]) ^ UInt8(prev[i])
        i += 1
    }
}

private func xorWithPrevToOutput(block: Array<Byte>, prev: Array<Byte>, out: Array<Byte>, offset: Int64): Unit {
    if (block.size != AES_BLOCK_SIZE || prev.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES block scratch length must be 16 bytes")
    }
    if (offset < 0 || (offset + AES_BLOCK_SIZE) > out.size) {
        throw CryptoException(OutOfBounds, "output block offset out of bounds")
    }
    xorWithPrevToOutputUnchecked(block, prev, out, offset)
}

private func xorWithPrevToOutputUnchecked(block: Array<Byte>, prev: Array<Byte>, out: Array<Byte>, offset: Int64): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        out[offset + i] = UInt8(block[i]) ^ UInt8(prev[i])
        i += 1
    }
}

private func ctrCryptWithSchedule(
    roundKeys: Array<UInt32>,
    nr: Int64,
    initialCounter: Array<Byte>,
    input: Array<Byte>,
    inc32!: Bool = false
): Array<Byte> {
    requireBlock(initialCounter, "CTR counter")
    if (inc32) {
        return ctrCryptWithScheduleInc32(roundKeys, nr, initialCounter, input)
    }
    ctrCryptWithScheduleInc128(roundKeys, nr, initialCounter, input)
}

private func ctrCryptWithScheduleInc128(
    roundKeys: Array<UInt32>,
    nr: Int64,
    initialCounter: Array<Byte>,
    input: Array<Byte>
): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var counter = initialCounter.clone()
    let keystream = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < input.size) {
        encryptBlockWithScheduleIntoUnchecked(counter, roundKeys, nr, keystream)
        let remaining = input.size - offset
        let take = if (remaining < AES_BLOCK_SIZE) {
            remaining
        } else {
            AES_BLOCK_SIZE
        }

        if (take == AES_BLOCK_SIZE) {
            let inHi = decodeUInt64BE(input, offset)
            let inLo = decodeUInt64BE(input, offset + 8)
            let streamHi = decodeUInt64BE(keystream, 0)
            let streamLo = decodeUInt64BE(keystream, 8)
            encodeUInt64BE(out, offset, inHi ^ streamHi)
            encodeUInt64BE(out, offset + 8, inLo ^ streamLo)
        } else {
            xorPartialBlockFromOffsetUnchecked(keystream, input, offset, take, out, offset)
        }

        incrementCounter128Unchecked(counter)
        offset += take
    }

    out
}

private func ctrCryptWithScheduleInc32(
    roundKeys: Array<UInt32>,
    nr: Int64,
    initialCounter: Array<Byte>,
    input: Array<Byte>
): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    ctrCryptWithScheduleInc32Into(roundKeys, nr, initialCounter, input, out)
    out
}

private func ctrCryptWithScheduleInc32Into(
    roundKeys: Array<UInt32>,
    nr: Int64,
    initialCounter: Array<Byte>,
    input: Array<Byte>,
    out: Array<Byte>
): Unit {
    if (out.size != input.size) {
        throw CryptoException(InvalidArgument, "CTR output length mismatch")
    }
    var counter = initialCounter.clone()
    let keystream = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))

    var offset = 0
    while (offset < input.size) {
        encryptBlockWithScheduleIntoUnchecked(counter, roundKeys, nr, keystream)
        let remaining = input.size - offset
        let take = if (remaining < AES_BLOCK_SIZE) {
            remaining
        } else {
            AES_BLOCK_SIZE
        }

        if (take == AES_BLOCK_SIZE) {
            let inHi = decodeUInt64BE(input, offset)
            let inLo = decodeUInt64BE(input, offset + 8)
            let streamHi = decodeUInt64BE(keystream, 0)
            let streamLo = decodeUInt64BE(keystream, 8)
            encodeUInt64BE(out, offset, inHi ^ streamHi)
            encodeUInt64BE(out, offset + 8, inLo ^ streamLo)
        } else {
            xorPartialBlockFromOffsetUnchecked(keystream, input, offset, take, out, offset)
        }

        incrementCounter32Unchecked(counter)
        offset += take
    }
}

private func xorPartialBlockFromOffset(
    block: Array<Byte>,
    input: Array<Byte>,
    inputOffset: Int64,
    take: Int64,
    out: Array<Byte>,
    outOffset: Int64
): Unit {
    if (block.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES block length must be 16 bytes")
    }
    if (take < 0 || take > AES_BLOCK_SIZE) {
        throw CryptoException(OutOfBounds, "partial XOR length out of bounds")
    }
    if (inputOffset < 0 || (inputOffset + take) > input.size) {
        throw CryptoException(OutOfBounds, "input offset out of bounds")
    }
    if (outOffset < 0 || (outOffset + take) > out.size) {
        throw CryptoException(OutOfBounds, "output offset out of bounds")
    }
    xorPartialBlockFromOffsetUnchecked(block, input, inputOffset, take, out, outOffset)
}

private func xorPartialBlockFromOffsetUnchecked(
    block: Array<Byte>,
    input: Array<Byte>,
    inputOffset: Int64,
    take: Int64,
    out: Array<Byte>,
    outOffset: Int64
): Unit {
    var i = 0
    while (i < take) {
        out[outOffset + i] = UInt8(input[inputOffset + i]) ^ UInt8(block[i])
        i += 1
    }
}

@OverflowWrapping
private func incrementCounter128Unchecked(counter: Array<Byte>): Unit {
    var i = AES_BLOCK_SIZE - 1
    while (i >= 0) {
        let v = UInt8(counter[i]) + UInt8(1)
        counter[i] = v
        if (v != UInt8(0)) {
            return
        }
        i -= 1
    }
}

@OverflowWrapping
private func incrementCounter32Unchecked(counter: Array<Byte>): Unit {
    var i = AES_BLOCK_SIZE - 1
    while (i >= AES_BLOCK_SIZE - 4) {
        let v = UInt8(counter[i]) + UInt8(1)
        counter[i] = v
        if (v != UInt8(0)) {
            return
        }
        i -= 1
    }
}

private func gcmJ0(h: Array<Byte>, iv: Array<Byte>): Array<Byte> {
    if (iv.size == 12) {
        let out = Array<Byte>(16, repeat: 0)
        secureCopyInto(iv, out)
        out[15] = UInt8(1)
        return out
    }

    ghash(h, [], iv)
}

private func gcmJ0WithPair(hHi: UInt64, hLo: UInt64, iv: Array<Byte>): Array<Byte> {
    if (iv.size == 12) {
        let out = Array<Byte>(16, repeat: 0)
        secureCopyInto(iv, out)
        out[15] = UInt8(1)
        return out
    }

    ghashWithPair(hHi, hLo, [], iv)
}

private func gcmJ0WithTable(tableHi: Array<UInt64>, tableLo: Array<UInt64>, iv: Array<Byte>): Array<Byte> {
    if (iv.size == 12) {
        let out = Array<Byte>(16, repeat: 0)
        secureCopyInto(iv, out)
        out[15] = UInt8(1)
        return out
    }

    ghashWithTable(tableHi, tableLo, [], iv)
}

private func aesGcmEncryptWithContextSoftwareInto(
    ctx: AesGcmContext,
    iv: Array<Byte>,
    plaintext: Array<Byte>,
    aad: Array<Byte>,
    ciphertextOut: Array<Byte>,
    tagOut: Array<Byte>,
    tagLen: Int64
): Unit {
    let j0 = gcmJ0WithTable(ctx.ghashTableHi, ctx.ghashTableLo, iv)
    var sHi: UInt64 = 0
    var sLo: UInt64 = 0
    let (aadHi, aadLo) = ghashUpdatePairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo, aad)
    sHi = aadHi
    sLo = aadLo

    var counter = j0.clone()
    incrementCounter32Unchecked(counter)

    let keystream = zeroBlock()
    let state = Array<UInt8>(AES_BLOCK_SIZE, repeat: UInt8(0))
    var offset = 0
    let fullLimit = plaintext.size - (plaintext.size % AES_BLOCK_SIZE)
    while (offset < fullLimit) {
        encryptBlockWithScheduleIntoUnchecked(counter, ctx.schedule.roundKeys, ctx.schedule.nr, keystream)
        let plainHi = decodeUInt64BE(plaintext, offset)
        let plainLo = decodeUInt64BE(plaintext, offset + 8)
        let streamHi = decodeUInt64BE(keystream, 0)
        let streamLo = decodeUInt64BE(keystream, 8)
        let cipherHi = plainHi ^ streamHi
        let cipherLo = plainLo ^ streamLo
        encodeUInt64BE(ciphertextOut, offset, cipherHi)
        encodeUInt64BE(ciphertextOut, offset + 8, cipherLo)
        sHi = sHi ^ cipherHi
        sLo = sLo ^ cipherLo

        let (nextHi, nextLo) = gfMul128PairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo)
        sHi = nextHi
        sLo = nextLo
        incrementCounter32Unchecked(counter)
        offset += AES_BLOCK_SIZE
    }

    if (offset < plaintext.size) {
        encryptBlockWithScheduleIntoUnchecked(counter, ctx.schedule.roundKeys, ctx.schedule.nr, keystream)
        let take = plaintext.size - offset
        var i = 0
        var hiShift = Int64(56)
        var loShift = Int64(56)
        while (i < take) {
            let value = UInt8(plaintext[offset + i]) ^ UInt8(keystream[i])
            ciphertextOut[offset + i] = value
            if (i < 8) {
                sHi = sHi ^ (UInt64(value) << hiShift)
                hiShift -= 8
            } else {
                sLo = sLo ^ (UInt64(value) << loShift)
                loShift -= 8
            }
            i += 1
        }
        let (nextHi, nextLo) = gfMul128PairWithTableUnchecked(sHi, sLo, ctx.ghashTableHi, ctx.ghashTableLo)
        sHi = nextHi
        sLo = nextLo
    }

    let (hashHi, hashLo) = ghashFinalizePairWithTable(
        sHi,
        sLo,
        aad.size,
        ciphertextOut.size,
        ctx.ghashTableHi,
        ctx.ghashTableLo
    )
    encryptBlockWithScheduleIntoUnchecked(j0, ctx.schedule.roundKeys, ctx.schedule.nr, keystream)
    let tagHi = decodeUInt64BE(keystream, 0) ^ hashHi
    let tagLo = decodeUInt64BE(keystream, 8) ^ hashLo

    var i = 0
    var hiShift = Int64(56)
    var loShift = Int64(56)
    while (i < tagLen) {
        tagOut[i] = if (i < 8) {
            let value = UInt8((tagHi >> hiShift) & UInt64(0xff))
            hiShift -= 8
            value
        } else {
            let value = UInt8((tagLo >> loShift) & UInt64(0xff))
            loShift -= 8
            value
        }
        i += 1
    }
}

private func ghash(h: Array<Byte>, aad: Array<Byte>, cipher: Array<Byte>): Array<Byte> {
    requireBlock(h, "GHASH key")
    let (hHi, hLo) = readU64PairBE(h)
    ghashWithPair(hHi, hLo, aad, cipher)
}

private func ghashWithPair(hHi: UInt64, hLo: UInt64, aad: Array<Byte>, cipher: Array<Byte>): Array<Byte> {
    var x = zeroBlock()
    ghashUpdateWithPairInPlace(x, hHi, hLo, aad)
    ghashUpdateWithPairInPlace(x, hHi, hLo, cipher)
    ghashFinalizeWithPairInPlace(x, hHi, hLo, aad.size, cipher.size)
    x
}

private func ghashWithTable(tableHi: Array<UInt64>, tableLo: Array<UInt64>, aad: Array<Byte>, cipher: Array<Byte>): Array<Byte> {
    var x = zeroBlock()
    ghashUpdateWithTableInPlace(x, tableHi, tableLo, aad)
    ghashUpdateWithTableInPlace(x, tableHi, tableLo, cipher)
    ghashFinalizeWithTableInPlace(x, tableHi, tableLo, aad.size, cipher.size)
    x
}

@OverflowWrapping
private func ghashUpdatePairWithTableUnchecked(
    zHiInput: UInt64,
    zLoInput: UInt64,
    tableHi: Array<UInt64>,
    tableLo: Array<UInt64>,
    input: Array<Byte>
): (UInt64, UInt64) {
    var zHi = zHiInput
    var zLo = zLoInput
    var offset = 0
    let fullLimit = input.size - (input.size % AES_BLOCK_SIZE)

    while (offset < fullLimit) {
        zHi = zHi ^ decodeUInt64BE(input, offset)
        zLo = zLo ^ decodeUInt64BE(input, offset + 8)
        let (nextHi, nextLo) = gfMul128PairWithTableUnchecked(zHi, zLo, tableHi, tableLo)
        zHi = nextHi
        zLo = nextLo
        offset += AES_BLOCK_SIZE
    }

    if (offset < input.size) {
        var tailHi: UInt64 = 0
        var tailLo: UInt64 = 0
        let take = input.size - offset
        var i = 0
        var hiShift = Int64(56)
        var loShift = Int64(56)
        while (i < take) {
            let value = UInt64(UInt8(input[offset + i]))
            if (i < 8) {
                tailHi = tailHi ^ (value << hiShift)
                hiShift -= 8
            } else {
                tailLo = tailLo ^ (value << loShift)
                loShift -= 8
            }
            i += 1
        }
        zHi = zHi ^ tailHi
        zLo = zLo ^ tailLo
        let (nextHi, nextLo) = gfMul128PairWithTableUnchecked(zHi, zLo, tableHi, tableLo)
        zHi = nextHi
        zLo = nextLo
    }

    (zHi, zLo)
}

private func ghashUpdateInPlace(acc: Array<Byte>, h: Array<Byte>, input: Array<Byte>): Unit {
    requireBlock(h, "GHASH key")
    let (hHi, hLo) = readU64PairBE(h)
    ghashUpdateWithPairInPlace(acc, hHi, hLo, input)
}

private func ghashUpdateWithPairInPlace(acc: Array<Byte>, hHi: UInt64, hLo: UInt64, input: Array<Byte>): Unit {
    requireBlock(acc, "GHASH accumulator")
    var (zHi, zLo) = readU64PairBE(acc)
    var offset = 0

    while ((offset + AES_BLOCK_SIZE) <= input.size) {
        zHi = zHi ^ decodeUInt64BE(input, offset)
        zLo = zLo ^ decodeUInt64BE(input, offset + 8)
        let (nextHi, nextLo) = gfMul128Pair(zHi, zLo, hHi, hLo)
        zHi = nextHi
        zLo = nextLo
        offset += AES_BLOCK_SIZE
    }

    writeU64PairBE(acc, zHi, zLo)

    if (offset < input.size) {
        let take = input.size - offset
        var i = 0
        while (i < take) {
            acc[i] = UInt8(acc[i]) ^ UInt8(input[offset + i])
            i += 1
        }
        let (tailHi, tailLo) = readU64PairBE(acc)
        let (nextHi, nextLo) = gfMul128Pair(tailHi, tailLo, hHi, hLo)
        writeU64PairBE(acc, nextHi, nextLo)
    }
}

private func ghashUpdateWithTableInPlace(
    acc: Array<Byte>,
    tableHi: Array<UInt64>,
    tableLo: Array<UInt64>,
    input: Array<Byte>
): Unit {
    requireBlock(acc, "GHASH accumulator")
    requireGhashTable(tableHi, tableLo)

    var (zHi, zLo) = readU64PairBE(acc)
    var offset = 0

    while ((offset + AES_BLOCK_SIZE) <= input.size) {
        zHi = zHi ^ decodeUInt64BE(input, offset)
        zLo = zLo ^ decodeUInt64BE(input, offset + 8)
        let (nextHi, nextLo) = gfMul128PairWithTableUnchecked(zHi, zLo, tableHi, tableLo)
        zHi = nextHi
        zLo = nextLo
        offset += AES_BLOCK_SIZE
    }

    writeU64PairBE(acc, zHi, zLo)

    if (offset < input.size) {
        let take = input.size - offset
        var i = 0
        while (i < take) {
            acc[i] = UInt8(acc[i]) ^ UInt8(input[offset + i])
            i += 1
        }
        let (tailHi, tailLo) = readU64PairBE(acc)
        let (nextHi, nextLo) = gfMul128PairWithTableUnchecked(tailHi, tailLo, tableHi, tableLo)
        writeU64PairBE(acc, nextHi, nextLo)
    }
}

private func ghashFinalizeInPlace(acc: Array<Byte>, h: Array<Byte>, aadLen: Int64, cipherLen: Int64): Unit {
    requireBlock(h, "GHASH key")
    let (hHi, hLo) = readU64PairBE(h)
    ghashFinalizeWithPairInPlace(acc, hHi, hLo, aadLen, cipherLen)
}

private func ghashFinalizeWithPairInPlace(acc: Array<Byte>, hHi: UInt64, hLo: UInt64, aadLen: Int64, cipherLen: Int64): Unit {
    requireBlock(acc, "GHASH accumulator")
    let (zHi, zLo) = readU64PairBE(acc)
    let (nextHi, nextLo) = ghashFinalizePair(zHi, zLo, aadLen, cipherLen, hHi, hLo)
    writeU64PairBE(acc, nextHi, nextLo)
}

private func ghashFinalizeWithTableInPlace(
    acc: Array<Byte>,
    tableHi: Array<UInt64>,
    tableLo: Array<UInt64>,
    aadLen: Int64,
    cipherLen: Int64
): Unit {
    requireBlock(acc, "GHASH accumulator")
    let (zHi, zLo) = readU64PairBE(acc)
    let (nextHi, nextLo) = ghashFinalizePairWithTable(zHi, zLo, aadLen, cipherLen, tableHi, tableLo)
    writeU64PairBE(acc, nextHi, nextLo)
}

@OverflowWrapping
private func ghashFinalizePair(
    zHi: UInt64,
    zLo: UInt64,
    aadLen: Int64,
    cipherLen: Int64,
    hHi: UInt64,
    hLo: UInt64
): (UInt64, UInt64) {
    let aadBits = UInt64(aadLen) * UInt64(8)
    let cipherBits = UInt64(cipherLen) * UInt64(8)
    gfMul128Pair(zHi ^ aadBits, zLo ^ cipherBits, hHi, hLo)
}

@OverflowWrapping
private func ghashFinalizePairWithTable(
    zHi: UInt64,
    zLo: UInt64,
    aadLen: Int64,
    cipherLen: Int64,
    tableHi: Array<UInt64>,
    tableLo: Array<UInt64>
): (UInt64, UInt64) {
    let aadBits = UInt64(aadLen) * UInt64(8)
    let cipherBits = UInt64(cipherLen) * UInt64(8)
    gfMul128PairWithTableUnchecked(zHi ^ aadBits, zLo ^ cipherBits, tableHi, tableLo)
}

@OverflowWrapping
private func shiftForByteIndex(index: Int64): Int64 {
    56 - (index * 8)
}

private func xorFullBlockFromOffsetInPlace(dst: Array<Byte>, src: Array<Byte>, offset: Int64): Unit {
    if (dst.size != AES_BLOCK_SIZE) {
        throw CryptoException(InvalidArgument, "AES block length must be 16 bytes")
    }
    if (offset < 0 || (offset + AES_BLOCK_SIZE) > src.size) {
        throw CryptoException(OutOfBounds, "source block offset out of bounds")
    }
    xorFullBlockFromOffsetInPlaceUnchecked(dst, src, offset)
}

private func xorFullBlockFromOffsetInPlaceUnchecked(dst: Array<Byte>, src: Array<Byte>, offset: Int64): Unit {
    var i = 0
    while (i < AES_BLOCK_SIZE) {
        dst[i] = UInt8(dst[i]) ^ UInt8(src[offset + i])
        i += 1
    }
}

@OverflowWrapping
private func constantTimeTagEqualsPair(tag: Array<Byte>, hi: UInt64, lo: UInt64): Bool {
    var diff = UInt8(0)
    var i = 0
    while (i < tag.size) {
        let expected = if (i < 8) {
            UInt8((hi >> shiftForByteIndex(i)) & UInt64(0xff))
        } else {
            UInt8((lo >> shiftForByteIndex(i - 8)) & UInt64(0xff))
        }
        diff = diff | (UInt8(tag[i]) ^ expected)
        i += 1
    }
    diff == UInt8(0)
}

@OverflowWrapping
private func writeTagPrefixFromPair(out: Array<Byte>, hi: UInt64, lo: UInt64): Unit {
    var i = 0
    while (i < out.size) {
        out[i] = if (i < 8) {
            UInt8((hi >> shiftForByteIndex(i)) & UInt64(0xff))
        } else {
            UInt8((lo >> shiftForByteIndex(i - 8)) & UInt64(0xff))
        }
        i += 1
    }
}

private func encodeUInt64BE(out: Array<Byte>, offset: Int64, value: UInt64): Unit {
    out[offset] = UInt8((value >> 56) & UInt64(0xff))
    out[offset + 1] = UInt8((value >> 48) & UInt64(0xff))
    out[offset + 2] = UInt8((value >> 40) & UInt64(0xff))
    out[offset + 3] = UInt8((value >> 32) & UInt64(0xff))
    out[offset + 4] = UInt8((value >> 24) & UInt64(0xff))
    out[offset + 5] = UInt8((value >> 16) & UInt64(0xff))
    out[offset + 6] = UInt8((value >> 8) & UInt64(0xff))
    out[offset + 7] = UInt8(value & UInt64(0xff))
}

@OverflowWrapping
private func buildGhashTable(hHi: UInt64, hLo: UInt64): (Array<UInt64>, Array<UInt64>) {
    let tableHi = Array<UInt64>(GHASH_TABLE_SIZE, repeat: UInt64(0))
    let tableLo = Array<UInt64>(GHASH_TABLE_SIZE, repeat: UInt64(0))

    var byteIndex = 0
    while (byteIndex < GHASH_TABLE_BYTES) {
        let base = byteIndex * GHASH_TABLE_STRIDE
        var byteValue = 1
        while (byteValue < GHASH_TABLE_STRIDE) {
            var xHi: UInt64 = 0
            var xLo: UInt64 = 0
            if (byteIndex < 8) {
                xHi = UInt64(byteValue) << shiftForByteIndex(byteIndex)
            } else {
                xLo = UInt64(byteValue) << shiftForByteIndex(byteIndex - 8)
            }
            let (entryHi, entryLo) = gfMul128Pair(xHi, xLo, hHi, hLo)
            let index = base + byteValue
            tableHi[index] = entryHi
            tableLo[index] = entryLo
            byteValue += 1
        }
        byteIndex += 1
    }

    (tableHi, tableLo)
}

private func requireGhashTable(tableHi: Array<UInt64>, tableLo: Array<UInt64>): Unit {
    if (tableHi.size != GHASH_TABLE_SIZE || tableLo.size != GHASH_TABLE_SIZE) {
        throw CryptoException(InvalidArgument, "GHASH table length mismatch")
    }
}

@OverflowWrapping
private func gfMul128PairWithTable(
    xHi: UInt64,
    xLo: UInt64,
    tableHi: Array<UInt64>,
    tableLo: Array<UInt64>
): (UInt64, UInt64) {
    requireGhashTable(tableHi, tableLo)
    gfMul128PairWithTableUnchecked(xHi, xLo, tableHi, tableLo)
}

@OverflowWrapping
private func gfMul128PairWithTableUnchecked(
    xHi: UInt64,
    xLo: UInt64,
    tableHi: Array<UInt64>,
    tableLo: Array<UInt64>
): (UInt64, UInt64) {
    var zHi: UInt64 = 0
    var zLo: UInt64 = 0

    var tableIndex = Int64((xHi >> 56) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = GHASH_TABLE_STRIDE + Int64((xHi >> 48) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 2 * GHASH_TABLE_STRIDE + Int64((xHi >> 40) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 3 * GHASH_TABLE_STRIDE + Int64((xHi >> 32) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 4 * GHASH_TABLE_STRIDE + Int64((xHi >> 24) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 5 * GHASH_TABLE_STRIDE + Int64((xHi >> 16) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 6 * GHASH_TABLE_STRIDE + Int64((xHi >> 8) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 7 * GHASH_TABLE_STRIDE + Int64(xHi & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]

    tableIndex = 8 * GHASH_TABLE_STRIDE + Int64((xLo >> 56) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 9 * GHASH_TABLE_STRIDE + Int64((xLo >> 48) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 10 * GHASH_TABLE_STRIDE + Int64((xLo >> 40) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 11 * GHASH_TABLE_STRIDE + Int64((xLo >> 32) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 12 * GHASH_TABLE_STRIDE + Int64((xLo >> 24) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 13 * GHASH_TABLE_STRIDE + Int64((xLo >> 16) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 14 * GHASH_TABLE_STRIDE + Int64((xLo >> 8) & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]
    tableIndex = 15 * GHASH_TABLE_STRIDE + Int64(xLo & UInt64(0xff))
    zHi = zHi ^ tableHi[tableIndex]
    zLo = zLo ^ tableLo[tableIndex]

    (zHi, zLo)
}

@OverflowWrapping
private func gfMul128InPlace(x: Array<Byte>, y: Array<Byte>): Unit {
    requireBlock(x, "GF input")
    requireBlock(y, "GF input")
    let (vHi, vLo) = readU64PairBE(y)
    gfMul128WithPairInPlace(x, vHi, vLo)
}

@OverflowWrapping
private func gfMul128WithPairInPlace(x: Array<Byte>, yHi: UInt64, yLo: UInt64): Unit {
    requireBlock(x, "GF input")
    let (xHi, xLo) = readU64PairBE(x)
    let (zHi, zLo) = gfMul128Pair(xHi, xLo, yHi, yLo)
    writeU64PairBE(x, zHi, zLo)
}

@OverflowWrapping
private func gfMul128Pair(xHiInput: UInt64, xLoInput: UInt64, yHi: UInt64, yLo: UInt64): (UInt64, UInt64) {
    var xHi = xHiInput
    var xLo = xLoInput
    var vHi = yHi
    var vLo = yLo
    var zHi: UInt64 = 0
    var zLo: UInt64 = 0
    let reductionPoly = UInt64(0xe1) << 56

    var i = 0
    while (i < 128) {
        let bit = xHi >> 63
        let bitMask = UInt64(0) - bit
        zHi = zHi ^ (vHi & bitMask)
        zLo = zLo ^ (vLo & bitMask)

        let lsb = vLo & UInt64(0x01)
        vLo = (vLo >> 1) | (vHi << 63)
        vHi = vHi >> 1
        let lsbMask = UInt64(0) - lsb
        vHi = vHi ^ (reductionPoly & lsbMask)

        xHi = (xHi << 1) | (xLo >> 63)
        xLo = xLo << 1
        i += 1
    }

    (zHi, zLo)
}

@OverflowWrapping
private func readU64PairBE(block: Array<Byte>): (UInt64, UInt64) {
    (decodeUInt64BE(block, 0), decodeUInt64BE(block, 8))
}

@OverflowWrapping
private func writeU64PairBE(block: Array<Byte>, hi: UInt64, lo: UInt64): Unit {
    encodeUInt64BE(block, 0, hi)
    encodeUInt64BE(block, 8, lo)
}

@OverflowWrapping
private func decodeUInt64BE(input: Array<Byte>, offset: Int64): UInt64 {
    (UInt64(UInt8(input[offset])) << 56) |
    (UInt64(UInt8(input[offset + 1])) << 48) |
    (UInt64(UInt8(input[offset + 2])) << 40) |
    (UInt64(UInt8(input[offset + 3])) << 32) |
    (UInt64(UInt8(input[offset + 4])) << 24) |
    (UInt64(UInt8(input[offset + 5])) << 16) |
    (UInt64(UInt8(input[offset + 6])) << 8) |
    UInt64(UInt8(input[offset + 7]))
}
