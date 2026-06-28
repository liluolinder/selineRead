package ignite

import std.collection.ArrayList
import std.env.*
import std.fs.{Directory, exists, File, FileInfo, OpenMode, Path, removeIfExists}
import std.io.InputStream
import std.sync.Mutex
import stdx.net.http.{
    HttpRequestBuilder,
    HttpHeaders, ClientBuilder, Client
}
import ignite.api2

let _inprocTestPortPlannerMutex = Mutex()
let _reservedInprocTestPorts = ArrayList<UInt16>()
var _inprocTestPortPlannerNonce: Int64 = 0

public class AppTestResponse {
    public let status: UInt16
    public let body: String
    public let headers: HttpHeaders

    public init(status: UInt16, body: String, headers: HttpHeaders) {
        this.status = status
        this.body = body
        this.headers = headers
    }

    public func header(name: String): ?String {
        headers.getFirst(name)
    }
}

public class App {
    public let config: Config
    public let router: Router
    var _engine: ServerEngine = StdxServerEngine()
    var _swaggerInfo: SwaggerInfo = SwaggerInfo()
    var _errorHandler: ?ErrorHandler = None
    var _shutdownHooks: ArrayList<() -> Unit> = ArrayList<() -> Unit>()
    var _startupObserveHooks: ArrayList<ServerStartupObserveHook> = ArrayList<ServerStartupObserveHook>()
    var _jinguiAcceptedTransportSessionHooks:
        ArrayList<ServerJinguiAcceptedTransportSessionHook> =
            ArrayList<ServerJinguiAcceptedTransportSessionHook>()
    var _swaggerJsonCache: ?String = None
    var _swaggerHtmlCache: ?String = None
    var _swaggerRouteInstalled: Bool = false
    var _lastServerTransportTouchpoint: ?ServerTransportTouchpoint = None
    var _lastServerStartupObserveEvent: ?ServerStartupObserveEvent = None
    var _lastJinguiAcceptedTransportSessionSnapshot:
        ?ServerJinguiAcceptedTransportSessionSnapshot = None
    var _notFoundHandler: ?Handler = None
    var _methodNotAllowedHandler: ?Handler = None
    var _networkMonitorStopSignal: ?NetworkMonitorStopSignal = None

    public init(config!: Config = Config()) {
        this.config = config
        this.router = Router(config)
    }

    public static func create(config!: Config = Config()): App {
        App(config: config)
    }

    // ── HTTP method routes ──

    public func get(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("GET", path, wrapSingle(handler), option)
        this
    }

    public func get(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("GET", path, wrapMany(handlers), option)
        this
    }

    public func post(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("POST", path, wrapSingle(handler), option)
        this
    }

    public func post(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("POST", path, wrapMany(handlers), option)
        this
    }

    public func put(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("PUT", path, wrapSingle(handler), option)
        this
    }

    public func put(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("PUT", path, wrapMany(handlers), option)
        this
    }

    public func delete(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("DELETE", path, wrapSingle(handler), option)
        this
    }

    public func delete(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("DELETE", path, wrapMany(handlers), option)
        this
    }

    public func patch(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("PATCH", path, wrapSingle(handler), option)
        this
    }

    public func patch(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("PATCH", path, wrapMany(handlers), option)
        this
    }

    public func head(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("HEAD", path, wrapSingle(handler), option)
        this
    }

    public func head(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("HEAD", path, wrapMany(handlers), option)
        this
    }

    public func options(path: String, handler: Handler, option!: ?RouteOption = None): App {
        registerRoute("OPTIONS", path, wrapSingle(handler), option)
        this
    }

    public func options(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        registerRoute("OPTIONS", path, wrapMany(handlers), option)
        this
    }

    public func all(path: String, handler: Handler, option!: ?RouteOption = None): App {
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
        for (method in methods) {
            registerRoute(method, path, wrapSingle(handler), option)
        }
        this
    }

    public func all(path: String, handlers: Array<Handler>, option!: ?RouteOption = None): App {
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
        let wrapped = wrapMany(handlers)
        for (method in methods) {
            registerRoute(method, path, cloneHandlers(wrapped), option)
        }
        this
    }

    // ── Static file serving ──

    public func `static`(prefix: String, root: String): App {
        let rootDir = root
        let catchAllPath = if (prefix.size > 0 && prefix.toRuneArray()[prefix.size - 1] == r'/') {
            prefix + "*"
        } else {
            prefix + "/*"
        }
        router.addRoute("GET", catchAllPath, wrapSingle({ ctx: Ctx =>
            let filePath = ctx.params("*")
            if (let Some(fullPath) <- resolveStaticAssetPath(rootDir, filePath)) {
                ctx.sendFile(fullPath)
            } else {
                ctx.sendStatus(404)
            }
        }))
        this
    }

    /// 静态优先 + SPA 回退：先按路径尝试发送静态文件，不存在则发送 indexFile（如 index.html），兜住所有请求转发前端。
    /// 适用于 Next.js 静态导出、Vite/React 等前端；子路径如 login/_xxxxx.txt 会按 root 下相对路径解析。
    /// 路径安全：拒绝含 ".." 的请求，回退到 indexFile。
    public func staticSpa(prefix: String, root: String, indexFile!: String = "index.html"): App {
        let rootDir = root
        let fallbackPath = rootDir + "/" + indexFile
        let serveFallback: Handler = { ctx: Ctx => ctx.sendFile(fallbackPath) }
        let normalizedPrefix = if (prefix.size > 0 && prefix.toRuneArray()[prefix.size - 1] == r'/') {
            let runes = prefix.toRuneArray()
            var s = ""
            for (i in 0..runes.size - 1) { s += runes[i].toString() }
            if (s.size == 0) { "/" } else { s }
        } else {
            prefix
        }
        if (normalizedPrefix == "/" || normalizedPrefix.size == 0) {
            router.addRoute("GET", "/", wrapSingle(serveFallback))
            router.addRoute("HEAD", "/", wrapSingle(serveFallback))
        }
        let catchAllPath = if (normalizedPrefix.size > 0 && normalizedPrefix.toRuneArray()[normalizedPrefix.size - 1] == r'/') {
            normalizedPrefix + "*"
        } else {
            normalizedPrefix + "/*"
        }
        let handler: Handler = { ctx: Ctx =>
            let filePath = ctx.params("*")
            if (let None <- normalizeStaticAssetRequestPath(filePath)) {
                ctx.sendFile(fallbackPath)
                return
            }
            let fullPath = resolveStaticAssetPath(rootDir, filePath) ?? fallbackPath
            let shouldServeStatic = if (exists(fullPath)) {
                let fileInfo = FileInfo(fullPath)
                !fileInfo.isDirectory()
            } else {
                false
            }
            if (shouldServeStatic) {
                ctx.sendFile(fullPath)
            } else {
                ctx.sendFile(fallbackPath)
            }
        }
        router.addRoute("GET", catchAllPath, wrapSingle(handler))
        router.addRoute("HEAD", catchAllPath, wrapSingle(handler))
        this
    }

    // ── WebSocket ──

    public func ws(path: String, handler: WsHandler): App {
        let wsFunc: Handler = { ctx: Ctx =>
            try {
                let conn = ctx.upgradeWebSocket()
                handler(conn)
            } catch (e: Exception) {
                println("[Ignite] WebSocket error: ${e.message}")
            }
        }
        router.addRoute("GET", path, wrapSingle(wsFunc))
        this
    }

    // ── Middleware ──

    public func use(handler: Handler): App {
        router.addGlobalMiddleware(handler)
        this
    }

    public func use(handlers: Array<Handler>): App {
        for (h in handlers) {
            router.addGlobalMiddleware(h)
        }
        this
    }

    // ── Route groups ──

    public func group(prefix: String): Group {
        Group(this, prefix)
    }

    public func notFound(handler: Handler): App {
        _notFoundHandler = Some(handler)
        this
    }

    public func methodNotAllowed(handler: Handler): App {
        _methodNotAllowedHandler = Some(handler)
        this
    }

    // ── Route management ──

    public func removeRoute(method: String, path: String): Bool {
        let removed = router.removeRoute(method, path)
        if (removed) {
            invalidateSwaggerCache()
        }
        removed
    }

    public func nameRoute(method: String, path: String, name: String): Bool {
        let renamed = router.setRouteName(method, path, name)
        if (renamed) {
            invalidateSwaggerCache()
        }
        renamed
    }

    /// 通过路由名反向生成 URL；优先使用显式 route name，其次使用 RouteOption.operationId。
    /// 若缺少路径参数或路由不存在，返回 None。
    public func urlFor(
        name: String,
        params!: Array<(String, String)> = [],
        query!: Array<(String, String)> = []
    ): ?String {
        match (router.findRouteByName(name)) {
            case Some(route) =>
                if (let Some(path) <- buildPathFromTemplate(route.path, params)) {
                    return Some(appendQueryPairs(path, query))
                }
                None
            case None => None
        }
    }

    // ── Swagger ──

    public func swagger(info: SwaggerInfo): App {
        _swaggerInfo = info
        _swaggerJsonCache = None
        _swaggerHtmlCache = None
        this
    }

    // ── Cache management ──

    public func invalidateSwaggerCache(): Unit {
        _swaggerJsonCache = None
        _swaggerHtmlCache = None
    }

    public func interfaceSpecs(): ArrayList<InterfaceSpec> {
        let specs = ArrayList<InterfaceSpec>()
        for (route in router.getRoutes()) {
            match (route.option) {
                case Some(opt) =>
                    if (opt.hidden) {
                        continue
                    }
                case None => ()
            }
            specs.add(buildInterfaceSpec(route))
        }
        specs
    }

    // ── Error handling ──

    public func onError(handler: ErrorHandler): App {
        _errorHandler = handler
        this
    }

    // ── Shutdown hooks ──

    public func onShutdown(hook: () -> Unit): App {
        _shutdownHooks.add(hook)
        this
    }

    public func onStartupObserve(hook: ServerStartupObserveHook): App {
        _startupObserveHooks.add(hook)
        this
    }

    public func onJinguiAcceptedTransportSession(
        hook: ServerJinguiAcceptedTransportSessionHook
    ): App {
        _jinguiAcceptedTransportSessionHooks.add(hook)
        this
    }

    public func serverEngine(engine: ServerEngine): App {
        _engine = engine
        this
    }

    public func withServerEngine(engine: ServerEngine): App {
        serverEngine(engine)
    }

    public func lastServerTransportTouchpoint(): ?ServerTransportTouchpoint {
        _lastServerTransportTouchpoint
    }

    public func lastServerStartupObserveEvent(): ?ServerStartupObserveEvent {
        _lastServerStartupObserveEvent
    }

    public func lastJinguiAcceptedTransportSessionSnapshot():
        ?ServerJinguiAcceptedTransportSessionSnapshot {
        _lastJinguiAcceptedTransportSessionSnapshot
    }

    // ── Server lifecycle ──

    public func listen(addr: String, port: UInt16): Unit {
        setupSwaggerRoute()
        resetStartupObserveState()
        stopNetworkMonitor()

        if (config.enablePrintRoutes) {
            router.printRoutes()
        }

        let hasTls = config.tlsCertFile.size > 0 && config.tlsKeyFile.size > 0
        let scheme = if (hasTls) { "https" } else { "http" }
        let tlsEnabled = hasTls
        let preparedTlsMaterialLoader: ?ServerPreparedTlsMaterialLoader = if (hasTls) {
            Some({
                =>
                api2.loadHttpServerTlsMaterialFromFiles(
                    config.tlsCertFile,
                    config.tlsKeyFile,
                    enablePrecheck: config.enableTlsPrecheck
                )
            })
        } else {
            None
        }
        let appName = config.appName
        let appVersion = config.appVersion
        let routeCount = router.allRoutes.size
        var pidStr = "?"
        try {
            pidStr = "${getProcessId()}"
        } catch (_: Exception) { }
        let currentPid = pidStr
        let transportRoutingBundle = buildServerTransportRoutingBundle(
            addr,
            port,
            hasTls,
            preferredBackendHint: config.serverPreferredBackendHint,
            allowExperimental: config.allowExperimentalServerBackend
        )
        let transportTouchpoint = resolveServerTransportTouchpoint(
            _engine,
            addr,
            port,
            buildServerTransportTouchpoint(transportRoutingBundle)
        )
        let tlsIngressContext = ServerTlsIngressContext(
            transportRoutingBundle,
            transportTouchpoint,
            preparedTlsMaterialLoader: preparedTlsMaterialLoader
        )
        _lastServerTransportTouchpoint = Some(transportTouchpoint)

        let option = ServerEngineListenOption(
            addr,
            port,
            config.readTimeout,
            config.writeTimeout,
            config.readHeaderTimeout,
            config.bodyLimit,
            config.tlsCertFile,
            config.tlsKeyFile,
            config.enableTlsPrecheck,
            serverPreferredBackendHint: config.serverPreferredBackendHint,
            allowExperimentalServerBackend: config.allowExperimentalServerBackend,
            preparedTlsMaterialLoader: preparedTlsMaterialLoader,
            transportRoutingBundle: Some(transportRoutingBundle),
            transportTouchpoint: transportTouchpoint,
            tlsIngressContext: Some(tlsIngressContext),
            jinguiAcceptedTransportSessionHook: Some({ snapshot =>
                notifyJinguiAcceptedTransportSessionSnapshot(snapshot)
            })
        )
        try {
            _engine.listen(
                option,
                this,
                {
                    readySignal =>
                    let networkSelection = api2.resolveBoundNetworkSelection(
                        addr,
                        mode: config.startupNetworkMode,
                        interfaceName: config.startupNetworkInterface
                    )
                    printBanner(
                        appName,
                        appVersion,
                        scheme,
                        addr,
                        port,
                        routeCount,
                        currentPid,
                        tlsEnabled,
                        config.enableSwagger,
                        config.swaggerPath,
                        config.enablePrintSwaggerUrl,
                        config.kmode,
                        config.enableBannerSignature,
                        networkSelection,
                        config.bannerStyle,
                        config.bannerColorMode,
                        config.bannerExtraTags,
                        config.bannerMaxTagLines
                    )
                    maybeStartNetworkMonitor(addr, networkSelection)
                    notifyStartupObserve(
                        ServerStartupObserveEvent(
                            "ready",
                            addr,
                            port,
                            scheme,
                            tlsEnabled,
                            transportTouchpoint: Some(transportTouchpoint),
                            jinguiAttachResultSnapshot: readySignal.jinguiAttachResultSnapshot
                        )
                    )
                }
            )
        } catch (e: api2.TlsConfigLoadException) {
            let snapshot = api2.tlsStartupFailureSnapshot(e)
            println("[Ignite] Failed to start server on ${addr}:${port} - ${e.message}")
            println("[Ignite][TLS] tls_stage=${snapshot.stage} tls_error_code=${snapshot.tlsErrorCode} ignite_error_code=${snapshot.igniteErrorCode} source=${snapshot.sourceCode}")
            println("[Ignite][TLS] hint=${snapshot.hint}")
            notifyStartupObserve(
                ServerStartupObserveEvent(
                    "failed",
                    addr,
                    port,
                    scheme,
                    tlsEnabled,
                    transportTouchpoint: Some(transportTouchpoint),
                    failureStage: snapshot.stage,
                    failureCode: snapshot.tlsErrorCode,
                    igniteErrorCode: snapshot.igniteErrorCode,
                    failureSource: snapshot.sourceCode,
                    hint: snapshot.hint,
                    message: e.message
                )
            )
        } catch (e: Exception) {
            let message = e.message
            let snapshot = api2.serverStartupFailureSnapshot(message)
            println("[Ignite] Failed to start server on ${addr}:${port} - ${message}")
            println("[Ignite][Listen] stage=${snapshot.stage} listen_error_code=${snapshot.listenErrorCode} ignite_error_code=${snapshot.igniteErrorCode}")
            println("[Ignite][Listen] hint=${snapshot.hint}")
            if (snapshot.listenErrorCode == "ADDRESS_IN_USE") {
                println("[Ignite] Hint: port ${port} may already be in use. Try a different port or kill the existing process.")
            }
            notifyStartupObserve(
                ServerStartupObserveEvent(
                    "failed",
                    addr,
                    port,
                    scheme,
                    tlsEnabled,
                    transportTouchpoint: Some(transportTouchpoint),
                    failureStage: snapshot.stage,
                    failureCode: snapshot.listenErrorCode,
                    igniteErrorCode: snapshot.igniteErrorCode,
                    hint: snapshot.hint,
                    message: message
                )
            )
        } finally {
            stopNetworkMonitor()
        }
    }

    /// 无需 listen 的进程内测试入口：会走完整路由与中间件链，并返回可断言的响应快照。
    public func handleForTest(
        method: String,
        path: String,
        body!: String = "",
        headers!: Array<(String, String)> = []
    ): AppTestResponse {
        setupSwaggerRoute()
        let host = "127.0.0.1"
        let claimedPorts = claimInprocTestPorts(method, path)
        try {
            for (port in claimedPorts) {
                resetStartupObserveState()
                let serverFuture = spawn {
                    this.listen(host, port)
                }
                let client = ClientBuilder()
                    .readTimeout(Duration.second * 1)
                    .writeTimeout(Duration.second * 1)
                    .poolSize(2)
                    .build()
                try {
                    if (let Some(event) <- waitForInprocStartupObserve(this, port)) {
                        if (event.phase == "failed") {
                            if (event.failureCode == "ADDRESS_IN_USE") {
                                continue
                            }
                            throw Exception(
                                "handleForTest failed to start path=${path} port=${port} code=${event.failureCode}"
                            )
                        }
                    }
                    return sendHandleForTestRequest(client, method, path, host, port, body, headers)
                } finally {
                    try {
                        client.close()
                    } catch (_: Exception) { }
                    shutdownHandleForTestServer(_engine, serverFuture)
                }
            }
        } finally {
            releaseInprocTestPorts(claimedPorts)
        }
        throw Exception("handleForTest failed to connect path=${path}")
    }

    public func shutdown(): Unit {
        stopNetworkMonitor()
        for (hook in _shutdownHooks) {
            hook()
        }
        _engine.shutdown()
    }

    // ── Internal ──

    func maybeStartNetworkMonitor(
        addr: String,
        initialSelection: api2.StartupNetworkSelection
    ): Unit {
        if (!config.enableNetworkChangeNotice) {
            return
        }
        if (!shouldMonitorBoundAddress(addr, initialSelection)) {
            return
        }
        let stopSignal = NetworkMonitorStopSignal()
        _networkMonitorStopSignal = Some(stopSignal)
        let bindAddr = addr
        let mode = config.startupNetworkMode
        let interfaceName = config.startupNetworkInterface
        spawn {
            var previous = initialSelection
            while (!stopSignal.isStopped()) {
                sleep(Duration.second * 2)
                if (stopSignal.isStopped()) {
                    break
                }
                let current = api2.resolveBoundNetworkSelection(
                    bindAddr,
                    mode: mode,
                    interfaceName: interfaceName
                )
                if (current.fingerprint != previous.fingerprint) {
                    println("[Ignite][Net] " + api2.formatStartupNetworkChangeNotice(previous, current))
                    if (current.warning.size > 0) {
                        println("[Ignite][Net] " + current.warning)
                    }
                    previous = current
                }
            }
        }
    }

    func stopNetworkMonitor(): Unit {
        if (let Some(stopSignal) <- _networkMonitorStopSignal) {
            stopSignal.stop()
            _networkMonitorStopSignal = None
        }
    }

    func wrapSingle(handler: Handler): ArrayList<Handler> {
        let list = ArrayList<Handler>()
        list.add(handler)
        list
    }

    func wrapMany(handlers: Array<Handler>): ArrayList<Handler> {
        if (handlers.size == 0) {
            throw Exception("[Ignite] Route handlers array must contain at least one handler.")
        }
        let list = ArrayList<Handler>()
        for (handler in handlers) {
            list.add(handler)
        }
        list
    }

    func cloneHandlers(handlers: ArrayList<Handler>): ArrayList<Handler> {
        let list = ArrayList<Handler>()
        for (handler in handlers) {
            list.add(handler)
        }
        list
    }

    func registerRoute(
        method: String,
        path: String,
        handlers: ArrayList<Handler>,
        option: ?RouteOption
    ): Unit {
        router.addRoute(method, path, handlers, option: option)
        invalidateSwaggerCache()
    }

    func notifyStartupObserve(event: ServerStartupObserveEvent): Unit {
        _lastServerStartupObserveEvent = Some(event)
        for (hook in _startupObserveHooks) {
            hook(event)
        }
    }

    func notifyJinguiAcceptedTransportSessionSnapshot(
        snapshot: ServerJinguiAcceptedTransportSessionSnapshot
    ): Unit {
        _lastJinguiAcceptedTransportSessionSnapshot = Some(snapshot)
        for (hook in _jinguiAcceptedTransportSessionHooks) {
            hook(snapshot)
        }
    }

    func resetStartupObserveState(): Unit {
        _lastServerStartupObserveEvent = None
        _lastJinguiAcceptedTransportSessionSnapshot = None
    }

    func setupSwaggerRoute(): Unit {
        if (!config.enableSwagger || _swaggerRouteInstalled) {
            return
        }
        let swaggerPath = config.swaggerPath + "/json"
        let appRef = this
        let hiddenSwaggerOption = RouteOption().asHidden()
        router.addRoute("GET", swaggerPath, wrapSingle({ ctx =>
            let forceRefresh = ctx.query("refresh") ?? ""
            if (appRef.config.enableSwaggerCache && forceRefresh != "1") {
                if (let Some(cached) <- appRef._swaggerJsonCache) {
                    ctx.json(cached)
                    return
                }
            }
            let gen = SwaggerGenerator(appRef._swaggerInfo, appRef.router.getRoutes())
            let jsonStr = gen.generate()
            if (appRef.config.enableSwaggerCache) {
                appRef._swaggerJsonCache = jsonStr
            }
            ctx.json(jsonStr)
        }), option: hiddenSwaggerOption)

        let uiPath = config.swaggerPath
        router.addRoute("GET", uiPath, wrapSingle({ ctx =>
            let forceRefresh = ctx.query("refresh") ?? ""
            if (appRef.config.enableSwaggerCache && forceRefresh != "1") {
                if (let Some(cached) <- appRef._swaggerHtmlCache) {
                    ctx.html(cached)
                    return
                }
            }
            let cssUrl = if (appRef.config.swaggerUICssUrl.size > 0) {
                appRef.config.swaggerUICssUrl
            } else {
                defaultSwaggerUICssUrl()
            }
            let jsUrl = if (appRef.config.swaggerUIJsUrl.size > 0) {
                appRef.config.swaggerUIJsUrl
            } else {
                defaultSwaggerUIJsUrl()
            }
            let htmlContent = swaggerUIHtml(appRef.config.swaggerPath, cssUrl, jsUrl)
            if (appRef.config.enableSwaggerCache) {
                appRef._swaggerHtmlCache = htmlContent
            }
            ctx.html(htmlContent)
        }), option: hiddenSwaggerOption)
        _swaggerRouteInstalled = true
    }

    func handleRequest(currentRequestCarrier: CurrentRequestCarrier): Unit {
        let requestMethod = currentRequestCarrier.requestMethod()
        let requestPath = currentRequestCarrier.requestPath()

        if (config.serverHeader.size > 0) {
            currentRequestCarrier.setResponseHeader("server", config.serverHeader)
        }

        let plan = resolveAppDispatchPlan(this, requestMethod, requestPath)
        if (let Some(ctx) <- prepareCurrentCarrierDispatchContext(this, currentRequestCarrier, plan)) {
            executePreparedCurrentCarrierDispatch(this, ctx)
        }
    }

    func maybeHandleTestOption(ctx: Ctx): Bool {
        if (!config.kmode) {
            return false
        }

        let requestedMode = requestedTestMode(ctx)
        if (requestedMode.size == 0) {
            return false
        }

        match (ctx.route()) {
            case Some(route) =>
                match (route.option) {
                    case Some(opt) =>
                        match (opt.testOption) {
                            case Some(testOpt) =>
                                if (!testOpt.enabled) {
                                    return false
                                }
                                let mode = normalizeRequestedTestMode(requestedMode, testOpt)
                                if (mode == "mock") {
                                    if (!testOpt.mock) {
                                        return false
                                    }
                                    ctx.setHeader("x-ignite-self-check", "IGTEST-" + testOpt.versionTag)
                                    ctx.setHeader("x-ignite-self-check-mode", mode)
                                    ctx.setHeader("x-ignite-self-check-route", interfaceSpecName(buildInterfaceSpec(route)))
                                    if (testOpt.mockBody.trimAscii().size > 0) {
                                        _ = ctx.status(200).json(testOpt.mockBody)
                                    } else {
                                        _ = ctx.status(200).json(buildSelfCheckPayload(route, mode, testOpt, ctx))
                                    }
                                    return true
                                }
                                if (mode == "probe") {
                                    if (!testOpt.probe) {
                                        return false
                                    }
                                    ctx.setHeader("x-ignite-self-check", "IGTEST-" + testOpt.versionTag)
                                    ctx.setHeader("x-ignite-self-check-mode", mode)
                                    ctx.setHeader("x-ignite-self-check-route", interfaceSpecName(buildInterfaceSpec(route)))
                                    _ = ctx.status(200).json(buildSelfCheckPayload(route, mode, testOpt, ctx))
                                    return true
                                }
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }
        false
    }

    func methodSemanticsHandler(
        requestMethod: String,
        requestPath: String,
        allowMethodsPresent: Bool,
        allowHeader: String
    ): Handler {
        { ctx: Ctx =>
            if (allowMethodsPresent) {
                if (allowHeader.size > 0) {
                    ctx.setHeader("allow", allowHeader)
                }
                if (requestMethod == "OPTIONS") {
                    let _ = ctx.noContent()
                } else if (let Some(handler) <- _methodNotAllowedHandler) {
                    let _ = ctx.status(405)
                    handler(ctx)
                } else {
                    let _ = ctx.status(405).sendString("Method Not Allowed")
                }
            } else if (let Some(handler) <- _notFoundHandler) {
                let _ = ctx.status(404)
                handler(ctx)
            } else {
                let _ = ctx.status(404).sendString("Cannot ${requestMethod} ${requestPath}")
            }
        }
    }

    func joinAllowHeader(methods: ArrayList<String>): String {
        var first = true
        var out = ""
        for (method in methods) {
            if (!first) {
                out += ", "
            }
            first = false
            out += method
        }
        out
    }
}

func requestedTestMode(ctx: Ctx): String {
    let headerMode = ctx.header("x-ignite-test") ?? ""
    if (headerMode.trimAscii().size > 0) {
        return headerMode.trimAscii()
    }
    let queryMode = ctx.query("__ignite_test") ?? ""
    if (queryMode.trimAscii().size > 0) {
        return queryMode.trimAscii()
    }
    let shortMode = ctx.query("__igtest") ?? ""
    if (shortMode.trimAscii().size > 0) {
        return shortMode.trimAscii()
    }
    ""
}

func normalizeRequestedTestMode(rawMode: String, option: TestOption): String {
    let mode = rawMode.trimAscii().toAsciiLower()
    if (mode == "mock" || mode == "probe") {
        return mode
    }
    if (mode == "1" || mode == "true" || mode == "on" || mode == "yes") {
        if (option.mock) {
            return "mock"
        }
        if (option.probe) {
            return "probe"
        }
    }
    ""
}

func buildSelfCheckPayload(route: Route, mode: String, option: TestOption, ctx: Ctx): String {
    let spec = buildInterfaceSpec(route)
    let fields = ArrayList<String>()
    fields.add("  \"ok\": true")
    fields.add("  \"mark\": " + jsonStringLiteral("IGTEST-" + option.versionTag))
    fields.add("  \"mode\": " + jsonStringLiteral(mode))
    fields.add("  \"method\": " + jsonStringLiteral(spec.method))
    fields.add("  \"path\": " + jsonStringLiteral(spec.path))
    fields.add("  \"interface\": " + jsonStringLiteral(interfaceSpecName(spec)))
    if (spec.summary.trimAscii().size > 0) {
        fields.add("  \"summary\": " + jsonStringLiteral(spec.summary))
    }
    fields.add("  \"storage\": " + jsonStringLiteral(option.storage))
    fields.add("  \"report\": " + jsonStringLiteral(option.report))
    fields.add("  \"probeEnabled\": ${option.probe}")
    fields.add("  \"mockEnabled\": ${option.mock}")
    fields.add("  \"receivedBodyBytes\": ${ctx.bodyBytes().size}")

    match (spec.requestBody) {
        case Some(bodySpec) =>
            fields.add("  \"requestRequired\": ${bodySpec.required}")
            if (bodySpec.contentType.trimAscii().size > 0) {
                fields.add("  \"expectedContentType\": " + jsonStringLiteral(bodySpec.contentType))
            }
        case None => ()
    }

    let expectedStatus = firstResponseStatus(spec.responses)
    if (expectedStatus > 0) {
        fields.add("  \"expectedStatus\": ${expectedStatus}")
    }

    "{\n" + joinJsonFields(fields) + "}"
}

func interfaceSpecName(spec: InterfaceSpec): String {
    let name = spec.name.trimAscii()
    if (name.size > 0) {
        return name
    }
    spec.method + " " + spec.path
}

func firstResponseStatus(responses: ArrayList<ResponseSpec>): Int64 {
    if (responses.size == 0) {
        return 0
    }
    Int64(responses[0].statusCode)
}

func normalizeHttpMethod(method: String): String {
    let m = method.trimAscii().toAsciiUpper()
    if (m.size == 0) {
        return "GET"
    }
    m
}

func normalizeTestUrl(path: String, host: String, port: UInt16): String {
    let trimmed = path.trimAscii()
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
        return trimmed
    }
    if (trimmed.size == 0) {
        return "http://${host}:${port}/"
    }
    if (trimmed.toRuneArray()[0] == r'/') {
        return "http://${host}:${port}" + trimmed
    }
    "http://${host}:${port}/" + trimmed
}

func buildPathFromTemplate(pathTemplate: String, params: Array<(String, String)>): ?String {
    let chars = pathTemplate.toRuneArray()
    var i: Int64 = 0
    var result = ""
    while (i < chars.size) {
        if (chars[i] == r':') {
            i += 1
            var name = ""
            while (i < chars.size && chars[i] != r'/') {
                name += chars[i].toString()
                i += 1
            }
            if (let Some(value) <- findRouteParam(params, name)) {
                result += value
            } else {
                return None
            }
            continue
        }
        if (chars[i] == r'*') {
            if (let Some(value) <- findRouteParam(params, "*")) {
                result += value
            } else {
                return None
            }
            i += 1
            continue
        }
        result += chars[i].toString()
        i += 1
    }
    Some(result)
}

func findRouteParam(params: Array<(String, String)>, key: String): ?String {
    for ((k, v) in params) {
        if (k == key) {
            return Some(v)
        }
    }
    None
}

func appendQueryPairs(path: String, query: Array<(String, String)>): String {
    if (query.size == 0) {
        return path
    }
    var out = path + "?"
    var first = true
    for ((k, v) in query) {
        if (!first) {
            out += "&"
        }
        first = false
        out += urlEncode(k) + "=" + urlEncode(v)
    }
    out
}

func urlEncode(input: String): String {
    let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    var out = ""
    for (r in input.toRuneArray()) {
        let c = r.toString()
        if (c == " ") {
            out += "+"
        } else if (strContainsRuneString(allowed, c)) {
            out += c
        } else {
            let bytes = c.toArray()
            for (b in bytes) {
                let n = Int64(b)
                out += "%"
                if (n < 16) {
                    out += "0"
                }
                out += intToHex(n)
            }
        }
    }
    out
}

func strContainsRuneString(haystack: String, needle: String): Bool {
    let h = haystack.toRuneArray()
    let n = needle.toRuneArray()
    if (n.size == 0) {
        return true
    }
    if (h.size < n.size) {
        return false
    }
    for (i in 0..=(h.size - n.size)) {
        var ok = true
        for (j in 0..n.size) {
            if (h[i + j] != n[j]) {
                ok = false
                break
            }
        }
        if (ok) {
            return true
        }
    }
    false
}

func intToHex(n: Int64): String {
    if (n < 10) {
        return "${n}"
    }
    if (n < 16) {
        return String.fromUtf8([UInt8(87 + n)])
    }
    intToHex(n / 16) + intToHex(n % 16)
}

func readInputStreamUtf8(stream: InputStream): String {
    let out = ArrayList<UInt8>()
    let buf = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = stream.read(buf)
        if (n <= 0) {
            break
        }
        for (i in 0..n) {
            out.add(buf[i])
        }
    }
    String.fromUtf8(out.toArray())
}

func sendHandleForTestRequest(
    client: Client,
    method: String,
    path: String,
    host: String,
    port: UInt16,
    body: String,
    headers: Array<(String, String)>
): AppTestResponse {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            let url = normalizeTestUrl(path, host, port)
            let requestBuilder = HttpRequestBuilder()
                .method(normalizeHttpMethod(method))
                .url(url)
            for ((k, v) in headers) {
                requestBuilder.header(k, v)
            }
            if (body.size > 0) {
                requestBuilder.body(body)
            }

            let response = client.send(requestBuilder.build())
            let responseBody = readInputStreamUtf8(response.body)
            return AppTestResponse(response.status, responseBody, response.headers)
        } catch (_: Exception) {
            if (attempt == 19) {
                throw Exception("handleForTest failed to connect path=${path} port=${port}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
    }
    throw Exception("handleForTest failed to connect path=${path} port=${port}")
}

func waitForInprocStartupObserve(app: App, port: UInt16): ?ServerStartupObserveEvent {
    var attempt: Int64 = 0
    while (attempt < 4) {
        match (app.lastServerStartupObserveEvent()) {
            case Some(event) =>
                if (event.port == port) {
                    return Some(event)
                }
            case None => ()
        }
        sleep(Duration.millisecond * 10)
        attempt += 1
    }
    None
}

func shutdownHandleForTestServer(engine: ServerEngine, serverFuture: Future<Unit>): Unit {
    engine.shutdown()
    try {
        let _ = serverFuture.get(Duration.millisecond * 100)
    } catch (_: Exception) {
        serverFuture.cancel()
    }
}

func claimInprocTestPorts(method: String, path: String): Array<UInt16> {
    synchronized(_inprocTestPortPlannerMutex) {
        let nonce = _inprocTestPortPlannerNonce
        _inprocTestPortPlannerNonce += 1
        claimInprocTestPortsForPlannerNonce(method, path, nonce)
    }
}

func claimInprocTestPortsForPlannerNonce(
    method: String,
    path: String,
    nonce: Int64,
    leaseRoot!: String = ""
): Array<UInt16> {
    let seed = buildInprocTestPortSeed(method, path, nonce)
    let resolvedLeaseRoot = resolveInprocTestPortLeaseRoot(leaseRoot)
    let claimed = ArrayList<UInt16>()
    try {
        var step: Int64 = 0
        while (claimed.size < 8 && step < 10000) {
            let port = buildInprocTestPortCandidate(seed, step)
            step += 1
            if (containsInprocPort(_reservedInprocTestPorts, port) || containsInprocPort(claimed, port)) {
                continue
            }
            if (!tryClaimCrossProcessInprocTestPortLease(port, leaseRoot: resolvedLeaseRoot)) {
                continue
            }
            claimed.add(port)
            _reservedInprocTestPorts.add(port)
        }
        if (claimed.size == 8) {
            return claimed.toArray()
        }
        throw Exception("handleForTest failed to claim enough in-proc test ports")
    } catch (e: Exception) {
        for (port in claimed) {
            removeInprocPort(_reservedInprocTestPorts, port)
            releaseCrossProcessInprocTestPortLease(port, leaseRoot: resolvedLeaseRoot)
        }
        throw e
    }
}

func previewInprocTestPortCandidates(
    method: String,
    path: String,
    nonce: Int64,
    count!: Int64 = 8
): Array<UInt16> {
    if (count <= 0) {
        return []
    }
    let seed = buildInprocTestPortSeed(method, path, nonce)
    let candidates = ArrayList<UInt16>()
    let wanted = if (count < 10000) { count } else { 10000 }
    var step: Int64 = 0
    while (candidates.size < wanted && step < 10000) {
        candidates.add(buildInprocTestPortCandidate(seed, step))
        step += 1
    }
    candidates.toArray()
}

func buildInprocTestPortCandidate(seed: Int64, step: Int64): UInt16 {
    let raw = 42000 + positiveInprocPortModulo(seed + (step * 7919), 10000)
    UInt16(raw)
}

func resolveInprocTestPortLeaseRoot(rootOverride: String): String {
    let trimmedOverride = rootOverride.trimAscii()
    if (trimmedOverride.size > 0) {
        return trimmedOverride
    }
    if (let Some(raw) <- getVariable("IGNITE_INPROC_TEST_PORT_LEASE_DIR")) {
        let trimmed = raw.trimAscii()
        if (trimmed.size > 0) {
            return trimmed
        }
    }
    "/tmp/ignite_handle_for_test_port_leases"
}

func tryClaimCrossProcessInprocTestPortLease(
    port: UInt16,
    leaseRoot!: String = ""
): Bool {
    let resolvedLeaseRoot = resolveInprocTestPortLeaseRoot(leaseRoot)
    ensureInprocTestPortLeaseRootExists(resolvedLeaseRoot)
    let leasePath = buildInprocTestPortLeasePath(port, resolvedLeaseRoot)
    try {
        Directory.create(leasePath)
        writeInprocTestPortLeaseOwner(leasePath, port)
        return true
    } catch (e: Exception) {
        if (exists(leasePath)) {
            return false
        }
        throw e
    }
}

func releaseCrossProcessInprocTestPortLease(
    port: UInt16,
    leaseRoot!: String = ""
): Unit {
    let leasePath = buildInprocTestPortLeasePath(port, resolveInprocTestPortLeaseRoot(leaseRoot))
    try {
        removeIfExists(leasePath, recursive: true)
    } catch (_: Exception) { }
}

func buildInprocTestPortLeasePath(port: UInt16, leaseRoot: String): String {
    Path(leaseRoot).join("port-${port}").toString()
}

func ensureInprocTestPortLeaseRootExists(root: String): Unit {
    var attempt: Int64 = 0
    while (attempt < 4) {
        try {
            Directory.create(root, recursive: true)
            return
        } catch (e: Exception) {
            if (exists(root)) {
                return
            }
            if (attempt == 3) {
                throw e
            }
            sleep(Duration.millisecond * 5)
            attempt += 1
        }
    }
}

func writeInprocTestPortLeaseOwner(leasePath: String, port: UInt16): Unit {
    let ownerPath = Path(leasePath).join("owner.txt").toString()
    var pidText = "0"
    try {
        pidText = "${getProcessId()}"
    } catch (_: Exception) { }
    let file = File(ownerPath, OpenMode.Write)
    try {
        file.write("pid=${pidText};port=${port}\n".toArray())
    } catch (e: Exception) {
        try {
            file.close()
        } catch (_: Exception) { }
        try {
            removeIfExists(leasePath, recursive: true)
        } catch (_: Exception) { }
        throw e
    }
    file.close()
}

func releaseClaimedInprocTestPorts(
    ports: Array<UInt16>,
    leaseRoot!: String = ""
): Unit {
    let resolvedLeaseRoot = resolveInprocTestPortLeaseRoot(leaseRoot)
    for (port in ports) {
        removeInprocPort(_reservedInprocTestPorts, port)
        releaseCrossProcessInprocTestPortLease(port, leaseRoot: resolvedLeaseRoot)
    }
}

func releaseInprocTestPorts(ports: Array<UInt16>): Unit {
    synchronized(_inprocTestPortPlannerMutex) {
        releaseClaimedInprocTestPorts(ports)
    }
}

func buildInprocTestPortSeed(method: String, path: String, nonce: Int64): Int64 {
    stableInprocTestPortHash(method, path) +
        (stableInprocTestProcessHash() * 31) +
        (nonce * 127)
}

func stableInprocTestProcessHash(): Int64 {
    var pidText = "0"
    try {
        pidText = "${getProcessId()}"
    } catch (_: Exception) { }
    stableInprocTestPortHash("PID", pidText)
}

func positiveInprocPortModulo(value: Int64, modulo: Int64): Int64 {
    let raw = value % modulo
    if (raw < 0) {
        return raw + modulo
    }
    raw
}

func containsInprocPort(ports: ArrayList<UInt16>, target: UInt16): Bool {
    for (port in ports) {
        if (port == target) {
            return true
        }
    }
    false
}

func removeInprocPort(ports: ArrayList<UInt16>, target: UInt16): Bool {
    var i: Int64 = 0
    while (i < ports.size) {
        if (ports[i] == target) {
            let _ = ports.remove(at: i)
            return true
        }
        i += 1
    }
    false
}

func stableInprocTestPortHash(method: String, path: String): Int64 {
    let text = normalizeHttpMethod(method) + ":" + path.trimAscii()
    var hash: Int64 = 17
    for (b in text.toArray()) {
        hash = ((hash * 131) + Int64(b)) % 10000
    }
    hash
}

func defaultSwaggerUICssUrl(): String {
    "https" + "://unpkg.com/" + "swagger-ui-dist@5/" + "swagger-ui.css"
}

func defaultSwaggerUIJsUrl(): String {
    "https" + "://unpkg.com/" + "swagger-ui-dist@5/" + "swagger-ui-bundle.js"
}

func swaggerUIHtml(basePath: String, cssUrl: String, jsUrl: String): String {
    let jsonUrl = basePath + "/json"
    #"<!DOCTYPE html>
<html>
<head>
<title>Ignite API - Swagger UI</title>
<link rel="stylesheet" href=""# + cssUrl + #"">
</head>
<body>
<div id="swagger-ui"></div>
<script src=""# + jsUrl + #""></script>
<script>
SwaggerUIBundle({ url: '"# + jsonUrl + #"', dom_id: '#swagger-ui' });
</script>
</body>
</html>"#
}

// ── Startup Banner ──

func bannerCenter(s: String, w: Int64): String {
    if (s.size >= w) { return s }
    let pad = w - s.size
    let left = pad / 2
    let right = pad - left
    var result = ""
    var i: Int64 = 0
    while (i < left) {
        result += " "
        i += 1
    }
    result += s
    i = 0
    while (i < right) {
        result += " "
        i += 1
    }
    result
}

func bannerPadRight(s: String, w: Int64): String {
    var result = s
    while (result.size < w) { result += " " }
    result
}

func bannerPadLeft(s: String, w: Int64): String {
    if (s.size >= w) { return s }
    var result = ""
    while (result.size < w - s.size) { result += " " }
    result + s
}

func bannerSpaces(count: Int64): String {
    if (count <= 0) { return "" }
    var result = ""
    var i: Int64 = 0
    while (i < count) {
        result += " "
        i += 1
    }
    result
}

func bannerDotFill(label: String, value: String, w: Int64): String {
    let dotsNeeded = w - label.size - value.size - 2
    var dots = ""
    if (dotsNeeded > 0) {
        var i: Int64 = 0
        while (i < dotsNeeded) {
            dots += "."
            i += 1
        }
    }
    "${label} ${dots} ${value}"
}

func bannerTintDots(s: String, dotColor: String, textColor: String): String {
    var result = textColor
    var dotMode = false
    for (r in s.toRuneArray()) {
        let ch = r.toString()
        if (ch == ".") {
            if (!dotMode) {
                result += dotColor
                dotMode = true
            }
            result += ch
        } else {
            if (dotMode) {
                result += textColor
                dotMode = false
            }
            result += ch
        }
    }
    result
}

func bannerComposeEndpointLine(url: String, addr: String, port: UInt16): String {
    "${url} || (bound on ${addr}:${port})"
}

func printBanner(
    appName: String,
    appVersion: String,
    scheme: String,
    addr: String,
    port: UInt16,
    touchpointCount: Int64,
    pid: String,
    tlsEnabled: Bool,
    enableSwagger: Bool,
    swaggerPath: String,
    enablePrintSwaggerUrl: Bool,
    kmode: Bool,
    enableBannerSignature: Bool,
    networkSelection: api2.StartupNetworkSelection,
    bannerStyle: BannerStyle,
    bannerColorMode: BannerColorMode,
    bannerExtraTags: Array<String>,
    bannerMaxTagLines: Int64
): Unit {
    println("")
    let lines = renderBannerLines(
        appName,
        appVersion,
        scheme,
        addr,
        port,
        touchpointCount,
        pid,
        tlsEnabled,
        enableSwagger,
        swaggerPath,
        enablePrintSwaggerUrl,
        kmode,
        enableBannerSignature,
        networkSelection,
        bannerStyle,
        bannerColorMode,
        bannerExtraTags,
        bannerMaxTagLines
    )
    for (line in lines) {
        println(line)
    }
    println("")
}

func renderBannerLines(
    appName: String,
    appVersion: String,
    scheme: String,
    addr: String,
    port: UInt16,
    touchpointCount: Int64,
    pid: String,
    tlsEnabled: Bool,
    enableSwagger: Bool,
    swaggerPath: String,
    enablePrintSwaggerUrl: Bool,
    kmode: Bool,
    enableBannerSignature: Bool,
    networkSelection: api2.StartupNetworkSelection,
    bannerStyle: BannerStyle,
    bannerColorMode: BannerColorMode,
    bannerExtraTags: Array<String>,
    bannerMaxTagLines: Int64
): Array<String> {
    let palette = buildBannerPalette(bannerColorMode)
    let frameworkVersion = IGNITE_FRAMEWORK_VERSION
    let versionDisplay = if (appVersion.size > 0) { appVersion } else { frameworkVersion }
    let title = "${appName} v${versionDisplay}"
    let displayAddr = networkSelection.primaryIP
    let url = "${scheme}://${displayAddr}:${port}"
    let endpointBound = "(bound on ${addr}:${port})"
    let tags = buildBannerTags(
        tlsEnabled,
        enableSwagger,
        kmode,
        networkSelection,
        bannerExtraTags
    )
    let tagLines = buildBannerTagLines(tags, bannerMaxTagLines, 53, palette)
    let warning = networkSelection.warning
    match (bannerStyle) {
        case BannerStyle.Renaissance =>
            renderRenaissanceBannerLines(
                title,
                url,
                endpointBound,
                port,
                touchpointCount,
                pid,
                frameworkVersion,
                enableBannerSignature,
                enableSwagger,
                swaggerPath,
                enablePrintSwaggerUrl,
                scheme,
                displayAddr,
                warning,
                tagLines,
                palette,
                networkSelection
            )
        case _ =>
            renderClassicBannerLines(
                title,
                url,
                endpointBound,
                addr,
                port,
                touchpointCount,
                pid,
                frameworkVersion,
                enableBannerSignature,
                enableSwagger,
                swaggerPath,
                enablePrintSwaggerUrl,
                scheme,
                displayAddr,
                warning,
                tagLines,
                palette,
                networkSelection
            )
    }
}

func renderClassicBannerLines(
    title: String,
    url: String,
    endpointBound: String,
    addr: String,
    port: UInt16,
    touchpointCount: Int64,
    pid: String,
    frameworkVersion: String,
    enableBannerSignature: Bool,
    enableSwagger: Bool,
    swaggerPath: String,
    enablePrintSwaggerUrl: Bool,
    scheme: String,
    displayAddr: String,
    warning: String,
    tagLines: Array<String>,
    palette: BannerPalette,
    networkSelection: api2.StartupNetworkSelection
): Array<String> {
    let innerWidth: Int64 = 53
    let endpointLine = bannerComposeEndpointLine(url, addr, port)
    let networkLine = buildBannerNetworkSelectionLine(networkSelection)
    let colW: Int64 = 24
    let statsLine = bannerPadRight(
        " " + bannerDotFill("Touchpoints", "${touchpointCount}", colW) + "  " +
            bannerDotFill("PID", pid, colW),
        innerWidth
    )
    let styledStatsLine = bannerTintDots(statsLine, palette.dot, palette.body)
    var border = ""
    var i: Int64 = 0
    while (i < innerWidth) {
        border += "─"
        i += 1
    }

    let lines = ArrayList<String>()
    lines.add(" ${palette.border}┌${border}┐${palette.reset}")
    lines.add(" ${palette.border}│${palette.reset}${palette.title}${bannerCenter(title, innerWidth)}${palette.reset}${palette.border}│${palette.reset}")
    if (endpointLine.size <= innerWidth) {
        let endpointPad = innerWidth - endpointLine.size
        let endpointPadLeft = endpointPad / 2
        let endpointPadRight = endpointPad - endpointPadLeft
        let endpointInner = bannerSpaces(endpointPadLeft) +
            "${palette.url}${url}${palette.reset}${palette.muted} || ${endpointBound}${palette.reset}" +
            bannerSpaces(endpointPadRight)
        lines.add(" ${palette.border}│${palette.reset}${endpointInner}${palette.border}│${palette.reset}")
    } else {
        lines.add(" ${palette.border}│${palette.reset}${palette.url}${bannerCenter(url, innerWidth)}${palette.reset}${palette.border}│${palette.reset}")
        lines.add(" ${palette.border}│${palette.reset}${palette.muted}${bannerCenter(endpointBound, innerWidth)}${palette.reset}${palette.border}│${palette.reset}")
    }
    if (networkLine.size > 0) {
        lines.add(" ${palette.border}│${palette.reset}${palette.muted}${bannerCenter(networkLine, innerWidth)}${palette.reset}${palette.border}│${palette.reset}")
    }
    lines.add(" ${palette.border}│${palette.reset}${bannerCenter("", innerWidth)}${palette.border}│${palette.reset}")
    lines.add(" ${palette.border}│${palette.reset}${styledStatsLine}${palette.reset}${palette.border}│${palette.reset}")
    for (tagLine in tagLines) {
        lines.add(" ${palette.border}│${palette.reset}${bannerCenter(tagLine, innerWidth)}${palette.border}│${palette.reset}")
    }
    if (enableBannerSignature) {
        let signatureLine = bannerPadLeft("_Ignite ${frameworkVersion}", innerWidth)
        lines.add(" ${palette.border}│${palette.reset}${palette.italic}${palette.muted}${signatureLine}${palette.reset}${palette.border}│${palette.reset}")
    }
    lines.add(" ${palette.border}└${border}┘${palette.reset}")
    if (enableSwagger && enablePrintSwaggerUrl) {
        lines.add(" ${palette.url}Swagger UI: ${scheme}://${displayAddr}:${port}${swaggerPath}${palette.reset}")
    }
    if (warning.size > 0) {
        lines.add(" [Ignite][Net] ${warning}")
    }
    lines.toArray()
}

func renderRenaissanceBannerLines(
    title: String,
    url: String,
    endpointBound: String,
    port: UInt16,
    touchpointCount: Int64,
    pid: String,
    frameworkVersion: String,
    enableBannerSignature: Bool,
    enableSwagger: Bool,
    swaggerPath: String,
    enablePrintSwaggerUrl: Bool,
    scheme: String,
    displayAddr: String,
    warning: String,
    tagLines: Array<String>,
    palette: BannerPalette,
    networkSelection: api2.StartupNetworkSelection
): Array<String> {
    let lines = ArrayList<String>()
    let divider = "──────────────────────────────────────────────────────"
    let networkLine = buildBannerNetworkSelectionLine(networkSelection)
    lines.add("${palette.title}${title}${palette.reset}")
    lines.add("${palette.border}${divider}${palette.reset}")
    lines.add("${palette.url}${url}${palette.reset}")
    lines.add("${palette.muted}${endpointBound}${palette.reset}")
    if (networkLine.size > 0) {
        lines.add("${palette.muted}${networkLine}${palette.reset}")
    }
    lines.add("")
    lines.add("${palette.body}touchpoints: ${touchpointCount}   pid: ${pid}${palette.reset}")
    for (tagLine in tagLines) {
        lines.add(tagLine)
    }
    if (enableBannerSignature) {
        lines.add("${palette.italic}${palette.muted}_Ignite ${frameworkVersion}${palette.reset}")
    }
    if (enableSwagger && enablePrintSwaggerUrl) {
        lines.add("${palette.url}Swagger UI: ${scheme}://${displayAddr}:${port}${swaggerPath}${palette.reset}")
    }
    if (warning.size > 0) {
        lines.add(" [Ignite][Net] ${warning}")
    }
    lines.toArray()
}

func buildBannerPalette(mode: BannerColorMode): BannerPalette {
    let esc = "\u{1B}"
    match (mode) {
        case BannerColorMode.Gray =>
            BannerPalette(
                esc + "[0m",
                esc + "[38;5;240m",
                esc + "[1;37m",
                esc + "[38;5;252m",
                esc + "[38;5;245m",
                esc + "[38;5;252m",
                esc + "[38;5;240m",
                esc + "[38;5;252m",
                esc + "[38;5;249m",
                esc + "[38;5;245m",
                esc + "[3m"
            )
        case BannerColorMode.Plain =>
            BannerPalette("", "", "", "", "", "", "", "", "", "", "")
        case _ =>
            BannerPalette(
                esc + "[0m",
                esc + "[38;5;240m",
                esc + "[1;38;5;81m",
                esc + "[38;5;114m",
                esc + "[38;5;246m",
                esc + "[38;5;252m",
                esc + "[38;5;240m",
                esc + "[38;5;252m",
                esc + "[38;5;42m",
                esc + "[38;5;174m",
                esc + "[3m"
            )
    }
}

func buildBannerTags(
    tlsEnabled: Bool,
    enableSwagger: Bool,
    kmode: Bool,
    networkSelection: api2.StartupNetworkSelection,
    extraTags: Array<String>
): Array<BannerTag> {
    let tags = ArrayList<BannerTag>()
    tags.add(BannerTag("TLS", if (tlsEnabled) { "active" } else { "muted" }))
    tags.add(BannerTag("Swagger", if (enableSwagger) { "active" } else { "muted" }))
    if (kmode) {
        tags.add(BannerTag("kMode.Debug", "accent"))
    }
    if (networkSelection.mode == "multi" && networkSelection.displayInterfacePairs.size > 1) {
        tags.add(BannerTag("Multi-NIC", "active"))
    } else if (networkSelection.mode == "named" && networkSelection.matchedInterface.size > 0) {
        tags.add(BannerTag("NIC:" + networkSelection.matchedInterface, "active"))
    } else if (networkSelection.mode == "direct" && networkSelection.matchedInterface.size > 0) {
        tags.add(BannerTag("Bind:" + networkSelection.matchedInterface, "muted"))
    }
    if (networkSelection.warning.size > 0) {
        tags.add(BannerTag("Net.Warn", "warning"))
    }
    for (raw in extraTags) {
        let trimmed = raw.trimAscii()
        if (trimmed.size > 0) {
            tags.add(BannerTag(trimmed, "active"))
        }
    }
    tags.toArray()
}

func buildBannerTagLines(
    tags: Array<BannerTag>,
    maxLines: Int64,
    maxWidth: Int64,
    palette: BannerPalette
): Array<String> {
    if (tags.size == 0 || maxLines <= 0) {
        return Array<String>(0, repeat: "")
    }
    let lines = ArrayList<String>()
    var line = ""
    var rawLen: Int64 = 0
    var lineCount: Int64 = 0
    for (tag in tags) {
        let nextRawLen = if (rawLen == 0) {
            tag.text.size
        } else {
            rawLen + 3 + tag.text.size
        }
        if (rawLen > 0 && nextRawLen > maxWidth && lineCount + 1 < maxLines) {
            lines.add(line)
            lineCount += 1
            line = ""
            rawLen = 0
        }
        if (rawLen > 0) {
            line += "   "
        }
        line += renderBannerTag(tag, palette)
        rawLen = if (rawLen == 0) { tag.text.size } else { rawLen + 3 + tag.text.size }
    }
    if (line.size > 0) {
        lines.add(line)
    }
    lines.toArray()
}

func renderBannerTag(tag: BannerTag, palette: BannerPalette): String {
    let color = match (tag.style) {
        case "accent" => palette.accent
        case "warning" => palette.warning
        case "muted" => palette.muted
        case _ => palette.active
    }
    color + tag.text + palette.reset
}

func buildBannerNetworkSelectionLine(selection: api2.StartupNetworkSelection): String {
    if (selection.displayInterfacePairs.size == 0) {
        return ""
    }
    let label = if (selection.mode == "multi") {
        "NICs"
    } else if (selection.mode == "named" && selection.matchedInterface.size > 0) {
        "NIC"
    } else if (selection.mode == "direct") {
        "Bind"
    } else {
        "NIC"
    }
    label + ": " + joinBannerValues(selection.displayInterfacePairs, " | ")
}

func shouldMonitorBoundAddress(
    addr: String,
    selection: api2.StartupNetworkSelection
): Bool {
    let trimmed = addr.trimAscii()
    if (trimmed == "127.0.0.1" || trimmed == "::1" || trimmed == "localhost") {
        return false
    }
    if (trimmed == "0.0.0.0" || trimmed == "::" || trimmed == "[::]") {
        return true
    }
    if (selection.mode == "direct") {
        return true
    }
    selection.displayInterfacePairs.size > 0
}

func joinBannerValues(values: Array<String>, sep: String): String {
    if (values.size == 0) {
        return ""
    }
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += sep
        }
        first = false
        out += value
    }
    out
}

class BannerPalette {
    let reset: String
    let border: String
    let title: String
    let url: String
    let muted: String
    let body: String
    let dot: String
    let active: String
    let accent: String
    let warning: String
    let italic: String

    init(
        reset: String,
        border: String,
        title: String,
        url: String,
        muted: String,
        body: String,
        dot: String,
        active: String,
        accent: String,
        warning: String,
        italic: String
    ) {
        this.reset = reset
        this.border = border
        this.title = title
        this.url = url
        this.muted = muted
        this.body = body
        this.dot = dot
        this.active = active
        this.accent = accent
        this.warning = warning
        this.italic = italic
    }
}

class BannerTag {
    let text: String
    let style: String

    init(text: String, style: String) {
        this.text = text
        this.style = style
    }
}

class NetworkMonitorStopSignal {
    let _mtx = Mutex()
    var _stopped = false

    func stop(): Unit {
        synchronized(_mtx) {
            _stopped = true
        }
    }

    func isStopped(): Bool {
        synchronized(_mtx) {
            _stopped
        }
    }
}
