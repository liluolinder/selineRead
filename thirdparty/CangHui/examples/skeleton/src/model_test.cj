package chui_skeleton

import chui.{Easing, Pulse}

@Test
func toggleSwapsLoadedStateAndCopy(): Unit {
    let model = SkeletonModel()
    @Expect(!model.loaded.value)
    @Expect(model.buttonLabel(), "加载完成")
    model.toggle()
    @Expect(model.loaded.value)
    @Expect(model.buttonLabel(), "重新加载")
    @Expect(model.statusText().contains("就位"))
    model.toggle()
    @Expect(!model.loaded.value)
}

@Test
func skeletonMirrorsArticleCount(): Unit {
    // 骨架行数与文章数一致，切换前后列表高度不跳。
    @Expect(skeletonRows(), ARTICLES.size)
    @Expect(ARTICLES.size > 0)
}

@Test
func barFractionsAlternateAndStayInUnit(): Unit {
    // 长短交错：偶数行标题条更长；比例均在 (0, 1]。
    @Expect(titleFraction(0) > titleFraction(1))
    @Expect(lineFraction(0) > lineFraction(1))
    for (row in 0..6) {
        @Expect(titleFraction(row) > 0.0 && titleFraction(row) <= 1.0)
        @Expect(lineFraction(row) > 0.0 && lineFraction(row) <= 1.0)
    }
    // 摘要条整体长于标题条（视觉上更像正文）。
    @Expect(lineFraction(0) > titleFraction(0))
    @Expect(lineFraction(1) > titleFraction(1))
}

@Test
func pulseBreathesAsConfigured(): Unit {
    // 与模型同参的脉冲：半个周期到峰值、一个周期回到起点（跨包直接使用公开 Pulse API）。
    let pulse = Pulse(period: 900, autoreverse: true, easing: Easing.Linear)
    pulse.tick(UInt64(450))
    @Expect(pulse.value > Float32(0.49) && pulse.value < Float32(0.51))
    pulse.tick(UInt64(450))
    @Expect(pulse.value > Float32(0.99))
    pulse.tick(UInt64(900))
    @Expect(pulse.value < Float32(0.01))
}
