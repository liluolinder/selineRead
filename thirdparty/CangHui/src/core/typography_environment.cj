package chui.core

import sdl.FontStyle

/**
 * Independently optional typography values inherited by semantic text leaves.
 * A nested environment replaces only the fields it supplies; omitted fields
 * continue to inherit from the nearest outer scope.
 */
public struct TypographyEnvironment {
    public let fontFamily: ?String
    public let fontSize: ?Length
    public let bold: ?Bool
    public let italic: ?Bool
    public let underline: ?Bool
    public let strikethrough: ?Bool

    public init(
        fontFamily!: ?String = None<String>,
        fontSize!: ?Length = None<Length>,
        bold!: ?Bool = None<Bool>,
        italic!: ?Bool = None<Bool>,
        underline!: ?Bool = None<Bool>,
        strikethrough!: ?Bool = None<Bool>
    ) {
        this.fontFamily = fontFamily
        this.fontSize = fontSize
        this.bold = bold
        this.italic = italic
        this.underline = underline
        this.strikethrough = strikethrough
    }

    /** Returns this environment with the supplied, deeper values overlaid field by field. */
    public func merging(overrides: TypographyEnvironment): TypographyEnvironment {
        TypographyEnvironment(
            fontFamily: match (overrides.fontFamily) {
                case Some(value) => Some(value)
                case None => fontFamily
            },
            fontSize: match (overrides.fontSize) {
                case Some(value) => Some(value)
                case None => fontSize
            },
            bold: match (overrides.bold) {
                case Some(value) => Some(value)
                case None => bold
            },
            italic: match (overrides.italic) {
                case Some(value) => Some(value)
                case None => italic
            },
            underline: match (overrides.underline) {
                case Some(value) => Some(value)
                case None => underline
            },
            strikethrough: match (overrides.strikethrough) {
                case Some(value) => Some(value)
                case None => strikethrough
            }
        )
    }

    /** Resolves omitted style fields to Regular. */
    public func resolvedFontStyle(): FontStyle {
        FontStyle(
            bold: match (bold) { case Some(value) => value case None => false },
            italic: match (italic) { case Some(value) => value case None => false },
            underline: match (underline) { case Some(value) => value case None => false },
            strikethrough: match (strikethrough) { case Some(value) => value case None => false }
        )
    }

    public func withFontFamily(value: String): TypographyEnvironment {
        merging(TypographyEnvironment(fontFamily: value))
    }

    public func withFontSize(value: Length): TypographyEnvironment {
        merging(TypographyEnvironment(fontSize: value))
    }

    /** Replaces every style field, so Regular explicitly clears inherited styling. */
    public func withFontStyle(value: FontStyle): TypographyEnvironment {
        merging(TypographyEnvironment(
            bold: value.bold,
            italic: value.italic,
            underline: value.underline,
            strikethrough: value.strikethrough
        ))
    }

    public func withBold(value!: Bool = true): TypographyEnvironment {
        merging(TypographyEnvironment(bold: value))
    }

    public func withItalic(value!: Bool = true): TypographyEnvironment {
        merging(TypographyEnvironment(italic: value))
    }

    public func withUnderline(value!: Bool = true): TypographyEnvironment {
        merging(TypographyEnvironment(underline: value))
    }

    public func withStrikethrough(value!: Bool = true): TypographyEnvironment {
        merging(TypographyEnvironment(strikethrough: value))
    }
}

/** Applies only the explicitly marked fields from `local` over an inherited style. */
internal func resolveLocalFontStyle(inherited: FontStyle, local: FontStyle, mask: Int32): FontStyle {
    FontStyle(
        bold: if ((mask & 0x01) != 0) { local.bold } else { inherited.bold },
        italic: if ((mask & 0x02) != 0) { local.italic } else { inherited.italic },
        underline: if ((mask & 0x04) != 0) { local.underline } else { inherited.underline },
        strikethrough: if ((mask & 0x08) != 0) { local.strikethrough } else { inherited.strikethrough }
    )
}

internal func typographyFontKey(value: ?String): String {
    match (value) {
        case Some(font) => "1:${font}"
        case None => "0:"
    }
}
