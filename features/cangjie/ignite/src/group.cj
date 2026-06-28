package ignite

import std.collection.ArrayList

public class Group {
    let _app: App
    let _prefix: String
    let _middlewares: ArrayList<Handler> = ArrayList<Handler>()
    let _parent: ?Group

    public init(app: App, prefix: String, parent!: ?Group = None) {
        this._app = app
        this._prefix = prefix
        this._parent = parent
    }

    public prop prefix: String {
        get() { _prefix }
    }

    // ── HTTP method routes ──

    public func get(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("GET", path, handler, option)
    }

    public func get(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("GET", path, handlers, option)
    }

    public func post(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("POST", path, handler, option)
    }

    public func post(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("POST", path, handlers, option)
    }

    public func put(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("PUT", path, handler, option)
    }

    public func put(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("PUT", path, handlers, option)
    }

    public func delete(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("DELETE", path, handler, option)
    }

    public func delete(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("DELETE", path, handlers, option)
    }

    public func patch(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("PATCH", path, handler, option)
    }

    public func patch(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("PATCH", path, handlers, option)
    }

    public func head(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("HEAD", path, handler, option)
    }

    public func head(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("HEAD", path, handlers, option)
    }

    public func options(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        addRoute("OPTIONS", path, handler, option)
    }

    public func options(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        addRoute("OPTIONS", path, handlers, option)
    }

    public func all(path: String, handler: Handler, option!: ?RouteOption = None): Group {
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
        for (method in methods) {
            addRoute(method, path, handler, option)
        }
        this
    }

    public func all(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): Group {
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
        for (method in methods) {
            addRoute(method, path, handlers, option)
        }
        this
    }

    // ── WebSocket ──

    public func ws(path: String, handler: WsHandler): Group {
        let fullPath = joinPath(_prefix, path)
        let wsFunc: Handler = { ctx: Ctx =>
            try {
                let conn = ctx.upgradeWebSocket()
                handler(conn)
            } catch (e: Exception) {
                println("[Ignite] WebSocket error: ${e.message}")
            }
        }
        let allHandlers = ArrayList<Handler>()
        collectMiddlewares(allHandlers)
        allHandlers.add(wsFunc)
        _app.router.addRoute("GET", fullPath, allHandlers)
        this
    }

    // ── Middleware (prepended to each route in this group; order: parent middlewares → this group middlewares → route handler) ──

    public func use(handler: Handler): Group {
        _middlewares.add(handler)
        this
    }

    public func use(handlers: Array<Handler>): Group {
        for (h in handlers) {
            _middlewares.add(h)
        }
        this
    }

    // ── Sub-groups ──

    public func group(prefix: String): Group {
        let fullPrefix = joinPath(_prefix, prefix)
        let g = Group(_app, fullPrefix, parent: this)
        for (mw in _middlewares) {
            g._middlewares.add(mw)
        }
        g
    }

    // ── Route registration helper ──

    func addRoute(method: String, path: String, handler: Handler, option: ?RouteOption): Group {
        let fullPath = joinPath(_prefix, path)
        let allHandlers = ArrayList<Handler>()
        collectMiddlewares(allHandlers)
        allHandlers.add(handler)
        _app.router.addRoute(method, fullPath, allHandlers, option: option)
        this
    }

    func addRoute(method: String, path: String, handlers: Array<Handler>, option: ?RouteOption): Group {
        if (handlers.size == 0) {
            throw Exception("[Ignite] Route handlers array must contain at least one handler.")
        }
        let fullPath = joinPath(_prefix, path)
        let allHandlers = ArrayList<Handler>()
        collectMiddlewares(allHandlers)
        for (handler in handlers) {
            allHandlers.add(handler)
        }
        _app.router.addRoute(method, fullPath, allHandlers, option: option)
        this
    }

    func collectMiddlewares(target: ArrayList<Handler>): Unit {
        if (let Some(p) <- _parent) {
            p.collectMiddlewares(target)
        }
        for (mw in _middlewares) {
            target.add(mw)
        }
    }

    func joinPath(prefix: String, path: String): String {
        if (prefix.size == 0) {
            return path
        }
        if (path.size == 0) {
            return prefix
        }
        let prefixRunes = prefix.toRuneArray()
        let pathRunes = path.toRuneArray()
        let prefixEndsSlash = prefixRunes[prefixRunes.size - 1] == r'/'
        let pathStartsSlash = pathRunes[0] == r'/'

        if (prefixEndsSlash && pathStartsSlash) {
            var result = prefix
            for (i in 1..pathRunes.size) {
                result += pathRunes[i].toString()
            }
            return result
        }
        if (!prefixEndsSlash && !pathStartsSlash) {
            return prefix + "/" + path
        }
        prefix + path
    }
}
