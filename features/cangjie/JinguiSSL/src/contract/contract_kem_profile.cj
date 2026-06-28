package jinguissl.contract

import jinguissl_core.crypto.kem.{rsaKemRequireAllowed, ecdhKemRequireAllowed}
import jinguissl_core.crypto.compliance.FipsProfile

/**
 * ContractKemProfile — DTO that reports whether the KEM (Key Encapsulation
 * Mechanism) module is available. KEM is currently a post-quantum reserve
 * (ML-KEM / Kyber) with no active product roadmap in JinguiSSL.
 */
public class ContractKemProfile {
    public let available: Bool
    public let algoHint: String
    public let detail: String

    public init(
        available: Bool,
        algoHint: String,
        detail: String
    ) {
        if (algoHint.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "KEM profile algo hint must not be empty")
        }
        if (detail.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "KEM profile detail must not be empty")
        }
        this.available = available
        this.algoHint = algoHint.trimAscii()
        this.detail = detail.trimAscii()
    }
}

public class ContractKemProfileOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractKemProfile

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractKemProfile = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "KEM profile outcome message must not be empty"
            )
        }
        if (ok) {
            match (code) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "KEM profile outcome code must be empty when ok is true"
                    )
                case None => ()
            }
            match (igniteCode) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "KEM profile outcome ignite code must be empty when ok is true"
                    )
                case None => ()
            }
            match (result) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "KEM profile outcome result must exist when ok is true"
                    )
            }
        } else {
            match (code) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "KEM profile outcome code must exist when ok is false"
                    )
            }
            match (igniteCode) {
                case Some(_) => ()
                case None =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "KEM profile outcome ignite code must exist when ok is false"
                    )
            }
            match (result) {
                case Some(_) =>
                    throw ContractException(
                        ContractErrorCode.BadInput,
                        "KEM profile outcome result must be empty when ok is false"
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
 * contractKemProfile — probes whether the KEM module is linked and available.
 * Currently a placeholder: KEM is extracted in core but has no active PQC
 * roadmap in the product.
 */
public func contractKemProfile(): ContractKemProfile {
    try {
        let profile = FipsProfile()
        rsaKemRequireAllowed(profile)
        ContractKemProfile(
            true,
            "ml-kem",
            "KEM module is present in jinguissl-core (ML-KEM / Kyber reserve); PQC product roadmap is TBD"
        )
    } catch (e: ContractException) {
        throw e
    } catch (_: Exception) {
        ContractKemProfile(
            false,
            "ml-kem",
            "KEM module is unavailable in the current runtime; PQC product roadmap is TBD"
        )
    }
}

/**
 * contractTryKemProfile — non-throwing wrapper around contractKemProfile.
 */
public func contractTryKemProfile(): ContractKemProfileOutcome {
    try {
        let result = contractKemProfile()
        ContractKemProfileOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractKemProfileOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}
