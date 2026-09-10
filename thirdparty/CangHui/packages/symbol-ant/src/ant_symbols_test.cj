package canghui_symbol_ant

import chui.{Color, Rect, Renderer, SymbolDirection, SymbolName, SymbolPaint, SymbolRegistry, SymbolVariant}

@Test
func antProviderFreezesSourceAndLimitsRuntimeEntries(): Unit {
    let provider = AntSymbolProvider(included: ["add", "right"])
    @Expect(provider.source().revision, "6c18c63fbcfcf71dae09cd6bd6d63a48f8b688f1")
    @Expect(provider.descriptors().size, 2)
    let registry = SymbolRegistry()
    registry.register(provider, AntSymbolAdapter())
    @Expect(registry.resolve(SymbolName("add", provider: "ant")).resolved.qualified(), "ant.plus")
}

@Test
func antDirectionalGlyphPaintsThroughProviderClosure(): Unit {
    let provider = AntSymbolProvider(included: ["right"])
    let glyph = provider.resolve("right", SymbolVariant.Outlined) ?? throw IllegalStateException("missing fixture")
    let renderer = Renderer.recordingHeadless()
    glyph.draw(renderer, Rect(0.0, 0.0, 24.0, 24.0),
        SymbolPaint(Color.rgb(20, 30, 40), 500.0, SymbolVariant.Outlined, SymbolDirection.RightToLeft, true))
    @Expect(renderer.drawIr().size, 2)
}
