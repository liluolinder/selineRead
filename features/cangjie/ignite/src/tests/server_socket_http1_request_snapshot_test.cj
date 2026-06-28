package ignite.tests

import ignite.*

@Test
public class SocketHttp11RequestSnapshotTestSuite {
    @TestCase
    public func testRequestSnapshotBuildsReadOnlyAcceptedMinimalSurface(): Unit {
        let request = openSocketHttp11Request(
            "GET /users?active=1 HTTP/1.1\r\nHost: example.com\r\nX-Request-Id: abc\r\n\r\n"
        )
        let seed = buildSocketHttp11DispatchSeed(request)
        let snapshot = buildSocketHttp11RequestSnapshot(
            request,
            seed,
            remoteAddress: "127.0.0.1:9000"
        )

        @Assert(snapshot.method, "GET")
        @Assert(snapshot.version, "HTTP/1.1")
        @Assert(snapshot.remoteAddress, "127.0.0.1:9000")
        @Assert(snapshot.rawTarget, "/users?active=1")
        @Assert(snapshot.targetForm, SocketHttp11RequestTargetForm.OriginForm)
        @Assert(snapshot.targetFormName(), "origin-form")
        @Assert(snapshot.dispatchPath ?? "", "/users")
        @Assert(snapshot.queryString, "active=1")
        @Assert(snapshot.authority, "example.com")
        @Assert(snapshot.scheme, "")
        @Assert(snapshot.header("host") ?? "", "example.com")
        @Assert(snapshot.header("x-request-id") ?? "", "abc")
        @Assert(snapshot.header("missing").isNone(), true)
        @Assert(snapshot.canResolveDispatchPlan(), true)
        @Assert(snapshot.normalizedDispatchTarget(), "/users?active=1")
        @Assert(snapshot.bodyPlan.framing, SocketHttp11RequestBodyFraming.Bodyless)
        @Assert(snapshot.bodyPlan.requiresBodyStage, false)
    }

    @TestCase
    public func testRequestSnapshotPreservesBodyPlanHandoffVocabulary(): Unit {
        let request = openSocketHttp11Request(
            "POST /upload HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\n\r\nabc"
        )
        let seed = buildSocketHttp11DispatchSeed(request)
        let snapshot = buildSocketHttp11RequestSnapshot(request, seed)

        @Assert(snapshot.method, "POST")
        @Assert(snapshot.dispatchPath ?? "", "/upload")
        @Assert(snapshot.bodyPlan.framing, SocketHttp11RequestBodyFraming.ContentLength)
        @Assert(snapshot.bodyPlan.declaredBodyBytes, 5)
        @Assert(snapshot.bodyPlan.remainingNetworkBodyBytes, 2)
        @Assert(snapshot.bodyPlan.requiresBodyStage, true)
        @Assert(snapshot.bodyPlan.needsMoreNetworkBytes, true)
        @Assert(String.fromUtf8(snapshot.bodyPlan.prefetchedBodyBytes), "abc")
        @Assert(snapshot.bodyPlan.trailingBufferedBytes.size, 0)
        @Assert(snapshot.header("content-length") ?? "", "5")
    }

    @TestCase
    public func testRequestSnapshotRejectsMethodMismatch(): Unit {
        let request = openSocketHttp11Request(
            "GET /same HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let otherRequest = openSocketHttp11Request(
            "POST /same HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let otherSeed = buildSocketHttp11DispatchSeed(otherRequest)

        try {
            let _ = buildSocketHttp11RequestSnapshot(request, otherSeed)
            @Fail("request snapshot should reject mismatched dispatch methods")
        } catch (e: SocketHttp11RequestSnapshotException) {
            @Assert(e.code, SocketHttp11RequestSnapshotErrorCode.MethodMismatch)
        }
    }

    @TestCase
    public func testRequestSnapshotRejectsMismatchedDispatchSeed(): Unit {
        let request = openSocketHttp11Request(
            "GET /first HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let otherRequest = openSocketHttp11Request(
            "GET /second HTTP/1.1\r\nHost: example.com\r\n\r\n"
        )
        let otherSeed = buildSocketHttp11DispatchSeed(otherRequest)

        try {
            let _ = buildSocketHttp11RequestSnapshot(request, otherSeed)
            @Fail("request snapshot should reject mismatched dispatch seed")
        } catch (e: SocketHttp11RequestSnapshotException) {
            @Assert(e.code, SocketHttp11RequestSnapshotErrorCode.TargetMismatch)
        }
    }
}

func openSocketHttp11Request(wire: String): SocketHttp11SessionRequest {
    let session = SocketHttp11ConnectionSession()
    session.appendHeadBytes(wire.toArray())
    match (session.tryOpenRequest()) {
        case Some(request) => request
        case None => throw Exception("expected a complete HTTP/1.1 request")
    }
}
