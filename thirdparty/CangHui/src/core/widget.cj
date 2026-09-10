package chui.core

import sdl.{Color, FontStyle, Rect, Size, SurfaceStyle, UiEvent}

protected let CUI_CONTROL_H: Float32 = 38.0
protected let CUI_SMALL_H: Float32 = 28.0
protected let CUI_GAP: Float32 = 8.0

/*
 * The immediate-mode widget contract. The tree is rebuilt from application code on every rendered
 * frame, so instances carry no retained scene — anything that must survive a rebuild lives in `State`
 * (see `localState`). Constructors call `emit(this)` so the enclosing container collects the widget in
 * declaration order. Each frame the shell calls `measure` (preferred size within `available`), `layout`
 * (assigns the frame), `draw`, and `handle` per input event; `handle` returns whether the event was
 * consumed, which stops dispatch to the widgets behind it. The default `width`/`padding`/... modifiers
 * wrap the widget in a `ModifiedWidget` and return the wrapper for chaining.
 */
public interface Widget {
    func measure(ctx: UiContext, available: Size): Size
    func layout(ctx: UiContext, rect: Rect): Unit
    func draw(ctx: UiContext): Unit
    func handle(ctx: UiContext, event: UiEvent): Bool

    /**
     * A flexible widget receives a share of its stack's leftover space instead of the
     * size it measured; non-flexible widgets hug their content. `flexWeight` sets the
     * relative share — wrap any widget in `Flexible(weight: ...)` to opt it in.
     */
    func isFlexible(): Bool {
        false
    }

    func flexWeight(): Float32 {
        1.0
    }

    /** Whether a stack may stretch this widget on `axis` beyond its measured size. */
    func acceptsStretch(_: Axis): Bool {
        true
    }

    /** Whether this node occupies a position in its parent layout. */
    func participatesInLayout(): Bool {
        true
    }

    /** Paint order among siblings in the same stacking context. Measurement is unchanged. */
    func stackingIndex(): Int64 {
        0
    }

    /*
     * The keyboard-focus id this widget registered during construction, or `None` for
     * non-focusable widgets and multi-control containers. Single-child wrappers forward
     * their child's id; `.enabled(false)` uses it to take the control out of Tab traversal.
     */
    func focusableId(): ?String {
        None
    }

    /*
     * Every keyboard-focus id this widget's subtree registered during construction, in
     * declaration order. The default covers leaf controls (their single `focusableId`);
     * containers concatenate their children's and wrappers forward. `.enabled(false)`
     * uses it to take a whole disabled subtree out of Tab traversal.
     */
    func focusableIds(): Array<String> {
        match (focusableId()) {
            case Some(id) => [id]
            case None => []
        }
    }

    /*
     * Every node in this subtree that can own ordinary input or an accessibility
     * action, independently from keyboard focus. The default covers focusable
     * controls; event-only nodes and containers must override and propagate it.
     * `InteractionSurface` uses this to keep its decorative slot one-owner-only.
     */
    func interactionOwnerIds(): Array<String> {
        focusableIds()
    }

    /**
     * Whether generic widget modifiers leave this subtree interactive. Controls with an intrinsic
     * display-only/read-only mode should still express that through their own semantic action; this
     * flag is reserved for `.enabled(false)` propagation through wrappers and probes.
     */
    func interactionsEnabled(): Bool {
        true
    }

    /** Supplies independently optional typography values to descendant semantic text leaves. */
    func typography(value: TypographyEnvironment): Widget {
        applyModifier(this, WidgetModifier.Typography(value))
    }

    /** Supplies an inherited registered font family to descendant semantic text leaves. */
    func fontFamily(value: String): Widget {
        typography(TypographyEnvironment(fontFamily: value))
    }

    /** Supplies an inherited font size to descendant semantic text leaves. */
    func fontSize(value: Length): Widget {
        typography(TypographyEnvironment(fontSize: value))
    }

    /** Supplies an inherited font size in font pixels. */
    func fontSize(value: Float32): Widget {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Supplies a complete inherited style, including explicit Regular clearing. */
    func fontStyle(value: FontStyle): Widget {
        typography(TypographyEnvironment().withFontStyle(value))
    }

    /** Supplies an inherited bold value without replacing the other style fields. */
    func bold(): Widget {
        bold(value: true)
    }

    func bold(value!: Bool): Widget {
        typography(TypographyEnvironment(bold: value))
    }

    /** Supplies an inherited italic value without replacing the other style fields. */
    func italic(): Widget {
        italic(value: true)
    }

    func italic(value!: Bool): Widget {
        typography(TypographyEnvironment(italic: value))
    }

    /** Supplies an inherited underline value without replacing the other style fields. */
    func underline(): Widget {
        underline(value: true)
    }

    func underline(value!: Bool): Widget {
        typography(TypographyEnvironment(underline: value))
    }

    /** Supplies an inherited strikethrough value without replacing the other style fields. */
    func strikethrough(): Widget {
        strikethrough(value: true)
    }

    func strikethrough(value!: Bool): Widget {
        typography(TypographyEnvironment(strikethrough: value))
    }

    /** Constrains this widget to an exact width, e.g. `.width(160.vp)`. */
    func width(value: Length): Widget {
        applyModifier(this, WidgetModifier.Width(value))
    }

    /** Constrains this widget to an exact width in virtual pixels. */
    func width(value: Float32): Widget {
        width(vpLength(value))
    }

    /** Constrains this widget to an exact height, e.g. `.height(48.vp)`. */
    func height(value: Length): Widget {
        applyModifier(this, WidgetModifier.Height(value))
    }

    /** Constrains this widget to an exact height in virtual pixels. */
    func height(value: Float32): Widget {
        height(vpLength(value))
    }

    /** Prevents this widget from measuring narrower than `value`. */
    func minWidth(value: Length): Widget {
        applyModifier(this, WidgetModifier.MinWidth(value))
    }

    /** Prevents this widget from measuring narrower than `value` virtual pixels. */
    func minWidth(value: Float32): Widget {
        minWidth(vpLength(value))
    }

    /** Prevents this widget from measuring wider than `value`. */
    func maxWidth(value: Length): Widget {
        applyModifier(this, WidgetModifier.MaxWidth(value))
    }

    /** Prevents this widget from measuring wider than `value` virtual pixels. */
    func maxWidth(value: Float32): Widget {
        maxWidth(vpLength(value))
    }

    /** Prevents this widget from measuring shorter than `value`. */
    func minHeight(value: Length): Widget {
        applyModifier(this, WidgetModifier.MinHeight(value))
    }

    /** Prevents this widget from measuring shorter than `value` virtual pixels. */
    func minHeight(value: Float32): Widget {
        minHeight(vpLength(value))
    }

    /** Prevents this widget from measuring taller than `value`. */
    func maxHeight(value: Length): Widget {
        applyModifier(this, WidgetModifier.MaxHeight(value))
    }

    /** Prevents this widget from measuring taller than `value` virtual pixels. */
    func maxHeight(value: Float32): Widget {
        maxHeight(vpLength(value))
    }

    /** Makes this widget consume all width offered by its parent. */
    func fillWidth(): Widget {
        applyModifier(this, WidgetModifier.FillWidth)
    }

    /** Makes this widget consume all height offered by its parent. */
    func fillHeight(): Widget {
        applyModifier(this, WidgetModifier.FillHeight)
    }

    /** Adds equal space around this widget, e.g. `.padding(16.vp)`. Order is significant. */
    func padding(all: Length): Widget {
        applyModifier(this, WidgetModifier.Padding(LengthInsets(all)))
    }

    /** Adds equal space around this widget in virtual pixels. */
    func padding(all: Float32): Widget {
        padding(vpLength(all))
    }

    /** Adds horizontal and vertical space around this widget. */
    func padding(horizontal: Length, vertical: Length): Widget {
        applyModifier(this, WidgetModifier.Padding(LengthInsets(horizontal, vertical)))
    }

    /** Adds horizontal and vertical space around this widget in virtual pixels. */
    func padding(horizontal: Float32, vertical: Float32): Widget {
        padding(vpLength(horizontal), vpLength(vertical))
    }

    /** Adds independently configurable space around all four edges. */
    func padding(left: Length, top: Length, right: Length, bottom: Length): Widget {
        applyModifier(this, WidgetModifier.Padding(LengthInsets(top: top, right: right, bottom: bottom, left: left)))
    }

    /** Adds independently configurable space around all four edges in virtual pixels. */
    func padding(left: Float32, top: Float32, right: Float32, bottom: Float32): Widget {
        padding(vpLength(left), vpLength(top), vpLength(right), vpLength(bottom))
    }

    /** Paints a solid rounded background behind this widget. */
    func background(color: Color): Widget {
        applyModifier(this, WidgetModifier.Surface(SurfaceStyle(color)))
    }

    /** Paints a solid background with the requested corner radius. */
    func background(color: Color, radius: Length): Widget {
        applyModifier(this, WidgetModifier.Background(color, radius))
    }

    /** Paints a solid background with the corner radius in virtual pixels. */
    func background(color: Color, radius: Float32): Widget {
        background(color, vpLength(radius))
    }

    /**
     * Paints a solid background whose four corners take independent radii (see `Corners`) — for chat
     * bubbles, top-rounded tabs, and edge-docked sheets. Radii are in virtual pixels.
     */
    func background(color: Color, corners!: Corners): Widget {
        applyModifier(this, WidgetModifier.PerCornerBackground(corners, color))
    }

    /** Paints a complete surface style behind this widget. */
    func surface(style: SurfaceStyle): Widget {
        applyModifier(this, WidgetModifier.Surface(style))
    }

    /** Paints a linear-gradient background behind this widget (see `Gradient`). */
    func gradientBackground(gradient: Gradient): Widget {
        applyModifier(this, WidgetModifier.GradientBackground(gradient, vpLength(0.0)))
    }

    /** Paints a linear-gradient background with the given corner radius. */
    func gradientBackground(gradient: Gradient, radius: Length): Widget {
        applyModifier(this, WidgetModifier.GradientBackground(gradient, radius))
    }

    /** Paints a linear-gradient background with the corner radius in virtual pixels. */
    func gradientBackground(gradient: Gradient, radius: Float32): Widget {
        gradientBackground(gradient, vpLength(radius))
    }

    /**
     * Casts a soft drop shadow behind this widget. The halo is painted behind the child, so chain it
     * after a rounded `background` and pass the matching corner radius so the shadow hugs the corners.
     */
    func shadow(value: Shadow): Widget {
        applyModifier(this, WidgetModifier.DropShadow(value, vpLength(0.0)))
    }

    /** Casts a soft drop shadow rounded to `radius` (match the widget's own rounding). */
    func shadow(value: Shadow, radius!: Length): Widget {
        applyModifier(this, WidgetModifier.DropShadow(value, radius))
    }

    /** Casts a soft drop shadow with the corner radius in virtual pixels. */
    func shadow(value: Shadow, radius!: Float32): Widget {
        applyModifier(this, WidgetModifier.DropShadow(value, vpLength(radius)))
    }

    /** Strokes a 1px rounded border on top of this widget's fill and content. */
    /**
     * Casts several stacked drop shadows behind this widget, painted in array order (first is
     * deepest). `Shadow.keyAmbient(level)` supplies the standard Material key-plus-ambient pair.
     */
    func shadow(layers: Array<Shadow>): Widget {
        applyModifier(this, WidgetModifier.MultiShadow(layers, vpLength(0.0)))
    }

    /** Casts stacked drop shadows hugging the given corner radius. */
    func shadow(layers: Array<Shadow>, radius!: Length): Widget {
        applyModifier(this, WidgetModifier.MultiShadow(layers, radius))
    }

    /** Casts stacked drop shadows with the corner radius in virtual pixels. */
    func shadow(layers: Array<Shadow>, radius!: Float32): Widget {
        shadow(layers, radius: vpLength(radius))
    }

    func border(color: Color): Widget {
        applyModifier(this, WidgetModifier.Border(color, 1.0, vpLength(0.0)))
    }

    /** Strokes a `width`-thick rounded border on top of this widget. */
    func border(color: Color, width!: Float32): Widget {
        applyModifier(this, WidgetModifier.Border(color, max(0.0, width), vpLength(0.0)))
    }

    /** Strokes a rounded border with the given width and corner radius (match the widget's rounding). */
    func border(color: Color, width!: Float32, radius!: Length): Widget {
        applyModifier(this, WidgetModifier.Border(color, max(0.0, width), radius))
    }

    /** Strokes a rounded border with the corner radius in virtual pixels. */
    func border(color: Color, width!: Float32, radius!: Float32): Widget {
        applyModifier(this, WidgetModifier.Border(color, max(0.0, width), vpLength(radius)))
    }

    /** Strokes a dashed 1.5px rounded border (dash 6, gap 4) on top of this widget. */
    func dashedBorder(color: Color): Widget {
        applyModifier(this, WidgetModifier.DashedBorder(color, 1.5, vpLength(0.0), 6.0, 4.0))
    }

    /** Strokes a dashed rounded border with the corner radius in virtual pixels (default dash 6, gap 4). */
    func dashedBorder(color: Color, radius!: Float32): Widget {
        applyModifier(this, WidgetModifier.DashedBorder(color, 1.5, vpLength(radius), 6.0, 4.0))
    }

    /** Strokes a fully configured dashed rounded border (width, corner radius, dash and gap lengths). */
    func dashedBorder(color: Color, width!: Float32, radius!: Float32, dash!: Float32, gap!: Float32): Widget {
        applyModifier(this, WidgetModifier.DashedBorder(color, max(0.0, width), vpLength(radius), max(0.0, dash),
            max(0.0, gap)))
    }

    /** Gives this widget a relative share of an enclosing stack's remaining space. */
    func flex(): Widget {
        applyModifier(this, WidgetModifier.Flex(1.0))
    }

    /** Gives this widget `weight` shares of an enclosing stack's remaining space. */
    func flex(weight: Float32): Widget {
        applyModifier(this, WidgetModifier.Flex(max(0.0, weight)))
    }

    /** ArkTS-shaped alias for sharing an enclosing Row/HStack's remaining space. */
    func layoutWeight(): Widget {
        flex()
    }

    /** ArkTS-shaped alias for sharing remaining space with an explicit weight. */
    func layoutWeight(weight: Float32): Widget {
        flex(weight)
    }

    /**
     * Sets this widget's paint and hit-test order among siblings in the same stacking context.
     * Higher values paint later and receive input first; equal values retain declaration order.
     */
    func zIndex(value: Int64): Widget {
        applyModifier(this, WidgetModifier.ZIndex(value))
    }

    /** Includes or removes this widget from layout, drawing, and event dispatch. */
    func visible(isVisible: Bool): Widget {
        if (!isVisible) {
            // A hidden subtree also leaves Tab traversal: its draw is skipped (no ring could
            // show) and its handle is suppressed (Enter/Space would do nothing), so a stop
            // kept in the ring would be an invisible dead end. Same protocol as `enabled`.
            for (id in focusableIds()) {
                unregisterFocusable(id)
            }
        }
        applyModifier(this, WidgetModifier.Visible(isVisible))
    }

    /*
     * Keeps this widget in layout and drawing while suppressing input events. A disabled
     * subtree also leaves keyboard Tab traversal — a stop that ignores Enter/Space would
     * be a dead end. Works at any granularity: on a single control or on a container
     * (an HStack form row, a whole panel), whose focus stops are removed via
     * `focusableIds()`.
     */
    func enabled(isEnabled: Bool): Widget {
        if (!isEnabled) {
            for (id in focusableIds()) {
                unregisterFocusable(id)
            }
        }
        applyModifier(this, WidgetModifier.Enabled(isEnabled))
    }

    /**
     * Adds a stable `cui.probe.v0` node around this widget. `semantics` may expose
     * dynamic public state such as selected/disabled/value on each sampled frame.
     */
    func probe(id: String): Widget {
        applyProbeModifier(this, id, "Widget", [], None<ProbeSemanticProvider>)
    }

    func probe(id: String, widgetType: String): Widget {
        applyProbeModifier(this, id, widgetType, [], None<ProbeSemanticProvider>)
    }

    func probe(id: String, widgetType: String, properties: Array<ProbeProperty>): Widget {
        applyProbeModifier(this, id, widgetType, properties, None<ProbeSemanticProvider>)
    }

    func probe(id: String, widgetType: String, properties: Array<ProbeProperty>,
        semantics: ProbeSemanticProvider): Widget {
        applyProbeModifier(this, id, widgetType, properties, Some(semantics))
    }
}

public enum Axis {
    | Horizontal
    | Vertical
}

public enum ButtonRole {
    | Normal
    | Primary
    | Danger
}

public enum TextAlign {
    | Leading
    | Center
    | Trailing
}

/** Controls how a stack positions children along its main axis. */
public enum MainAxisAlignment {
    | Start
    | Center
    | End
    | SpaceBetween
    | SpaceAround
    | SpaceEvenly
}

/** Controls how a stack positions children across its main axis. */
public enum CrossAxisAlignment {
    | Start
    | Center
    | End
    | Stretch
}

/** A two-dimensional alignment used by overlay-style containers. */
public enum Alignment {
    | TopLeading
    | Top
    | TopTrailing
    | Leading
    | Center
    | Trailing
    | BottomLeading
    | Bottom
    | BottomTrailing
}
