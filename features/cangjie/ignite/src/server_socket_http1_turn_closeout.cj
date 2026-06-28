package ignite

class SocketHttp11RuntimeTurnCloseout {
    let requestCloseAfterResponse: Bool
    let responseRequestsClose: Bool
    let shouldCloseConnection: Bool
    let nextConnectionState: SocketHttp11ConnectionState
    let closeReason: String

    init(
        requestCloseAfterResponse: Bool,
        responseRequestsClose: Bool,
        shouldCloseConnection: Bool,
        nextConnectionState: SocketHttp11ConnectionState,
        closeReason: String
    ) {
        this.requestCloseAfterResponse = requestCloseAfterResponse
        this.responseRequestsClose = responseRequestsClose
        this.shouldCloseConnection = shouldCloseConnection
        this.nextConnectionState = nextConnectionState
        this.closeReason = closeReason
    }

    func canReuseConnection(): Bool {
        nextConnectionState == SocketHttp11ConnectionState.ReceivingHead
    }
}

func buildSocketHttp11RuntimeTurnCloseout(
    request: SocketHttp11SessionRequest,
    response: SocketHttp11ResponseSnapshot
): SocketHttp11RuntimeTurnCloseout {
    let requestCloseAfterResponse = request.closeAfterResponse
    let responseRequestsClose = response.shouldCloseConnection() || !response.keepAliveAllowed
    let shouldCloseConnection = requestCloseAfterResponse || responseRequestsClose
    let nextConnectionState = if (shouldCloseConnection) {
        SocketHttp11ConnectionState.Closing
    } else {
        SocketHttp11ConnectionState.ReceivingHead
    }

    SocketHttp11RuntimeTurnCloseout(
        requestCloseAfterResponse,
        responseRequestsClose,
        shouldCloseConnection,
        nextConnectionState,
        resolveSocketHttp11RuntimeTurnCloseReason(
            request,
            requestCloseAfterResponse,
            responseRequestsClose,
            shouldCloseConnection
        )
    )
}

func resolveSocketHttp11RuntimeTurnCloseReason(
    request: SocketHttp11SessionRequest,
    requestCloseAfterResponse: Bool,
    responseRequestsClose: Bool,
    shouldCloseConnection: Bool
): String {
    if (!shouldCloseConnection) {
        return "-"
    }

    if (requestCloseAfterResponse) {
        let closeReason = request.closeReason.trimAscii()
        if (closeReason.size > 0 && closeReason != "-") {
            return closeReason
        }
        return "request_close_after_response"
    }

    if (responseRequestsClose) {
        return "response_close_after_write"
    }

    "-"
}
