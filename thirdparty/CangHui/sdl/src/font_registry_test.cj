package sdl

import std.fs.exists

protected func bundledFontFixture(): String {
    for (candidate in bundledFontCandidatesFor("")) {
        if (exists(candidate)) { return candidate }
    }
    ""
}

@Test
func bundledFontCandidatesPreferExplicitEnvironmentPath(): Unit {
    let candidates = bundledFontCandidatesFor("/opt/app/HarmonyOS_Sans_SC.ttf")
    @Expect(candidates[0], "/opt/app/HarmonyOS_Sans_SC.ttf")
    @Expect(candidates[1], "assets/fonts/HarmonyOS_Sans_SC.ttf")
}

@Test
func fontResolutionOrdersExplicitThemeApplicationBundledSystem(): Unit {
    let bundled = bundledFontFixture()
    @Expect(!bundled.isEmpty())
    Fonts.clear()
    Fonts.clearApplicationFamily()
    Fonts.registerBundledFallback(bundled)
    Fonts.register("component-face", bundled)
    Fonts.register("theme-face", bundled)
    Fonts.register("application-face", bundled)
    Fonts.useApplicationFamily("application-face")
    try {
        let explicit = Fonts.resolutionChain(
            explicitFamily: Some("component-face"), themeFamily: Some("theme-face"))
        @Expect(explicit[0].sourceName(), "application")
        @Expect(explicit[0].family, "component-face")

        let themed = Fonts.resolutionChain(themeFamily: Some("theme-face"))
        @Expect(themed[0].sourceName(), "theme")
        @Expect(themed[0].family, "theme-face")

        let application = Fonts.resolutionChain()
        @Expect(application[0].sourceName(), "application")
        @Expect(application[0].family, "application-face")

        Fonts.clearApplicationFamily()
        let fallback = Fonts.resolutionChain()
        @Expect(fallback[0].sourceName(), "bundled")
        @Expect(fallback[0].family, CANGHUI_DEFAULT_FONT_FAMILY)
        @Expect(fallback[fallback.size - 1].sourceName(), "system")
    } finally {
        Fonts.clear()
        Fonts.clearApplicationFamily()
        Fonts.clearBundledFallbackOverride()
    }
}
