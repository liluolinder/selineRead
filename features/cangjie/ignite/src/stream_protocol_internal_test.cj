package ignite

@Test
public class StreamProtocolHeaderTestSuite {
    @TestCase
    public func testHttp2ProtocolsDoNotEmitHttp11OnlyHeaders(): Unit {
        @Assert(shouldEmitChunkedTransferHeader("h2"), false)
        @Assert(shouldEmitChunkedTransferHeader("HTTP/2"), false)
        @Assert(shouldEmitChunkedTransferHeader("http2"), false)
        @Assert(shouldEmitConnectionKeepAliveHeader("h2c"), false)
        @Assert(shouldEmitConnectionKeepAliveHeader("HTTP/2.0"), false)
    }

    @TestCase
    public func testHttp11ProtocolsStillEmitLegacyStreamingHeaders(): Unit {
        @Assert(shouldEmitChunkedTransferHeader("HTTP/1.1"), true)
        @Assert(shouldEmitConnectionKeepAliveHeader("HTTP/1.1"), true)
        @Assert(shouldEmitChunkedTransferHeader(""), true)
        @Assert(shouldEmitConnectionKeepAliveHeader(""), true)
    }
}
