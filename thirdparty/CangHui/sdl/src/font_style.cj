package sdl

/** Text weight, slant and line decorations used by CangHui text components. */
public struct FontStyle <: Equatable<FontStyle> {
    public let bold: Bool
    public let italic: Bool
    public let underline: Bool
    public let strikethrough: Bool

    public init(
        bold!: Bool = false,
        italic!: Bool = false,
        underline!: Bool = false,
        strikethrough!: Bool = false
    ) {
        this.bold = bold
        this.italic = italic
        this.underline = underline
        this.strikethrough = strikethrough
    }

    public static let regular = FontStyle()

    public prop isRegular: Bool {
        get() { !bold && !italic && !underline && !strikethrough }
    }

    public func withBold(value!: Bool = true): FontStyle {
        FontStyle(bold: value, italic: italic, underline: underline, strikethrough: strikethrough)
    }

    public func withItalic(value!: Bool = true): FontStyle {
        FontStyle(bold: bold, italic: value, underline: underline, strikethrough: strikethrough)
    }

    public func withUnderline(value!: Bool = true): FontStyle {
        FontStyle(bold: bold, italic: italic, underline: value, strikethrough: strikethrough)
    }

    public func withStrikethrough(value!: Bool = true): FontStyle {
        FontStyle(bold: bold, italic: italic, underline: underline, strikethrough: value)
    }

    public func ttfFlags(): Int32 {
        var flags: Int32 = 0
        if (bold) { flags |= 0x01 }
        if (italic) { flags |= 0x02 }
        if (underline) { flags |= 0x04 }
        if (strikethrough) { flags |= 0x08 }
        flags
    }

    public operator func ==(other: FontStyle): Bool {
        bold == other.bold && italic == other.italic && underline == other.underline &&
            strikethrough == other.strikethrough
    }

    public operator func !=(other: FontStyle): Bool {
        !(this == other)
    }
}
