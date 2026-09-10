package chui.core

import std.collection.ArrayList
import std.sync.Mutex

/** Admission policy for immutable worker preparation owned by one `UiTaskScope`. */
public enum UiTaskPolicy {
    /** Refuses a second task while the first task is preparing or waiting for owner commit. */
    | SingleFlight
    /** Cancels older outstanding work and commits only the newest prepared value. */
    | LatestOnly
    /** Admits at most `limit` outstanding tasks. */
    | Queue(Int64)
    /** Latest-only semantics after a bounded quiet period in milliseconds. */
    | Debounce(UInt64)
}

public func uiTaskPolicyName(value: UiTaskPolicy): String {
    match (value) {
        case UiTaskPolicy.SingleFlight => "single-flight"
        case UiTaskPolicy.LatestOnly => "latest-only"
        case UiTaskPolicy.Queue(limit) => "queue(${limit})"
        case UiTaskPolicy.Debounce(delayMs) => "debounce(${delayMs}ms)"
    }
}

/** Observable producer-side state. Final owner truth remains the attached `UiOwnerReceipt`. */
public enum UiTaskSubmissionStatus <: Equatable<UiTaskSubmissionStatus> {
    | Preparing
    | OwnerQueued
    | Committed
    | Cancelled
    | RejectedCapacity
    | RejectedClosed
    | RejectedStaleOwner
    | FailedPreparation
    | FailedApply

    public operator func ==(other: UiTaskSubmissionStatus): Bool {
        uiTaskSubmissionStatusName(this) == uiTaskSubmissionStatusName(other)
    }

    public operator func !=(other: UiTaskSubmissionStatus): Bool { !(this == other) }
}

public func uiTaskSubmissionStatusName(value: UiTaskSubmissionStatus): String {
    match (value) {
        case UiTaskSubmissionStatus.Preparing => "preparing"
        case UiTaskSubmissionStatus.OwnerQueued => "owner-queued"
        case UiTaskSubmissionStatus.Committed => "committed"
        case UiTaskSubmissionStatus.Cancelled => "cancelled"
        case UiTaskSubmissionStatus.RejectedCapacity => "rejected-capacity"
        case UiTaskSubmissionStatus.RejectedClosed => "rejected-closed"
        case UiTaskSubmissionStatus.RejectedStaleOwner => "rejected-stale-owner"
        case UiTaskSubmissionStatus.FailedPreparation => "failed-preparation"
        case UiTaskSubmissionStatus.FailedApply => "failed-apply"
    }
}

/** Cancellation and receipt handle for one scoped preparation. */
public class UiTaskSubmission {
    public let sequence: UInt64
    public let generation: UInt64
    private let mutex = Mutex()
    private var cancelled = false
    private var localStatus: ?UiTaskSubmissionStatus = None
    private var localMessage = ""
    private var ownerTicketValue: ?UiOwnerTicket = None

    init(sequence: UInt64, generation: UInt64) {
        this.sequence = sequence
        this.generation = generation
    }

    /** Cooperatively cancels preparation or the not-yet-claimed owner task. */
    public func cancel(): Bool {
        let ticket: ?UiOwnerTicket = synchronized(mutex) {
            if (isTerminalLocked() || cancelled) { return false }
            cancelled = true
            ownerTicketValue
        }
        match (ticket) {
            case Some(value) => let _ = value.cancel()
            case None => ()
        }
        true
    }

    public func isCancellationRequested(): Bool {
        synchronized(mutex) { cancelled }
    }

    /** Producer-side status projected from the canonical owner receipt when one exists. */
    public func status(): UiTaskSubmissionStatus {
        synchronized(mutex) {
            match (localStatus) {
                case Some(value) => return value
                case None => ()
            }
            match (ownerTicketValue) {
                case Some(ticket) => match (ticket.receipt()) {
                    case Some(receipt) => return uiTaskStatusFromOwner(receipt.status)
                    case None => return UiTaskSubmissionStatus.OwnerQueued
                }
                case None => if (cancelled) {
                    UiTaskSubmissionStatus.Cancelled
                } else {
                    UiTaskSubmissionStatus.Preparing
                }
            }
        }
    }

    public func message(): String {
        synchronized(mutex) {
            if (!localMessage.isEmpty()) { return localMessage }
            match (ownerTicketValue) {
                case Some(ticket) => match (ticket.receipt()) {
                    case Some(receipt) => receipt.message
                    case None => ""
                }
                case None => ""
            }
        }
    }

    /** Canonical owner receipt, or `None` before preparation has posted to the owner. */
    public func ownerReceipt(): ?UiOwnerReceipt {
        synchronized(mutex) {
            match (ownerTicketValue) {
                case Some(ticket) => ticket.receipt()
                case None => None
            }
        }
    }

    func attachOwnerTicket(ticket: UiOwnerTicket): Unit {
        let cancelNow = synchronized(mutex) {
            ownerTicketValue = Some(ticket)
            cancelled
        }
        if (cancelNow) { let _ = ticket.cancel() }
    }

    func failPreparation(message: String): Unit {
        synchronized(mutex) {
            if (!cancelled) {
                localStatus = Some(UiTaskSubmissionStatus.FailedPreparation)
                localMessage = message
            }
        }
    }

    func reject(status: UiTaskSubmissionStatus, message: String): Unit {
        synchronized(mutex) {
            localStatus = Some(status)
            localMessage = message
        }
    }

    private func isTerminalLocked(): Bool {
        if (localStatus.isSome()) { return true }
        match (ownerTicketValue) {
            case Some(ticket) => ticket.receipt().isSome()
            case None => false
        }
    }
}

/**
 * Bounded producer lifecycle layered on the existing `UiOwnerQueue`.
 *
 * `prepare` runs on a worker and must return an immutable result. `apply` is posted to the supplied
 * owner queue and is therefore the only closure allowed to mutate live UI state. The scope does not
 * retry work and does not close a shared owner queue when it is disposed.
 */
public class UiTaskScope {
    public let ownerKey: String
    public let policy: UiTaskPolicy
    private let ownerQueue: UiOwnerQueue
    private let mutex = Mutex()
    private var submissions = ArrayList<UiTaskSubmission>()
    private var nextSequence: UInt64 = 0
    private var nextGeneration: UInt64 = 0
    private var closed = false

    public init(ownerKey: String, ownerQueue: UiOwnerQueue, policy!: UiTaskPolicy = UiTaskPolicy.LatestOnly) {
        if (ownerKey.isEmpty()) { throw IllegalArgumentException("UI task scope owner key must not be empty") }
        validateUiTaskPolicy(policy)
        this.ownerKey = ownerKey
        this.ownerQueue = ownerQueue
        this.policy = policy
    }

    /** Starts one worker preparation subject to this scope's admission policy. */
    public func submit<T>(
        prepare: () -> T,
        apply: (T) -> Unit,
        baseEpoch!: ?UInt64 = None,
        surfaceGeneration!: ?Int64 = None,
        topologyHash!: String = ""
    ): UiTaskSubmission {
        let admitted: (UiTaskSubmission, Bool, UInt64) = synchronized(mutex) {
            collectResolvedLocked()
            nextSequence = nextUiTaskCounter(nextSequence, "sequence")
            if (closed) {
                let rejected = UiTaskSubmission(nextSequence, nextGeneration)
                rejected.reject(UiTaskSubmissionStatus.RejectedClosed, "UI task scope is closed")
                (rejected, false, UInt64(0))
            } else if (!hasUiTaskCapacity(policy, submissions.size)) {
                let rejected = UiTaskSubmission(nextSequence, nextGeneration)
                rejected.reject(UiTaskSubmissionStatus.RejectedCapacity,
                    "UI task scope policy ${uiTaskPolicyName(policy)} rejected concurrent work")
                (rejected, false, UInt64(0))
            } else {
                if (uiTaskReplacesOutstanding(policy)) {
                    for (submission in submissions) { let _ = submission.cancel() }
                }
                nextGeneration = nextUiTaskCounter(nextGeneration, "generation")
                let created = UiTaskSubmission(nextSequence, nextGeneration)
                submissions.add(created)
                (created, true, uiTaskDebounceMilliseconds(policy))
            }
        }
        let (submission, shouldRun, debounceMs) = admitted
        if (!shouldRun) { return submission }
        let queue = ownerQueue
        let scopeKey = ownerKey
        let _ = spawn {
            sleepUiTaskDebounce(debounceMs, submission)
            if (submission.isCancellationRequested()) { return }
            try {
                let prepared = prepare()
                if (submission.isCancellationRequested()) { return }
                let ticket = queue.post({=>
                    if (!submission.isCancellationRequested()) { apply(prepared) }
                }, baseEpoch: baseEpoch, surfaceGeneration: surfaceGeneration,
                    topologyHash: if (topologyHash.isEmpty()) {scopeKey} else {topologyHash})
                submission.attachOwnerTicket(ticket)
            } catch (error: Exception) {
                submission.failPreparation(error.message)
            }
        }
        submission
    }

    /** Removes completed handles from capacity accounting and returns their final statuses. */
    public func collect(): Array<UiTaskSubmissionStatus> {
        synchronized(mutex) {
            let statuses = ArrayList<UiTaskSubmissionStatus>()
            var i = submissions.size - 1
            while (i >= 0) {
                let status = submissions[i].status()
                if (uiTaskStatusIsTerminal(status)) {
                    statuses.add(status)
                    submissions.remove(at: i)
                }
                i -= 1
            }
            statuses.toArray()
        }
    }

    public func outstandingCount(): Int64 {
        synchronized(mutex) {
            collectResolvedLocked()
            submissions.size
        }
    }

    /** Cancels outstanding work and permanently rejects new submissions. */
    public func close(): Unit {
        let snapshot: Array<UiTaskSubmission> = synchronized(mutex) {
            if (closed) {
                []
            } else {
                closed = true
                submissions.toArray()
            }
        }
        for (submission in snapshot) { let _ = submission.cancel() }
    }

    public func isClosed(): Bool { synchronized(mutex) { closed } }

    private func collectResolvedLocked(): Unit {
        var i = submissions.size - 1
        while (i >= 0) {
            if (uiTaskStatusIsTerminal(submissions[i].status())) { submissions.remove(at: i) }
            i -= 1
        }
    }
}

private func validateUiTaskPolicy(value: UiTaskPolicy): Unit {
    match (value) {
        case UiTaskPolicy.Queue(limit) => if (limit <= 0) {
            throw IllegalArgumentException("UI task queue limit must be positive")
        }
        case _ => ()
    }
}

private func hasUiTaskCapacity(policy: UiTaskPolicy, current: Int64): Bool {
    match (policy) {
        case UiTaskPolicy.SingleFlight => current == 0
        case UiTaskPolicy.Queue(limit) => current < limit
        case _ => true
    }
}

private func uiTaskReplacesOutstanding(policy: UiTaskPolicy): Bool {
    match (policy) {
        case UiTaskPolicy.LatestOnly => true
        case UiTaskPolicy.Debounce(_) => true
        case _ => false
    }
}

private func uiTaskDebounceMilliseconds(policy: UiTaskPolicy): UInt64 {
    match (policy) { case UiTaskPolicy.Debounce(value) => value case _ => UInt64(0) }
}

private func sleepUiTaskDebounce(milliseconds: UInt64, submission: UiTaskSubmission): Unit {
    var elapsed: UInt64 = 0
    while (elapsed < milliseconds && !submission.isCancellationRequested()) {
        sleep(Duration.millisecond)
        elapsed += UInt64(1)
    }
}

private func nextUiTaskCounter(current: UInt64, role: String): UInt64 {
    if (current == UInt64.Max) { throw IllegalStateException("UI task ${role} exhausted") }
    current + UInt64(1)
}

private func uiTaskStatusFromOwner(value: UiOwnerTaskStatus): UiTaskSubmissionStatus {
    match (value) {
        case UiOwnerTaskStatus.Committed => UiTaskSubmissionStatus.Committed
        case UiOwnerTaskStatus.Cancelled => UiTaskSubmissionStatus.Cancelled
        case UiOwnerTaskStatus.RejectedClosed => UiTaskSubmissionStatus.RejectedClosed
        case UiOwnerTaskStatus.RejectedStaleEpoch => UiTaskSubmissionStatus.RejectedStaleOwner
        case UiOwnerTaskStatus.RejectedSurfaceGeneration => UiTaskSubmissionStatus.RejectedStaleOwner
        case UiOwnerTaskStatus.Failed => UiTaskSubmissionStatus.FailedApply
    }
}

private func uiTaskStatusIsTerminal(value: UiTaskSubmissionStatus): Bool {
    match (value) {
        case UiTaskSubmissionStatus.Preparing => false
        case UiTaskSubmissionStatus.OwnerQueued => false
        case _ => true
    }
}
