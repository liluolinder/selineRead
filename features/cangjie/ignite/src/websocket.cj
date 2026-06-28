package ignite

import stdx.net.http.{HttpContext, WebSocket, WebSocketFrame, WebSocketFrameType}
import std.collection.ArrayList

public type WsHandler = (WsConn) -> Unit

public class WsConn {
    let _ws: WebSocket

    public init(ws: WebSocket) {
        _ws = ws
    }

    public func readMessage(): WsMessage {
        let data = ArrayList<UInt8>()
        var msgType = WebSocketFrameType.TextWebFrame
        while (true) {
            let frame = _ws.read()
            match (frame.frameType) {
                case TextWebFrame | BinaryWebFrame =>
                    msgType = frame.frameType
                    for (b in frame.payload) { data.add(b) }
                    if (frame.fin) { break }
                case ContinuationWebFrame =>
                    for (b in frame.payload) { data.add(b) }
                    if (frame.fin) { break }
                case CloseWebFrame =>
                    return WsMessage(messageType: WebSocketFrameType.CloseWebFrame, data: frame.payload)
                case PingWebFrame =>
                    _ws.writePongFrame(frame.payload)
                case _ => ()
            }
        }
        WsMessage(messageType: msgType, data: data.toArray())
    }

    public func writeText(text: String): Unit {
        _ws.write(WebSocketFrameType.TextWebFrame, text.toArray())
    }

    public func writeBinary(data: Array<UInt8>): Unit {
        _ws.write(WebSocketFrameType.BinaryWebFrame, data)
    }

    public func close(status!: UInt16 = 1000, reason!: String = ""): Unit {
        _ws.writeCloseFrame(status: status, reason: reason)
        _ws.closeConn()
    }

    public func ping(data!: Array<UInt8> = Array<UInt8>(0, repeat: 0)): Unit {
        _ws.writePingFrame(data)
    }

    public prop subProtocol: String {
        get() { _ws.subProtocol }
    }
}

public struct WsMessage {
    public let messageType: WebSocketFrameType
    public let data: Array<UInt8>

    public init(messageType!: WebSocketFrameType, data!: Array<UInt8>) {
        this.messageType = messageType
        this.data = data
    }

    public func text(): String {
        String.fromUtf8(data)
    }

    public prop isClose: Bool {
        get() { messageType == WebSocketFrameType.CloseWebFrame }
    }

    public prop isText: Bool {
        get() { messageType == WebSocketFrameType.TextWebFrame }
    }

    public prop isBinary: Bool {
        get() { messageType == WebSocketFrameType.BinaryWebFrame }
    }
}
