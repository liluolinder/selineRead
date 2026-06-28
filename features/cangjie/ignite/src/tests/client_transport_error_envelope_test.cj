package ignite.tests

import ignite.client.*
import ignite.api2
import ignite.security
import std.collection.{ArrayList, HashMap}

@Test
public class ClientTransportErrorEnvelopeTestSuite {
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
    public func testCryptoUnavailableSuggestsFallbackAndDoesNotConsumeConnection(): Unit {
        let observedMessages = ArrayList<String>()
        let cryptoConfig = buildCryptoConfig(api2.ClientCryptoProviderKind.jinguiSSL)
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .useCrypto(cryptoConfig)
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("http://127.0.0.1:1/transport-crypto-fallback")
                .header("x-ignite-log-case", "transport-crypto-unavailable")
                .encryptedBodyJson("{\"ok\":true}", aad: "route:/transport-crypto-fallback")
                .onRequest({ _ =>
                    throw api2.ClientCryptoException(
                        api2.ClientCryptoErrorCode.CryptoUnavailable,
                        "provider path broken"
                    )
                })
                .send()
            @Fail("crypto unavailable should fail before send")
        } catch (e: api2.ClientCryptoException) {
            @Assert(e.code, api2.ClientCryptoErrorCode.CryptoUnavailable)
        } finally {
            client.close()
        }

        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(contains(observedMessages[0], "errorClass=CRYPTO"), true)
        @Assert(contains(observedMessages[0], "phase=request_prepare"), true)
        @Assert(contains(observedMessages[0], "causeCode=crypto_unavailable"), true)
        @Assert(contains(observedMessages[0], "backendId=stdx-http-client"), true)
        @Assert(contains(observedMessages[0], "providerId=-"), true)
        @Assert(contains(observedMessages[0], "cryptoProviderId=crypto:jinguiSSL"), true)
        @Assert(contains(observedMessages[0], "publicPath=stable-default"), true)
        @Assert(contains(observedMessages[0], "transportTags=scene=client,scheme=http,cryptoProvider=crypto:jinguiSSL"), true)
        @Assert(contains(observedMessages[0], "retryable=false"), true)
        @Assert(contains(observedMessages[0], "fallbackSuggested=true"), true)
        @Assert(contains(observedMessages[0], "connectionConsumed=false"), true)
        @Assert(contains(observedMessages[0], "fallbackFrom=stdx-http-client@crypto:jinguiSSL"), true)
        @Assert(contains(observedMessages[0], "fallbackTo=stdx-http-client@crypto:stdx-fallback"), true)
        @Assert(contains(observedMessages[0], "fallbackOutcome=suggested-only"), true)
        @Assert(contains(observedMessages[0], "retryCount=0"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-crypto-unavailable"), true)
    }

    @TestCase
    public func testX509VerifyMismatchIsObservedAsTlsVerifyFailure(): Unit {
        security.resetSecurityMetrics()
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .useX509Verify(
                security.X509VerifyOption(
                    enabled: true,
                    requireHttps: true,
                    expectedServerName: "api.ignite.dev"
                )
            )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("https://127.0.0.1:18443/transport-x509-verify")
                .header("x-ignite-log-case", "transport-x509-verify")
                .send()
            @Fail("x509 verify mismatch should fail before network send")
        } catch (e: security.SecurityException) {
            @Assert(e.code, security.SecurityErrorCode.VerifyFailed)
        } finally {
            client.close()
        }

        let metrics = security.securityMetricsSnapshot()
        @Assert(metrics.certRejects, 1)
        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(contains(observedMessages[0], "errorClass=TLS"), true)
        @Assert(contains(observedMessages[0], "phase=verify"), true)
        @Assert(contains(observedMessages[0], "causeCode=tls_verify_error"), true)
        @Assert(contains(observedMessages[0], "backendId=stdx-http-client"), true)
        @Assert(contains(observedMessages[0], "providerId=tls:stdx-default"), true)
        @Assert(contains(observedMessages[0], "cryptoProviderId=-"), true)
        @Assert(contains(observedMessages[0], "publicPath=stable-default"), true)
        @Assert(contains(observedMessages[0], "riskLevel=medium"), true)
        @Assert(contains(observedMessages[0], "transportTags=scene=client,scheme=https,x509=enabled"), true)
        @Assert(contains(observedMessages[0], "retryable=false"), true)
        @Assert(contains(observedMessages[0], "fallbackSuggested=false"), true)
        @Assert(contains(observedMessages[0], "connectionConsumed=false"), true)
        @Assert(contains(observedMessages[0], "retryCount=0"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-x509-verify"), true)
    }

    @TestCase
    public func testOpaqueSecurityVerifyFailureStillObservesTlsVerifyCause(): Unit {
        security.resetSecurityMetrics()
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .useX509Verify(
                security.X509VerifyOption(
                    enabled: true,
                    requireHttps: false,
                    hook: { _ =>
                        throw security.SecurityException(
                            security.SecurityErrorCode.VerifyFailed,
                            "policy blocked by verifier"
                        )
                    }
                )
            )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("https://127.0.0.1:18443/transport-x509-opaque-verify")
                .header("x-ignite-log-case", "transport-x509-opaque-verify")
                .send()
            @Fail("opaque verify failure should fail before network send")
        } catch (e: security.SecurityException) {
            @Assert(e.code, security.SecurityErrorCode.VerifyFailed)
            @Assert(e.message, "policy blocked by verifier")
        } finally {
            client.close()
        }

        let metrics = security.securityMetricsSnapshot()
        @Assert(metrics.certRejects, 0)
        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "errorClass=TLS"), true)
        @Assert(contains(observedMessages[0], "phase=verify"), true)
        @Assert(contains(observedMessages[0], "causeCode=tls_verify_error"), true)
        @Assert(contains(observedMessages[0], "providerId=tls:stdx-default"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-x509-opaque-verify"), true)
    }

    @TestCase
    public func testProviderUnavailableLeavesNoFallbackRecordWhenNoChainExists(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("https://127.0.0.1:18443/transport-provider-unavailable")
                .header("x-ignite-log-case", "transport-provider-unavailable")
                .onRequest({ _ =>
                    throw Exception("tls provider unavailable during request prepare")
                })
                .send()
            @Fail("provider unavailable should fail before network send")
        } catch (e: Exception) {
            @Assert(e.message.size > 0, true)
        } finally {
            client.close()
        }

        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(contains(observedMessages[0], "errorClass=TLS"), true)
        @Assert(contains(observedMessages[0], "phase=request_prepare"), true)
        @Assert(contains(observedMessages[0], "causeCode=provider_unavailable"), true)
        @Assert(contains(observedMessages[0], "backendId=stdx-http-client"), true)
        @Assert(contains(observedMessages[0], "providerId=tls:stdx-default"), true)
        @Assert(contains(observedMessages[0], "publicPath=stable-default"), true)
        @Assert(contains(observedMessages[0], "transportTags=scene=client,scheme=https"), true)
        @Assert(contains(observedMessages[0], "retryable=false"), true)
        @Assert(contains(observedMessages[0], "fallbackSuggested=true"), true)
        @Assert(contains(observedMessages[0], "connectionConsumed=false"), true)
        @Assert(contains(observedMessages[0], "fallbackFrom=stdx-http-client@tls:stdx-default"), true)
        @Assert(contains(observedMessages[0], "fallbackTo=-"), true)
        @Assert(contains(observedMessages[0], "fallbackOutcome=no-fallback"), true)
        @Assert(contains(observedMessages[0], "retryCount=0"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-provider-unavailable"), true)
    }

    @TestCase
    public func testExperimentalProviderUnavailableSuggestsStableFallback(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .allowExperimentalTransport()
            .preferTransportBackend("jinguissl-provider-candidate")
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("https://127.0.0.1:18443/transport-provider-unavailable-fallback")
                .allowExperimentalTransport()
                .preferTransportBackend("jinguissl-provider-candidate")
                .header("x-ignite-log-case", "transport-provider-unavailable-fallback")
                .onRequest({ _ =>
                    throw Exception("tls provider unavailable during tls attach")
                })
                .send()
            @Fail("experimental provider unavailable should fail before network send")
        } catch (e: Exception) {
            @Assert(e.message.size > 0, true)
        } finally {
            client.close()
        }

        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(contains(observedMessages[0], "errorClass=TLS"), true)
        @Assert(contains(observedMessages[0], "phase=request_prepare"), true)
        @Assert(contains(observedMessages[0], "causeCode=provider_unavailable"), true)
        @Assert(contains(observedMessages[0], "backendId=jinguissl-provider-candidate"), true)
        @Assert(contains(observedMessages[0], "providerId=tls:jinguissl"), true)
        @Assert(contains(observedMessages[0], "publicPath=experimental-only"), true)
        @Assert(contains(observedMessages[0], "riskLevel=medium"), true)
        @Assert(contains(observedMessages[0], "transportTags=scene=client,scheme=https"), true)
        @Assert(contains(observedMessages[0], "retryable=false"), true)
        @Assert(contains(observedMessages[0], "fallbackSuggested=true"), true)
        @Assert(contains(observedMessages[0], "connectionConsumed=false"), true)
        @Assert(contains(observedMessages[0], "fallbackFrom=jinguissl-provider-candidate@tls:jinguissl"), true)
        @Assert(contains(observedMessages[0], "fallbackTo=stdx-http-client"), true)
        @Assert(contains(observedMessages[0], "fallbackOutcome=suggested-only"), true)
        @Assert(contains(observedMessages[0], "retryCount=0"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-provider-unavailable-fallback"), true)
    }

    @TestCase
    public func testRequestLevelExperimentalOverrideUsesLisiExperimentalSelection(): Unit {
        let observedMessages = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 1
        )
            .onError({ e =>
                observedMessages.add(e.message)
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("https://127.0.0.1:18443/transport-experimental-override")
                .allowExperimentalTransport()
                .preferTransportBackend("jinguissl-provider-candidate")
                .header("x-ignite-log-case", "transport-experimental-override")
                .onRequest({ _ =>
                    throw Exception("selection probe stop before experimental send")
                })
                .send()
            @Fail("request-level experimental override should stop before send")
        } catch (e: Exception) {
            @Assert(e.message.size > 0, true)
        } finally {
            client.close()
        }

        @Assert(observedMessages.size, 1)
        @Assert(contains(observedMessages[0], "[ignite.client.observe]"), true)
        @Assert(contains(observedMessages[0], "backendId=jinguissl-provider-candidate"), true)
        @Assert(contains(observedMessages[0], "providerId=tls:jinguissl"), true)
        @Assert(contains(observedMessages[0], "publicPath=experimental-only"), true)
        @Assert(contains(observedMessages[0], "riskLevel=medium"), true)
        @Assert(contains(observedMessages[0], "fields=case=transport-experimental-override"), true)
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
}
