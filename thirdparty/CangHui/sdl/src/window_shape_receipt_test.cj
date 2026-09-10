package sdl

@Test
func windowShapeCapabilityReceiptsStayFieldProofPending(): Unit {
    for (platform in ["windows", "linux-x11", "linux-wayland", "macos"]) {
        let receipt = WindowShapeCapabilityReceipt(platform)
        @Expect(receipt.contractAvailable)
        @Expect(!receipt.softwareConformanceComplete)
        @Expect(!receipt.hostRuntimeComplete)
        @Expect(receipt.fieldProofPending)
    }
}

@Test
func windowShapeNoRequestReceiptDoesNotClaimHostApplication(): Unit {
    let receipt = applyRoundedWindowShape(CPointer<Unit>(), 100, 100, 0.0)
    @Expect(receipt.status == WindowShapeApplyStatus.NotRequested)
    @Expect(!receipt.softwareConformanceComplete)
    @Expect(!receipt.hostRuntimeComplete)
    @Expect(receipt.fieldProofPending)
}
