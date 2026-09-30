package linderHttp.http

/**
 * 证书校验模式。
 */
public enum TlsMode <: ToString {
    /** 用系统 CA 校验（默认，生产环境应该用这个） */
    | System
    /** 不校验证书，仅用于自签名/内网调试 */
    | TrustAll
    /** 用指定的 CA 证书校验（私有 CA / 抓包代理） */
    | CustomCa
    /** 直接接管一个标准库的 TlsClientConfig */
    | Native

    public func toString(): String {
        match (this) {
            case System => "system"
            case TrustAll => "trust-all"
            case CustomCa => "custom-ca"
            case Native => "native"
        }
    }
}

/**
 * TLS 配置的外观。
 *
 * 关键设计：库默认「校验证书」。相比「一律信任所有证书」，这既更安全，实测也更少握手失败。
 * 需要访问自签名服务时显式用 `TlsOptions.trustAll()`。
 *
 * 另一个关键点：底层 stdx 的 `TlsClientConfig` 是一次性的、且必须显式提供，
 * 其中 `serverName` 决定 TLS SNI。所以本类只保存「策略」，真正的配置在建立每个
 * host 的连接时由 `materialize(host)` 生成，确保 SNI 与目标主机一致。
 */
public class TlsOptions {
    private let mode: TlsMode
    private let caPem: ?String
    private let serverNameOverride: ?String
    private let alpn: ?Array<String>
    private let baseConfig: ?TlsClientConfig

    private init(mode: TlsMode, caPem: ?String, serverNameOverride: ?String, alpn: ?Array<String>,
        baseConfig: ?TlsClientConfig) {
        this.mode = mode
        this.caPem = caPem
        this.serverNameOverride = serverNameOverride
        this.alpn = alpn
        this.baseConfig = baseConfig
    }

    /** 系统 CA 校验 + 按目标主机自动 SNI。 */
    public static func system(): TlsOptions {
        TlsOptions(TlsMode.System, None, None, None, None)
    }

    /** 信任所有证书（仅开发测试）。 */
    public static func trustAll(): TlsOptions {
        TlsOptions(TlsMode.TrustAll, None, None, None, None)
    }

    /** 用 PEM 文本中的 CA 证书校验。 */
    public static func customCa(pem: String): TlsOptions {
        TlsOptions(TlsMode.CustomCa, Some(pem), None, None, None)
    }

    /** 接管一个已有的标准库配置（高级用法：双向认证、密码套件、TLS 版本等）。 */
    public static func native(config: TlsClientConfig): TlsOptions {
        TlsOptions(TlsMode.Native, None, None, None, Some(config))
    }

    /** 覆盖 SNI 域名（例如证书签给域名、却用 IP 连接）。 */
    public func withServerName(name: String): TlsOptions {
        TlsOptions(mode, caPem, Some(name), alpn, baseConfig)
    }

    /** 手工指定 ALPN 协议列表。 */
    public func withAlpn(protocols: Array<String>): TlsOptions {
        TlsOptions(mode, caPem, serverNameOverride, Some(protocols), baseConfig)
    }

    public func modeName(): TlsMode {
        mode
    }

    public func alpnProtocols(): ?Array<String> {
        alpn
    }

    /** 连接池键的一部分：TLS 策略不同就必须用不同的底层连接。 */
    internal func key(): String {
        let override = match (serverNameOverride) {
            case Some(name) => name
            case None => "-"
        }
        let protocols = match (alpn) {
            case Some(list) => String.join(list, delimiter: ",")
            case None => "-"
        }
        "${mode}:${override}:${protocols}"
    }

    /**
     * 生成某个主机实际使用的 TLS 配置。
     *
     * @param host 目标主机名，写入 SNI
     * @param http2Enabled 是否允许协商 h2（关闭时只报 http/1.1）
     */
    internal func materialize(host: String, http2Enabled: Bool): TlsClientConfig {
        var config = match (baseConfig) {
            case Some(existing) => copyNative(existing)
            case None => TlsClientConfig()
        }
        match (mode) {
            case TlsMode.System => config.verifyMode = Default
            case TlsMode.TrustAll => config.verifyMode = TrustAll
            case TlsMode.CustomCa =>
                let pem = caPem.getOrThrow()
                let decoded = X509Certificate.decodeFromPem(pem)
                let chain = ArrayList<Certificate>()
                for (certificate in decoded) {
                    chain.add(certificate)
                }
                config.verifyMode = CustomCA(chain.toArray())
            case TlsMode.Native => ()
        }
        // SNI：显式覆盖优先，否则用目标主机名。stdx 不会自动补，缺了会握手失败。
        let sni = match (serverNameOverride) {
            case Some(name) => name
            case None => host
        }
        if (!sni.isEmpty()) {
            config.serverName = Some(sni)
        }
        if (let Some(protocols) <- alpn) {
            config.supportedAlpnProtocols = protocols
        } else if (!http2Enabled) {
            config.supportedAlpnProtocols = ["http/1.1"]
        }
        config
    }

    /** 深拷贝一份标准库配置，避免多个连接共享同一对象。 */
    private func copyNative(source: TlsClientConfig): TlsClientConfig {
        var target = TlsClientConfig()
        target.verifyMode = source.verifyMode
        if (!source.certificate.isNone()) {
            target.certificate = source.certificate
        }
        target.securityLevel = source.securityLevel
        target.supportedVersions = source.supportedVersions
        if (!source.signatureAlgorithms.isNone()) {
            target.signatureAlgorithms = source.signatureAlgorithms
        }
        target.supportedCipherSuites = source.supportedCipherSuites
        target.supportedAlpnProtocols = source.supportedAlpnProtocols
        if (!source.serverName.isNone()) {
            target.serverName = source.serverName
        }
        target
    }
}
