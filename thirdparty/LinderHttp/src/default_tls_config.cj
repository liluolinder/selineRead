package linderHttp

/**
 * 创建默认TLS客户端配置
 * 
 * @return TlsClientConfig 验证模式为TrustAll的TLS配置
 * 
 * 注意：TrustAll模式会信任所有证书，仅用于开发测试环境。
 * 生产环境建议使用更严格的验证模式。
 */
public func defaultTlsConfig(): TlsClientConfig {
    var tlsConfig = TlsClientConfig()
    tlsConfig.verifyMode = TrustAll
    tlsConfig
}
