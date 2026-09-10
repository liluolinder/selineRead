package canghui_symbol_arco

import std.collection.{ArrayList, HashSet}
import chui.{Rect, Renderer, SymbolAdapter, SymbolDescriptor, SymbolGlyph, SymbolName, SymbolPaint,
    SymbolProvider, SymbolProviderSource, SymbolVariant, drawSymbolLine}

private let ARCO_PROVIDER_ID = "arco"

public class ArcoSymbolAdapter <: SymbolAdapter {
    public func providerId(): String { ARCO_PROVIDER_ID }

    public func canonicalName(name: String): ?String {
        match (name) {
            case "plus" | "add" => Some("plus")
            case "minus" | "remove" => Some("minus")
            case "close" | "cancel" => Some("close")
            case "check" | "done" => Some("check")
            case "left" | "chevron-left" => Some("left")
            case "right" | "chevron-right" => Some("right")
            case _ => None
        }
    }
}

public class ArcoSymbolProvider <: SymbolProvider {
    private let includeAll: Bool
    private let included = HashSet<String>()

    public init(included!: Array<String> = []) {
        includeAll = included.isEmpty()
        let adapter = ArcoSymbolAdapter()
        for (name in included) {
            match (adapter.canonicalName(name)) {
                case Some(canonical) => this.included.add(canonical)
                case None => throw IllegalArgumentException("unknown Arco symbol: " + name)
            }
        }
    }

    public func id(): String { ARCO_PROVIDER_ID }

    public func source(): SymbolProviderSource {
        SymbolProviderSource(
            "https://github.com/arco-design/arco-design",
            "fbf2ec0a8cc28a5d20f1f82de6c2c4196ef66950",
            "2.66.16",
            "MIT",
            "icon/_svgs"
        )
    }

    public func descriptors(): Array<SymbolDescriptor> {
        let out = ArrayList<SymbolDescriptor>()
        add(out, descriptor("plus", ["add"], "tips/outline/plus.svg"))
        add(out, descriptor("minus", ["remove"], "tips/outline/minus.svg"))
        add(out, descriptor("close", ["cancel"], "tips/outline/close.svg"))
        add(out, descriptor("check", ["done"], "tips/outline/check.svg"))
        add(out, descriptor("left", ["chevron-left"], "direction/outline/left.svg", directional: true))
        add(out, descriptor("right", ["chevron-right"], "direction/outline/right.svg", directional: true))
        out.toArray()
    }

    public func resolve(name: String, _: SymbolVariant): ?SymbolGlyph {
        if (!enabled(name)) { return None }
        match (name) {
            case "plus" => Some(glyph(name, "tips/outline/plus.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 48.0, 48.0, 5.0, 24.0, 43.0, 24.0, 4.0, paint)
                drawSymbolLine(renderer, rect, 48.0, 48.0, 24.0, 5.0, 24.0, 43.0, 4.0, paint)
            }))
            case "minus" => Some(glyph(name, "tips/outline/minus.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 48.0, 48.0, 5.0, 24.0, 43.0, 24.0, 4.0, paint)
            }))
            case "close" => Some(glyph(name, "tips/outline/close.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 48.0, 48.0, 9.86, 9.86, 38.14, 38.14, 4.0, paint)
                drawSymbolLine(renderer, rect, 48.0, 48.0, 38.14, 9.86, 9.86, 38.14, 4.0, paint)
            }))
            case "check" => Some(glyph(name, "tips/outline/check.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 48.0, 48.0, 6.32, 20.95, 19.05, 33.68, 4.0, paint)
                drawSymbolLine(renderer, rect, 48.0, 48.0, 19.05, 33.68, 41.68, 11.05, 4.0, paint)
            }))
            case "left" => Some(glyph(name, "direction/outline/left.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 48.0, 48.0, 32.0, 8.4, 16.44, 23.96, 4.0, paint)
                drawSymbolLine(renderer, rect, 48.0, 48.0, 16.44, 23.96, 32.0, 39.51, 4.0, paint)
            }))
            case "right" => Some(glyph(name, "direction/outline/right.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 48.0, 48.0, 16.0, 8.4, 31.56, 23.96, 4.0, paint)
                drawSymbolLine(renderer, rect, 48.0, 48.0, 31.56, 23.96, 16.0, 39.51, 4.0, paint)
            }))
            case _ => None
        }
    }

    private func descriptor(name: String, aliases: Array<String>, path: String,
        directional!: Bool = false): SymbolDescriptor {
        SymbolDescriptor(name, aliases: aliases, directional: directional, sourcePath: "icon/_svgs/" + path)
    }

    private func add(out: ArrayList<SymbolDescriptor>, value: SymbolDescriptor): Unit {
        if (enabled(value.name)) { out.add(value) }
    }

    private func enabled(name: String): Bool { includeAll || included.contains(name) }

    private func glyph(name: String, path: String, painter: (Renderer, Rect, SymbolPaint) -> Unit): SymbolGlyph {
        SymbolGlyph(ARCO_PROVIDER_ID, name, "icon/_svgs/" + path, painter)
    }
}

public class ArcoSymbols {
    private init() {}
    public static func plus(): SymbolName { SymbolName("plus", provider: ARCO_PROVIDER_ID) }
    public static func minus(): SymbolName { SymbolName("minus", provider: ARCO_PROVIDER_ID) }
    public static func close(): SymbolName { SymbolName("close", provider: ARCO_PROVIDER_ID) }
    public static func check(): SymbolName { SymbolName("check", provider: ARCO_PROVIDER_ID) }
    public static func left(): SymbolName { SymbolName("left", provider: ARCO_PROVIDER_ID) }
    public static func right(): SymbolName { SymbolName("right", provider: ARCO_PROVIDER_ID) }
}
