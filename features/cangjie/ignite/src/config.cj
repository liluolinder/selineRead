package ignite

import ignite.api2

public enum BannerStyle <: Equatable<BannerStyle> & ToString {
    | Classic
    | Renaissance

    public operator func ==(right: BannerStyle): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: BannerStyle): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Classic => 0
            case Renaissance => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Classic => "classic"
            case Renaissance => "renaissance"
        }
    }
}

public enum BannerColorMode <: Equatable<BannerColorMode> & ToString {
    | Color
    | Gray
    | Plain

    public operator func ==(right: BannerColorMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: BannerColorMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Color => 0
            case Gray => 1
            case Plain => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Color => "color"
            case Gray => "gray"
            case Plain => "plain"
        }
    }
}
public struct Config {
    public var appName: String = "Ignite"
    /// 应用版本，用于启动 Banner 标题；空则显示框架版本。Banner 始终输出，不可关闭。
    public var appVersion: String = ""
    public var serverHeader: String = "Ignite"

    public var strictRouting: Bool = false
    public var caseSensitive: Bool = false
    public var unescapePath: Bool = false

    public var bodyLimit: Int64 = 4 * 1024 * 1024
    public var readTimeout: Duration = Duration.second * 30
    public var writeTimeout: Duration = Duration.second * 30
    public var readHeaderTimeout: Duration = Duration.second * 10
    public var idleTimeout: Duration = Duration.second * 120

    public var concurrency: Int64 = 256 * 1024

    public var enableSwagger: Bool = false
    public var swaggerPath: String = "/swagger"
    public var swaggerUICssUrl: String = ""
    public var swaggerUIJsUrl: String = ""
    /// 为 true 时启动后打印 Swagger UI 地址；仅影响启动输出，不影响 Swagger 路由是否注册。
    public var enablePrintSwaggerUrl: Bool = true
    /// 为 true 时启动时额外打印路由表；Banner 始终输出，不受此控制。
    public var enablePrintRoutes: Bool = false
    /// 为 true 时在 Banner 右下角打印框架签名；仅影响展示，不影响版本读取逻辑。
    public var enableBannerSignature: Bool = true
    /// 通配监听地址（如 0.0.0.0）在 Banner 和网络通知中采用的网卡选择模式；不改变底层实际 bind 行为。
    public var startupNetworkMode: api2.StartupNetworkMode = api2.StartupNetworkMode.AutoSingle
    /// 当 startupNetworkMode = named 时指定要展示/跟踪的网卡名；留空会回退到 auto_single。
    public var startupNetworkInterface: String = ""
    /// 为 true 时在启动完成后轮询本机网络快照，检测选定网卡/IP 变化并输出通知。
    public var enableNetworkChangeNotice: Bool = true
    /// `0700` Banner 风格：classic 为盒子风，renaissance 为文档风纯文本样式。
    public var bannerStyle: BannerStyle = BannerStyle.Classic
    /// `0700` Banner 颜色模式：color / gray / plain。
    public var bannerColorMode: BannerColorMode = BannerColorMode.Color
    /// 附加 Banner 标签；会在内建标签后补充显示，默认不做未来能力占位。
    public var bannerExtraTags: Array<String> = []
    /// Banner 标签区最多渲染的行数。
    public var bannerMaxTagLines: Int64 = 2
    /// kmode（调试模式）：为 true 时启动后启用类似 debug 行为，Banner 中必打当前 Ignite 版本，并可配合 kmodeMiddleware 使用。
    public var kmode: Bool = false
    /// kmode panic hook：用于 App 顶层异常兜底。返回 true 表示异常已处理（例如触发重启/终止流程），将跳过默认 500 处理。
    public var kmodePanicHandler: ?KModePanicHandler = None

    public var tlsCertFile: String = ""
    public var tlsKeyFile: String = ""
    /// 为 true 时启用 jinguiSSL TLS precheck；为 false 时仅使用 stdx TLS 构造路径（保留回退能力）。
    public var enableTlsPrecheck: Bool = true
    /// 服务器端传输后端偏好；默认留空，保持稳定默认路径。
    public var serverPreferredBackendHint: String = ""
    /// 服务器端是否允许实验性后端参与选路；默认 false。
    public var allowExperimentalServerBackend: Bool = false

    public var allowRouteOverwrite: Bool = false

    public var enableSwaggerCache: Bool = true

    public var jsonEncoder: ?JsonEncoder = None

    public init(
        appName!: String = "Ignite",
        appVersion!: String = "",
        serverHeader!: String = "Ignite",
        strictRouting!: Bool = false,
        caseSensitive!: Bool = false,
        bodyLimit!: Int64 = 4 * 1024 * 1024,
        readTimeout!: Duration = Duration.second * 30,
        writeTimeout!: Duration = Duration.second * 30,
        concurrency!: Int64 = 256 * 1024,
        enableSwagger!: Bool = false,
        swaggerPath!: String = "/swagger",
        swaggerUICssUrl!: String = "",
        swaggerUIJsUrl!: String = "",
        enablePrintSwaggerUrl!: Bool = true,
        enablePrintRoutes!: Bool = false,
        enableBannerSignature!: Bool = true,
        startupNetworkMode!: api2.StartupNetworkMode = api2.StartupNetworkMode.AutoSingle,
        startupNetworkInterface!: String = "",
        enableNetworkChangeNotice!: Bool = true,
        bannerStyle!: BannerStyle = BannerStyle.Classic,
        bannerColorMode!: BannerColorMode = BannerColorMode.Color,
        bannerExtraTags!: Array<String> = [],
        bannerMaxTagLines!: Int64 = 2,
        kmode!: Bool = false,
        kmodePanicHandler!: ?KModePanicHandler = None,
        tlsCertFile!: String = "",
        tlsKeyFile!: String = "",
        enableTlsPrecheck!: Bool = true,
        allowRouteOverwrite!: Bool = false,
        enableSwaggerCache!: Bool = true,
        jsonEncoder!: ?JsonEncoder = None,
        serverPreferredBackendHint!: String = "",
        allowExperimentalServerBackend!: Bool = false
    ) {
        this.appName = appName
        this.appVersion = appVersion
        this.serverHeader = serverHeader
        this.strictRouting = strictRouting
        this.caseSensitive = caseSensitive
        this.bodyLimit = bodyLimit
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
        this.concurrency = concurrency
        this.enableSwagger = enableSwagger
        this.swaggerPath = swaggerPath
        this.swaggerUICssUrl = swaggerUICssUrl
        this.swaggerUIJsUrl = swaggerUIJsUrl
        this.enablePrintSwaggerUrl = enablePrintSwaggerUrl
        this.enablePrintRoutes = enablePrintRoutes
        this.enableBannerSignature = enableBannerSignature
        this.startupNetworkMode = startupNetworkMode
        this.startupNetworkInterface = startupNetworkInterface
        this.enableNetworkChangeNotice = enableNetworkChangeNotice
        this.bannerStyle = bannerStyle
        this.bannerColorMode = bannerColorMode
        this.bannerExtraTags = bannerExtraTags
        this.bannerMaxTagLines = bannerMaxTagLines
        this.kmode = kmode
        this.kmodePanicHandler = kmodePanicHandler
        this.tlsCertFile = tlsCertFile
        this.tlsKeyFile = tlsKeyFile
        this.enableTlsPrecheck = enableTlsPrecheck
        this.serverPreferredBackendHint = serverPreferredBackendHint
        this.allowExperimentalServerBackend = allowExperimentalServerBackend
        this.allowRouteOverwrite = allowRouteOverwrite
        this.enableSwaggerCache = enableSwaggerCache
        this.jsonEncoder = jsonEncoder
    }
}
