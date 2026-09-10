package chui.symbol

import std.collection.{ArrayList, HashSet}
import std.sync.Mutex
import sdl.{Color, IconName, Pen, Point, Rect, Renderer, clampF32, drawIcon}

/** Provider-neutral Symbol protocol version used by runtime and generated registries. */
public let CANGHUI_SYMBOL_PROTOCOL = "canghui.symbol.v0"

public enum SymbolVariant <: Equatable<SymbolVariant> {
    | Outlined
    | Filled
    | Rounded
    | Sharp

    public operator func ==(other: SymbolVariant): Bool {
        symbolVariantName(this) == symbolVariantName(other)
    }

    public operator func !=(other: SymbolVariant): Bool { !(this == other) }
}

public func symbolVariantName(value: SymbolVariant): String {
    match (value) {
        case SymbolVariant.Outlined => "outlined"
        case SymbolVariant.Filled => "filled"
        case SymbolVariant.Rounded => "rounded"
        case SymbolVariant.Sharp => "sharp"
    }
}

public enum SymbolDirection <: Equatable<SymbolDirection> {
    | Inherit
    | LeftToRight
    | RightToLeft

    public operator func ==(other: SymbolDirection): Bool {
        symbolDirectionName(this) == symbolDirectionName(other)
    }

    public operator func !=(other: SymbolDirection): Bool { !(this == other) }
}

public func symbolDirectionName(value: SymbolDirection): String {
    match (value) {
        case SymbolDirection.Inherit => "inherit"
        case SymbolDirection.LeftToRight => "ltr"
        case SymbolDirection.RightToLeft => "rtl"
    }
}

public enum SymbolMissingPolicy <: Equatable<SymbolMissingPolicy> {
    | Fallback
    | Strict

    public operator func ==(other: SymbolMissingPolicy): Bool {
        match ((this, other)) {
            case (SymbolMissingPolicy.Fallback, SymbolMissingPolicy.Fallback) => true
            case (SymbolMissingPolicy.Strict, SymbolMissingPolicy.Strict) => true
            case _ => false
        }
    }

    public operator func !=(other: SymbolMissingPolicy): Bool { !(this == other) }
}

/** Stable Symbol identity. An empty provider selects the built-in provider or a global alias. */
public struct SymbolName {
    public let provider: String
    public let name: String

    public init(name: String, provider!: String = "") {
        validateSymbolToken(name, "symbol name")
        if (!provider.isEmpty()) { validateSymbolToken(provider, "symbol provider") }
        this.provider = provider
        this.name = name
    }

    public func qualified(): String {
        if (provider.isEmpty()) { name } else { provider + "." + name }
    }
}

/** Frozen upstream provenance for one optional provider package. */
public struct SymbolProviderSource {
    public let repository: String
    public let revision: String
    public let version: String
    public let license: String
    public let sourceRoot: String

    public init(repository: String, revision: String, version: String, license: String, sourceRoot: String) {
        if (repository.isEmpty() || revision.isEmpty() || license.isEmpty() || sourceRoot.isEmpty()) {
            throw IllegalArgumentException("symbol provider source fields must not be empty")
        }
        this.repository = repository
        this.revision = revision
        this.version = version
        this.license = license
        this.sourceRoot = sourceRoot
    }
}

/** One canonical provider entry and the variants carried by the current package. */
public class SymbolDescriptor {
    public let name: String
    public let aliases: Array<String>
    public let variants: Array<SymbolVariant>
    public let directional: Bool
    public let sourcePath: String

    public init(
        name: String,
        aliases!: Array<String> = [],
        variants!: Array<SymbolVariant> = [SymbolVariant.Outlined],
        directional!: Bool = false,
        sourcePath!: String = ""
    ) {
        validateSymbolToken(name, "symbol name")
        if (variants.isEmpty()) { throw IllegalArgumentException("symbol variants must not be empty: " + name) }
        for (alias in aliases) { validateSymbolToken(alias, "symbol alias") }
        this.name = name
        this.aliases = aliases
        this.variants = variants
        this.directional = directional
        this.sourcePath = sourcePath
    }

    public func supports(variant: SymbolVariant): Bool {
        let requested = symbolVariantName(variant)
        for (candidate in variants) {
            if (symbolVariantName(candidate) == requested) { return true }
        }
        false
    }
}

/** Optional unqualified alias contributed by a provider adapter. */
public struct SymbolAlias {
    public let alias: String
    public let target: SymbolName

    public init(alias: String, target: SymbolName) {
        validateSymbolToken(alias, "symbol alias")
        if (target.provider.isEmpty()) {
            throw IllegalArgumentException("global symbol aliases require a qualified target")
        }
        this.alias = alias
        this.target = target
    }
}

/** Resolved paint passed to a provider-owned vector painter. */
public struct SymbolPaint {
    public let color: Color
    public let weight: Float32
    public let variant: SymbolVariant
    public let direction: SymbolDirection
    public let mirrored: Bool

    public init(color: Color, weight: Float32, variant: SymbolVariant,
        direction: SymbolDirection, mirrored: Bool) {
        if (weight < 1.0 || weight > 1000.0) {
            throw IllegalArgumentException("symbol weight must be in 1..1000")
        }
        this.color = color
        this.weight = weight
        this.variant = variant
        this.direction = direction
        this.mirrored = mirrored
    }
}

public type SymbolPainter = (Renderer, Rect, SymbolPaint) -> Unit

/** Provider-owned vector glyph retained behind the stable Symbol call surface. */
public class SymbolGlyph {
    public let provider: String
    public let name: String
    public let sourcePath: String
    private let painter: SymbolPainter

    public init(provider: String, name: String, sourcePath: String, painter: SymbolPainter) {
        validateSymbolToken(provider, "symbol provider")
        validateSymbolToken(name, "symbol name")
        this.provider = provider
        this.name = name
        this.sourcePath = sourcePath
        this.painter = painter
    }

    public func draw(renderer: Renderer, rect: Rect, paint: SymbolPaint): Unit {
        painter(renderer, rect, paint)
    }
}

/** Runtime provider contract. Providers may expose all symbols or a generated declared subset. */
public interface SymbolProvider {
    func id(): String
    func source(): SymbolProviderSource
    func descriptors(): Array<SymbolDescriptor>
    func resolve(canonicalName: String, variant: SymbolVariant): ?SymbolGlyph
}

/** Maps upstream names and aliases onto one provider's stable canonical names. */
public interface SymbolAdapter {
    func providerId(): String
    func canonicalName(name: String): ?String

    func globalAliases(): Array<SymbolAlias> {
        []
    }
}

/** Exact runtime result, including deterministic fallback and variant degradation facts. */
public class SymbolResolution {
    public let requested: SymbolName
    public let resolved: SymbolName
    public let descriptor: SymbolDescriptor
    public let glyph: SymbolGlyph
    public let variant: SymbolVariant
    public let fallback: Bool
    public let variantFallback: Bool

    public init(requested: SymbolName, resolved: SymbolName, descriptor: SymbolDescriptor,
        glyph: SymbolGlyph, variant: SymbolVariant, fallback: Bool, variantFallback: Bool) {
        this.requested = requested
        this.resolved = resolved
        this.descriptor = descriptor
        this.glyph = glyph
        this.variant = variant
        this.fallback = fallback
        this.variantFallback = variantFallback
    }
}

/** Deterministic registry suitable for process-wide use or isolated tests. */
public class SymbolRegistry {
    private let mutex = Mutex()
    private let providers = ArrayList<SymbolProvider>()
    private let adapters = ArrayList<SymbolAdapter>()
    private let aliases = ArrayList<SymbolAlias>()

    public init(includeBuiltin!: Bool = true) {
        if (includeBuiltin) {
            register(BuiltinSymbolProvider(), BuiltinSymbolAdapter())
        }
    }

    public func register(provider: SymbolProvider): Unit {
        registerProvider(provider, None)
    }

    public func register(provider: SymbolProvider, adapter: SymbolAdapter): Unit {
        registerProvider(provider, Some(adapter))
    }

    private func registerProvider(provider: SymbolProvider, adapter: ?SymbolAdapter): Unit {
        let providerId = provider.id()
        validateSymbolToken(providerId, "symbol provider")
        let descriptors = provider.descriptors()
        if (descriptors.isEmpty()) {
            throw IllegalArgumentException("symbol provider must expose at least one descriptor: " + providerId)
        }
        validateProviderDescriptors(providerId, descriptors)
        match (adapter) {
            case Some(value) where value.providerId() != providerId =>
                throw IllegalArgumentException("symbol adapter/provider mismatch: " + value.providerId() + " != " + providerId)
            case _ => ()
        }
        synchronized(mutex) {
            for (existing in providers) {
                if (existing.id() == providerId) {
                    throw IllegalStateException("duplicate symbol provider: " + providerId)
                }
            }
            match (adapter) {
                case Some(value) => validateGlobalAliases(providerId, value.globalAliases())
                case None => ()
            }
            providers.add(provider)
            match (adapter) {
                case Some(value) =>
                    adapters.add(value)
                    for (alias in value.globalAliases()) { aliases.add(alias) }
                case None => ()
            }
        }
    }

    public func providerIds(): Array<String> {
        let values = ArrayList<String>()
        synchronized(mutex) {
            for (provider in providers) { values.add(provider.id()) }
        }
        sortSymbolStrings(values.toArray())
    }

    public func descriptors(providerId: String): Array<SymbolDescriptor> {
        synchronized(mutex) {
            match (findProviderLocked(providerId)) {
                case Some(provider) => return sortSymbolDescriptors(provider.descriptors())
                case None => return []
            }
        }
    }

    public func resolve(
        requested: SymbolName,
        variant!: SymbolVariant = SymbolVariant.Outlined,
        policy!: SymbolMissingPolicy = SymbolMissingPolicy.Fallback
    ): SymbolResolution {
        synchronized(mutex) {
            resolveLocked(requested, variant, policy)
        }
    }

    private func resolveLocked(requested: SymbolName, variant: SymbolVariant,
        policy: SymbolMissingPolicy): SymbolResolution {
        let qualified = qualifyLocked(requested)
        match (findProviderLocked(qualified.provider)) {
            case Some(provider) =>
                match (findDescriptorLocked(provider, qualified.name)) {
                    case Some(descriptor) =>
                        let selected = selectedVariant(descriptor, variant)
                        match (provider.resolve(descriptor.name, selected[0])) {
                            case Some(glyph) => return SymbolResolution(requested,
                                SymbolName(descriptor.name, provider: provider.id()), descriptor, glyph,
                                selected[0], false, selected[1])
                            case None => throw IllegalStateException(
                                "symbol provider descriptor has no glyph: " + provider.id() + "." + descriptor.name)
                        }
                    case None => ()
                }
            case None => ()
        }
        if (policy == SymbolMissingPolicy.Strict) {
            throw IllegalArgumentException("symbol not found: " + requested.qualified())
        }
        fallbackResolutionLocked(requested, variant)
    }

    private func fallbackResolutionLocked(requested: SymbolName, variant: SymbolVariant): SymbolResolution {
        match (findProviderLocked("builtin")) {
            case Some(provider) => match (findDescriptorLocked(provider, "missing")) {
                case Some(descriptor) => match (provider.resolve("missing", SymbolVariant.Outlined)) {
                    case Some(glyph) => SymbolResolution(requested, SymbolName("missing", provider: "builtin"),
                        descriptor, glyph, SymbolVariant.Outlined, true,
                        symbolVariantName(variant) != symbolVariantName(SymbolVariant.Outlined))
                    case None => throw IllegalStateException("built-in missing symbol has no glyph")
                }
                case None => throw IllegalStateException("built-in missing symbol descriptor is absent")
            }
            case None => throw IllegalStateException("fallback requested without the built-in symbol provider")
        }
    }

    private func qualifyLocked(requested: SymbolName): SymbolName {
        if (requested.provider.isEmpty()) {
            for (alias in aliases) {
                if (alias.alias == requested.name) { return alias.target }
            }
            return SymbolName(requested.name, provider: "builtin")
        }
        for (adapter in adapters) {
            if (adapter.providerId() == requested.provider) {
                match (adapter.canonicalName(requested.name)) {
                    case Some(canonical) => return SymbolName(canonical, provider: requested.provider)
                    case None => return requested
                }
            }
        }
        requested
    }

    private func findProviderLocked(providerId: String): ?SymbolProvider {
        for (provider in providers) {
            if (provider.id() == providerId) { return Some(provider) }
        }
        None
    }

    private func findDescriptorLocked(provider: SymbolProvider, name: String): ?SymbolDescriptor {
        for (descriptor in provider.descriptors()) {
            if (descriptor.name == name) { return Some(descriptor) }
        }
        None
    }

    private func validateGlobalAliases(providerId: String, values: Array<SymbolAlias>): Unit {
        let local = HashSet<String>()
        for (alias in values) {
            if (alias.target.provider != providerId) {
                throw IllegalArgumentException("global symbol alias target must stay in its provider: " + alias.alias)
            }
            if (local.contains(alias.alias)) {
                throw IllegalStateException("duplicate global symbol alias: " + alias.alias)
            }
            local.add(alias.alias)
            for (existing in aliases) {
                if (existing.alias == alias.alias) {
                    throw IllegalStateException("cross-provider symbol alias collision: " + alias.alias)
                }
            }
        }
    }
}

/** Process-wide registry used by normal Symbol widgets. */
public class Symbols {
    private static let registry = SymbolRegistry()

    private init() {}

    public static func register(provider: SymbolProvider): Unit {
        registry.register(provider)
    }

    public static func register(provider: SymbolProvider, adapter: SymbolAdapter): Unit {
        registry.register(provider, adapter)
    }

    public static func providerIds(): Array<String> {
        registry.providerIds()
    }

    public static func descriptors(providerId: String): Array<SymbolDescriptor> {
        registry.descriptors(providerId)
    }

    public static func resolve(requested: SymbolName,
        variant!: SymbolVariant = SymbolVariant.Outlined,
        policy!: SymbolMissingPolicy = SymbolMissingPolicy.Fallback): SymbolResolution {
        registry.resolve(requested, variant: variant, policy: policy)
    }
}

/** Resolves, records, and paints one Symbol without requiring a widget instance. */
public func drawSymbol(
    renderer: Renderer,
    requested: SymbolName,
    rect: Rect,
    color: Color,
    weight!: Float32 = 400.0,
    variant!: SymbolVariant = SymbolVariant.Outlined,
    direction!: SymbolDirection = SymbolDirection.Inherit,
    mirrored!: Bool = false,
    accessibilityLabel!: String = "",
    policy!: SymbolMissingPolicy = SymbolMissingPolicy.Fallback
): SymbolResolution {
    let resolution = Symbols.resolve(requested, variant: variant, policy: policy)
    let effectiveMirror = mirrored ||
        (resolution.descriptor.directional && direction == SymbolDirection.RightToLeft)
    let paint = SymbolPaint(color, weight, resolution.variant, direction, effectiveMirror)
    renderer.symbolIr(
        resolution.resolved.provider,
        resolution.resolved.name,
        rect,
        color,
        weight: weight,
        filled: symbolVariantName(resolution.variant) == symbolVariantName(SymbolVariant.Filled),
        mirrored: effectiveMirror,
        variant: symbolVariantName(resolution.variant),
        direction: symbolDirectionName(direction),
        accessibilityLabel: accessibilityLabel,
        requestedProvider: requested.provider,
        requestedName: requested.name,
        fallback: resolution.fallback,
        variantFallback: resolution.variantFallback
    )
    resolution.glyph.draw(renderer, rect, paint)
    resolution
}

/** Maps one provider viewport point into the destination rectangle. */
public func symbolPoint(rect: Rect, viewportWidth: Float32, viewportHeight: Float32,
    x: Float32, y: Float32, mirrored: Bool): Point {
    let logicalX = if (mirrored) { viewportWidth - x } else { x }
    Point(rect.x + rect.w * logicalX / viewportWidth, rect.y + rect.h * y / viewportHeight)
}

/** Draws one provider-space line with weight scaled to the destination extent. */
public func drawSymbolLine(renderer: Renderer, rect: Rect, viewportWidth: Float32, viewportHeight: Float32,
    x1: Float32, y1: Float32, x2: Float32, y2: Float32, baseWidth: Float32, paint: SymbolPaint): Unit {
    let from = symbolPoint(rect, viewportWidth, viewportHeight, x1, y1, paint.mirrored)
    let to = symbolPoint(rect, viewportWidth, viewportHeight, x2, y2, paint.mirrored)
    renderer.strokeLine(from.x, from.y, to.x, to.y,
        Pen(width: symbolStrokeWidth(rect, viewportWidth, viewportHeight, baseWidth, paint.weight), color: paint.color))
}

/** Draws one provider-space filled bar, preserving square-ended source silhouettes. */
public func drawSymbolBar(renderer: Renderer, rect: Rect, viewportWidth: Float32, viewportHeight: Float32,
    x: Float32, y: Float32, width: Float32, height: Float32, paint: SymbolPaint): Unit {
    let scale = clampF32(paint.weight / 400.0, 0.25, 2.5)
    let centerX = x + width / 2.0
    let centerY = y + height / 2.0
    let weightedWidth = if (width < height) { width * scale } else { width }
    let weightedHeight = if (height < width) { height * scale } else { height }
    let left = centerX - weightedWidth / 2.0
    let top = centerY - weightedHeight / 2.0
    let first = symbolPoint(rect, viewportWidth, viewportHeight, left, top, paint.mirrored)
    let second = symbolPoint(rect, viewportWidth, viewportHeight,
        left + weightedWidth, top + weightedHeight, paint.mirrored)
    let widthValue = second.x - first.x
    let heightValue = second.y - first.y
    renderer.fill(Rect(min(first.x, second.x), min(first.y, second.y),
        max(0.0, if (widthValue < 0.0) { -widthValue } else { widthValue }),
        max(0.0, if (heightValue < 0.0) { -heightValue } else { heightValue })), paint.color)
}

public func symbolNameForIcon(icon: IconName): SymbolName {
    SymbolName(builtinSymbolName(icon), provider: "builtin")
}

private class BuiltinSymbolProvider <: SymbolProvider {
    public func id(): String { "builtin" }

    public func source(): SymbolProviderSource {
        SymbolProviderSource("CangHui", "built-in", "0.17.0", "MIT", "sdl/src/icon_draw.cj")
    }

    public func descriptors(): Array<SymbolDescriptor> {
        let out = ArrayList<SymbolDescriptor>()
        for (name in [
            "new-document", "open-folder", "save", "save-as", "copy", "paste", "refresh", "trash",
            "brush", "calendar", "clock", "process", "calculator", "chevron-left", "chevron-right",
            "sun", "moon", "missing"
        ]) {
            out.add(SymbolDescriptor(name, aliases: builtinAliases(name),
                directional: name == "chevron-left" || name == "chevron-right",
                sourcePath: "sdl/src/icon_draw.cj"))
        }
        out.toArray()
    }

    public func resolve(canonicalName: String, _: SymbolVariant): ?SymbolGlyph {
        if (canonicalName == "missing") {
            return Some(SymbolGlyph("builtin", "missing", "sdl/src/icon_draw.cj") {renderer, rect, paint =>
                let width = symbolStrokeWidth(rect, 24.0, 24.0, 1.8, paint.weight)
                renderer.strokeRoundedRect(rect.inset(max(1.0, width)), max(1.0, rect.w * 0.12),
                    Pen(width: width, color: paint.color))
                drawSymbolLine(renderer, rect, 24.0, 24.0, 7.0, 7.0, 17.0, 17.0, 1.8, paint)
                drawSymbolLine(renderer, rect, 24.0, 24.0, 17.0, 7.0, 7.0, 17.0, 1.8, paint)
            })
        }
        match (iconForBuiltinSymbol(canonicalName)) {
            case Some(icon) =>
                let selected = icon
                Some(SymbolGlyph("builtin", canonicalName, "sdl/src/icon_draw.cj") {renderer, rect, paint =>
                    drawIcon(renderer, selected, rect, paint.color,
                        weight: symbolStrokeWidth(rect, 24.0, 24.0, 1.6, paint.weight))
                })
            case None => None
        }
    }
}

private class BuiltinSymbolAdapter <: SymbolAdapter {
    public func providerId(): String { "builtin" }

    public func canonicalName(name: String): ?String {
        for (descriptor in BuiltinSymbolProvider().descriptors()) {
            if (descriptor.name == name) { return Some(name) }
            for (alias in descriptor.aliases) {
                if (alias == name) { return Some(descriptor.name) }
            }
        }
        None
    }
}

private func builtinAliases(name: String): Array<String> {
    match (name) {
        case "new-document" => ["new", "file-add"]
        case "open-folder" => ["folder-open"]
        case "trash" => ["delete"]
        case "chevron-left" => ["left"]
        case "chevron-right" => ["right"]
        case _ => []
    }
}

private func builtinSymbolName(icon: IconName): String {
    match (icon) {
        case IconName.NewDocument => "new-document"
        case IconName.OpenFolder => "open-folder"
        case IconName.Save => "save"
        case IconName.SaveAs => "save-as"
        case IconName.Copy => "copy"
        case IconName.Paste => "paste"
        case IconName.Refresh => "refresh"
        case IconName.Trash => "trash"
        case IconName.Brush => "brush"
        case IconName.Calendar => "calendar"
        case IconName.Clock => "clock"
        case IconName.Process => "process"
        case IconName.Calculator => "calculator"
        case IconName.ChevronLeft => "chevron-left"
        case IconName.ChevronRight => "chevron-right"
        case IconName.Sun => "sun"
        case IconName.Moon => "moon"
    }
}

private func iconForBuiltinSymbol(name: String): ?IconName {
    match (name) {
        case "new-document" => Some(IconName.NewDocument)
        case "open-folder" => Some(IconName.OpenFolder)
        case "save" => Some(IconName.Save)
        case "save-as" => Some(IconName.SaveAs)
        case "copy" => Some(IconName.Copy)
        case "paste" => Some(IconName.Paste)
        case "refresh" => Some(IconName.Refresh)
        case "trash" => Some(IconName.Trash)
        case "brush" => Some(IconName.Brush)
        case "calendar" => Some(IconName.Calendar)
        case "clock" => Some(IconName.Clock)
        case "process" => Some(IconName.Process)
        case "calculator" => Some(IconName.Calculator)
        case "chevron-left" => Some(IconName.ChevronLeft)
        case "chevron-right" => Some(IconName.ChevronRight)
        case "sun" => Some(IconName.Sun)
        case "moon" => Some(IconName.Moon)
        case _ => None
    }
}

private func symbolStrokeWidth(rect: Rect, viewportWidth: Float32, viewportHeight: Float32,
    baseWidth: Float32, weight: Float32): Float32 {
    let extentScale = min(rect.w / viewportWidth, rect.h / viewportHeight)
    max(0.5, baseWidth * extentScale * clampF32(weight / 400.0, 0.25, 2.5))
}

private func selectedVariant(descriptor: SymbolDescriptor, requested: SymbolVariant): (SymbolVariant, Bool) {
    if (descriptor.supports(requested)) { return (requested, false) }
    if (descriptor.supports(SymbolVariant.Outlined)) {
        return (SymbolVariant.Outlined, true)
    }
    (descriptor.variants[0], true)
}

private func validateProviderDescriptors(providerId: String, descriptors: Array<SymbolDescriptor>): Unit {
    let names = HashSet<String>()
    let localAliases = HashSet<String>()
    for (descriptor in descriptors) {
        if (names.contains(descriptor.name)) {
            throw IllegalStateException("duplicate canonical symbol name: " + providerId + "." + descriptor.name)
        }
        names.add(descriptor.name)
    }
    for (descriptor in descriptors) {
        for (alias in descriptor.aliases) {
            if (names.contains(alias) || localAliases.contains(alias)) {
                throw IllegalStateException("duplicate provider symbol alias: " + providerId + "." + alias)
            }
            localAliases.add(alias)
        }
    }
}

private func validateSymbolToken(value: String, label: String): Unit {
    if (value.isEmpty()) { throw IllegalArgumentException(label + " must not be empty") }
    var segmentStart = true
    for (r in value.toRuneArray()) {
        let letter = r >= r'a' && r <= r'z'
        let digit = r >= r'0' && r <= r'9'
        if (r == r'-') {
            if (segmentStart) { throw IllegalArgumentException(label + " has an empty segment: " + value) }
            segmentStart = true
        } else {
            if ((!letter && !digit) || (segmentStart && digit)) {
                throw IllegalArgumentException(label + " accepts lowercase letters, digits and hyphens: " + value)
            }
            segmentStart = false
        }
    }
    if (segmentStart) { throw IllegalArgumentException(label + " must not end with a hyphen: " + value) }
}

private func sortSymbolStrings(values: Array<String>): Array<String> {
    var i: Int64 = 0
    while (i < values.size) {
        var j: Int64 = i + 1
        while (j < values.size) {
            if (values[j] < values[i]) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}

private func sortSymbolDescriptors(values: Array<SymbolDescriptor>): Array<SymbolDescriptor> {
    var i: Int64 = 0
    while (i < values.size) {
        var j: Int64 = i + 1
        while (j < values.size) {
            if (values[j].name < values[i].name) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}
