package chui.host

@Test
func iosNativeSurfaceBridgeRejectsStaleGenerations(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(17, 320000, 480000, 640, 960, 2000, 1), 0)
    @Expect(bridge.frame(1000, 2000, 1), 0)
    @Expect(bridge.resize(360000, 640000, 720, 1280, 2000, 1), 0)
    @Expect(bridge.detach(1), 0)
    @Expect(bridge.frame(3000, 4000, 1), -2)
    @Expect(bridge.attach(23, 360000, 640000, 720, 1280, 2000, 1), -2)
    @Expect(bridge.attach(23, 360000, 640000, 720, 1280, 2000, 2), 0)
    @Expect(bridge.currentGeneration(), 2)
    @Expect(bridge.totalAttachCount(), 2)
    @Expect(bridge.totalResizeCount(), 1)
    @Expect(bridge.totalDetachCount(), 1)
    @Expect(bridge.totalFrameCount(), 1)
}

@Test
func iosNativeSurfaceBridgeCapturesHostFactsThroughOwnerQueue(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(29, 393000, 852000, 1179, 2556, 3000, 1), 0)
    @Expect(bridge.updateSafeArea(59000, 0, 34000, 0), 0)
    @Expect(bridge.updateLifecycle(1), 0)
    @Expect(bridge.touch(0, 7, 120500, 240250, 1234, 1), 0)
    @Expect(bridge.currentSafeTopMilli(), 59000)
    @Expect(bridge.currentSafeBottomMilli(), 34000)
    @Expect(bridge.currentLifecycleState(), 1)
    @Expect(bridge.currentTouchPhase(), 0)
    @Expect(bridge.currentTouchId(), 7)
    @Expect(bridge.currentTouchXMilli(), 120500)
    @Expect(bridge.currentTouchYMilli(), 240250)
    @Expect(bridge.currentTouchTimestampMillis(), 1234)
    @Expect(bridge.totalTouchCount(), 1)
    @Expect(bridge.clearColorArgb(), 4290054911)
}

@Test
func iosNativeSurfaceBridgeCapturesPointerAndTraitIngress(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(31, 1194000, 834000, 2388, 1668, 2000, 1), 0)
    @Expect(bridge.pointer(0, 9, 400000, 280000, 2000, 1, 1), 0)
    @Expect(bridge.pointer(1, 9, 410000, 290000, 2016, 1, 1), 0)
    @Expect(bridge.updateTraits(2, 2, 2, 2000), 0)
    @Expect(bridge.currentPointerPhase(), 1)
    @Expect(bridge.currentPointerKind(), 1)
    @Expect(bridge.currentPointerId(), 9)
    @Expect(bridge.currentPointerXMilli(), 410000)
    @Expect(bridge.currentPointerYMilli(), 290000)
    @Expect(bridge.currentPointerTimestampMillis(), 2016)
    @Expect(bridge.currentTraitStyle(), 2)
    @Expect(bridge.currentTraitHorizontalSizeClass(), 2)
    @Expect(bridge.currentTraitVerticalSizeClass(), 2)
    @Expect(bridge.currentTraitScaleMilli(), 2000)
    @Expect(bridge.totalPointerCount(), 2)
    @Expect(bridge.totalTraitCount(), 1)
}

@Test
func iosNativeSurfaceBridgeValidatesIntegerAbiInputs(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(0, 320000, 480000, 640, 960, 2000, 1), -1)
    @Expect(bridge.attach(17, 0, 480000, 640, 960, 2000, 1), -1)
    @Expect(bridge.updateSafeArea(-1, 0, 0, 0), -1)
    @Expect(bridge.updateLifecycle(6), -1)
    @Expect(bridge.touch(4, 0, 0, 0, 0, 1), -1)
    @Expect(bridge.pointer(3, 0, 0, 0, 0, 0, 1), -1)
    @Expect(bridge.pointer(0, 0, 0, 0, 0, 2, 1), -1)
    @Expect(bridge.updateTraits(3, 0, 0, 1000), -1)
    @Expect(bridge.updateTraits(0, 0, 0, 0), -1)
}

@Test
func iosMobileApplicationProviderBindsReceiptToLifecycleAndSurface(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    let provider = IOSMobileApplicationHostProvider(
        "dev.canghui.ios.provider",
        bridge: bridge
    )
    @Expect(provider.applyLifecycle(AppLifecycleState.Active, 4))
    @Expect(provider.attachSurface(41, 1194000, 834000, 2388, 1668, 2000, 9), 0)
    @Expect(provider.stageUnsignedInputTree())
    let receipt = provider.packageReceipt()
    @Expect(provider.platform(), MobileApplicationPlatform.IOS)
    @Expect(provider.packageKind(), MobilePackageKind.IOSApplicationBundle)
    @Expect(provider.packageStage(), MobilePackageStage.InputTree)
    @Expect(receipt.signing, MobileSigningState.Unsigned)
    @Expect(!receipt.installable())
    @Expect(!receipt.deviceProven())
    @Expect(receipt.lifecycleEpoch, 4)
    @Expect(receipt.surfaceGeneration, 9)
    @Expect(receipt.inputFiles.size, 14)
    @Expect(provider.permissionState(HostCapability.NativeSurface), MobilePermissionState.Granted)
}

@Test
func iosMobileApplicationProviderRejectsStaleReceiptRollback(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    let provider = IOSMobileApplicationHostProvider(
        "dev.canghui.ios.rollback",
        bridge: bridge
    )
    @Expect(provider.applyLifecycle(AppLifecycleState.Active, 1))
    @Expect(provider.attachSurface(43, 1194000, 834000, 2388, 1668, 2000, 1), 0)
    @Expect(provider.stageUnsignedInputTree())
    let stale = provider.packageReceipt()
    @Expect(provider.applyLifecycle(AppLifecycleState.Background, 2))
    @Expect(provider.detachSurface(1), 0)
    @Expect(provider.attachSurface(47, 1194000, 834000, 2388, 1668, 2000, 2), 0)
    @Expect(!provider.applyPackageReceipt(stale))
    @Expect(provider.packageStage(), MobilePackageStage.InputTree)
    @Expect(provider.lifecycleEpoch(), 2)
    @Expect(provider.surfaceGeneration(), 2)
}

@Test
func iosMobileApplicationProviderRejectsNonMonotonicLifecycle(): Unit {
    let provider = IOSMobileApplicationHostProvider("dev.canghui.ios.lifecycle")
    @Expect(provider.applyLifecycle(AppLifecycleState.Active, 3))
    @Expect(!provider.applyLifecycle(AppLifecycleState.Inactive, 2))
    @Expect(!provider.applyLifecycle(AppLifecycleState.Inactive, 3))
    @Expect(provider.lifecycleState(), AppLifecycleState.Active)
    @Expect(provider.lifecycleEpoch(), 3)
}

@Test
func iosMobileApplicationProviderPreparesButDoesNotSignPackage(): Unit {
    let provider = IOSMobileApplicationHostProvider("dev.canghui.ios.prepare")
    @Expect(provider.applyLifecycle(AppLifecycleState.Active, 1))
    @Expect(provider.attachSurface(59, 1194000, 834000, 2388, 1668, 2000, 1), 0)
    @Expect(provider.stageUnsignedInputTree())
    let prepared = provider.prepareSigning(MobileSigningPreparationRequest(
        "CangHui.app",
        declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
    ))
    @Expect(prepared.requirementsSatisfied())
    @Expect(!prepared.signedPackage())
    @Expect(!prepared.installable())
    @Expect(provider.packageStage(), MobilePackageStage.InputTree)
    @Expect(provider.packageReceipt().signing, MobileSigningState.Unsigned)
}

@Test
func iosMobileApplicationProviderRequiresSignedEvidenceGate(): Unit {
    let provider = IOSMobileApplicationHostProvider("dev.canghui.ios.evidence")
    @Expect(provider.applyLifecycle(AppLifecycleState.Active, 4))
    @Expect(provider.attachSurface(61, 1194000, 834000, 2388, 1668, 2000, 9), 0)
    @Expect(provider.stageUnsignedInputTree())
    let source = provider.packageReceipt()
    let direct = MobileHostPackageReceipt(
        source.platform,
        source.packageKind,
        MobilePackageStage.SignedPackage,
        source.applicationId,
        source.lifecycleState,
        source.lifecycleEpoch,
        source.surfaceGeneration,
        signing: MobileSigningState.Signed,
        permissions: source.permissions,
        inputFiles: source.inputFiles
    )
    @Expect(!provider.applyPackageReceipt(direct))
    let preparation = provider.prepareSigning(MobileSigningPreparationRequest(
        "CangHui.app",
        declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
    ))
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
            "verify-20260819-provider", digest, 4096, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    @Expect(provider.applySignedPackageEvidence(evidence))
    @Expect(provider.packageStage(), MobilePackageStage.SignedPackage)
    @Expect(provider.packageReceipt().installable())
    @Expect(!provider.packageReceipt().deviceProven())
}

@Test
func iosMobileApplicationProviderRecordsInstallationWithoutAdvancingStage(): Unit {
    let provider = IOSMobileApplicationHostProvider("dev.canghui.ios.install")
    @Expect(provider.applyLifecycle(AppLifecycleState.Active, 4))
    @Expect(provider.attachSurface(67, 1194000, 834000, 2388, 1668, 2000, 9), 0)
    @Expect(provider.stageUnsignedInputTree())
    let source = provider.packageReceipt()
    let preparation = provider.prepareSigning(MobileSigningPreparationRequest(
        "CangHui.app",
        declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
    ))
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
            "verify-20260819-provider-install", digest, 4096, preparation.sourceBinding,
            MobileSignedPackageVerificationOutcome.Passed
        )
    )
    @Expect(provider.applySignedPackageEvidence(evidence))
    let installation = provider.recordInstallationAttempt(
        evidence,
        MobileInstallationAttemptRequest(
            "CangHui.app", "ios-platform-owner", MobileInstallationTargetClass.PhysicalDevice,
            "devicectl", "development-install-v1", "install-20260819-provider",
            digest, 4096, MobileInstallationAttemptOutcome.Installed
        )
    )
    @Expect(installation.installationProven())
    @Expect(provider.packageStage(), MobilePackageStage.SignedPackage)
    @Expect(provider.packageReceipt().deviceProof, MobileDeviceProofState.NotRun)
    @Expect(!provider.packageReceipt().deviceProven())
}
