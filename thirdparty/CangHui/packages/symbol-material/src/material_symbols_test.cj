package canghui_symbol_material

import chui.{Color, Rect, Renderer, SymbolDirection, SymbolName, SymbolPaint, SymbolRegistry, SymbolVariant}

@Test
func materialProviderFreezesSourceAndHonorsSubsets(): Unit {
    let provider = MaterialSymbolProvider(included: ["plus"])
    @Expect(provider.source().revision, "528cb964c01fb2b09bc3b9208f82b6d8f8c1c1e2")
    @Expect(provider.source().license, "Apache-2.0")
    @Expect(provider.descriptors().size, 1)
    @Expect(provider.descriptors()[0].name, "add")
}

@Test
func materialAliasesResolveAndPaintHeadlessly(): Unit {
    let registry = SymbolRegistry()
    registry.register(MaterialSymbolProvider(included: ["add"]), MaterialSymbolAdapter())
    let resolution = registry.resolve(SymbolName("plus", provider: "material"), variant: SymbolVariant.Filled)
    @Expect(resolution.resolved.qualified(), "material.add")
    @Expect(resolution.variant, SymbolVariant.Outlined)
    @Expect(resolution.variantFallback)
    let renderer = Renderer.recordingHeadless()
    resolution.glyph.draw(renderer, Rect(0.0, 0.0, 24.0, 24.0),
        SymbolPaint(Color.rgb(30, 40, 50), 400.0, resolution.variant,
            SymbolDirection.Inherit, false))
    @Expect(renderer.drawIr().size > 0)
}
