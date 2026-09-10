package chui.host

import std.collection.ArrayList

/** Receipt for applying a platform-owned signed-package verification result. */
public const CANGHUI_MOBILE_SIGNED_PACKAGE_EVIDENCE_PROTOCOL =
    "canghui.mobile-signed-package-evidence.v0"

public enum MobileSignedPackageVerificationOutcome <:
    Equatable<MobileSignedPackageVerificationOutcome> {
    | Failed
    | Passed

    public operator func ==(other: MobileSignedPackageVerificationOutcome): Bool {
        mobileSignedPackageVerificationOutcomeName(this) ==
            mobileSignedPackageVerificationOutcomeName(other)
    }

    public operator func !=(other: MobileSignedPackageVerificationOutcome): Bool {
        !(this == other)
    }
}

public func mobileSignedPackageVerificationOutcomeName(
    outcome: MobileSignedPackageVerificationOutcome
): String {
    match (outcome) {
        case MobileSignedPackageVerificationOutcome.Failed => "failed"
        case MobileSignedPackageVerificationOutcome.Passed => "passed"
    }
}

public enum MobileSignedPackageEvidenceState <: Equatable<MobileSignedPackageEvidenceState> {
    | Rejected
    | Applied

    public operator func ==(other: MobileSignedPackageEvidenceState): Bool {
        mobileSignedPackageEvidenceStateName(this) == mobileSignedPackageEvidenceStateName(other)
    }

    public operator func !=(other: MobileSignedPackageEvidenceState): Bool {
        !(this == other)
    }
}

public func mobileSignedPackageEvidenceStateName(
    state: MobileSignedPackageEvidenceState
): String {
    match (state) {
        case MobileSignedPackageEvidenceState.Rejected => "rejected"
        case MobileSignedPackageEvidenceState.Applied => "applied"
    }
}

/**
 * Non-secret output from a platform-owner-controlled verification step.
 * Labels identify policy and tool receipts; they are not paths or commands.
 */
public struct MobileSignedPackageEvidenceRequest {
    public let outputName: String
    public let platformOwner: String
    public let verifierTool: String
    public let verificationPolicy: String
    public let verificationReceiptId: String
    public let artifactDigest: String
    public let artifactSize: Int64
    public let sourceBinding: String
    public let outcome: MobileSignedPackageVerificationOutcome

    public init(
        outputName: String,
        platformOwner: String,
        verifierTool: String,
        verificationPolicy: String,
        verificationReceiptId: String,
        artifactDigest: String,
        artifactSize: Int64,
        sourceBinding: String,
        outcome: MobileSignedPackageVerificationOutcome
    ) {
        validateSignedPackageEvidenceLabel(outputName, "signed package output name", 255)
        validateSignedPackageEvidenceLabel(platformOwner, "signed package platform owner", 128)
        validateSignedPackageEvidenceLabel(verifierTool, "signed package verifier tool", 128)
        validateSignedPackageEvidenceLabel(verificationPolicy, "signed package verification policy", 128)
        validateSignedPackageEvidenceLabel(
            verificationReceiptId,
            "signed package verification receipt id",
            128
        )
        validateSignedPackageEvidenceDigest(artifactDigest)
        if (artifactSize <= 0) {
            throw IllegalArgumentException("signed package artifact size must be positive")
        }
        validateSignedPackageEvidenceLabel(sourceBinding, "signed package source binding", 256)
        this.outputName = outputName
        this.platformOwner = platformOwner
        this.verifierTool = verifierTool
        this.verificationPolicy = verificationPolicy
        this.verificationReceiptId = verificationReceiptId
        this.artifactDigest = artifactDigest
        this.artifactSize = artifactSize
        this.sourceBinding = sourceBinding
        this.outcome = outcome
    }
}

/**
 * An applied receipt advances input-tree to signed-package only. It does not
 * execute a verifier or prove installation, launch, rendering, or device use.
 */
public struct MobileSignedPackageEvidenceReceipt {
    public let protocol: String
    public let platform: MobileApplicationPlatform
    public let packageKind: MobilePackageKind
    public let sourceStage: MobilePackageStage
    public let applicationId: String
    public let lifecycleEpoch: Int64
    public let surfaceGeneration: Int64
    public let state: MobileSignedPackageEvidenceState
    public let outcome: MobileSignedPackageVerificationOutcome
    public let outputName: String
    public let platformOwner: String
    public let verifierTool: String
    public let verificationPolicy: String
    public let verificationReceiptId: String
    public let artifactDigest: String
    public let artifactSize: Int64
    public let sourceBinding: String
    public let limitations: Array<String>
    private let sourceInputFiles: Array<String>

    public init(
        source: MobileHostPackageReceipt,
        signer: MobileExternalSignerReceipt,
        request: MobileSignedPackageEvidenceRequest
    ) {
        this.protocol = CANGHUI_MOBILE_SIGNED_PACKAGE_EVIDENCE_PROTOCOL
        this.platform = source.platform
        this.packageKind = source.packageKind
        this.sourceStage = source.stage
        this.applicationId = source.applicationId
        this.lifecycleEpoch = source.lifecycleEpoch
        this.surfaceGeneration = source.surfaceGeneration
        this.state = if (signedPackageEvidenceMatches(source, signer, request)) {
            MobileSignedPackageEvidenceState.Applied
        } else {
            MobileSignedPackageEvidenceState.Rejected
        }
        this.outcome = request.outcome
        this.outputName = request.outputName
        this.platformOwner = request.platformOwner
        this.verifierTool = request.verifierTool
        this.verificationPolicy = request.verificationPolicy
        this.verificationReceiptId = request.verificationReceiptId
        this.artifactDigest = request.artifactDigest
        this.artifactSize = request.artifactSize
        this.sourceBinding = request.sourceBinding
        this.limitations = signedPackageEvidenceLimitations(source, signer, request, this.state)
        this.sourceInputFiles = source.inputFiles
    }

    public func applied(): Bool { state == MobileSignedPackageEvidenceState.Applied }

    public func advancesPackageReceipt(): Bool { applied() }

    func matchesSourceInputFiles(values: Array<String>): Bool {
        sameSignedPackageStrings(sourceInputFiles, values)
    }

    func matchesSignedPackageReceipt(source: MobileHostPackageReceipt): Bool {
        applied() && source.platform == platform && source.packageKind == packageKind &&
            source.stage == MobilePackageStage.SignedPackage &&
            source.signing == MobileSigningState.Signed &&
            source.deviceProof == MobileDeviceProofState.NotRun &&
            source.applicationId == applicationId && source.lifecycleEpoch == lifecycleEpoch &&
            source.surfaceGeneration == surfaceGeneration &&
            mobileSigningSourceBinding(source) == sourceBinding &&
            matchesSourceInputFiles(source.inputFiles)
    }

    public func toJson(): String {
        let advanced = if (applied()) { "true" } else { "false" }
        "{\"protocol\":\"" + protocol + "\",\"platform\":\"" +
            mobileApplicationPlatformName(platform) + "\",\"packageKind\":\"" +
            mobilePackageKindName(packageKind) + "\",\"sourceStage\":\"" +
            mobilePackageStageName(sourceStage) + "\",\"applicationId\":" +
            mobileSignedPackageQuote(applicationId) + ",\"lifecycleEpoch\":" +
            lifecycleEpoch.toString() + ",\"surfaceGeneration\":" +
            surfaceGeneration.toString() + ",\"state\":\"" +
            mobileSignedPackageEvidenceStateName(state) + "\",\"outcome\":\"" +
            mobileSignedPackageVerificationOutcomeName(outcome) + "\",\"outputName\":" +
            mobileSignedPackageQuote(outputName) + ",\"platformOwner\":" +
            mobileSignedPackageQuote(platformOwner) + ",\"verifierTool\":" +
            mobileSignedPackageQuote(verifierTool) + ",\"verificationPolicy\":" +
            mobileSignedPackageQuote(verificationPolicy) + ",\"verificationReceiptId\":" +
            mobileSignedPackageQuote(verificationReceiptId) + ",\"artifactDigest\":" +
            mobileSignedPackageQuote(artifactDigest) + ",\"artifactSize\":" +
            artifactSize.toString() + ",\"sourceBinding\":" +
            mobileSignedPackageQuote(sourceBinding) + ",\"limitations\":" +
            renderMobileSignedPackageStrings(limitations) + ",\"signedPackage\":" + advanced +
            ",\"installable\":" + advanced +
            ",\"installationProven\":false,\"deviceProven\":false}"
    }
}

public func verifyMobileSignedPackageEvidence(
    source: MobileHostPackageReceipt,
    signer: MobileExternalSignerReceipt,
    request: MobileSignedPackageEvidenceRequest
): MobileSignedPackageEvidenceReceipt {
    MobileSignedPackageEvidenceReceipt(source, signer, request)
}

/** Advance a fresh input-tree receipt after the evidence receipt was applied. */
public func advanceMobileSignedPackageReceipt(
    source: MobileHostPackageReceipt,
    evidence: MobileSignedPackageEvidenceReceipt
): MobileHostPackageReceipt {
    if (!evidence.applied() || source.platform != evidence.platform ||
        source.packageKind != evidence.packageKind || source.stage != MobilePackageStage.InputTree ||
        source.signing != MobileSigningState.Unsigned || source.applicationId != evidence.applicationId ||
        source.lifecycleEpoch != evidence.lifecycleEpoch ||
        source.surfaceGeneration != evidence.surfaceGeneration ||
        mobileSigningSourceBinding(source) != evidence.sourceBinding ||
        !evidence.matchesSourceInputFiles(source.inputFiles)) {
        throw IllegalArgumentException("signed package evidence is rejected or stale")
    }
    MobileHostPackageReceipt(
        source.platform,
        source.packageKind,
        MobilePackageStage.SignedPackage,
        source.applicationId,
        source.lifecycleState,
        source.lifecycleEpoch,
        source.surfaceGeneration,
        signing: MobileSigningState.Signed,
        deviceProof: MobileDeviceProofState.NotRun,
        permissions: source.permissions,
        inputFiles: source.inputFiles,
        limitations: advancedSignedPackageLimitations(source.limitations)
    )
}

private func signedPackageEvidenceMatches(
    source: MobileHostPackageReceipt,
    signer: MobileExternalSignerReceipt,
    request: MobileSignedPackageEvidenceRequest
): Bool {
    source.stage == MobilePackageStage.InputTree &&
        source.signing == MobileSigningState.Unsigned && signer.accepted() &&
        signer.platform == source.platform && signer.packageKind == source.packageKind &&
        signer.sourceStage == source.stage && signer.applicationId == source.applicationId &&
        signer.lifecycleEpoch == source.lifecycleEpoch &&
        signer.surfaceGeneration == source.surfaceGeneration &&
        signer.outputName == request.outputName && signer.artifactDigest == request.artifactDigest &&
        signer.sourceBinding == request.sourceBinding &&
        mobileSigningSourceBinding(source) == request.sourceBinding &&
        request.outcome == MobileSignedPackageVerificationOutcome.Passed
}

private func signedPackageEvidenceLimitations(
    source: MobileHostPackageReceipt,
    signer: MobileExternalSignerReceipt,
    request: MobileSignedPackageEvidenceRequest,
    state: MobileSignedPackageEvidenceState
): Array<String> {
    let limitations = ArrayList<String>()
    if (source.stage != MobilePackageStage.InputTree || source.signing != MobileSigningState.Unsigned) {
        limitations.add("source receipt must be an unsigned input-tree")
    }
    if (!signer.accepted()) { limitations.add("external signer metadata receipt is not accepted") }
    if (signer.platform != source.platform || signer.packageKind != source.packageKind ||
        signer.applicationId != source.applicationId) {
        limitations.add("signer receipt package identity does not match source")
    }
    if (signer.lifecycleEpoch != source.lifecycleEpoch ||
        signer.surfaceGeneration != source.surfaceGeneration ||
        signer.sourceBinding != request.sourceBinding ||
        mobileSigningSourceBinding(source) != request.sourceBinding) {
        limitations.add("signed package evidence binding is stale or mismatched")
    }
    if (signer.outputName != request.outputName || signer.artifactDigest != request.artifactDigest) {
        limitations.add("verified artifact does not match signer output")
    }
    if (request.outcome != MobileSignedPackageVerificationOutcome.Passed) {
        limitations.add("platform verification outcome did not pass")
    }
    if (state == MobileSignedPackageEvidenceState.Applied) {
        limitations.add("platform owner attests that an external verifier checked the signed artifact")
    }
    limitations.add("CangHui does not execute the signer or verifier")
    limitations.add("installable means eligible for an installation attempt, not installed")
    limitations.add("installation, launch, rendering and device replay remain separate evidence")
    limitations.toArray()
}

private func advancedSignedPackageLimitations(values: Array<String>): Array<String> {
    let limitations = ArrayList<String>()
    for (value in values) { limitations.add(value) }
    limitations.add("signed package evidence applied by an external platform owner")
    limitations.add("installation and device proof remain open")
    limitations.toArray()
}

private func sameSignedPackageStrings(left: Array<String>, right: Array<String>): Bool {
    if (left.size != right.size) { return false }
    for (i in 0..left.size) {
        if (left[i] != right[i]) { return false }
    }
    true
}

private func validateSignedPackageEvidenceLabel(value: String, label: String, maxLength: Int64): Unit {
    if (value.isEmpty() || value.size > maxLength || value == "." || value == ".." ||
        !mobileSignedPackageSafeName(value)) {
        throw IllegalArgumentException(label + " must be a bounded opaque label")
    }
}

private func validateSignedPackageEvidenceDigest(value: String): Unit {
    if (value.size != 71 || !value.startsWith("sha256:")) {
        throw IllegalArgumentException("signed package artifact digest must be sha256: plus 64 hex characters")
    }
    let runes = value.toRuneArray()
    for (i in 7..runes.size) {
        let r = runes[i]
        if (!((r >= r'a' && r <= r'f') || (r >= r'0' && r <= r'9'))) {
            throw IllegalArgumentException("signed package artifact digest must use lowercase hex")
        }
    }
}

private func mobileSignedPackageSafeName(value: String): Bool {
    for (r in value.toRuneArray()) {
        let allowed = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') ||
            (r >= r'0' && r <= r'9') || r == r'.' || r == r'_' || r == r'-' || r == r':'
        if (!allowed) { return false }
    }
    true
}

private func renderMobileSignedPackageStrings(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(mobileSignedPackageQuote(value))
    }
    out.append("]")
    out.toString()
}

private func mobileSignedPackageQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        match (r) {
            case r'\\' => out.append("\\\\")
            case r'\"' => out.append("\\\"")
            case r'\n' => out.append("\\n")
            case r'\r' => out.append("\\r")
            case r'\t' => out.append("\\t")
            case _ => out.append(r.toString())
        }
    }
    out.append("\"")
    out.toString()
}
