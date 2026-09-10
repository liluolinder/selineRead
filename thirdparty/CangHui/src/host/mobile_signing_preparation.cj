package chui.host

import std.collection.ArrayList

/** Public boundary for handing an input tree to an external platform signer. */
public const CANGHUI_MOBILE_SIGNING_PREPARATION_PROTOCOL =
    "canghui.mobile-signing-preparation.v0"

public enum MobileSigningPreparationState <: Equatable<MobileSigningPreparationState> {
    | Blocked
    | RequirementsSatisfied

    public operator func ==(other: MobileSigningPreparationState): Bool {
        mobileSigningPreparationStateName(this) == mobileSigningPreparationStateName(other)
    }

    public operator func !=(other: MobileSigningPreparationState): Bool {
        !(this == other)
    }
}

public func mobileSigningPreparationStateName(
    state: MobileSigningPreparationState
): String {
    match (state) {
        case MobileSigningPreparationState.Blocked => "blocked"
        case MobileSigningPreparationState.RequirementsSatisfied => "requirements-satisfied"
    }
}

/**
 * Names are capability labels only. They are never secret values or filesystem paths.
 */
public struct MobileSigningPreparationRequest {
    public let outputName: String
    public let declaredCapabilities: Array<String>

    public init(outputName: String, declaredCapabilities!: Array<String> = []) {
        validateSigningOutputName(outputName)
        validateSigningCapabilityNames(declaredCapabilities)
        this.outputName = outputName
        this.declaredCapabilities = declaredCapabilities
    }

    public func hasCapability(name: String): Bool {
        for (capability in declaredCapabilities) {
            if (capability == name) { return true }
        }
        false
    }
}

/**
 * Preparation is deliberately weaker than a signed package. It only compares
 * a provider-owned input tree with non-secret capability labels declared by
 * the caller. Platform doctor/signer evidence remains authoritative.
 */
public struct MobileSigningPreparationReceipt {
    public let protocol: String
    public let platform: MobileApplicationPlatform
    public let packageKind: MobilePackageKind
    public let sourceStage: MobilePackageStage
    public let applicationId: String
    public let lifecycleEpoch: Int64
    public let surfaceGeneration: Int64
    public let sourceBinding: String
    public let state: MobileSigningPreparationState
    public let outputName: String
    public let requiredCapabilities: Array<String>
    public let missingCapabilities: Array<String>
    public let limitations: Array<String>

    public init(
        source: MobileHostPackageReceipt,
        request: MobileSigningPreparationRequest
    ) {
        this.protocol = CANGHUI_MOBILE_SIGNING_PREPARATION_PROTOCOL
        this.platform = source.platform
        this.packageKind = source.packageKind
        this.sourceStage = source.stage
        this.applicationId = source.applicationId
        this.lifecycleEpoch = source.lifecycleEpoch
        this.surfaceGeneration = source.surfaceGeneration
        this.sourceBinding = mobileSigningSourceBinding(source)
        this.state = if (source.stage == MobilePackageStage.InputTree &&
            source.signing == MobileSigningState.Unsigned) {
            let required = mobileSigningRequiredCapabilities(source.platform)
            if (allSigningCapabilitiesPresent(required, request)) {
                MobileSigningPreparationState.RequirementsSatisfied
            } else {
                MobileSigningPreparationState.Blocked
            }
        } else {
            MobileSigningPreparationState.Blocked
        }
        this.outputName = request.outputName
        this.requiredCapabilities = mobileSigningRequiredCapabilities(source.platform)
        this.missingCapabilities = missingSigningCapabilities(this.requiredCapabilities, request)
        this.limitations = mobileSigningPreparationLimitations(
            source,
            this.missingCapabilities
        )
    }

    public func requirementsSatisfied(): Bool {
        state == MobileSigningPreparationState.RequirementsSatisfied
    }

    public func signedPackage(): Bool { false }

    public func installable(): Bool { false }

    public func toJson(): String {
        "{\"protocol\":\"" + protocol + "\",\"platform\":\"" +
            mobileApplicationPlatformName(platform) + "\",\"packageKind\":\"" +
            mobilePackageKindName(packageKind) + "\",\"sourceStage\":\"" +
            mobilePackageStageName(sourceStage) + "\",\"applicationId\":" +
            mobileSigningQuote(applicationId) + ",\"lifecycleEpoch\":" + lifecycleEpoch.toString() +
            ",\"surfaceGeneration\":" + surfaceGeneration.toString() +
            ",\"sourceBinding\":" + mobileSigningQuote(sourceBinding) + ",\"state\":\"" +
            mobileSigningPreparationStateName(state) + "\",\"outputName\":\"" +
            outputName + "\",\"requiredCapabilities\":" +
            renderSigningPreparationStrings(requiredCapabilities) +
            ",\"missingCapabilities\":" + renderSigningPreparationStrings(missingCapabilities) +
            ",\"limitations\":" + renderSigningPreparationStrings(limitations) +
            ",\"signedPackage\":false,\"installable\":false}"
    }
}

/** Correlates a signer result with one provider receipt; it is not a digest. */
public func mobileSigningSourceBinding(source: MobileHostPackageReceipt): String {
    "input-tree-v0:" + mobileApplicationPlatformName(source.platform) + ":" +
        mobilePackageKindName(source.packageKind) + ":id-" + source.applicationId.size.toString() + ":" +
        source.lifecycleEpoch.toString() + ":" + source.surfaceGeneration.toString() + ":" +
        source.inputFiles.size.toString()
}

public func prepareMobileSigning(
    source: MobileHostPackageReceipt,
    request: MobileSigningPreparationRequest
): MobileSigningPreparationReceipt {
    MobileSigningPreparationReceipt(source, request)
}

private func mobileSigningRequiredCapabilities(platform: MobileApplicationPlatform): Array<String> {
    match (platform) {
        case MobileApplicationPlatform.IOS => ["ios-signing-identity", "ios-provisioning-profile"]
        case MobileApplicationPlatform.Android => ["android-keystore", "android-key-alias"]
        case MobileApplicationPlatform.HarmonyOS => ["harmony-signing-profile", "harmony-signing-key"]
    }
}

private func allSigningCapabilitiesPresent(
    required: Array<String>,
    request: MobileSigningPreparationRequest
): Bool {
    for (name in required) {
        if (!request.hasCapability(name)) { return false }
    }
    true
}

private func missingSigningCapabilities(
    required: Array<String>,
    request: MobileSigningPreparationRequest
): Array<String> {
    let missing = ArrayList<String>()
    for (name in required) {
        if (!request.hasCapability(name)) { missing.add(name) }
    }
    missing.toArray()
}

private func mobileSigningPreparationLimitations(
    source: MobileHostPackageReceipt,
    missingCapabilities: Array<String>
): Array<String> {
    let limitations = ArrayList<String>()
    if (source.stage != MobilePackageStage.InputTree) {
        limitations.add("source receipt must be at input-tree")
    }
    if (source.signing != MobileSigningState.Unsigned) {
        limitations.add("source receipt must remain unsigned")
    }
    if (!missingCapabilities.isEmpty()) {
        limitations.add("required signing capability labels are incomplete")
    }
    limitations.add("external platform signer is still required")
    limitations.add("declared capability labels are not host readiness evidence")
    limitations.add("no certificate, key, profile or secret is accepted by this protocol")
    limitations.add("no signed package, installation or device proof is produced")
    limitations.toArray()
}

private func validateSigningOutputName(value: String): Unit {
    if (value.isEmpty() || value.size > 255 || value == "." || value == ".." ||
        !mobileSigningNameIsSafe(value)) {
        throw IllegalArgumentException("mobile signing output name must be a single safe name")
    }
}

private func validateSigningCapabilityNames(values: Array<String>): Unit {
    if (values.size > 16) {
        throw IllegalArgumentException("mobile signing capability labels must not exceed 16")
    }
    for (i in 0..values.size) {
        if (values[i].isEmpty() || values[i].size > 128 || !mobileSigningNameIsSafe(values[i])) {
            throw IllegalArgumentException("mobile signing capability labels must be bounded opaque names")
        }
        for (j in (i + 1)..values.size) {
            if (values[i] == values[j]) {
                throw IllegalArgumentException("mobile signing capability labels must be unique")
            }
        }
    }
}

private func mobileSigningNameIsSafe(value: String): Bool {
    for (r in value.toRuneArray()) {
        let allowed = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') ||
            (r >= r'0' && r <= r'9') || r == r'.' || r == r'_' || r == r'-'
        if (!allowed) { return false }
    }
    true
}

private func renderSigningPreparationStrings(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(mobileSigningQuote(value))
    }
    out.append("]")
    out.toString()
}

private func mobileSigningQuote(value: String): String {
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
