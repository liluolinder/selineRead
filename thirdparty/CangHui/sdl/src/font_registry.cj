package sdl

import std.collection.{ArrayList, HashMap, HashSet}
import std.env.getVariable
import std.fs.exists

public let CANGHUI_DEFAULT_FONT_FAMILY = "HarmonyOS Sans SC"

public enum FontResolutionSource {
    | Application
    | Theme
    | Bundled
    | System
}

public func fontResolutionSourceName(source: FontResolutionSource): String {
    match (source) {
        case FontResolutionSource.Application => "application"
        case FontResolutionSource.Theme => "theme"
        case FontResolutionSource.Bundled => "bundled"
        case FontResolutionSource.System => "system"
    }
}

/** One resolved face in the application/theme/bundled/system fallback chain. */
public struct FontResolution {
    public let source: FontResolutionSource
    public let family: String
    public let path: String

    public init(source: FontResolutionSource, family: String, path: String) {
        this.source = source
        this.family = family
        this.path = path
    }

    public func sourceName(): String {
        fontResolutionSourceName(source)
    }
}

private class FontRegistryState {
    let registered = HashMap<String, String>()
    var applicationFamily: String = ""
    var bundledOverride: String = ""
    var bundledCache: String = ""
    var generation: UInt64 = 0
}

/** Process-wide names and fallback policy for application-provided font files. */
public class Fonts {
    private static let state = FontRegistryState()

    private init() {}

    public static func register(name: String, path: String): Unit {
        state.registered[name] = path
        state.generation += 1
    }

    public static func pathFor(name: String): ?String {
        state.registered.get(name)
    }

    public static func isRegistered(name: String): Bool {
        state.registered.contains(name)
    }

    public static func unregister(name: String): Unit {
        let _ = state.registered.remove(name)
        state.generation += 1
    }

    /** Clears named application faces while retaining the framework fallback configuration. */
    public static func clear(): Unit {
        state.registered.clear()
        state.generation += 1
    }

    public static func names(): Array<String> {
        let out = ArrayList<String>()
        for ((name, _) in state.registered) {
            out.add(name)
        }
        out.toArray()
    }

    /** Selects a registered family for text that has no component or Theme override. */
    public static func useApplicationFamily(name: String): Unit {
        state.applicationFamily = name
        state.generation += 1
    }

    public static func clearApplicationFamily(): Unit {
        state.applicationFamily = ""
        state.generation += 1
    }

    public static func applicationFamily(): ?String {
        if (state.applicationFamily.isEmpty()) { None } else { Some(state.applicationFamily) }
    }

    /** Overrides automatic packaged-resource discovery for HarmonyOS Sans. */
    public static func registerBundledFallback(path: String): Unit {
        state.bundledOverride = path
        state.bundledCache = ""
        state.generation += 1
    }

    public static func clearBundledFallbackOverride(): Unit {
        state.bundledOverride = ""
        state.bundledCache = ""
        state.generation += 1
    }

    public static func bundledFallbackPath(): ?String {
        if (!state.bundledOverride.isEmpty() && exists(state.bundledOverride)) {
            return Some(state.bundledOverride)
        }
        if (!state.bundledCache.isEmpty() && exists(state.bundledCache)) {
            return Some(state.bundledCache)
        }
        for (candidate in bundledFontCandidates()) {
            if (exists(candidate)) {
                state.bundledCache = candidate
                return Some(candidate)
            }
        }
        None
    }

    /**
     * Returns the deterministic font chain for one text request. Missing names and files are
     * skipped. The final system entry has an empty path and is always present.
     */
    public static func resolutionChain(
        explicitFamily!: ?String = None<String>,
        themeFamily!: ?String = None<String>
    ): Array<FontResolution> {
        let out = ArrayList<FontResolution>()
        let paths = HashSet<String>()
        addRegisteredResolution(out, paths, explicitFamily, FontResolutionSource.Application)
        addRegisteredResolution(out, paths, themeFamily, FontResolutionSource.Theme)
        addRegisteredResolution(out, paths, applicationFamily(), FontResolutionSource.Application)
        match (bundledFallbackPath()) {
            case Some(path) => addResolution(out, paths,
                FontResolution(FontResolutionSource.Bundled, CANGHUI_DEFAULT_FONT_FAMILY, path))
            case None => ()
        }
        out.add(FontResolution(FontResolutionSource.System, "System UI", ""))
        out.toArray()
    }

    public static func resolve(
        explicitFamily!: ?String = None<String>,
        themeFamily!: ?String = None<String>
    ): FontResolution {
        resolutionChain(explicitFamily: explicitFamily, themeFamily: themeFamily)[0]
    }

    /** Monotonic registry version used by renderers to invalidate cached resolution chains. */
    public static func generation(): UInt64 {
        state.generation
    }
}

private func addRegisteredResolution(
    out: ArrayList<FontResolution>,
    paths: HashSet<String>,
    family: ?String,
    source: FontResolutionSource
): Unit {
    match (family) {
        case Some(name) => match (Fonts.pathFor(name)) {
            case Some(path) where exists(path) => addResolution(out, paths, FontResolution(source, name, path))
            case _ => ()
        }
        case None => ()
    }
}

private func addResolution(out: ArrayList<FontResolution>, paths: HashSet<String>, value: FontResolution): Unit {
    if (!paths.contains(value.path)) {
        paths.add(value.path)
        out.add(value)
    }
}

protected func bundledFontCandidatesFor(environmentPath: String): Array<String> {
    let out = ArrayList<String>()
    if (!environmentPath.isEmpty()) { out.add(environmentPath) }
    for (path in [
        "assets/fonts/HarmonyOS_Sans_SC.ttf",
        "Resources/fonts/HarmonyOS_Sans_SC.ttf",
        "resources/fonts/HarmonyOS_Sans_SC.ttf",
        "../assets/fonts/HarmonyOS_Sans_SC.ttf",
        "../../assets/fonts/HarmonyOS_Sans_SC.ttf",
        "../../../assets/fonts/HarmonyOS_Sans_SC.ttf",
        "../Resources/fonts/HarmonyOS_Sans_SC.ttf",
        "../../Resources/fonts/HarmonyOS_Sans_SC.ttf"
    ]) {
        out.add(path)
    }
    out.toArray()
}

private func bundledFontCandidates(): Array<String> {
    let environmentPath = match (getVariable("CANGHUI_HARMONYOS_SANS")) {
        case Some(value) => value.trimAscii()
        case None => ""
    }
    bundledFontCandidatesFor(environmentPath)
}
