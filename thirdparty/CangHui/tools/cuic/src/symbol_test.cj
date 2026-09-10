package cuic

@Test
func symbolProviderAliasesNormalize(): Unit {
    @Expect(normalizeSymbolProvider("material-design"), "material")
    @Expect(normalizeSymbolProvider("antd"), "ant")
    @Expect(normalizeSymbolProvider("acro"), "arco")
}

@Test
func symbolGeneratorCanonicalizesAliasesAndEmitsOnlyDeclaredEntries(): Unit {
    let framework = integratedFrameworkRoot()
    let options = parseSymbolGenerateOptions([
        "cuic", "symbol", "generate", "material:plus@primary_add", "ant:check",
        "--output", "/tmp/generated_symbols.cj", "--package", "generated_symbols"
    ], 3, framework)
    let source = renderGeneratedSymbolRegistry(options)
    @Expect(source.contains("MaterialSymbolProvider(included: [\"add\"])"))
    @Expect(source.contains("AntSymbolProvider(included: [\"check\"])"))
    @Expect(source.contains("remove"), false)
    @Expect(source.contains("primary_add"))
}

@Test
func symbolGeneratorRejectsCanonicalAndCrossProviderAliasDuplicates(): Unit {
    let framework = integratedFrameworkRoot()
    try {
        let _ = parseSymbolGenerateOptions([
            "cuic", "symbol", "generate", "material:add", "material:plus",
            "--output", "/tmp/duplicate_symbols.cj"
        ], 3, framework)
        @Fail("Alias-equivalent canonical selections should fail.")
    } catch (_: CuicError) {
        @Expect(true)
    }
    try {
        let _ = parseSymbolGenerateOptions([
            "cuic", "symbol", "generate", "material:add@action", "ant:plus@action",
            "--output", "/tmp/collision_symbols.cj"
        ], 3, framework)
        @Fail("Cross-provider export aliases should fail.")
    } catch (_: CuicError) {
        @Expect(true)
    }
}

@Test
func symbolCatalogJsonCarriesFrozenSources(): Unit {
    let json = renderSymbolCatalogJson(loadSymbolCatalogs(integratedFrameworkRoot()))
    @Expect(json.contains("\"schema\":\"canghui.symbol.catalog.v0\""))
    @Expect(json.contains("528cb964c01fb2b09bc3b9208f82b6d8f8c1c1e2"))
    @Expect(json.contains("6c18c63fbcfcf71dae09cd6bd6d63a48f8b688f1"))
    @Expect(json.contains("fbf2ec0a8cc28a5d20f1f82de6c2c4196ef66950"))
}

@Test
func symbolCatalogRejectsGeneratedSourceInjectionAndUnsafePaths(): Unit {
    let invalidType = """
canghui.symbol.provider.v0
provider=material
namespace=canghui_symbol_material
providerType=MaterialSymbolProvider); println(\"unsafe\")
adapterType=MaterialSymbolAdapter
repository=https://example.invalid/material
revision=test
version=test
license=Apache-2.0
symbol=add|variants=outlined|directional=false|source=symbols/add.svg
"""
    try {
        let _ = parseSymbolCatalog(invalidType, "invalid-type.catalog")
        @Fail("Catalog type names must not inject generated Cangjie source.")
    } catch (_: CuicError) {
        @Expect(true)
    }

    let unsafePath = """
canghui.symbol.provider.v0
provider=material
namespace=canghui_symbol_material
providerType=MaterialSymbolProvider
adapterType=MaterialSymbolAdapter
repository=https://example.invalid/material
revision=test
version=test
license=Apache-2.0
symbol=add|variants=outlined|directional=false|source=../add.svg
"""
    try {
        let _ = parseSymbolCatalog(unsafePath, "unsafe-path.catalog")
        @Fail("Catalog source paths must remain relative to their frozen source root.")
    } catch (_: CuicError) {
        @Expect(true)
    }
}
