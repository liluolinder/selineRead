package canghui_symbol_ant

import std.collection.{ArrayList, HashSet}
import chui.{Rect, Renderer, SymbolAdapter, SymbolDescriptor, SymbolGlyph, SymbolName, SymbolPaint,
    SymbolProvider, SymbolProviderSource, SymbolVariant, drawSymbolBar, drawSymbolLine}

private let ANT_PROVIDER_ID = "ant"

public class AntSymbolAdapter <: SymbolAdapter {
    public func providerId(): String { ANT_PROVIDER_ID }

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

public class AntSymbolProvider <: SymbolProvider {
    private let includeAll: Bool
    private let included = HashSet<String>()

    public init(included!: Array<String> = []) {
        includeAll = included.isEmpty()
        let adapter = AntSymbolAdapter()
        for (name in included) {
            match (adapter.canonicalName(name)) {
                case Some(canonical) => this.included.add(canonical)
                case None => throw IllegalArgumentException("unknown Ant Design symbol: " + name)
            }
        }
    }

    public func id(): String { ANT_PROVIDER_ID }

    public func source(): SymbolProviderSource {
        SymbolProviderSource(
            "https://github.com/ant-design/ant-design-icons",
            "6c18c63fbcfcf71dae09cd6bd6d63a48f8b688f1",
            "rolling-2026-07-06",
            "MIT",
            "packages/icons-svg/svg/outlined"
        )
    }

    public func descriptors(): Array<SymbolDescriptor> {
        let out = ArrayList<SymbolDescriptor>()
        add(out, descriptor("plus", ["add"], "plus.svg"))
        add(out, descriptor("minus", ["remove"], "minus.svg"))
        add(out, descriptor("close", ["cancel"], "close.svg"))
        add(out, descriptor("check", ["done"], "check.svg"))
        add(out, descriptor("left", ["chevron-left"], "left.svg", directional: true))
        add(out, descriptor("right", ["chevron-right"], "right.svg", directional: true))
        out.toArray()
    }

    public func resolve(name: String, _: SymbolVariant): ?SymbolGlyph {
        if (!enabled(name)) { return None }
        match (name) {
            case "plus" => Some(glyph(name, "plus.svg", {renderer, rect, paint =>
                drawSymbolBar(renderer, rect, 1024.0, 1024.0, 482.0, 152.0, 68.0, 720.0, paint)
                drawSymbolBar(renderer, rect, 1024.0, 1024.0, 152.0, 474.0, 720.0, 76.0, paint)
            }))
            case "minus" => Some(glyph(name, "minus.svg", {renderer, rect, paint =>
                drawSymbolBar(renderer, rect, 1024.0, 1024.0, 144.0, 474.0, 736.0, 76.0, paint)
            }))
            case "close" => Some(glyph(name, "close.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 210.0, 210.0, 814.0, 814.0, 82.0, paint)
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 814.0, 210.0, 210.0, 814.0, 82.0, paint)
            }))
            case "check" => Some(glyph(name, "check.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 150.0, 500.0, 405.0, 790.0, 78.0, paint)
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 405.0, 790.0, 875.0, 220.0, 78.0, paint)
            }))
            case "left" => Some(glyph(name, "left.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 715.0, 180.0, 305.0, 512.0, 78.0, paint)
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 305.0, 512.0, 715.0, 844.0, 78.0, paint)
            }))
            case "right" => Some(glyph(name, "right.svg", {renderer, rect, paint =>
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 309.0, 180.0, 719.0, 512.0, 78.0, paint)
                drawSymbolLine(renderer, rect, 1024.0, 1024.0, 719.0, 512.0, 309.0, 844.0, 78.0, paint)
            }))
            case _ => None
        }
    }

    private func descriptor(name: String, aliases: Array<String>, file: String,
        directional!: Bool = false): SymbolDescriptor {
        SymbolDescriptor(name, aliases: aliases, directional: directional,
            sourcePath: "packages/icons-svg/svg/outlined/" + file)
    }

    private func add(out: ArrayList<SymbolDescriptor>, value: SymbolDescriptor): Unit {
        if (enabled(value.name)) { out.add(value) }
    }

    private func enabled(name: String): Bool { includeAll || included.contains(name) }

    private func glyph(name: String, file: String, painter: (Renderer, Rect, SymbolPaint) -> Unit): SymbolGlyph {
        SymbolGlyph(ANT_PROVIDER_ID, name, "packages/icons-svg/svg/outlined/" + file, painter)
    }
}

public class AntSymbols {
    private init() {}
    public static func plus(): SymbolName { SymbolName("plus", provider: ANT_PROVIDER_ID) }
    public static func minus(): SymbolName { SymbolName("minus", provider: ANT_PROVIDER_ID) }
    public static func close(): SymbolName { SymbolName("close", provider: ANT_PROVIDER_ID) }
    public static func check(): SymbolName { SymbolName("check", provider: ANT_PROVIDER_ID) }
    public static func left(): SymbolName { SymbolName("left", provider: ANT_PROVIDER_ID) }
    public static func right(): SymbolName { SymbolName("right", provider: ANT_PROVIDER_ID) }
}
