package chui.core

import std.collection.ArrayList
import std.sync.{AtomicBool, AtomicInt64}
private func requireOwnerReceipt(ticket: UiOwnerTicket): UiOwnerReceipt {
    match (ticket.receipt()) {
        case Some(receipt) => receipt
        case None => throw IllegalStateException("expected UI owner receipt")
    }
}

@Test
func uiOwnerQueueRunsTasksInTicketOrder(): Unit {
    let queue = UiOwnerQueue()
    let values = ArrayList<Int64>()
    let first = queue.post({=> values.add(1)}, topologyHash: "tree-a")
    let second = queue.post({=> values.add(2)}, topologyHash: "tree-b")
    let third = queue.post({=> values.add(3)}, topologyHash: "tree-c")

    let receipts = queue.drain()
    @Expect(values.toArray(), [1, 2, 3])
    @Expect(receipts.size, 3)
    @Expect(first.sequence < second.sequence && second.sequence < third.sequence)
    @Expect(requireOwnerReceipt(first).status == UiOwnerTaskStatus.Committed)
    @Expect(requireOwnerReceipt(third).ownerEpoch, UInt64(3))
    @Expect(requireOwnerReceipt(second).topologyHash, "tree-b")
}

@Test
func uiOwnerQueueSerializesConcurrentProducers(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    let futures = ArrayList<Future<Unit>>()
    for (_ in 0..64) {
        futures.add(spawn {
            let _ = queue.post({=> let _ = applied.fetchAdd(1)})
        })
    }
    for (future in futures) {
        future.get()
    }

    let receipts = queue.drain()
    @Expect(receipts.size, 64)
    @Expect(applied.load(), 64)
    for (i in 1..receipts.size) {
        @Expect(receipts[i - 1].sequence < receipts[i].sequence)
        @Expect(receipts[i].status == UiOwnerTaskStatus.Committed)
    }
}

@Test
func uiOwnerQueueRejectsStaleEpochAndSurfaceWork(): Unit {
    let queue = UiOwnerQueue()
    queue.setSurfaceGeneration(Some(7))
    let applied = AtomicInt64(0)
    let first = queue.post({=> let _ = applied.fetchAdd(1)}, baseEpoch: Some(UInt64(0)),
        surfaceGeneration: Some(7))
    let staleEpoch = queue.post({=> let _ = applied.fetchAdd(1)}, baseEpoch: Some(UInt64(0)),
        surfaceGeneration: Some(7))
    let staleSurface = queue.post({=> let _ = applied.fetchAdd(1)}, surfaceGeneration: Some(6))

    let receipts = queue.drain()
    @Expect(receipts.size, 3)
    @Expect(applied.load(), 1)
    @Expect(requireOwnerReceipt(first).status == UiOwnerTaskStatus.Committed)
    @Expect(requireOwnerReceipt(staleEpoch).status == UiOwnerTaskStatus.RejectedStaleEpoch)
    @Expect(requireOwnerReceipt(staleSurface).status == UiOwnerTaskStatus.RejectedSurfaceGeneration)
    @Expect(queue.currentEpoch(), UInt64(1))
}

@Test
func uiOwnerQueueCancellationPreventsExecution(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    let ticket = queue.post({=> let _ = applied.fetchAdd(1)})
    @Expect(ticket.cancel())
    @Expect(!ticket.cancel())

    let receipts = queue.drain()
    @Expect(receipts.size, 1)
    @Expect(applied.load(), 0)
    @Expect(requireOwnerReceipt(ticket).status == UiOwnerTaskStatus.Cancelled)
    @Expect(queue.currentEpoch(), UInt64(0))
    @Expect(!ticket.cancel())
}

@Test
func uiOwnerQueueCannotCancelAfterOwnerClaimsExecution(): Unit {
    let queue = UiOwnerQueue()
    let started = AtomicBool(false)
    let release = AtomicBool(false)
    let ticket = queue.post({=>
        started.store(true)
        while (!release.load()) {
            sleep(Duration.millisecond)
        }
    })
    let future = spawn {
        let _ = queue.drain()
    }
    while (!started.load()) {
        sleep(Duration.millisecond)
    }

    @Expect(!ticket.cancel())
    release.store(true)
    future.get()
    @Expect(requireOwnerReceipt(ticket).status == UiOwnerTaskStatus.Committed)
}

@Test
func uiOwnerQueueFailureAdvancesEpochAndDoesNotStopLaterWork(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    let failed = queue.post({=> throw IllegalStateException("commit failed")},
        baseEpoch: Some(UInt64(0)))
    let afterFailure = queue.post({=> let _ = applied.fetchAdd(1)}, baseEpoch: Some(UInt64(1)))

    let receipts = queue.drain()
    @Expect(receipts.size, 2)
    @Expect(requireOwnerReceipt(failed).status == UiOwnerTaskStatus.Failed)
    @Expect(requireOwnerReceipt(failed).ownerEpoch, UInt64(1))
    @Expect(requireOwnerReceipt(failed).message, "commit failed")
    @Expect(requireOwnerReceipt(afterFailure).status == UiOwnerTaskStatus.Committed)
    @Expect(applied.load(), 1)
    @Expect(queue.currentEpoch(), UInt64(2))
}

@Test
func uiOwnerQueueDefersReentrantPostsToNextDrain(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    let outer = queue.post({=>
        let _ = applied.fetchAdd(1)
        let base = queue.currentEpoch()
        let _ = queue.post({=> let _ = applied.fetchAdd(1)}, baseEpoch: Some(base))
    })

    let first = queue.drain()
    @Expect(first.size, 1)
    @Expect(applied.load(), 1)
    @Expect(queue.hasPending())
    @Expect(requireOwnerReceipt(outer).status == UiOwnerTaskStatus.Committed)

    let second = queue.drain()
    @Expect(second.size, 1)
    @Expect(applied.load(), 2)
    @Expect(!queue.hasPending())
}

@Test
func uiOwnerQueueWakeIsBestEffortAndDrainIsBounded(): Unit {
    let wakeCount = AtomicInt64(0)
    let queue = UiOwnerQueue(wake: {=> let _ = wakeCount.fetchAdd(1)})
    let applied = AtomicInt64(0)
    for (_ in 0..3) {
        let _ = queue.post({=> let _ = applied.fetchAdd(1)})
    }
    @Expect(wakeCount.load(), 3)

    @Expect(queue.drain(maxTasks: 2).size, 2)
    @Expect(applied.load(), 2)
    @Expect(queue.pendingCount(), 1)
    @Expect(queue.drain().size, 1)
    @Expect(applied.load(), 3)
}

@Test
func uiOwnerQueueWakeFailureDoesNotLosePostedWork(): Unit {
    let queue = UiOwnerQueue(wake: {=>
        throw IllegalStateException("wake failed")
    })
    let applied = AtomicInt64(0)

    let ticket = queue.post({=> let _ = applied.fetchAdd(1)})
    @Expect(ticket.receipt().isNone())
    @Expect(queue.drain().size, 1)
    @Expect(applied.load(), 1)
    @Expect(requireOwnerReceipt(ticket).status == UiOwnerTaskStatus.Committed)
}

@Test
func uiOwnerQueueRejectsInvalidGenerationAndDrainLimit(): Unit {
    let queue = UiOwnerQueue()
    var generationRejected = false
    var limitRejected = false
    try {
        let _ = queue.post({=> ()}, surfaceGeneration: Some(-1))
    } catch (_: IllegalArgumentException) {
        generationRejected = true
    }
    try {
        let _ = queue.drain(maxTasks: 0)
    } catch (_: IllegalArgumentException) {
        limitRejected = true
    }
    @Expect(generationRejected)
    @Expect(limitRejected)
}

@Test
func uiOwnerQueueCloseResolvesPendingAndFuturePosts(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    let pending = queue.post({=> let _ = applied.fetchAdd(1)}, topologyHash: "before-close")

    let receipts = queue.close(reason: "owner stopped")
    @Expect(receipts.size, 1)
    @Expect(queue.isClosed())
    @Expect(!queue.hasPending())
    @Expect(applied.load(), 0)
    @Expect(requireOwnerReceipt(pending).status == UiOwnerTaskStatus.Cancelled)
    @Expect(requireOwnerReceipt(pending).message, "owner stopped")

    let rejected = queue.post({=> let _ = applied.fetchAdd(1)}, topologyHash: "after-close")
    @Expect(requireOwnerReceipt(rejected).status == UiOwnerTaskStatus.RejectedClosed)
    @Expect(requireOwnerReceipt(rejected).ownerEpoch, UInt64(0))
    @Expect(requireOwnerReceipt(rejected).message, "owner stopped")
    @Expect(applied.load(), 0)
    @Expect(!rejected.cancel())

    @Expect(queue.close(reason: "later close").isEmpty())
    let stillRejected = queue.post({=> ()})
    @Expect(requireOwnerReceipt(stillRejected).message, "owner stopped")
}

@Test
func uiOwnerQueueCancelAllPendingKeepsQueueOpen(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    let first = queue.post({=> let _ = applied.fetchAdd(1)})
    let second = queue.post({=> let _ = applied.fetchAdd(1)})

    let cancelled = queue.cancelAllPending(reason: "replace prepared frame")
    @Expect(cancelled.size, 2)
    @Expect(requireOwnerReceipt(first).status == UiOwnerTaskStatus.Cancelled)
    @Expect(requireOwnerReceipt(second).status == UiOwnerTaskStatus.Cancelled)
    @Expect(requireOwnerReceipt(first).message, "replace prepared frame")
    @Expect(!queue.isClosed())
    @Expect(!queue.hasPending())

    let replacement = queue.post({=> let _ = applied.fetchAdd(1)})
    @Expect(queue.drain().size, 1)
    @Expect(applied.load(), 1)
    @Expect(requireOwnerReceipt(replacement).status == UiOwnerTaskStatus.Committed)
}

@Test
func uiOwnerQueueConcurrentCloseAndPostsResolveEveryTicket(): Unit {
    let queue = UiOwnerQueue()
    let start = AtomicBool(false)
    let applied = AtomicInt64(0)
    let futures = ArrayList<Future<UiOwnerTicket>>()
    for (_ in 0..64) {
        futures.add(spawn {
            while (!start.load()) {
                sleep(Duration.millisecond)
            }
            queue.post({=> let _ = applied.fetchAdd(1)})
        })
    }
    let closer = spawn {
        while (!start.load()) {
            sleep(Duration.millisecond)
        }
        let _ = queue.close(reason: "concurrent shutdown")
    }

    start.store(true)
    let tickets = ArrayList<UiOwnerTicket>()
    for (future in futures) {
        tickets.add(future.get())
    }
    closer.get()

    @Expect(queue.isClosed())
    @Expect(!queue.hasPending())
    @Expect(applied.load(), 0)
    for (ticket in tickets) {
        let receipt = requireOwnerReceipt(ticket)
        @Expect(receipt.status == UiOwnerTaskStatus.Cancelled ||
            receipt.status == UiOwnerTaskStatus.RejectedClosed)
        @Expect(receipt.message, "concurrent shutdown")
    }
}

@Test
func uiOwnerQueueCompactsLargeBoundedBacklogsWithoutChangingOrder(): Unit {
    let queue = UiOwnerQueue()
    let applied = AtomicInt64(0)
    for (_ in 0..2050) {
        let _ = queue.post({=> let _ = applied.fetchAdd(1)})
    }

    let first = queue.drain(maxTasks: 1024)
    @Expect(first.size, 1024)
    @Expect(first[0].sequence, UInt64(1))
    @Expect(first[1023].sequence, UInt64(1024))
    @Expect(queue.pendingCount(), 1026)

    let second = queue.drain(maxTasks: 1024)
    @Expect(second.size, 1024)
    @Expect(second[0].sequence, UInt64(1025))
    @Expect(second[1023].sequence, UInt64(2048))
    @Expect(queue.pendingCount(), 2)

    let final = queue.drain()
    @Expect(final.size, 2)
    @Expect(final[0].sequence, UInt64(2049))
    @Expect(final[1].sequence, UInt64(2050))
    @Expect(applied.load(), 2050)
    @Expect(!queue.hasPending())
}
