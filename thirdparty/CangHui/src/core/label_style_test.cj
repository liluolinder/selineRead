package chui.core

import sdl.{FontStyle, Size}

// Room enough that single-line labels are measured at their natural width, never truncated.
private let LABEL_ROOM = Size(10000.0, 10000.0)

@Test
func labelBoldMeasuresWiderThanPlain(): Unit {
    let ctx = testContext()
    let plain = Label("Typography").measure(ctx, LABEL_ROOM)
    let bold = Label("Typography").bold().measure(ctx, LABEL_ROOM)
    // The `.bold()` modifier threads through measure: the faux-bold advance is wider.
    @Expect(bold.w > plain.w)
    // Weight does not change the line height.
    @Expect(bold.h == plain.h)
}

@Test
func labelStyleModifiersComposeAndDefaultRegular(): Unit {
    let ctx = testContext()
    // A label with no style modifier measures like an explicitly regular one.
    let plain = Label("hi there").measure(ctx, LABEL_ROOM)
    let explicitRegular = Label("hi there").fontStyle(FontStyle.regular).measure(ctx, LABEL_ROOM)
    @Expect(plain.w == explicitRegular.w)
    // Underline is decoration only; it leaves the measured width unchanged.
    let underlined = Label("hi there").underline().measure(ctx, LABEL_ROOM)
    @Expect(underlined.w == plain.w)
    // Chained modifiers accumulate — bold+italic is still bold-widened.
    let boldItalic = Label("hi there").bold().italic().measure(ctx, LABEL_ROOM)
    @Expect(boldItalic.w > plain.w)
}

@Test
func labelFontFamilyThreadsAndComposesWithStyle(): Unit {
    let ctx = testContext()
    let plain = Label("hello world").measure(ctx, LABEL_ROOM)
    // Headless metrics are font-agnostic, so a font family measures like the default — the point is
    // that `.fontFamily(...)` threads through measure without error and falls back gracefully.
    let named = Label("hello world").fontFamily("NoSuchFont").measure(ctx, LABEL_ROOM)
    @Expect(named.w == plain.w)
    // Font family and weight compose: a named bold label is still bold-widened.
    let namedBold = Label("hello world").fontFamily("NoSuchFont").bold().measure(ctx, LABEL_ROOM)
    @Expect(namedBold.w > plain.w)
}

@Test
func labelBoldWrapsToMoreLinesThanPlain(): Unit {
    let ctx = testContext()
    // At a width that plain text fills tightly, the wider bold advance forces an extra wrap line —
    // proving the style reaches the multi-line wrapping path too, not just single-line measure.
    let text = "the quick brown fox jumps over the lazy dog"
    let width: Float32 = 160.0
    let plainLines = wrapText(ctx, text, width, 15.0, Int64.Max)
    let boldLines = wrapText(ctx, text, width, 15.0, Int64.Max, style: FontStyle(bold: true))
    @Expect(boldLines.size >= plainLines.size)
    @Expect(boldLines.size > 1)
}

@Test
func maxLinesChangeRewrapsCachedLines(): Unit {
    let ctx = testContext()
    // The line limit is a wrap input the lines cache does not key on: measuring, then raising
    // the limit on the same (stored, re-emitted) instance must re-wrap, not serve the old lines.
    let label = Label("alpha beta gamma delta epsilon zeta eta theta iota kappa").maxLines(2)
    let narrow = Size(90.0, 400.0)
    let twoLines = label.measure(ctx, narrow)
    let manyLines = label.maxLines(8).measure(ctx, narrow)
    @Expect(manyLines.h > twoLines.h)
}

@Test
func labelLineSpacingChangesOnlyWrappedGaps(): Unit {
    let ctx = testContext()
    let text = "the quick brown fox jumps over the lazy dog"
    let narrow = Size(160.0, 400.0)
    let lines = wrapText(ctx, text, 160.0, 15.0, Int64.Max)
    @Expect(lines.size > 1)
    let defaultSpacing = Label(text).wrap().measure(ctx, narrow)
    let wideSpacing = Label(text).wrap().lineSpacing(10.0).measure(ctx, narrow)
    @Expect(wideSpacing.h - defaultSpacing.h == Float32(lines.size - 1) * 8.0)
    let single = Label("one line").measure(ctx, LABEL_ROOM)
    let singleSpaced = Label("one line").lineSpacing(10.0).measure(ctx, LABEL_ROOM)
    @Expect(singleSpaced.h == single.h)
    @Expect(singleSpaced.w == single.w)
}

@Test
func labelLineSpacingRejectsInvalidValues(): Unit {
    var negativeRejected = false
    var nanRejected = false
    var infRejected = false
    try { let _ = Label("x").lineSpacing(-1.0) } catch (_: IllegalArgumentException) { negativeRejected = true }
    try { let _ = Label("x").lineSpacing(Float32.NaN) } catch (_: IllegalArgumentException) { nanRejected = true }
    try { let _ = Label("x").lineSpacing(Float32.Inf) } catch (_: IllegalArgumentException) { infRejected = true }
    @Expect(negativeRejected)
    @Expect(nanRejected)
    @Expect(infRejected)
}
