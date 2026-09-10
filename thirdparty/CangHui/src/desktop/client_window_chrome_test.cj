package chui.desktop

import sdl.Rect

@Test
func clientChromeGeometrySupportsLeadingTrailingAndHiddenOverrides(): Unit {
    let frame = Rect(0.0, 0.0, 800.0, 600.0)
    let leading = ClientWindowChromeStyle(placement: WindowChromePlacement.Leading)
    let trailing = ClientWindowChromeStyle(placement: WindowChromePlacement.Trailing)
    let hidden = ClientWindowChromeStyle(placement: WindowChromePlacement.Hidden)

    @Expect(leading.controlRect(frame, WindowChromeControl.Close).x <
        leading.controlRect(frame, WindowChromeControl.Minimize).x)
    @Expect(trailing.controlRect(frame, WindowChromeControl.Close).x >
        trailing.controlRect(frame, WindowChromeControl.Minimize).x)
    @Expect(leading.contentFrame(frame).y, leading.height)
    @Expect(hidden.contentFrame(frame).y, Float32(0.0))
    @Expect(hidden.contentFrame(frame).h, frame.h)
}

@Test
func clientChromeDragRegionExcludesWindowControlButtons(): Unit {
    let frame = Rect(0.0, 0.0, 800.0, 600.0)
    let style = ClientWindowChromeStyle(placement: WindowChromePlacement.Trailing)
    let close = style.controlRect(frame, WindowChromeControl.Close)

    @Expect(style.isDragRegion(frame, 200.0, 12.0))
    @Expect(!style.isDragRegion(frame, close.centerX(), close.centerY()))
    match (style.controlAt(frame, close.centerX(), close.centerY())) {
        case Some(WindowChromeControl.Close) => @Expect(true)
        case _ => @Fail("Close control should win hit testing over the drag region.")
    }
}

@Test
func clientChromeControlPressStaysCancelledAfterMoveOutAndReentry(): Unit {
    let press = ClientWindowChromePressState()
    press.begin(WindowChromeControl.Close)
    @Expect(press.isHeld(WindowChromeControl.Close))

    press.move(None)
    @Expect(!press.isHeld(WindowChromeControl.Close))
    press.move(Some(WindowChromeControl.Close))
    @Expect(!press.isHeld(WindowChromeControl.Close))
    @Expect(press.release(Some(WindowChromeControl.Close)).isNone())
    @Expect(!press.isActive())

    press.begin(WindowChromeControl.Close)
    match (press.release(Some(WindowChromeControl.Close))) {
        case Some(WindowChromeControl.Close) => @Expect(true)
        case _ => @Fail("A fresh release-inside gesture should activate the control.")
    }
}
