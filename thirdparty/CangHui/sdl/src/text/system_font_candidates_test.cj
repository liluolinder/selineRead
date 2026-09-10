package sdl.text

@Test
func systemFontCandidatesPreferInstalledHarmonyAndCjkMacFaces(): Unit {
    let candidates = systemFontCandidatesFor("/Users/example")

    @Expect(candidates[0], "/Users/example/Library/Fonts/HarmonyOS_Sans_SC.ttf")
    @Expect(candidates[1], "/Users/example/Library/Fonts/HarmonyOS Sans SC.ttf")
    @Expect(candidates[7], "/System/Library/Fonts/Hiragino Sans GB.ttc")
    @Expect(candidates[10], "/System/Library/Fonts/SFNS.ttf")
}
