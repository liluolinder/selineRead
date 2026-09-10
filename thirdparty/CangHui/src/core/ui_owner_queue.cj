package chui.core

import std.collection.ArrayList
import std.sync.Mutex

/** Work executed only by the UI owner after a worker has finished preparing immutable input. */
public type UiOwnerTaskHandler = () -> Unit

/** Best-effort host wake-up invoked after a task is posted. It must itself be thread-safe. */
public type UiOwnerWakeHandler = () -> Unit

/** Final disposition of one task submitted to a `UiOwnerQueue`. */
public enum UiOwnerTaskStatus <: Equatable<UiOwnerTaskStatus> {
    | Committed
    | Cancelled
    | RejectedClosed
    | RejectedStaleEpoch
    | RejectedSurfaceGeneration
    | Failed

    public operator func ==(other: UiOwnerTaskStatus): Bool {
        uiOwnerTaskStatusName(this) == uiOwnerTaskStatusName(other)
    }

    public operator func !=(other: UiOwnerTaskStatus): Bool {
        !(this == other)
    }
}

public func uiOwnerTaskStatusName(status: UiOwnerTaskStatus): String {
    match (status) {
        case UiOwnerTaskStatus.Committed => "committed"
        case UiOwnerTaskStatus.Cancelled => "cancelled"
        case UiOwnerTaskStatus.RejectedClosed => "rejected-closed"
        case UiOwnerTaskStatus.RejectedStaleEpoch => "rejected-stale-epoch"
        case UiOwnerTaskStatus.RejectedSurfaceGeneration => "rejected-surface-generation"
        case UiOwnerTaskStatus.Failed => "failed"
    }
}

/** Immutable completion record for one owner task. */
public class UiOwnerReceipt {
    public let sequence: UInt64
    public let status: UiOwnerTaskStatus
    /** Owner epoch after this task was resolved. Rejected and cancelled tasks do not advance it. */
    public let ownerEpoch: UInt64
    public let topologyHash: String
    public let message: String

    public init(
        sequence: UInt64,
        status: UiOwnerTaskStatus,
        ownerEpoch: UInt64,
        topologyHash!: String = "",
        message!: String = ""
    ) {
        this.sequence = sequence
        this.status = status
        this.ownerEpoch = ownerEpoch
        this.topologyHash = topologyHash
        this.message = message
    }
}

/**
 * Thread-safe handle returned to the producer. Cancellation is cooperative: it succeeds only while
 * the task is still pending, and completion becomes visible through `receipt()` after owner drain.
 */
public class UiOwnerTicket {
    public let sequence: UInt64
    public let baseEpoch: ?UInt64
    public let surfaceGeneration: ?Int64
    public let topologyHash: String
    private let mutex = Mutex()
    private var cancelRequested = false
    private var executionClaimed = false
    private var finalReceipt: ?UiOwnerReceipt = None

    init(sequence: UInt64, baseEpoch: ?UInt64, surfaceGeneration: ?Int64, topologyHash: String) {
        this.sequence = sequence
        this.baseEpoch = baseEpoch
        this.surfaceGeneration = surfaceGeneration
        this.topologyHash = topologyHash
    }

    /** Requests cancellation before execution. Returns false after cancellation or completion. */
    public func cancel(): Bool {
        synchronized(mutex) {
            if (cancelRequested || executionClaimed || finalReceipt.isSome()) {
                return false
            }
            cancelRequested = true
            return true
        }
    }

    /** Returns whether cancellation was requested before owner execution. */
    public func isCancellationRequested(): Bool {
        synchronized(mutex) {
            return cancelRequested
        }
    }

    /** Returns the final receipt, or `None` while the task is queued or executing. */
    public func receipt(): ?UiOwnerReceipt {
        synchronized(mutex) {
            return finalReceipt
        }
    }

    func complete(receipt: UiOwnerReceipt): Unit {
        synchronized(mutex) {
            if (finalReceipt.isNone()) {
                finalReceipt = Some(receipt)
            }
        }
    }

    /** Atomically transfers a still-pending ticket from producer cancellation to owner execution. */
    func claimForExecution(): Bool {
        synchronized(mutex) {
            if (cancelRequested || executionClaimed || finalReceipt.isSome()) {
                return false
            }
            executionClaimed = true
            return true
        }
    }
}

private class UiOwnerTask {
    let ticket: UiOwnerTicket
    let action: UiOwnerTaskHandler

    init(ticket: UiOwnerTicket, action: UiOwnerTaskHandler) {
        this.ticket = ticket
        this.action = action
    }
}

/**
 * Thread-safe producer queue with one serialized owner drain lane.
 *
 * Workers may prepare immutable values and call `post`; only the owner calls `drain`. The queue gives
 * concurrent producers a total sequence order, rejects stale epoch/surface work, and records a receipt.
 * It does not turn arbitrary task bodies into rollback-capable transactions: live UI mutation belongs
 * inside a small owner task whose preconditions were checked before execution.
 */
public class UiOwnerQueue {
    private let mutex = Mutex()
    private let drainMutex = Mutex()
    private var pending = ArrayList<UiOwnerTask>()
    private var pendingHead: Int64 = 0
    private let wakeHandler: ?UiOwnerWakeHandler
    private var nextSequence: UInt64 = 0
    private var ownerEpoch: UInt64 = 0
    private var activeSurfaceGeneration: ?Int64 = None
    private var closed = false
    private var closeReason = "UI owner queue closed"

    public init(wake!: ?UiOwnerWakeHandler = None) {
        this.wakeHandler = wake
    }

    /**
     * Enqueues one owner task and returns its monotonic ticket. `baseEpoch` and `surfaceGeneration`
     * are optional optimistic-concurrency gates; `topologyHash` is trace metadata for later SceneDiff
     * layers and is not interpreted by this queue.
     * Throws `IllegalArgumentException` for a negative surface generation and
     * `IllegalStateException` if the sequence space is exhausted.
     */
    public func post(
        action: UiOwnerTaskHandler,
        baseEpoch!: ?UInt64 = None,
        surfaceGeneration!: ?Int64 = None,
        topologyHash!: String = ""
    ): UiOwnerTicket {
        requireSurfaceGeneration(surfaceGeneration)
        let posted: (UiOwnerTicket, ?UiOwnerReceipt) = synchronized(mutex) {
            if (nextSequence == UInt64.Max) {
                throw IllegalStateException("UI owner task sequence exhausted")
            }
            nextSequence += UInt64(1)
            let created = UiOwnerTicket(nextSequence, baseEpoch, surfaceGeneration, topologyHash)
            if (closed) {
                let receipt = UiOwnerReceipt(created.sequence, UiOwnerTaskStatus.RejectedClosed,
                    ownerEpoch, topologyHash: topologyHash, message: closeReason)
                (created, Some(receipt))
            } else {
                pending.add(UiOwnerTask(created, action))
                (created, None)
            }
        }
        let (ticket, rejected) = posted
        match (rejected) {
            case Some(receipt) => ticket.complete(receipt)
            case None => wakeOwner()
        }
        ticket
    }

    /** Returns whether at least one task is waiting for owner resolution. */
    public func hasPending(): Bool {
        synchronized(mutex) {
            return pendingHead < pending.size
        }
    }

    public func pendingCount(): Int64 {
        synchronized(mutex) {
            return pending.size - pendingHead
        }
    }

    /** Returns whether the owner has permanently stopped accepting work. */
    public func isClosed(): Bool {
        synchronized(mutex) {
            return closed
        }
    }

    /** Epoch advanced before each task body that passes cancellation and stale gates. */
    public func currentEpoch(): UInt64 {
        synchronized(mutex) {
            return ownerEpoch
        }
    }

    /**
     * Updates the host-owned native-surface generation. `None` represents a detached surface.
     * Tasks targeting another generation are rejected when drained.
     * Throws `IllegalArgumentException` for a negative generation.
     */
    public func setSurfaceGeneration(generation: ?Int64): Unit {
        requireSurfaceGeneration(generation)
        synchronized(mutex) {
            activeSurfaceGeneration = generation
        }
        if (hasPending()) {
            wakeOwner()
        }
    }

    public func surfaceGeneration(): ?Int64 {
        synchronized(mutex) {
            return activeSurfaceGeneration
        }
    }

    /**
     * Runs at most `maxTasks` tasks in sequence order. Calls are serialized even if a faulty host
     * invokes `drain` concurrently; tasks posted reentrantly remain queued for the next drain.
     * Throws `IllegalArgumentException` when `maxTasks` is not positive.
     */
    public func drain(maxTasks!: Int64 = 1024): Array<UiOwnerReceipt> {
        if (maxTasks <= 0) {
            throw IllegalArgumentException("UI owner drain limit must be positive")
        }
        synchronized(drainMutex) {
            let ready = takePending(maxTasks)
            let receipts = ArrayList<UiOwnerReceipt>()
            for (task in ready) {
                receipts.add(execute(task))
            }
            return receipts.toArray()
        }
    }

    /** Cancels tasks that have not yet been taken by a drain call. */
    public func cancelAllPending(reason!: String = "UI owner queue cancelled"): Array<UiOwnerReceipt> {
        synchronized(drainMutex) {
            let ready = takePending(Int64.Max)
            return cancelTasks(ready, reason)
        }
    }

    /**
     * Permanently closes the queue and cancels its pending snapshot. Posts racing with closure are
     * either included in that snapshot or completed immediately as `RejectedClosed`.
     */
    public func close(reason!: String = "UI owner queue closed"): Array<UiOwnerReceipt> {
        synchronized(drainMutex) {
            let ready = synchronized(mutex) {
                if (!closed) {
                    closed = true
                    closeReason = reason
                }
                let snapshot = ArrayList<UiOwnerTask>()
                for (i in pendingHead..pending.size) {
                    snapshot.add(pending[i])
                }
                pending.clear()
                pendingHead = 0
                snapshot.toArray()
            }
            return cancelTasks(ready, reason)
        }
    }

    private func takePending(limit: Int64): Array<UiOwnerTask> {
        synchronized(mutex) {
            let count = min(limit, pending.size - pendingHead)
            let ready = ArrayList<UiOwnerTask>()
            for (offset in 0..count) {
                ready.add(pending[pendingHead + offset])
            }
            pendingHead += count
            compactPending()
            return ready.toArray()
        }
    }

    private func execute(task: UiOwnerTask): UiOwnerReceipt {
        let ticket = task.ticket
        if (!ticket.claimForExecution()) {
            let receipt = UiOwnerReceipt(ticket.sequence, UiOwnerTaskStatus.Cancelled, currentEpoch(),
                topologyHash: ticket.topologyHash, message: "task cancelled before owner execution")
            ticket.complete(receipt)
            return receipt
        }

        let (rejection, executionEpoch) = claimExecutionEpoch(ticket)
        match (rejection) {
            case Some(status) =>
                let receipt = UiOwnerReceipt(ticket.sequence, status, executionEpoch,
                    topologyHash: ticket.topologyHash, message: rejectionMessage(status))
                ticket.complete(receipt)
                return receipt
            case None => ()
        }

        try {
            task.action()
            let receipt = UiOwnerReceipt(ticket.sequence, UiOwnerTaskStatus.Committed, executionEpoch,
                topologyHash: ticket.topologyHash)
            ticket.complete(receipt)
            receipt
        } catch (error: Exception) {
            // The epoch was already advanced because the body may have partially changed live state.
            // This conservatively rejects later work prepared against the previous owner epoch.
            let receipt = UiOwnerReceipt(ticket.sequence, UiOwnerTaskStatus.Failed, executionEpoch,
                topologyHash: ticket.topologyHash, message: error.message)
            ticket.complete(receipt)
            receipt
        }
    }

    private func claimExecutionEpoch(ticket: UiOwnerTicket): (?UiOwnerTaskStatus, UInt64) {
        var rejection: ?UiOwnerTaskStatus = None
        var executionEpoch: UInt64 = 0
        synchronized(mutex) {
            match (ticket.baseEpoch) {
                case Some(expected) => if (ownerEpoch != expected) {
                    rejection = Some(UiOwnerTaskStatus.RejectedStaleEpoch)
                }
                case None => ()
            }
            if (rejection.isNone() && !surfaceGenerationMatches(ticket.surfaceGeneration,
                activeSurfaceGeneration)) {
                rejection = Some(UiOwnerTaskStatus.RejectedSurfaceGeneration)
            }
            if (rejection.isNone()) {
                ownerEpoch = nextOwnerEpoch(ownerEpoch)
                executionEpoch = ownerEpoch
            } else {
                executionEpoch = ownerEpoch
            }
        }
        (rejection, executionEpoch)
    }

    private func cancelTasks(tasks: Array<UiOwnerTask>, reason: String): Array<UiOwnerReceipt> {
        let receipts = ArrayList<UiOwnerReceipt>()
        for (task in tasks) {
            let receipt = UiOwnerReceipt(task.ticket.sequence, UiOwnerTaskStatus.Cancelled,
                currentEpoch(), topologyHash: task.ticket.topologyHash, message: reason)
            task.ticket.complete(receipt)
            receipts.add(receipt)
        }
        receipts.toArray()
    }

    private func wakeOwner(): Unit {
        match (wakeHandler) {
            case Some(wake) => try {
                wake()
            } catch (_: Exception) {
                // Posting succeeded; a best-effort host wake failure must not discard queued work.
                ()
            }
            case None => ()
        }
    }

    private func compactPending(): Unit {
        if (pendingHead == 0) {
            return
        }
        if (pendingHead >= pending.size) {
            pending.clear()
            pendingHead = 0
            return
        }
        if (pendingHead >= 1024 && pendingHead >= pending.size / 2) {
            let remaining = ArrayList<UiOwnerTask>()
            for (i in pendingHead..pending.size) {
                remaining.add(pending[i])
            }
            pending = remaining
            pendingHead = 0
        }
    }
}

/** Throws `IllegalArgumentException` when a supplied surface generation is negative. */
private func requireSurfaceGeneration(generation: ?Int64): Unit {
    match (generation) {
        case Some(value) => if (value < 0) {
            throw IllegalArgumentException("UI owner surface generation must not be negative")
        }
        case None => ()
    }
}

private func rejectionMessage(status: UiOwnerTaskStatus): String {
    if (status == UiOwnerTaskStatus.RejectedStaleEpoch) {
        "task base epoch no longer matches the UI owner"
    } else {
        "task surface generation no longer matches the UI owner"
    }
}

private func surfaceGenerationMatches(expected: ?Int64, current: ?Int64): Bool {
    match (expected) {
        case None => true
        case Some(value) => match (current) {
            case Some(actual) => value == actual
            case None => false
        }
    }
}

private func nextOwnerEpoch(current: UInt64): UInt64 {
    if (current == UInt64.Max) {
        UInt64(0)
    } else {
        current + UInt64(1)
    }
}
