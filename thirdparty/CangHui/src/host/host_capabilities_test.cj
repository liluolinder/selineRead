package chui.host

@Test
func hostProfileDeduplicatesAndReportsMissingCapabilities(): Unit {
    let host = HostProfile(
        HostPlatform.HarmonyOS,
        capabilities: [HostCapability.Ime, HostCapability.Ime, HostCapability.Lifecycle]
    )

    @Expect(host.capabilities.size, 2)
    @Expect(host.supports(HostCapability.Ime))
    @Expect(!host.supports(HostCapability.MediaSession))
    let missing = host.missing([HostCapability.Lifecycle, HostCapability.MediaSession])
    @Expect(missing.size, 1)
    @Expect(missing[0] == HostCapability.MediaSession)
}

@Test
func platformAndCapabilityNamesStayManifestFriendly(): Unit {
    @Expect(hostPlatformName(HostPlatform.Android), "android")
    @Expect(hostPlatformName(HostPlatform.HarmonyOS), "harmonyos")
    @Expect(hostPlatformName(HostPlatform.IOS), "ios")
    @Expect(hostCapabilityName(HostCapability.NativeSurface), "native-surface")
    @Expect(hostCapabilityName(HostCapability.SafeArea), "safe-area")
    @Expect(hostCapabilityName(HostCapability.BackgroundTasks), "background-tasks")
}
