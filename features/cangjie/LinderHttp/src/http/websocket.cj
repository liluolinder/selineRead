package linderHttp.http

/**
 * 收到的一条 WebSocket 消息。
 *
 * 分片（Continuation）由库内部自动拼装，调用方拿到的永远是完整消息。
 */
public enum WebSocketMessage {
    /** 文本消息 */
    | Text(String)
    /** 二进制消息 */
    | Binary(Array<UInt8>)
    /** 收到 Ping（库已自动回 Pong） */
    | Ping(Array<UInt8>)
    /** 收到 Pong */
    | Pong(Array<UInt8>)
    /** 对端关闭 */
    | Closed(?UInt16, String)
}

/**
 * WebSocket 连接。
 *
 * ```cangjie
 * let client = HttpClientBuilder().build()
 * let ws = client.websocket("wss://echo.example.com/ws")
 * ws.sendText("hello")
 * match (ws.receive()) {
 *     case Some(WebSocketMessage.Text(text)) => println(text)
 *     case _ => ()
 * }
 * ws.close()
 * client.close()
 * ```
 *
 * `receive()` 会阻塞等待；返回 None 表示没有更多消息（连接已关闭）。
 * 实现 `Resource`，也可用 `try (ws = ...)` 自动关闭。
 */
public class WebSocket <: Resource {
    private let socket: NativeWebSocket
    private let transport: Client
    private let urlValue: String
    private var closedFlag: Bool = false

    internal init(socket: NativeWebSocket, transport: Client, url: String) {
        this.socket = socket
        this.transport = transport
        this.urlValue = url
    }

    public func url(): String {
        urlValue
    }

    /** 协商出的子协议（服务端未选择则为 None）。 */
    public prop subProtocol: ?String {
        get() {
            socket.subProtocol
        }
    }

    public func sendText(message: String): Unit {
        ensureOpen()
        socket.write(WebSocketFrameType.TextWebFrame, message.toArray())
    }

    public func sendBinary(data: Array<UInt8>): Unit {
        ensureOpen()
        socket.write(WebSocketFrameType.BinaryWebFrame, data)
    }

    public func ping(payload!: Array<UInt8> = Array<UInt8>()): Unit {
        ensureOpen()
        socket.writePingFrame(payload)
    }

    /**
     * 读取一条完整消息；收到 Ping 自动回 Pong，收到 Close 返回 None 并关闭连接。
     */
    public func receive(): ?WebSocketMessage {
        if (closedFlag) {
            return None
        }
        let payload = ArrayList<UInt8>()
        var frameType: ?WebSocketFrameType = None
        var frame = socket.read()
        while (true) {
            match (frame.frameType) {
                case WebSocketFrameType.TextWebFrame | WebSocketFrameType.BinaryWebFrame =>
                    frameType = Some(frame.frameType)
                    payload.add(all: frame.payload)
                    if (frame.fin) {
                        break
                    }
                case WebSocketFrameType.ContinuationWebFrame =>
                    payload.add(all: frame.payload)
                    if (frame.fin) {
                        break
                    }
                case WebSocketFrameType.CloseWebFrame =>
                    try {
                        socket.write(WebSocketFrameType.CloseWebFrame, frame.payload)
                    } catch (_: Exception) {
                        ()
                    }
                    close()
                    return Some(WebSocketMessage.Closed(None, String.fromUtf8(frame.payload)))
                case WebSocketFrameType.PingWebFrame =>
                    try {
                        socket.writePongFrame(frame.payload)
                    } catch (_: Exception) {
                        ()
                    }
                    return Some(WebSocketMessage.Ping(frame.payload))
                case WebSocketFrameType.PongWebFrame => return Some(WebSocketMessage.Pong(frame.payload))
                case _ => ()
            }
            frame = socket.read()
        }
        match (frameType) {
            case Some(WebSocketFrameType.TextWebFrame) => Some(WebSocketMessage.Text(String.fromUtf8(payload.toArray())))
            case Some(WebSocketFrameType.BinaryWebFrame) => Some(WebSocketMessage.Binary(payload.toArray()))
            case _ => None
        }
    }

    /** 只要文本消息；二进制消息返回 None。 */
    public func receiveText(): ?String {
        match (receive()) {
            case Some(WebSocketMessage.Text(text)) => Some(text)
            case _ => None
        }
    }

    /** 只要二进制消息；文本消息返回 None。 */
    public func receiveBinary(): ?Array<UInt8> {
        match (receive()) {
            case Some(WebSocketMessage.Binary(data)) => Some(data)
            case _ => None
        }
    }

    /** 发送关闭帧并关闭底层连接。 */
    public func close(): Unit {
        if (closedFlag) {
            return
        }
        closedFlag = true
        try {
            socket.writeCloseFrame(status: 1000)
        } catch (_: Exception) {
            ()
        }
        try {
            socket.closeConn()
        } catch (_: Exception) {
            ()
        }
        try {
            transport.close()
        } catch (_: Exception) {
            ()
        }
    }

    public func isClosed(): Bool {
        closedFlag
    }

    public func toString(): String {
        "WebSocket(${urlValue}, closed=${closedFlag})"
    }

    private func ensureOpen(): Unit {
        if (closedFlag) {
            throw HttpError(ErrorKind.Closed, "WebSocket 已关闭", url: urlValue)
        }
    }
}
