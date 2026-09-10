package canghui_mobile_host_replay

import std.convert.*
import chui.*
import chui.kmode.macros.*

private let mobileReceipt = MobileHostPackageReceipt(
    MobileApplicationPlatform.Android,
    MobilePackageKind.AndroidApplicationPackage,
    MobilePackageStage.InputTree,
    "dev.canghui.mobile.replay",
    AppLifecycleState.Active,
    4,
    9,
    signing: MobileSigningState.Unsigned,
    permissions: [
        MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.PermissionRequired),
        MobilePermissionReceipt(HostCapability.TouchInput, MobilePermissionState.Granted)
    ],
    inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libcanghui.so"],
    limitations: ["unsigned consumer fixture", "no APK or device proof"]
)

private let replayHandler = mobileHostReplayHandler(mobileReceipt)

private let iosProvider = IOSMobileApplicationHostProvider("dev.canghui.mobile.ios.provider")
private var iosProviderReady = false

private func ensureIOSProvider(): Unit {
    if (iosProviderReady) { return }
    if (!iosProvider.applyLifecycle(AppLifecycleState.Active, 4)) {
        throw IllegalStateException("iOS provider lifecycle setup was rejected")
    }
    if (iosProvider.attachSurface(53, 1194000, 834000, 2388, 1668, 2000, 9) != 0) {
        throw IllegalStateException("iOS provider surface setup was rejected")
    }
    if (!iosProvider.stageUnsignedInputTree()) {
        throw IllegalStateException("iOS provider input tree staging was rejected")
    }
    iosProviderReady = true
}

private func signerField(inputs: Array<String>, index: Int64): String {
    if (index < inputs.size) { inputs[index] } else { "" }
}

private func installationTargetClass(value: String): MobileInstallationTargetClass {
    match (value) {
        case "physical-device" => MobileInstallationTargetClass.PhysicalDevice
        case "simulator-or-emulator" => MobileInstallationTargetClass.SimulatorOrEmulator
        case "managed-device-pool" => MobileInstallationTargetClass.ManagedDevicePool
        case _ => throw IllegalArgumentException("unsupported installation target device class")
    }
}

@KModeLink["mobile.demo.host.replay"]
func replayMobileHost(payload: String): String {
    replayHandler(payload)
}

@KModeLink["mobile.demo.ios.provider.replay"]
func replayIOSMobileHost(payload: String): String {
    ensureIOSProvider()
    renderMobileHostSemanticReplay(
        iosProvider.packageReceipt(),
        contexts: parseMobileHostReplayPayload(payload)
    )
}

@KModeLink["mobile.demo.ios.signing.prepare"]
func prepareIOSMobileSigning(payload: String): String {
    ensureIOSProvider()
    var inputs: Array<String> = []
    if (!payload.isEmpty()) { inputs = payload.split(",") }
    iosProvider.prepareSigning(MobileSigningPreparationRequest(
        "CangHui.app",
        declaredCapabilities: inputs
    )).toJson()
}

@KModeLink["mobile.demo.ios.signing.bind"]
func bindIOSMobileSigning(payload: String): String {
    ensureIOSProvider()
    let preparation = iosProvider.prepareSigning(MobileSigningPreparationRequest(
        "CangHui.app",
        declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
    ))
    var inputs: Array<String> = []
    if (!payload.isEmpty()) { inputs = payload.split("|") }
    let outputName = signerField(inputs, 0)
    bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            if (outputName.isEmpty()) { "CangHui.app" } else { outputName },
            signerField(inputs, 1), signerField(inputs, 2), signerField(inputs, 3),
            signerField(inputs, 4), signerField(inputs, 5)
        )
    ).toJson()
}

@KModeLink["mobile.demo.ios.signing.verify"]
func verifyIOSMobileSigning(payload: String): String {
    ensureIOSProvider()
    var inputs: Array<String> = []
    if (!payload.isEmpty()) { inputs = payload.split("|") }
    let outputName = signerField(inputs, 0)
    let digest = signerField(inputs, 5)
    let sourceBinding = signerField(inputs, 7)
    let preparation = iosProvider.prepareSigning(MobileSigningPreparationRequest(
        "CangHui.app",
        declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
    ))
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            outputName, "xcode", "identity-ref", "profile-ref", digest, sourceBinding
        )
    )
    let outcome = if (signerField(inputs, 8) == "passed") {
        MobileSignedPackageVerificationOutcome.Passed
    } else {
        MobileSignedPackageVerificationOutcome.Failed
    }
    let evidence = verifyMobileSignedPackageEvidence(
        iosProvider.packageReceipt(),
        signer,
        MobileSignedPackageEvidenceRequest(
            outputName, signerField(inputs, 1), signerField(inputs, 2), signerField(inputs, 3),
            signerField(inputs, 4), digest, Int64.parse(signerField(inputs, 6)), sourceBinding,
            outcome
        )
    )
    if (evidence.applied() && !iosProvider.applySignedPackageEvidence(evidence)) {
        throw IllegalStateException("iOS signed package evidence was not applied by the provider")
    }
    evidence.toJson()
}

@KModeLink["mobile.demo.ios.installation.record"]
func recordIOSMobileInstallation(payload: String): String {
    var inputs: Array<String> = []
    if (!payload.isEmpty()) { inputs = payload.split("|") }
    let provider = IOSMobileApplicationHostProvider("dev.canghui.mobile.ios.provider")
    if (!provider.applyLifecycle(AppLifecycleState.Active, 4) ||
        provider.attachSurface(71, 1194000, 834000, 2388, 1668, 2000, 9) != 0 ||
        !provider.stageUnsignedInputTree()) {
        throw IllegalStateException("iOS installation provider setup was rejected")
    }
    let source = provider.packageReceipt()
    let outputName = signerField(inputs, 0)
    let platformOwner = signerField(inputs, 1)
    let digest = signerField(inputs, 6)
    let artifactSize = Int64.parse(signerField(inputs, 7))
    let sourceBinding = signerField(inputs, 8)
    let preparation = provider.prepareSigning(MobileSigningPreparationRequest(
        outputName,
        declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
    ))
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            outputName, "xcode", "identity-ref", "profile-ref", digest, sourceBinding
        )
    )
    let evidence = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            outputName, platformOwner, "codesign-verify", "strict-v1",
            "verify-installation-input", digest, artifactSize, sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    if (!provider.applySignedPackageEvidence(evidence)) {
        return recordMobileInstallationAttempt(
            provider.packageReceipt(),
            evidence,
            MobileInstallationAttemptRequest(
                outputName, platformOwner, installationTargetClass(signerField(inputs, 2)), signerField(inputs, 3),
                signerField(inputs, 4), signerField(inputs, 5), digest, artifactSize,
                MobileInstallationAttemptOutcome.Failed
            )
        ).toJson()
    }
    let outcome = if (signerField(inputs, 9) == "installed") {
        MobileInstallationAttemptOutcome.Installed
    } else {
        MobileInstallationAttemptOutcome.Failed
    }
    provider.recordInstallationAttempt(
        evidence,
        MobileInstallationAttemptRequest(
            outputName, platformOwner, installationTargetClass(signerField(inputs, 2)), signerField(inputs, 3),
            signerField(inputs, 4), signerField(inputs, 5), digest, artifactSize, outcome
        )
    ).toJson()
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    println("Use cuic kmode call mobile-host-replay mobile.demo.host.replay [payload].")
    0
}
