package ignite.tests

import std.collection.HashMap
import std.collection.ArrayList
import ignite.client.*
import ignite.api2

@Test
public class ClientAliasMatrixTestSuite {
    func buildCryptoConfig(): api2.ClientCryptoConfig {
        let ring = HashMap<String, Array<UInt8>>()
        ring.add("k1", "0123456789abcdef0123456789abcdef".toArray())
        api2.ClientCryptoConfig(
            providerKind: api2.ClientCryptoProviderKind.StdxFallback,
            activeKid: "k1",
            keyRing: ring,
            aeadAlgorithm: "AES-256-GCM"
        )
    }

    @TestCase
    public func testAliasPostJsonEncryptedPathStillWorks(): Unit {
        let marks = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 3,
            writeTimeout: Duration.second * 3,
            poolSize: 2
        )
            .withBaseUrl("http://127.0.0.1:1")
            .withCrypto(buildCryptoConfig())
            .withRetryPolicy(ClientRetryConfig(enabled: false))
            .onRequestHook({ _ =>
                marks.add("request")
                throw api2.ClientCryptoException(
                    api2.ClientCryptoErrorCode.CryptoUnavailable,
                    "alias stop"
                )
            })
            .onErrorHook({ _ =>
                marks.add("error")
            })

        try {
            let _ = client.postJsonEncrypted("/alias-secure", "{\"ok\":true}", aad: "route:/alias-secure")
            @Fail("alias encrypted post should fail from hook")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(marks.size, 2)
        @Assert(marks[0], "request")
        @Assert(marks[1], "error")
    }

    @TestCase
    public func testAliasCookieAndRetryBuilderPathStillWorks(): Unit {
        let marks = ArrayList<String>()
        let cookieStore = CookieStore()
        let client = RestClient(
            readTimeout: Duration.second * 3,
            writeTimeout: Duration.second * 3,
            poolSize: 2
        )
            .withBaseUrl("http://127.0.0.1:1")
            .enableCookieJar()
            .withCookieJar(cookieStore)
            .withRetryPolicy(ClientRetryConfig(enabled: false))
            .onErrorHook({ _ =>
                marks.add("error")
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("/alias-builder")
                .withQuery("q", "1")
                .withHeader("x-ignite-log-case", "alias-builder")
                .withRetryPolicy(ClientRetryConfig(enabled: false))
                .onRequestHook({ _ =>
                    throw api2.ClientCryptoException(
                        api2.ClientCryptoErrorCode.CryptoUnavailable,
                        "builder alias stop"
                    )
                })
                .send()
            @Fail("builder alias request should fail from hook")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(marks.size, 1)
        @Assert(marks[0], "error")
    }
}
