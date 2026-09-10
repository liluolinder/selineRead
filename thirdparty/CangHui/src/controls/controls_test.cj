package chui.controls

import sdl.{FrameInfo, IconName, Key, MouseButton, Rect, Renderer, Size, UiEvent}
import chui.core.{Button, ComponentProbe, IconButton, ProbeProperty, SegmentedControlStyle, Spacer,
    State, StateStore, Theme, UiContext, VStack, Widget, buildRoot, emit}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func segmentedControlKeyboardSwitchesSegments(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let choice = State<Int64>(1)
    let captured = State<?Widget>(None)
    let _ = buildRoot({
        => captured.value = Some(SegmentedControl(["日", "周", "月"], choice))
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 1) // the control registered exactly one focus stop

    let control = captured.value.getOrThrow()
    control.layout(ctx, Rect(0.0, 0.0, 288.0, 34.0))
    @Expect(!control.handle(ctx, UiEvent.KeyDown(Key.Right, false))) // unfocused: not consumed
    @Expect(choice.value, Int64(1))

    ctx.focus(ring[0])
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(choice.value, Int64(2))
    let _ = control.handle(ctx, UiEvent.KeyDown(Key.Right, false))
    @Expect(choice.value, Int64(2)) // clamped at the last segment
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(choice.value, Int64(1))
}

// TabView's strip is a focus stop ahead of its page content: Left/Right switch tabs while
// the strip has focus and fall through to the active page otherwise.
@Test
func tabViewKeyboardSwitchesTabs(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let page = State<Int64>(0)
    let captured = State<?Widget>(None)
    let _ = buildRoot({
        =>
        captured.value = Some(TabView(["概览", "设置"], page) {
            Spacer()
            Spacer()
        })
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 1) // the strip registered exactly one focus stop

    let tabs = captured.value.getOrThrow()
    tabs.layout(ctx, Rect(0.0, 0.0, 400.0, 300.0))
    @Expect(!tabs.handle(ctx, UiEvent.KeyDown(Key.Right, false))) // unfocused: falls to the page
    @Expect(page.value, Int64(0))

    ctx.focus(ring[0])
    @Expect(tabs.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(page.value, Int64(1))
    @Expect(tabs.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(page.value, Int64(0))
}

// Focus stops on hidden tab pages are dead ends (only the active page receives events), so
// the build takes them out of the ring; switching tabs re-registers on the next rebuild.
@Test
func tabViewHiddenPageLeavesFocusRing(): Unit {
    let store = StateStore()
    let page = State<Int64>(0)
    let build = {
        =>
        let _ = buildRoot({
            =>
            let _ = TabView(["一", "二"], page) {
                Button("甲", {=> ()}).key("p1.a")
                Button("乙", {=> ()}).key("p2.a")
            }
        }, store)
    }
    build()
    let first = store.focusRing()
    @Expect(first.size, 2) // the strip plus the active page's button
    @Expect(first[1], "p1.a")

    page.value = 1
    build()
    let second = store.focusRing()
    @Expect(second.size, 2)
    @Expect(second[1], "p2.a")
}

@Test
func sliderMouseAndKeyboardEventsUpdateState(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(0.0)
    let slider = Slider(value, key: "volume", lower: 0.0, upper: 10.0)

    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0)))
    @Expect(value.value, Float32(5.0))
    @Expect(ctx.isDragging("volume"))

    ctx.leftMouseDown = true
    @Expect(slider.handle(ctx, UiEvent.MouseMove(108.0, 19.0)))
    @Expect(value.value, Float32(10.0))

    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(9.9))
}

@Test
func sliderStepSnapsToDiscreteMultiples(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(3.0)
    // step 2 over [0, 10]: the legal values are 0, 2, 4, 6, 8, 10. Construction snaps the initial 3.
    let slider = Slider(value, key: "vol", lower: 0.0, upper: 10.0, step: 2.0)
    @Expect(value.value, Float32(4.0))

    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    // The track spans x in [8, 108] (width 100). x=70 -> amount 0.62 -> raw 6.2, which snaps to 6.
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 70.0, 19.0)))
    @Expect(value.value, Float32(6.0))

    // Arrow keys move by exactly one increment, staying on the grid.
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(value.value, Float32(8.0))
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(6.0))
}

@Test
func sliderTrackClickStartsLocalInkAtAnyPosition(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(0.0)
    let slider = Slider(value, key: "slider.ink")
    slider.layout(ctx, Rect(20.0, 40.0, 180.0, 32.0))

    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 160.0, 56.0)))
    let ripple = sliderTrackFrame(Rect(20.0, 40.0, 180.0, 32.0))
    @Expect(ripple.x, Float32(28.0))
    @Expect(ripple.y, Float32(53.0))
    @Expect(ripple.w, Float32(164.0))
    @Expect(ripple.h, Float32(6.0))
    @Expect(sliderInkOriginX(ripple, 20.0), ripple.x)
    @Expect(sliderInkOriginX(ripple, 200.0), ripple.right())
}

@Test
func segmentedControlSelectsClickedSegment(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let control = SegmentedControl(["One", "Two", "Three"], selected)

    control.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 250.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func segmentedControlStyleDeformsStockIndicatorWithoutReplacingInput(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let paintedWidth = State<Float32>(0.0)
    let style = SegmentedControlStyle(
        deformation: 1.0,
        paintIndicator: {_, rect, _ => paintedWidth.value = rect.w},
        foreground: {theme, _ => theme.text}
    )
    let store = StateStore()
    let captured = State<?Widget>(None)
    let _ = buildRoot({=>
        captured.value = Some(SegmentedControl(["One", "Two", "Three"], selected)
            .indicatorStyle(style))
    }, store)
    let control = captured.value.getOrThrow()
    control.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    control.draw(ctx)
    @Expect(paintedWidth.value, 94.0)

    selected.value = 2
    ctx.frame = FrameInfo(UInt64(16), UInt64(16))
    control.draw(ctx)
    @Expect(paintedWidth.value > 94.0)
}

@Test
func switchActivatesOnReleaseAndSupportsKeyboard(): Unit {
    let ctx = controlTestContext()
    let checked = State<Bool>(false)
    let control = Switch("Notifications", checked).key("notifications")
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(!checked.value)
    @Expect(control.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(checked.value)
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(!checked.value)
}

@Test
func checkboxAndSwitchKeepLabelClicksInsideTheirLocalInkFrames(): Unit {
    let ctx = controlTestContext()
    let checked = State<Bool>(false)
    let checkbox = Checkbox("Long checkbox label", checked).key("checkbox.ink")
    checkbox.layout(ctx, Rect(20.0, 40.0, 220.0, 32.0))

    @Expect(checkbox.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 180.0, 56.0)))
    let checkInk = checkboxIndicatorFrame(Rect(20.0, 40.0, 220.0, 32.0))
    @Expect(checkInk.x, Float32(20.0))
    @Expect(checkInk.y, Float32(47.0))
    @Expect(checkInk.w, Float32(18.0))
    @Expect(checkInk.h, Float32(18.0))

    let enabled = State<Bool>(false)
    let toggle = Switch("Long switch label", enabled).key("switch.ink")
    toggle.layout(ctx, Rect(20.0, 80.0, 220.0, 32.0))
    @Expect(toggle.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 180.0, 96.0)))
    let switchInk = switchTrackFrame(Rect(20.0, 80.0, 220.0, 32.0))
    @Expect(switchInk.x, Float32(20.0))
    @Expect(switchInk.y, Float32(85.0))
    @Expect(switchInk.w, Float32(40.0))
    @Expect(switchInk.h, Float32(22.0))
}

@Test
func radioButtonsShareOneSelectionState(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(1)
    let control = RadioButton("Detailed", selected, 2)
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    let _ = control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0))
    let _ = control.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0))

    @Expect(selected.value, Int64(2))
}

@Test
func pickerWrapsSelectionAndRespondsToArrowKeys(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let picker = Picker(["Compact", "Comfortable", "Spacious"], selected, key: "density")
    picker.layout(ctx, Rect(0.0, 0.0, 190.0, 38.0))

    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 12.0)))
    @Expect(picker.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 8.0, 12.0)))
    @Expect(selected.value, Int64(2))
    @Expect(picker.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(selected.value, Int64(0))
}

@Test
func compactPickerKeepsPreviousAndNextHitZonesDistinct(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(1)
    let picker = Picker(["A", "B", "C"], selected, key: "compact-picker")
    picker.layout(ctx, Rect(0.0, 0.0, 50.0, 38.0))

    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 12.0)))
    @Expect(picker.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 12.0)))
    @Expect(selected.value, Int64(0))
    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 12.0)))
    @Expect(picker.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 40.0, 12.0)))
    @Expect(selected.value, Int64(1))
}

@Test
func stepperClampsRangeWithoutIntegerOverflow(): Unit {
    let ctx = controlTestContext()
    let value = State<Int64>(9)
    let stepper = Stepper(value, key: "quantity").range(0, 10).step(3)
    stepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))

    @Expect(stepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 136.0, 12.0)))
    @Expect(stepper.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 136.0, 12.0)))
    @Expect(value.value, Int64(10))
    @Expect(stepper.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Int64(7))
}

@Test
func compactStepperKeepsDecrementAndIncrementHitZonesDistinct(): Unit {
    let ctx = controlTestContext()
    let value = State<Int64>(5)
    let stepper = Stepper(value, key: "compact-stepper", lower: 0, upper: 10)
    stepper.layout(ctx, Rect(0.0, 0.0, 50.0, 38.0))

    @Expect(stepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 12.0)))
    @Expect(stepper.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 12.0)))
    @Expect(value.value, Int64(4))
    @Expect(stepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 12.0)))
    @Expect(stepper.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 40.0, 12.0)))
    @Expect(value.value, Int64(5))
}

// A range pressed against the Int64 extremes must not overflow when stepping: the guard saturates
// at the type bound before clamping to the range, so `lowerBound + step` / `upperBound - step` are
// never evaluated into an over/underflow.
@Test
func stepperStepsAtInt64ExtremesWithoutOverflow(): Unit {
    let ctx = controlTestContext()

    // Range crammed against Int64.Max: pressing decrement saturates at Int64.Min then clamps to the
    // floor, rather than evaluating `lowerBound + step` (= Int64.Max + 3) into an overflow.
    let high = State<Int64>(Int64.Max)
    let highStepper = Stepper(high, key: "high", lower: Int64.Max - 2, upper: Int64.Max, step: 5)
    highStepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))
    @Expect(highStepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 18.0, 12.0)))
    @Expect(highStepper.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 18.0, 12.0)))
    @Expect(high.value, Int64.Max - 2)

    // Range crammed against Int64.Min: pressing increment saturates at Int64.Max then clamps to the
    // ceiling, rather than evaluating `upperBound - step` (= Int64.Min - 3) into an underflow.
    let low = State<Int64>(Int64.Min)
    let lowStepper = Stepper(low, key: "low", lower: Int64.Min, upper: Int64.Min + 2, step: 5)
    lowStepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))
    @Expect(lowStepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 126.0, 12.0)))
    @Expect(lowStepper.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 126.0, 12.0)))
    @Expect(low.value, Int64.Min + 2)
}

@Test
func tabViewSelectsHeaderWithoutPages(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let tabs = TabView(["First", "Second"], selected) {}

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 120.0))
    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
}

@Test
func tabViewLaysOutIncomingPageOnSwitch(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let second = ControlLayoutProbe()
    let tabs = TabView(["A", "B"], selected) {
        Spacer()
        emit(second)
    }

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    @Expect(second.rect.h, Float32(0.0))

    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
    @Expect(second.rect.h > 0.0)
}

// Clicking a numeric column header sorts by value (not lexically); Home/End then select the
// smallest/largest row by that column, and the selection is stored as the original row index.
@Test
func stepperConstructorBoundsClampInitialValue(): Unit {
    let ctx = controlTestContext()
    let value = State<Int64>(200) // above the ctor upper bound
    let stepper = Stepper(value, key: "age", lower: 0, upper: 100, step: 5)
    stepper.layout(ctx, Rect(0.0, 0.0, 120.0, 32.0))
    @Expect(value.value, Int64(100)) // clamped into [0, 100] by the constructor
}

@Test
func primitiveControlsExposeStableHeadlessSemantics(): Unit {
    let enabled = State<Bool>(true)
    let mode = State<Int64>(2)
    let volume = State<Float32>(0.75)
    let density = State<Int64>(1)
    let quantity = State<Int64>(4)
    let report = ComponentProbe("test.primitive-control-semantics", width: 420.0, height: 300.0).run("") {
        VStack {
            IconButton(IconName.Save) {=> ()}
                .key("semantic-save")
                .accessibilityLabel("Save document")
            Switch("Notifications", enabled).key("semantic-switch")
            RadioButton("Detailed", mode, 2).key("semantic-radio")
                .accessibilityLabel("Detailed layout")
            Slider(volume, key: "semantic-slider").accessibilityLabel("Volume")
            Picker(["Compact", "Comfortable"], density, key: "semantic-picker")
                .accessibilityLabel("Density")
            Stepper(quantity, key: "semantic-stepper", lower: 0, upper: 10)
                .accessibilityLabel("Quantity")
        }
    }

    @Expect(report.contains("\"id\":\"control-semantic:semantic-save\""))
    @Expect(report.contains("\"label\":\"Save document\""))
    @Expect(report.contains("\"role\":\"switch\""))
    @Expect(report.contains("\"value\":\"on\""))
    @Expect(report.contains("\"label\":\"Detailed layout\""))
    @Expect(report.contains("\"selected\":\"true\""))
    @Expect(report.contains("\"label\":\"Volume\""))
    @Expect(report.contains("\"value\":\"0.750000\""))
    @Expect(report.contains("\"label\":\"Density\""))
    @Expect(report.contains("\"value\":\"Comfortable\""))
    @Expect(report.contains("\"label\":\"Quantity\""))
    @Expect(report.contains("\"shortcut\":\"Left|Right|Up|Down\""))

    let ascii = ComponentProbe("test.primitive-control-semantics-ascii", width: 240.0, height: 60.0)
        .run("@cui-ascii 60 12") {
            Slider(volume, key: "ascii-volume").accessibilityLabel("Volume")
        }
    @Expect(ascii.contains("Volume"))
    @Expect(ascii.contains("Slider.adjust()"))
    @Expect(ascii.contains("Left|Right"))
}

@Test
func explicitPrimitiveControlProbeKeepsSameOwnerPrecedence(): Unit {
    let report = ComponentProbe("test.explicit-primitive-probe", width: 120.0, height: 60.0).run("") {
        IconButton(IconName.Save) {=> ()}
            .key("explicit-icon")
            .accessibilityLabel("Save")
            .probe("explicit-icon", "IconButton", [
                ProbeProperty("role", "button"),
                ProbeProperty("label", "Explicit save"),
                ProbeProperty("action", "document.save()")
            ])
    }
    @Expect(report.contains("\"id\":\"explicit-icon\""))
    @Expect(report.contains("\"action\":\"document.save()\""))
    @Expect(!report.contains("control-semantic:explicit-icon"))
}

@Test
func compoundControlsExposeStableHeadlessSemantics(): Unit {
    let score = State<Int64>(3)
    let page = State<Int64>(1)
    let report = ComponentProbe("test.compound-control-semantics", width: 620.0, height: 300.0).run("") {
        VStack {
            Rating(score, count: 5, key: "semantic-rating").accessibilityLabel("Score")
            Breadcrumb(["Home", "Docs", "Project"], onSelect: {_ => ()}, key: "semantic-crumbs")
                .accessibilityLabel("Document path")
            Pagination(5, page, key: "semantic-pages").accessibilityLabel("Results")
            StepIndicator(["Account", "Configure", "Confirm"], 2, onSelect: {_ => ()}, key: "semantic-steps")
                .accessibilityLabel("Checkout")
        }
    }

    @Expect(report.contains("\"id\":\"control-semantic:semantic-rating\""))
    @Expect(report.contains("\"role\":\"rating\""))
    @Expect(report.contains("\"label\":\"Score\""))
    @Expect(report.contains("\"value\":\"3/5\""))
    @Expect(report.contains("\"shortcut\":\"Left|Down|Right|Up|Home|End\""))

    @Expect(report.contains("\"id\":\"control-semantic:semantic-crumbs\""))
    @Expect(report.contains("\"role\":\"breadcrumb\""))
    @Expect(report.contains("\"label\":\"Document path\""))
    @Expect(report.contains("\"value\":\"Project\""))
    @Expect(!report.contains("\"action\":\"Breadcrumb.navigate()\""))

    @Expect(report.contains("\"id\":\"control-semantic:semantic-pages\""))
    @Expect(report.contains("\"role\":\"pagination\""))
    @Expect(report.contains("\"label\":\"Results\""))
    @Expect(report.contains("\"value\":\"page 2 of 5\""))
    @Expect(!report.contains("\"action\":\"Pagination.setPage()\""))

    @Expect(report.contains("\"id\":\"control-semantic:semantic-steps\""))
    @Expect(report.contains("\"role\":\"stepindicator\""))
    @Expect(report.contains("\"label\":\"Checkout\""))
    @Expect(report.contains("\"value\":\"step 3 of 3\""))
    @Expect(!report.contains("\"action\":\"StepIndicator.select()\""))

    let ascii = ComponentProbe("test.compound-control-semantics-ascii", width: 360.0, height: 120.0)
        .run("@cui-ascii 60 20") {
            Rating(score, count: 5, key: "ascii-rating").accessibilityLabel("Score")
            StepIndicator(["Account", "Configure", "Confirm"], 2, key: "ascii-steps")
        }
    @Expect(ascii.contains("Score"))
    @Expect(ascii.contains("Rating.set()"))
    @Expect(!ascii.contains("StepIndicator.select()"))
}

@Test
func explicitCompoundControlProbeKeepsSameOwnerPrecedence(): Unit {
    let score = State<Int64>(2)
    let report = ComponentProbe("test.explicit-compound-probe", width: 160.0, height: 60.0).run("") {
        Rating(score, count: 5, key: "explicit-rating")
            .accessibilityLabel("Score")
            .probe("explicit-rating", "Rating", [
                ProbeProperty("role", "rating"),
                ProbeProperty("label", "Explicit score"),
                ProbeProperty("action", "score.set()")
            ])
    }
    @Expect(report.contains("\"id\":\"explicit-rating\""))
    @Expect(report.contains("\"action\":\"score.set()\""))
    @Expect(!report.contains("control-semantic:explicit-rating"))
}

@Test
func readonlyCompoundControlsExposeValueWithoutAction(): Unit {
    let score = State<Int64>(4)
    let report = ComponentProbe("test.readonly-compound-semantics", width: 420.0, height: 140.0).run("") {
        VStack {
            Rating(score, count: 5, readonly: true, key: "readonly-rating")
            StepIndicator(["Account", "Configure", "Confirm"], 1, key: "display-steps")
            Breadcrumb(["Home", "Docs", "Project"], key: "display-crumbs")
        }
    }
    @Expect(report.contains("\"id\":\"control-semantic:readonly-rating\""))
    @Expect(report.contains("\"role\":\"rating\""))
    @Expect(report.contains("\"value\":\"4/5\""))
    @Expect(!report.contains("\"action\":\"Rating.set()\""))

    @Expect(report.contains("\"id\":\"control-semantic:display-steps\""))
    @Expect(report.contains("\"value\":\"step 2 of 3\""))
    @Expect(!report.contains("\"action\":\"StepIndicator.select()\""))

    @Expect(report.contains("\"id\":\"control-semantic:display-crumbs\""))
    @Expect(report.contains("\"role\":\"breadcrumb\""))
    @Expect(!report.contains("\"action\":\"Breadcrumb.navigate()\""))
}

private class ControlLayoutProbe <: Widget {
    var rect = Rect.zero()

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
