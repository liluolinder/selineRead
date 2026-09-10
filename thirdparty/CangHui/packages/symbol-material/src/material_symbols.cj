package canghui_symbol_material

import std.collection.{ArrayList, HashSet}
import chui.{Rect, Renderer, SymbolAdapter, SymbolDescriptor, SymbolGlyph, SymbolName, SymbolPaint,
    SymbolProvider, SymbolProviderSource, SymbolVariant, drawSymbolBar, drawSymbolLine}

private let MATERIAL_PROVIDER_ID = "material"

/** Material upstream-name adapter retained outside the provider-neutral core. */
public class MaterialSymbolAdapter <: SymbolAdapter {
    public func providerId(): String { MATERIAL_PROVIDER_ID }

    public func canonicalName(name: String): ?String {
        match (name) {
            case "add" | "plus" => Some("add")
            case "remove" | "minus" => Some("remove")
            case "close" | "cancel" => Some("close")
            case "check" | "done" => Some("check")
            case "chevron-left" | "left" => Some("chevron-left")
            case "chevron-right" | "right" => Some("chevron-right")
            case _ => None
        }
    }
}

/** Optional Material provider. A non-empty `included` array limits the runtime registry subset. */
public class MaterialSymbolProvider <: SymbolProvider {
    private let includeAll: Bool
    private let included = HashSet<String>()

    public init(included!: Array<String> = []) {
        includeAll = included.isEmpty()
        let adapter = MaterialSymbolAdapter()
        for (name in included) {
            match (adapter.canonicalName(name)) {
                case Some(canonical) => this.included.add(canonical)
                case None => throw IllegalArgumentException("unknown Material symbol: " + name)
            }
        }
    }

    public func id(): String { MATERIAL_PROVIDER_ID }

    public func source(): SymbolProviderSource {
        SymbolProviderSource(
            "https://github.com/google/material-design-icons",
            "528cb964c01fb2b09bc3b9208f82b6d8f8c1c1e2",
            "rolling-2026-07-24",
            "Apache-2.0",
            "symbols/web/**/materialsymbolsoutlined/*_24px.svg"
        )
    }

    public func descriptors(): Array<SymbolDescriptor> {
        let out = ArrayList<SymbolDescriptor>()
        add(out, SymbolDescriptor("add", aliases: ["plus"],
            variants: [SymbolVariant.Outlined],
            sourcePath: "symbols/web/add/materialsymbolsoutlined/add_24px.svg"))
        add(out, SymbolDescriptor("remove", aliases: ["minus"],
            variants: [SymbolVariant.Outlined],
            sourcePath: "symbols/web/remove/materialsymbolsoutlined/remove_24px.svg"))
        add(out, SymbolDescriptor("close", aliases: ["cancel"],
            variants: [SymbolVariant.Outlined],
            sourcePath: "symbols/web/close/materialsymbolsoutlined/close_24px.svg"))
        add(out, SymbolDescriptor("check", aliases: ["done"],
            variants: [SymbolVariant.Outlined],
            sourcePath: "symbols/web/check/materialsymbolsoutlined/check_24px.svg"))
        add(out, SymbolDescriptor("chevron-left", aliases: ["left"],
            variants: [SymbolVariant.Outlined], directional: true,
            sourcePath: "symbols/web/chevron_left/materialsymbolsoutlined/chevron_left_24px.svg"))
        add(out, SymbolDescriptor("chevron-right", aliases: ["right"],
            variants: [SymbolVariant.Outlined], directional: true,
            sourcePath: "symbols/web/chevron_right/materialsymbolsoutlined/chevron_right_24px.svg"))
        out.toArray()
    }

    public func resolve(name: String, _: SymbolVariant): ?SymbolGlyph {
        if (!enabled(name)) { return None }
        match (name) {
            case "add" => Some(glyph(name, "symbols/web/add/materialsymbolsoutlined/add_24px.svg",
                {renderer, rect, paint =>
                    drawSymbolBar(renderer, rect, 24.0, 24.0, 5.0, 11.0, 14.0, 2.0, paint)
                    drawSymbolBar(renderer, rect, 24.0, 24.0, 11.0, 5.0, 2.0, 14.0, paint)
                }))
            case "remove" => Some(glyph(name, "symbols/web/remove/materialsymbolsoutlined/remove_24px.svg",
                {renderer, rect, paint =>
                    drawSymbolBar(renderer, rect, 24.0, 24.0, 5.0, 11.0, 14.0, 2.0, paint)
                }))
            case "close" => Some(glyph(name, "symbols/web/close/materialsymbolsoutlined/close_24px.svg",
                {renderer, rect, paint =>
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 6.0, 6.0, 18.0, 18.0, 2.0, paint)
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 18.0, 6.0, 6.0, 18.0, 2.0, paint)
                }))
            case "check" => Some(glyph(name, "symbols/web/check/materialsymbolsoutlined/check_24px.svg",
                {renderer, rect, paint =>
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 4.6, 12.3, 9.6, 17.3, 2.0, paint)
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 9.6, 17.3, 19.4, 7.0, 2.0, paint)
                }))
            case "chevron-left" => Some(glyph(name,
                "symbols/web/chevron_left/materialsymbolsoutlined/chevron_left_24px.svg",
                {renderer, rect, paint =>
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 14.5, 6.0, 8.5, 12.0, 2.0, paint)
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 8.5, 12.0, 14.5, 18.0, 2.0, paint)
                }))
            case "chevron-right" => Some(glyph(name,
                "symbols/web/chevron_right/materialsymbolsoutlined/chevron_right_24px.svg",
                {renderer, rect, paint =>
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 9.5, 6.0, 15.5, 12.0, 2.0, paint)
                    drawSymbolLine(renderer, rect, 24.0, 24.0, 15.5, 12.0, 9.5, 18.0, 2.0, paint)
                }))
            case _ => None
        }
    }

    private func add(out: ArrayList<SymbolDescriptor>, descriptor: SymbolDescriptor): Unit {
        if (enabled(descriptor.name)) { out.add(descriptor) }
    }

    private func enabled(name: String): Bool { includeAll || included.contains(name) }

    private func glyph(name: String, sourcePath: String,
        painter: (Renderer, Rect, SymbolPaint) -> Unit): SymbolGlyph {
        SymbolGlyph(MATERIAL_PROVIDER_ID, name, sourcePath, painter)
    }
}

public class MaterialSymbols {
    private init() {}

    public static func add(): SymbolName { SymbolName("add", provider: MATERIAL_PROVIDER_ID) }
    public static func remove(): SymbolName { SymbolName("remove", provider: MATERIAL_PROVIDER_ID) }
    public static func close(): SymbolName { SymbolName("close", provider: MATERIAL_PROVIDER_ID) }
    public static func check(): SymbolName { SymbolName("check", provider: MATERIAL_PROVIDER_ID) }
    public static func chevronLeft(): SymbolName { SymbolName("chevron-left", provider: MATERIAL_PROVIDER_ID) }
    public static func chevronRight(): SymbolName { SymbolName("chevron-right", provider: MATERIAL_PROVIDER_ID) }
}
