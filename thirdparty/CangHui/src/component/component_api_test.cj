package chui.component

import chui.host.{HostCapability, HostPlatform, HostProfile}

@Test
func commonPackageAcceptsEveryPlatformWhenPlatformListIsEmpty(): Unit {
    let descriptor = ComponentPackageDescriptor("common.cards", "Common Cards", "1.0.0")
    match (descriptor.compatibility(HostProfile(HostPlatform.Desktop))) {
        case ComponentCompatibility.Compatible => @Expect(true)
        case _ => @Fail("A common package should accept desktop.")
    }
    match (descriptor.compatibility(HostProfile(HostPlatform.HarmonyOS))) {
        case ComponentCompatibility.Compatible => @Expect(true)
        case _ => @Fail("A common package should accept HarmonyOS.")
    }
}

@Test
func packageCompatibilitySeparatesPlatformAndCapabilityFailures(): Unit {
    let descriptor = ComponentPackageDescriptor(
        "media.stage",
        "Media Stage",
        "0.1.0",
        supportedPlatforms: [HostPlatform.Desktop, HostPlatform.HarmonyOS],
        requiredCapabilities: [HostCapability.NativeSurface, HostCapability.AudioOutput]
    )

    match (descriptor.compatibility(HostProfile(HostPlatform.Android))) {
        case ComponentCompatibility.UnsupportedPlatform(HostPlatform.Android) => @Expect(true)
        case _ => @Fail("Android should fail the package platform gate.")
    }

    match (descriptor.compatibility(HostProfile(
        HostPlatform.HarmonyOS,
        capabilities: [HostCapability.NativeSurface]
    ))) {
        case ComponentCompatibility.MissingCapabilities(missing) =>
            @Expect(missing.size, 1)
            @Expect(missing[0] == HostCapability.AudioOutput)
        case _ => @Fail("HarmonyOS should report the missing audio capability.")
    }
}

@Test
func descriptorRejectsEmptyStableIdentity(): Unit {
    var rejected = false
    try {
        let _ = ComponentPackageDescriptor("", "Broken", "0.1.0")
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}
