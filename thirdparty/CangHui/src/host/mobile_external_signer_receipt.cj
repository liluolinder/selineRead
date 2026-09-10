package chui.host

import std.collection.ArrayList

/** Receipt emitted after a platform-owned signer reports package metadata. */
public const CANGHUI_MOBILE_EXTERNAL_SIGNER_RECEIPT_PROTOCOL =
    "canghui.mobile-external-signer-receipt.v0"

public enum MobileExternalSignerReceiptState <: Equatable<MobileExternalSignerReceiptState> {
    | Rejected
    | Accepted

    public operator func ==(other: MobileExternalSignerReceiptState): Bool {
        mobileExternalSignerReceiptStateName(this) == mobileExternalSignerReceiptStateName(other)
    }

    public operator func !=(other: MobileExternalSignerReceiptState): Bool {
        !(this == other)
    }
}

public func mobileExternalSignerReceiptStateName(
    state: MobileExternalSignerReceiptState
): String {
    match (state) {
        case MobileExternalSignerReceiptState.Rejected => "rejected"
        case MobileExternalSignerReceiptState.Accepted => "accepted"
    }
}

/** Non-secret signer output metadata. */
public struct MobileExternalSignerReceiptRequest {
    public let outputName: String
    public let signerTool: String
    public let signerIdentity: String
    public let provisioningProfile: String
    public let artifactDigest: String
    public let sourceBinding: String

    public init(
        outputName: String,
        signerTool: String,
        signerIdentity: String,
        provisioningProfile: String,
        artifactDigest: String,
        sourceBinding: String
    ) {
        validateExternalSignerLabel(outputName, "external signer output name", 255)
        validateExternalSignerLabel(signerTool, "external signer tool", 128)
        validateExternalSignerLabel(signerIdentity, "external signer identity", 128)
        validateExternalSignerLabel(provisioningProfile, "external signer profile", 128)
        validateExternalSignerLabel(sourceBinding, "external signer source binding", 256)
        validateExternalSignerDigest(artifactDigest)
        this.outputName = outputName
        this.signerTool = signerTool
        this.signerIdentity = signerIdentity
        this.provisioningProfile = provisioningProfile
        this.artifactDigest = artifactDigest
        this.sourceBinding = sourceBinding
    }
}

/**
 * Acceptance is deliberately weaker than package verification. The common
 * mobile package receipt stays at input-tree until a platform owner applies
 * independently verified signed-package evidence.
 */
public struct MobileExternalSignerReceipt {
    public let protocol: String
    public let platform: MobileApplicationPlatform
    public let packageKind: MobilePackageKind
    public let sourceStage: MobilePackageStage
    public let applicationId: String
    public let lifecycleEpoch: Int64
    public let surfaceGeneration: Int64
    public let state: MobileExternalSignerReceiptState
    public let outputName: String
    public let signerTool: String
    public let signerIdentity: String
    public let provisioningProfile: String
    public let artifactDigest: String
    public let sourceBinding: String
    public let limitations: Array<String>

    public init(
        source: MobileSigningPreparationReceipt,
        request: MobileExternalSignerReceiptRequest
    ) {
        this.protocol = CANGHUI_MOBILE_EXTERNAL_SIGNER_RECEIPT_PROTOCOL
        this.platform = source.platform
        this.packageKind = source.packageKind
        this.sourceStage = source.sourceStage
        this.applicationId = source.applicationId
        this.lifecycleEpoch = source.lifecycleEpoch
        this.surfaceGeneration = source.surfaceGeneration
        this.state = if (source.state == MobileSigningPreparationState.RequirementsSatisfied &&
            source.outputName == request.outputName && source.sourceBinding == request.sourceBinding) {
            MobileExternalSignerReceiptState.Accepted
        } else {
            MobileExternalSignerReceiptState.Rejected
        }
        this.outputName = request.outputName
        this.signerTool = request.signerTool
        this.signerIdentity = request.signerIdentity
        this.provisioningProfile = request.provisioningProfile
        this.artifactDigest = request.artifactDigest
        this.sourceBinding = request.sourceBinding
        this.limitations = externalSignerReceiptLimitations(source, request, this.state)
    }

    public func accepted(): Bool {
        state == MobileExternalSignerReceiptState.Accepted
    }

    public func advancesPackageReceipt(): Bool { false }

    public func toJson(): String {
        "{\"protocol\":\"" + protocol + "\",\"platform\":\"" +
            mobileApplicationPlatformName(platform) + "\",\"packageKind\":\"" +
            mobilePackageKindName(packageKind) + "\",\"sourceStage\":\"" +
            mobilePackageStageName(sourceStage) + "\",\"applicationId\":" +
            mobileExternalSignerQuote(applicationId) + ",\"lifecycleEpoch\":" + lifecycleEpoch.toString() +
            ",\"surfaceGeneration\":" + surfaceGeneration.toString() +
            ",\"state\":\"" + mobileExternalSignerReceiptStateName(state) +
            "\",\"outputName\":" + mobileExternalSignerQuote(outputName) + ",\"signerTool\":" +
            mobileExternalSignerQuote(signerTool) + ",\"signerIdentity\":" + mobileExternalSignerQuote(signerIdentity) +
            ",\"provisioningProfile\":" + mobileExternalSignerQuote(provisioningProfile) +
            ",\"artifactDigest\":" + mobileExternalSignerQuote(artifactDigest) +
            ",\"sourceBinding\":" + mobileExternalSignerQuote(sourceBinding) +
            ",\"limitations\":" + renderExternalSignerStrings(limitations) +
            ",\"signedPackage\":false,\"installable\":false,\"deviceProven\":false}"
    }
}

public func bindMobileExternalSignerReceipt(
    source: MobileSigningPreparationReceipt,
    request: MobileExternalSignerReceiptRequest
): MobileExternalSignerReceipt {
    MobileExternalSignerReceipt(source, request)
}

private func externalSignerReceiptLimitations(
    source: MobileSigningPreparationReceipt,
    request: MobileExternalSignerReceiptRequest,
    state: MobileExternalSignerReceiptState
): Array<String> {
    let limitations = ArrayList<String>()
    if (source.state != MobileSigningPreparationState.RequirementsSatisfied) {
        limitations.add("signing preparation requirements are incomplete")
    }
    if (source.outputName != request.outputName) {
        limitations.add("signer output name does not match preparation")
    }
    if (source.sourceBinding != request.sourceBinding) {
        limitations.add("signer source binding is stale or mismatched")
    }
    if (state == MobileExternalSignerReceiptState.Accepted) {
        limitations.add("accepted metadata does not verify a signature or package bytes")
    }
    limitations.add("common package receipt remains at input-tree")
    limitations.add("platform owner must independently verify signer output before signed-package")
    limitations.add("no certificate, key, profile content, password, path or command is accepted")
    limitations.toArray()
}

private func validateExternalSignerLabel(value: String, label: String, maxLength: Int64): Unit {
    if (value.isEmpty() || value.size > maxLength || value == "." || value == ".." ||
        !externalSignerSafeName(value)) {
        throw IllegalArgumentException(label + " must be a bounded opaque label")
    }
}

private func validateExternalSignerDigest(value: String): Unit {
    if (value.size != 71 || !value.startsWith("sha256:")) {
        throw IllegalArgumentException("external signer artifact digest must be sha256: plus 64 hex characters")
    }
    let runes = value.toRuneArray()
    for (i in 7..runes.size) {
        let r = runes[i]
        let lower = (r >= r'a' && r <= r'f') || (r >= r'0' && r <= r'9')
        if (!lower) { throw IllegalArgumentException("external signer artifact digest must use lowercase hex") }
    }
}

private func externalSignerSafeName(value: String): Bool {
    for (r in value.toRuneArray()) {
        let allowed = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') ||
            (r >= r'0' && r <= r'9') || r == r'.' || r == r'_' || r == r'-' || r == r':'
        if (!allowed) { return false }
    }
    true
}

private func renderExternalSignerStrings(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(mobileExternalSignerQuote(value))
    }
    out.append("]")
    out.toString()
}

private func mobileExternalSignerQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        match (r) {
            case r'\\' => out.append("\\\\")
            case r'"' => out.append("\\\"")
            case r'\n' => out.append("\\n")
            case r'\r' => out.append("\\r")
            case r'\t' => out.append("\\t")
            case _ => out.append(r.toString())
        }
    }
    out.append("\"")
    out.toString()
}
