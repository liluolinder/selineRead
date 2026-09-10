package canghui_scene3d_bgfx

@Test
func macOSSdlMetalHostQuitEventRequestsClose(): Unit {
    @Expect(macOSSdlMetalHostEventRequestsClose(UInt32(0x100)))
}

@Test
func macOSSdlMetalHostIgnoresNonQuitEvents(): Unit {
    @Expect(!macOSSdlMetalHostEventRequestsClose(UInt32(0x206)))
    @Expect(!macOSSdlMetalHostEventRequestsClose(UInt32(0x300)))
}
