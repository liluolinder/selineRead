package chui.host

import std.sync.Mutex

/** The checked-in iOS application input tree used by the unsigned provider proof. */
public func iosMobileApplicationInputTreeFiles(): Array<String> {
    [
        "platform/ios/probe/Info.plist",
        "platform/ios/probe/AppDelegate.m",
        "platform/ios/bootstrap/CangHuiRuntimeBootstrap.m",
        "platform/ios/runtime/CangHuiUIKitHostView.m",
        "platform/ios/runtime/CangHuiMetalSurfaceView.m",
        "platform/ios/runtime/CangHuiDisplayLinkDriver.m",
        "platform/ios/runtime/CangHuiNativeSceneSurfaceView.m",
        "platform/ios/include/CangHuiHost.h",
        "platform/ios/include/CangHuiNativeSurface.h",
        "platform/ios/include/CangHuiRuntimeBootstrap.h",
        "platform/ios/include/CangHuiUIKitHostView.h",
        "platform/ios/include/CangHuiMetalSurfaceView.h",
        "platform/ios/include/CangHuiNativeSceneSurfaceView.h",
        "platform/ios/include/CangjieGUIHost.h"
    ]
}

/**
 * Provider-owned iOS application boundary.
 *
 * The provider owns lifecycle epochs and package evidence while the native
 * surface bridge remains the source of generation truth. A receipt must match
 * both facts before it can advance, so a stale package cannot roll a live
 * consumer back to an older surface or lifecycle.
 */
public class IOSMobileApplicationHostProvider <: MobileApplicationHostProvider {
    private let stateMutex = Mutex()
    private let applicationIdentifier: String
    private let bridge: IOSNativeSurfaceBridge
    private var currentState = AppLifecycleState.Launching
    private var currentEpoch: Int64 = 0
    private var currentStage = MobilePackageStage.ContractReady
    private var currentSigning = MobileSigningState.NotEvaluated
    private var currentDeviceProof = MobileDeviceProofState.NotRun
    private var currentPermissions: Array<MobilePermissionReceipt> = []
    private var currentInputFiles: Array<String> = []
    private var currentLimitations: Array<String> = []

    public init(applicationId: String, bridge!: IOSNativeSurfaceBridge = IOSNativeSurfaceBridge()) {
        if (applicationId.isEmpty()) {
            throw IllegalArgumentException("iOS application id must not be empty")
        }
        this.applicationIdentifier = applicationId
        this.bridge = bridge
    }

    public func platform(): MobileApplicationPlatform { MobileApplicationPlatform.IOS }

    public func packageKind(): MobilePackageKind {
        MobilePackageKind.IOSApplicationBundle
    }

    public func lifecycleState(): AppLifecycleState {
        synchronized(stateMutex) { currentState }
    }

    public func lifecycleEpoch(): Int64 {
        synchronized(stateMutex) { currentEpoch }
    }

    public func surfaceGeneration(): Int64 {
        synchronized(stateMutex) { bridge.currentGeneration() }
    }

    public func packageStage(): MobilePackageStage {
        synchronized(stateMutex) { currentStage }
    }

    public func permissionState(capability: HostCapability): MobilePermissionState {
        synchronized(stateMutex) {
            for (permission in currentPermissions) {
                if (permission.capability == capability) { return permission.state }
            }
            MobilePermissionState.NotDeclared
        }
    }

    public func applyLifecycle(state: AppLifecycleState, epoch: Int64): Bool {
        if (epoch < 0) { return false }
        synchronized(stateMutex) {
            if (epoch < currentEpoch) { return false }
            if (epoch == currentEpoch) {
                return state == currentState
            }
            if (iosMobileLifecycleStateValue(state) < 0) { return false }
            if (bridge.updateLifecycle(iosMobileLifecycleStateValue(state)) != 0) {
                return false
            }
            currentState = state
            currentEpoch = epoch
            true
        }
    }

    /** Apply the common receipt only when it describes this provider's facts. */
    public func applyPackageReceipt(receipt: MobileHostPackageReceipt): Bool {
        synchronized(stateMutex) { applyPackageReceiptLocked(receipt, false) }
    }

    /** Apply signed-package stage only through the verified evidence gate. */
    public func applySignedPackageEvidence(
        evidence: MobileSignedPackageEvidenceReceipt
    ): Bool {
        synchronized(stateMutex) {
            let source = packageReceiptLocked()
            try {
                applyPackageReceiptLocked(
                    advanceMobileSignedPackageReceipt(source, evidence),
                    true
                )
            } catch (_: IllegalArgumentException) {
                false
            }
        }
    }

    /** Record one external installer result without advancing to device-proven. */
    public func recordInstallationAttempt(
        evidence: MobileSignedPackageEvidenceReceipt,
        request: MobileInstallationAttemptRequest
    ): MobileInstallationAttemptReceipt {
        synchronized(stateMutex) {
            recordMobileInstallationAttempt(packageReceiptLocked(), evidence, request)
        }
    }

    /** Stage the actual checked-in iOS host input tree without package claims. */
    public func stageUnsignedInputTree(): Bool {
        synchronized(stateMutex) {
            let receipt = MobileHostPackageReceipt(
                MobileApplicationPlatform.IOS,
                MobilePackageKind.IOSApplicationBundle,
                MobilePackageStage.InputTree,
                applicationIdentifier,
                currentState,
                currentEpoch,
                bridge.currentGeneration(),
                signing: MobileSigningState.Unsigned,
                permissions: iosMobileApplicationPermissions(),
                inputFiles: iosMobileApplicationInputTreeFiles(),
                limitations: [
                    "unsigned iOS application input tree",
                    "no IPA, signing, installation, or device proof"
                ]
            )
            applyPackageReceiptLocked(receipt, false)
        }
    }

    public func packageReceipt(): MobileHostPackageReceipt {
        synchronized(stateMutex) { packageReceiptLocked() }
    }

    /** Prepare a non-secret handoff to the application-owned Xcode signer. */
    public func prepareSigning(
        request: MobileSigningPreparationRequest
    ): MobileSigningPreparationReceipt {
        synchronized(stateMutex) {
            prepareMobileSigning(
                MobileHostPackageReceipt(
                    MobileApplicationPlatform.IOS,
                    MobilePackageKind.IOSApplicationBundle,
                    currentStage,
                    applicationIdentifier,
                    currentState,
                    currentEpoch,
                    bridge.currentGeneration(),
                    signing: currentSigning,
                    deviceProof: currentDeviceProof,
                    permissions: currentPermissions,
                    inputFiles: currentInputFiles,
                    limitations: currentLimitations
                ),
                request
            )
        }
    }

    public func attachSurface(
        handle: Int64,
        logicalWidthMilli: Int64,
        logicalHeightMilli: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        synchronized(stateMutex) {
            bridge.attach(handle, logicalWidthMilli, logicalHeightMilli,
                pixelWidth, pixelHeight, scaleMilli, generation)
        }
    }

    public func resizeSurface(
        logicalWidthMilli: Int64,
        logicalHeightMilli: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        synchronized(stateMutex) {
            bridge.resize(logicalWidthMilli, logicalHeightMilli,
                pixelWidth, pixelHeight, scaleMilli, generation)
        }
    }

    public func detachSurface(generation: Int64): Int64 {
        synchronized(stateMutex) { bridge.detach(generation) }
    }

    private func packageReceiptLocked(): MobileHostPackageReceipt {
        MobileHostPackageReceipt(
            MobileApplicationPlatform.IOS,
            MobilePackageKind.IOSApplicationBundle,
            currentStage,
            applicationIdentifier,
            currentState,
            currentEpoch,
            bridge.currentGeneration(),
            signing: currentSigning,
            deviceProof: currentDeviceProof,
            permissions: currentPermissions,
            inputFiles: currentInputFiles,
            limitations: currentLimitations
        )
    }

    private func applyPackageReceiptLocked(
        receipt: MobileHostPackageReceipt,
        signedEvidenceAuthorized: Bool
    ): Bool {
        if (receipt.platform != platform() || receipt.packageKind != packageKind()) {
            return false
        }
        if (receipt.applicationId != applicationIdentifier) {
            return false
        }
        if (receipt.lifecycleEpoch != currentEpoch ||
            receipt.surfaceGeneration != bridge.currentGeneration()) {
            return false
        }
        if (!mobilePackageTransitionAllowed(currentStage, receipt.stage)) {
            return false
        }
        if (currentStage == MobilePackageStage.InputTree &&
            receipt.stage == MobilePackageStage.SignedPackage && !signedEvidenceAuthorized) {
            return false
        }
        if (receipt.stage == currentStage && !sameIOSPackageEvidence(receipt)) {
            return false
        }
        currentStage = receipt.stage
        currentSigning = receipt.signing
        currentDeviceProof = receipt.deviceProof
        currentPermissions = receipt.permissions
        currentInputFiles = receipt.inputFiles
        currentLimitations = receipt.limitations
        true
    }

    private func sameIOSPackageEvidence(receipt: MobileHostPackageReceipt): Bool {
        receipt.signing == currentSigning && receipt.deviceProof == currentDeviceProof &&
            sameIOSPermissions(receipt.permissions, currentPermissions) &&
            sameIOSStrings(receipt.inputFiles, currentInputFiles) &&
            sameIOSStrings(receipt.limitations, currentLimitations)
    }
}

private func iosMobileLifecycleStateValue(state: AppLifecycleState): Int64 {
    match (state) {
        case AppLifecycleState.Launching => 0
        case AppLifecycleState.Active => 1
        case AppLifecycleState.Inactive => 2
        case AppLifecycleState.Background => 3
        case AppLifecycleState.Suspended => 4
        case AppLifecycleState.Terminating => 5
    }
}

private func iosMobileApplicationPermissions(): Array<MobilePermissionReceipt> {
    [
        MobilePermissionReceipt(HostCapability.Lifecycle, MobilePermissionState.Granted),
        MobilePermissionReceipt(HostCapability.NativeSurface, MobilePermissionState.Granted),
        MobilePermissionReceipt(HostCapability.SafeArea, MobilePermissionState.Granted),
        MobilePermissionReceipt(HostCapability.SystemTheme, MobilePermissionState.Granted),
        MobilePermissionReceipt(HostCapability.TouchInput, MobilePermissionState.Granted)
    ]
}

private func sameIOSPermissions(
    left: Array<MobilePermissionReceipt>,
    right: Array<MobilePermissionReceipt>
): Bool {
    if (left.size != right.size) { return false }
    for (i in 0..left.size) {
        if (left[i].capability != right[i].capability || left[i].state != right[i].state) {
            return false
        }
    }
    true
}

private func sameIOSStrings(left: Array<String>, right: Array<String>): Bool {
    if (left.size != right.size) { return false }
    for (i in 0..left.size) {
        if (left[i] != right[i]) { return false }
    }
    true
}
