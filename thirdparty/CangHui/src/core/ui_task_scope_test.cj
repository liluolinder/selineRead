package chui.core

import std.sync.{AtomicBool, AtomicInt64}

private func waitForUiTask(condition: () -> Bool): Unit {
    var remaining: Int64 = 5000
    while (!condition() && remaining > 0) {
        sleep(Duration.millisecond)
        remaining -= 1
    }
    @Expect(condition())
}

@Test
func uiTaskScopeLatestOnlyCommitsOnlyNewestPreparedValue(): Unit {
    let queue = UiOwnerQueue()
    let scope = UiTaskScope("search", queue, policy: UiTaskPolicy.LatestOnly)
    let releaseFirst = AtomicBool(false)
    let applied = AtomicInt64(0)
    let first = scope.submit({=>
        while (!releaseFirst.load()) { sleep(Duration.millisecond) }
        Int64(1)
    }, {value => applied.store(value)})
    let second = scope.submit({=> Int64(2)}, {value => applied.store(value)})
    releaseFirst.store(true)
    waitForUiTask({=> queue.hasPending()})
    let _ = queue.drain()

    @Expect(applied.load(), 2)
    @Expect(first.status() == UiTaskSubmissionStatus.Cancelled)
    @Expect(second.status() == UiTaskSubmissionStatus.Committed)
}

@Test
func uiTaskScopeSingleFlightAndQueuePoliciesAreBounded(): Unit {
    let queue = UiOwnerQueue()
    let single = UiTaskScope("single", queue, policy: UiTaskPolicy.SingleFlight)
    let release = AtomicBool(false)
    let first = single.submit({=>
        while (!release.load()) { sleep(Duration.millisecond) }
        Int64(1)
    }, {_ => ()})
    let rejected = single.submit({=> Int64(2)}, {_ => ()})
    @Expect(rejected.status() == UiTaskSubmissionStatus.RejectedCapacity)
    release.store(true)
    waitForUiTask({=> queue.hasPending()})
    let _ = queue.drain()
    @Expect(first.status() == UiTaskSubmissionStatus.Committed)

    let bounded = UiTaskScope("bounded", queue, policy: UiTaskPolicy.Queue(1))
    let queued = bounded.submit({=> Int64(3)}, {_ => ()})
    let overflow = bounded.submit({=> Int64(4)}, {_ => ()})
    @Expect(overflow.status() == UiTaskSubmissionStatus.RejectedCapacity)
    waitForUiTask({=> queue.hasPending()})
    let _ = queue.drain()
    @Expect(queued.status() == UiTaskSubmissionStatus.Committed)
}

@Test
func uiTaskScopeDebounceCloseAndPreparationFailureAreIsolated(): Unit {
    let queue = UiOwnerQueue()
    let scope = UiTaskScope("filter", queue, policy: UiTaskPolicy.Debounce(UInt64(10)))
    let applied = AtomicInt64(0)
    let old = scope.submit({=> Int64(1)}, {value => applied.store(value)})
    let newest = scope.submit({=> Int64(2)}, {value => applied.store(value)})
    waitForUiTask({=> queue.hasPending()})
    let _ = queue.drain()
    @Expect(old.status() == UiTaskSubmissionStatus.Cancelled)
    @Expect(newest.status() == UiTaskSubmissionStatus.Committed)
    @Expect(applied.load(), 2)

    let failureScope = UiTaskScope("failure", queue)
    let failed = failureScope.submit<Int64>({=> throw IllegalStateException("worker failed")}, {_ => ()})
    waitForUiTask({=> failed.status() == UiTaskSubmissionStatus.FailedPreparation})
    @Expect(failed.message(), "worker failed")
    let healthy = failureScope.submit({=> Int64(9)}, {value => applied.store(value)})
    waitForUiTask({=> queue.hasPending()})
    let _ = queue.drain()
    @Expect(healthy.status() == UiTaskSubmissionStatus.Committed)
    @Expect(applied.load(), 9)

    failureScope.close()
    let rejected = failureScope.submit({=> Int64(10)}, {_ => ()})
    @Expect(rejected.status() == UiTaskSubmissionStatus.RejectedClosed)
}

@Test
func uiTaskScopeReusesOwnerSurfaceAndEpochReceipts(): Unit {
    let queue = UiOwnerQueue()
    queue.setSurfaceGeneration(Some(4))
    let scope = UiTaskScope("surface", queue, policy: UiTaskPolicy.Queue(2))
    let stale = scope.submit({=> Int64(1)}, {_ => ()}, surfaceGeneration: Some(3))
    let current = scope.submit({=> Int64(2)}, {_ => ()}, baseEpoch: Some(UInt64(0)),
        surfaceGeneration: Some(4))
    waitForUiTask({=> queue.pendingCount() == 2})
    let _ = queue.drain()
    @Expect(stale.status() == UiTaskSubmissionStatus.RejectedStaleOwner)
    @Expect(current.status() == UiTaskSubmissionStatus.Committed)
    @Expect(stale.ownerReceipt().isSome())
}

@Test
func uiTaskScopeCloseRacePreventsLateOwnerApply(): Unit {
    let queue = UiOwnerQueue()
    let scope = UiTaskScope("closing", queue, policy: UiTaskPolicy.SingleFlight)
    let release = AtomicBool(false)
    let applied = AtomicInt64(0)
    let task = scope.submit({=>
        while (!release.load()) { sleep(Duration.millisecond) }
        Int64(1)
    }, {value => applied.store(value)})
    scope.close()
    release.store(true)
    waitForUiTask({=> task.status() == UiTaskSubmissionStatus.Cancelled})
    @Expect(!queue.hasPending())
    @Expect(applied.load(), 0)
}

@Test
func uiTaskScopeFailedApplyAndStaleEpochDoNotPoisonLaterWork(): Unit {
    let queue = UiOwnerQueue()
    let scope = UiTaskScope("apply", queue, policy: UiTaskPolicy.Queue(3))
    let failed = scope.submit<Int64>({=> Int64(1)},
        {_ => throw IllegalStateException("apply failed")})
    waitForUiTask({=> queue.hasPending()})
    let _ = queue.drain()
    @Expect(failed.status() == UiTaskSubmissionStatus.FailedApply)

    let stale = scope.submit({=> Int64(2)}, {_ => ()}, baseEpoch: Some(UInt64(0)))
    let healthy = scope.submit({=> Int64(3)}, {_ => ()}, baseEpoch: Some(queue.currentEpoch()))
    waitForUiTask({=> queue.pendingCount() == 2})
    let _ = queue.drain()
    @Expect(stale.status() == UiTaskSubmissionStatus.RejectedStaleOwner)
    @Expect(healthy.status() == UiTaskSubmissionStatus.Committed)
}
