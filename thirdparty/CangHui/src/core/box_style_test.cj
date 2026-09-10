package chui.core

import sdl.{Color, Rect, Size}

@Test
func shadowElevationScalesWithLevel(): Unit {
    let e1 = Shadow.elevation(1)
    let e4 = Shadow.elevation(4)
    // Deeper elevation drops further and blurs softer.
    @Expect(e4.offsetY > e1.offsetY)
    @Expect(e4.blur > e1.blur)
    // Level is clamped to 1..6.
    @Expect(Shadow.elevation(0).offsetY == Shadow.elevation(1).offsetY)
    @Expect(Shadow.elevation(10).blur == Shadow.elevation(6).blur)
}

@Test
func shadowDefaultsAndWithColor(): Unit {
    let s = Shadow(color: Color.rgb(0, 0, 0))
    @Expect(s.offsetY == Float32(2.0))
    @Expect(s.blur == Float32(12.0))
    @Expect(s.spread == Float32(0.0))
    // A negative blur is clamped to zero.
    @Expect(Shadow(color: Color.rgb(0, 0, 0), blur: -5.0).blur == Float32(0.0))
    // withColor swaps the colour but keeps the geometry.
    let tinted = Shadow.elevation(2).withColor(Color.rgb(255, 0, 0))
    @Expect(Int64(tinted.color.r), 255)
    @Expect(tinted.blur == Shadow.elevation(2).blur)
}

@Test
func gradientStoresStopsAndReverses(): Unit {
    let g = Gradient(start: Color.rgb(10, 20, 30), end: Color.rgb(200, 180, 160))
    @Expect(g.vertical)
    @Expect(Int64(g.start.r), 10)
    @Expect(Int64(g.end.r), 200)
    // reversed swaps the stops but keeps the axis.
    let r = g.reversed()
    @Expect(Int64(r.start.r), 200)
    @Expect(Int64(r.end.r), 10)
    @Expect(r.vertical == g.vertical)
    // A horizontal gradient records its axis.
    @Expect(!Gradient(start: Color.rgb(0, 0, 0), end: Color.rgb(255, 255, 255), vertical: false).vertical)
}

@Test
func gradientBackgroundIsDecorationNotResizing(): Unit {
    let ctx = testContext()
    let room = Size(300.0, 200.0)
    let g = Gradient(start: Color.rgb(80, 120, 240), end: Color.rgb(200, 80, 160))
    let plain = Label("Card").measure(ctx, room)
    // A gradient background is a decoration: it does not change the measured size.
    let gradiented = Label("Card").gradientBackground(g, 12.0).measure(ctx, room)
    @Expect(gradiented.w == plain.w)
    @Expect(gradiented.h == plain.h)
    // Lays out and draws against the headless renderer (a no-op fill) without throwing.
    let card = Label("Card").padding(16.0).gradientBackground(g, 12.0)
    card.layout(ctx, Rect(0.0, 0.0, 200.0, 60.0))
    card.draw(ctx)
}

@Test
func shadowAndBorderAreDecorationsNotResizing(): Unit {
    let ctx = testContext()
    let room = Size(300.0, 200.0)
    let plain = Label("Card").measure(ctx, room)
    // Shadow, border, and their combination are decorations: they must not change the measured size.
    let shadowed = Label("Card").shadow(Shadow.elevation(3), radius: 12.0).measure(ctx, room)
    @Expect(shadowed.w == plain.w)
    @Expect(shadowed.h == plain.h)
    let bordered = Label("Card").border(Color.rgb(0, 0, 0), width: 2.0, radius: 12.0).measure(ctx, room)
    @Expect(bordered.w == plain.w)
    @Expect(bordered.h == plain.h)
}

@Test
func dashedBorderIsDecorationNotResizing(): Unit {
    let ctx = testContext()
    let room = Size(300.0, 200.0)
    let plain = Label("Card").measure(ctx, room)
    // A dashed border is a decoration: it does not change the measured size.
    let dashed = Label("Card").dashedBorder(Color.rgb(120, 120, 120), radius: 12.0).measure(ctx, room)
    @Expect(dashed.w == plain.w)
    @Expect(dashed.h == plain.h)
    // Fully configured, it lays out and draws against the headless renderer without throwing.
    let card = Label("Card")
        .padding(12.0)
        .dashedBorder(Color.rgb(120, 120, 120), width: 2.0, radius: 10.0, dash: 6.0, gap: 4.0)
    card.layout(ctx, Rect(0.0, 0.0, 200.0, 60.0))
    card.draw(ctx)
}

@Test
func keyAmbientBuildsTheMaterialPair(): Unit {
    let layers = Shadow.keyAmbient(3)
    // Two layers: the ambient halo first (painted deepest), the key shadow second.
    @Expect(layers.size, 2)
    let ambient = layers[0]
    let key = layers[1]
    // The ambient is the wide, faint, near-omni layer; the key is tighter, darker, and drops further.
    @Expect(ambient.blur > key.blur)
    @Expect(Int64(ambient.color.a) < Int64(key.color.a))
    @Expect(key.offsetY > ambient.offsetY)
    // Level scales both layers and clamps to 1..6 like the single-layer elevation.
    let deep = Shadow.keyAmbient(6)
    @Expect(deep[1].offsetY > key.offsetY)
    @Expect(Shadow.keyAmbient(0)[1].offsetY == Shadow.keyAmbient(1)[1].offsetY)
    @Expect(Shadow.keyAmbient(99)[0].blur == Shadow.keyAmbient(6)[0].blur)
    // A tint recolours both layers but keeps their relative alphas.
    let tinted = Shadow.keyAmbient(3, color: Color.rgb(30, 40, 80))
    @Expect(Int64(tinted[0].color.b), 80)
    @Expect(Int64(tinted[0].color.a) < Int64(tinted[1].color.a))
}

@Test
func multiShadowIsDecorationNotResizing(): Unit {
    let ctx = testContext()
    let room = Size(300.0, 200.0)
    let plain = Label("Card").measure(ctx, room)
    // Stacked shadows are decoration: the measured size is untouched.
    let layered = Label("Card").shadow(Shadow.keyAmbient(3), radius: 12.0).measure(ctx, room)
    @Expect(layered.w == plain.w)
    @Expect(layered.h == plain.h)
    // A full dual-layer card lays out and draws against the headless renderer without throwing,
    // and an empty layer list is a safe no-op.
    let card = Label("Card").padding(16.0).background(Color.rgb(255, 255, 255), 12.0)
        .shadow(Shadow.keyAmbient(4), radius: 12.0)
    card.layout(ctx, Rect(0.0, 0.0, 200.0, 60.0))
    card.draw(ctx)
    let none = Label("Card").shadow(Array<Shadow>(), radius: 8.0)
    none.layout(ctx, Rect(0.0, 0.0, 200.0, 60.0))
    none.draw(ctx)
}

@Test
func cornersStoreValuesAndFactoriesShapeSides(): Unit {
    // The full initializer records each corner independently (top-left, top-right, bottom-right, bottom-left).
    let c = Corners(topLeft: 16.0, topRight: 12.0, bottomRight: 4.0, bottomLeft: 8.0)
    @Expect(c.topLeft == Float32(16.0))
    @Expect(c.topRight == Float32(12.0))
    @Expect(c.bottomRight == Float32(4.0))
    @Expect(c.bottomLeft == Float32(8.0))
    // all() rounds every corner equally.
    let a = Corners.all(10.0)
    @Expect(a.topLeft == Float32(10.0) && a.bottomRight == Float32(10.0))
    // top() rounds the top two and leaves the bottom two square.
    let t = Corners.top(10.0)
    @Expect(t.topLeft == Float32(10.0) && t.topRight == Float32(10.0))
    @Expect(t.bottomLeft == Float32(0.0) && t.bottomRight == Float32(0.0))
    // bottom() / left() / right() round only their side.
    @Expect(Corners.bottom(6.0).bottomLeft == Float32(6.0) && Corners.bottom(6.0).topLeft == Float32(0.0))
    @Expect(Corners.left(6.0).topLeft == Float32(6.0) && Corners.left(6.0).topRight == Float32(0.0))
    @Expect(Corners.right(6.0).topRight == Float32(6.0) && Corners.right(6.0).topLeft == Float32(0.0))
}

@Test
func perCornerBackgroundIsDecorationNotResizing(): Unit {
    let ctx = testContext()
    let room = Size(300.0, 200.0)
    let plain = Label("Bubble").measure(ctx, room)
    // A per-corner background is a decoration: it does not change the measured size.
    let bubble = Corners(topLeft: 16.0, topRight: 16.0, bottomRight: 16.0, bottomLeft: 4.0)
    let bubbled = Label("Bubble").background(Color.rgb(230, 240, 255), corners: bubble).measure(ctx, room)
    @Expect(bubbled.w == plain.w)
    @Expect(bubbled.h == plain.h)
    // Lays out and draws against the headless renderer (a no-op fill) without throwing.
    let card = Label("Bubble").padding(12.0).background(Color.rgb(230, 240, 255), corners: Corners.top(14.0))
    card.layout(ctx, Rect(0.0, 0.0, 200.0, 60.0))
    card.draw(ctx)
}

@Test
func styledBoxLayoutAndDrawWithoutError(): Unit {
    let ctx = testContext()
    // A full card stack — rounded background, matching shadow, and border — lays out and draws
    // against the headless renderer without throwing, and the shadow modifier keeps the frame.
    let card = Label("Card")
        .padding(16.0)
        .background(Color.rgb(255, 255, 255), 12.0)
        .shadow(Shadow.elevation(2), radius: 12.0)
        .border(Color.rgb(200, 200, 200), width: 1.0, radius: 12.0)
    let size = card.measure(ctx, Size(300.0, 200.0))
    @Expect(size.w > Float32(0.0))
    card.layout(ctx, Rect(0.0, 0.0, size.w, size.h))
    card.draw(ctx) // must not throw
}
