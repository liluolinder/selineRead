package chui.controls

import sdl.{Color, FontStyle, IconName}
import chui.core.{Length, LengthUnit}

private func resolveSpanFontStyle(inherited: FontStyle, local: FontStyle, mask: Int32): FontStyle {
    FontStyle(
        bold: if ((mask & 0x01) != 0) { local.bold } else { inherited.bold },
        italic: if ((mask & 0x02) != 0) { local.italic } else { inherited.italic },
        underline: if ((mask & 0x04) != 0) { local.underline } else { inherited.underline },
        strikethrough: if ((mask & 0x08) != 0) { local.strikethrough } else { inherited.strikethrough }
    )
}

// What a span carries: a run of text, or an inline icon.
enum RichSpanKind {
    | SpanText(String)
    | SpanIcon(IconName)
}

/**
 * One styled run in a `RichText`: a run of text or an inline icon, each optionally coloured. Build them
 * with the factories — `RichSpan.text` (default or explicit colour), `RichSpan.muted` (secondary text
 * colour) and `RichSpan.icon` — then chain the style builders (`bold`, `italic`, `underline`,
 * `strikethrough`, `fontStyle`, `fontFamily`, `fontSize`, `highlight`) to vary weight, slant, decoration,
 * typeface, size, and background per run. A run with no `fontSize` inherits the `RichText`'s base size;
 * runs of differing sizes on one line are centred against each other and the line grows to the tallest.
 * `highlight(background)` paints a `<mark>`-style box behind a run (e.g. to mark search matches).
 */
public struct RichSpan {
    let kind: RichSpanKind
    let color: ?Color
    let isMuted: Bool
    let style: FontStyle
    // One bit per explicitly supplied FontStyle field; omitted fields inherit from RichText/container.
    let styleMask: Int32
    let fontFace: ?String
    // None inherits the RichText's base point size; Some overrides just this run.
    let size: ?Length
    // Some makes this run a clickable link: clicking any of its fragments runs the action, and the
    // pointer shows the interactive cursor over it. None is an ordinary, inert run.
    let tapAction: ?() -> Unit
    // Some paints a rounded highlight box behind this run (a `<mark>`-style background), drawn under the
    // text or icon; None leaves the run on the plain background. Named to avoid clashing with `highlight`.
    let highlightColor: ?Color

    private init(
        kind: RichSpanKind,
        color: ?Color,
        isMuted: Bool,
        style: FontStyle,
        styleMask: Int32,
        fontFace: ?String,
        size: ?Length,
        tapAction: ?() -> Unit,
        highlightColor: ?Color
    ) {
        this.kind = kind
        this.color = color
        this.isMuted = isMuted
        this.style = style
        this.styleMask = styleMask
        this.fontFace = fontFace
        this.size = size
        this.tapAction = tapAction
        this.highlightColor = highlightColor
    }

    /** A run of text in the default text colour, or an explicit `color`. */
    public static func text(text: String, color!: ?Color = None): RichSpan {
        RichSpan(RichSpanKind.SpanText(text), color, false, FontStyle.regular, 0, None, None, None, None)
    }

    /** A run of text in the theme's secondary (muted) text colour. */
    public static func muted(text: String): RichSpan {
        RichSpan(RichSpanKind.SpanText(text), None, true, FontStyle.regular, 0, None, None, None, None)
    }

    /** An inline icon, sized to the line and optionally coloured. */
    public static func icon(icon: IconName, color!: ?Color = None): RichSpan {
        RichSpan(RichSpanKind.SpanIcon(icon), color, false, FontStyle.regular, 0, None, None, None, None)
    }

    /** This span drawn bold (or with bold set to `value`). */
    public func bold(value!: Bool = true): RichSpan {
        RichSpan(kind, color, isMuted, style.withBold(value: value), styleMask | 0x01, fontFace, size, tapAction,
            highlightColor)
    }

    /** This span drawn italic (or with italic set to `value`). */
    public func italic(value!: Bool = true): RichSpan {
        RichSpan(kind, color, isMuted, style.withItalic(value: value), styleMask | 0x02, fontFace, size, tapAction,
            highlightColor)
    }

    /** This span underlined (or with the underline set to `value`). */
    public func underline(value!: Bool = true): RichSpan {
        RichSpan(kind, color, isMuted, style.withUnderline(value: value), styleMask | 0x04, fontFace, size, tapAction,
            highlightColor)
    }

    /** This span struck through (or with the strikethrough set to `value`). */
    public func strikethrough(value!: Bool = true): RichSpan {
        RichSpan(kind, color, isMuted, style.withStrikethrough(value: value), styleMask | 0x08, fontFace, size,
            tapAction, highlightColor)
    }

    /** This span with its whole text style replaced. */
    public func fontStyle(value: FontStyle): RichSpan {
        RichSpan(kind, color, isMuted, value, 0x0f, fontFace, size, tapAction, highlightColor)
    }

    /** This span drawn in a registered application font (see `Fonts.register`). */
    public func fontFamily(name: String): RichSpan {
        RichSpan(kind, color, isMuted, style, styleMask, Some(name), size, tapAction, highlightColor)
    }

    /** This span drawn at its own point size, overriding the `RichText`'s base size. */
    public func fontSize(value: Length): RichSpan {
        RichSpan(kind, color, isMuted, style, styleMask, fontFace, Some(value), tapAction, highlightColor)
    }

    /** This span drawn at its own point size in font pixels. */
    public func fontSize(value: Float32): RichSpan {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Makes this span a clickable link: clicking it runs `action`, and the pointer turns interactive. */
    public func onTap(action: () -> Unit): RichSpan {
        RichSpan(kind, color, isMuted, style, styleMask, fontFace, size, action, highlightColor)
    }

    /**
     * Paints a rounded `background` highlight box behind this span (a `<mark>`-style background), drawn
     * under the text or icon. The run's text colour is unchanged; pair with an explicit `text(color:)`
     * for readable contrast. The box covers exactly the span's fragments with rounded corners, so two
     * separately highlighted neighbouring spans each round their own ends at the seam — text that
     * should read as one continuous mark belongs in a single span.
     */
    public func highlight(background: Color): RichSpan {
        RichSpan(kind, color, isMuted, style, styleMask, fontFace, size, tapAction, Some(background))
    }

    internal func resolvedStyle(inherited: FontStyle): FontStyle {
        resolveSpanFontStyle(inherited, style, styleMask)
    }

    internal func resolvedFontFamily(inherited: ?String): ?String {
        match (fontFace) {
            case Some(value) => Some(value)
            case None => inherited
        }
    }
}
