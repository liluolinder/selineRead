# Material Symbols Source

- Repository: <https://github.com/google/material-design-icons>
- Revision: `528cb964c01fb2b09bc3b9208f82b6d8f8c1c1e2`
- Snapshot date: `2026-07-24`
- License: Apache-2.0; see `LICENSE`
- Source root: `symbols/web/**/materialsymbolsoutlined/*_24px.svg`

This package adapts the declared six-symbol subset onto CangHui vector
primitives. It does not bundle the complete upstream collection. Provider
registration remains explicit so generated applications retain only their
declared runtime registry entries. The frozen paths in this package are the
outlined SVG sources; unsupported variants degrade deterministically to
outlined and are reported through `SymbolResolution.variantFallback`.
