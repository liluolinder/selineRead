package ignite.governance

import ignite.client.RestClient
import std.sync.Mutex
import std.time.{DateTime, MonoTime}

public type KModeFailoverProbeHook = (Int64, String) -> ?String
public type KModeFailoverWaitHook = (Int64) -> Unit
public type KModeFailoverClockHook = () -> Int64
public type KModeFailoverDeferredHook = (KModeFailoverResult) -> Unit

public enum KModeFailoverDecision <: Equatable<KModeFailoverDecision> & ToString {
    | Continue
    | Restart
    | Terminate

    public operator func ==(right: KModeFailoverDecision): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: KModeFailoverDecision): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Continue => 0
            case Restart => 1
            case Terminate => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Continue => "continue"
            case Restart => "restart"
            case Terminate => "terminate"
        }
    }
}

public class KModeFailoverOption {
    public var enabled: Bool = false
    public var probeUrl: String = "http://localhost:8828"
    public var probeMethod: String = "POST"
    public var probePayload: String = ""
    public var probeHeaderName: String = "X-Ignite-KMode"
    public var probeHeaderValue: String = "emergency"
    public var expectedResponse: String = "RESTART"
    public var probeTimeoutSec: Int64 = 3
    public var maxAttempts: Int64 = 3
    public var intervalMs: Int64 = 1000
    public var totalBudgetMs: Int64 = 0
    public var cooldownMs: Int64 = 0
    public var repeatWindowMs: Int64 = 0
    public var respondBeforeProbe: Bool = false
    public var restartOnMatch: Bool = true
    public var terminateOnMiss: Bool = true
    public var probeHook: ?KModeFailoverProbeHook = None
    public var waitHook: ?KModeFailoverWaitHook = None
    public var clockHook: ?KModeFailoverClockHook = None
    let coordinator = KModeFailoverCoordinator()

    public init(
        enabled!: Bool = false,
        probeUrl!: String = "http://localhost:8828",
        probeMethod!: String = "POST",
        probePayload!: String = "",
        probeHeaderName!: String = "X-Ignite-KMode",
        probeHeaderValue!: String = "emergency",
        expectedResponse!: String = "RESTART",
        probeTimeoutSec!: Int64 = 3,
        maxAttempts!: Int64 = 3,
        intervalMs!: Int64 = 1000,
        totalBudgetMs!: Int64 = 0,
        cooldownMs!: Int64 = 0,
        repeatWindowMs!: Int64 = 0,
        respondBeforeProbe!: Bool = false,
        restartOnMatch!: Bool = true,
        terminateOnMiss!: Bool = true,
        probeHook!: ?KModeFailoverProbeHook = None,
        waitHook!: ?KModeFailoverWaitHook = None,
        clockHook!: ?KModeFailoverClockHook = None
    ) {
        this.enabled = enabled
        this.probeUrl = probeUrl
        this.probeMethod = normalizeMethod(probeMethod)
        this.probePayload = probePayload
        this.probeHeaderName = probeHeaderName
        this.probeHeaderValue = probeHeaderValue
        this.expectedResponse = expectedResponse.trimAscii()
        this.probeTimeoutSec = if (probeTimeoutSec > 0) { probeTimeoutSec } else { 1 }
        this.maxAttempts = if (maxAttempts > 0) { maxAttempts } else { 1 }
        this.intervalMs = if (intervalMs >= 0) { intervalMs } else { 0 }
        this.totalBudgetMs = if (totalBudgetMs >= 0) { totalBudgetMs } else { 0 }
        this.cooldownMs = if (cooldownMs >= 0) { cooldownMs } else { 0 }
        this.repeatWindowMs = if (repeatWindowMs >= 0) { repeatWindowMs } else { 0 }
        this.respondBeforeProbe = respondBeforeProbe
        this.restartOnMatch = restartOnMatch
        this.terminateOnMiss = terminateOnMiss
        this.probeHook = probeHook
        this.waitHook = waitHook
        this.clockHook = clockHook
    }
}

public class KModeFailoverResult {
    public let decision: KModeFailoverDecision
    public let attempts: Int64
    public let matched: Bool
    public let lastStatus: Int64
    public let lastResponse: String
    public let reason: String
    public let exitCause: String
    public let startedAtMs: Int64
    public let finishedAtMs: Int64
    public let elapsedMs: Int64

    public init(
        decision: KModeFailoverDecision,
        attempts: Int64,
        matched: Bool,
        lastStatus: Int64,
        lastResponse: String,
        reason: String,
        exitCause: String,
        startedAtMs: Int64,
        finishedAtMs: Int64,
        elapsedMs: Int64
    ) {
        this.decision = decision
        this.attempts = attempts
        this.matched = matched
        this.lastStatus = lastStatus
        this.lastResponse = lastResponse
        this.reason = reason
        this.exitCause = exitCause
        this.startedAtMs = startedAtMs
        this.finishedAtMs = finishedAtMs
        this.elapsedMs = elapsedMs
    }
}

public func runKModeFailover(option: KModeFailoverOption, reason: String): KModeFailoverResult {
    let startedAtMs = currentFailoverWallClockMs(option)
    if (let Some(bypassResult) <- option.coordinator.tryBegin(option, reason, startedAtMs)) {
        return bypassResult
    }
    let startMono = MonoTime.now()
    runKModeFailoverAfterBegin(option, reason, startMono, startedAtMs)
}

public func deferKModeFailover(
    option: KModeFailoverOption,
    reason: String,
    onResult!: ?KModeFailoverDeferredHook = None
): KModeFailoverResult {
    let startedAtMs = currentFailoverWallClockMs(option)
    if (let Some(bypassResult) <- option.coordinator.tryBegin(option, reason, startedAtMs)) {
        return bypassResult
    }
    let deferredResult = buildFailoverBypassResult(option, reason, startedAtMs, "probe_deferred", None)
    let startMono = MonoTime.now()
    spawn {
        let result = runKModeFailoverAfterBegin(option, reason, startMono, startedAtMs)
        if (let Some(hook) <- onResult) {
            hook(result)
        }
    }
    deferredResult
}

func runKModeFailoverAfterBegin(
    option: KModeFailoverOption,
    reason: String,
    startMono: MonoTime,
    startedAtMs: Int64
): KModeFailoverResult {
    if (!option.enabled) {
        return option.coordinator.finish(
            option,
            buildFailoverResult(
                option,
                Continue,
                0,
                false,
                -1,
                "",
                reason,
                "disabled",
                startMono,
                startedAtMs
            )
        )
    }

    var attempt: Int64 = 1
    var lastStatus: Int64 = -1
    var lastResponse = ""

    while (attempt <= option.maxAttempts) {
        if (remainingFailoverBudgetMs(option, startMono, startedAtMs) == 0) {
            return option.coordinator.finish(
                option,
                buildFailoverResult(
                    option,
                    finalMissDecision(option),
                    attempt - 1,
                    false,
                    lastStatus,
                    lastResponse,
                    reason,
                    "budget_exceeded",
                    startMono,
                    startedAtMs
                )
            )
        }
        let probe = executeProbe(option, attempt, reason)
        if (let Some((status, response)) <- probe) {
            lastStatus = status
            lastResponse = response
            if (status >= 200 && status < 300 && response.trimAscii() == option.expectedResponse) {
                let decision = if (option.restartOnMatch) { Restart } else { Continue }
                return option.coordinator.finish(
                    option,
                    buildFailoverResult(
                        option,
                        decision,
                        attempt,
                        true,
                        lastStatus,
                        lastResponse,
                        reason,
                        "matched",
                        startMono,
                        startedAtMs
                    )
                )
            }
        } else {
            lastStatus = -1
        }

        if (attempt < option.maxAttempts && option.intervalMs > 0) {
            let waitMs = resolveFailoverWaitMs(option, startMono, startedAtMs)
            if (waitMs == 0) {
                return option.coordinator.finish(
                    option,
                    buildFailoverResult(
                        option,
                        finalMissDecision(option),
                        attempt,
                        false,
                        lastStatus,
                        lastResponse,
                        reason,
                        "budget_exceeded",
                        startMono,
                        startedAtMs
                    )
                )
            }
            waitForFailoverInterval(option, waitMs)
        }
        attempt += 1
    }

    let finalDecision = finalMissDecision(option)
    option.coordinator.finish(
        option,
        buildFailoverResult(
            option,
            finalDecision,
            option.maxAttempts,
            false,
            lastStatus,
            lastResponse,
            reason,
            "miss",
            startMono,
            startedAtMs
        )
    )
}

func executeProbe(option: KModeFailoverOption, attempt: Int64, reason: String): ?(Int64, String) {
    if (let Some(hook) <- option.probeHook) {
        if (let Some(response) <- hook(attempt, reason)) {
            return Some((200, response))
        }
        return None
    }

    let client = RestClient(
        readTimeout: Duration.second * option.probeTimeoutSec,
        writeTimeout: Duration.second * option.probeTimeoutSec,
        poolSize: 2
    )
    var output: ?(Int64, String) = None
    try {
        let req = client.request()
            .method(option.probeMethod)
            .url(option.probeUrl)
            .header("content-type", "text/plain; charset=utf-8")
            .header("x-ignite-kmode-reason", reason)

        if (option.probeHeaderName.size > 0) {
            req.header(option.probeHeaderName, option.probeHeaderValue)
        }

        if (methodSupportsBody(option.probeMethod)) {
            req.body(option.probePayload)
        }

        let resp = req.send()
        output = Some((Int64(resp.status), resp.body()))
    } catch (_: Exception) {
        output = None
    } finally {
        client.close()
    }
    output
}

func methodSupportsBody(method: String): Bool {
    method == "POST" || method == "PUT" || method == "PATCH" || method == "DELETE"
}

func normalizeMethod(raw: String): String {
    let m = raw.trimAscii().toAsciiUpper()
    if (m.size == 0) {
        return "POST"
    }
    m
}

func waitForFailoverInterval(option: KModeFailoverOption, ms: Int64): Unit {
    if (ms <= 0) {
        return
    }
    if (let Some(waitHook) <- option.waitHook) {
        waitHook(ms)
        return
    }
    sleep(Duration.millisecond * ms)
}

func buildFailoverResult(
    option: KModeFailoverOption,
    decision: KModeFailoverDecision,
    attempts: Int64,
    matched: Bool,
    lastStatus: Int64,
    lastResponse: String,
    reason: String,
    exitCause: String,
    startMono: MonoTime,
    startedAtMs: Int64
): KModeFailoverResult {
    let finishedAtMs = currentFailoverWallClockMs(option)
    let elapsedMs = currentFailoverElapsedMs(option, startMono, startedAtMs)
    KModeFailoverResult(
        decision,
        attempts,
        matched,
        lastStatus,
        lastResponse,
        reason,
        exitCause,
        startedAtMs,
        finishedAtMs,
        elapsedMs
    )
}

func currentFailoverWallClockMs(option: KModeFailoverOption): Int64 {
    if (let Some(clockHook) <- option.clockHook) {
        return clockHook()
    }
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

func currentFailoverElapsedMs(
    option: KModeFailoverOption,
    startMono: MonoTime,
    startedAtMs: Int64
): Int64 {
    if (let Some(clockHook) <- option.clockHook) {
        let currentMs = clockHook()
        if (currentMs >= startedAtMs) {
            return currentMs - startedAtMs
        }
        return 0
    }
    (MonoTime.now() - startMono).toMilliseconds()
}

func remainingFailoverBudgetMs(
    option: KModeFailoverOption,
    startMono: MonoTime,
    startedAtMs: Int64
): Int64 {
    if (option.totalBudgetMs <= 0) {
        return -1
    }
    let elapsedMs = currentFailoverElapsedMs(option, startMono, startedAtMs)
    if (elapsedMs >= option.totalBudgetMs) {
        return 0
    }
    option.totalBudgetMs - elapsedMs
}

func resolveFailoverWaitMs(
    option: KModeFailoverOption,
    startMono: MonoTime,
    startedAtMs: Int64
): Int64 {
    let remaining = remainingFailoverBudgetMs(option, startMono, startedAtMs)
    if (remaining < 0) {
        return option.intervalMs
    }
    if (remaining == 0) {
        return 0
    }
    if (option.intervalMs < remaining) {
        return option.intervalMs
    }
    remaining
}

func finalMissDecision(option: KModeFailoverOption): KModeFailoverDecision {
    if (option.terminateOnMiss) {
        return Terminate
    }
    Continue
}

class KModeFailoverCoordinator {
    let mtx = Mutex()
    var running: Bool = false
    var cooldownUntilMs: Int64 = 0
    var lastResult: ?KModeFailoverResult = None
    var lastReason: String = ""
    var lastReasonAtMs: Int64 = -1

    init() {}

    func tryBegin(
        option: KModeFailoverOption,
        reason: String,
        nowMs: Int64
    ): ?KModeFailoverResult {
        var output: ?KModeFailoverResult = None
        synchronized(mtx) {
            if (running) {
                output = Some(buildFailoverBypassResult(option, reason, nowMs, "single_flight_skip", lastResult))
            } else if (shouldSkipRepeatedReason(option, reason, nowMs)) {
                output = Some(buildFailoverBypassResult(option, reason, nowMs, "repeat_panic_skip", lastResult))
            } else if (option.cooldownMs > 0 && nowMs < cooldownUntilMs) {
                output = Some(buildFailoverBypassResult(option, reason, nowMs, "cooldown_skip", lastResult))
            } else {
                running = true
            }
        }
        output
    }

    func finish(option: KModeFailoverOption, result: KModeFailoverResult): KModeFailoverResult {
        synchronized(mtx) {
            running = false
            lastResult = Some(result)
            lastReason = result.reason
            lastReasonAtMs = result.finishedAtMs
            if (option.cooldownMs > 0) {
                cooldownUntilMs = result.finishedAtMs + option.cooldownMs
            } else {
                cooldownUntilMs = result.finishedAtMs
            }
        }
        result
    }

    func shouldSkipRepeatedReason(option: KModeFailoverOption, reason: String, nowMs: Int64): Bool {
        if (option.repeatWindowMs <= 0) {
            return false
        }
        if (lastReasonAtMs < 0) {
            return false
        }
        if (reason != lastReason) {
            return false
        }
        let elapsed = nowMs - lastReasonAtMs
        elapsed >= 0 && elapsed < option.repeatWindowMs
    }
}

func buildFailoverBypassResult(
    option: KModeFailoverOption,
    reason: String,
    nowMs: Int64,
    exitCause: String,
    previous: ?KModeFailoverResult
): KModeFailoverResult {
    var decision = finalMissDecision(option)
    var lastStatus: Int64 = -1
    var lastResponse = ""
    if (let Some(result) <- previous) {
        decision = result.decision
        lastStatus = result.lastStatus
        lastResponse = result.lastResponse
    }
    KModeFailoverResult(
        decision,
        0,
        false,
        lastStatus,
        lastResponse,
        reason,
        exitCause,
        nowMs,
        nowMs,
        0
    )
}
