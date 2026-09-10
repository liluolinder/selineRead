package chui.controls

import std.collection.{ArrayList, HashSet}
import sdl.{Color, Key, Pen, Rect, Size, UiEvent}
import chui.core.{AnimationSpec, Animator, ComponentControlAppearance, ComponentControlKind, ComponentControlState,
    ComponentControlStyle, ControlContentEnvironment, ControlSemantics, InteractionAnimation, LAYOUT_UNBOUNDED,
    Motion, SemanticActionKind, State, UiContext, Widget,
    resolveControlKey, buildKeyedChild, drawFocusRing, drawSurface, emit, focusableControlIdentity,
    handlePointerClick, localState, recordControlSemantics, resolveComponentControlAppearance}

private let ACCORDION_HEADER_H: Float32 = 42.0

/**
 * One section of an `Accordion`: a header title and a builder for the body shown when it is expanded.
 * The body stays built while an animated close is still visible, then is removed once fully collapsed.
 * Per-body local state is therefore dropped after the close transition settles and recreated on reopen.
 */
public struct AccordionSection {
    let title: ?String
    let header: ?() -> Unit
    let body: () -> Unit
    let semanticLabel: String

    public init(title: String, body: () -> Unit) {
        this.title = Some(title)
        this.header = None
        this.body = body
        this.semanticLabel = title
    }

    /** Creates a section with arbitrary decorative header content. */
    public init(accessibilityLabel!: String = "", header!: () -> Unit, body!: () -> Unit) {
        this.title = None
        this.header = Some(header)
        this.body = body
        this.semanticLabel = accessibilityLabel
    }
}

/**
 * A stack of collapsible sections: each has a clickable header (title plus a disclosure chevron) and a
 * body revealed when expanded. Good for settings groups, FAQs and property inspectors. With `single`
 * set, opening one section closes the others (an accordion proper); otherwise sections toggle
 * independently. Expansion is retained by the view's identity, seeded by `initiallyExpanded`, or owned
 * externally through `expanded`.
 *
 * Each header is a keyboard focus stop: Enter or Space toggles the focused section, and Tab walks the
 * headers and the controls inside visible bodies. A closing body remains mounted until its reveal
 * reaches zero; after that its local state resets, so hoist anything that must persist across reopen.
 */
public class Accordion <: Widget {
    private let titles: Array<?String>
    private let headers: Array<?Widget>
    private let semanticLabels: Array<String>
    private let headerIds: Array<String>
    // The built body for each open section, or None while collapsed.
    private let bodies: Array<?Widget>
    private let expandedState: State<HashSet<Int64>>
    private let single: Bool
    private let headerRects: Array<Rect>
    private let bodyRects: Array<Rect>
    private let bodyAnimations: Array<Animator>
    private let headerAnimations: Array<InteractionAnimation>
    private var animationSpec: AnimationSpec
    private var customStyle: ?ComponentControlStyle

    public init(
        sections: Array<AccordionSection>,
        single!: Bool = false,
        expanded!: ?State<HashSet<Int64>> = None,
        initiallyExpanded!: Array<Int64> = [],
        key!: ?String = None,
        animation!: AnimationSpec = AnimationSpec.automatic(duration: Motion.normal, easing: Motion.standard)
    ) {
        let ident = resolveControlKey(key, "Accordion")
        this.single = single
        this.expandedState = match (expanded) {
            case Some(value) => value
            case None => localState<HashSet<Int64>>("Accordion:${ident}:expanded") {
                seedExpanded(initiallyExpanded, single)
            }
        }
        let count = sections.size
        let builtTitles = ArrayList<?String>()
        let builtHeaders = ArrayList<?Widget>()
        let builtSemanticLabels = ArrayList<String>()
        let builtIds = ArrayList<String>()
        let builtBodies = ArrayList<?Widget>()
        let builtBodyAnimations = ArrayList<Animator>()
        let builtHeaderAnimations = ArrayList<InteractionAnimation>()
        // Build header (focus) ids and open bodies in declaration order, so Tab walks header, its body's
        // controls, next header, and so on.
        for (i in 0..count) {
            builtTitles.add(sections[i].title)
            builtSemanticLabels.add(sections[i].semanticLabel)
            let headerId = focusableControlIdentity("Accordion:${ident}:header:${i}")
            builtIds.add(headerId)
            match (sections[i].header) {
                case Some(headerBody) => builtHeaders.add(Some(buildDecorativeControlChild(headerBody)))
                case None => builtHeaders.add(None)
            }
            let isOpen = this.expandedState.value.contains(i)
            let bodyAnimation = localState<Animator>("Accordion:${ident}:body-motion:${i}") {
                Animator(if (isOpen) { 1.0 } else { 0.0 })
            }.value
            builtBodyAnimations.add(bodyAnimation)
            builtHeaderAnimations.add(localState<InteractionAnimation>("Accordion:${ident}:header-motion:${i}") {
                InteractionAnimation()
            }.value)
            if (isOpen || bodyAnimation.value > 0.001) {
                let sectionBody = sections[i].body
                builtBodies.add(Some(buildKeyedChild("Accordion:${ident}:body:${i}") {=> sectionBody()}))
            } else {
                builtBodies.add(None)
            }
        }
        this.titles = builtTitles.toArray()
        this.headers = builtHeaders.toArray()
        this.semanticLabels = builtSemanticLabels.toArray()
        this.headerIds = builtIds.toArray()
        this.bodies = builtBodies.toArray()
        this.bodyAnimations = builtBodyAnimations.toArray()
        this.headerAnimations = builtHeaderAnimations.toArray()
        this.headerRects = Array<Rect>(count, {_ => Rect.zero()})
        this.bodyRects = Array<Rect>(count, {_ => Rect.zero()})
        this.animationSpec = animation
        this.customStyle = None
        emit(this)
    }

    /** Applies an automatic or exact expansion animation property. */
    public func animation(value: AnimationSpec): Accordion {
        animationSpec = value
        this
    }

    /** Overrides the component theme's state-aware Accordion header style. */
    public func controlStyle(value: ComponentControlStyle): Accordion {
        customStyle = Some(value)
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        var height: Float32 = 0.0
        for (i in 0..titles.size) {
            height += headerHeight(ctx, i, available.w)
            match (bodies[i]) {
                case Some(widget) =>
                    let fullHeight = widget.measure(ctx, Size(available.w, LAYOUT_UNBOUNDED)).h
                    height += fullHeight * bodyProgress(i)
                case None => ()
            }
        }
        Size(available.w, height)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        var y = rect.y
        for (i in 0..titles.size) {
            let height = headerHeight(ctx, i, rect.w)
            headerRects[i] = Rect(rect.x, y, rect.w, height)
            match (headers[i]) {
                case Some(widget) => widget.layout(ctx, headerContentFrame(ctx, headerRects[i]))
                case None => ()
            }
            y += height
            match (bodies[i]) {
                case Some(widget) =>
                    let bodyHeight = widget.measure(ctx, Size(rect.w, LAYOUT_UNBOUNDED)).h
                    let visibleHeight = bodyHeight * bodyProgress(i)
                    widget.layout(ctx, Rect(rect.x, y, rect.w, bodyHeight))
                    bodyRects[i] = Rect(rect.x, y, rect.w, visibleHeight)
                    y += visibleHeight
                case None => bodyRects[i] = Rect.zero()
            }
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (i in 0..titles.size) {
            let target: Float32 = if (expandedState.value.contains(i)) { 1.0 } else { 0.0 }
            let reveal = bodyAnimations[i].animate(ctx, target: target, spec: animationSpec)
            drawHeader(ctx, i, reveal)
            match (bodies[i]) {
                case Some(widget) =>
                    if (bodyRects[i].h > 0.001) {
                        ctx.renderer.pushClip(bodyRects[i])
                        widget.draw(ctx)
                        ctx.renderer.popClip()
                    }
                case None => ()
            }
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        for (i in 0..titles.size) {
            let appearance = currentHeaderAppearance(ctx, i, bodyProgress(i))
            if (handlePointerClick(ctx, event, headerRects[i], headerIds[i], {=>
                ctx.preserveScrollAnchor()
                toggleSection(i)
            }, inkRadius: appearance.focusRadius, inkColor: Some(appearance.ink))) {
                return true
            }
        }
        match (event) {
            case UiEvent.Frame(_) =>
                for (widget in bodies) {
                    match (widget) {
                        case Some(w) => let _ = w.handle(ctx, event)
                        case None => ()
                    }
                }
                return false
            case UiEvent.KeyDown(Key.Enter, _) => if (toggleFocusedHeader(ctx)) {
                return true
            }
            case UiEvent.KeyDown(Key.Space, _) => if (toggleFocusedHeader(ctx)) {
                return true
            }
            case _ => ()
        }
        // A closing body stays mounted only for drawing. Once its state is closed it leaves normal
        // input immediately, so clipped content cannot receive invisible pointer or keyboard events.
        var i = titles.size - 1
        while (i >= 0) {
            if (expandedState.value.contains(i)) {
                match (bodies[i]) {
                    case Some(w) => if (w.handle(ctx, event)) {
                        return true
                    }
                    case None => ()
                }
            }
            i -= 1
        }
        false
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (i in 0..titles.size) {
            ids.add(headerIds[i])
            if (expandedState.value.contains(i)) {
                match (bodies[i]) {
                    case Some(w) => for (fid in w.focusableIds()) {
                        ids.add(fid)
                    }
                    case None => ()
                }
            }
        }
        ids.toArray()
    }

    private func toggleFocusedHeader(ctx: UiContext): Bool {
        for (i in 0..titles.size) {
            if (ctx.hasFocus(headerIds[i])) {
                let appearance = currentHeaderAppearance(ctx, i, bodyProgress(i))
                ctx.preserveScrollAnchor()
                ctx.startInkRipple(headerIds[i], headerRects[i], headerRects[i].centerX(), headerRects[i].centerY(),
                    color: Some(appearance.ink), cornerRadius: appearance.focusRadius)
                toggleSection(i)
                return true
            }
        }
        false
    }

    // Rebuilds the expansion set as a fresh value so the state write is observed. In single mode,
    // opening a section closes the others.
    private func toggleSection(index: Int64): Unit {
        let next = HashSet<Int64>()
        let isOpen = expandedState.value.contains(index)
        if (!isOpen && single) {
            // Opening in single mode: start from empty, so all others close.
            next.add(index)
        } else {
            for (existing in expandedState.value) {
                next.add(existing)
            }
            if (isOpen) {
                next.remove(index)
            } else {
                next.add(index)
            }
        }
        expandedState.value = next
    }

    private func drawHeader(ctx: UiContext, index: Int64, reveal: Float32): Unit {
        let rect = headerRects[index]
        let headerId = headerIds[index]
        let progress = headerAnimations[index].animate(ctx, ctx.isHovered(headerId), ctx.isPressed(headerId),
            AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate))
        let appearance = resolveComponentControlAppearance(ctx.theme, ComponentControlKind.AccordionHeader,
            ComponentControlState(hover: progress.hover, press: progress.press,
                focused: ctx.hasFocus(headerId), selected: expandedState.value.contains(index),
                selection: Some(reveal), expanded: expandedState.value.contains(index)),
            styleOverride: customStyle)
        drawSurface(ctx, rect, appearance.surface)
        recordControlSemantics(ctx, rect, "AccordionHeader", ControlSemantics(
            "button",
            label: semanticLabels[index],
            value: if (expandedState.value.contains(index)) { "expanded" } else { "collapsed" },
            action: "Accordion.toggle(" + index.toString() + ")",
            actionOwner: headerId,
            expanded: Some(expandedState.value.contains(index)),
            typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate]
        ))
        if (ctx.showFocusRing(headerId)) {
            drawFocusRing(ctx, rect, appearance.focusRadius)
        }
        let insets = ctx.resolve(ctx.theme.components.spacing.controlPadding)
        drawDisclosure(ctx, rect.x + insets.left + 6.0, rect.centerY(), reveal, appearance.indicator)
        match (titles[index]) {
            case Some(value) =>
                let pointSize = max(1.0, ctx.resolve(ctx.theme.components.typography.control))
                let textY = rect.centerY() - ctx.renderer.textHeight(pointSize: pointSize) / 2.0
                ctx.renderer.text(value, headerContentFrame(ctx, rect).x, textY, appearance.foreground,
                    pointSize: pointSize)
            case None => match (headers[index]) {
                case Some(widget) => ctx.withControlContentEnvironment(ControlContentEnvironment(
                    appearance.foreground,
                    role: "button",
                    interactionOwner: headerId,
                    selected: expandedState.value.contains(index),
                    expanded: expandedState.value.contains(index),
                    focused: ctx.hasFocus(headerId),
                    hovered: progress.hover > 0.0,
                    pressed: progress.press > 0.0
                )) {=> widget.draw(ctx)}
                case None => ()
            }
        }
    }

    private func bodyProgress(index: Int64): Float32 {
        max(0.0, min(1.0, bodyAnimations[index].value))
    }

    private func headerHeight(ctx: UiContext, index: Int64, availableWidth: Float32): Float32 {
        let spacing = ctx.theme.components.spacing
        let insets = ctx.resolve(spacing.controlPadding)
        let contentHeight = match (headers[index]) {
            case Some(widget) => widget.measure(ctx,
                Size(max(0.0, availableWidth - insets.horizontal() - 22.0), LAYOUT_UNBOUNDED)).h
            case None => ctx.renderer.textHeight(
                pointSize: max(1.0, ctx.resolve(ctx.theme.components.typography.control)))
        }
        max(ACCORDION_HEADER_H, max(spacing.controlMinHeight, contentHeight + insets.vertical()))
    }

    private func headerContentFrame(ctx: UiContext, rect: Rect): Rect {
        let insets = ctx.resolve(ctx.theme.components.spacing.controlPadding)
        Rect(rect.x + insets.left + 22.0, rect.y + insets.top,
            max(0.0, rect.w - insets.horizontal() - 22.0),
            max(0.0, rect.h - insets.vertical()))
    }

    private func currentHeaderAppearance(
        ctx: UiContext,
        index: Int64,
        reveal: Float32
    ): ComponentControlAppearance {
        let headerId = headerIds[index]
        let expanded = expandedState.value.contains(index)
        resolveComponentControlAppearance(ctx.theme, ComponentControlKind.AccordionHeader,
            ComponentControlState(
                hover: if (ctx.isHovered(headerId)) { 1.0 } else { 0.0 },
                press: if (ctx.isPressed(headerId)) { 1.0 } else { 0.0 },
                focused: ctx.hasFocus(headerId),
                selected: expanded,
                selection: Some(reveal),
                expanded: expanded
            ), styleOverride: customStyle)
    }
}

// A disclosure chevron interpolating from right to down as the body reveals.
private func drawDisclosure(ctx: UiContext, cx: Float32, cy: Float32, progress: Float32, color: Color): Unit {
    let pen = Pen(width: 1.7, color: color)
    let arm: Float32 = 3.5
    let t = max(0.0, min(1.0, progress))
    let x1 = (cx - arm * 0.5) + ((cx - arm) - (cx - arm * 0.5)) * t
    let y1 = (cy - arm) + ((cy - arm * 0.5) - (cy - arm)) * t
    let xm = (cx + arm * 0.5) + (cx - (cx + arm * 0.5)) * t
    let ym = cy + ((cy + arm * 0.5) - cy) * t
    let x2 = (cx - arm * 0.5) + ((cx + arm) - (cx - arm * 0.5)) * t
    let y2 = (cy + arm) + ((cy - arm * 0.5) - (cy + arm)) * t
    ctx.renderer.strokeLine(x1, y1, xm, ym, pen)
    ctx.renderer.strokeLine(xm, ym, x2, y2, pen)
}

// The seed expansion set: the requested indices, capped to one when `single`.
private func seedExpanded(indices: Array<Int64>, single: Bool): HashSet<Int64> {
    let set = HashSet<Int64>()
    for (index in indices) {
        if (single && !set.isEmpty()) {
            break
        }
        set.add(index)
    }
    set
}
