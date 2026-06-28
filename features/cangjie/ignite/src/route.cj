package ignite

import std.collection.{ArrayList, HashMap}

public class Route {
    public var method: String
    public var path: String
    public var handlers: ArrayList<Handler>
    public var paramNames: ArrayList<String>
    public var option: ?RouteOption = None
    public var name: String = ""

    public init(method: String, path: String, handlers: ArrayList<Handler>) {
        this.method = method
        this.path = path
        this.handlers = handlers
        this.paramNames = ArrayList<String>()
        parseParams()
    }

    public func withOption(opt: RouteOption): Route {
        this.option = opt
        this
    }

    public func withName(n: String): Route {
        this.name = n
        this
    }

    func parseParams(): Unit {
        let chars = path.toRuneArray()
        var i: Int64 = 0
        while (i < chars.size) {
            if (chars[i] == r':') {
                var paramName = ""
                i += 1
                while (i < chars.size && chars[i] != r'/') {
                    paramName += chars[i].toString()
                    i += 1
                }
                paramNames.add(paramName)
            } else if (chars[i] == r'*') {
                paramNames.add("*")
                i += 1
            } else {
                i += 1
            }
        }
    }
}

public struct MatchResult {
    public let matched: Bool
    public let params: HashMap<String, String>
    public let handlers: ArrayList<Handler>
    public let route: ?Route
    public let allowedMethods: ArrayList<String>

    public init(
        matched!: Bool,
        params!: HashMap<String, String>,
        handlers!: ArrayList<Handler>,
        route!: ?Route,
        allowedMethods!: ArrayList<String> = ArrayList<String>()
    ) {
        this.matched = matched
        this.params = params
        this.handlers = handlers
        this.route = route
        this.allowedMethods = allowedMethods
    }

    public static func notFound(allowedMethods!: ArrayList<String> = ArrayList<String>()): MatchResult {
        MatchResult(
            matched: false,
            params: HashMap<String, String>(),
            handlers: ArrayList<Handler>(),
            route: None,
            allowedMethods: allowedMethods
        )
    }
}
