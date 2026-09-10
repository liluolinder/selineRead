package chui.core

import sdl.{IconName, Rect, Size}

@Test
func rowLayoutWeightPinsTrailingContentAndUsesDeclaredSpace(): Unit {
    let ctx = testContext()
    let leading = SizedLayoutProbe(Size(20.0, 20.0))
    let content = SizedLayoutProbe(Size(80.0, 16.0))
    let trailing = SizedLayoutProbe(Size(40.0, 18.0))
    let row = Row(space: 8.vp) {
        emit(leading)
        content.layoutWeight()
        emit(trailing)
    }

    row.layout(ctx, Rect(12.0, 8.0, 276.0, 28.0))
    @Expect(leading.rect.x, Float32(12.0))
    @Expect(leading.rect.y, Float32(12.0))
    @Expect(leading.rect.w, Float32(20.0))
    @Expect(content.rect.x, Float32(40.0))
    @Expect(content.rect.y, Float32(14.0))
    @Expect(content.rect.w, Float32(200.0))
    @Expect(trailing.rect.x, Float32(248.0))
    @Expect(trailing.rect.y, Float32(13.0))
    @Expect(trailing.rect.right(), Float32(288.0))
}

@Test
func rowJustifyContentAndAlignItemsUseGeneralContainerPolicy(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(20.0, 10.0))
    let second = SizedLayoutProbe(Size(30.0, 20.0))
    let row = Row {
        emit(first)
        emit(second)
    }.justifyContent(MainAxisAlignment.SpaceBetween)
        .alignItems(CrossAxisAlignment.End)

    row.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    @Expect(first.rect.x, Float32(0.0))
    @Expect(first.rect.y, Float32(30.0))
    @Expect(second.rect.x, Float32(90.0))
    @Expect(second.rect.y, Float32(20.0))
}

@Test
func buttonsKeepIntrinsicHeightInTallHorizontalRows(): Unit {
    let ctx = testContext()
    let slot = SizedLayoutProbe(Size(50.0, 18.0))
    let button = Button(onClick: {=> ()}) {
        emit(slot)
    }
    let row = Row {
        emit(button)
    }

    row.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))

    @Expect(slot.rect.h, Float32(38.0))
    @Expect(!button.acceptsStretch(Axis.Vertical))
    @Expect(button.acceptsStretch(Axis.Horizontal))
}

@Test
func explicitFillHeightStillOverridesButtonIntrinsicHeight(): Unit {
    let ctx = testContext()
    let slot = SizedLayoutProbe(Size(50.0, 18.0))
    let button = Button(onClick: {=> ()}) {
        emit(slot)
    }
    let row = Row {
        emit(button)
        button.fillHeight()
    }

    row.layout(ctx, Rect(0.0, 0.0, 240.0, 72.0))

    @Expect(slot.rect.h, Float32(72.0))
}

@Test
func iconButtonKeepsIntrinsicVerticalStretchPolicy(): Unit {
    let button = IconButton(IconName.Save, onClick: {=> ()})
    @Expect(!button.acceptsStretch(Axis.Vertical))
    @Expect(button.acceptsStretch(Axis.Horizontal))
}
