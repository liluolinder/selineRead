package ignite.tests

import ignite.*

@Test
public class SocketHttp11RequestBodyPlanTestSuite {
    @TestCase
    public func testBodyPlanBuildsBodylessAndBoundedContentLengthPlans(): Unit {
        let getHead = parseSocketHttp11HeadForBodyTest(
            "GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let bodylessPlan = buildSocketHttp11RequestBodyPlan(getHead, "GET /next HTTP/1.1\r\n".toArray())
        @Assert(bodylessPlan.framing, SocketHttp11RequestBodyFraming.Bodyless)
        @Assert(bodylessPlan.requiresBodyStage, false)
        @Assert(bodylessPlan.needsMoreNetworkBytes, false)
        @Assert(bodylessPlan.supportsBoundedRelay(), false)
        @Assert(String.fromUtf8(bodylessPlan.trailingBufferedBytes), "GET /next HTTP/1.1\r\n")

        let postHead = parseSocketHttp11HeadForBodyTest(
            "POST /upload HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\n\r\n"
        )
        let contentLengthPlan = buildSocketHttp11RequestBodyPlan(postHead, "abcdeGET".toArray())
        @Assert(contentLengthPlan.framing, SocketHttp11RequestBodyFraming.ContentLength)
        @Assert(contentLengthPlan.declaredBodyBytes, 5)
        @Assert(contentLengthPlan.remainingNetworkBodyBytes, 0)
        @Assert(contentLengthPlan.requiresBodyStage, true)
        @Assert(contentLengthPlan.needsMoreNetworkBytes, false)
        @Assert(contentLengthPlan.supportsBoundedRelay(), true)
        @Assert(String.fromUtf8(contentLengthPlan.prefetchedBodyBytes), "abcde")
        @Assert(String.fromUtf8(contentLengthPlan.trailingBufferedBytes), "GET")
    }

    @TestCase
    public func testBodyPlanBuildsChunkedPlanAndPreservesPrefetchedBytes(): Unit {
        let head = parseSocketHttp11HeadForBodyTest(
            "POST /stream HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n"
        )
        let plan = buildSocketHttp11RequestBodyPlan(head, "4\r\nWiki\r\n".toArray())

        @Assert(plan.framing, SocketHttp11RequestBodyFraming.Chunked)
        @Assert(plan.declaredBodyBytes, -1)
        @Assert(plan.remainingNetworkBodyBytes, -1)
        @Assert(plan.requiresBodyStage, true)
        @Assert(plan.needsMoreNetworkBytes, true)
        @Assert(plan.supportsBoundedRelay(), false)
        @Assert(String.fromUtf8(plan.prefetchedBodyBytes), "4\r\nWiki\r\n")
        @Assert(plan.trailingBufferedBytes.size, 0)
    }

    @TestCase
    public func testBodyPlanRejectsInvalidFramingHeaders(): Unit {
        let mixed = parseSocketHttp11HeadForBodyTest(
            "POST /bad HTTP/1.1\r\nHost: example.com\r\nContent-Length: 4\r\nTransfer-Encoding: chunked\r\n\r\n"
        )
        assertSocketHttp11BodyPlanFailure(
            mixed,
            Array<UInt8>(0, repeat: 0),
            SocketHttp11BodyPlanErrorCode.ContentLengthWithTransferEncoding
        )

        let conflicting = parseSocketHttp11HeadForBodyTest(
            "POST /bad HTTP/1.1\r\nHost: example.com\r\nContent-Length: 4\r\nContent-Length: 5\r\n\r\n"
        )
        assertSocketHttp11BodyPlanFailure(
            conflicting,
            Array<UInt8>(0, repeat: 0),
            SocketHttp11BodyPlanErrorCode.ConflictingContentLength
        )

        let unsupported = parseSocketHttp11HeadForBodyTest(
            "POST /bad HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: gzip\r\n\r\n"
        )
        assertSocketHttp11BodyPlanFailure(
            unsupported,
            Array<UInt8>(0, repeat: 0),
            SocketHttp11BodyPlanErrorCode.UnsupportedTransferEncoding
        )
    }
}

func parseSocketHttp11HeadForBodyTest(headText: String): SocketHttp11RequestHead {
    match (tryParseSocketHttp11RequestHead(headText.toArray())) {
        case Some(parsed) => parsed
        case None => @Fail("complete HTTP/1.1 head should parse before body-plan tests")
    }
}

func assertSocketHttp11BodyPlanFailure(
    head: SocketHttp11RequestHead,
    tail: Array<UInt8>,
    expectedCode: SocketHttp11BodyPlanErrorCode
): Unit {
    try {
        let _ = buildSocketHttp11RequestBodyPlan(head, tail)
        @Fail("socket HTTP/1.1 body plan should have failed")
    } catch (e: SocketHttp11BodyPlanException) {
        @Assert(e.code, expectedCode)
    }
}
