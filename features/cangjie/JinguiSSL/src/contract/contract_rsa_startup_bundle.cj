package jinguissl.contract

import jinguissl_core.crypto.rsa.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile

/**
 * ContractRsaCapability — DTO that reports RSA module availability,
 * supported key sizes, signature schemes, and hash algorithms.
 */
public class ContractRsaCapability {
    public let available: Bool
    public let detail: String
    public let supportedKeySizes: Array<Int64>
    public let supportedSchemes: Array<String>
    public let supportedHashAlgorithms: Array<String>
    public let rsaAllowed: Bool

    public init(
        available: Bool,
        detail: String,
        supportedKeySizes: Array<Int64>,
        supportedSchemes: Array<String>,
        supportedHashAlgorithms: Array<String>,
        rsaAllowed: Bool
    ) {
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "rsa capability detail must not be empty")
        }
        if (supportedKeySizes.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "rsa capability must report at least one key size")
        }
        if (supportedSchemes.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "rsa capability must report at least one scheme")
        }
        if (supportedHashAlgorithms.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "rsa capability must report at least one hash algorithm")
        }
        this.available = available
        this.detail = detail.trimAscii()
        this.supportedKeySizes = supportedKeySizes.clone()
        this.supportedSchemes = supportedSchemes.clone()
        this.supportedHashAlgorithms = supportedHashAlgorithms.clone()
        this.rsaAllowed = rsaAllowed
    }
}

public class ContractRsaCapabilityOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractRsaCapability

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractRsaCapability = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "rsa capability outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "rsa capability outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "rsa capability outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "rsa capability outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "rsa capability outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "rsa capability outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "rsa capability outcome result must be empty when ok is false"
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
 * contractRsaCapability — returns the RSA module capability, including
 * supported key sizes, signature schemes, and FIPS compliance status.
 */
public func contractRsaCapability(): ContractRsaCapability {
    try {
        let profile = FipsProfile.phase1Default()
        let rsaOk = try {
            rsaRequireAllowed(profile)
            true
        } catch (_: Exception) {
            false
        }

        let keySizes: Array<Int64> = [2048, 4096]
        let schemes: Array<String> = [RsaSignatureScheme.PKCS1v15.toString(), RsaSignatureScheme.PSS.toString()]
        let hashAlgos: Array<String> = [
            RsaHashAlgorithm.SHA1.toString(),
            RsaHashAlgorithm.SHA256.toString(),
            RsaHashAlgorithm.SHA384.toString(),
            RsaHashAlgorithm.SHA512.toString()
        ]

        ContractRsaCapability(
            true,
            "RSA module is available with ${keySizes.size} key sizes and ${schemes.size} schemes; FIPS=${rsaOk}",
            keySizes,
            schemes,
            hashAlgos,
            rsaOk
        )
    } catch (e: ContractException) {
        throw e
    } catch (_: Exception) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "RSA module is unavailable in the current runtime"
        )
    }
}

/**
 * contractTryRsaCapability — non-throwing wrapper around contractRsaCapability.
 */
public func contractTryRsaCapability(): ContractRsaCapabilityOutcome {
    try {
        let result = contractRsaCapability()
        ContractRsaCapabilityOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractRsaCapabilityOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

/**
 * contractRequireRsaCapability — throws if RSA module is unavailable.
 */
public func contractRequireRsaCapability(): ContractRsaCapability {
    let capability = contractRsaCapability()
    if (!capability.available) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "RSA capability is required but unavailable: ${capability.detail}"
        )
    }
    capability
}
