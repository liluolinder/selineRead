package ignite.middleware

import ignite.{App, BufferedRequestBodyTooLargeException, Handler, Ctx}
import ignite.governance.{
    KModeFailoverOption,
    KModeFailoverDecision,
    KModeFailoverResult,
    deferKModeFailover,
    runKModeFailover
}

public type RecoverKModeFailoverHook = (Ctx, Exception, KModeFailoverResult) -> Unit
public type RecoverKModeFailoverAsyncHook = (App, KModeFailoverResult) -> Unit

public class RecoverConfig {
    public var enableStackTrace: Bool = false
    public var customHandler: ?((Ctx, Exception) -> Unit) = None
    public var kmodeFailover: ?KModeFailoverOption = None
    public var onKModeRestart: ?RecoverKModeFailoverHook = None
    public var onKModeTerminate: ?RecoverKModeFailoverHook = None
    public var onKModeRestartAsync: ?RecoverKModeFailoverAsyncHook = None
    public var onKModeTerminateAsync: ?RecoverKModeFailoverAsyncHook = None

    public init(
        enableStackTrace!: Bool = false,
        customHandler!: ?((Ctx, Exception) -> Unit) = None,
        kmodeFailover!: ?KModeFailoverOption = None,
        onKModeRestart!: ?RecoverKModeFailoverHook = None,
        onKModeTerminate!: ?RecoverKModeFailoverHook = None,
        onKModeRestartAsync!: ?RecoverKModeFailoverAsyncHook = None,
        onKModeTerminateAsync!: ?RecoverKModeFailoverAsyncHook = None
    ) {
        this.enableStackTrace = enableStackTrace
        this.customHandler = customHandler
        this.kmodeFailover = kmodeFailover
        this.onKModeRestart = onKModeRestart
        this.onKModeTerminate = onKModeTerminate
        this.onKModeRestartAsync = onKModeRestartAsync
        this.onKModeTerminateAsync = onKModeTerminateAsync
    }
}

public func recoverMiddleware(config!: RecoverConfig = RecoverConfig()): Handler {
    { ctx: Ctx =>
        try {
            ctx.next()
        } catch (e: BufferedRequestBodyTooLargeException) {
            if (let Some(handler) <- config.customHandler) {
                handler(ctx, e)
            } else {
                let _ = ctx.status(413).sendString("Payload Too Large")
            }
        } catch (e: Exception) {
            if (let Some(result) <- runFailoverIfNeeded(ctx, e, config)) {
                if (shouldHandleGuardActive(result)) {
                    handleGuardActiveDecision(ctx, result)
                    return
                }
                if (result.decision == KModeFailoverDecision.Restart) {
                    handleRestartDecision(ctx, e, result, config)
                    return
                }
                if (result.decision == KModeFailoverDecision.Terminate) {
                    handleTerminateDecision(ctx, e, result, config)
                    return
                }
            }

            if (let Some(handler) <- config.customHandler) {
                handler(ctx, e)
            } else {
                println("[Ignite Recovery] Panic recovered: ${e.message}")
                let _ = ctx.status(500).sendString("Internal Server Error")
            }
        }
    }
}

func runFailoverIfNeeded(ctx: Ctx, e: Exception, config: RecoverConfig): ?KModeFailoverResult {
    if (!ctx.app().config.kmode) {
        return None
    }
    if (let Some(option) <- config.kmodeFailover) {
        let reason = "panic:${ctx.method}:${ctx.path}:${e.message}"
        if (option.respondBeforeProbe) {
            let appRef = ctx.app()
            return Some(
                deferKModeFailover(
                    option,
                    reason,
                    onResult: Some({ result =>
                        handleDeferredFailoverOutcome(appRef, result, config)
                    })
                )
            )
        }
        return Some(runKModeFailover(option, reason))
    }
    None
}

func handleRestartDecision(
    ctx: Ctx,
    e: Exception,
    result: KModeFailoverResult,
    config: RecoverConfig
): Unit {
    annotateFailoverContext(ctx, result)
    println("[Ignite Recovery] KMode failover decision=restart attempts=${result.attempts} lastStatus=${result.lastStatus}")
    let _ = ctx.status(503).sendString("Service Restart Requested")
    if (let Some(hook) <- config.onKModeRestart) {
        hook(ctx, e, result)
    } else {
        ctx.app().shutdown()
    }
}

func handleTerminateDecision(
    ctx: Ctx,
    e: Exception,
    result: KModeFailoverResult,
    config: RecoverConfig
): Unit {
    annotateFailoverContext(ctx, result)
    println("[Ignite Recovery] KMode failover decision=terminate attempts=${result.attempts} lastStatus=${result.lastStatus}")
    let _ = ctx.status(503).sendString("Service Terminated by KMode Failover")
    if (let Some(hook) <- config.onKModeTerminate) {
        hook(ctx, e, result)
    } else {
        ctx.app().shutdown()
    }
}

func annotateFailoverContext(ctx: Ctx, result: KModeFailoverResult): Unit {
    ctx.setHeader("x-ignite-failover-decision", result.decision.toString())
    ctx.setHeader("x-ignite-failover-exit-cause", result.exitCause)
    ctx.setHeader("x-ignite-failover-attempts", result.attempts.toString())
    ctx.setHeader("x-ignite-failover-elapsed-ms", result.elapsedMs.toString())
    ctx.setLocal("__ignite_guard_event", "kmode_failover")
    ctx.setLocal("__ignite_guard_exit_cause", result.exitCause)
    ctx.setLocal("__ignite_guard_detail", formatFailoverDetail(result))
}

func shouldHandleGuardActive(result: KModeFailoverResult): Bool {
    result.exitCause == "probe_deferred" ||
    result.exitCause == "single_flight_skip" ||
    result.exitCause == "cooldown_skip" ||
    result.exitCause == "repeat_panic_skip"
}

func handleGuardActiveDecision(ctx: Ctx, result: KModeFailoverResult): Unit {
    annotateFailoverContext(ctx, result)
    println("[Ignite Recovery] KMode failover guard active exitCause=${result.exitCause}")
    let body = guardActiveBody(result.exitCause)
    let _ = ctx.status(503).sendString(body)
}

func guardActiveBody(exitCause: String): String {
    if (exitCause == "probe_deferred") {
        return "Service Failover Probe Scheduled"
    }
    if (exitCause == "cooldown_skip") {
        return "Service Guard Cooling Down"
    }
    if (exitCause == "repeat_panic_skip") {
        return "Repeated Panic Suppressed"
    }
    "Service Guard Active"
}

func handleDeferredFailoverOutcome(app: App, result: KModeFailoverResult, config: RecoverConfig): Unit {
    if (result.decision == KModeFailoverDecision.Restart) {
        println("[Ignite Recovery] Deferred KMode failover decision=restart attempts=${result.attempts} lastStatus=${result.lastStatus}")
        if (let Some(hook) <- config.onKModeRestartAsync) {
            hook(app, result)
        } else {
            app.shutdown()
        }
        return
    }
    if (result.decision == KModeFailoverDecision.Terminate) {
        println("[Ignite Recovery] Deferred KMode failover decision=terminate attempts=${result.attempts} lastStatus=${result.lastStatus}")
        if (let Some(hook) <- config.onKModeTerminateAsync) {
            hook(app, result)
        } else {
            app.shutdown()
        }
    }
}

func formatFailoverDetail(result: KModeFailoverResult): String {
    "decision=${result.decision.toString()};" +
    "exitCause=${result.exitCause};" +
    "attempts=${result.attempts};" +
    "matched=${boolWord(result.matched)};" +
    "lastStatus=${result.lastStatus};" +
    "elapsedMs=${result.elapsedMs}"
}

func boolWord(v: Bool): String {
    if (v) {
        return "true"
    }
    "false"
}
