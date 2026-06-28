package ignite.tests

import ignite.client.*
import std.time.MonoTime

@Test
public class ClientRetryTestSuite {
    func elapsedMs(start: MonoTime): Int64 {
        (MonoTime.now() - start).toMilliseconds()
    }

    func retryProfile(idempotentOnly: Bool): ClientRetryConfig {
        ClientRetryConfig(
            enabled: true,
            maxAttempts: 3,
            idempotentOnly: idempotentOnly,
            baseDelayMs: 80,
            maxDelayMs: 160,
            jitterMs: 0
        )
    }

    func buildClient(): RestClient {
        RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 10
        )
    }

    @TestCase
    public func testIdempotentMethodRetriesWithBackoff(): Unit {
        let client = buildClient().useRetry(retryProfile(true))
        let start = MonoTime.now()
        try {
            let _ = client.get("http://127.0.0.1:1/retry-get")
            @Fail("request should fail on closed local port")
        } catch (_: Exception) {
            @Assert(true)
        }
        let elapsed = elapsedMs(start)
        @Assert(elapsed >= 180, true)
    }

    @TestCase
    public func testNonIdempotentMethodNoRetryByDefault(): Unit {
        let client = buildClient().useRetry(retryProfile(true))
        let start = MonoTime.now()
        try {
            let _ = client.post("http://127.0.0.1:1/retry-post-default", "x")
            @Fail("request should fail on closed local port")
        } catch (_: Exception) {
            @Assert(true)
        }
        let elapsed = elapsedMs(start)
        @Assert(elapsed < 160, true)
    }

    @TestCase
    public func testPerRequestRetryCanEnablePost(): Unit {
        let client = buildClient().useRetry(retryProfile(true))
        let start = MonoTime.now()
        try {
            let _ = client.request()
                .method("POST")
                .url("http://127.0.0.1:1/retry-post-override")
                .body("x")
                .retry(retryProfile(false))
                .send()
            @Fail("request should fail on closed local port")
        } catch (_: Exception) {
            @Assert(true)
        }
        let elapsed = elapsedMs(start)
        @Assert(elapsed >= 180, true)
    }

    @TestCase
    public func testDisableRetrySkipsBackoff(): Unit {
        let client = buildClient().useRetry(retryProfile(true))
        let start = MonoTime.now()
        try {
            let _ = client.request()
                .method("GET")
                .url("http://127.0.0.1:1/retry-disable")
                .body("x")
                .disableRetry()
                .send()
            @Fail("request should fail on closed local port")
        } catch (_: Exception) {
            @Assert(true)
        }
        let elapsed = elapsedMs(start)
        @Assert(elapsed < 160, true)
    }
}
