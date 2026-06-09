package linderHttp


/**
 * WebSocket客户端封装类
 * 
 * 提供简化的WebSocket连接和消息收发功能。
 * 
 * ## 功能特性
 * - WebSocket连接管理
 * - 文本/二进制消息收发
 * - Ping/Pong心跳
 * - 自动处理消息分片
 * - 子协议支持
 * 
 * ## 使用示例
 * ```cangjie
 * let ws = WebSocketClient("wss://echo.websocket.org")
 * ws.connect()
 * ws.sendText("Hello, WebSocket!")
 * let message = ws.readText()
 * ws.close()
 * ```
 */
public class WebSocketClient {
    /**
     * 底层WebSocket连接
     */
    private var connection: ?WebSocket = None
    
    /**
     * 连接URL
     */
    public var url: URL
    
    /**
     * 子协议列表
     */
    public var subProtocols: ArrayList<String> = ArrayList<String>()
    
    /**
     * 自定义请求头
     */
    public var headers: HttpHeaders = HttpHeaders()
    
    /**
     * TLS配置
     */
    public var tlsConfig: ?TlsClientConfig = None
    
    /**
     * 选定的子协议（连接成功后可用）
     */
    public prop selectedSubProtocol: ?String {
        get() {
            if (connection.isNone()) {
                None
            } else {
                connection.getOrThrow().subProtocol
            }
        }
    }
    
    /**
     * 构造函数
     * @param url WebSocket服务器地址 (ws:// 或 wss://)
     */
    public init(url: String) {
        this.url = URL.parse(url)
    }
    
    /**
     * 构造函数
     * @param url URL对象
     */
    public init(url: URL) {
        this.url = url
    }
    
    /**
     * 设置子协议
     * @param protocols 子协议列表
     * @return 当前对象（支持链式调用）
     */
    public func setSubProtocols(protocols: ArrayList<String>): WebSocketClient {
        this.subProtocols = protocols
        this
    }
    
    /**
     * 设置子协议
     * @param protocols 子协议数组
     * @return 当前对象（支持链式调用）
     */
    public func setSubProtocols(protocols: Array<String>): WebSocketClient {
        this.subProtocols = ArrayList<String>()
        for (p in protocols) {
            this.subProtocols.add(p)
        }
        this
    }
    
    /**
     * 添加子协议
     * @param protocol 子协议名称
     * @return 当前对象（支持链式调用）
     */
    public func addSubProtocol(protocol: String): WebSocketClient {
        this.subProtocols.add(protocol)
        this
    }
    
    /**
     * 设置请求头
     * @param headers HttpHeaders对象
     * @return 当前对象（支持链式调用）
     */
    public func setHeaders(headers: HttpHeaders): WebSocketClient {
        this.headers = headers
        this
    }
    
    /**
     * 添加请求头
     * @param name 头部名称
     * @param value 头部值
     * @return 当前对象（支持链式调用）
     */
    public func addHeader(name: String, value: String): WebSocketClient {
        this.headers.add(name, value)
        this
    }
    
    /**
     * 设置TLS配置
     * @param config TLS配置
     * @return 当前对象（支持链式调用）
     */
    public func setTlsConfig(config: TlsClientConfig): WebSocketClient {
        this.tlsConfig = config
        this
    }
    
    /**
     * 连接WebSocket服务器
     * @return 响应头信息
     * @throws HttpException 连接失败时抛出
     */
    public func connect(): HttpHeaders {
        let clientBuilder = ClientBuilder()
        if (!tlsConfig.isNone()) {
            clientBuilder.tlsConfig(tlsConfig.getOrThrow())
        }
        
        let client = clientBuilder.build()
        let (ws, respHeaders) = WebSocket.upgradeFromClient(
            client, 
            url, 
            subProtocols: subProtocols, 
            headers: headers
        )
        client.close()
        connection = ws
        respHeaders
    }
    
    /**
     * 发送文本消息
     * @param message 文本内容
     */
    public func sendText(message: String): Unit {
        if (connection.isNone()) {
            throw HttpException("WebSocket未连接")
        }
        connection.getOrThrow().write(TextWebFrame, message.toArray())
    }
    
    /**
     * 发送二进制消息
     * @param data 二进制数据
     */
    public func sendBinary(data: Array<UInt8>): Unit {
        if (connection.isNone()) {
            throw HttpException("WebSocket未连接")
        }
        connection.getOrThrow().write(BinaryWebFrame, data)
    }
    
    /**
     * 发送Ping帧
     */
    public func ping(): Unit {
        if (connection.isNone()) {
            throw HttpException("WebSocket未连接")
        }
        connection.getOrThrow().write(PingWebFrame, Array<UInt8>())
    }
    
    /**
     * 发送Ping帧
     * @param payload 负载数据
     */
    public func ping(payload: Array<UInt8>): Unit {
        if (connection.isNone()) {
            throw HttpException("WebSocket未连接")
        }
        connection.getOrThrow().write(PingWebFrame, payload)
    }
    
    /**
     * 发送Pong帧
     * @param payload 负载数据
     */
    public func pong(payload: Array<UInt8>): Unit {
        if (connection.isNone()) {
            throw HttpException("WebSocket未连接")
        }
        connection.getOrThrow().writePongFrame(payload)
    }
    
    /**
     * 读取消息帧
     * @return WebSocketFrame对象
     */
    public func read(): WebSocketFrame {
        if (connection.isNone()) {
            throw HttpException("WebSocket未连接")
        }
        connection.getOrThrow().read()
    }
    
    /**
     * 读取文本消息（自动处理分片）
     * @return 文本内容，如果是关闭帧返回None
     */
    public func readText(): ?String {
        let data = ArrayList<UInt8>()
        var frame = read()
        
        while (true) {
            match (frame.frameType) {
                case ContinuationWebFrame =>
                    data.add(all: frame.payload)
                    if (frame.fin) {
                        break
                    }
                case TextWebFrame =>
                    if (!data.isEmpty()) {
                        throw HttpException("无效的帧序列")
                    }
                    data.add(all: frame.payload)
                    if (frame.fin) {
                        break
                    }
                case BinaryWebFrame =>
                    throw HttpException("期望文本帧，但收到二进制帧")
                case CloseWebFrame =>
                    return None
                case PingWebFrame =>
                    pong(frame.payload)
                case _ => ()
            }
            frame = read()
        }
        
        String.fromUtf8(data.toArray())
    }
    
    /**
     * 读取二进制消息（自动处理分片）
     * @return 二进制数据，如果是关闭帧返回None
     */
    public func readBinary(): ?Array<UInt8> {
        let data = ArrayList<UInt8>()
        var frame = read()
        
        while (true) {
            match (frame.frameType) {
                case ContinuationWebFrame =>
                    data.add(all: frame.payload)
                    if (frame.fin) {
                        break
                    }
                case BinaryWebFrame =>
                    if (!data.isEmpty()) {
                        throw HttpException("无效的帧序列")
                    }
                    data.add(all: frame.payload)
                    if (frame.fin) {
                        break
                    }
                case TextWebFrame =>
                    throw HttpException("期望二进制帧，但收到文本帧")
                case CloseWebFrame =>
                    return None
                case PingWebFrame =>
                    pong(frame.payload)
                case _ => ()
            }
            frame = read()
        }
        
        data.toArray()
    }
    
    /**
     * 发送关闭帧
     * @param status 关闭状态码（默认1000表示正常关闭）
     */
    public func close(status!: UInt16 = 1000): Unit {
        if (connection.isNone()) {
            return
        }
        let highByte: UInt8 = UInt8((status >> 8) & 0xFF)
        let lowByte: UInt8 = UInt8(status & 0xFF)
        let statusBytes: Array<UInt8> = [highByte, lowByte]
        connection.getOrThrow().write(CloseWebFrame, statusBytes)
    }
    
    /**
     * 发送关闭帧并关闭底层连接
     * @param status 关闭状态码
     */
    public func closeConnection(status!: UInt16 = 1000): Unit {
        if (connection.isNone()) {
            return
        }
        close(status: status)
        let frame = read()
        // 等待服务器的关闭帧响应
        if (frame.frameType != CloseWebFrame) {
            // 如果不是关闭帧，继续读取
        }
        connection.getOrThrow().closeConn()
        connection = None
    }
    
    /**
     * 检查连接状态
     * @return 是否已连接
     */
    public func isConnected(): Bool {
        !connection.isNone()
    }
    
    /**
     * 获取底层WebSocket对象
     * @return WebSocket对象
     */
    public func getRawWebSocket(): ?WebSocket {
        connection
    }
}
