package ignite

import std.collection.{ArrayList, HashMap}
import std.unicode.*

enum NodeType {
    | Static
    | Param
    | CatchAll
}

class TrieNode {
    var nodeType: NodeType = Static
    var segment: String = ""
    var paramName: String = ""
    var children: ArrayList<TrieNode> = ArrayList<TrieNode>()
    var staticChildMap: HashMap<String, TrieNode> = HashMap<String, TrieNode>()
    var paramChild: ?TrieNode = None
    var catchAllChild: ?TrieNode = None
    var handlersMap: HashMap<String, ArrayList<Handler>> = HashMap<String, ArrayList<Handler>>()
    var routeMap: HashMap<String, Route> = HashMap<String, Route>()
    var middlewares: ArrayList<Handler> = ArrayList<Handler>()

    init() {}

    init(nodeType: NodeType, segment: String) {
        this.nodeType = nodeType
        this.segment = segment
    }

    func addHandler(method: String, handlers: ArrayList<Handler>, route: Route): Unit {
        handlersMap.add(method, handlers)
        routeMap.add(method, route)
    }

    func removeHandler(method: String): Bool {
        match (handlersMap.get(method)) {
            case Some(_) =>
                let _ = handlersMap.remove(method)
                let _ = routeMap.remove(method)
                true
            case None => false
        }
    }

    func getHandler(method: String): ?(ArrayList<Handler>, Route) {
        match (handlersMap.get(method)) {
            case Some(h) =>
                match (routeMap.get(method)) {
                    case Some(r) => Some((h, r))
                    case None => None
                }
            case None => None
        }
    }

    func addStaticChild(child: TrieNode): Unit {
        staticChildMap.add(child.segment, child)
        children.add(child)
    }

    func findStaticChild(seg: String): ?TrieNode {
        staticChildMap.get(seg)
    }
}

public class Router {
    let root: TrieNode = TrieNode()
    let config: Config
    let allRoutes: ArrayList<Route> = ArrayList<Route>()
    var globalMiddlewares: ArrayList<Handler> = ArrayList<Handler>()

    public init(config: Config) {
        this.config = config
    }

    public func addRoute(method: String, path: String, handlers: ArrayList<Handler>, option!: ?RouteOption = None): Route {
        let normalizedMethod = method.trimAscii().toAsciiUpper()
        let normalizedPath = normalizePath(path)
        let segments = splitPath(normalizedPath)

        if (!config.allowRouteOverwrite) {
            match (findRoute(normalizedMethod, normalizedPath)) {
                case Some(_) =>
                    throw Exception("[Ignite] Route conflict: ${normalizedMethod} ${normalizedPath} already registered. Set Config.allowRouteOverwrite=true to allow override.")
                case None => ()
            }
        }

        var current = root

        for (seg in segments) {
            if (seg.size == 0) { continue }
            if (seg.size > 0 && seg.toRuneArray()[0] == r':') {
                let runes = seg.toRuneArray()
                var paramName = ""
                for (i in 1..runes.size) {
                    paramName += runes[i].toString()
                }
                match (current.paramChild) {
                    case Some(child) => current = child
                    case None =>
                        let child = TrieNode(Param, seg)
                        child.paramName = paramName
                        current.paramChild = child
                        current = child
                }
            } else if (seg == "*") {
                match (current.catchAllChild) {
                    case Some(child) => current = child
                    case None =>
                        let child = TrieNode(CatchAll, seg)
                        child.paramName = "*"
                        current.catchAllChild = child
                        current = child
                }
            } else {
                match (current.findStaticChild(seg)) {
                    case Some(child) => current = child
                    case None =>
                        let child = TrieNode(Static, seg)
                        current.addStaticChild(child)
                        current = child
                }
            }
        }

        let route = Route(normalizedMethod, normalizedPath, handlers)
        if (let Some(opt) <- option) {
            route.option = opt
            let opId = opt.operationId.trimAscii()
            if (opId.size > 0) {
                route.name = opId
            }
        }
        current.addHandler(normalizedMethod, handlers, route)
        allRoutes.add(route)
        route
    }

    public func removeRoute(method: String, path: String): Bool {
        let normalizedMethod = method.trimAscii().toAsciiUpper()
        let normalizedPath = normalizePath(path)
        let segments = splitPath(normalizedPath)
        var current = root

        for (seg in segments) {
            if (seg.size == 0) { continue }
            if (seg.size > 0 && seg.toRuneArray()[0] == r':') {
                match (current.paramChild) {
                    case Some(child) => current = child
                    case None => return false
                }
            } else if (seg == "*") {
                match (current.catchAllChild) {
                    case Some(child) => current = child
                    case None => return false
                }
            } else {
                match (current.findStaticChild(seg)) {
                    case Some(child) => current = child
                    case None => return false
                }
            }
        }

        let removed = current.removeHandler(normalizedMethod)
        if (removed) {
            var i: Int64 = 0
            while (i < allRoutes.size) {
                let r = allRoutes[i]
                if (r.method == normalizedMethod && r.path == normalizedPath) {
                    let _ = allRoutes.remove(at: i)
                    break
                }
                i += 1
            }
        }
        removed
    }

    func findRoute(method: String, path: String): ?Route {
        let normalizedPath = normalizePath(path)
        let segments = splitPath(normalizedPath)
        var current = root

        for (seg in segments) {
            if (seg.size == 0) { continue }
            if (seg.size > 0 && seg.toRuneArray()[0] == r':') {
                match (current.paramChild) {
                    case Some(child) => current = child
                    case None => return None
                }
            } else if (seg == "*") {
                match (current.catchAllChild) {
                    case Some(child) => current = child
                    case None => return None
                }
            } else {
                match (current.findStaticChild(seg)) {
                    case Some(child) => current = child
                    case None => return None
                }
            }
        }

        current.routeMap.get(method)
    }

    public func matchRoute(method: String, path: String): MatchResult {
        let normalizedMethod = method.trimAscii().toAsciiUpper()
        let normalizedPath = normalizePath(path)
        let exactResult = matchRouteExact(normalizedMethod, normalizedPath)
        if (exactResult.matched) {
            return exactResult
        }
        let allowed = allowedMethodsForPath(normalizedPath)
        for (allowedMethod in allowed) {
            if (allowedMethod == normalizedMethod) {
                return MatchResult.notFound()
            }
        }
        MatchResult.notFound(allowedMethods: allowed)
    }

    func matchRouteExact(method: String, normalizedPath: String): MatchResult {
        let segments = splitPath(normalizedPath)
        let params = HashMap<String, String>()
        let result = matchNode(root, segments, 0, method, params)
        result
    }

    func matchNode(
        node: TrieNode,
        segments: ArrayList<String>,
        index: Int64,
        method: String,
        params: HashMap<String, String>
    ): MatchResult {
        if (index >= segments.size) {
            if (let Some(result) <- buildNodeMatchResult(node, method, params)) {
                return result
            }
            if (let Some(result) <- buildCatchAllMatchResult(node, segments, index, method, params)) {
                return result
            }
            return MatchResult.notFound()
        }

        let seg = segments[index]
        if (seg.size == 0) {
            return matchNode(node, segments, index + 1, method, params)
        }

        for (child in node.children) {
            if (matchSegment(child.segment, seg)) {
                let result = matchNode(child, segments, index + 1, method, params)
                if (result.matched) {
                    return result
                }
            }
        }

        if (let Some(paramChild) <- node.paramChild) {
            params.add(paramChild.paramName, seg)
            let result = matchNode(paramChild, segments, index + 1, method, params)
            if (result.matched) {
                return result
            }
            params.remove(paramChild.paramName)
        }

        if (let Some(result) <- buildCatchAllMatchResult(node, segments, index, method, params)) {
            return result
        }

        MatchResult.notFound()
    }

    func buildNodeMatchResult(
        node: TrieNode,
        method: String,
        params: HashMap<String, String>
    ): ?MatchResult {
        match (node.getHandler(method)) {
            case Some((handlers, route)) =>
                if (!validateParams(params, route)) {
                    return None
                }
                let allHandlers = buildHandlerChain(handlers)
                Some(MatchResult(
                    matched: true,
                    params: params,
                    handlers: allHandlers,
                    route: route,
                    allowedMethods: ArrayList<String>()
                ))
            case None => None
        }
    }

    func buildCatchAllMatchResult(
        node: TrieNode,
        segments: ArrayList<String>,
        index: Int64,
        method: String,
        params: HashMap<String, String>
    ): ?MatchResult {
        if (let Some(catchAllChild) <- node.catchAllChild) {
            let remaining = joinRemainingSegments(segments, index)
            params.add("*", remaining)
            match (catchAllChild.getHandler(method)) {
                case Some((handlers, route)) =>
                    if (!validateParams(params, route)) {
                        let _ = params.remove("*")
                        return None
                    }
                    let allHandlers = buildHandlerChain(handlers)
                    return Some(MatchResult(
                        matched: true,
                        params: params,
                        handlers: allHandlers,
                        route: route,
                        allowedMethods: ArrayList<String>()
                    ))
                case None =>
                    let _ = params.remove("*")
                    return None
            }
        }
        None
    }

    func joinRemainingSegments(segments: ArrayList<String>, index: Int64): String {
        if (index >= segments.size) {
            return ""
        }
        var remaining = ""
        for (i in index..segments.size) {
            if (i > index) {
                remaining += "/"
            }
            remaining += segments[i]
        }
        remaining
    }

    func allowedMethodsForPath(normalizedPath: String): ArrayList<String> {
        let segments = splitPath(normalizedPath)
        let methodSet = HashMap<String, Bool>()
        collectAllowedMethods(root, segments, 0, methodSet)
        orderedMethods(methodSet)
    }

    func collectAllowedMethods(
        node: TrieNode,
        segments: ArrayList<String>,
        index: Int64,
        methodSet: HashMap<String, Bool>
    ): Unit {
        if (index >= segments.size) {
            for ((method, _handlers) in node.handlersMap) {
                methodSet.add(method, true)
            }
            if (let Some(catchAllChild) <- node.catchAllChild) {
                for ((method, _handlers) in catchAllChild.handlersMap) {
                    methodSet.add(method, true)
                }
            }
            return
        }

        let seg = segments[index]
        if (seg.size == 0) {
            collectAllowedMethods(node, segments, index + 1, methodSet)
            return
        }

        for (child in node.children) {
            if (matchSegment(child.segment, seg)) {
                collectAllowedMethods(child, segments, index + 1, methodSet)
            }
        }

        if (let Some(paramChild) <- node.paramChild) {
            collectAllowedMethods(paramChild, segments, index + 1, methodSet)
        }

        if (let Some(catchAllChild) <- node.catchAllChild) {
            for ((method, _handlers) in catchAllChild.handlersMap) {
                methodSet.add(method, true)
            }
        }
    }

    func orderedMethods(methodSet: HashMap<String, Bool>): ArrayList<String> {
        let ordered = ArrayList<String>()
        let preferred = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
        for (method in preferred) {
            if (methodSet.contains(method)) {
                ordered.add(method)
            }
        }
        for ((method, _enabled) in methodSet) {
            if (!containsString(ordered, method)) {
                ordered.add(method)
            }
        }
        ordered
    }

    func containsString(values: ArrayList<String>, target: String): Bool {
        for (item in values) {
            if (item == target) {
                return true
            }
        }
        false
    }

    func buildHandlerChain(routeHandlers: ArrayList<Handler>): ArrayList<Handler> {
        let chain = ArrayList<Handler>()
        for (mw in globalMiddlewares) {
            chain.add(mw)
        }
        for (h in routeHandlers) {
            chain.add(h)
        }
        chain
    }

    public func addGlobalMiddleware(handler: Handler): Unit {
        globalMiddlewares.add(handler)
    }

    public func buildGlobalMiddlewareChain(finalHandler: Handler): ArrayList<Handler> {
        let chain = ArrayList<Handler>()
        for (mw in globalMiddlewares) {
            chain.add(mw)
        }
        chain.add(finalHandler)
        chain
    }

    func matchSegment(pattern: String, actual: String): Bool {
        if (config.caseSensitive) {
            pattern == actual
        } else {
            pattern.toLower() == actual.toLower()
        }
    }

    func normalizePath(path: String): String {
        var p = path
        if (p.size == 0) { return "/" }
        let runes = p.toRuneArray()
        if (runes[0] != r'/') {
            p = "/" + p
        }
        var result = ""
        var i: Int64 = 0
        let chars = p.toRuneArray()
        var needSlash = false
        while (i < chars.size) {
            if (chars[i] == r'/') {
                needSlash = true
                while (i + 1 < chars.size && chars[i + 1] == r'/') {
                    i += 1
                }
            } else {
                if (needSlash && result.size > 0) {
                    result += "/"
                }
                needSlash = false
                result += chars[i].toString()
            }
            i += 1
        }
        p = if (result.size == 0) { "/" } else { "/" + result }
        if (!config.strictRouting && p.size > 1) {
            let r = p.toRuneArray()
            if (r[r.size - 1] == r'/') {
                var trim = ""
                for (j in 0..r.size - 1) {
                    trim += r[j].toString()
                }
                p = trim
            }
        }
        p
    }

    func splitPath(path: String): ArrayList<String> {
        let segments = ArrayList<String>()
        let chars = path.toRuneArray()
        var current = ""
        var i: Int64 = 0
        if (chars.size > 0 && chars[0] == r'/') {
            i = 1
        }
        while (i < chars.size) {
            if (chars[i] == r'/') {
                if (current.size > 0) {
                    segments.add(current)
                    current = ""
                }
                while (i + 1 < chars.size && chars[i + 1] == r'/') {
                    i += 1
                }
            } else {
                current += chars[i].toString()
            }
            i += 1
        }
        if (current.size > 0) {
            segments.add(current)
        }
        segments
    }

    public func getRoutes(): ArrayList<Route> {
        allRoutes
    }

    public func setRouteName(method: String, path: String, name: String): Bool {
        let normalizedMethod = method.trimAscii().toAsciiUpper()
        let normalizedPath = normalizePath(path)
        let routeName = name.trimAscii()
        if (routeName.size == 0) {
            return false
        }
        for (route in allRoutes) {
            if (route.method == normalizedMethod && route.path == normalizedPath) {
                route.name = routeName
                return true
            }
        }
        false
    }

    public func findRouteByName(name: String): ?Route {
        let routeName = name.trimAscii()
        if (routeName.size == 0) {
            return None
        }

        for (route in allRoutes) {
            if (route.name == routeName) {
                return Some(route)
            }
        }

        for (route in allRoutes) {
            match (route.option) {
                case Some(opt) =>
                    if (opt.operationId.trimAscii() == routeName) {
                        return Some(route)
                    }
                case None => ()
            }
        }
        None
    }

    public func printRoutes(): Unit {
        println("┌───────────┬─────────────────────────────────┐")
        println("│  Method   │  Path                           │")
        println("├───────────┼─────────────────────────────────┤")
        for (route in allRoutes) {
            let m = padRight(route.method, 9)
            let p = padRight(route.path, 33)
            println("│ ${m} │ ${p} │")
        }
        println("└───────────┴─────────────────────────────────┘")
    }

    func padRight(s: String, width: Int64): String {
        var result = s
        while (result.size < width) {
            result += " "
        }
        result
    }
}

func validateParams(params: HashMap<String, String>, route: Route): Bool {
    match (route.option) {
        case Some(opt) =>
            for ((name, pattern) in opt.paramValidations) {
                match (params.get(name)) {
                    case Some(value) =>
                        if (!validateParamValue(value, pattern)) {
                            return false
                        }
                    case None => ()
                }
            }
            true
        case None => true
    }
}

func validateParamValue(value: String, pattern: String): Bool {
    let p = pattern.toLower()
    if (p == "int") {
        if (value.size == 0) { return false }
        let runes = value.toRuneArray()
        var start = 0
        if (runes[0] == r'-') {
            if (runes.size == 1) { return false }
            start = 1
        }
        for (i in start..runes.size) {
            let c = runes[i]
            if (c < r'0' || c > r'9') { return false }
        }
        return true
    }
    if (p == "uint") {
        if (value.size == 0) { return false }
        for (ch in value.toRuneArray()) {
            if (ch < r'0' || ch > r'9') { return false }
        }
        return true
    }
    if (p == "num") {
        if (value.size == 0) { return false }
        var dotSeen = false
        for (ch in value.toRuneArray()) {
            if (ch == r'.') {
                if (dotSeen) { return false }
                dotSeen = true
            } else if (ch < r'0' || ch > r'9') {
                return false
            }
        }
        return true
    }
    if (p == "alpha") {
        if (value.size == 0) { return false }
        for (ch in value.toRuneArray()) {
            let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z')
            if (!ok) { return false }
        }
        return true
    }
    if (p == "alnum") {
        if (value.size == 0) { return false }
        for (ch in value.toRuneArray()) {
            let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')
            if (!ok) { return false }
        }
        return true
    }
    if (p == "uuid") {
        let runes = value.toRuneArray()
        if (runes.size != 36) { return false }
        let dashPos = [8, 13, 18, 23]
        for (idx in 0..36) {
            let c = runes[idx]
            if (idx == 8 || idx == 13 || idx == 18 || idx == 23) {
                if (c != r'-') { return false }
            } else {
                let hex = (c >= r'0' && c <= r'9') || (c >= r'a' && c <= r'f') || (c >= r'A' && c <= r'F')
                if (!hex) { return false }
            }
        }
        return true
    }
    true
}
