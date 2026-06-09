package linderHttp




/**
 * HTTP客户端类
 * 
 * 提供HTTP请求构建和发送功能，支持链式调用配置。
 * 
 * ## 功能特性
 * - 支持所有标准HTTP方法（GET、POST、PUT、DELETE等）
 * - 支持自定义HTTP方法
 * - 支持TLS/SSL安全连接
 * - 支持HTTP/2协议
 * - 支持请求/响应拦截器
 * - 支持代理设置
 * - 支持自动重定向
 * 
 * ## 使用示例
 * ```cangjie
 * let client = HttpClient(url: "https://api.example.com/data")
 * let response = client
 *     .setHeader("Content-Type", "application/json")
 *     .setBody("{\"name\": \"test\"}")
 *     .send()
 * ```
 */
public class LinderHttpClient {
    /**
     * HTTP客户端构建器实例
     * 默认值：`ClientBuilder()`（未初始化状态）
     * 安全提示：禁止外部直接访问底层构建器，
     * 调用send()时候进行创建
     */
    private var clientBuilder: ClientBuilder = ClientBuilder()

    private var client: ?Client = None

    /**
     * HTTP拦截器
     * 默认值：`None`（未初始化状态）
     */
    private var interceptor: ?Interceptor = None
    
    /**
     * 目标请求URL
     * 默认值：空字符串
     * 关联更新：调用`setUrl()`时自动同步更新`tlsConfig.serverName`
     */
    public var url: RequestUrl = RequestUrl.from('')

    /**
     * 自定义HTTP头部容器
     * 类型：专属的`HttpHeader`对象
     * 默认值：空头部容器实例
     */
    public var headers: HttpHeader = HttpHeader()

    /**
     * TLS/SSL客户端安全配置
     *
     * 默认值：`defaultTlsConfig()`生成的基准配置
     * 特殊机制：`setUrl()`会重置serverName为URL的hostName，
     * 需显式调用`setServerName()`覆盖此行为
     */
    public var tlsConfig: TlsClientConfig = defaultTlsConfig()

    /**
     * HTTP请求方法标识
     * 默认值：`GET`
     * 合法值：标准方法（GET/POST等）或自定义方法
     */
    public var method: String = 'GET'

    /**
     * 请求附带数据
     * 默认值：NONE 表示不附带数据
     */
    public var requestBody: ?RequestBody = None

    /**
     * 重定向自动处理开关
     * 默认值：`true`（启用自动重定向）
     */
    public var autoRedirect: Bool = true

    /**
     * 读取响应超时阈值
     * 计量单位：`Duration`
     * 默认值：15秒
     */
    public var readTimeout: Duration = Duration.second * 15

    /**
     * 发送请求超时阈值
     * 计量单位：`Duration`
     * 默认值：15秒
     */
    public var writeTimeout: Duration = Duration.second * 15

    /**
     * 配置客户端 HTTP/2 流控窗口初始值
     * size: UInt32 - 默认值 65535 ， 取值范围为 0 至 2^31 - 1
     */
    public var initialWindowSize: UInt32 = 65535

    /**
     * 配置客户端 HTTP/2 是否支持服务器推送 默认值 true。
     */
    public var enablePush: Bool = true

    /**
     *  配置客户端 HTTP/2 Hpack 动态表初始值。 默认值 4096
     */
    public var headerTableSize: UInt32 = 4096

    /**
     * 设置客户端 http 代理，默认使用系统环境变量 http_proxy 的值。
     */
    public var httpProxy: String = ''
    
    /**
     * 设置客户端 https 代理，默认使用系统环境变量 https_proxy 的值。
     */
    public var httpsProxy: String = ''

    /**
     * 初始化HTTP客户端
     *
     * @param url 请求的目标URL（包含协议头，如https://）
     * @param serverName 自定义域名标识，用于TLS握手验证
     *     - 若未设置则从url自动设置
     *     - 优先级低于tlsConfig：若同时设置serverName和tlsConfig，serverName将被忽略
     *     - 默认行为：当serverName为空时，自动从url解析hostName
     * @param tlsConfig TLS客户端配置，默认使用defaultTlsConfig()
     *     - 重要：该参数会覆盖serverName的设置，两者同时存在时以tlsConfig为准
     * @param httpHeader 库专属HTTP头容器
     * @param stdHeaders 通用HTTP头容器
     *     - 互斥约束：httpHeader与stdHeaders不可同时设置，否则抛出IllegalArgumentException
     * @param interceptor HTTP拦截器，默认None
     * @param method 请求方法，默认GET
     * @param requestBody 请求附带数据，默认None
     * @param autoRedirect 是否自动重定向，默认true
     * @param readTimeout 读超时时间，默认15秒
     * @param writeTimeout 写超时时间，默认15秒
     * @param initialWindowSize 配置客户端 HTTP/2 流控窗口初始值  UInt32 - 默认值 65535 ， 取值范围为 0 至 2^31 - 1
     * @param enablePush 配置客户端 HTTP/2 是否支持服务器推送 默认值 true。
     * @param headerTableSize 配置客户端 HTTP/2 Hpack 动态表初始值。 默认值 4096
     * @param httpProxy 设置客户端 http 代理，默认使用系统环境变量 http_proxy 的值。
     * @param httpsProxy 设置客户端 https 代理，默认使用系统环境变量 https_proxy 的值。
     *
     * @throws IllegalArgumentException 当同时设置httpHeader和stdHeaders时抛出
     *
     * 初始化逻辑说明：
     * 1. TLS域名处理：
     *    - 优先尝试使用serverName参数设置tlsConfig.serverName
     *    - 执行`this.tlsConfig = tlsConfig`会覆盖先前设置
     * 2. HTTP头处理：
     *    - 双Header容器互斥检测
     */
    public init(
        url!: RequestUrl = RequestUrl.from('') ,
        serverName!: String = '',
        tlsConfig!: ?TlsClientConfig = None,
        httpHeader!: ?HttpHeader = None,
        stdHeaders!: ?HttpHeaders = None,
        interceptor!: ?Interceptor = None,
        method!: RequestMethod = RequestMethod.GET,
        requestBody!: ?RequestBody = None,
        autoRedirect!: Bool = true,
        readTimeout!: Duration = Duration.second * 15,
        writeTimeout!: Duration = Duration.second * 15,
        initialWindowSize!: UInt32 = 65535,
        enablePush!: Bool = true,
        headerTableSize!: UInt32 = 4096,
        httpProxy!: String = '',
        httpsProxy!: String = ''
    ) {
        this.url = url
        this.tlsConfig.serverName = if (serverName != '') {
            serverName
        } else {
            let tempServerName = match (url) {
                case RequestUrl.STRING(v) => URL.parse(v).hostName.toString()
                case RequestUrl.URL(v) => v.hostName.toString()
            }
            if (tempServerName != '') {
                tempServerName
            } else {
                this.tlsConfig.serverName
            }
        }

        if (!tlsConfig.isNone()) {
            this.tlsConfig = tlsConfig.getOrThrow()
        }

        this.requestBody = requestBody
        if (httpHeader.isNone() && stdHeaders.isNone()) {
            this.headers = HttpHeader()
        } else if (!httpHeader.isNone() && stdHeaders.isNone()) {
            this.headers = httpHeader.getOrThrow()
        } else if (httpHeader.isNone() && !stdHeaders.isNone()) {
            this.headers.setAll(stdHeaders.getOrThrow())
        } else {
            throw IllegalArgumentException('不可同时设置双Headers')
        }
        this.interceptor = interceptor
        this.method = method.toString()
        this.autoRedirect = autoRedirect
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
        this.initialWindowSize = initialWindowSize
        this.enablePush = enablePush
        this.headerTableSize = headerTableSize
        this.httpsProxy = httpsProxy
        this.httpProxy = httpProxy
    }

    /**
     * 设置请求URL并自动更新TLS域名
     * 如果tlsconfig已设置serverName则无操作,否则自动设置
     * @param v 目标URL
     * @return 当前对象（支持链式调用）
     *
     * 调用此方法将同步更新TLS配置的域名，
     */
    public func setUrl(v: RequestUrl): LinderHttpClient {
        url = v
        tlsConfig.serverName = if (tlsConfig.serverName.isSome()) {
            tlsConfig.serverName
        } else {
            match (url) {
                case RequestUrl.STRING(v) => URL.parse(v).hostName.toString()
                case RequestUrl.URL(v) => v.hostName.toString()
            }
        }
        this
    }

    /**
     * 设置请求URL并自动更新TLS域名
     * 如果tlsconfig已设置serverName则无操作,否则自动设置
     * @param v 目标URL
     * @return 当前对象（支持链式调用）
     *
     * 调用此方法将同步更新TLS配置的域名，
     */
    public func setUrl(v: String): LinderHttpClient {
        url = RequestUrl.from(v)
        tlsConfig.serverName = if (tlsConfig.serverName.isSome()) {
            tlsConfig.serverName
        } else {
            match (url) {
                case RequestUrl.STRING(v) => URL.parse(v).hostName.toString()
                case RequestUrl.URL(v) => v.hostName.toString()
            }
        }
        this
    }

    /**
     * 设置请求URL并自动更新TLS域名
     * 如果tlsconfig已设置serverName则无操作,否则自动设置
     * @param v 目标URL
     * @return 当前对象（支持链式调用）
     *
     * 调用此方法将同步更新TLS配置的域名，
     */
    public func setUrl(v: URL): LinderHttpClient {
        url = RequestUrl.from(v)
        tlsConfig.serverName = if (tlsConfig.serverName.isSome()) {
            tlsConfig.serverName
        } else {
            match (url) {
                case RequestUrl.STRING(v) => URL.parse(v).hostName.toString()
                case RequestUrl.URL(v) => v.hostName.toString()
            }
        }
        this
    }

    /**
     * 设置通用HTTP头部（覆盖式更新）
     * @param v 标准HTTP头容器
     * @return 当前对象（支持链式调用）
     *
     * 重要：此操作将覆盖现有HttpHeader
     */
    public func setHeader(v: HttpHeaders): LinderHttpClient {
        headers.setAll(v)
        this
    }

    /**
     * 设置HTTP头部（覆盖式更新）
     * @param v 专属HTTP头容器
     * @return 当前对象（支持链式调用）
     *
     * 警告：此操作将覆盖现有HttpHeader
     */
    public func setHeader(v: HttpHeader): LinderHttpClient {
        headers = (v)
        this
    }

    /**
     * 设置HTTP头部（从HashMap批量设置）
     * @param v HashMap<String, String>类型的键值对集合
     * @return 当前对象（支持链式调用）
     *
     * 说明：遍历HashMap中的所有键值对，逐个添加到HTTP头部
     * 注意：如果键已存在，将覆盖原有值
     */
    public func setHeader(v: HashMap<String, String>): LinderHttpClient {
        for ((key, value) in v) {
            headers.set(key: key, value: value)
        }
        this
    }

    /**
     * 设置请求方法（枚举类型RequestMethod）
     * @param v 预定义的请求方法枚举
     * @return 当前对象（支持链式调用）
     *
     * 内部自动转换为字符串形式存储，
     * 优先使用此方法保证方法名合法性
     */
    public func setMethod(v: RequestMethod): LinderHttpClient {
        method = v.toString()
        this
    }

    /**
     * 设置请求方法（自定义字符串）
     * @param v 自定义方法字符串
     * @return 当前对象（支持链式调用）
     *
     * 注意：需自行确保方法名符合HTTP规范，
     * 非标准方法可能导致请求失败
     */
    public func setMethod(v: String): LinderHttpClient {
        method = v
        this
    }

    /**
     * 设置拦截器
     * @param v 拦截器对象
     * @return 当前对象（支持链式调用）
     */
    public func setInterceptor(v: Interceptor): LinderHttpClient {
        interceptor = v
        this
    }

    /**
     * 自定义TLS握手域名
     * @param v 域名标识
     * @return 当前对象（支持链式调用）
     *
     * 重要：此设置会被后续setUrl()覆盖，
     * 如需设置请在setUrl()后调用
     */
    public func setServerName(v: String): LinderHttpClient {
        tlsConfig.serverName = v
        this
    }

    /**
     * 配置重定向策略
     * @param v 是否自动重定向（默认true）
     * @return 当前对象（支持链式调用）
     */
    public func setAutoRedirect(v: Bool): LinderHttpClient {
        autoRedirect = v
        this
    }

    /**
     * 设置读超时时长
     * @param v 超时时间（不设置默认15秒）
     * @return 当前对象（支持链式调用）
     */
    public func setReadTimeout(v: Duration): LinderHttpClient {
        readTimeout = v
        this
    }

    /**
     * 设置写超时时长
     * @param v 超时时间（不设置默认15秒）
     * @return 当前对象（支持链式调用）
     */
    public func setWriteTimeout(v: Duration): LinderHttpClient {
        writeTimeout = v
        this
    }

    /**
     * 设置请求附带数据
     * @param v RequestBody枚举包裹的数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: RequestBody): LinderHttpClient {
        requestBody = v
        this
    }

    /**
     * 设置请求附带数据
     * @param v String类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: String): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 设置请求附带数据
     * @param v InputStream类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: InputStream): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 设置请求附带数据
     * @param v Array<Byte>类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: Array<Byte>): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 设置请求附带数据
     * @param v DataModel类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: DataModel): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 设置请求附带数据
     * @param v JsonObject类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: JsonObject): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 设置请求附带数据
     * @param v Form类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: Form): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 设置请求附带数据
     * @param v MultipartFormData类型数据
     * @return 当前对象（支持链式调用）
     */
    public func setBody(v: MultipartFormData): LinderHttpClient {
        requestBody = RequestBody.from(v)
        this
    }

    /**
     * 配置客户端 HTTP/2 流控窗口初始值
     * @param v UInt32
     * @return 当前对象（支持链式调用）
     */
    public func setInitialWindowSize(v: UInt32): LinderHttpClient {
        initialWindowSize = v
        this
    }

    /**
     * 配置客户端 HTTP/2 是否支持服务器推送
     * @param v Bool
     * @return 当前对象（支持链式调用）
     */
    public func setEnablePush(v: Bool): LinderHttpClient {
        enablePush = v
        this
    }

    /**
     * 配置客户端 HTTP/2 Hpack 动态表初始值。
     * @param v UInt32
     * @return 当前对象（支持链式调用）
     */
    public func setHeaderTableSize(v: UInt32): LinderHttpClient {
        headerTableSize = v
        this
    }

    /**
     * 设置客户端 http 代理
     * @param v String
     * @return 当前对象（支持链式调用）
     */
    public func setHttpProxy(v: String): LinderHttpClient {
        httpProxy = v
        this
    }

    /**
     * 设置客户端 https 代理
     * @param v String
     * @return 当前对象（支持链式调用）
     */
    public func setHttpsProxy(v: String): LinderHttpClient {
        httpsProxy = v
        this
    }

    /**
     * 清空请求附带数据
     * @return 当前对象（支持链式调用）
     */
    public func clearBody(): LinderHttpClient {
        requestBody = None
        this
    }

    /**
     * 设置默认请求头
     * @return 当前对象（支持链式调用）
     */
    public func setDefaultHeader(): LinderHttpClient {
        headers = HttpHeader()
        this
    }

    /**
     * 取消请求
     * @return 当前对象（支持链式调用）
     */
    public func destroy(): LinderHttpClient {
        if (!client.isNone()) {
            client.getOrThrow().close()
            client = None
        }
        this
    }

    /**
     * 对URL的路径和查询参数进行编码
     * @param originalURL 原始URL对象
     * @return 编码后的URL对象
     * 
     * 说明：此方法会对URL中的路径和查询参数进行编码，
     * 确保特殊字符（如中文、空格等）被正确编码
     */
    private func encodeUrl(originalURL: URL): URL {
        originalURL
    }

    /**
     * 发送请求
     * @param needSetDefaultHeader 是否设置为默认请求头， 默认为否
     * @return HttpResponse 请求返回体对象
     */
    public func send(needSetDefaultHeader!: Bool = false): LinderHttpResponse {
        var requestBuilder = HttpRequestBuilder()
        var res: HttpResponse
        var response: LinderHttpResponse = LinderHttpResponse()

        // 请求前拦截
        if (let Some(intercept) <- interceptor) {
            if (let Some(request) <- intercept.onRequest) {
                request(this)
            }
        }

        try {
            clientBuilder
                .tlsConfig(tlsConfig)
                .autoRedirect(autoRedirect)
                .readTimeout(readTimeout)
                .writeTimeout(writeTimeout)
                .initialWindowSize(initialWindowSize)
                .enablePush(enablePush)
                .headerTableSize(headerTableSize)

            if (httpProxy != '') {
                clientBuilder.httpProxy(httpProxy)
            }
            if (httpsProxy != '') {
                clientBuilder.httpsProxy(httpsProxy)
            }

            requestBuilder.method(method).url(match (url) {
                case RequestUrl.URL(v) => v
                case RequestUrl.STRING(v) => URL.parse(v)
            } |> encodeUrl).setHeaders(headers.rawHeaders)

            if (!requestBody.isNone()) {
                match (requestBody.getOrThrow()) {
                    case RequestBody.String(v) =>
                        requestBuilder.body(v)
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: "text/xml")
                        }
                    case RequestBody.ByteArray(v) =>
                        requestBuilder.body(v)
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: "application/octet-stream")
                        }
                    case RequestBody.InputStream(v) =>
                        requestBuilder.body(v)
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: "application/octet-stream")
                        }
                    case RequestBody.UrlEncoded(v) =>
                        requestBuilder.body(v.toEncodeString())
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: "application/x-www-form-urlencoded")
                        }
                    case RequestBody.Object(v) =>
                        requestBuilder.body(v.toJson().toString())
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: "application/json")
                        }
                    case RequestBody.Json(v) =>
                        requestBuilder.body(v.toString())
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: "application/json")
                        }
                    case RequestBody.Multipart(v) =>
                        requestBuilder.body(v.build())
                        if (headers.get('content-type').isEmpty()) {
                            headers.set(key: "content-type", value: v.getContentType())
                        }
                }
            }
        } catch (e: Exception) {
            // 请求构建错误拦截
            if (let Some(intercept) <- interceptor) {
                if (let Some(error) <- intercept.onError) {
                    error(e, this) 
                }else{
                    throw e
                }
            }else{
                throw e
            }
        }

        try {
            res = (requestBuilder.build() |> clientBuilder.build().send)
            response = LinderHttpResponse(body: res.body, bodySize: res.bodySize, status: res.status,
                headers: res.headers, isPersistent: res.isPersistent, request: res.request)
            if (needSetDefaultHeader) {
                setDefaultHeader()
            }
        } catch (e: Exception) {
            // 请求发送错误拦截
            if (let Some(intercept) <- interceptor) {
                if (let Some(error) <- intercept.onError) {
                    error(e, this)
                }else{
                    throw e
                }
            }else{
                throw e
            }
            
        }

        // 响应拦截
        if (let Some(intercept) <- interceptor) {
            if (let Some(res) <- intercept.onResponse) {
                res(response)
            }
        }

        clearBody()
        response
    }
}
