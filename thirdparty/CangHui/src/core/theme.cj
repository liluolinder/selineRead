package chui.core

import sdl.{Color, SurfaceStyle}

/*
 * The semantic palette widgets draw from: background/panel/field fills, text and accent colors, and
 * the shared corner radii and border width (logical pixels). Widgets read roles (`accent`, `danger`,
 * `mutedText`) rather than literal colors, so swapping the `Theme` on the context restyles the whole
 * tree; `light()` and `dark()` are the built-in variants. The surface builders (`panelSurface`,
 * `fieldSurface`, `buttonSurface`, ...) derive complete `SurfaceStyle`s from these roles so controls
 * share one look. Immutable — construct a new value to change anything. Every constructor parameter
 * is named — a palette is a dozen same-typed colors, and named construction is what keeps each row
 * of a theme readable and un-transposable.
 */
public struct Theme {
    public let bg: Color
    public let panel: Color
    public let panelEdge: Color
    public let text: Color
    public let mutedText: Color
    public let accent: Color
    public let accentText: Color
    public let danger: Color
    public let field: Color
    public let fieldActive: Color
    public let panelRaised: Color
    public let accentSoft: Color
    public let shadow: Color
    public let radius: Float32
    public let smallRadius: Float32
    public let controlRadius: Float32
    public let borderWidth: Float32
    public let motionLevel: MotionLevel
    /** When true, automatic animations collapse to the shortest duration. */
    public let reduceMotion: Bool
    public let fontFamily: ?String
    public let components: ComponentTheme

    public init(
        bg!: Color,
        panel!: Color,
        panelEdge!: Color,
        text!: Color,
        mutedText!: Color,
        accent!: Color,
        accentText!: Color,
        danger!: Color,
        field!: Color,
        fieldActive!: Color,
        panelRaised!: Color = Color.rgb(255, 255, 255),
        accentSoft!: Color = Color.rgb(224, 240, 255),
        shadow!: Color = Color.rgba(16, 24, 40, 34),
        radius!: Float32 = 12.0,
        smallRadius!: Float32 = 7.0,
        controlRadius!: Float32 = 9.0,
        borderWidth!: Float32 = 1.0,
        motionLevel!: MotionLevel = MotionLevel.Standard,
        reduceMotion!: Bool = false,
        fontFamily!: ?String = None<String>,
        components!: ComponentTheme = ComponentTheme()
    ) {
        this.bg = bg
        this.panel = panel
        this.panelEdge = panelEdge
        this.text = text
        this.mutedText = mutedText
        this.accent = accent
        this.accentText = accentText
        this.danger = danger
        this.field = field
        this.fieldActive = fieldActive
        this.panelRaised = panelRaised
        this.accentSoft = accentSoft
        this.shadow = shadow
        this.radius = radius
        this.smallRadius = smallRadius
        this.controlRadius = controlRadius
        this.borderWidth = borderWidth
        this.motionLevel = motionLevel
        this.reduceMotion = reduceMotion
        this.fontFamily = fontFamily
        this.components = components
    }

    public static func light(motionLevel!: MotionLevel = MotionLevel.Standard, reduceMotion!: Bool = false): Theme {
        Theme(
            bg: Color.rgb(242, 245, 249),
            panel: Color.rgb(255, 255, 255),
            panelEdge: Color.rgb(210, 217, 226),
            text: Color.rgb(20, 27, 38),
            mutedText: Color.rgb(93, 105, 122),
            accent: Color.rgb(33, 114, 229),
            accentText: Color.rgb(255, 255, 255),
            danger: Color.rgb(208, 63, 67),
            field: Color.rgb(248, 250, 253),
            fieldActive: Color.rgb(235, 244, 255),
            panelRaised: Color.rgb(255, 255, 255),
            accentSoft: Color.rgb(226, 239, 255),
            shadow: Color.rgba(15, 23, 42, 28),
            radius: 14.0,
            smallRadius: 8.0,
            controlRadius: 10.0,
            motionLevel: motionLevel,
            reduceMotion: reduceMotion
        )
    }

    /** Returns the same visual and motion tokens with a registered default font family. */
    public func withFontFamily(value: ?String): Theme {
        Theme(
            bg: bg,
            panel: panel,
            panelEdge: panelEdge,
            text: text,
            mutedText: mutedText,
            accent: accent,
            accentText: accentText,
            danger: danger,
            field: field,
            fieldActive: fieldActive,
            panelRaised: panelRaised,
            accentSoft: accentSoft,
            shadow: shadow,
            radius: radius,
            smallRadius: smallRadius,
            controlRadius: controlRadius,
            borderWidth: borderWidth,
            motionLevel: motionLevel,
            reduceMotion: reduceMotion,
            fontFamily: value,
            components: components
        )
    }

    /** Returns the same semantic palette with component-scoped appearance overrides. */
    public func withComponents(value: ComponentTheme): Theme {
        Theme(
            bg: bg,
            panel: panel,
            panelEdge: panelEdge,
            text: text,
            mutedText: mutedText,
            accent: accent,
            accentText: accentText,
            danger: danger,
            field: field,
            fieldActive: fieldActive,
            panelRaised: panelRaised,
            accentSoft: accentSoft,
            shadow: shadow,
            radius: radius,
            smallRadius: smallRadius,
            controlRadius: controlRadius,
            borderWidth: borderWidth,
            motionLevel: motionLevel,
            reduceMotion: reduceMotion,
            fontFamily: fontFamily,
            components: value
        )
    }

    public static func dark(motionLevel!: MotionLevel = MotionLevel.Standard, reduceMotion!: Bool = false): Theme {
        Theme(
            bg: Color.rgb(18, 22, 29),
            panel: Color.rgb(28, 34, 44),
            panelEdge: Color.rgb(65, 75, 91),
            text: Color.rgb(241, 245, 249),
            mutedText: Color.rgb(157, 169, 187),
            accent: Color.rgb(87, 166, 255),
            accentText: Color.rgb(8, 18, 31),
            danger: Color.rgb(255, 124, 124),
            field: Color.rgb(36, 43, 55),
            fieldActive: Color.rgb(44, 61, 80),
            panelRaised: Color.rgb(35, 42, 54),
            accentSoft: Color.rgb(34, 62, 96),
            shadow: Color.rgba(0, 0, 0, 72),
            radius: 14.0,
            smallRadius: 8.0,
            controlRadius: 10.0,
            motionLevel: motionLevel,
            reduceMotion: reduceMotion
        )
    }

    /** Returns the same visual palette with a different animation expression level. */
    public func withMotionLevel(value: MotionLevel): Theme {
        Theme(
            bg: bg,
            panel: panel,
            panelEdge: panelEdge,
            text: text,
            mutedText: mutedText,
            accent: accent,
            accentText: accentText,
            danger: danger,
            field: field,
            fieldActive: fieldActive,
            panelRaised: panelRaised,
            accentSoft: accentSoft,
            shadow: shadow,
            radius: radius,
            smallRadius: smallRadius,
            controlRadius: controlRadius,
            borderWidth: borderWidth,
            motionLevel: value,
            reduceMotion: reduceMotion,
            fontFamily: fontFamily,
            components: components
        )
    }

    /** Returns the same visual palette with reduced-motion enabled or disabled. */
    public func withReduceMotion(value: Bool): Theme {
        Theme(
            bg: bg,
            panel: panel,
            panelEdge: panelEdge,
            text: text,
            mutedText: mutedText,
            accent: accent,
            accentText: accentText,
            danger: danger,
            field: field,
            fieldActive: fieldActive,
            panelRaised: panelRaised,
            accentSoft: accentSoft,
            shadow: shadow,
            radius: radius,
            smallRadius: smallRadius,
            controlRadius: controlRadius,
            borderWidth: borderWidth,
            motionLevel: motionLevel,
            reduceMotion: value,
            fontFamily: fontFamily,
            components: components
        )
    }

    /** Linearly blends every visual token toward `other`. */
    public func lerp(other: Theme, t: Float32): Theme {
        let k = max(0.0, min(1.0, t))
        Theme(
            bg: bg.lerp(other.bg, k),
            panel: panel.lerp(other.panel, k),
            panelEdge: panelEdge.lerp(other.panelEdge, k),
            text: text.lerp(other.text, k),
            mutedText: mutedText.lerp(other.mutedText, k),
            accent: accent.lerp(other.accent, k),
            accentText: accentText.lerp(other.accentText, k),
            danger: danger.lerp(other.danger, k),
            field: field.lerp(other.field, k),
            fieldActive: fieldActive.lerp(other.fieldActive, k),
            panelRaised: panelRaised.lerp(other.panelRaised, k),
            accentSoft: accentSoft.lerp(other.accentSoft, k),
            shadow: shadow.lerp(other.shadow, k),
            radius: radius + (other.radius - radius) * k,
            smallRadius: smallRadius + (other.smallRadius - smallRadius) * k,
            controlRadius: controlRadius + (other.controlRadius - controlRadius) * k,
            borderWidth: borderWidth + (other.borderWidth - borderWidth) * k,
            motionLevel: if (k < 0.5) { motionLevel } else { other.motionLevel },
            reduceMotion: reduceMotion || other.reduceMotion,
            fontFamily: if (k < 0.5) { fontFamily } else { other.fontFamily },
            components: if (k < 0.5) { components } else { other.components }
        )
    }

    public func panelSurface(): SurfaceStyle {
        match (components.panelSurface) {
            case Some(value) => value
            case None => SurfaceStyle(
                panel,
                border: panelEdge,
                radius: radius,
                borderWidth: borderWidth,
                shadow: shadow,
                shadowOffsetY: 2.0
            )
        }
    }

    public func raisedSurface(): SurfaceStyle {
        SurfaceStyle(
            panelRaised,
            border: panelEdge,
            radius: radius,
            borderWidth: borderWidth,
            shadow: shadow,
            shadowOffsetY: 3.0
        )
    }

    public func fieldSurface(active: Bool): SurfaceStyle {
        SurfaceStyle(
            if (active) {
                fieldActive
            } else {
                field
            },
            border: if (active) {
                accent
            } else {
                panelEdge
            },
            radius: controlRadius,
            borderWidth: borderWidth,
            shadow: if (active) {
                accent.withAlpha(34)
            } else {
                Color.rgba(0, 0, 0, 0)
            },
            shadowOffsetY: 1.0
        )
    }

    public func buttonSurface(role: ButtonRole): SurfaceStyle {
        match (role) {
            case ButtonRole.Primary => SurfaceStyle(
                accent,
                border: accent,
                radius: controlRadius,
                borderWidth: borderWidth,
                shadow: accent.withAlpha(30),
                shadowOffsetY: 2.5
            )
            case ButtonRole.Danger => SurfaceStyle(
                danger,
                border: danger,
                radius: controlRadius,
                borderWidth: borderWidth,
                shadow: danger.withAlpha(24),
                shadowOffsetY: 2.5
            )
            case ButtonRole.Normal => SurfaceStyle(
                panelRaised,
                border: panelEdge,
                radius: controlRadius,
                borderWidth: borderWidth,
                shadow: shadow.withAlpha(20),
                shadowOffsetY: 1.0
            )
        }
    }

    /** InkWell color that remains visible on each semantic button surface. */
    public func inkColor(role!: ButtonRole = ButtonRole.Normal): Color {
        match (role) {
            case ButtonRole.Normal => accent
            case ButtonRole.Primary => accentText
            case ButtonRole.Danger => accentText
        }
    }

    public func selectedSurface(): SurfaceStyle {
        SurfaceStyle(accent, border: accent, radius: controlRadius, borderWidth: borderWidth)
    }
}
