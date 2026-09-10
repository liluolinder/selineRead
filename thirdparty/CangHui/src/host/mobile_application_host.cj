package chui.host

/** Stable protocol shared by iOS, Android and HarmonyOS application hosts. */
public const CANGHUI_MOBILE_APPLICATION_HOST_PROTOCOL = "canghui.mobile-application-host.v0"

public enum MobileApplicationPlatform <: Equatable<MobileApplicationPlatform> {
    | IOS
    | Android
    | HarmonyOS

    public operator func ==(other: MobileApplicationPlatform): Bool {
        mobileApplicationPlatformName(this) == mobileApplicationPlatformName(other)
    }

    public operator func !=(other: MobileApplicationPlatform): Bool {
        !(this == other)
    }
}

public func mobileApplicationPlatformName(platform: MobileApplicationPlatform): String {
    match (platform) {
        case MobileApplicationPlatform.IOS => "ios"
        case MobileApplicationPlatform.Android => "android"
        case MobileApplicationPlatform.HarmonyOS => "harmonyos"
    }
}

public enum MobilePackageKind <: Equatable<MobilePackageKind> {
    | IOSApplicationBundle
    | AndroidApplicationPackage
    | HarmonyApplicationPackage

    public operator func ==(other: MobilePackageKind): Bool {
        mobilePackageKindName(this) == mobilePackageKindName(other)
    }

    public operator func !=(other: MobilePackageKind): Bool {
        !(this == other)
    }
}

public func mobilePackageKindName(kind: MobilePackageKind): String {
    match (kind) {
        case MobilePackageKind.IOSApplicationBundle => "ios-application-bundle"
        case MobilePackageKind.AndroidApplicationPackage => "android-application-package"
        case MobilePackageKind.HarmonyApplicationPackage => "harmony-application-package"
    }
}

/** Evidence stages are intentionally ordered and cannot be skipped. */
public enum MobilePackageStage <: Equatable<MobilePackageStage> {
    | ContractReady
    | InputTree
    | SignedPackage
    | DeviceProven

    public operator func ==(other: MobilePackageStage): Bool {
        mobilePackageStageName(this) == mobilePackageStageName(other)
    }

    public operator func !=(other: MobilePackageStage): Bool {
        !(this == other)
    }
}

public func mobilePackageStageName(stage: MobilePackageStage): String {
    match (stage) {
        case MobilePackageStage.ContractReady => "contract-ready"
        case MobilePackageStage.InputTree => "input-tree"
        case MobilePackageStage.SignedPackage => "signed-package"
        case MobilePackageStage.DeviceProven => "device-proven"
    }
}

public func mobilePackageTransitionAllowed(from: MobilePackageStage, to: MobilePackageStage): Bool {
    if (from == to) { return true }
    match (from) {
        case MobilePackageStage.ContractReady => to == MobilePackageStage.InputTree
        case MobilePackageStage.InputTree => to == MobilePackageStage.SignedPackage
        case MobilePackageStage.SignedPackage => to == MobilePackageStage.DeviceProven
        case MobilePackageStage.DeviceProven => false
    }
}

public enum MobilePermissionState <: Equatable<MobilePermissionState> {
    | NotDeclared
    | PermissionRequired
    | Granted
    | Denied
    | Unsupported

    public operator func ==(other: MobilePermissionState): Bool {
        mobilePermissionStateName(this) == mobilePermissionStateName(other)
    }

    public operator func !=(other: MobilePermissionState): Bool {
        !(this == other)
    }
}

public func mobilePermissionStateName(state: MobilePermissionState): String {
    match (state) {
        case MobilePermissionState.NotDeclared => "not-declared"
        case MobilePermissionState.PermissionRequired => "permission-required"
        case MobilePermissionState.Granted => "granted"
        case MobilePermissionState.Denied => "denied"
        case MobilePermissionState.Unsupported => "unsupported"
    }
}

public enum MobileSigningState <: Equatable<MobileSigningState> {
    | NotEvaluated
    | Unsigned
    | Signed

    public operator func ==(other: MobileSigningState): Bool {
        mobileSigningStateName(this) == mobileSigningStateName(other)
    }

    public operator func !=(other: MobileSigningState): Bool {
        !(this == other)
    }
}

public func mobileSigningStateName(state: MobileSigningState): String {
    match (state) {
        case MobileSigningState.NotEvaluated => "not-evaluated"
        case MobileSigningState.Unsigned => "unsigned"
        case MobileSigningState.Signed => "signed"
    }
}

public enum MobileDeviceProofState <: Equatable<MobileDeviceProofState> {
    | NotRun
    | Passed
    | Failed

    public operator func ==(other: MobileDeviceProofState): Bool {
        mobileDeviceProofStateName(this) == mobileDeviceProofStateName(other)
    }

    public operator func !=(other: MobileDeviceProofState): Bool {
        !(this == other)
    }
}

public func mobileDeviceProofStateName(state: MobileDeviceProofState): String {
    match (state) {
        case MobileDeviceProofState.NotRun => "not-run"
        case MobileDeviceProofState.Passed => "passed"
        case MobileDeviceProofState.Failed => "failed"
    }
}

public struct MobilePermissionReceipt {
    public let capability: HostCapability
    public let state: MobilePermissionState

    public init(capability: HostCapability, state: MobilePermissionState) {
        this.capability = capability
        this.state = state
    }
}

/** Context attached to callbacks entering the Cangjie UI owner queue. */
public struct MobileHostCallbackContext {
    public let actionId: String
    public let lifecycleEpoch: Int64
    public let surfaceGeneration: Int64

    public init(actionId: String, lifecycleEpoch: Int64, surfaceGeneration: Int64) {
        if (actionId.isEmpty()) {
            throw IllegalArgumentException("mobile callback action id must not be empty")
        }
        if (lifecycleEpoch < 0 || surfaceGeneration < 0) {
            throw IllegalArgumentException("mobile callback epoch and generation must not be negative")
        }
        this.actionId = actionId
        this.lifecycleEpoch = lifecycleEpoch
        this.surfaceGeneration = surfaceGeneration
    }

    public func isCurrent(expectedLifecycleEpoch: Int64, expectedSurfaceGeneration: Int64): Bool {
        lifecycleEpoch == expectedLifecycleEpoch && surfaceGeneration == expectedSurfaceGeneration
    }
}

/**
 * Provider-neutral package receipt. Construction fails when evidence claims
 * jump ahead of signing or device replay.
 */
public struct MobileHostPackageReceipt {
    public let protocol: String
    public let platform: MobileApplicationPlatform
    public let packageKind: MobilePackageKind
    public let stage: MobilePackageStage
    public let applicationId: String
    public let lifecycleState: AppLifecycleState
    public let lifecycleEpoch: Int64
    public let surfaceGeneration: Int64
    public let signing: MobileSigningState
    public let deviceProof: MobileDeviceProofState
    public let permissions: Array<MobilePermissionReceipt>
    public let inputFiles: Array<String>
    public let limitations: Array<String>

    public init(
        platform: MobileApplicationPlatform,
        packageKind: MobilePackageKind,
        stage: MobilePackageStage,
        applicationId: String,
        lifecycleState: AppLifecycleState,
        lifecycleEpoch: Int64,
        surfaceGeneration: Int64,
        signing!: MobileSigningState = MobileSigningState.NotEvaluated,
        deviceProof!: MobileDeviceProofState = MobileDeviceProofState.NotRun,
        permissions!: Array<MobilePermissionReceipt> = [],
        inputFiles!: Array<String> = [],
        limitations!: Array<String> = []
    ) {
        if (!mobilePackageKindMatchesPlatform(platform, packageKind)) {
            throw IllegalArgumentException("mobile package kind does not match platform")
        }
        if (applicationId.isEmpty()) {
            throw IllegalArgumentException("mobile application id must not be empty")
        }
        if (lifecycleEpoch < 0 || surfaceGeneration < 0) {
            throw IllegalArgumentException("mobile receipt epoch and generation must not be negative")
        }
        if (mobilePackageStageRequiresInputTree(stage) && inputFiles.isEmpty()) {
            throw IllegalArgumentException("mobile package stage requires a non-empty input tree")
        }
        if (mobilePackageStageRequiresSigning(stage) && signing != MobileSigningState.Signed) {
            throw IllegalArgumentException("mobile signed-package stage requires signed evidence")
        }
        if (!mobilePackageStageRequiresSigning(stage) && signing == MobileSigningState.Signed) {
            throw IllegalArgumentException("mobile signing evidence cannot precede signed-package stage")
        }
        if (stage == MobilePackageStage.DeviceProven && deviceProof != MobileDeviceProofState.Passed) {
            throw IllegalArgumentException("mobile device-proven stage requires passed device replay")
        }
        if (stage != MobilePackageStage.DeviceProven && deviceProof == MobileDeviceProofState.Passed) {
            throw IllegalArgumentException("mobile device proof cannot precede device-proven stage")
        }
        validateMobilePermissionReceipts(permissions)
        validateMobileReceiptStrings(inputFiles, "mobile input file")
        validateMobileReceiptStrings(limitations, "mobile limitation")
        this.protocol = CANGHUI_MOBILE_APPLICATION_HOST_PROTOCOL
        this.platform = platform
        this.packageKind = packageKind
        this.stage = stage
        this.applicationId = applicationId
        this.lifecycleState = lifecycleState
        this.lifecycleEpoch = lifecycleEpoch
        this.surfaceGeneration = surfaceGeneration
        this.signing = signing
        this.deviceProof = deviceProof
        this.permissions = permissions
        this.inputFiles = inputFiles
        this.limitations = limitations
    }

    public func installable(): Bool {
        mobilePackageStageRequiresSigning(stage) && signing == MobileSigningState.Signed
    }

    public func deviceProven(): Bool {
        stage == MobilePackageStage.DeviceProven && deviceProof == MobileDeviceProofState.Passed
    }

    public func accepts(context: MobileHostCallbackContext): Bool {
        context.isCurrent(lifecycleEpoch, surfaceGeneration)
    }

    public func permissionState(capability: HostCapability): MobilePermissionState {
        for (permission in permissions) {
            if (permission.capability == capability) { return permission.state }
        }
        MobilePermissionState.NotDeclared
    }
}

/** Platform implementation boundary for UIKit, Android and HarmonyOS hosts. */
public interface MobileApplicationHostProvider {
    func platform(): MobileApplicationPlatform
    func packageKind(): MobilePackageKind
    func lifecycleState(): AppLifecycleState
    func lifecycleEpoch(): Int64
    func surfaceGeneration(): Int64
    func packageStage(): MobilePackageStage
    func permissionState(capability: HostCapability): MobilePermissionState
    func applyLifecycle(state: AppLifecycleState, epoch: Int64): Bool
    func applyPackageReceipt(receipt: MobileHostPackageReceipt): Bool
}

private func mobilePackageKindMatchesPlatform(
    platform: MobileApplicationPlatform,
    kind: MobilePackageKind
): Bool {
    match (platform) {
        case MobileApplicationPlatform.IOS => kind == MobilePackageKind.IOSApplicationBundle
        case MobileApplicationPlatform.Android => kind == MobilePackageKind.AndroidApplicationPackage
        case MobileApplicationPlatform.HarmonyOS => kind == MobilePackageKind.HarmonyApplicationPackage
    }
}

private func mobilePackageStageRequiresInputTree(stage: MobilePackageStage): Bool {
    match (stage) {
        case MobilePackageStage.ContractReady => false
        case _ => true
    }
}

private func mobilePackageStageRequiresSigning(stage: MobilePackageStage): Bool {
    match (stage) {
        case MobilePackageStage.SignedPackage => true
        case MobilePackageStage.DeviceProven => true
        case _ => false
    }
}

private func validateMobilePermissionReceipts(permissions: Array<MobilePermissionReceipt>): Unit {
    for (i in 0..permissions.size) {
        for (j in (i + 1)..permissions.size) {
            if (permissions[i].capability == permissions[j].capability) {
                throw IllegalArgumentException("mobile permission capability must be unique")
            }
        }
    }
}

private func validateMobileReceiptStrings(values: Array<String>, label: String): Unit {
    for (i in 0..values.size) {
        if (values[i].isEmpty()) {
            throw IllegalArgumentException(label + " must not be empty")
        }
        for (j in (i + 1)..values.size) {
            if (values[i] == values[j]) {
                throw IllegalArgumentException(label + " must be unique")
            }
        }
    }
}
