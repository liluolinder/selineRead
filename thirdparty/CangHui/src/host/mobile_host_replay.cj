package chui.host

import std.collection.ArrayList

/** Stable, headless representation of one mobile host receipt and callback replay. */
public const CANGHUI_MOBILE_HOST_REPLAY_PROTOCOL = "canghui.mobile-host-replay.v0"

public enum MobileHostCallbackDecision <: Equatable<MobileHostCallbackDecision> {
    | Current
    | StaleLifecycle
    | StaleSurface
    | StaleLifecycleAndSurface

    public operator func ==(other: MobileHostCallbackDecision): Bool {
        mobileHostCallbackDecisionName(this) == mobileHostCallbackDecisionName(other)
    }

    public operator func !=(other: MobileHostCallbackDecision): Bool {
        !(this == other)
    }
}

public func mobileHostCallbackDecisionName(decision: MobileHostCallbackDecision): String {
    match (decision) {
        case MobileHostCallbackDecision.Current => "current"
        case MobileHostCallbackDecision.StaleLifecycle => "stale-lifecycle"
        case MobileHostCallbackDecision.StaleSurface => "stale-surface"
        case MobileHostCallbackDecision.StaleLifecycleAndSurface => "stale-lifecycle-and-surface"
    }
}

public struct MobileHostCallbackReplay {
    public let context: MobileHostCallbackContext
    public let accepted: Bool
    public let decision: MobileHostCallbackDecision

    public init(receipt: MobileHostPackageReceipt, context: MobileHostCallbackContext) {
        this.context = context
        this.accepted = receipt.accepts(context)
        this.decision = classifyMobileHostCallback(receipt, context)
    }

    public func toJson(): String {
        "{\"actionId\":" + mobileHostReplayQuote(context.actionId) +
            ",\"lifecycleEpoch\":" + context.lifecycleEpoch.toString() +
            ",\"surfaceGeneration\":" + context.surfaceGeneration.toString() +
            ",\"accepted\":" + accepted.toString() +
            ",\"decision\":" + mobileHostReplayQuote(mobileHostCallbackDecisionName(decision)) + "}"
    }
}

public class MobileHostSemanticReplay {
    public let protocol: String
    public let receipt: MobileHostPackageReceipt
    public let callbacks: Array<MobileHostCallbackReplay>

    public init(receipt: MobileHostPackageReceipt, contexts!: Array<MobileHostCallbackContext> = []) {
        this.protocol = CANGHUI_MOBILE_HOST_REPLAY_PROTOCOL
        this.receipt = receipt
        let replayed = ArrayList<MobileHostCallbackReplay>()
        for (context in contexts) {
            replayed.add(MobileHostCallbackReplay(receipt, context))
        }
        this.callbacks = replayed.toArray()
    }

    public func toJson(): String {
        let out = StringBuilder()
        out.append("{\"protocol\":")
        out.append(mobileHostReplayQuote(protocol))
        out.append(",\"receipt\":")
        out.append(renderMobileHostPackageReceipt(receipt))
        out.append(",\"installable\":")
        out.append(receipt.installable())
        out.append(",\"deviceProven\":")
        out.append(receipt.deviceProven())
        out.append(",\"callbacks\":[")
        var first = true
        for (callback in callbacks) {
            if (!first) { out.append(",") }
            first = false
            out.append(callback.toJson())
        }
        out.append("]}")
        out.toString()
    }
}

public func replayMobileHostSemantics(
    receipt: MobileHostPackageReceipt,
    contexts!: Array<MobileHostCallbackContext> = []
): MobileHostSemanticReplay {
    MobileHostSemanticReplay(receipt, contexts: contexts)
}

public func renderMobileHostSemanticReplay(
    receipt: MobileHostPackageReceipt,
    contexts!: Array<MobileHostCallbackContext> = []
): String {
    replayMobileHostSemantics(receipt, contexts: contexts).toJson()
}

func classifyMobileHostCallback(
    receipt: MobileHostPackageReceipt,
    context: MobileHostCallbackContext
): MobileHostCallbackDecision {
    let lifecycleCurrent = context.lifecycleEpoch == receipt.lifecycleEpoch
    let surfaceCurrent = context.surfaceGeneration == receipt.surfaceGeneration
    if (lifecycleCurrent && surfaceCurrent) { return MobileHostCallbackDecision.Current }
    if (!lifecycleCurrent && !surfaceCurrent) {
        return MobileHostCallbackDecision.StaleLifecycleAndSurface
    }
    if (!lifecycleCurrent) { MobileHostCallbackDecision.StaleLifecycle }
    else { MobileHostCallbackDecision.StaleSurface }
}

private func renderMobileHostPackageReceipt(receipt: MobileHostPackageReceipt): String {
    let out = StringBuilder()
    out.append("{\"protocol\":")
    out.append(mobileHostReplayQuote(receipt.protocol))
    out.append(",\"platform\":")
    out.append(mobileHostReplayQuote(mobileApplicationPlatformName(receipt.platform)))
    out.append(",\"packageKind\":")
    out.append(mobileHostReplayQuote(mobilePackageKindName(receipt.packageKind)))
    out.append(",\"stage\":")
    out.append(mobileHostReplayQuote(mobilePackageStageName(receipt.stage)))
    out.append(",\"applicationId\":")
    out.append(mobileHostReplayQuote(receipt.applicationId))
    out.append(",\"lifecycleState\":")
    out.append(mobileHostReplayQuote(appLifecycleStateName(receipt.lifecycleState)))
    out.append(",\"lifecycleEpoch\":")
    out.append(receipt.lifecycleEpoch)
    out.append(",\"surfaceGeneration\":")
    out.append(receipt.surfaceGeneration)
    out.append(",\"signing\":")
    out.append(mobileHostReplayQuote(mobileSigningStateName(receipt.signing)))
    out.append(",\"deviceProof\":")
    out.append(mobileHostReplayQuote(mobileDeviceProofStateName(receipt.deviceProof)))
    out.append(",\"permissions\":[")
    var first = true
    for (permission in receipt.permissions) {
        if (!first) { out.append(",") }
        first = false
        out.append("{\"capability\":")
        out.append(mobileHostReplayQuote(hostCapabilityName(permission.capability)))
        out.append(",\"state\":")
        out.append(mobileHostReplayQuote(mobilePermissionStateName(permission.state)))
        out.append("}")
    }
    out.append("],\"inputFiles\":")
    out.append(renderMobileHostReplayStrings(receipt.inputFiles))
    out.append(",\"limitations\":")
    out.append(renderMobileHostReplayStrings(receipt.limitations))
    out.append("}")
    out.toString()
}

private func renderMobileHostReplayStrings(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(mobileHostReplayQuote(value))
    }
    out.append("]")
    out.toString()
}

private func mobileHostReplayQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else if (r == r'\b') { out.append("\\b") }
        else if (r == r'\f') { out.append("\\f") }
        else if (UInt32(r) < 32) {
            throw IllegalArgumentException("mobile host replay strings contain an unsupported control character")
        }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}
