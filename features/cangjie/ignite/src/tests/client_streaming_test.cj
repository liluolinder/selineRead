package ignite.tests

import ignite.client.*
import std.collection.ArrayList
import std.io.InputStream
import stdx.net.http.HttpResponseBuilder
import std.time.MonoTime

@Test
public class ClientStreamingTestSuite {
    @TestCase
    public func testBodyBytesHandlesLargePayload(): Unit {
        let payload = makePayload(1024 * 512)
        let response = ClientResponse(
            HttpResponseBuilder()
                .status(200)
                .body(payload)
                .build()
        )

        let start = MonoTime.now()
        let bytes = response.bodyBytes()
        let elapsedMs = (MonoTime.now() - start).toMilliseconds()
        @Assert(bytes.size, payload.size)
        @Assert(bytes[0], payload[0])
        @Assert(bytes[12345], payload[12345])
        @Assert(bytes[payload.size - 1], payload[payload.size - 1])
        @Assert(elapsedMs < 2000, true)

        let cached = response.bodyBytes()
        @Assert(cached.size, payload.size)
        @Assert(cached[12345], payload[12345])
    }

    @TestCase
    public func testBodyStreamSupportsChunkedReadForLargePayload(): Unit {
        let payload = makePayload(1024 * 256)
        let expectedChecksum = checksum(payload)

        let response = ClientResponse(
            HttpResponseBuilder()
                .status(200)
                .body(payload)
                .build()
        )

        let start = MonoTime.now()
        let stream = response.bodyStream()
        let tmp = Array<UInt8>(4096, repeat: 0)
        var totalSize: Int64 = 0
        var sum: Int64 = 0
        while (true) {
            let n = stream.read(tmp)
            if (n <= 0) {
                break
            }
            totalSize += n
            for (i in 0..n) {
                sum += Int64(tmp[i])
            }
        }
        let elapsedMs = (MonoTime.now() - start).toMilliseconds()

        @Assert(totalSize, payload.size)
        @Assert(sum, expectedChecksum)
        @Assert(elapsedMs < 2000, true)
    }

    @TestCase
    public func testBodyStreamReturnsConsumedStreamAfterBodyBytesCachesPayload(): Unit {
        let payload = makePayload(1024 * 64)
        let response = ClientResponse(
            HttpResponseBuilder()
                .status(200)
                .body(payload)
                .build()
        )

        let cached = response.bodyBytes()
        @Assert(cached.size, payload.size)
        @Assert(cached[777], payload[777])

        let drained = readAllFromStream(response.bodyStream())
        @Assert(drained.size, 0)

        let cachedAgain = response.bodyBytes()
        @Assert(cachedAgain.size, payload.size)
        @Assert(cachedAgain[777], payload[777])
    }

    @TestCase
    public func testDiscardCanDrainLargePayload(): Unit {
        let payload = makePayload(1024 * 256)
        let response = ClientResponse(
            HttpResponseBuilder()
                .status(200)
                .body(payload)
                .build()
        )

        response.discard()
        let after = response.bodyBytes()
        @Assert(after.size, 0)
    }

    @TestCase
    public func testObserveMetadataRemainsReadableAfterBodyDrainAndDiscard(): Unit {
        let afterBodyBytes = makeObservedResponse(makePayload(2048))
        let afterDiscard = makeObservedResponse(makePayload(2048))

        let cached = afterBodyBytes.bodyBytes()
        @Assert(cached.size, 2048)
        assertObservedMetadata(afterBodyBytes, 202)

        afterDiscard.discard()
        let drained = afterDiscard.bodyBytes()
        @Assert(drained.size, 0)
        assertObservedMetadata(afterDiscard, 202)
    }
}

func makePayload(size: Int64): Array<UInt8> {
    let out = Array<UInt8>(size, repeat: 0)
    var i: Int64 = 0
    while (i < size) {
        out[i] = UInt8(i % 251)
        i += 1
    }
    out
}

func checksum(data: Array<UInt8>): Int64 {
    var sum: Int64 = 0
    for (b in data) {
        sum += Int64(b)
    }
    sum
}

func readAllFromStream(stream: InputStream): Array<UInt8> {
    let chunks = ArrayList<Array<UInt8>>()
    let tmp = Array<UInt8>(4096, repeat: 0)
    var totalSize: Int64 = 0
    while (true) {
        let n = stream.read(tmp)
        if (n <= 0) {
            break
        }
        let chunk = Array<UInt8>(n, repeat: 0)
        for (i in 0..n) {
            chunk[i] = tmp[i]
        }
        totalSize += n
        chunks.add(chunk)
    }

    let out = Array<UInt8>(totalSize, repeat: 0)
    var offset: Int64 = 0
    for (chunk in chunks) {
        for (i in 0..chunk.size) {
            out[offset + i] = chunk[i]
        }
        offset += chunk.size
    }
    out
}

func makeObservedResponse(payload: Array<UInt8>): ClientResponse {
    let response = ClientResponse(
        HttpResponseBuilder()
            .status(202)
            .body(payload)
            .build()
    )
    response.headers.add("x-ignite-observe-error-class", "NONE")
    response.headers.add("x-ignite-observe-backend-id", "stdx-http-client")
    response.headers.add("x-ignite-observe-provider-id", "-")
    response.headers.add("x-ignite-observe-crypto-provider-id", "-")
    response.headers.add("x-ignite-observe-public-path", "stable-default")
    response.headers.add("x-ignite-observe-risk-level", "low")
    response.headers.add("x-ignite-observe-transport-tags", "scene=client,scheme=http")
    response.headers.add("x-ignite-observe-retry-count", "0")
    response.headers.add("x-ignite-observe-duration-ms", "12")
    response.headers.add("x-ignite-observe-fields", "case=streaming")
    response.headers.add("x-ignite-observe-selected-reason", "stable_default_path")
    response.headers.add("x-ignite-observe-fallback-chain", "-")
    response.headers.add("x-ignite-observe-candidate-order", "stdx-http-client")
    response
}

func assertObservedMetadata(response: ClientResponse, expectedStatus: UInt16): Unit {
    match (response.observeSnapshot()) {
        case Some(snapshot) =>
            @Assert(snapshot.outcome, "success")
            @Assert(snapshot.responseStatus, expectedStatus)
            @Assert(snapshot.backendId, "stdx-http-client")
            @Assert(snapshot.publicPath, "stable-default")
            @Assert(snapshot.fields, "case=streaming")
        case None => @Fail("expected observe snapshot after body drain")
    }

    match (response.transportTouchpoint()) {
        case Some(touchpoint) =>
            @Assert(touchpoint.selectedBackend, "stdx-http-client")
            @Assert(touchpoint.selectedReason, "stable_default_path")
            @Assert(touchpoint.publicPath, "stable-default")
            @Assert(touchpoint.transportTags, "scene=client,scheme=http")
        case None => @Fail("expected transport touchpoint after body drain")
    }
}
