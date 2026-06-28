package ignite.tests

import ignite.*
import ignite.client.*
import ignite.api2
import std.collection.{ArrayList, HashMap}
import std.time.DateTime

@Test
public class ClientTransportSelectionTestSuite {
    func buildCryptoConfig(kind: api2.ClientCryptoProviderKind): api2.ClientCryptoConfig {
        let ring = HashMap<String, Array<UInt8>>()
        ring.add("k1", "0123456789abcdef0123456789abcdef".toArray())
        api2.ClientCryptoConfig(
            providerKind: kind,
            activeKid: "k1",
            keyRing: ring,
            aeadAlgorithm: "AES-256-GCM"
        )
    }

    @TestCase
    public func testSuccessfulResponseIncludesTransportSelectionObserveHeaders(): Unit {
        let app = App(config: Config())
        app.get("/transport-selection", { ctx =>
            ctx.sendString("selection-ok")
        })

        let port = choosePort(913)
        let url = "http://127.0.0.1:${port}/transport-selection"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let backendIds = ArrayList<String>()
        let providerIds = ArrayList<String>()
        let cryptoProviderIds = ArrayList<String>()
        let publicPaths = ArrayList<String>()
        let riskLevels = ArrayList<String>()
        let touchpointMarks = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .onTransportTouchpoint({ touchpoint =>
                touchpointMarks.add("global:" + touchpoint.selectedBackend + ":" + touchpoint.publicPath)
            })
            .onResponse({ resp =>
                backendIds.add(readHeader(resp, "x-ignite-observe-backend-id"))
                providerIds.add(readHeader(resp, "x-ignite-observe-provider-id"))
                cryptoProviderIds.add(readHeader(resp, "x-ignite-observe-crypto-provider-id"))
                publicPaths.add(readHeader(resp, "x-ignite-observe-public-path"))
                riskLevels.add(readHeader(resp, "x-ignite-observe-risk-level"))
            })

        try {
            waitForReady(probeClient, url)
            let resp = client.request()
                .method("GET")
                .url(url)
                .onTransportTouchpoint({ touchpoint =>
                    touchpointMarks.add("local:" + touchpoint.selectedBackend + ":" + touchpoint.riskLevel)
                })
                .send()
            @Assert(resp.status, 200)
            @Assert(resp.body(), "selection-ok")
            @Assert(backendIds.size, 1)
            @Assert(backendIds[0], "stdx-http-client")
            @Assert(providerIds.size, 1)
            @Assert(providerIds[0], "-")
            @Assert(cryptoProviderIds.size, 1)
            @Assert(cryptoProviderIds[0], "-")
            @Assert(publicPaths.size, 1)
            @Assert(publicPaths[0], "stable-default")
            @Assert(riskLevels.size, 1)
            @Assert(riskLevels[0], "low")
            @Assert(readHeader(resp, "x-ignite-observe-selected-reason"), "stable_default_path")
            @Assert(readHeader(resp, "x-ignite-observe-fallback-chain"), "-")
            @Assert(readHeader(resp, "x-ignite-observe-candidate-order"), "stdx-default,jinguissl-provider-candidate")
            @Assert(readHeader(resp, "x-ignite-observe-transport-tags"), "scene=client,scheme=http")
            @Assert(touchpointMarks.size, 2)
            @Assert(touchpointMarks[0], "global:stdx-http-client:stable-default")
            @Assert(touchpointMarks[1], "local:stdx-http-client:low")
            match (resp.transportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "stdx-http-client")
                    @Assert(touchpoint.selectedReason, "stable_default_path")
                    @Assert(touchpoint.candidateOrder, "stdx-default,jinguissl-provider-candidate")
                    @Assert(touchpoint.transportTags, "scene=client,scheme=http")
                case None => @Fail("expected response transport touchpoint")
            }
            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "stdx-http-client")
                    @Assert(touchpoint.providerId, "-")
                    @Assert(touchpoint.publicPath, "stable-default")
                    @Assert(touchpoint.riskLevel, "low")
                    @Assert(containsSelectionText(touchpoint.toJson(), "\"selectedBackend\":\"stdx-http-client\""), true)
                    @Assert(containsSelectionText(touchpoint.toLogLine(), "selectedBackend=stdx-http-client"), true)
                case None => @Fail("expected client transport touchpoint")
            }
        } finally {
            probeClient.close()
            client.close()
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    @TestCase
    public func testEncryptedRequestIncludesCryptoProviderSelectionHeader(): Unit {
        let app = App(config: Config())
        app.post("/transport-selection-crypto", { ctx =>
            _ = ctx.status(201).sendString("crypto-ok")
        })

        let port = choosePort(1231)
        let url = "http://127.0.0.1:${port}/transport-selection-crypto"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let cryptoProviderIds = ArrayList<String>()
        let riskLevels = ArrayList<String>()
        let touchpointMarks = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .useCrypto(buildCryptoConfig(api2.ClientCryptoProviderKind.StdxFallback))
            .onTransportTouchpoint({ touchpoint =>
                touchpointMarks.add("global:" + touchpoint.cryptoProviderId)
            })
            .onResponse({ resp =>
                cryptoProviderIds.add(readHeader(resp, "x-ignite-observe-crypto-provider-id"))
                riskLevels.add(readHeader(resp, "x-ignite-observe-risk-level"))
            })

        try {
            waitForReady(probeClient, url, method: "POST")
            let resp = client.request()
                .method("POST")
                .url(url)
                .encryptedBodyJson("{\"scope\":\"selection\"}", aad: "route:/transport-selection-crypto")
                .send()
            @Assert(resp.status, 201)
            @Assert(resp.body(), "crypto-ok")
            @Assert(cryptoProviderIds.size, 1)
            @Assert(cryptoProviderIds[0], "crypto:stdx-fallback")
            @Assert(riskLevels.size, 1)
            @Assert(riskLevels[0], "medium")
            @Assert(touchpointMarks.size, 1)
            @Assert(touchpointMarks[0], "global:crypto:stdx-fallback")
            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.cryptoProviderId, "crypto:stdx-fallback")
                    @Assert(touchpoint.riskLevel, "medium")
                case None => @Fail("expected encrypted transport touchpoint")
            }
        } finally {
            probeClient.close()
            client.close()
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    @TestCase
    public func testExperimentalBackendHintCanDriveHttpSelection(): Unit {
        let app = App(config: Config())
        app.get("/transport-selection-experimental", { ctx =>
            ctx.sendString("experimental-selection-ok")
        })

        let port = choosePort(1547)
        let url = "http://127.0.0.1:${port}/transport-selection-experimental"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let backendIds = ArrayList<String>()
        let providerIds = ArrayList<String>()
        let publicPaths = ArrayList<String>()
        let riskLevels = ArrayList<String>()
        let touchpointLines = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .allowExperimentalTransport()
            .preferTransportBackend("jinguissl-provider-candidate")
            .onTransportTouchpoint({ touchpoint =>
                touchpointLines.add(touchpoint.toLogLine())
            })
            .onResponse({ resp =>
                backendIds.add(readHeader(resp, "x-ignite-observe-backend-id"))
                providerIds.add(readHeader(resp, "x-ignite-observe-provider-id"))
                publicPaths.add(readHeader(resp, "x-ignite-observe-public-path"))
                riskLevels.add(readHeader(resp, "x-ignite-observe-risk-level"))
            })

        try {
            waitForReady(probeClient, url)
            let resp = client.request()
                .method("GET")
                .url(url)
                .send()
            @Assert(resp.status, 200)
            @Assert(resp.body(), "experimental-selection-ok")
            @Assert(backendIds.size, 1)
            @Assert(backendIds[0], "jinguissl-provider-candidate")
            @Assert(providerIds.size, 1)
            @Assert(providerIds[0], "-")
            @Assert(publicPaths.size, 1)
            @Assert(publicPaths[0], "experimental-only")
            @Assert(riskLevels.size, 1)
            @Assert(riskLevels[0], "medium")
            @Assert(touchpointLines.size, 1)
            @Assert(containsSelectionText(touchpointLines[0], "selectedBackend=jinguissl-provider-candidate"), true)
            @Assert(containsSelectionText(touchpointLines[0], "publicPath=experimental-only"), true)
            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "jinguissl-provider-candidate")
                    @Assert(touchpoint.publicPath, "experimental-only")
                    @Assert(touchpoint.riskLevel, "medium")
                case None => @Fail("expected experimental transport touchpoint")
            }
        } finally {
            probeClient.close()
            client.close()
            app.shutdown()
            try {
                let _ = serverFuture.get(Duration.second * 1)
            } catch (_: Exception) {
                serverFuture.cancel()
            }
        }
    }

    func readHeader(resp: ClientResponse, name: String): String {
        if (let Some(value) <- resp.header(name)) {
            return value
        }
        "missing"
    }

    func waitForReady(client: RestClient, url: String, method!: String = "GET"): Unit {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                let builder = client.request()
                    .method(method)
                    .url(url)
                if (method == "POST") {
                    builder.bodyJson("{\"probe\":true}")
                }
                let resp = builder.send()
                if (resp.status == 200) {
                    let _ = resp.body()
                    return
                }
                if (method == "POST" && resp.status == 201) {
                    let _ = resp.body()
                    return
                }
            } catch (_: Exception) {}
            if (attempt == 19) {
                throw Exception("failed to connect test server: ${url}")
            }
            sleep(Duration.millisecond * 50)
            attempt += 1
        }
        throw Exception("failed to connect test server: ${url}")
    }

    func choosePort(offset: Int64): UInt16 {
        let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let raw = 52000 + ((nowMs + offset) % 4000)
        UInt16(raw)
    }

    func containsSelectionText(text: String, target: String): Bool {
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
}
