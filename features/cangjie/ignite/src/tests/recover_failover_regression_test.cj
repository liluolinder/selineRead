package ignite.tests

import ignite.*
import ignite.governance.KModeFailoverOption
import ignite.governance.AuditConfig
import ignite.middleware.*
import std.collection.ArrayList
import std.sync.Mutex

class RecoverFailoverTestClock {
    public var nowMs: Int64 = 0

    public init(nowMs!: Int64 = 0) {
        this.nowMs = nowMs
    }
}

class RecoverProbeGate {
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
public class RecoverFailoverRegressionTestSuite {
    @TestCase
    public func testRecoverRestartDecisionEmitsHeadersAndAuditDetail(): Unit {
        let auditLines = ArrayList<String>()
        let restartHooks = ArrayList<String>()

        let app = App(config: Config(kmode: true))
        let auditConfig = AuditConfig(
            linuxStyle: false,
            redactSensitiveFields: false,
            output: { line => auditLines.add(line) }
        )
        app.use(auditMiddleware(config: AuditMiddlewareConfig(auditConfig: auditConfig)))
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    kmodeFailover: KModeFailoverOption(
                        enabled: true,
                        maxAttempts: 1,
                        intervalMs: 0,
                        terminateOnMiss: false,
                        probeHook: { _, _ => Some("RESTART") }
                    ),
                    onKModeRestart: { _, _, result =>
                        restartHooks.add("${result.exitCause}:${result.decision.toString()}")
                    }
                )
            )
        )
        app.get("/panic", { _ => throw Exception("restart-me") })

        let resp = app.handleForTest("GET", "/panic")
        @Assert(resp.status, UInt16(503))
        @Assert(resp.body, "Service Restart Requested")
        @Assert(resp.header("x-ignite-failover-decision") ?? "", "restart")
        @Assert(resp.header("x-ignite-failover-exit-cause") ?? "", "matched")
        @Assert(resp.header("x-ignite-failover-attempts") ?? "", "1")
        @Assert(restartHooks.size, 1)
        @Assert(restartHooks[0], "matched:restart")
        @Assert(auditLines.size > 0, true)
        @Assert(contains(auditLines[auditLines.size - 1], "\"guardEvent\":\"kmode_failover\""), true)
        @Assert(contains(auditLines[auditLines.size - 1], "\"guardExitCause\":\"matched\""), true)
        @Assert(
            contains(
                auditLines[auditLines.size - 1],
                "\"detail\":\"decision=restart;exitCause=matched;attempts=1;matched=true;lastStatus=200;elapsedMs="
            ),
            true
        )
    }

    @TestCase
    public func testRecoverTerminateDecisionEmitsHeadersAndHook(): Unit {
        let terminateHooks = ArrayList<String>()

        let app = App(config: Config(kmode: true))
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    kmodeFailover: KModeFailoverOption(
                        enabled: true,
                        maxAttempts: 2,
                        intervalMs: 0,
                        terminateOnMiss: true,
                        probeHook: { _, _ => Some("MISS") }
                    ),
                    onKModeTerminate: { _, _, result =>
                        terminateHooks.add("${result.exitCause}:${result.decision.toString()}:${result.attempts}")
                    }
                )
            )
        )
        app.get("/panic", { _ => throw Exception("terminate-me") })

        let resp = app.handleForTest("GET", "/panic")
        @Assert(resp.status, UInt16(503))
        @Assert(resp.body, "Service Terminated by KMode Failover")
        @Assert(resp.header("x-ignite-failover-decision") ?? "", "terminate")
        @Assert(resp.header("x-ignite-failover-exit-cause") ?? "", "miss")
        @Assert(resp.header("x-ignite-failover-attempts") ?? "", "2")
        @Assert(terminateHooks.size, 1)
        @Assert(terminateHooks[0], "miss:terminate:2")
    }

    @TestCase
    public func testRecoverCooldownSkipReturnsGuardCoolingDown(): Unit {
        let attempts = ArrayList<Int64>()
        let clock = RecoverFailoverTestClock()
        let app = App(config: Config(kmode: true))
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    kmodeFailover: KModeFailoverOption(
                        enabled: true,
                        maxAttempts: 1,
                        intervalMs: 0,
                        cooldownMs: 20,
                        terminateOnMiss: false,
                        probeHook: { attempt, _ =>
                            attempts.add(attempt)
                            Some("RESTART")
                        },
                        clockHook: { => clock.nowMs }
                    ),
                    onKModeRestart: { _, _, _ => () }
                )
            )
        )
        app.get("/panic", { _ => throw Exception("cooldown-me") })

        let first = app.handleForTest("GET", "/panic")
        @Assert(first.status, UInt16(503))
        @Assert(first.body, "Service Restart Requested")
        @Assert(first.header("x-ignite-failover-exit-cause") ?? "", "matched")
        @Assert(attempts.size, 1)

        clock.nowMs = 5
        let second = app.handleForTest("GET", "/panic")
        @Assert(second.status, UInt16(503))
        @Assert(second.body, "Service Guard Cooling Down")
        @Assert(second.header("x-ignite-failover-exit-cause") ?? "", "cooldown_skip")
        @Assert(second.header("x-ignite-failover-decision") ?? "", "restart")
        @Assert(attempts.size, 1)
    }

    @TestCase
    public func testRecoverRepeatPanicSkipReturnsSuppressedMessage(): Unit {
        let attempts = ArrayList<Int64>()
        let clock = RecoverFailoverTestClock()
        let app = App(config: Config(kmode: true))
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    kmodeFailover: KModeFailoverOption(
                        enabled: true,
                        maxAttempts: 1,
                        intervalMs: 0,
                        repeatWindowMs: 20,
                        terminateOnMiss: false,
                        probeHook: { attempt, _ =>
                            attempts.add(attempt)
                            Some("RESTART")
                        },
                        clockHook: { => clock.nowMs }
                    ),
                    onKModeRestart: { _, _, _ => () }
                )
            )
        )
        app.get("/panic", { _ => throw Exception("repeat-me") })

        let first = app.handleForTest("GET", "/panic")
        @Assert(first.status, UInt16(503))
        @Assert(first.body, "Service Restart Requested")
        @Assert(first.header("x-ignite-failover-exit-cause") ?? "", "matched")
        @Assert(attempts.size, 1)

        clock.nowMs = 5
        let second = app.handleForTest("GET", "/panic")
        @Assert(second.status, UInt16(503))
        @Assert(second.body, "Repeated Panic Suppressed")
        @Assert(second.header("x-ignite-failover-exit-cause") ?? "", "repeat_panic_skip")
        @Assert(second.header("x-ignite-failover-decision") ?? "", "restart")
        @Assert(attempts.size, 1)
    }

    @TestCase
    public func testRecoverRespondBeforeProbeSchedulesBackgroundFailover(): Unit {
        let gate = RecoverProbeGate()
        let asyncEvents = ArrayList<String>()
        let app = App(config: Config(kmode: true))
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    kmodeFailover: KModeFailoverOption(
                        enabled: true,
                        maxAttempts: 1,
                        intervalMs: 0,
                        respondBeforeProbe: true,
                        terminateOnMiss: false,
                        probeHook: { _, _ =>
                            gate.markEntered()
                            while (!gate.isReleased()) {
                                sleep(Duration.millisecond * 5)
                            }
                            Some("RESTART")
                        }
                    ),
                    onKModeRestartAsync: { _, result =>
                        asyncEvents.add("${result.exitCause}:${result.decision.toString()}")
                    }
                )
            )
        )
        app.get("/panic", { _ => throw Exception("async-me") })

        let resp = app.handleForTest("GET", "/panic")
        @Assert(resp.status, UInt16(503))
        @Assert(resp.body, "Service Failover Probe Scheduled")
        @Assert(resp.header("x-ignite-failover-exit-cause") ?? "", "probe_deferred")
        @Assert(resp.header("x-ignite-failover-decision") ?? "", "continue")

        waitUntil({ => gate.isEntered() }, 40, 5)
        @Assert(gate.isEntered(), true)
        @Assert(asyncEvents.size, 0)

        gate.release()
        waitUntil({ => asyncEvents.size > 0 }, 40, 5)
        @Assert(asyncEvents.size, 1)
        @Assert(asyncEvents[0], "matched:restart")
    }

    @TestCase
    public func testRecoverRespondBeforeProbeRespectsSingleFlightGuard(): Unit {
        let gate = RecoverProbeGate()
        let asyncEvents = ArrayList<String>()
        let app = App(config: Config(kmode: true))
        app.use(
            recoverMiddleware(
                config: RecoverConfig(
                    kmodeFailover: KModeFailoverOption(
                        enabled: true,
                        maxAttempts: 1,
                        intervalMs: 0,
                        respondBeforeProbe: true,
                        terminateOnMiss: false,
                        probeHook: { _, _ =>
                            gate.markEntered()
                            while (!gate.isReleased()) {
                                sleep(Duration.millisecond * 5)
                            }
                            Some("RESTART")
                        }
                    ),
                    onKModeRestartAsync: { _, result =>
                        asyncEvents.add("${result.exitCause}:${result.decision.toString()}")
                    }
                )
            )
        )
        app.get("/panic", { _ => throw Exception("async-single-flight") })

        let first = app.handleForTest("GET", "/panic")
        @Assert(first.status, UInt16(503))
        @Assert(first.body, "Service Failover Probe Scheduled")
        @Assert(first.header("x-ignite-failover-exit-cause") ?? "", "probe_deferred")

        waitUntil({ => gate.isEntered() }, 40, 5)
        @Assert(gate.isEntered(), true)

        let second = app.handleForTest("GET", "/panic")
        @Assert(second.status, UInt16(503))
        @Assert(second.body, "Service Guard Active")
        @Assert(second.header("x-ignite-failover-exit-cause") ?? "", "single_flight_skip")

        gate.release()
        waitUntil({ => asyncEvents.size > 0 }, 40, 5)
        @Assert(asyncEvents.size, 1)
        @Assert(asyncEvents[0], "matched:restart")
    }

    func waitUntil(check: () -> Bool, maxAttempts: Int64, sleepMs: Int64): Unit {
        var attempt: Int64 = 0
        while (attempt < maxAttempts) {
            if (check()) {
                return
            }
            sleep(Duration.millisecond * sleepMs)
            attempt += 1
        }
    }

    func contains(text: String, target: String): Bool {
        let t = text.toRuneArray()
        let p = target.toRuneArray()
        if (p.size == 0) {
            return true
        }
        if (t.size < p.size) {
            return false
        }
        var i: Int64 = 0
        while (i <= t.size - p.size) {
            var ok = true
            var j: Int64 = 0
            while (j < p.size) {
                if (t[i + j] != p[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) {
                return true
            }
            i += 1
        }
        false
    }
}
