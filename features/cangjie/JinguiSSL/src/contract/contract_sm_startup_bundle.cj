package jinguissl.contract

import jinguissl_core.crypto.sm3.sm3
import jinguissl_core.crypto.sm4.{sm4Encrypt, sm4Decrypt}

/**
 * ContractSmCapability — DTO that reports SM3 hash and SM4 cipher availability.
 */
public class ContractSmCapability {
    public let sm3Available: Bool
    public let sm4Available: Bool
    public let detail: String
    public let sm3DigestLen: Int64
    public let sm4BlockLen: Int64
    public let sm4KeyLen: Int64

    public init(
        sm3Available: Bool,
        sm4Available: Bool,
        detail: String,
        sm3DigestLen: Int64,
        sm4BlockLen: Int64,
        sm4KeyLen: Int64
    ) {
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "sm capability detail must not be empty")
        }
        if (sm3DigestLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "sm3 digest length must be positive")
        }
        if (sm4BlockLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "sm4 block length must be positive")
        }
        if (sm4KeyLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "sm4 key length must be positive")
        }
        this.sm3Available = sm3Available
        this.sm4Available = sm4Available
        this.detail = detail.trimAscii()
        this.sm3DigestLen = sm3DigestLen
        this.sm4BlockLen = sm4BlockLen
        this.sm4KeyLen = sm4KeyLen
    }
}

public class ContractSmCapabilityOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractSmCapability

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractSmCapability = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "sm capability outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ok outcome must not carry error code"
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

/**
 * contractSmCapability — reports SM3 hash and SM4 cipher availability
 * by probing the core implementations.
 */
public func contractSmCapability(): ContractSmCapability {
    var sm3Ok: Bool = false
    var sm4Ok: Bool = false
    try {
        let testSm3 = sm3(Array<Byte>(0, repeat: 0))
        sm3Ok = testSm3.size == Int64(32)
    } catch (_) {
        sm3Ok = false
    }
    try {
        let testSm4 = sm4Encrypt(
            Array<Byte>(16, repeat: 0),
            Array<Byte>(16, repeat: 0)
        )
        sm4Ok = testSm4.size == Int64(16)
    } catch (_) {
        sm4Ok = false
    }
    ContractSmCapability(
        sm3Ok,
        sm4Ok,
        "SM3 hash (GM/T 0004-2012) and SM4 ECB cipher (GM/T 0002-2012)",
        Int64(32),
        Int64(16),
        Int64(16)
    )
}

/**
 * contractTrySmCapability — non-throwing wrapper around contractSmCapability.
 */
public func contractTrySmCapability(): ContractSmCapabilityOutcome {
    try {
        let result = contractSmCapability()
        ContractSmCapabilityOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractSmCapabilityOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

/**
 * contractRequireSmCapability — throws if SM3 or SM4 module is unavailable.
 */
public func contractRequireSmCapability(): ContractSmCapability {
    let capability = contractSmCapability()
    if (!capability.sm3Available || !capability.sm4Available) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "SM capability is required but unavailable: ${capability.detail}"
        )
    }
    capability
}
