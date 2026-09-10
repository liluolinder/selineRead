package chui.core

import sdl.{Color, Fonts, FontSizes, FontStyle, Rect, Size, UiEvent}

private let LABEL_LINE_GAP: Float32 = 2.0

/*
 * Single- or multi-line text. Defaults to one line with overflow ellipsized; `maxLines(n)` allows
 * wrapping onto up to `n` lines (the last is ellipsized when text remains) and `wrap()` removes the
 * cap. The builders (`bold`, `fontSize`, `fontFamily`, ...) mutate and return `this` for chaining.
 * Width and wrap results are cached and shared between measure and draw for the same width and point
 * size; builders that change measurement inputs (style, face, line limit) drop those caches.
 */
public class Label <: Widget {
    private let text: String
    private var isMuted: Bool
    private var alignment: TextAlign
    private var textColor: ?Color
    private var pointSize: ?Length
    private var textStyle: FontStyle = FontStyle.regular
    private var textStyleMask: Int32 = 0
    private var fontFace: ?String = None
    private var lineLimit: Int64 = 1
    private var lineGap: Float32 = LABEL_LINE_GAP
    private var frame = Rect.zero()
    // Wrapping runs several renderer measurements; measure and draw reuse the result
    // for the same width and point size instead of re-breaking the text each pass.
    private var cachedLines: ?Array<String> = None
    private var cachedLinesWidth: Float32 = -1.0
    private var cachedLinesPointSize: Float32 = -1.0
    private var cachedLinesStyleFlags: Int32 = -1
    private var cachedLinesFontKey: String = ""
    // The widest wrapped line, cached with the lines it derives from so a warm multi-line measure
    // re-measures nothing instead of re-scanning every line each measure pass.
    private var cachedLinesWidest: Float32 = 0.0
    private var cachedTextWidth: Float32 = -1.0
    private var cachedTextWidthPointSize: Float32 = -1.0
    private var cachedTextWidthStyleFlags: Int32 = -1
    private var cachedTextWidthFontKey: String = ""

    public init(
        text: String,
        muted!: Bool = false,
        align!: TextAlign = TextAlign.Leading,
        color!: ?Color = None,
        fontSize!: ?Length = None<Length>
    ) {
        this.text = text
        this.isMuted = muted
        this.alignment = align
        this.textColor = color
        this.pointSize = fontSize
        emit(this)
    }

    /** Uses the theme's secondary text color. */
    public func muted(): Label {
        isMuted = true
        this
    }

    /** Controls whether the theme's secondary text color is used. */
    public func muted(value: Bool): Label {
        isMuted = value
        this
    }

    /** Sets horizontal text alignment inside the assigned frame. */
    public func textAlign(value: TextAlign): Label {
        alignment = value
        this
    }

    /** Overrides the theme-derived text color. */
    public func foregroundColor(value: Color): Label {
        textColor = Some(value)
        this
    }

    /** Sets the font size, e.g. `.fontSize(15.fp)`. */
    public func fontSize(value: Length): Label {
        pointSize = Some(value)
        this
    }

    /** Sets the font size in font pixels. */
    public func fontSize(value: Float32): Label {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Replaces the whole text style (weight, slant, and decorations) at once. */
    public func fontStyle(value: FontStyle): Label {
        textStyle = value
        textStyleMask = 0x0f
        dropMetricsCaches()
        this
    }

    /** Draws the text bold (or sets bold to `value`). */
    public func bold(): Label {
        bold(value: true)
    }

    public func bold(value!: Bool): Label {
        textStyle = textStyle.withBold(value: value)
        textStyleMask |= 0x01
        dropMetricsCaches()
        this
    }

    /** Draws the text italic (or sets italic to `value`). */
    public func italic(): Label {
        italic(value: true)
    }

    public func italic(value!: Bool): Label {
        textStyle = textStyle.withItalic(value: value)
        textStyleMask |= 0x02
        dropMetricsCaches()
        this
    }

    /** Underlines the text (or sets the underline to `value`). */
    public func underline(): Label {
        underline(value: true)
    }

    public func underline(value!: Bool): Label {
        textStyle = textStyle.withUnderline(value: value)
        textStyleMask |= 0x04
        dropMetricsCaches()
        this
    }

    /** Strikes through the text (or sets the strikethrough to `value`). */
    public func strikethrough(): Label {
        strikethrough(value: true)
    }

    public func strikethrough(value!: Bool): Label {
        textStyle = textStyle.withStrikethrough(value: value)
        textStyleMask |= 0x08
        dropMetricsCaches()
        this
    }

    /**
     * Draws the text in a registered application font (see `Fonts.register`). An unknown, unreadable,
     * or glyph-incomplete face falls through Theme/application defaults, bundled HarmonyOS Sans, and
     * finally the platform UI font.
     */
    public func fontFamily(name: String): Label {
        fontFace = Some(name)
        dropMetricsCaches()
        this
    }

    // Style and font are measurement inputs (bold is wider, a face has its own metrics) that the
    // width/wrap caches do not key on, so a builder that changes them must drop what was measured
    // under the old ones — otherwise a widget measured before restyling keeps stale fit decisions.
    private func dropMetricsCaches(): Unit {
        cachedTextWidthPointSize = -1.0
        cachedLines = None
        cachedLinesWidth = -1.0
        cachedLinesPointSize = -1.0
    }

    /**
     * Allows the text to wrap onto up to `value` lines. The final line is ellipsized
     * when text remains. Throws `IllegalArgumentException` when `value` is not positive.
     */
    public func maxLines(value: Int64): Label {
        if (value <= 0) {
            throw IllegalArgumentException("Label maxLines must be greater than zero")
        }
        lineLimit = value
        // The line limit is a wrap input the lines cache does not key on (same rule as the
        // style builders): a stored, re-emitted Label changing its limit must re-wrap.
        dropMetricsCaches()
        this
    }

    /** Lets the text wrap onto as many lines as it needs. */
    public func wrap(): Label {
        lineLimit = Int64.Max
        dropMetricsCaches()
        this
    }

    /** Sets the non-negative finite gap between wrapped lines; single-line labels are unaffected. */
    public func lineSpacing(value: Float32): Label {
        if (value < 0.0 || value - value != 0.0) {
            throw IllegalArgumentException("Label lineSpacing must be a non-negative finite value")
        }
        lineGap = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = resolvedPointSize(ctx)
        let style = resolvedTextStyle(ctx)
        let font = resolvedFontFace(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps, style: style, font: font)
        if (lineLimit == 1) {
            return Size(min(available.w, singleLineWidth(ctx, ps, style, font)), max(CUI_SMALL_H, lineHeight + 6.0))
        }
        let lines = linesFor(ctx, available.w, ps, style, font)
        let count = max(1, lines.size)
        let textBlock = Float32(count) * lineHeight + Float32(count - 1) * lineGap
        // widest was measured when the lines were wrapped and cached; a warm pass reuses it.
        Size(min(available.w, cachedLinesWidest), max(CUI_SMALL_H, textBlock + 6.0))
    }

    /** Complete, length-delimited identity for retained preferred-size reuse. */
    internal func retainedMeasureInputIdentity(ctx: UiContext): String {
        let point = resolvedPointSize(ctx)
        let style = resolvedTextStyle(ctx)
        let font = resolvedFontFace(ctx)
        let fontKey = typographyFontKey(font)
        "Label|" + text.toArray().size.toString() + ":" + text + "|" +
            point.toString() + "|" + style.ttfFlags().toString() + "|" +
            fontKey.toArray().size.toString() + ":" + fontKey + "|" +
            lineLimit.toString() + "|" + lineGap.toString() + "|" +
            Fonts.generation().toString()
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let ps = resolvedPointSize(ctx)
        let style = resolvedTextStyle(ctx)
        let font = resolvedFontFace(ctx)
        let color = drawColor(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps, style: style, font: font)
        if (lineLimit == 1) {
            // Reuse the cached full-text width for the fit test: ellipsize (a binary search) runs
            // only when the text overflows, so a fitting single-line label re-measures nothing.
            let fitted = if (singleLineWidth(ctx, ps, style, font) <= frame.w) {
                text
            } else {
                ellipsize(ctx, text, frame.w, ps, style: style, font: font)
            }
            ctx.renderer.text(
                fitted,
                lineX(ctx, fitted, ps, style, font),
                frame.centerY() - lineHeight / 2.0,
                color,
                pointSize: ps,
                style: style,
                font: font
            )
            return
        }
        let lines = linesFor(ctx, frame.w, ps, style, font)
        let textBlock = Float32(lines.size) * lineHeight + Float32(max(0, lines.size - 1)) * lineGap
        var y = frame.centerY() - textBlock / 2.0
        for (line in lines) {
            ctx.renderer.text(line, lineX(ctx, line, ps, style, font), y, color, pointSize: ps, style: style,
                font: font)
            y += lineHeight + lineGap
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func drawColor(ctx: UiContext): Color {
        match (textColor) {
            case Some(value) => value
            case None =>
                if (isMuted) {
                    ctx.contentSupportingForeground()
                } else {
                    ctx.contentForeground()
                }
        }
    }

    private func resolvedPointSize(ctx: UiContext): Float32 {
        let length = match (pointSize) {
            case Some(value) => value
            case None => match (ctx.typographyEnvironment().fontSize) {
                case Some(value) => value
                case None => Length(FontSizes.BODY, LengthUnit.Fp)
            }
        }
        max(1.0, ctx.resolve(length))
    }

    private func resolvedTextStyle(ctx: UiContext): FontStyle {
        resolveLocalFontStyle(ctx.typographyEnvironment().resolvedFontStyle(), textStyle, textStyleMask)
    }

    private func resolvedFontFace(ctx: UiContext): ?String {
        match (fontFace) {
            case Some(value) => Some(value)
            case None => ctx.typographyEnvironment().fontFamily
        }
    }

    // Exact float comparison is deliberate in both caches: the keys are reused values,
    // not computed approximations, so equality means "same inputs as last time".
    private func singleLineWidth(ctx: UiContext, ps: Float32, style: FontStyle, font: ?String): Float32 {
        let styleFlags = style.ttfFlags()
        let fontKey = typographyFontKey(font)
        if (cachedTextWidthPointSize != ps || cachedTextWidthStyleFlags != styleFlags ||
            cachedTextWidthFontKey != fontKey) {
            cachedTextWidth = ctx.renderer.textWidth(text, pointSize: ps, style: style, font: font)
            cachedTextWidthPointSize = ps
            cachedTextWidthStyleFlags = styleFlags
            cachedTextWidthFontKey = fontKey
        }
        cachedTextWidth
    }

    private func linesFor(ctx: UiContext, width: Float32, ps: Float32, style: FontStyle,
        font: ?String): Array<String> {
        let styleFlags = style.ttfFlags()
        let fontKey = typographyFontKey(font)
        match (cachedLines) {
            case Some(lines) where cachedLinesWidth == width && cachedLinesPointSize == ps &&
                cachedLinesStyleFlags == styleFlags && cachedLinesFontKey == fontKey => lines
            case _ =>
                let lines = wrapText(ctx, text, width, ps, lineLimit, style: style, font: font)
                var widest: Float32 = 0.0
                for (line in lines) {
                    widest = max(widest, ctx.renderer.textWidth(line, pointSize: ps, style: style, font: font))
                }
                cachedLines = Some(lines)
                cachedLinesWidth = width
                cachedLinesPointSize = ps
                cachedLinesStyleFlags = styleFlags
                cachedLinesFontKey = fontKey
                cachedLinesWidest = widest
                lines
        }
    }

    private func lineX(ctx: UiContext, line: String, ps: Float32, style: FontStyle, font: ?String): Float32 {
        // Leading (the default) does not need the line width, so the common case skips the measure.
        match (alignment) {
            case TextAlign.Leading => frame.x
            case TextAlign.Center =>
                let lineW = ctx.renderer.textWidth(line, pointSize: ps, style: style, font: font)
                frame.x + max(0.0, frame.w - lineW) / 2.0
            case TextAlign.Trailing =>
                let lineW = ctx.renderer.textWidth(line, pointSize: ps, style: style, font: font)
                frame.right() - lineW
        }
    }
}
