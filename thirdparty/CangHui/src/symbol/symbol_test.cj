package chui.symbol

import sdl.{Color, Rect, Renderer}

private class SymbolTestProvider <: SymbolProvider {
    private let providerId: String
    private let symbolName: String

    init(providerId: String, symbolName: String) {
        this.providerId = providerId
        this.symbolName = symbolName
    }

    public func id(): String { providerId }
    public func source(): SymbolProviderSource {
        SymbolProviderSource("https://example.invalid/symbols", "test-revision", "test", "MIT", "symbols")
    }
    public func descriptors(): Array<SymbolDescriptor> {
        [SymbolDescriptor(symbolName, variants: [SymbolVariant.Outlined], sourcePath: "symbols/${symbolName}.svg")]
    }
    public func resolve(name: String, _: SymbolVariant): ?SymbolGlyph {
        if (name != symbolName) { return None }
        Some(SymbolGlyph(providerId, name, "symbols/${name}.svg") {_, _, _ => ()})
    }
}

private class DuplicateSymbolTestProvider <: SymbolProvider {
    public func id(): String { "duplicate" }
    public func source(): SymbolProviderSource {
        SymbolProviderSource("https://example.invalid/duplicate", "test-revision", "test", "MIT", "symbols")
    }
    public func descriptors(): Array<SymbolDescriptor> {
        [SymbolDescriptor("same"), SymbolDescriptor("same")]
    }
    public func resolve(_: String, _: SymbolVariant): ?SymbolGlyph { None }
}

private class GlobalAliasTestAdapter <: SymbolAdapter {
    private let idValue: String
    private let aliasValue: String
    private let targetValue: String

    init(idValue: String, aliasValue: String, targetValue: String) {
        this.idValue = idValue
        this.aliasValue = aliasValue
        this.targetValue = targetValue
    }

    public func providerId(): String { idValue }
    public func canonicalName(name: String): ?String {
        if (name == targetValue) { Some(targetValue) } else { None }
    }
    public func globalAliases(): Array<SymbolAlias> {
        [SymbolAlias(aliasValue, SymbolName(targetValue, provider: idValue))]
    }
}

@Test
func builtInProviderKeepsLegacyIconNamesAndAliases(): Unit {
    let registry = SymbolRegistry()
    let direct = registry.resolve(SymbolName("save", provider: "builtin"))
    @Expect(direct.resolved.qualified(), "builtin.save")
    let alias = registry.resolve(SymbolName("delete", provider: "builtin"))
    @Expect(alias.resolved.qualified(), "builtin.trash")
}

@Test
func missingSymbolsFallbackOrFailDeterministically(): Unit {
    let registry = SymbolRegistry()
    let fallback = registry.resolve(SymbolName("not-present", provider: "material"))
    @Expect(fallback.fallback)
    @Expect(fallback.resolved.qualified(), "builtin.missing")
    try {
        let _ = registry.resolve(SymbolName("not-present", provider: "material"),
            policy: SymbolMissingPolicy.Strict)
        @Fail("Strict Symbol lookup should reject a missing provider entry.")
    } catch (_: IllegalArgumentException) {
        @Expect(true)
    }
}

@Test
func providerAndAliasDuplicatesAreRejected(): Unit {
    let registry = SymbolRegistry(includeBuiltin: false)
    try {
        registry.register(DuplicateSymbolTestProvider())
        @Fail("Duplicate canonical Symbol names should fail registration.")
    } catch (_: IllegalStateException) {
        @Expect(true)
    }
    registry.register(SymbolTestProvider("one", "add"), GlobalAliasTestAdapter("one", "create", "add"))
    try {
        registry.register(SymbolTestProvider("two", "plus"), GlobalAliasTestAdapter("two", "create", "plus"))
        @Fail("Cross-provider global aliases should fail registration.")
    } catch (_: IllegalStateException) {
        @Expect(true)
    }
}

@Test
func symbolDrawIrCarriesStyleDirectionAccessibilityAndFallback(): Unit {
    let renderer = Renderer.recordingHeadless()
    let _ = drawSymbol(renderer, SymbolName("chevron-left", provider: "builtin"),
        Rect(2.0, 3.0, 24.0, 24.0), Color.rgb(10, 20, 30), weight: 600.0,
        variant: SymbolVariant.Filled, direction: SymbolDirection.RightToLeft,
        accessibilityLabel: "Previous")
    let commands = renderer.drawIr()
    @Expect(commands[0].kind, "symbol")
    let json = commands[0].toJson()
    @Expect(json.contains("\"provider\":\"builtin\""))
    @Expect(json.contains("\"mirrored\":true"))
    @Expect(json.contains("\"accessibilityLabel\":\"Previous\""))
    @Expect(json.contains("\"variantFallback\":true"))
}
