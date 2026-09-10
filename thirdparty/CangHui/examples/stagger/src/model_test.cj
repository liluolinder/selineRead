package chui_stagger

@Test
func staggerDelayScalesWithRowIndex(): Unit {
    // 行号 × 步进：首行不等，其后每行多等一个步进。
    @Expect(staggerDelay(0, 45), UInt64(0))
    @Expect(staggerDelay(1, 45), UInt64(45))
    @Expect(staggerDelay(3, 45), UInt64(135))
    // 步进为 0 即所有行同时入场（退化为无交错）。
    @Expect(staggerDelay(5, 0), UInt64(0))
    // 负步进/负行号按无交错处理，不产生负延迟。
    @Expect(staggerDelay(-2, 45), UInt64(0))
    @Expect(staggerDelay(3, -10), UInt64(0))
}

@Test
func cascadeTotalMsCoversLastRow(): Unit {
    // 整组耗时 = 末行等待 + 一行缓动：6 行 × 45ms 步进 + 260ms = 225 + 260。
    @Expect(cascadeTotalMs(6, 45, 260), 485)
    // 无交错时整组就是一行的时长（所有行并行）。
    @Expect(cascadeTotalMs(6, 0, 260), 260)
    // 单行没有交错可言。
    @Expect(cascadeTotalMs(1, 90, 260), 260)
    // 空列表耗时为零。
    @Expect(cascadeTotalMs(0, 45, 260), 0)
}

@Test
func modelStepFollowsSegmentAndClamps(): Unit {
    let model = StaggerModel()
    // 默认「轻交错」档。
    @Expect(model.step(), STAGGER_STEPS[1])
    model.stepIndex.value = 0
    @Expect(model.step(), 0)
    @Expect(model.delayFor(4), UInt64(0)) // 无交错档下所有行同时入场
    model.stepIndex.value = 2
    @Expect(model.step(), STAGGER_STEPS[2])
    @Expect(model.delayFor(2), UInt64(2 * STAGGER_STEPS[2]))
    // 越界档位钳回首档，不抛异常。
    model.stepIndex.value = 99
    @Expect(model.step(), STAGGER_STEPS[0])
}

@Test
func modelToggleFlipsShown(): Unit {
    let model = StaggerModel()
    // 默认展开，一进来就是入场后的样子（首帧静止，快照稳定）。
    @Expect(model.shown.value)
    model.toggle()
    @Expect(!model.shown.value)
    model.toggle()
    @Expect(model.shown.value)
}

@Test
func statusTextReportsCascadeShape(): Unit {
    let model = StaggerModel()
    model.stepIndex.value = 1
    // 有交错时报出步进与整组耗时。
    @Expect(model.statusText().contains("交错"))
    @Expect(model.statusText().contains("${model.totalMs()}"))
    // 无交错时改述为「同时入场」。
    model.stepIndex.value = 0
    @Expect(model.statusText().contains("同时入场"))
    @Expect(model.totalMs(), REVEAL_MS)
}
