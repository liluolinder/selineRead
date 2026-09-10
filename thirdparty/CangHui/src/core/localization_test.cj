package chui.core

@Test
func localizationCatalogUsesExactFallbackDefaultAndCallerValues(): Unit {
    let catalog = LocalizationCatalog(defaultLocale: LocaleTag.english())
    catalog.put("en", "action.build", "Build")
    catalog.put("zh", "action.build", "建造")
    catalog.put("zh-Hant", "action.demolish", "拆除")

    @Expect(catalog.resolve("action.build", LocaleTag("zh-Hant-TW", fallbackTag: "zh")), "建造")
    @Expect(catalog.resolve("action.demolish", LocaleTag.traditionalChinese()), "拆除")
    @Expect(catalog.resolve("action.build", LocaleTag("fr")), "Build")
    @Expect(catalog.resolve("missing", LocaleTag("fr"), fallback: "Fallback"), "Fallback")
    @Expect(catalog.resolve("missing-key", LocaleTag("fr")), "missing-key")
}

@Test
func localizationCatalogOverwritesOneExactLocaleWithoutAffectingOthers(): Unit {
    let catalog = LocalizationCatalog()
    catalog.put("en", "title", "First")
    catalog.put("zh-Hant", "title", "標題")
    catalog.put("en", "title", "Second")

    @Expect(catalog.resolve("title", LocaleTag.english()), "Second")
    @Expect(catalog.resolve("title", LocaleTag.traditionalChinese()), "標題")
    @Expect(catalog.contains(LocaleTag.english(), "title"))
}

@Test
func localizationCatalogRejectsEmptyLocaleAndKey(): Unit {
    var localeRejected = false
    var keyRejected = false
    try {
        let _ = LocaleTag("")
    } catch (_: IllegalArgumentException) {
        localeRejected = true
    }
    try {
        LocalizationCatalog().put("en", "", "value")
    } catch (_: IllegalArgumentException) {
        keyRejected = true
    }
    @Expect(localeRejected)
    @Expect(keyRejected)
}
