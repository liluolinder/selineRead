package ignite

func prepareCurrentCarrierDispatchContext(
    app: App,
    currentRequestCarrier: CurrentRequestCarrier,
    plan: AppDispatchPlan
): ?Ctx {
    let ctx = Ctx(currentRequestCarrier, app)
    ctx.setParams(plan.params)
    ctx.setHandlers(plan.handlers)

    if (plan.matched()) {
        if (let Some(route) <- plan.route) {
            ctx.setRoute(route)
        }
        if (app.maybeHandleTestOption(ctx)) {
            return None
        }
    }

    Some(ctx)
}

func executePreparedCurrentCarrierDispatch(app: App, ctx: Ctx): Unit {
    try {
        ctx.next()
    } catch (e: BufferedRequestBodyTooLargeException) {
        if (let Some(errorHandler) <- app._errorHandler) {
            errorHandler(ctx, e)
        } else {
            let carrier = ctx.currentRequestCarrier()
            carrier.setResponseStatus(413)
            carrier.setResponseHeader("content-type", "text/plain; charset=utf-8")
            carrier.setResponseString("Payload Too Large")
        }
    } catch (e: Exception) {
        if (app.config.kmode) {
            if (let Some(kmodePanicHandler) <- app.config.kmodePanicHandler) {
                if (kmodePanicHandler(ctx, e)) {
                    return
                }
            }
        }
        if (let Some(errorHandler) <- app._errorHandler) {
            errorHandler(ctx, e)
        } else {
            let carrier = ctx.currentRequestCarrier()
            carrier.setResponseStatus(500)
            carrier.setResponseHeader("content-type", "text/plain; charset=utf-8")
            carrier.setResponseString("Internal Server Error")
        }
    }
}
