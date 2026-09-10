package chui.host

@Test
func mobileApplicationHostNamesStayStableAcrossPlatforms(): Unit {
    @Expect(mobileApplicationPlatformName(MobileApplicationPlatform.IOS), "ios")
    @Expect(mobileApplicationPlatformName(MobileApplicationPlatform.Android), "android")
    @Expect(mobileApplicationPlatformName(MobileApplicationPlatform.HarmonyOS), "harmonyos")
    @Expect(mobilePackageKindName(MobilePackageKind.IOSApplicationBundle), "ios-application-bundle")
    @Expect(mobilePackageStageName(MobilePackageStage.DeviceProven), "device-proven")
    @Expect(mobilePermissionStateName(MobilePermissionState.PermissionRequired), "permission-required")
}

@Test
func mobilePackageStagesCannotSkipEvidenceLayers(): Unit {
    @Expect(mobilePackageTransitionAllowed(MobilePackageStage.ContractReady, MobilePackageStage.InputTree))
    @Expect(mobilePackageTransitionAllowed(MobilePackageStage.InputTree, MobilePackageStage.SignedPackage))
    @Expect(mobilePackageTransitionAllowed(MobilePackageStage.SignedPackage, MobilePackageStage.DeviceProven))
    @Expect(!mobilePackageTransitionAllowed(MobilePackageStage.ContractReady, MobilePackageStage.SignedPackage))
    @Expect(!mobilePackageTransitionAllowed(MobilePackageStage.InputTree, MobilePackageStage.DeviceProven))
    @Expect(!mobilePackageTransitionAllowed(MobilePackageStage.DeviceProven, MobilePackageStage.InputTree))
}

@Test
func unsignedMobileInputTreeIsNotInstallable(): Unit {
    let receipt = MobileHostPackageReceipt(
        MobileApplicationPlatform.Android,
        MobilePackageKind.AndroidApplicationPackage,
        MobilePackageStage.InputTree,
        "dev.canghui.demo",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        permissions: [MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.PermissionRequired)],
        inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libcanghui.so"]
    )
    @Expect(receipt.protocol, CANGHUI_MOBILE_APPLICATION_HOST_PROTOCOL)
    @Expect(!receipt.installable())
    @Expect(!receipt.deviceProven())
    @Expect(receipt.lifecycleState, AppLifecycleState.Active)
    @Expect(receipt.permissionState(HostCapability.Notifications), MobilePermissionState.PermissionRequired)
    @Expect(receipt.permissionState(HostCapability.MediaLibrary), MobilePermissionState.NotDeclared)
}

@Test
func mobilePackageReceiptRejectsPlatformAndEvidenceOverclaims(): Unit {
    var rejectedKind = false
    try {
        let _ = MobileHostPackageReceipt(
            MobileApplicationPlatform.IOS,
            MobilePackageKind.HarmonyApplicationPackage,
            MobilePackageStage.ContractReady,
            "dev.canghui.demo",
            AppLifecycleState.Launching,
            0,
            0
        )
    } catch (_: IllegalArgumentException) {
        rejectedKind = true
    }
    @Expect(rejectedKind)

    var rejectedUnsigned = false
    try {
        let _ = MobileHostPackageReceipt(
            MobileApplicationPlatform.HarmonyOS,
            MobilePackageKind.HarmonyApplicationPackage,
            MobilePackageStage.SignedPackage,
            "dev.canghui.demo",
            AppLifecycleState.Active,
            1,
            1,
            signing: MobileSigningState.Unsigned,
            inputFiles: ["module.json5"]
        )
    } catch (_: IllegalArgumentException) {
        rejectedUnsigned = true
    }
    @Expect(rejectedUnsigned)

    var rejectedDeviceClaim = false
    try {
        let _ = MobileHostPackageReceipt(
            MobileApplicationPlatform.IOS,
            MobilePackageKind.IOSApplicationBundle,
            MobilePackageStage.DeviceProven,
            "dev.canghui.demo",
            AppLifecycleState.Active,
            2,
            3,
            signing: MobileSigningState.Signed,
            deviceProof: MobileDeviceProofState.NotRun,
            inputFiles: ["Info.plist", "Demo.app"]
        )
    } catch (_: IllegalArgumentException) {
        rejectedDeviceClaim = true
    }
    @Expect(rejectedDeviceClaim)

    var rejectedDuplicatePermission = false
    try {
        let _ = MobileHostPackageReceipt(
            MobileApplicationPlatform.Android,
            MobilePackageKind.AndroidApplicationPackage,
            MobilePackageStage.ContractReady,
            "dev.canghui.demo",
            AppLifecycleState.Launching,
            0,
            0,
            permissions: [
                MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.PermissionRequired),
                MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.Granted)
            ]
        )
    } catch (_: IllegalArgumentException) {
        rejectedDuplicatePermission = true
    }
    @Expect(rejectedDuplicatePermission)
}

@Test
func mobileCallbackContextRejectsStaleLifecycleOrSurfaceGeneration(): Unit {
    let receipt = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.DeviceProven,
        "dev.canghui.demo",
        AppLifecycleState.Active,
        12,
        18,
        signing: MobileSigningState.Signed,
        deviceProof: MobileDeviceProofState.Passed,
        inputFiles: ["Info.plist", "Demo.app"]
    )
    @Expect(receipt.installable())
    @Expect(receipt.deviceProven())
    @Expect(receipt.accepts(MobileHostCallbackContext("player.toggle", 12, 18)))
    @Expect(!receipt.accepts(MobileHostCallbackContext("player.toggle", 11, 18)))
    @Expect(!receipt.accepts(MobileHostCallbackContext("player.toggle", 12, 17)))
}
