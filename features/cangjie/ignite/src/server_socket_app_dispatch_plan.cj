package ignite

import std.collection.{ArrayList, HashMap}

enum AppDispatchPlanKind {
    | Matched
    | NotFound
    | MethodNotAllowed
}

class AppDispatchPlan {
    let requestMethod: String
    let requestPath: String
    let kind: AppDispatchPlanKind
    let params: HashMap<String, String>
    let handlers: ArrayList<Handler>
    let route: ?Route
    let allowedMethods: ArrayList<String>

    init(
        requestMethod: String,
        requestPath: String,
        kind: AppDispatchPlanKind,
        params!: HashMap<String, String>,
        handlers!: ArrayList<Handler>,
        route!: ?Route,
        allowedMethods!: ArrayList<String>
    ) {
        this.requestMethod = requestMethod
        this.requestPath = requestPath
        this.kind = kind
        this.params = params
        this.handlers = handlers
        this.route = route
        this.allowedMethods = allowedMethods
    }

    func matched(): Bool {
        match (kind) {
            case AppDispatchPlanKind.Matched => true
            case _ => false
        }
    }

    func kindName(): String {
        dispatchPlanKindName(kind)
    }
}

func resolveAppDispatchPlan(app: App, requestMethod: String, requestPath: String): AppDispatchPlan {
    let result = app.router.matchRoute(requestMethod, requestPath)
    if (result.matched) {
        return AppDispatchPlan(
            requestMethod,
            requestPath,
            AppDispatchPlanKind.Matched,
            params: result.params,
            handlers: result.handlers,
            route: result.route,
            allowedMethods: result.allowedMethods
        )
    }

    let allowMethodsPresent = result.allowedMethods.size > 0
    let kind = if (allowMethodsPresent) {
        AppDispatchPlanKind.MethodNotAllowed
    } else {
        AppDispatchPlanKind.NotFound
    }
    let allowHeader = if (allowMethodsPresent) {
        app.joinAllowHeader(result.allowedMethods)
    } else {
        ""
    }
    let fallback = app.methodSemanticsHandler(requestMethod, requestPath, allowMethodsPresent, allowHeader)
    return AppDispatchPlan(
        requestMethod,
        requestPath,
        kind,
        params: HashMap<String, String>(),
        handlers: app.router.buildGlobalMiddlewareChain(fallback),
        route: None,
        allowedMethods: result.allowedMethods
    )
}

func dispatchPlanKindName(kind: AppDispatchPlanKind): String {
    match (kind) {
        case AppDispatchPlanKind.Matched => "matched"
        case AppDispatchPlanKind.NotFound => "not-found"
        case AppDispatchPlanKind.MethodNotAllowed => "method-not-allowed"
    }
}
