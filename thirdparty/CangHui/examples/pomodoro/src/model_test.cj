package chui_pomodoro

@Test
func clockFormatsAndCeils(): Unit {
    // 起步显示整分；不足一秒向上取整；零与负值钳到 00:00。
    @Expect(formatClock(25 * 60_000), "25:00")
    @Expect(formatClock(61_000), "01:01")
    @Expect(formatClock(60_001), "01:01")
    @Expect(formatClock(999), "00:01")
    @Expect(formatClock(0), "00:00")
    @Expect(formatClock(-50), "00:00")
}

@Test
func initialStateIsIdleFocus(): Unit {
    let model = newPomodoroModel()
    @Expect(!model.running.value)
    @Expect(!model.inBreak.value)
    @Expect(model.remainingMs.value, 25 * 60_000)
    @Expect(model.completed.value, 0)
    // 满段起点占比为 1。
    @Expect(model.fraction() > 0.999)
}

@Test
func tickOnlyRunsWhenStarted(): Unit {
    let model = newPomodoroModel()
    // 停表时 tick 不动。
    model.tick(1000)
    @Expect(model.remainingMs.value, 25 * 60_000)
    // 开表后按增量扣减。
    model.toggleRun()
    model.tick(1000)
    @Expect(model.remainingMs.value, 25 * 60_000 - 1000)
}

@Test
func phaseAdvancesAndCountsOnZero(): Unit {
    let model = newPomodoroModel()
    model.toggleRun()
    // 一口气扣穿整段：进入休息、计一个番茄、按休息时长重新起段。
    model.tick(25 * 60_000 + 500)
    @Expect(model.inBreak.value)
    @Expect(model.completed.value, 1)
    @Expect(model.remainingMs.value, 5 * 60_000)
    // 休息扣穿回到专注，不再计数。
    model.tick(5 * 60_000 + 1)
    @Expect(!model.inBreak.value)
    @Expect(model.completed.value, 1)
    @Expect(model.remainingMs.value, 25 * 60_000)
}

@Test
func skipSwitchesPhaseWithoutCounting(): Unit {
    let model = newPomodoroModel()
    model.skip()
    @Expect(model.inBreak.value)
    @Expect(model.completed.value, 0)
    @Expect(model.remainingMs.value, 5 * 60_000)
    model.skip()
    @Expect(!model.inBreak.value)
    @Expect(model.remainingMs.value, 25 * 60_000)
}

@Test
func resetReturnsToFreshFocus(): Unit {
    let model = newPomodoroModel()
    model.toggleRun()
    model.tick(3 * 60_000)
    model.skip()
    model.reset()
    @Expect(!model.running.value)
    @Expect(!model.inBreak.value)
    @Expect(model.remainingMs.value, 25 * 60_000)
}

@Test
func idleDurationChangeRetimesPhaseStart(): Unit {
    let model = newPomodoroModel()
    // 停表且停在专注段起点：改专注时长即重排剩余时间。
    model.focusMinutes.value = 30
    @Expect(model.remainingMs.value, 30 * 60_000)
    // 运行中改动不打断当前段。
    model.toggleRun()
    model.tick(1000)
    model.focusMinutes.value = 40
    @Expect(model.remainingMs.value, 30 * 60_000 - 1000)
}
