package selineWebdav

import ignite.*
import std.collection.ArrayList
import stdx.log.*

// 日志器
let serverLogger: Logger = getGlobalLogger()

// WebDAV服务器配置
public struct WebDavServerConfig {
    public var appName: String = "Seline WebDAV"
    public var readTimeout: Duration = Duration.second * 60
    public var writeTimeout: Duration = Duration.second * 60
    public var bodyLimit: Int64 = 1024 * 1024 * 1024 // 1GB
    public var concurrency: Int64 = 1024 * 1024 // 高并发支持

    public init(
        appName!: String = "Seline WebDAV",
        readTimeout!: Duration = Duration.second * 60,
        writeTimeout!: Duration = Duration.second * 60,
        bodyLimit!: Int64 = 1024 * 1024 * 1024,
        concurrency!: Int64 = 1024 * 1024
    ) {
        this.appName = appName
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
        this.bodyLimit = bodyLimit
        this.concurrency = concurrency
    }
}

// WebDAV服务器 - 封装ignite，提供简单的启动接口
public class WebDavServer {
    public var handler: WebDavHandler
    public var host: String
    public var port: UInt16
    public var serverConfig: WebDavServerConfig
    private var app: ?App = None

    public init(rootPath: String, host!: String = "127.0.0.1", port!: Int64 = 8080,
        config!: WebDavServerConfig = WebDavServerConfig()) {
        this.handler = WebDavHandler(rootPath)
        this.host = host
        this.port = UInt16(port)
        this.serverConfig = config
    }

    public init(handlerConfig: WebDavConfig, host!: String = "127.0.0.1", port!: Int64 = 8080,
        config!: WebDavServerConfig = WebDavServerConfig()) {
        this.handler = WebDavHandler(handlerConfig)
        this.host = host
        this.port = UInt16(port)
        this.serverConfig = config
    }

    // 启动服务器
    public func start(): WebDavServer {
        // 创建高性能配置
        let igniteConfig = Config(
            appName: serverConfig.appName,
            serverHeader: "SelineWebDAV",
            readTimeout: serverConfig.readTimeout,
            writeTimeout: serverConfig.writeTimeout,
            bodyLimit: serverConfig.bodyLimit,
            concurrency: serverConfig.concurrency
        )

        let app = App(config: igniteConfig)
        let router = app.router

        // 创建handler列表
        let handlers = ArrayList<Handler>()
        handlers.add(handler.handle)

        // 注册标准HTTP方法
        let standardMethods = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
        for (method in standardMethods) {
            router.addRoute(method, "/", handlers)
            router.addRoute(method, "/*", handlers)
        }

        // 注册WebDAV特有方法
        let webdavMethods = ["PROPFIND", "PROPPATCH", "MKCOL", "COPY", "MOVE", "LOCK", "UNLOCK"]
        for (method in webdavMethods) {
            router.addRoute(method, "/", handlers)
            router.addRoute(method, "/*", handlers)
        }

        serverLogger.info("WebDAV Server starting on http://${host}:${port}")
        serverLogger.info("Root path: ${handler.getRootPath()}")
        serverLogger.info("Concurrency: ${serverConfig.concurrency}")
        
        this.app = app
        app.listen(host, port)
        this
    }

    // 关闭服务器
    public func shutdown(): WebDavServer {
        if (let Some(a) <- app) {
            serverLogger.info("WebDAV Server shutting down...")
            a.shutdown()
            serverLogger.info("WebDAV Server stopped")
        }
        this
    }

    // 获取根路径
    public func getRootPath(): String {
        handler.getRootPath()
    }
}

// 便捷函数：快速启动WebDAV服务器（无认证）
public func startWebDav(rootPath: String, host!: String = "127.0.0.1", port!: Int64 = 8080,
    serverConfig!: WebDavServerConfig = WebDavServerConfig()): WebDavServer {
    let server = WebDavServer(rootPath, host: host, port: port, config: serverConfig)
    server.start()
    server
}

// 便捷函数：使用配置启动WebDAV服务器（无认证）
public func startWebDavWithConfig(handlerConfig: WebDavConfig, host!: String = "127.0.0.1", port!: Int64 = 8080,
    serverConfig!: WebDavServerConfig = WebDavServerConfig()): WebDavServer {
    let server = WebDavServer(handlerConfig, host: host, port: port, config: serverConfig)
    server.start()
    server
}

// 便捷函数：带认证启动WebDAV服务器
public func startWebDavWithAuth(
    rootPath: String,
    username: String,
    password: String,
    host!: String = "127.0.0.1",
    port!: Int64 = 8080,
    realm!: String = "WebDAV",
    encodeHref!:Bool = true,
    serverConfig!: WebDavServerConfig = WebDavServerConfig()
): WebDavServer {
    let users = ArrayList<WebDavUser>()
    users.add(WebDavUser(username, password))
    let handlerConfig = WebDavConfig(
        rootPath,
        enableAuth: true,
        users: users,
        realm: realm,
        encodeHref:encodeHref
    )
    let server = WebDavServer(handlerConfig, host: host, port: port, config: serverConfig,)
    server.start()
    server
}
