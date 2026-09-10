package chui.host

import std.collection.ArrayList

/** Receipt for one platform-owner-controlled installation attempt. */
public const CANGHUI_MOBILE_INSTALLATION_ATTEMPT_PROTOCOL =
    "canghui.mobile-installation-attempt.v0"

public enum MobileInstallationAttemptOutcome <: Equatable<MobileInstallationAttemptOutcome> {
    | Failed
    | Installed

    public operator func ==(other: MobileInstallationAttemptOutcome): Bool {
        mobileInstallationAttemptOutcomeName(this) == mobileInstallationAttemptOutcomeName(other)
    }

    public operator func !=(other: MobileInstallationAttemptOutcome): Bool {
        !(this == other)
    }
}

public func mobileInstallationAttemptOutcomeName(
    outcome: MobileInstallationAttemptOutcome
): String {
    match (outcome) {
        case MobileInstallationAttemptOutcome.Failed => "failed"
        case MobileInstallationAttemptOutcome.Installed => "installed"
    }
}

public enum MobileInstallationAttemptState <: Equatable<MobileInstallationAttemptState> {
    | Rejected
    | Recorded

    public operator func ==(other: MobileInstallationAttemptState): Bool {
        mobileInstallationAttemptStateName(this) == mobileInstallationAttemptStateName(other)
    }

    public operator func !=(other: MobileInstallationAttemptState): Bool {
        !(this == other)
    }
}

public func mobileInstallationAttemptStateName(state: MobileInstallationAttemptState): String {
    match (state) {
        case MobileInstallationAttemptState.Rejected => "rejected"
        case MobileInstallationAttemptState.Recorded => "recorded"
    }
}

public enum MobileInstallationTargetClass <: Equatable<MobileInstallationTargetClass> {
    | PhysicalDevice
    | SimulatorOrEmulator
    | ManagedDevicePool

    public operator func ==(other: MobileInstallationTargetClass): Bool {
        mobileInstallationTargetClassName(this) == mobileInstallationTargetClassName(other)
    }

    public operator func !=(other: MobileInstallationTargetClass): Bool {
        !(this == other)
    }
}

public func mobileInstallationTargetClassName(value: MobileInstallationTargetClass): String {
    match (value) {
        case MobileInstallationTargetClass.PhysicalDevice => "physical-device"
        case MobileInstallationTargetClass.SimulatorOrEmulator => "simulator-or-emulator"
        case MobileInstallationTargetClass.ManagedDevicePool => "managed-device-pool"
    }
}

/**
 * Non-secret metadata emitted by a platform-owned installer boundary.
 * Device identity is intentionally reduced to a closed class value.
 */
public struct MobileInstallationAttemptRequest {
    public let outputName: String
    public let platformOwner: String
    public let targetDeviceClass: MobileInstallationTargetClass
    public let installerTool: String
    public let installationPolicy: String
    public let installationReceiptId: String
    public let artifactDigest: String
    public let artifactSize: Int64
    public let outcome: MobileInstallationAttemptOutcome

    public init(
        outputName: String,
        platformOwner: String,
        targetDeviceClass: MobileInstallationTargetClass,
        installerTool: String,
        installationPolicy: String,
        installationReceiptId: String,
        artifactDigest: String,
        artifactSize: Int64,
        outcome: MobileInstallationAttemptOutcome
    ) {
        validateInstallationAttemptLabel(outputName, "installation output name", 255)
        validateInstallationAttemptLabel(platformOwner, "installation platform owner", 128)
        validateInstallationAttemptLabel(installerTool, "installation installer tool", 128)
        validateInstallationAttemptLabel(installationPolicy, "installation policy", 128)
        validateInstallationAttemptLabel(
            installationReceiptId,
            "installation receipt id",
            128
        )
        validateInstallationAttemptDigest(artifactDigest)
        if (artifactSize <= 0) {
            throw IllegalArgumentException("installation artifact size must be positive")
        }
        this.outputName = outputName
        this.platformOwner = platformOwner
        this.targetDeviceClass = targetDeviceClass
        this.installerTool = installerTool
        this.installationPolicy = installationPolicy
        this.installationReceiptId = installationReceiptId
        this.artifactDigest = artifactDigest
        this.artifactSize = artifactSize
        this.outcome = outcome
    }
}

/**
 * A recorded receipt proves only the platform owner's reported installer result.
 * It never proves launch, rendering, semantic replay or complete device use.
 */
public struct MobileInstallationAttemptReceipt {
    public let protocol: String
    public let platform: MobileApplicationPlatform
    public let packageKind: MobilePackageKind
    public let sourceStage: MobilePackageStage
    public let applicationId: String
    public let lifecycleEpoch: Int64
    public let surfaceGeneration: Int64
    public let state: MobileInstallationAttemptState
    public let outcome: MobileInstallationAttemptOutcome
    public let outputName: String
    public let platformOwner: String
    public let targetDeviceClass: MobileInstallationTargetClass
    public let installerTool: String
    public let installationPolicy: String
    public let installationReceiptId: String
    public let artifactDigest: String
    public let artifactSize: Int64
    public let limitations: Array<String>

    public init(
        source: MobileHostPackageReceipt,
        evidence: MobileSignedPackageEvidenceReceipt,
        request: MobileInstallationAttemptRequest
    ) {
        this.protocol = CANGHUI_MOBILE_INSTALLATION_ATTEMPT_PROTOCOL
        this.platform = source.platform
        this.packageKind = source.packageKind
        this.sourceStage = source.stage
        this.applicationId = source.applicationId
        this.lifecycleEpoch = source.lifecycleEpoch
        this.surfaceGeneration = source.surfaceGeneration
        this.state = if (installationAttemptMatches(source, evidence, request)) {
            MobileInstallationAttemptState.Recorded
        } else {
            MobileInstallationAttemptState.Rejected
        }
        this.outcome = request.outcome
        this.outputName = request.outputName
        this.platformOwner = request.platformOwner
        this.targetDeviceClass = request.targetDeviceClass
        this.installerTool = request.installerTool
        this.installationPolicy = request.installationPolicy
        this.installationReceiptId = request.installationReceiptId
        this.artifactDigest = request.artifactDigest
        this.artifactSize = request.artifactSize
        this.limitations = installationAttemptLimitations(source, evidence, request, this.state)
    }

    public func recorded(): Bool { state == MobileInstallationAttemptState.Recorded }

    public func installed(): Bool {
        recorded() && outcome == MobileInstallationAttemptOutcome.Installed
    }

    public func installationProven(): Bool { installed() }

    public func advancesPackageReceipt(): Bool { false }

    public func toJson(): String {
        let recordedValue = if (recorded()) { "true" } else { "false" }
        let installedValue = if (installed()) { "true" } else { "false" }
        "{\"protocol\":\"" + protocol + "\",\"platform\":\"" +
            mobileApplicationPlatformName(platform) + "\",\"packageKind\":\"" +
            mobilePackageKindName(packageKind) + "\",\"sourceStage\":\"" +
            mobilePackageStageName(sourceStage) + "\",\"applicationId\":" +
            mobileInstallationAttemptQuote(applicationId) + ",\"lifecycleEpoch\":" +
            lifecycleEpoch.toString() + ",\"surfaceGeneration\":" +
            surfaceGeneration.toString() + ",\"state\":\"" +
            mobileInstallationAttemptStateName(state) + "\",\"outcome\":\"" +
            mobileInstallationAttemptOutcomeName(outcome) + "\",\"outputName\":" +
            mobileInstallationAttemptQuote(outputName) + ",\"platformOwner\":" +
            mobileInstallationAttemptQuote(platformOwner) + ",\"targetDeviceClass\":\"" +
            mobileInstallationTargetClassName(targetDeviceClass) + "\",\"installerTool\":" +
            mobileInstallationAttemptQuote(installerTool) + ",\"installationPolicy\":" +
            mobileInstallationAttemptQuote(installationPolicy) + ",\"installationReceiptId\":" +
            mobileInstallationAttemptQuote(installationReceiptId) + ",\"artifactDigest\":" +
            mobileInstallationAttemptQuote(artifactDigest) + ",\"artifactSize\":" +
            artifactSize.toString() + ",\"limitations\":" +
            renderMobileInstallationAttemptStrings(limitations) + ",\"recorded\":" +
            recordedValue + ",\"installed\":" + installedValue +
            ",\"installationProven\":" + installedValue +
            ",\"launchProven\":false,\"renderingProven\":false,\"deviceProven\":false}"
    }
}

public func recordMobileInstallationAttempt(
    source: MobileHostPackageReceipt,
    evidence: MobileSignedPackageEvidenceReceipt,
    request: MobileInstallationAttemptRequest
): MobileInstallationAttemptReceipt {
    MobileInstallationAttemptReceipt(source, evidence, request)
}

private func installationAttemptMatches(
    source: MobileHostPackageReceipt,
    evidence: MobileSignedPackageEvidenceReceipt,
    request: MobileInstallationAttemptRequest
): Bool {
    evidence.applied() && evidence.matchesSignedPackageReceipt(source) &&
        request.outputName == evidence.outputName &&
        request.platformOwner == evidence.platformOwner &&
        request.artifactDigest == evidence.artifactDigest &&
        request.artifactSize == evidence.artifactSize
}

private func installationAttemptLimitations(
    source: MobileHostPackageReceipt,
    evidence: MobileSignedPackageEvidenceReceipt,
    request: MobileInstallationAttemptRequest,
    state: MobileInstallationAttemptState
): Array<String> {
    let limitations = ArrayList<String>()
    if (!evidence.applied() || !evidence.matchesSignedPackageReceipt(source)) {
        limitations.add("signed package evidence is rejected, stale or rooted in a different input tree")
    }
    if (request.outputName != evidence.outputName || request.artifactDigest != evidence.artifactDigest ||
        request.artifactSize != evidence.artifactSize) {
        limitations.add("installation artifact does not match signed package evidence")
    }
    if (request.platformOwner != evidence.platformOwner) {
        limitations.add("installation platform owner does not match signed package evidence")
    }
    if (state == MobileInstallationAttemptState.Recorded &&
        request.outcome == MobileInstallationAttemptOutcome.Failed) {
        limitations.add("platform installer reported a failed installation attempt")
    }
    if (state == MobileInstallationAttemptState.Recorded &&
        request.outcome == MobileInstallationAttemptOutcome.Installed) {
        limitations.add("platform owner reports that the signed artifact was installed")
    }
    limitations.add("CangHui does not execute the installer or inspect a device identifier")
    limitations.add("installation proof does not prove launch, rendering or semantic replay")
    limitations.add("device-proven requires a later independent device replay receipt")
    limitations.toArray()
}

private func validateInstallationAttemptLabel(value: String, label: String, maxLength: Int64): Unit {
    if (value.isEmpty() || value.size > maxLength || value == "." || value == ".." ||
        !mobileInstallationAttemptSafeName(value)) {
        throw IllegalArgumentException(label + " must be a bounded opaque label")
    }
}

private func validateInstallationAttemptDigest(value: String): Unit {
    if (value.size != 71 || !value.startsWith("sha256:")) {
        throw IllegalArgumentException("installation artifact digest must be sha256: plus 64 hex characters")
    }
    let runes = value.toRuneArray()
    for (i in 7..runes.size) {
        let r = runes[i]
        if (!((r >= r'a' && r <= r'f') || (r >= r'0' && r <= r'9'))) {
            throw IllegalArgumentException("installation artifact digest must use lowercase hex")
        }
    }
}

private func mobileInstallationAttemptSafeName(value: String): Bool {
    for (r in value.toRuneArray()) {
        let allowed = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') ||
            (r >= r'0' && r <= r'9') || r == r'.' || r == r'_' || r == r'-' || r == r':'
        if (!allowed) { return false }
    }
    true
}

private func renderMobileInstallationAttemptStrings(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(mobileInstallationAttemptQuote(value))
    }
    out.append("]")
    out.toString()
}

private func mobileInstallationAttemptQuote(value: String): String {
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
