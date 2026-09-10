package chui.desktop

@Test
func nonMacPlatformReceiptsNeverClaimFieldProof(): Unit {
    let harmonyGles = harmonyGraphicsCapability(HarmonyGraphicsPath.OpenGLES)
    let harmonyVulkan = harmonyGraphicsCapability(HarmonyGraphicsPath.Vulkan)
    let windows = desktopWindowShapeCapability("windows")
    let linux = desktopWindowShapeCapability("linux-wayland")

    for (receipt in [harmonyGles, harmonyVulkan, windows, linux]) {
        @Expect(receipt.contractAvailable)
        @Expect(!receipt.softwareConformanceComplete)
        @Expect(!receipt.hostRuntimeComplete)
        @Expect(receipt.fieldProofPending)
    }
}
