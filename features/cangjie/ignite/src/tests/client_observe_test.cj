package ignite.tests

import std.collection.ArrayList
import ignite.client.*
import ignite.api2

@Test
public class ClientObserveTestSuite {
    @TestCase
    public func testObservedErrorFromRequestHookIncludesCryptoClassAndFields(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 3,
            writeTimeout: Duration.second * 3,
            poolSize: 2
        )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("POST")
                .url("http://127.0.0.1:1/observe-hook")
                .header("x-ignite-log-trace-id", "trace-001")
                .onRequest({ _ =>
                    throw api2.ClientCryptoException(
                        api2.ClientCryptoErrorCode.CryptoUnavailable,
                        "crypto hook rejected"
                    )
                })
                .send()
            @Fail("request hook should fail")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(observedMessages.size, 1)
        @Assert(observeContainsStr(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(observeContainsStr(observedMessages[0], "errorClass=CRYPTO"), true)
        @Assert(observeContainsStr(observedMessages[0], "retryCount=0"), true)
        @Assert(observeContainsStr(observedMessages[0], "durationMs="), true)
        @Assert(observeContainsStr(observedMessages[0], "fields=trace-id=trace-001"), true)
    }

    @TestCase
    public func testObservedErrorIncludesRetryCountForNetworkFailures(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 2
        )
            .useRetry(
                ClientRetryConfig(
                    enabled: true,
                    maxAttempts: 3,
                    idempotentOnly: true,
                    baseDelayMs: 5,
                    maxDelayMs: 5,
                    jitterMs: 0
                )
            )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("http://127.0.0.1:1/observe-network")
                .header("x-ignite-log-op", "retry-test")
                .send()
            @Fail("request should fail on closed local port")
        } catch (_: Exception) {
            @Assert(true)
        }

        @Assert(observedMessages.size, 1)
        @Assert(observeContainsStr(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(observeContainsStr(observedMessages[0], "retryCount=2"), true)
        @Assert(
            observeContainsStr(observedMessages[0], "errorClass=NETWORK") ||
            observeContainsStr(observedMessages[0], "errorClass=UNKNOWN"),
            true
        )
        @Assert(observeContainsStr(observedMessages[0], "fields=op=retry-test"), true)
    }

    @TestCase
    public func testObservedErrorClassifiesTimedOutTransportPhrase(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 2
        )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("http://127.0.0.1:1/observe-timeout")
                .header("x-ignite-log-op", "timeout-test")
                .onRequest({ _ =>
                    throw Exception("dial tcp 10.0.0.8:443: operation timed out before send")
                })
                .send()
            @Fail("request hook should fail with timeout-like message")
        } catch (e: Exception) {
            @Assert(observeContainsStr(e.message, "operation timed out"), true)
        }

        @Assert(observedMessages.size, 1)
        @Assert(observeContainsStr(observedMessages[0], "errorClass=TIMEOUT"), true)
        @Assert(observeContainsStr(observedMessages[0], "retryCount=0"), true)
        @Assert(observeContainsStr(observedMessages[0], "fields=op=timeout-test"), true)
    }
}

func observeContainsStr(hay: String, needle: String): Bool {
    let h = hay.toRuneArray()
    let n = needle.toRuneArray()
    if (n.size == 0) { return true }
    if (h.size < n.size) { return false }
    for (i in 0..=(h.size - n.size)) {
        var ok = true
        for (j in 0..n.size) {
            if (h[i + j] != n[j]) { ok = false; break }
        }
        if (ok) { return true }
    }
    false
}
