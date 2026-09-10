package chui.core

import std.collection.ArrayList
import sdl.FontStyle

private let TEXT_ELLIPSIS = "…"

// The gallop bracket start (covers most lines at UI widths in one probe) and the remainder length
// up to which a single whole-run probe is still the cheapest opening move.
private let WRAP_GALLOP_SEED: Int64 = 32
private let WRAP_GALLOP_THRESHOLD: Int64 = 512

/*
 * Text fitting shared by single-line ellipsis and multi-line wrapping. Prefix widths are
 * found with binary search over the rune array, so the cost per line is O(log n) renderer
 * measurements instead of one per character.
 */

/** Returns `text` unchanged when it fits, otherwise the widest `prefix + …` that fits. */
protected func ellipsize(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    style!: FontStyle = FontStyle.regular,
    font!: ?String = None
): String {
    if (ctx.renderer.textWidth(text, pointSize: ps, style: style, font: font) <= maxWidth) {
        return text
    }
    if (ctx.renderer.textWidth(TEXT_ELLIPSIS, pointSize: ps, style: style, font: font) > maxWidth) {
        return ""
    }
    let runes = text.toRuneArray()
    var low: Int64 = 0
    var high = runes.size - 1
    while (low < high) {
        let mid = (low + high + 1) / 2
        let candidate = runeSlice(runes, 0, mid) + TEXT_ELLIPSIS
        if (ctx.renderer.textWidth(candidate, pointSize: ps, style: style, font: font) <= maxWidth) {
            low = mid
        } else {
            high = mid - 1
        }
    }
    runeSlice(runes, 0, low) + TEXT_ELLIPSIS
}

/**
 * Breaks `text` into at most `maxLines` display lines that fit `maxWidth`, preferring
 * space boundaries and falling back to per-rune breaks (which suits CJK text). The last
 * line is ellipsized when text remains.
 */
protected func wrapText(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    maxLines: Int64,
    style!: FontStyle = FontStyle.regular,
    font!: ?String = None
): Array<String> {
    let runes = text.toRuneArray()
    let lines = ArrayList<String>()
    var start: Int64 = 0
    while (start < runes.size && lines.size < maxLines) {
        if (lines.size == maxLines - 1) {
            lines.add(ellipsize(ctx, runeSlice(runes, start, runes.size), maxWidth, ps, style: style, font: font))
            return lines.toArray()
        }
        var take = maxFittingRunes(ctx, runes, start, maxWidth, ps, style: style, font: font)
        // Prefer breaking after the last space inside the fitted range.
        if (start + take < runes.size && runes[start + take] != r' ') {
            var back = take - 1
            while (back > 0) {
                if (runes[start + back] == r' ') {
                    take = back + 1
                    break
                }
                back -= 1
            }
        }
        var lineEnd = start + take
        while (lineEnd > start && runes[lineEnd - 1] == r' ') {
            lineEnd -= 1
        }
        lines.add(runeSlice(runes, start, lineEnd))
        start += take
        // Consume the space the break landed on so lines never start blank.
        while (start < runes.size && runes[start] == r' ') {
            start += 1
        }
    }
    if (lines.isEmpty()) {
        lines.add("")
    }
    lines.toArray()
}

/** The largest rune count from `start` whose text fits `maxWidth`; at least one. */
private func maxFittingRunes(
    ctx: UiContext,
    runes: Array<Rune>,
    start: Int64,
    maxWidth: Float32,
    ps: Float32,
    style!: FontStyle = FontStyle.regular,
    font!: ?String = None
): Int64 {
    if (start >= runes.size) {
        return 0
    }
    // One shared fit engine module-wide; Label's contract floors at one rune so wrapping always makes
    // progress even when not a single rune fits the width.
    max(1,
        maxRunesFitting(runes, start, maxWidth,
            {s => ctx.renderer.textWidth(s, pointSize: ps, style: style, font: font)}))
}

/*
 * The largest rune count k in [1, remaining] with measure(runes[start..start+k]) <= maxW; 0 if even
 * one rune does not fit (or there is no width / no runes left). The one binary-search fit engine for
 * every text-wrapping path in the module (Label above, RichText's layout engine), so a boundary or
 * measure-caching fix lands everywhere at once.
 */
protected func maxRunesFitting(runes: Array<Rune>, start: Int64, maxW: Float32, measure: (String) -> Float32): Int64 {
    let n = runes.size - start
    if (n <= 0 || maxW <= 0.0) {
        return 0
    }
    // Short remainders keep the single whole-run probe: one measurement settles the common case
    // (a label that simply fits). Long remainders must not — probing the full text again on every
    // line is what made wrapping a 20000-rune document quadratic in string builds — so they gallop
    // for a bracket first, keeping every measured prefix within a few line-lengths.
    if (n <= WRAP_GALLOP_THRESHOLD) {
        if (measure(runeSlice(runes, start, start + n)) <= maxW) {
            return n
        }
        return largestFitting(runes, start, 0, n - 1, measure, maxW)
    }
    var fits = 0
    var probe = WRAP_GALLOP_SEED
    while (probe < n) {
        if (measure(runeSlice(runes, start, start + probe)) <= maxW) {
            fits = probe
            probe *= 4
        } else {
            return largestFitting(runes, start, fits, probe - 1, measure, maxW)
        }
    }
    if (measure(runeSlice(runes, start, start + n)) <= maxW) {
        return n
    }
    largestFitting(runes, start, fits, n - 1, measure, maxW)
}

// Binary search for the largest fitting count inside (knownFit, hi]; `knownFit` already fits (or
// is 0). Same monotone predicate as before, so the result is identical to the full-range search.
private func largestFitting(
    runes: Array<Rune>,
    start: Int64,
    knownFit: Int64,
    hi: Int64,
    measure: (String) -> Float32,
    maxW: Float32
): Int64 {
    var lo = knownFit + 1
    var high = hi
    var answer = knownFit
    while (lo <= high) {
        let mid = (lo + high) / 2
        if (measure(runeSlice(runes, start, start + mid)) <= maxW) {
            answer = mid
            lo = mid + 1
        } else {
            high = mid - 1
        }
    }
    answer
}

// Module-visible so RichText's layout engine shares this one slice helper instead of keeping a copy.
protected func runeSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var i = start
    while (i < end) {
        builder.append(runes[i])
        i += 1
    }
    builder.toString()
}
