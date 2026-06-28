package ignite.tests

import ignite.client.*
import std.collection.ArrayList

@Test
public class ClientConnectTransportTestSuite {
    @TestCase
    public func testClosedLocalPortIsObservedAsConnectFailure(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
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
                .url("http://127.0.0.1:1/connect-failure")
                .header("x-ignite-log-case", "transport-connect-failure")
                .send()
            @Fail("closed local port should fail")
        } catch (_: Exception) {
            @Assert(true)
        } finally {
            client.close()
        }

        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(contains(observedMessages[0], "errorClass=NETWORK"), true)
        @Assert(contains(observedMessages[0], "phase=connect"), true)
        @Assert(containsAny(observedMessages[0], "causeCode=connection_refused", "causeCode=connect_error"), true)
        @Assert(contains(observedMessages[0], "backendId=stdx-http-client"), true)
        @Assert(contains(observedMessages[0], "providerId=-"), true)
        @Assert(contains(observedMessages[0], "publicPath=stable-default"), true)
        @Assert(contains(observedMessages[0], "retryable=true"), true)
        @Assert(contains(observedMessages[0], "fallbackSuggested=false"), true)
        @Assert(contains(observedMessages[0], "connectionConsumed=false"), true)
        @Assert(contains(observedMessages[0], "retryCount=2"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-connect-failure"), true)
    }

    func contains(text: String, target: String): Bool {
        let t = text.toRuneArray()
        let p = target.toRuneArray()
        if (p.size == 0) {
            return true
        }
        if (t.size < p.size) {
            return false
        }
        var i: Int64 = 0
        while (i <= t.size - p.size) {
            var ok = true
            var j: Int64 = 0
            while (j < p.size) {
                if (t[i + j] != p[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) {
                return true
            }
            i += 1
        }
        false
    }

    func containsAny(text: String, left: String, right: String): Bool {
        contains(text, left) || contains(text, right)
    }
}
