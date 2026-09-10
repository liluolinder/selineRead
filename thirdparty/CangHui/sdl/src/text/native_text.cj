package sdl.text

import std.collection.{ArrayList, HashMap, HashSet}
import std.env.getVariable
import std.math.abs

private let DEFAULT_POINT_SIZE: Float32 = 15.0
private let FONT_SIZE_EPSILON: Float32 = 0.01
private let MAX_NAMED_FONT_INSTANCES: Int64 = 32
private let MAX_TEXT_MEASURE_CACHE_ENTRIES: Int64 = 2048
private let FONT_INSTANCE_SHIFT: Int64 = 16
private let FONT_CREATE_FILENAME_PROPERTY = "SDL_ttf.font.create.filename"
private let FONT_CREATE_SIZE_PROPERTY = "SDL_ttf.font.create.size"
private let FONT_CREATE_FACE_PROPERTY = "SDL_ttf.font.create.face"

// TTF_STYLE_BOLD, and the mask of every other flag (italic/underline/strikethrough). Bold is the
// one style worth a real companion face — synthetic emboldening thickens strokes unevenly and
// roughens edges, while slants and rules synthesise cleanly.
private let STYLE_BOLD: Int32 = 0x01
private let STYLE_NON_BOLD_MASK: Int32 = 0x0E

// SDL_Color packed as the UInt32 the TTF_RenderText_Blended binding declares: white at full
// alpha. Glyph coverage is colour-independent, so surfaces render white once and callers apply
// the actual colour as a texture colour mod.
private let WHITE_TEXT_PIXEL: UInt32 = 0xFFFFFFFF

protected class NativeTextException <: Exception {
    public init(message: String) {
        super(message)
    }
}

protected struct NativeTextMetrics {
    public let width: Float32
    public let height: Float32

    public init(width: Float32, height: Float32) {
        this.width = width
        this.height = height
    }
}

protected struct NativeTextColor {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }
}

protected class NativeTextRenderer {
    private let engine: CPointer<Unit>
    private let systemPath: String
    // The always-available platform UI font. Every text draw with no explicit face, and any face
    // whose file cannot be opened, falls back to this.
    private let defaultFace: FontFace
    // Successfully opened application font files, keyed by file path — opened lazily on first use.
    private let faces = HashMap<String, FontFace>()
    // Paths that failed to open once, remembered so a bad path degrades to the system font without
    // re-attempting the open every frame.
    private let failedPaths = HashSet<String>()
    // Layout may ask for the same label metrics through several ancestor measure passes before
    // placing it. On device-class CPUs, repeating glyph coverage and TTF_GetStringSize for every
    // pass dominates the first frame, so retain one bounded renderer-local metrics cache.
    private let measureCache = HashMap<String, NativeTextMetrics>()
    private var closed: Bool = false

    /**
     * Throws `NativeTextException` when SDL_ttf cannot initialize the system-font backend.
     */
    public init(renderer: CPointer<Unit>) {
        if (!unsafe { TTF_Init() }) {
            throw NativeTextException("TTF_Init failed: ${lastNativeError()}")
        }
        let found = findSystemFontPath()
        if (let Some(value) <- found) {
            this.systemPath = value
        } else {
            unsafe { TTF_Quit() }
            throw NativeTextException("No supported system UI font was found: ${lastNativeError()}")
        }
        let createdEngine = unsafe { TTF_CreateRendererTextEngine(renderer) }
        this.engine = createdEngine
        if (createdEngine.isNull()) {
            unsafe { TTF_Quit() }
            throw NativeTextException("TTF_CreateRendererTextEngine failed: ${lastNativeError()}")
        }
        this.defaultFace = FontFace(systemPath, engine)
        // Warm the default face at the base size, so a font engine that cannot shape for the system
        // font fails fast at construction (as the previous eager text object did) rather than mid-frame.
        try {
            defaultFace.fontFor(DEFAULT_POINT_SIZE, 0)
        } catch (error: NativeTextException) {
            defaultFace.close()
            unsafe {
                TTF_DestroyRendererTextEngine(engine)
                TTF_Quit()
            }
            throw error
        }
    }

    public func measure(
        text: String,
        pointSize: Float32,
        styleFlags: Int32,
        facePaths: Array<String>
    ): NativeTextMetrics {
        let cacheKey = textMeasureCacheKey(text, pointSize, styleFlags, facePaths)
        match (measureCache.get(cacheKey)) {
            case Some(cached) => return cached
            case None => ()
        }
        let font = fontForText(text, facePaths, pointSize, styleFlags)
        let cText = unsafe { LibC.mallocCString(text) }
        var metrics = NativeTextMetrics(0.0, 0.0)
        try (textResource = cText.asResource()) {
            var width: Int32 = 0
            var height: Int32 = 0
            ensureNative(unsafe {
                TTF_GetStringSize(font.pointer(), textResource.value, UIntNative(text.size), inout width, inout height)
            }, "TTF_GetStringSize")
            metrics = NativeTextMetrics(Float32(width), Float32(height))
        }
        if (measureCache.size >= MAX_TEXT_MEASURE_CACHE_ENTRIES) {
            measureCache.clear()
        }
        measureCache[cacheKey] = metrics
        metrics
    }

    /**
     * Rasterizes `text` into a new RGBA surface via TTF_RenderText_Blended and returns the raw
     * SDL surface pointer — null for empty text or when rasterization fails. Glyphs are white at
     * full alpha so the caller can colour the resulting texture with a colour mod, which also
     * keeps colour out of any caching key. The caller owns the surface and must destroy it.
     *
     * This is the path for text that must be transformed (rotated axis titles): the text engine
     * `draw` uses rasterizes straight onto the render target and cannot rotate, while a surface
     * can become a texture and go through the rotating texture pipeline.
     */
    public func renderSurface(
        text: String,
        pointSize: Float32,
        styleFlags: Int32,
        facePaths: Array<String>
    ): CPointer<Unit> {
        if (text.isEmpty()) {
            return CPointer<Unit>()
        }
        let font = fontForText(text, facePaths, pointSize, styleFlags)
        let cText = unsafe { LibC.mallocCString(text) }
        var surface = CPointer<Unit>()
        try (textResource = cText.asResource()) {
            surface = unsafe {
                TTF_RenderText_Blended(font.pointer(), textResource.value, UIntNative(text.size), WHITE_TEXT_PIXEL)
            }
        }
        surface
    }

    public func draw(
        text: String,
        x: Float32,
        y: Float32,
        pointSize: Float32,
        styleFlags: Int32,
        facePaths: Array<String>,
        color: NativeTextColor
    ): Unit {
        if (text.isEmpty()) {
            return
        }
        // The font reuses a cached, already-shaped text object for `text`, so an unchanged string
        // (every visible label during a scroll) is not re-shaped by SDL_ttf — only redrawn.
        fontForText(text, facePaths, pointSize, styleFlags).drawText(text, x, y, color)
    }

    /** Returns the concrete face path selected after glyph-coverage fallback. */
    public func resolvedPath(
        text: String,
        pointSize: Float32,
        styleFlags: Int32,
        facePaths: Array<String>
    ): String {
        fontForText(text, facePaths, pointSize, styleFlags).sourcePath
    }

    /* Selects the first usable face that contains every printable rune in the string. If no face
     * covers the complete string, the first successfully opened face is retained so rendering stays
     * deterministic and the native backend can draw its missing-glyph marker. */
    private func fontForText(
        text: String,
        facePaths: Array<String>,
        pointSize: Float32,
        styleFlags: Int32
    ): NativeFont {
        var first: ?NativeFont = None
        for (facePath in facePaths) {
            match (fontCandidate(facePath, pointSize, styleFlags)) {
                case Some(font) =>
                    if (first.isNone()) { first = Some(font) }
                    if (font.supports(text)) { return font }
                case None => ()
            }
        }
        match (first) {
            case Some(font) => font
            case None => defaultFace.fontFor(pointSize, styleFlags)
        }
    }

    private func fontCandidate(facePath: String, pointSize: Float32, styleFlags: Int32): ?NativeFont {
        if (facePath.isEmpty()) {
            return Some(defaultFace.fontFor(pointSize, styleFlags))
        }
        if (failedPaths.contains(facePath)) { return None }
        let face = match (faces.get(facePath)) {
            case Some(cached) => cached
            case None =>
                let created = FontFace(facePath, engine)
                faces[facePath] = created
                created
        }
        try {
            Some(face.fontFor(pointSize, styleFlags))
        } catch (_: NativeTextException) {
            failedPaths.add(facePath)
            match (faces.get(facePath)) {
                case Some(cached) => cached.close()
                case None => ()
            }
            let _ = faces.remove(facePath)
            None
        }
    }

    /*
     * Total shaping operations across all faces and sizes since the last reset — each is one
     * TTF_CreateText, a shaped-text cache miss. A per-frame text-cost probe: on a warm cache this
     * stays flat while draw calls scale with frames, which is the caching doing its job.
     */
    public func shapeCount(): UInt64 {
        var total = defaultFace.shapeCount()
        for ((_, face) in faces) {
            total += face.shapeCount()
        }
        total
    }

    public func resetShapeCount(): Unit {
        defaultFace.resetShapeCount()
        for ((_, face) in faces) {
            face.resetShapeCount()
        }
    }

    public func familyName(): String {
        let name = defaultFace.familyName()
        if (name.isEmpty()) {
            "System UI"
        } else {
            name
        }
    }

    public func path(): String {
        systemPath
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        defaultFace.close()
        for ((_, face) in faces) {
            face.close()
        }
        faces.clear()
        measureCache.clear()
        unsafe {
            TTF_DestroyRendererTextEngine(engine)
            TTF_Quit()
        }
    }

}

private func textMeasureCacheKey(
    text: String,
    pointSize: Float32,
    styleFlags: Int32,
    facePaths: Array<String>
): String {
    var key = "${pointSize}|${styleFlags}"
    for (path in facePaths) {
        key += "|${path}"
    }
    key + "|${text}"
}

/*
 * One typeface: a font file opened at whatever (size, style) combinations the UI asks for. Each
 * combination is its own TTF_Font handle with its own shaped-text cache — TTF_SetFontStyle changes
 * glyph shape and advance width, so a variant needs a distinct handle for correct measurement and
 * rendering. The default system font and every application-loaded font are each one FontFace.
 */
private class FontFace {
    private let path: String
    private let engine: CPointer<Unit>
    private let fonts = ArrayList<NativeFont>()
    private var closed: Bool = false
    // Lazily probed path of the true-bold companion file; None when the face has no separately
    // shipped bold weight and bold must be synthesised.
    private var boldProbed: Bool = false
    private var boldCompanionPath: ?String = None
    // Variable fonts can carry true named weights inside one file (HarmonyOS Sans SC does). Keep
    // the encoded FreeType named-instance face index so bold does not degrade to faux emboldening.
    private var boldInstanceProbed: Bool = false
    private var boldInstanceFaceIndex: ?Int64 = None

    init(path: String, engine: CPointer<Unit>) {
        this.path = path
        this.engine = engine
    }

    // A font handle for the requested size and style, opened, style-set, and attached on first use
    // and cached for reuse. Throws `NativeTextException` when the file cannot be opened or the engine
    // cannot shape for it.
    func fontFor(pointSize: Float32, styleFlags: Int32): NativeFont {
        let normalized = normalizePointSize(pointSize)
        for (font in fonts) {
            if (font.styleFlags == styleFlags && abs(font.pointSize - normalized) < FONT_SIZE_EPSILON) {
                return font
            }
        }
        let font = openStyled(normalized, styleFlags)
        // Close the freshly opened font if it cannot attach: it is not yet in `fonts`, so close()
        // would never reach it, and there is no finalizer — a failed attach would otherwise leak the
        // native TTF_Font handle.
        try {
            font.attach(engine)
        } catch (error: NativeTextException) {
            font.close()
            throw error
        }
        fonts.add(font)
        font
    }

    /*
     * Opens the handle for (size, style), preferring real bold outlines over synthetic ones. A bold
     * request first selects an in-file variable-font Bold instance, then a companion file when one
     * ships alongside (msyh.ttc -> msyhbd.ttc, segoeui.ttf -> segoeuib.ttf, X-Regular -> X-Bold).
     * Only the remaining flags are synthesised on a real bold face; if neither route opens, every
     * requested flag is synthesised from the base face.
     */
    private func openStyled(pointSize: Float32, styleFlags: Int32): NativeFont {
        if ((styleFlags & STYLE_BOLD) != 0) {
            if (let Some(faceIndex) <- boldInstance()) {
                try {
                    return openFontAtFace(path, pointSize, faceIndex, styleFlags,
                        styleFlags & STYLE_NON_BOLD_MASK, path)
                } catch (_: NativeTextException) {
                    // The base face remains usable; continue to a separate companion or faux bold.
                }
            }
            if (let Some(boldFile) <- boldCompanion()) {
                try {
                    return openFont(boldFile, pointSize, styleFlags, styleFlags & STYLE_NON_BOLD_MASK, path)
                } catch (_: NativeTextException) {
                    // Degrade like every other font failure: the base file still renders, in faux bold.
                }
            }
        }
        openFont(path, pointSize, styleFlags, styleFlags, path)
    }

    private func boldInstance(): ?Int64 {
        if (!boldInstanceProbed) {
            boldInstanceProbed = true
            boldInstanceFaceIndex = probeBoldNamedInstance(path)
        }
        boldInstanceFaceIndex
    }

    // The true-bold companion file's path, probed once per face and remembered (None when the face
    // ships no separate bold weight).
    private func boldCompanion(): ?String {
        if (!boldProbed) {
            boldProbed = true
            boldCompanionPath = probeBoldCompanion(path)
        }
        boldCompanionPath
    }

    func familyName(): String {
        if (fonts.isEmpty()) {
            return ""
        }
        let name = unsafe { TTF_GetFontFamilyName(fonts[0].pointer()) }
        if (name.isNull()) {
            ""
        } else {
            name.toString()
        }
    }

    func shapeCount(): UInt64 {
        var total: UInt64 = 0
        for (font in fonts) {
            total += font.shapeCount
        }
        total
    }

    func resetShapeCount(): Unit {
        for (font in fonts) {
            font.shapeCount = 0
        }
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        var index = fonts.size - 1
        while (index >= 0) {
            fonts[index].close()
            index -= 1
        }
        fonts.clear()
    }
}

// One shaped, ready-to-draw text object plus the colour last applied to it, so redrawing the same
// string in the same colour next frame skips even the colour update.
internal class ShapedText {
    let pointer: CPointer<Unit>
    var colorKey: Int64 = -1

    init(pointer: CPointer<Unit>) {
        this.pointer = pointer
    }
}

// Packs an RGBA colour into one Int64 so a text object's current colour compares in a single check.
private func colorKey(color: NativeTextColor): Int64 {
    (Int64(color.red) << 24) | (Int64(color.green) << 16) | (Int64(color.blue) << 8) | Int64(color.alpha)
}

private class NativeFont {
    let pointSize: Float32
    let sourcePath: String
    // The SDL_ttf TTF_STYLE_* bitmask baked into this handle (0 = regular). Part of the cache key
    // alongside pointSize, so bold and regular text of the same size resolve to distinct handles.
    let styleFlags: Int32
    private let font: CPointer<Unit>
    private var engine = CPointer<Unit>()
    // Already-shaped text objects for this size, reused across frames; a miss is the only path that
    // shapes a string. Bounded and self-freeing: an evicted object's TTF_Text is destroyed.
    private let cache: GenerationCache<ShapedText>
    private let coverage = HashMap<String, Bool>()
    // Shaped-text cache misses (real TTF_CreateText calls) since the last reset. No access modifier
    // so the renderer can total it as a per-frame text-cost probe.
    var shapeCount: UInt64 = 0
    private var closed: Bool = false

    init(font: CPointer<Unit>, pointSize: Float32, styleFlags: Int32, syntheticFlags: Int32, sourcePath: String) {
        this.font = font
        this.pointSize = pointSize
        this.styleFlags = styleFlags
        this.sourcePath = sourcePath
        // Bake the synthesised styles into the handle once. A handle opened from a true-bold
        // companion file arrives with the bold bit already cleared here — the weight is in the
        // outlines — while slants and rules are always synthesised on top.
        if (syntheticFlags != 0) {
            unsafe { TTF_SetFontStyle(font, syntheticFlags) }
        }
        this.cache = GenerationCache<ShapedText>(SHAPED_TEXT_CACHE_CAP) {
            shaped => if (shaped.pointer.isNotNull()) {
                unsafe { TTF_DestroyText(shaped.pointer) }
            }
        }
    }

    /**
     * Binds this font to the shared text engine and fails fast — as the previous eager text object
     * did — if the engine cannot shape for it. Throws `NativeTextException` on failure.
     */
    func attach(engine: CPointer<Unit>): Unit {
        this.engine = engine
        let probe = unsafe { TTF_CreateText(engine, font, CString(CPointer<UInt8>()), UIntNative(0)) }
        if (probe.isNull()) {
            throw NativeTextException("TTF_CreateText failed: ${lastNativeError()}")
        }
        unsafe { TTF_DestroyText(probe) }
    }

    /** True when this face contains every printable rune required by `text`. */
    func supports(text: String): Bool {
        match (coverage.get(text)) {
            case Some(value) => return value
            case None => ()
        }
        var supported = true
        for (r in text.toRuneArray()) {
            let codepoint = UInt32(r)
            if (fontCoverageIgnorable(codepoint)) { continue }
            if (!unsafe { TTF_FontHasGlyph(font, codepoint) }) {
                supported = false
                break
            }
        }
        coverage[text] = supported
        supported
    }

    /**
     * Draws `text` at (x, y) in `color`, reusing a cached shaped-text object so an unchanged string
     * is not re-shaped by SDL_ttf — only a cache miss shapes. Throws `NativeTextException` on failure.
     */
    func drawText(text: String, x: Float32, y: Float32, color: NativeTextColor): Unit {
        let shaped = obtainShaped(text)
        let wanted = colorKey(color)
        // The text object remembers its colour, so only a genuine change touches SDL_ttf again.
        if (shaped.colorKey != wanted) {
            ensureNative(unsafe {
                TTF_SetTextColor(shaped.pointer, color.red, color.green, color.blue, color.alpha)
            }, "TTF_SetTextColor")
            shaped.colorKey = wanted
        }
        ensureNative(unsafe { TTF_DrawRendererText(shaped.pointer, x, y) }, "TTF_DrawRendererText")
    }

    // The shaped text object for `text`, created and cached on first use. Only this miss path calls
    // TTF_CreateText (the shaping cost); repeats hit the cache.
    private func obtainShaped(text: String): ShapedText {
        match (cache.get(text)) {
            case Some(shaped) => return shaped
            case None => ()
        }
        let cText = unsafe { LibC.mallocCString(text) }
        var pointer = CPointer<Unit>()
        try (textResource = cText.asResource()) {
            pointer = unsafe { TTF_CreateText(engine, font, textResource.value, UIntNative(text.size)) }
        }
        if (pointer.isNull()) {
            throw NativeTextException("TTF_CreateText failed: ${lastNativeError()}")
        }
        shapeCount += 1
        let shaped = ShapedText(pointer)
        cache.put(text, shaped)
        shaped
    }

    func pointer(): CPointer<Unit> {
        font
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        cache.clear()
        coverage.clear()
        unsafe { TTF_CloseFont(font) }
    }
}

private func fontCoverageIgnorable(codepoint: UInt32): Bool {
    codepoint == 0 || codepoint == 9 || codepoint == 10 || codepoint == 13 ||
        codepoint == 0x200D || codepoint == 0xFE0E || codepoint == 0xFE0F
}

// The first system-font candidate that SDL_ttf can open, probed by opening then immediately closing
// it. The default face reopens it lazily per size; this only settles which path to use.
private func findSystemFontPath(): ?String {
    for (path in systemFontCandidates()) {
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            let pointer = unsafe { TTF_OpenFont(pathResource.value, DEFAULT_POINT_SIZE) }
            if (pointer.isNotNull()) {
                unsafe { TTF_CloseFont(pointer) }
                return path
            }
        }
    }
    None
}

/**
 * Throws `NativeTextException` when SDL_ttf cannot open the selected system font.
 */
private func openFont(
    path: String,
    pointSize: Float32,
    styleFlags: Int32,
    syntheticFlags: Int32,
    sourcePath: String
): NativeFont {
    let cPath = unsafe { LibC.mallocCString(path) }
    var font = CPointer<Unit>()
    try (pathResource = cPath.asResource()) {
        font = unsafe { TTF_OpenFont(pathResource.value, pointSize) }
        if (font.isNull()) {
            throw NativeTextException("TTF_OpenFont failed: ${lastNativeError()}")
        }
    }
    NativeFont(font, pointSize, styleFlags, syntheticFlags, sourcePath)
}

private func openFontAtFace(
    path: String,
    pointSize: Float32,
    faceIndex: Int64,
    styleFlags: Int32,
    syntheticFlags: Int32,
    sourcePath: String
): NativeFont {
    let font = tryOpenFontAtFace(path, pointSize, faceIndex)
    if (font.isNull()) {
        throw NativeTextException("TTF_OpenFontWithProperties failed: ${lastNativeError()}")
    }
    NativeFont(font, pointSize, styleFlags, syntheticFlags, sourcePath)
}

// SDL_ttf exposes FreeType's encoded named-instance index through its face-number property. The
// upper 16 bits select a variable-font named instance while face 0 remains the default Regular.
private func tryOpenFontAtFace(path: String, pointSize: Float32, faceIndex: Int64): CPointer<Unit> {
    let properties = unsafe { SDL_CreateProperties() }
    if (properties == 0) { return CPointer<Unit>() }
    let cPath = unsafe { LibC.mallocCString(path) }
    let cFilenameProperty = unsafe { LibC.mallocCString(FONT_CREATE_FILENAME_PROPERTY) }
    let cSizeProperty = unsafe { LibC.mallocCString(FONT_CREATE_SIZE_PROPERTY) }
    let cFaceProperty = unsafe { LibC.mallocCString(FONT_CREATE_FACE_PROPERTY) }
    var font = CPointer<Unit>()
    try {
        let hasPath = unsafe { SDL_SetStringProperty(properties, cFilenameProperty, cPath) }
        let hasSize = unsafe { SDL_SetFloatProperty(properties, cSizeProperty, pointSize) }
        let hasFace = unsafe { SDL_SetNumberProperty(properties, cFaceProperty, faceIndex) }
        if (hasPath && hasSize && hasFace) {
            font = unsafe { TTF_OpenFontWithProperties(properties) }
        }
    } finally {
        unsafe {
            SDL_DestroyProperties(properties)
            LibC.free(cPath)
            LibC.free(cFilenameProperty)
            LibC.free(cSizeProperty)
            LibC.free(cFaceProperty)
        }
    }
    font
}

private func namedInstanceFaceIndex(instance: Int64): Int64 {
    instance << FONT_INSTANCE_SHIFT
}

/*
 * Returns a true Bold named instance carried inside `path`, preferring the exact style name and
 * retaining a family-specific Bold spelling as fallback. Invalid successive indices fail open, so
 * the bounded probe stops without requiring FreeType internals or a dependency change.
 */
protected func probeBoldNamedInstance(path: String): ?Int64 {
    var fallback: ?Int64 = None
    var instance: Int64 = 1
    while (instance <= MAX_NAMED_FONT_INSTANCES) {
        let faceIndex = namedInstanceFaceIndex(instance)
        let font = tryOpenFontAtFace(path, DEFAULT_POINT_SIZE, faceIndex)
        if (font.isNull()) { break }
        let styleName = unsafe { TTF_GetFontStyleName(font) }
        let style = if (styleName.isNull()) { "" } else { styleName.toString() }
        unsafe { TTF_CloseFont(font) }
        if (style == "Bold") { return Some(faceIndex) }
        if (fallback.isNone() && style.contains("Bold")) { fallback = Some(faceIndex) }
        instance += 1
    }
    fallback
}

// Splits a font path into stem and extension, recognising only real font-file extensions so a
// dotted directory name is never mistaken for one.
private func splitFontExt(path: String): (String, String) {
    for (ext in [".ttf", ".ttc", ".otf", ".TTF", ".TTC", ".OTF"]) {
        if (path.endsWith(ext)) {
            return (path[0..path.size - ext.size], ext)
        }
    }
    (path, "")
}

/*
 * Filename spellings under which a face's true-bold companion ships, tried in order: the
 * "-Regular" -> "-Bold" convention of most downloadable families (Noto, LXGW WenKai), then the
 * Windows stem suffixes ("bd" for msyh -> msyhbd and arial -> arialbd, "b" for segoeui ->
 * segoeuib), then a plain "-Bold" suffix. Pure string work so tests can pin the shapes; whether a
 * candidate exists is settled by probeBoldCompanion.
 */
protected func boldCompanionCandidates(path: String): Array<String> {
    let (stem, ext) = splitFontExt(path)
    let out = ArrayList<String>()
    if (!ext.isEmpty()) {
        if (stem.endsWith("-Regular")) {
            out.add(stem[0..stem.size - 8] + "-Bold" + ext)
        } else if (stem.endsWith("Regular")) {
            out.add(stem[0..stem.size - 7] + "Bold" + ext)
        }
        out.add(stem + "bd" + ext)
        out.add(stem + "b" + ext)
        out.add(stem + "-Bold" + ext)
    }
    out.toArray()
}

// The first bold-companion candidate SDL_ttf can actually open, probed open-then-close exactly like
// findSystemFontPath; None when no candidate exists. Runs once per face and is remembered.
private func probeBoldCompanion(path: String): ?String {
    for (candidate in boldCompanionCandidates(path)) {
        let cPath = unsafe { LibC.mallocCString(candidate) }
        try (pathResource = cPath.asResource()) {
            let pointer = unsafe { TTF_OpenFont(pathResource.value, DEFAULT_POINT_SIZE) }
            if (pointer.isNotNull()) {
                unsafe { TTF_CloseFont(pointer) }
                return candidate
            }
        }
    }
    None
}

private func systemFontCandidates(): Array<String> {
    let home = match (getVariable("HOME")) {
        case Some(value) => value.trimAscii()
        case None => ""
    }
    systemFontCandidatesFor(home)
}

// Keep CJK-capable faces ahead of Latin-only platform UI fonts. Recent macOS releases no longer
// expose PingFang at the historical path, so falling straight through to SFNS loses Chinese glyphs.
protected func systemFontCandidatesFor(home: String): Array<String> {
    let candidates = ArrayList<String>()
    if (!home.isEmpty()) {
        candidates.add("${home}/Library/Fonts/HarmonyOS_Sans_SC.ttf")
        candidates.add("${home}/Library/Fonts/HarmonyOS Sans SC.ttf")
    }
    candidates.add("/Library/Fonts/HarmonyOS_Sans_SC.ttf")
    candidates.add("/Library/Fonts/HarmonyOS Sans SC.ttf")
    for (path in [
        "C:\\Windows\\Fonts\\msyh.ttc",
        "C:\\Windows\\Fonts\\segoeui.ttf",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    ]) {
        candidates.add(path)
    }
    candidates.toArray()
}

private func normalizePointSize(pointSize: Float32): Float32 {
    if (pointSize <= 0.0) {
        DEFAULT_POINT_SIZE
    } else {
        pointSize
    }
}

/**
 * Throws `NativeTextException` when an SDL_ttf operation reports failure.
 */
private func ensureNative(ok: Bool, api: String): Unit {
    if (!ok) {
        throw NativeTextException("${api} failed: ${lastNativeError()}")
    }
}

private func lastNativeError(): String {
    let error = unsafe { SDL_GetError() }
    if (error.isNull()) {
        "unknown SDL_ttf error"
    } else {
        error.toString()
    }
}
