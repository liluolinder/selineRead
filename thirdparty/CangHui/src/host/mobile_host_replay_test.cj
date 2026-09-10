package chui.host

func replayFixtureReceipt(): MobileHostPackageReceipt {
    MobileHostPackageReceipt(
        MobileApplicationPlatform.Android,
        MobilePackageKind.AndroidApplicationPackage,
        MobilePackageStage.InputTree,
        "dev.canghui.replay",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        permissions: [
            MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.PermissionRequired),
            MobilePermissionReceipt(HostCapability.TouchInput, MobilePermissionState.Granted)
        ],
        inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libcanghui.so"],
        limitations: ["unsigned consumer fixture", "no device proof"]
    )
}

@Test
func mobileHostSemanticReplayClassifiesCurrentAndStaleCallbacks(): Unit {
    let replay = replayMobileHostSemantics(replayFixtureReceipt(), contexts: [
        MobileHostCallbackContext("player.toggle", 4, 9),
        MobileHostCallbackContext("player.seek", 3, 9),
        MobileHostCallbackContext("player.open", 4, 8),
        MobileHostCallbackContext("player.close", 3, 8)
    ])
    @Expect(replay.protocol, CANGHUI_MOBILE_HOST_REPLAY_PROTOCOL)
    @Expect(replay.callbacks.size, Int64(4))
    @Expect(replay.callbacks[0].accepted)
    @Expect(replay.callbacks[0].decision, MobileHostCallbackDecision.Current)
    @Expect(replay.callbacks[1].decision, MobileHostCallbackDecision.StaleLifecycle)
    @Expect(replay.callbacks[2].decision, MobileHostCallbackDecision.StaleSurface)
    @Expect(replay.callbacks[3].decision, MobileHostCallbackDecision.StaleLifecycleAndSurface)
}

@Test
func mobileHostSemanticReplayRendersHonestPackageAndPermissionState(): Unit {
    let json = renderMobileHostSemanticReplay(replayFixtureReceipt(), contexts: [
        MobileHostCallbackContext("player.toggle", 4, 9)
    ])
    @Expect(json.contains("\"protocol\":\"canghui.mobile-host-replay.v0\""))
    @Expect(json.contains("\"stage\":\"input-tree\""))
    @Expect(json.contains("\"signing\":\"unsigned\""))
    @Expect(json.contains("\"installable\":false"))
    @Expect(json.contains("\"deviceProven\":false"))
    @Expect(json.contains("\"capability\":\"notifications\""))
    @Expect(json.contains("\"decision\":\"current\""))
}

@Test
func mobileHostSemanticReplayEscapesConsumerControlledStrings(): Unit {
    let receipt = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.ContractReady,
        "dev.canghui.\"quoted\"",
        AppLifecycleState.Launching,
        0,
        0,
        limitations: ["line one\nline two"]
    )
    let json = renderMobileHostSemanticReplay(receipt)
    @Expect(json.contains("dev.canghui.\\\"quoted\\\""))
    @Expect(json.contains("line one\\nline two"))
}

@Test
func mobileSigningPreparationStaysBlockedWithoutSecretCapabilities(): Unit {
    let source = replayFixtureReceipt()
    let receipt = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest("player.apk")
    )
    @Expect(receipt.state, MobileSigningPreparationState.Blocked)
    @Expect(receipt.missingCapabilities.size, Int64(2))
    @Expect(!receipt.signedPackage())
    @Expect(!receipt.installable())
}

@Test
func mobileSigningPreparationBecomesReadyOnlyForExternalSigner(): Unit {
    let source = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.InputTree,
        "dev.canghui.ios.signing",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        inputFiles: ["Info.plist", "CangHuiRuntimeBootstrap.m"]
    )
    let receipt = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
        )
    )
    @Expect(receipt.state, MobileSigningPreparationState.RequirementsSatisfied)
    @Expect(receipt.missingCapabilities.size, Int64(0))
    @Expect(receipt.toJson().contains("\"signedPackage\":false"))
    @Expect(receipt.toJson().contains("external platform signer is still required"))
}

@Test
func mobileSigningPreparationRejectsPathLikeLabels(): Unit {
    var rejected = false
    try {
        let _ = MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["../private-key"]
        )
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func mobileExternalSignerReceiptAcceptsOnlyFreshPreparationBinding(): Unit {
    let source = MobileSigningPreparationReceipt(
        MobileHostPackageReceipt(
            MobileApplicationPlatform.IOS,
            MobilePackageKind.IOSApplicationBundle,
            MobilePackageStage.InputTree,
            "dev.canghui.ios.signing",
            AppLifecycleState.Active,
            4,
            9,
            signing: MobileSigningState.Unsigned,
            inputFiles: ["Info.plist", "CangHuiRuntimeBootstrap.m"]
        ),
        MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
        )
    )
    let receipt = bindMobileExternalSignerReceipt(
        source,
        MobileExternalSignerReceiptRequest(
            "CangHui.app",
            "xcode",
            "identity-ref",
            "profile-ref",
            "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            source.sourceBinding
        )
    )
    @Expect(receipt.accepted())
    @Expect(!receipt.advancesPackageReceipt())
    @Expect(receipt.toJson().contains("\"state\":\"accepted\""))
    @Expect(receipt.toJson().contains("\"signedPackage\":false"))
}

@Test
func mobileExternalSignerReceiptRejectsStaleBindingAndUnsafeDigest(): Unit {
    let source = MobileSigningPreparationReceipt(
        replayFixtureReceipt(),
        MobileSigningPreparationRequest("player.apk")
    )
    var digestRejected = false
    try {
        let _ = MobileExternalSignerReceiptRequest(
            "player.apk", "apksigner", "identity", "profile", "sha256:bad", source.sourceBinding
        )
    } catch (_: IllegalArgumentException) {
        digestRejected = true
    }
    @Expect(digestRejected)
    let receipt = bindMobileExternalSignerReceipt(
        source,
        MobileExternalSignerReceiptRequest(
            "other.apk", "apksigner", "identity", "profile",
            "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "input-tree-v0:android:android-application-package:stale:4:9:2"
        )
    )
    @Expect(!receipt.accepted())
    @Expect(receipt.toJson().contains("source binding is stale or mismatched"))
}

@Test
func mobileSignedPackageEvidenceAdvancesOnlyFreshPassedVerification(): Unit {
    let source = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.InputTree,
        "dev.canghui.ios.signed",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        inputFiles: ["Info.plist", "CangHuiRuntimeBootstrap.m"]
    )
    let preparation = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
        )
    )
    let digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            "CangHui.app", "xcode", "identity-ref", "profile-ref", digest,
            preparation.sourceBinding
        )
    )
    let evidence = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            "CangHui.app", "ios-platform-owner", "codesign-verify", "strict-v1",
            "verify-20260819-001", digest, 4096, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    @Expect(evidence.applied())
    @Expect(evidence.advancesPackageReceipt())
    @Expect(evidence.toJson().contains("\"state\":\"applied\""))
    @Expect(evidence.toJson().contains("\"installationProven\":false"))
    let advanced = advanceMobileSignedPackageReceipt(source, evidence)
    @Expect(advanced.stage, MobilePackageStage.SignedPackage)
    @Expect(advanced.signing, MobileSigningState.Signed)
    @Expect(advanced.installable())
    @Expect(!advanced.deviceProven())
}

@Test
func mobileSignedPackageEvidenceRejectsFailedOrStaleVerification(): Unit {
    let source = replayFixtureReceipt()
    let preparation = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "player.apk",
            declaredCapabilities: ["android-keystore", "android-key-alias"]
        )
    )
    let digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            "player.apk", "apksigner", "identity-ref", "profile-ref", digest,
            preparation.sourceBinding
        )
    )
    let failed = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            "player.apk", "android-platform-owner", "apksigner-verify", "strict-v1",
            "verify-20260819-002", digest, 8192, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Failed
        )
    )
    @Expect(!failed.applied())
    @Expect(failed.toJson().contains("verification outcome did not pass"))
    let stale = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            "player.apk", "android-platform-owner", "apksigner-verify", "strict-v1",
            "verify-20260819-003", digest, 8192,
            "input-tree-v0:android:android-application-package:stale:4:9:2",
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    @Expect(!stale.applied())
    var rejectedSize = false
    try {
        let _ = MobileSignedPackageEvidenceRequest(
            "player.apk", "android-platform-owner", "apksigner-verify", "strict-v1",
            "verify-20260819-004", digest, 0, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    } catch (_: IllegalArgumentException) {
        rejectedSize = true
    }
    @Expect(rejectedSize)
}

@Test
func mobileSignedPackageEvidenceCannotAdvanceAReplacementInputTree(): Unit {
    let source = replayFixtureReceipt()
    let preparation = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "player.apk",
            declaredCapabilities: ["android-keystore", "android-key-alias"]
        )
    )
    let digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            "player.apk", "apksigner", "identity-ref", "profile-ref", digest,
            preparation.sourceBinding
        )
    )
    let evidence = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            "player.apk", "android-platform-owner", "apksigner-verify", "strict-v1",
            "verify-20260819-tree", digest, 8192, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    let replacement = MobileHostPackageReceipt(
        source.platform,
        source.packageKind,
        source.stage,
        source.applicationId,
        source.lifecycleState,
        source.lifecycleEpoch,
        source.surfaceGeneration,
        signing: source.signing,
        permissions: source.permissions,
        inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libreplacement.so"],
        limitations: source.limitations
    )
    var rejected = false
    try {
        let _ = advanceMobileSignedPackageReceipt(replacement, evidence)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func mobileInstallationAttemptRecordsInstalledAndFailedOutcomesWithoutDeviceProof(): Unit {
    let source = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.InputTree,
        "dev.canghui.ios.install",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        inputFiles: ["Info.plist", "CangHuiRuntimeBootstrap.m"]
    )
    let preparation = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
        )
    )
    let digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            "CangHui.app", "xcode", "identity-ref", "profile-ref", digest,
            preparation.sourceBinding
        )
    )
    let evidence = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            "CangHui.app", "ios-platform-owner", "codesign-verify", "strict-v1",
            "verify-20260819-install", digest, 4096, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    let signed = advanceMobileSignedPackageReceipt(source, evidence)
    let installed = recordMobileInstallationAttempt(
        signed,
        evidence,
        MobileInstallationAttemptRequest(
            "CangHui.app", "ios-platform-owner", MobileInstallationTargetClass.PhysicalDevice,
            "devicectl", "development-install-v1", "install-20260819-001",
            digest, 4096, MobileInstallationAttemptOutcome.Installed
        )
    )
    @Expect(installed.recorded())
    @Expect(installed.installed())
    @Expect(installed.installationProven())
    @Expect(!installed.advancesPackageReceipt())
    @Expect(installed.toJson().contains("\"sourceStage\":\"signed-package\""))
    @Expect(installed.toJson().contains("\"installationProven\":true"))
    @Expect(installed.toJson().contains("\"launchProven\":false"))
    @Expect(installed.toJson().contains("\"deviceProven\":false"))

    let failed = recordMobileInstallationAttempt(
        signed,
        evidence,
        MobileInstallationAttemptRequest(
            "CangHui.app", "ios-platform-owner", MobileInstallationTargetClass.PhysicalDevice,
            "devicectl", "development-install-v1", "install-20260819-002",
            digest, 4096, MobileInstallationAttemptOutcome.Failed
        )
    )
    @Expect(failed.recorded())
    @Expect(!failed.installed())
    @Expect(!failed.installationProven())
    @Expect(failed.toJson().contains("platform installer reported a failed installation attempt"))
}

@Test
func mobileInstallationAttemptRejectsStaleArtifactAndReplacementTree(): Unit {
    let source = replayFixtureReceipt()
    let preparation = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "player.apk",
            declaredCapabilities: ["android-keystore", "android-key-alias"]
        )
    )
    let digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let signer = bindMobileExternalSignerReceipt(
        preparation,
        MobileExternalSignerReceiptRequest(
            "player.apk", "apksigner", "identity-ref", "profile-ref", digest,
            preparation.sourceBinding
        )
    )
    let evidence = verifyMobileSignedPackageEvidence(
        source,
        signer,
        MobileSignedPackageEvidenceRequest(
            "player.apk", "android-platform-owner", "apksigner-verify", "strict-v1",
            "verify-20260819-install", digest, 8192, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    let signed = advanceMobileSignedPackageReceipt(source, evidence)
    let mismatched = recordMobileInstallationAttempt(
        signed,
        evidence,
        MobileInstallationAttemptRequest(
            "player.apk", "android-platform-owner", MobileInstallationTargetClass.PhysicalDevice,
            "adb", "development-install-v1", "install-20260819-mismatch",
            "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            8192, MobileInstallationAttemptOutcome.Installed
        )
    )
    @Expect(!mismatched.recorded())
    @Expect(!mismatched.installationProven())

    let replacement = MobileHostPackageReceipt(
        signed.platform,
        signed.packageKind,
        signed.stage,
        signed.applicationId,
        signed.lifecycleState,
        signed.lifecycleEpoch,
        signed.surfaceGeneration,
        signing: signed.signing,
        deviceProof: signed.deviceProof,
        permissions: signed.permissions,
        inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libreplacement.so"],
        limitations: signed.limitations
    )
    let wrongTree = recordMobileInstallationAttempt(
        replacement,
        evidence,
        MobileInstallationAttemptRequest(
            "player.apk", "android-platform-owner", MobileInstallationTargetClass.PhysicalDevice,
            "adb", "development-install-v1", "install-20260819-tree",
            digest, 8192, MobileInstallationAttemptOutcome.Installed
        )
    )
    @Expect(!wrongTree.recorded())

    @Expect(
        mobileInstallationTargetClassName(MobileInstallationTargetClass.ManagedDevicePool),
        "managed-device-pool"
    )
}
