package ignite.tests

import ignite.*
import ignite.client.*
import std.time.DateTime

@Test
public class ClientResponseRecoveryAcceptanceTestSuite {
    @TestCase
    public func testSuccessfulResponseRecoversObserveAndTouchpointSnapshots(): Unit {
        let app = App(config: Config())
        app.get("/client-acceptance-recovery", { ctx =>
            ctx.sendString("acceptance-ok")
        })

        let port = chooseClientRecoveryAcceptancePort(171)
        let url = "http://127.0.0.1:${port}/client-acceptance-recovery"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )

        try {
            waitForClientRecoveryAcceptanceReady(probeClient, url)

            let resp = client.request()
                .method("GET")
                .url(url)
                .send()

            @Assert(resp.status, 200)
            @Assert(resp.body(), "acceptance-ok")

            match (resp.observeSnapshot()) {
                case Some(snapshot) =>
                    @Assert(snapshot.outcome, "success")
                    @Assert(snapshot.responseStatus, 200)
                    @Assert(snapshot.backendId, "stdx-http-client")
                    @Assert(snapshot.transportTags, "scene=client,scheme=http")
                case None => @Fail("expected response observe snapshot")
            }

            match (resp.transportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "stdx-http-client")
                    @Assert(touchpoint.selectedReason, "stable_default_path")
                    @Assert(touchpoint.fallbackChain, "-")
                    @Assert(touchpoint.publicPath, "stable-default")
                    @Assert(touchpoint.riskLevel, "low")
                    @Assert(touchpoint.transportTags, "scene=client,scheme=http")
                case None => @Fail("expected response transport touchpoint")
            }

            match (client.lastClientObserveSnapshot()) {
                case Some(snapshot) =>
                    @Assert(snapshot.outcome, "success")
                    @Assert(snapshot.responseStatus, 200)
                    @Assert(snapshot.phase, "response")
                case None => @Fail("expected client observe snapshot")
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
    public func testExperimentalSelectionStillRecoversPublicTouchpoint(): Unit {
        let app = App(config: Config())
        app.get("/client-acceptance-experimental", { ctx =>
            ctx.sendString("experimental-ok")
        })

        let port = chooseClientRecoveryAcceptancePort(287)
        let url = "http://127.0.0.1:${port}/client-acceptance-experimental"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .allowExperimentalTransport()
            .preferTransportBackend("jinguissl-provider-candidate")

        try {
            waitForClientRecoveryAcceptanceReady(probeClient, url)

            let resp = client.request()
                .method("GET")
                .url(url)
                .send()

            @Assert(resp.status, 200)
            @Assert(resp.body(), "experimental-ok")

            match (resp.transportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "jinguissl-provider-candidate")
                    @Assert(touchpoint.selectedReason, "preferred_backend_hint")
                    @Assert(touchpoint.publicPath, "experimental-only")
                    @Assert(touchpoint.riskLevel, "medium")
                case None => @Fail("expected experimental response transport touchpoint")
            }

            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "jinguissl-provider-candidate")
                    @Assert(touchpoint.publicPath, "experimental-only")
                    @Assert(touchpoint.riskLevel, "medium")
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
    public func testClearRecoverySnapshotsResetsRetainedStateBeforeFreshFailureRecovery(): Unit {
        let app = App(config: Config())
        app.get("/client-acceptance-reset", { ctx =>
            ctx.sendString("reset-ok")
        })

        let port = chooseClientRecoveryAcceptancePort(431)
        let url = "http://127.0.0.1:${port}/client-acceptance-reset"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )

        try {
            waitForClientRecoveryAcceptanceReady(probeClient, url)

            let resp = client.request()
                .method("GET")
                .url(url)
                .send()

            @Assert(resp.status, 200)
            @Assert(resp.body(), "reset-ok")

            match (client.lastClientObserveSnapshot()) {
                case Some(snapshot) =>
                    @Assert(snapshot.outcome, "success")
                    @Assert(snapshot.backendId, "stdx-http-client")
                    @Assert(snapshot.publicPath, "stable-default")
                case None => @Fail("expected seeded client observe snapshot")
            }

            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "stdx-http-client")
                    @Assert(touchpoint.publicPath, "stable-default")
                    @Assert(touchpoint.riskLevel, "low")
                case None => @Fail("expected seeded client transport touchpoint")
            }

            client.clearRecoverySnapshots()

            match (client.lastClientObserveSnapshot()) {
                case Some(_) => @Fail("expected cleared client observe snapshot")
                case None => ()
            }

            match (client.lastClientTransportTouchpoint()) {
                case Some(_) => @Fail("expected cleared client transport touchpoint")
                case None => ()
            }

            try {
                let _ = client.request()
                    .method("GET")
                    .url(url)
                    .allowExperimentalTransport()
                    .preferTransportBackend("jinguissl-provider-candidate")
                    .header("x-ignite-log-case", "clear-recovery-reset")
                    .onRequest({ _ =>
                        throw Exception("forced failure after clearRecoverySnapshots")
                    })
                    .send()
                @Fail("expected forced request_prepare failure")
            } catch (e: Exception) {
                @Assert(e.message.size > 0, true)
            }

            match (client.lastClientObserveSnapshot()) {
                case Some(snapshot) =>
                    @Assert(snapshot.outcome, "error")
                    @Assert(snapshot.phase, "request_prepare")
                    @Assert(snapshot.backendId, "jinguissl-provider-candidate")
                    @Assert(snapshot.publicPath, "experimental-only")
                    @Assert(snapshot.riskLevel, "medium")
                    @Assert(snapshot.fields, "case=clear-recovery-reset")
                case None => @Fail("expected fresh failure observe snapshot")
            }

            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "jinguissl-provider-candidate")
                    @Assert(touchpoint.selectedReason, "preferred_backend_hint")
                    @Assert(touchpoint.publicPath, "experimental-only")
                    @Assert(touchpoint.riskLevel, "medium")
                case None => @Fail("expected fresh failure transport touchpoint")
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
    public func testSequentialRequestsOverwriteRetainedSnapshotsWithoutStaleCarry(): Unit {
        let app = App(config: Config())
        app.get("/client-acceptance-sequential-overwrite", { ctx =>
            ctx.sendString("overwrite-ok")
        })

        let port = chooseClientRecoveryAcceptancePort(593)
        let url = "http://127.0.0.1:${port}/client-acceptance-sequential-overwrite"
        let serverFuture = spawn {
            app.listen("127.0.0.1", port)
        }

        let probeClient = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )

        try {
            waitForClientRecoveryAcceptanceReady(probeClient, url)

            let first = client.request()
                .method("GET")
                .url(url)
                .send()

            @Assert(first.status, 200)
            @Assert(first.body(), "overwrite-ok")
            assertRetainedSuccessSnapshot(client, "stdx-http-client", "stable-default", "low")

            try {
                let _ = client.request()
                    .method("GET")
                    .url(url)
                    .allowExperimentalTransport()
                    .preferTransportBackend("jinguissl-provider-candidate")
                    .header("x-ignite-log-case", "sequential-overwrite-failure")
                    .onRequest({ _ =>
                        throw Exception("forced sequential overwrite failure")
                    })
                    .send()
                @Fail("expected forced sequential overwrite failure")
            } catch (e: Exception) {
                @Assert(e.message.size > 0, true)
            }

            match (client.lastClientObserveSnapshot()) {
                case Some(snapshot) =>
                    @Assert(snapshot.outcome, "error")
                    @Assert(snapshot.phase, "request_prepare")
                    @Assert(snapshot.responseStatus, 0)
                    @Assert(snapshot.backendId, "jinguissl-provider-candidate")
                    @Assert(snapshot.publicPath, "experimental-only")
                    @Assert(snapshot.riskLevel, "medium")
                    @Assert(snapshot.fields, "case=sequential-overwrite-failure")
                case None => @Fail("expected retained failure snapshot")
            }

            match (client.lastClientTransportTouchpoint()) {
                case Some(touchpoint) =>
                    @Assert(touchpoint.selectedBackend, "jinguissl-provider-candidate")
                    @Assert(touchpoint.selectedReason, "preferred_backend_hint")
                    @Assert(touchpoint.publicPath, "experimental-only")
                    @Assert(touchpoint.riskLevel, "medium")
                case None => @Fail("expected retained failure touchpoint")
            }

            let second = client.request()
                .method("GET")
                .url(url)
                .send()

            @Assert(second.status, 200)
            @Assert(second.body(), "overwrite-ok")
            assertRetainedSuccessSnapshot(client, "stdx-http-client", "stable-default", "low")
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
}

func waitForClientRecoveryAcceptanceReady(client: RestClient, url: String): Unit {
    var attempt: Int64 = 0
    while (attempt < 20) {
        try {
            let resp = client.request()
                .method("GET")
                .url(url)
                .send()
            if (resp.status == 200) {
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

func chooseClientRecoveryAcceptancePort(offset: Int64): UInt16 {
    let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
    let raw = 56000 + ((nowMs + offset) % 3000)
    UInt16(raw)
}

func assertRetainedSuccessSnapshot(
    client: RestClient,
    expectedBackend: String,
    expectedPublicPath: String,
    expectedRiskLevel: String
): Unit {
    match (client.lastClientObserveSnapshot()) {
        case Some(snapshot) =>
            @Assert(snapshot.outcome, "success")
            @Assert(snapshot.errorClass, "NONE")
            @Assert(snapshot.phase, "response")
            @Assert(snapshot.responseStatus, 200)
            @Assert(snapshot.backendId, expectedBackend)
            @Assert(snapshot.publicPath, expectedPublicPath)
            @Assert(snapshot.riskLevel, expectedRiskLevel)
        case None => @Fail("expected retained success snapshot")
    }

    match (client.lastClientTransportTouchpoint()) {
        case Some(touchpoint) =>
            @Assert(touchpoint.selectedBackend, expectedBackend)
            @Assert(touchpoint.publicPath, expectedPublicPath)
            @Assert(touchpoint.riskLevel, expectedRiskLevel)
        case None => @Fail("expected retained success touchpoint")
    }
}
