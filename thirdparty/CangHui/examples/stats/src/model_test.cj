package chui_stats

@Test
func deltaTextSignsThePercent(): Unit {
    @Expect(deltaText(12), "+12%")
    @Expect(deltaText(0), "+0%")
    @Expect(deltaText(-8), "-8%")
}

@Test
func deltaIsGoodRespectsDirection(): Unit {
    // Up on a higher-is-better metric is good; down is bad.
    @Expect(deltaIsGood(Stat("A", 10, "x", 5)))
    @Expect(!deltaIsGood(Stat("A", 10, "x", -5)))
    // On a lower-is-better metric (latency), a drop is good and a rise is bad.
    @Expect(deltaIsGood(Stat("Latency", 40, "ms", -8, goodWhenUp: false)))
    @Expect(!deltaIsGood(Stat("Latency", 40, "ms", 8, goodWhenUp: false)))
}

@Test
func statsForSelectsPeriodDataset(): Unit {
    @Expect(statsFor(0).size, 4)
    @Expect(statsFor(0)[0].name, "活跃用户")
    // Different periods carry different values for the same metric.
    @Expect(statsFor(0)[0].value != statsFor(2)[0].value)
    @Expect(PERIOD_LABELS.size, 3)
    // Out-of-range period falls back to the last dataset (month).
    @Expect(statsFor(99)[0].value, statsFor(2)[0].value)
}

@Test
func modelStatsFollowPeriod(): Unit {
    let model = StatsModel()
    @Expect(model.stats()[0].value, TODAY[0].value)
    model.period.value = 1
    @Expect(model.stats()[0].value, WEEK[0].value)
}
