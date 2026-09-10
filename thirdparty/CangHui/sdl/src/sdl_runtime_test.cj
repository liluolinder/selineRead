package sdl

private class RuntimeGateCounter {
    var starts: Int64 = 0
    var stops: Int64 = 0

    func start(): Bool { starts += 1; true }
    func failStart(): Bool { starts += 1; false }
    func stop(): Unit { stops += 1 }
}

@Test
func sdlRuntimeGateStartsFirstAndStopsLast(): Unit {
    let counter = RuntimeGateCounter()
    let gate = SdlRuntimeGate()
    @Expect(gate.acquire(UInt64(7), { => counter.start() }))
    @Expect(gate.acquire(UInt64(7), { => counter.start() }))
    @Expect(counter.starts, Int64(1))
    @Expect(gate.referenceCount(), Int64(2))
    @Expect(gate.release(UInt64(7), { => counter.stop() }))
    @Expect(counter.stops, Int64(0))
    @Expect(gate.release(UInt64(7), { => counter.stop() }))
    @Expect(counter.stops, Int64(1))
}

@Test
func sdlRuntimeGateRejectsCrossThreadAndFailedStart(): Unit {
    let counter = RuntimeGateCounter()
    let gate = SdlRuntimeGate()
    @Expect(!gate.acquire(UInt64(3), { => counter.failStart() }))
    @Expect(gate.referenceCount(), Int64(0))
    @Expect(gate.acquire(UInt64(3), { => counter.start() }))
    @Expect(!gate.acquire(UInt64(4), { => counter.start() }))
    @Expect(!gate.release(UInt64(4), { => counter.stop() }))
    @Expect(gate.referenceCount(), Int64(1))
    @Expect(gate.release(UInt64(3), { => counter.stop() }))
}
