package ignite.middleware

import ignite.{Handler, Ctx}
import std.collection.ArrayList

public class RewriteConfig {
    public var rules: Array<(String, String)>

    public init(rules: Array<(String, String)>) {
        this.rules = rules
    }
}

public func rewriteMiddleware(config: RewriteConfig): Handler {
    { ctx: Ctx =>
        let path = ctx.path
        for ((from, to) in config.rules) {
            if (path == from) {
                let newPath = normalizeRewriteTarget(to)
                if (newPath.size > 0 && newPath != path) {
                    ctx.setLocal("_rewrite_from", path)
                    ctx.setLocal("_rewrite_to", newPath)
                    if (!applyRewriteMatch(ctx, newPath)) {
                        return
                    }
                }
                break
            }
            if (strStartsWith(path, from)) {
                let rest = substringFrom(path, from.size)
                let newPath = normalizeRewriteTarget(to + rest)
                if (newPath.size > 0 && newPath != path) {
                    ctx.setLocal("_rewrite_from", path)
                    ctx.setLocal("_rewrite_to", newPath)
                    if (!applyRewriteMatch(ctx, newPath)) {
                        return
                    }
                }
                break
            }
        }
        ctx.next()
    }
}

func applyRewriteMatch(ctx: Ctx, newPath: String): Bool {
    let currentIndex = ctx.handlerIndex()
    let result = ctx.app().router.matchRoute(ctx.method, newPath)
    ctx.overridePath(newPath)
    if (result.matched) {
        ctx.setParams(result.params)
        ctx.setHandlers(result.handlers)
        if (let Some(route) <- result.route) {
            ctx.setRoute(route)
        }
        ctx.setHandlerIndex(currentIndex)
        return true
    }

    if (result.allowedMethods.size > 0) {
        let allowValue = joinAllowedMethods(result.allowedMethods)
        if (allowValue.size > 0) {
            ctx.setHeader("allow", allowValue)
        }
        _ = ctx.status(405).sendString("Method Not Allowed")
        return false
    }

    _ = ctx.sendStatus(404)
    false
}

func normalizeRewriteTarget(raw: String): String {
    let trimmed = raw.trimAscii()
    if (trimmed.size == 0) {
        return ""
    }
    if (trimmed.startsWith("/")) {
        return trimmed
    }
    "/" + trimmed
}

func joinAllowedMethods(methods: ArrayList<String>): String {
    var out = ""
    var i: Int64 = 0
    while (i < methods.size) {
        if (i > 0) {
            out += ", "
        }
        out = out + methods[i]
        i += 1
    }
    out
}
