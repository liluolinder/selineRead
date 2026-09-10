package chui.controls

import std.collection.ArrayList
import sdl.{Color, FontStyle, IconName}
import chui.core.{maxRunesFitting, runeSlice}

// A span fragment placed at a position during layout: a text slice or an icon at (x, y) in content space.
enum PlacedKind {
    | PlacedText(String)
    | PlacedIcon(IconName)
}

struct PlacedItem {
    let x: Float32
    let y: Float32
    let line: Int64
    let kind: PlacedKind
    let color: ?Color
    let muted: Bool
    let style: FontStyle
    let font: ?String
    // The resolved point size this text fragment draws at (ignored for icons, which use the icon box).
    let size: Float32
    // The fragment's advance width and box height (the icon box for icons; the run's line height at
    // its own size/style/font for text). Together with (x, y) they are the fragment's box — the
    // highlight, the focus ring, and the link hit rect all use it. `spanIndex` is the source span,
    // `onTap` its link action (None for an ordinary fragment).
    let width: Float32
    let height: Float32
    let spanIndex: Int64
    let onTap: ?() -> Unit
    // Some paints a rounded highlight box behind this fragment (carried from the source span).
    let highlight: ?Color

    // All-named construction: several fields share a type (three Float32 metrics, two ?Color), so
    // positional building would let a silent transposition compile — named arguments make it a
    // compile error instead.
    init(
        x!: Float32,
        y!: Float32,
        line!: Int64,
        kind!: PlacedKind,
        color!: ?Color,
        muted!: Bool,
        style!: FontStyle,
        font!: ?String,
        size!: Float32,
        width!: Float32,
        height!: Float32,
        spanIndex!: Int64,
        onTap!: ?() -> Unit,
        highlight!: ?Color
    ) {
        this.x = x
        this.y = y
        this.line = line
        this.kind = kind
        this.color = color
        this.muted = muted
        this.style = style
        this.font = font
        this.size = size
        this.width = width
        this.height = height
        this.spanIndex = spanIndex
        this.onTap = onTap
        this.highlight = highlight
    }
}

// An in-progress fragment during the first layout pass: its x and line index are known, but its final
// y waits until the line's height (the tallest fragment on it) is settled in the second pass.
struct LaidFrag {
    let x: Float32
    let line: Int64
    let height: Float32
    let kind: PlacedKind
    let color: ?Color
    let muted: Bool
    let style: FontStyle
    let font: ?String
    let size: Float32
    let width: Float32
    let spanIndex: Int64
    let onTap: ?() -> Unit
    let highlight: ?Color

    // All-named for the same reason as PlacedItem: same-typed neighbours must not be transposable.
    init(
        x!: Float32,
        line!: Int64,
        height!: Float32,
        kind!: PlacedKind,
        color!: ?Color,
        muted!: Bool,
        style!: FontStyle,
        font!: ?String,
        size!: Float32,
        width!: Float32,
        spanIndex!: Int64,
        onTap!: ?() -> Unit,
        highlight!: ?Color
    ) {
        this.x = x
        this.line = line
        this.height = height
        this.kind = kind
        this.color = color
        this.muted = muted
        this.style = style
        this.font = font
        this.size = size
        this.width = width
        this.spanIndex = spanIndex
        this.onTap = onTap
        this.highlight = highlight
    }
}

extend LaidFrag {
    // Settles this fragment at its final vertical position — the ONE place a LaidFrag becomes a
    // PlacedItem, so the two field lists are never copied across anywhere else.
    func placed(y: Float32): PlacedItem {
        PlacedItem(x: x, y: y, line: line, kind: kind, color: color, muted: muted, style: style, font: font,
            size: size, width: width, height: height, spanIndex: spanIndex, onTap: onTap, highlight: highlight)
    }
}

// The result of laying spans out: the placed fragments, the total content height, the widest line,
// the line count (what "single line" means for hugging — a line's height varies with its runs, so
// comparing heights cannot answer it), and one measured width per line so block alignment can be
// computed per line from that line's own metrics rather than a uniform advance.
struct RichLayout {
    let items: Array<PlacedItem>
    let height: Float32
    let width: Float32
    let lines: Int64
    let lineWidths: Array<Float32>

    init(items: Array<PlacedItem>, height: Float32, width: Float32, lines: Int64,
        lineWidths: Array<Float32>) {
        this.items = items
        this.height = height
        this.width = width
        this.lines = lines
        this.lineWidths = lineWidths
    }
}

/** Inline icon side length for a given line height — a touch smaller so it sits within the line. */
func richIconSize(lineHeight: Float32): Float32 {
    max(8.0, lineHeight * 0.82)
}

// A rune that belongs to an ASCII word (identifier, number, issue tag): any visible ASCII character.
// CJK and other non-ASCII scripts are excluded on purpose — they break per rune, as convention wants.
internal func isAsciiWordRune(r: Rune): Bool {
    r > r' ' && r <= r'~'
}

// The end (exclusive) of the ASCII word starting at `start`.
internal func asciiWordEnd(runes: Array<Rune>, start: Int64): Int64 {
    var end = start
    while (end < runes.size && isAsciiWordRune(runes[end])) {
        end += 1
    }
    end
}

/*
 * Lays a span list into placed fragments, wrapping to `maxWidth`. Text runs are broken at rune
 * boundaries (so CJK wraps cleanly), with two word-level refinements for scripts that use spaces:
 * a forced break inside a run backs up to fall after the run's last space, and an ASCII word that
 * starts mid-line and would otherwise split moves to the next line whole when it fits one (an
 * identifier or issue tag is never cut in half; a word wider than a full line still rune-splits so
 * nothing overflows). CJK text has no spaces and non-ASCII runes, so both refinements leave it
 * exactly as before — filling every line and breaking anywhere. Icons flow
 * inline as square boxes of `iconSize`. Each span's resolved point size comes from `spanSizes` (parallel
 * to `spans`); `widthOf` returns a run's width and `heightOf` a run's line height, both at the run's
 * size, style, and font (a face carries its own vertical metrics, so heights must come from the same
 * font the run draws with) — so the engine is pure and testable independent of the font backend.
 *
 * Two passes: the first places fragments left-to-right with wrapping, recording each line's height as
 * the tallest fragment on it; the second stacks the lines and centres every fragment within its line,
 * so runs of different sizes align on a common centre and the line grows to the largest. For a uniform
 * size this is identical to top-of-line placement. `lineGap` is inserted only between consecutive
 * lines. Returns the placed items, total content height, widest line, and each line's measured width.
 */
internal func layoutResolvedRichSpans(
    spans: Array<RichSpan>,
    spanSizes: Array<Float32>,
    spanStyles: Array<FontStyle>,
    spanFonts: Array<?String>,
    maxWidth: Float32,
    iconSize: Float32,
    spanGap: Float32,
    widthOf: (String, Float32, FontStyle, ?String) -> Float32,
    heightOf: (Float32, FontStyle, ?String) -> Float32,
    lineGap!: Float32 = 0.0
): RichLayout {
    let frags = ArrayList<LaidFrag>()
    let lineHeights = ArrayList<Float32>()
    lineHeights.add(0.0)
    let lineWidths = ArrayList<Float32>()
    lineWidths.add(0.0)
    var x: Float32 = 0.0
    var line: Int64 = 0
    var widest: Float32 = 0.0
    for (si in 0..spans.size) {
        let span = spans[si]
        let size = spanSizes[si]
        let style = spanStyles[si]
        let font = spanFonts[si]
        match (span.kind) {
            case RichSpanKind.SpanText(text) =>
                let fragHeight = heightOf(size, style, font)
                // Bind this run's size, style, and font so widths reflect the actual metrics (a bigger
                // or bolder run is wider) and wrapping breaks where the run really overflows.
                let spanMeasure = {s: String => widthOf(s, size, style, font)}
                let runes = text.toRuneArray()
                var i = 0
                while (i < runes.size) {
                    // A wrapped continuation never starts with the space the line broke on (the
                    // i > 0 guard keeps a span's own leading space, e.g. a separator span).
                    if (x == 0.0 && i > 0 && runes[i] == r' ') {
                        i += 1
                        continue
                    }
                    var fit = maxRunesFitting(runes, i, maxWidth - x, spanMeasure)
                    if (fit == 0) {
                        if (x > 0.0) {
                            // Nothing more fits on this line; wrap and retry the same rune.
                            x = 0.0
                            line += 1
                            lineHeights.add(0.0)
                            lineWidths.add(0.0)
                            continue
                        }
                        // A single rune overflows even a full line; place it anyway to make progress.
                        fit = 1
                    }
                    if (i + fit < runes.size && runes[i + fit] != r' ') {
                        // Breaking mid-run: prefer to land just after the run's last space.
                        var back = fit - 1
                        var atSpace = false
                        while (back > 0) {
                            if (runes[i + back] == r' ') {
                                fit = back + 1
                                atSpace = true
                                break
                            }
                            back -= 1
                        }
                        // No space to back to and the break falls inside an ASCII word: move the
                        // whole word to the next line when it fits one, instead of cutting it.
                        if (!atSpace && x > 0.0 && isAsciiWordRune(runes[i])) {
                            let wordEnd = asciiWordEnd(runes, i)
                            if (i + fit < wordEnd && spanMeasure(runeSlice(runes, i, wordEnd)) <= maxWidth) {
                                x = 0.0
                                line += 1
                                lineHeights.add(0.0)
                                lineWidths.add(0.0)
                                continue
                            }
                        }
                    }
                    let segment = runeSlice(runes, i, i + fit)
                    let segWidth = spanMeasure(segment)
                    frags.add(
                        LaidFrag(x: x, line: line, height: fragHeight, kind: PlacedKind.PlacedText(segment),
                            color: span.color, muted: span.isMuted, style: style, font: font,
                            size: size, width: segWidth, spanIndex: si, onTap: span.tapAction,
                            highlight: span.highlightColor))
                    if (fragHeight > lineHeights[line]) {
                        lineHeights[line] = fragHeight
                    }
                    x += segWidth
                    lineWidths[line] = x
                    widest = max(widest, x)
                    i += fit
                }
            case RichSpanKind.SpanIcon(icon) =>
                if (x + iconSize > maxWidth && x > 0.0) {
                    x = 0.0
                    line += 1
                    lineHeights.add(0.0)
                    lineWidths.add(0.0)
                }
                frags.add(
                    LaidFrag(x: x, line: line, height: iconSize, kind: PlacedKind.PlacedIcon(icon),
                        color: span.color, muted: false, style: style, font: font, size: size,
                        width: iconSize, spanIndex: si, onTap: span.tapAction, highlight: span.highlightColor))
                if (iconSize > lineHeights[line]) {
                    lineHeights[line] = iconSize
                }
                x += iconSize
                lineWidths[line] = x
                widest = max(widest, x)
                x += spanGap
        }
    }
    if (frags.isEmpty()) {
        return RichLayout(Array<PlacedItem>(), 0.0, 0.0, 0, [])
    }
    // Second pass: stack lines, adding the configured gap after every line except the final one.
    let lineTops = ArrayList<Float32>()
    var acc: Float32 = 0.0
    var stacked: Int64 = 0
    for (h in lineHeights) {
        lineTops.add(acc)
        acc += h
        stacked += 1
        if (stacked < lineHeights.size) {
            acc += lineGap
        }
    }
    let placed = ArrayList<PlacedItem>()
    for (frag in frags) {
        placed.add(frag.placed(lineTops[frag.line] + (lineHeights[frag.line] - frag.height) / 2.0))
    }
    RichLayout(placed.toArray(), acc, widest, lineHeights.size, lineWidths.toArray())
}
