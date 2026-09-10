package canghui_symbol_arco

import chui.{Color, Rect, Renderer, SymbolDirection, SymbolName, SymbolPaint, SymbolRegistry, SymbolVariant}

@Test
func arcoProviderCarriesTaggedUpstreamAndAcroCompatibleCatalog(): Unit {
    let provider = ArcoSymbolProvider(included: ["chevron-left"])
    @Expect(provider.source().revision, "fbf2ec0a8cc28a5d20f1f82de6c2c4196ef66950")
    @Expect(provider.source().version, "2.66.16")
    let registry = SymbolRegistry()
    registry.register(provider, ArcoSymbolAdapter())
    @Expect(registry.resolve(SymbolName("chevron-left", provider: "arco")).resolved.qualified(), "arco.left")
}

@Test
func arcoLineSourcePaintsDeterministicCommands(): Unit {
    let provider = ArcoSymbolProvider(included: ["check"])
    let glyph = provider.resolve("check", SymbolVariant.Outlined) ?? throw IllegalStateException("missing fixture")
    let renderer = Renderer.recordingHeadless()
    glyph.draw(renderer, Rect(0.0, 0.0, 24.0, 24.0),
        SymbolPaint(Color.rgb(5, 10, 15), 400.0, SymbolVariant.Outlined, SymbolDirection.Inherit, false))
    @Expect(renderer.drawIr().size, 2)
}
