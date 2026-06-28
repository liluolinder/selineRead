package jinguissl.contract

import jinguissl_core.crypto.ed25519.{
    ED25519_SEED_LEN,
    ED25519_PUBLIC_KEY_LEN,
    ED25519_SIGNATURE_LEN,
    ed25519GeneratePrivateKeySeed,
    ed25519PublicKeyFromSeed,
    ed25519Sign,
    ed25519Verify
}

/**
 * ContractEd25519SigningCapability — DTO that reports whether Ed25519 signing
 * is available in the current runtime and what key/signature sizes to expect.
 */
public class ContractEd25519SigningCapability {
    public let available: Bool
    public let detail: String
    public let seedLen: Int64
    public let pubKeyLen: Int64
    public let sigLen: Int64

    public init(
        available: Bool,
        detail: String,
        seedLen: Int64,
        pubKeyLen: Int64,
        sigLen: Int64
    ) {
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "ed25519 signing capability detail must not be empty")
        }
        if (seedLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "ed25519 seed length must be positive")
        }
        if (pubKeyLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "ed25519 public key length must be positive")
        }
        if (sigLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "ed25519 signature length must be positive")
        }
        this.available = available
        this.detail = detail.trimAscii()
        this.seedLen = seedLen
        this.pubKeyLen = pubKeyLen
        this.sigLen = sigLen
    }
}

public class ContractEd25519SigningCapabilityOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractEd25519SigningCapability

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractEd25519SigningCapability = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "ed25519 signing capability outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ed25519 signing capability outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ed25519 signing capability outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ed25519 signing capability outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ed25519 signing capability outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ed25519 signing capability outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ed25519 signing capability outcome result must be empty when ok is false"
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
 * contractEd25519SigningCapability — checks that the Ed25519 module is
 * available and returns key/signature size constants without generating keys.
 */
public func contractEd25519SigningCapability(): ContractEd25519SigningCapability {
    try {
        let seed = ed25519GeneratePrivateKeySeed()
        let available = seed.size == ED25519_SEED_LEN
        ContractEd25519SigningCapability(
            available,
            if (available) {
                "ed25519 module is available; key generation, signing, and verify are operational"
            } else {
                "ed25519 module reported unexpected seed size"
            },
            ED25519_SEED_LEN,
            ED25519_PUBLIC_KEY_LEN,
            ED25519_SIGNATURE_LEN
        )
    } catch (e: ContractException) {
        throw e
    } catch (_: Exception) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "ed25519 module is unavailable in the current runtime"
        )
    }
}

/**
 * contractTryEd25519SigningCapability — non-throwing wrapper around
 * contractEd25519SigningCapability.
 */
public func contractTryEd25519SigningCapability(): ContractEd25519SigningCapabilityOutcome {
    try {
        let result = contractEd25519SigningCapability()
        ContractEd25519SigningCapabilityOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractEd25519SigningCapabilityOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

/**
 * contractRequireEd25519SigningCapability — throws if ed25519 is unavailable.
 */
public func contractRequireEd25519SigningCapability(): ContractEd25519SigningCapability {
    let capability = contractEd25519SigningCapability()
    if (!capability.available) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "ed25519 signing capability is required but unavailable: ${capability.detail}"
        )
    }
    capability
}
