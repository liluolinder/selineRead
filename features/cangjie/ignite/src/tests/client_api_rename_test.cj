package ignite.tests

import ignite.client.*
import ignite.api2
import std.collection.{ArrayList, HashMap}

@Test
public class ClientApiRenameTestSuite {
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

    func buildClient(): RestClient {
        RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 10
        )
    }

    @TestCase
    public func testRenamedRestClientAndHookApis(): Unit {
        let marks = ArrayList<String>()
        let client = buildClient()
            .withBaseUrl("http://127.0.0.1:1")
            .withHeader("x-client", "rename")
            .enableCookieJar()
            .withRetryPolicy(ClientRetryConfig(enabled: false))
            .onRequestHook({ _ =>
                marks.add("global-request")
                throw api2.ClientCryptoException(
                    api2.ClientCryptoErrorCode.CryptoUnavailable,
                    "halt-before-network"
                )
            })
            .onErrorHook({ _ =>
                marks.add("global-error")
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("/v1")
                .onErrorHook({ _ =>
                    marks.add("local-error")
                })
                .send()
            @Fail("request should fail from request hook")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(marks.size, 3)
        @Assert(marks[0], "global-request")
        @Assert(marks[1], "global-error")
        @Assert(marks[2], "local-error")
    }

    @TestCase
    public func testRenamedBuilderBodyApis(): Unit {
        let marks = ArrayList<String>()
        let cfg = buildCryptoConfig()
        let formData = ArrayList<(String, String)>()
        formData.add(("a", "1"))

        let files = ArrayList<MultipartFile>()
        let fields = ArrayList<(String, String)>()
        fields.add(("kind", "demo"))

        let client = buildClient()
            .withCrypto(cfg)
            .withRetryPolicy(ClientRetryConfig(enabled: false))
            .onRequestHook({ _ =>
                marks.add("hit")
                throw api2.ClientCryptoException(
                    api2.ClientCryptoErrorCode.CryptoUnavailable,
                    "stop"
                )
            })

        try {
            let _ = client.request()
                .method("POST")
                .url("http://127.0.0.1:1/a")
                .bodyJson("{\"ok\":true}")
                .bodyFormUrlEncoded(formData)
                .bodyMultipartForm(fields, files)
                .bodyEncryptedJson("{\"secure\":true}", aad: "route:/a")
                .send()
            @Fail("request should fail from request hook")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        }

        @Assert(marks.size, 1)
        @Assert(marks[0], "hit")
    }
}
