package ignite.tests

import std.collection.HashMap
import std.collection.ArrayList
import ignite.client.*
import ignite.api2

@Test
public class ClientLegacyCompatTestSuite {
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
    public func testLegacyRestClientApisRemainUsable(): Unit {
        let marks = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 3,
            writeTimeout: Duration.second * 3,
            poolSize: 2
        )
            .baseUrl("http://127.0.0.1:1")
            .defaultHeader("x-client", "legacy")
            .useCookies()
            .useRetry(ClientRetryConfig(enabled: false))
            .onRequest({ _ =>
                marks.add("legacy-request")
                throw api2.ClientCryptoException(
                    api2.ClientCryptoErrorCode.CryptoUnavailable,
                    "legacy request stop"
                )
            })
            .onError({ _ =>
                marks.add("legacy-error")
            })

        try {
            let _ = client.get("/v1/legacy")
            @Fail("legacy request should fail from request hook")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(marks.size, 2)
        @Assert(marks[0], "legacy-request")
        @Assert(marks[1], "legacy-error")
    }

    @TestCase
    public func testLegacyBuilderAliasesRemainUsable(): Unit {
        let cfg = buildCryptoConfig()
        let marks = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 3,
            writeTimeout: Duration.second * 3,
            poolSize: 2
        )
            .useCrypto(cfg)
            .onError({ _ =>
                marks.add("err")
            })

        try {
            let _ = client.request()
                .method("POST")
                .url("http://127.0.0.1:1/v1/legacy-builder")
                .withQuery("page", "1")
                .withHeader("x-ignite-log-route", "legacy")
                .withBasicAuth("u", "p")
                .withBearerToken("token")
                .bodyEncryptedJson("{\"ok\":true}", aad: "route:/v1/legacy-builder")
                .onRequestHook({ _ =>
                    throw api2.ClientCryptoException(
                        api2.ClientCryptoErrorCode.CryptoUnavailable,
                        "legacy builder stop"
                    )
                })
                .send()
            @Fail("legacy builder request should fail from hook")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(marks.size, 1)
        @Assert(marks[0], "err")
    }
}
