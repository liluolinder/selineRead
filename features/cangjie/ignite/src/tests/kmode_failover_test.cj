package ignite.tests

import ignite.governance.{
    KModeFailoverDecision,
    KModeFailoverOption,
    runKModeFailover
}
import std.collection.ArrayList
import std.sync.Mutex

class FailoverTestClock {
    public var nowMs: Int64 = 0

    public init(nowMs!: Int64 = 0) {
        this.nowMs = nowMs
    }
}

class FailoverProbeGate {
    let mtx = Mutex()
    var entered: Bool = false
    var released: Bool = false

    public init() {}

    public func markEntered(): Unit {
        synchronized(mtx) {
            entered = true
        }
    }

    public func isEntered(): Bool {
        var output = false
        synchronized(mtx) {
            output = entered
        }
        output
    }

    public func release(): Unit {
        synchronized(mtx) {
            released = true
        }
    }

    public func isReleased(): Bool {
        var output = false
        synchronized(mtx) {
            output = released
        }
        output
    }
}

@Test
public class KModeFailoverTestSuite {
    @TestCase
    public func testFailoverDisabledReturnsContinue(): Unit {
        let option = KModeFailoverOption(enabled: false)
        let result = runKModeFailover(option, "panic:/health")
        @Assert(result.decision, KModeFailoverDecision.Continue)
        @Assert(result.attempts, 0)
        @Assert(result.matched, false)
        @Assert(result.exitCause, "disabled")
    }

    @TestCase
    public func testFailoverMatchReturnsRestart(): Unit {
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 3,
            intervalMs: 0,
            probeHook: { _, _ => Some("RESTART") }
        )
        let result = runKModeFailover(option, "panic:/users")
        @Assert(result.decision, KModeFailoverDecision.Restart)
        @Assert(result.attempts, 1)
        @Assert(result.matched, true)
        @Assert(result.lastStatus, 200)
        @Assert(result.exitCause, "matched")
    }

    @TestCase
    public func testFailoverMissReturnsTerminateAfterMaxAttempts(): Unit {
        let calls = ArrayList<Int64>()
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 4,
            intervalMs: 0,
            terminateOnMiss: true,
            probeHook: { attempt, _ =>
                calls.add(attempt)
                Some("KEEP-RUNNING")
            }
        )

        let result = runKModeFailover(option, "panic:/orders")
        @Assert(result.decision, KModeFailoverDecision.Terminate)
        @Assert(result.matched, false)
        @Assert(result.attempts, 4)
        @Assert(calls.size, 4)
        @Assert(result.exitCause, "miss")
    }

    @TestCase
    public func testFailoverMissCanFallbackToContinue(): Unit {
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 2,
            intervalMs: 0,
            terminateOnMiss: false,
            probeHook: { _, _ => Some("IGNORE") }
        )
        let result = runKModeFailover(option, "panic:/metrics")
        @Assert(result.decision, KModeFailoverDecision.Continue)
        @Assert(result.attempts, 2)
        @Assert(result.matched, false)
        @Assert(result.exitCause, "miss")
    }

    @TestCase
    public func testFailoverNormalizesInvalidTimeoutAndAttempts(): Unit {
        let option = KModeFailoverOption(
            enabled: true,
            probeTimeoutSec: 0,
            maxAttempts: 0,
            intervalMs: -1,
            probeHook: { _, _ => Some("MISS") }
        )
        @Assert(option.probeTimeoutSec, 1)
        @Assert(option.maxAttempts, 1)
        @Assert(option.intervalMs, 0)
    }

    @TestCase
    public func testFailoverWaitHookRunsBetweenAttempts(): Unit {
        let waits = ArrayList<Int64>()
        let attempts = ArrayList<Int64>()
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 3,
            intervalMs: 25,
            terminateOnMiss: false,
            probeHook: { attempt, _ =>
                attempts.add(attempt)
                Some("MISS")
            },
            waitHook: { ms =>
                waits.add(ms)
            }
        )

        let result = runKModeFailover(option, "panic:/wait-hook")
        @Assert(result.decision, KModeFailoverDecision.Continue)
        @Assert(result.attempts, 3)
        @Assert(attempts.size, 3)
        @Assert(waits.size, 2)
        @Assert(waits[0], 25)
        @Assert(waits[1], 25)
        @Assert(result.exitCause, "miss")
        @Assert(result.elapsedMs >= 0, true)
        @Assert(result.finishedAtMs >= result.startedAtMs, true)
    }

    @TestCase
    public func testFailoverBudgetStopsFurtherAttempts(): Unit {
        let waits = ArrayList<Int64>()
        let attempts = ArrayList<Int64>()
        let clock = FailoverTestClock()
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 4,
            intervalMs: 10,
            totalBudgetMs: 15,
            terminateOnMiss: false,
            probeHook: { attempt, _ =>
                attempts.add(attempt)
                Some("MISS")
            },
            waitHook: { ms =>
                waits.add(ms)
                clock.nowMs += ms
            },
            clockHook: { => clock.nowMs }
        )

        let result = runKModeFailover(option, "panic:/budget")
        @Assert(result.decision, KModeFailoverDecision.Continue)
        @Assert(result.attempts, 2)
        @Assert(result.matched, false)
        @Assert(result.exitCause, "budget_exceeded")
        @Assert(attempts.size, 2)
        @Assert(waits.size, 2)
        @Assert(waits[0], 10)
        @Assert(waits[1], 5)
        @Assert(result.elapsedMs, 15)
        @Assert(result.finishedAtMs, 15)
    }

    @TestCase
    public func testFailoverCooldownSkipsRepeatedRunWithinWindow(): Unit {
        let attempts = ArrayList<Int64>()
        let clock = FailoverTestClock()
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 1,
            intervalMs: 0,
            cooldownMs: 20,
            terminateOnMiss: false,
            probeHook: { attempt, _ =>
                attempts.add(attempt)
                Some("RESTART")
            },
            clockHook: { => clock.nowMs }
        )

        let first = runKModeFailover(option, "panic:/cooldown:first")
        @Assert(first.decision, KModeFailoverDecision.Restart)
        @Assert(first.exitCause, "matched")
        @Assert(attempts.size, 1)

        clock.nowMs = 5
        let second = runKModeFailover(option, "panic:/cooldown:second")
        @Assert(second.decision, KModeFailoverDecision.Restart)
        @Assert(second.exitCause, "cooldown_skip")
        @Assert(second.attempts, 0)
        @Assert(attempts.size, 1)

        clock.nowMs = 25
        let third = runKModeFailover(option, "panic:/cooldown:third")
        @Assert(third.decision, KModeFailoverDecision.Restart)
        @Assert(third.exitCause, "matched")
        @Assert(attempts.size, 2)
    }

    @TestCase
    public func testFailoverSingleFlightSkipsConcurrentProbe(): Unit {
        let gate = FailoverProbeGate()
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 1,
            intervalMs: 0,
            terminateOnMiss: false,
            probeHook: { _, _ =>
                gate.markEntered()
                while (!gate.isReleased()) {
                    sleep(Duration.millisecond * 5)
                }
                Some("RESTART")
            }
        )

        let future = spawn {
            runKModeFailover(option, "panic:/single-flight:first")
        }

        var spin: Int64 = 0
        while (!gate.isEntered() && spin < 40) {
            sleep(Duration.millisecond * 5)
            spin += 1
        }
        @Assert(gate.isEntered(), true)

        let skipped = runKModeFailover(option, "panic:/single-flight:second")
        @Assert(skipped.decision, KModeFailoverDecision.Continue)
        @Assert(skipped.exitCause, "single_flight_skip")
        @Assert(skipped.attempts, 0)

        gate.release()
        let first = future.get(Duration.second * 1)
        @Assert(first.decision, KModeFailoverDecision.Restart)
        @Assert(first.exitCause, "matched")
    }

    @TestCase
    public func testFailoverRepeatWindowSkipsSameReasonBurst(): Unit {
        let attempts = ArrayList<Int64>()
        let clock = FailoverTestClock()
        let option = KModeFailoverOption(
            enabled: true,
            expectedResponse: "RESTART",
            maxAttempts: 1,
            intervalMs: 0,
            repeatWindowMs: 20,
            terminateOnMiss: false,
            probeHook: { attempt, _ =>
                attempts.add(attempt)
                Some("RESTART")
            },
            clockHook: { => clock.nowMs }
        )

        let first = runKModeFailover(option, "panic:/repeat:same")
        @Assert(first.decision, KModeFailoverDecision.Restart)
        @Assert(first.exitCause, "matched")
        @Assert(attempts.size, 1)

        clock.nowMs = 5
        let second = runKModeFailover(option, "panic:/repeat:same")
        @Assert(second.decision, KModeFailoverDecision.Restart)
        @Assert(second.exitCause, "repeat_panic_skip")
        @Assert(second.attempts, 0)
        @Assert(attempts.size, 1)

        clock.nowMs = 6
        let third = runKModeFailover(option, "panic:/repeat:other")
        @Assert(third.exitCause, "matched")
        @Assert(attempts.size, 2)
    }
}
