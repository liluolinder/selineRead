package jinguissl.contract

import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.compliance.FipsProfile

/**
 * ContractEccCapability — DTO that reports which elliptic curves are available
 * and whether ECDSA/ECDH operations comply with the active FIPS profile.
 */
public class ContractEccCapability {
    public let available: Bool
    public let detail: String
    public let supportedCurves: Array<String>
    public let fipsCurves: Array<String>
    public let ecdsaAllowed: Bool
    public let ecdhAllowed: Bool

    public init(
        available: Bool,
        detail: String,
        supportedCurves: Array<String>,
        fipsCurves: Array<String>,
        ecdsaAllowed: Bool,
        ecdhAllowed: Bool
    ) {
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "ecc capability detail must not be empty")
        }
        this.available = available
        this.detail = detail.trimAscii()
        this.supportedCurves = supportedCurves.clone()
        this.fipsCurves = fipsCurves.clone()
        this.ecdsaAllowed = ecdsaAllowed
        this.ecdhAllowed = ecdhAllowed
    }
}

public class ContractEccCapabilityOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractEccCapability

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractEccCapability = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "ecc capability outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ecc capability outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ecc capability outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ecc capability outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ecc capability outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ecc capability outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "ecc capability outcome result must be empty when ok is false"
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
 * contractEccCapability — returns the ECC module capability, including
 * available curves and whether ECDSA/ECDH operations are allowed.
 */
public func contractEccCapability(): ContractEccCapability {
    try {
        let profile = FipsProfile.phase1Default()
        let allCurves: Array<String> = ["P-256", "P-384", "P-521", "secp256k1"]
        let fipsCurves: Array<String> = ["P-256", "P-384", "P-521"]
        let ecdsaOk = try {
            ecdsaRequireAllowed(profile)
            true
        } catch (_: Exception) {
            false
        }
        let ecdhOk = try {
            ecdhRequireAllowed(profile)
            true
        } catch (_: Exception) {
            false
        }

        ContractEccCapability(
            true,
            "ECC module is available with ${allCurves.size} curves; ECDSA=${ecdsaOk}, ECDH=${ecdhOk}",
            allCurves,
            fipsCurves,
            ecdsaOk,
            ecdhOk
        )
    } catch (e: ContractException) {
        throw e
    } catch (_: Exception) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "ECC module is unavailable in the current runtime"
        )
    }
}

/**
 * contractTryEccCapability — non-throwing wrapper around contractEccCapability.
 */
public func contractTryEccCapability(): ContractEccCapabilityOutcome {
    try {
        let result = contractEccCapability()
        ContractEccCapabilityOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractEccCapabilityOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

/**
 * contractRequireEccCapability — throws if ECC module is unavailable.
 */
public func contractRequireEccCapability(): ContractEccCapability {
    let capability = contractEccCapability()
    if (!capability.available) {
        throw ContractException(
            ContractErrorCode.CryptoUnavailable,
            "ECC capability is required but unavailable: ${capability.detail}"
        )
    }
    capability
}
