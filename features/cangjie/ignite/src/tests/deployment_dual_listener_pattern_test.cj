package ignite.tests

import ignite.*

let DUAL_TLS_CERT_A = "_helper/testdata/tls/server-cert-a.pem"
let DUAL_TLS_KEY_A = "_helper/testdata/tls/server-key-a.pem"

@Test
public class DeploymentDualListenerPatternTestSuite {
    @TestCase
    public func testHttpRedirectAppKeepsRedirectRoutingContract(): Unit {
        let httpApp = buildHttpRedirectApp("127.0.0.1", UInt16(18443))

        let rootResult = httpApp.router.matchRoute("GET", "/")
        let healthResult = httpApp.router.matchRoute("GET", "/health")
        let nestedResult = httpApp.router.matchRoute("GET", "/api/v1/users")

        @Assert(rootResult.matched, true)
        @Assert(healthResult.matched, true)
        @Assert(nestedResult.matched, true)
        @Assert(httpApp.config.tlsCertFile, "")
        @Assert(httpApp.config.tlsKeyFile, "")

        match (rootResult.route) {
            case Some(route) => @Assert(route.path, "/")
            case None => throw Exception("expected root redirect route")
        }
        match (healthResult.route) {
            case Some(route) => @Assert(route.path, "/*")
            case None => throw Exception("expected catch-all redirect route")
        }
        match (nestedResult.route) {
            case Some(route) => @Assert(route.path, "/*")
            case None => throw Exception("expected nested catch-all redirect route")
        }
    }

    @TestCase
    public func testSeparateHttpAndHttpsAppsCarryIndependentListenOptions(): Unit {
        let httpEngine = DeploymentSpyServerEngine()
        let httpsEngine = DeploymentSpyServerEngine()

        let httpApp = buildHttpRedirectApp("127.0.0.1", UInt16(18443))
        let httpsApp = buildHttpsServiceApp(DUAL_TLS_CERT_A, DUAL_TLS_KEY_A)

        httpApp.serverEngine(httpEngine)
        httpsApp.serverEngine(httpsEngine)

        httpApp.listen("127.0.0.1", UInt16(18080))
        httpsApp.listen("127.0.0.1", UInt16(18443))

        @Assert(httpEngine.listenCalled, true)
        @Assert(httpsEngine.listenCalled, true)
        @Assert(httpEngine.lastPort, UInt16(18080))
        @Assert(httpsEngine.lastPort, UInt16(18443))
        @Assert(httpEngine.lastTlsCertFile, "")
        @Assert(httpEngine.lastTlsKeyFile, "")
        @Assert(httpsEngine.lastTlsCertFile, DUAL_TLS_CERT_A)
        @Assert(httpsEngine.lastTlsKeyFile, DUAL_TLS_KEY_A)
        @Assert(httpEngine.loadedTlsIngressContext, true)
        @Assert(httpsEngine.loadedTlsIngressContext, true)
        @Assert(httpEngine.loadedTransportRoutingBundle, true)
        @Assert(httpsEngine.loadedTransportRoutingBundle, true)
        @Assert(httpEngine.loadedPreparedTlsMaterial, false)
        @Assert(httpsEngine.loadedPreparedTlsMaterial, true)
        @Assert(httpsEngine.lastPreparedTlsAlpnCount >= 2, true)
        @Assert(httpsEngine.lastPreparedTlsCertPemSize > 0, true)
        @Assert(httpEngine.lastRoutingSelectedBackend, "stdx-default")
        @Assert(httpEngine.lastRoutingTlsProviderId, "stdx")
        @Assert(httpsEngine.lastRoutingSelectedBackend, "stdx-default")
        @Assert(httpsEngine.lastRoutingTlsProviderId, "stdx")
        @Assert(httpEngine.lastIngressSelectedBackend, "stdx-default")
        @Assert(httpEngine.lastIngressTouchpointBackend, "stdx-http-server")
        @Assert(httpEngine.lastIngressTouchpointProviderId, "-")
        @Assert(httpsEngine.lastIngressSelectedBackend, "stdx-default")
        @Assert(httpsEngine.lastIngressTouchpointBackend, "stdx-http-server")
        @Assert(httpsEngine.lastIngressTouchpointProviderId, "tls:stdx-default")
        @Assert(httpEngine.readyCalled, true)
        @Assert(httpsEngine.readyCalled, true)
        match (httpEngine.lastTransportTouchpoint) {
            case Some(touchpoint) =>
                @Assert(touchpoint.selectedBackend, "stdx-http-server")
                @Assert(touchpoint.providerId, "-")
                @Assert(touchpoint.tlsEnabled, false)
            case None => @Fail("expected http transport touchpoint")
        }
        match (httpsEngine.lastTransportTouchpoint) {
            case Some(touchpoint) =>
                @Assert(touchpoint.selectedBackend, "stdx-http-server")
                @Assert(touchpoint.providerId, "tls:stdx-default")
                @Assert(touchpoint.selectedReason, "stable_default_path")
                @Assert(containsText(touchpoint.candidateOrder, "jinguissl-provider-candidate"), true)
            case None => @Fail("expected https transport touchpoint")
        }
        match (httpApp.lastServerTransportTouchpoint()) {
            case Some(touchpoint) =>
                @Assert(touchpoint.selectedBackend, "stdx-http-server")
                @Assert(touchpoint.providerId, "-")
                @Assert(touchpoint.tlsEnabled, false)
            case None => @Fail("expected http app transport touchpoint snapshot")
        }
        match (httpsApp.lastServerTransportTouchpoint()) {
            case Some(touchpoint) =>
                @Assert(touchpoint.selectedBackend, "stdx-http-server")
                @Assert(touchpoint.providerId, "tls:stdx-default")
                @Assert(touchpoint.tlsEnabled, true)
            case None => @Fail("expected https app transport touchpoint snapshot")
        }
    }

    @TestCase
    public func testPreferredServerBackendHintStillFallsBackToStdxWhileAttachIsPrecheckOnly(): Unit {
        let httpsEngine = DeploymentSpyServerEngine()
        let httpsApp = buildHttpsServiceAppWithServerTransportPreference(
            DUAL_TLS_CERT_A,
            DUAL_TLS_KEY_A,
            "jinguissl-provider-candidate",
            true
        )

        httpsApp.serverEngine(httpsEngine)
        httpsApp.listen("127.0.0.1", UInt16(18444))

        @Assert(httpsEngine.listenCalled, true)
        @Assert(httpsEngine.loadedTlsIngressContext, true)
        @Assert(httpsEngine.loadedTransportRoutingBundle, true)
        @Assert(
            httpsEngine.lastServerPreferredBackendHint,
            "jinguissl-provider-candidate"
        )
        @Assert(httpsEngine.lastAllowExperimentalServerBackend, true)
        @Assert(httpsEngine.lastRoutingSelectedBackend, "stdx-default")
        @Assert(httpsEngine.lastRoutingSelectedReason, "fallback_to_stable_default")
        @Assert(httpsEngine.lastRoutingTlsProviderId, "stdx")
        @Assert(httpsEngine.loadedJinguiAttachPlanSnapshot, true)
        @Assert(httpsEngine.lastJinguiAttachProviderId, "jinguissl")
        @Assert(httpsEngine.lastJinguiAttachSurface, "accepted-socket")
        @Assert(httpsEngine.lastJinguiAttachPlanningStatus, "PLANNING_ONLY")
        @Assert(httpsEngine.lastJinguiAttachPlanningReady, true)
        @Assert(httpsEngine.lastJinguiAttachStableStatus, "BLOCKED")
        @Assert(httpsEngine.lastJinguiAttachStableReady, false)
        @Assert(httpsEngine.lastJinguiAttachExpectedTlsVersion, "TLS1.3")
        @Assert(
            containsText(httpsEngine.lastJinguiAttachExpectedAlpn, "h2"),
            true
        )
        @Assert(
            containsText(httpsEngine.lastJinguiAttachExpectedAlpn, "http/1.1"),
            true
        )
        @Assert(httpsEngine.lastJinguiAttachMaterialKeyAlgorithm.size > 0, true)
        @Assert(httpsEngine.lastIngressSelectedBackend, "stdx-default")
        @Assert(httpsEngine.lastIngressSelectedReason, "fallback_to_stable_default")
        @Assert(httpsEngine.lastIngressTouchpointBackend, "stdx-http-server")
        @Assert(httpsEngine.lastIngressTouchpointProviderId, "tls:stdx-default")
        @Assert(
            containsText(
                httpsEngine.lastRoutingBlockedCandidates,
                "jinguissl-provider-candidate:SERVER_ATTACH_PRECHECK_ONLY"
            ),
            true
        )
        match (httpsEngine.lastTransportTouchpoint) {
            case Some(touchpoint) =>
                @Assert(
                    touchpoint.candidateOrder,
                    "jinguissl-provider-candidate,stdx-default"
                )
                @Assert(touchpoint.selectedBackend, "stdx-http-server")
                @Assert(touchpoint.providerId, "tls:stdx-default")
                @Assert(touchpoint.selectedReason, "fallback_to_stable_default")
                @Assert(
                    containsText(
                        touchpoint.blockedCandidates,
                        "jinguissl-provider-candidate:SERVER_ATTACH_PRECHECK_ONLY"
                    ),
                    true
                )
            case None => @Fail("expected https preferred transport touchpoint")
        }
        match (httpsApp.lastServerTransportTouchpoint()) {
            case Some(touchpoint) =>
                @Assert(touchpoint.selectedBackend, "stdx-http-server")
                @Assert(touchpoint.providerId, "tls:stdx-default")
                @Assert(touchpoint.selectedReason, "fallback_to_stable_default")
            case None => @Fail("expected https app preferred transport touchpoint snapshot")
        }
    }
}

func buildHttpRedirectApp(httpsHost: String, httpsPort: UInt16): App {
    let app = App(config: Config(appName: "ignite-http-redirect"))
    app.get("/*", { ctx =>
        let target = "https://${httpsHost}:${httpsPort}${ctx.path}"
        ctx.redirect(target, code: 307)
    })
    app.get("/", { ctx =>
        let target = "https://${httpsHost}:${httpsPort}/"
        ctx.redirect(target, code: 307)
    })
    app
}

func buildHttpsServiceApp(certFile: String, keyFile: String): App {
    let app = App(config: Config(
        appName: "ignite-https-service",
        tlsCertFile: certFile,
        tlsKeyFile: keyFile,
        enableTlsPrecheck: false
    ))
    app.get("/", { ctx =>
        _ = ctx.sendString("dual-listener-ok")
    })
    app.get("/health", { ctx =>
        _ = ctx.json(#"{"ok":true,"scheme":"https"}"#)
    })
    app
}

func buildHttpsServiceAppWithServerTransportPreference(
    certFile: String,
    keyFile: String,
    preferredBackendHint: String,
    allowExperimental: Bool
): App {
    let app = App(config: Config(
        appName: "ignite-https-service-preferred",
        tlsCertFile: certFile,
        tlsKeyFile: keyFile,
        enableTlsPrecheck: false,
        serverPreferredBackendHint: preferredBackendHint,
        allowExperimentalServerBackend: allowExperimental
    ))
    app.get("/", { ctx =>
        _ = ctx.sendString("preferred-backend-ok")
    })
    app
}

class DeploymentSpyServerEngine <: ServerEngine {
    var listenCalled: Bool = false
    var readyCalled: Bool = false
    var lastPort: UInt16 = 0
    var lastTlsCertFile: String = ""
    var lastTlsKeyFile: String = ""
    var loadedPreparedTlsMaterial: Bool = false
    var lastPreparedTlsAlpnCount: Int64 = 0
    var lastPreparedTlsCertPemSize: Int64 = 0
    var loadedTlsIngressContext: Bool = false
    var lastIngressSelectedBackend: String = ""
    var lastIngressSelectedReason: String = ""
    var lastIngressTouchpointBackend: String = ""
    var lastIngressTouchpointProviderId: String = ""
    var loadedJinguiAttachPlanSnapshot: Bool = false
    var lastJinguiAttachProviderId: String = ""
    var lastJinguiAttachSurface: String = ""
    var lastJinguiAttachPlanningStatus: String = ""
    var lastJinguiAttachPlanningReady: Bool = false
    var lastJinguiAttachStableStatus: String = ""
    var lastJinguiAttachStableReady: Bool = false
    var lastJinguiAttachExpectedTlsVersion: String = ""
    var lastJinguiAttachExpectedAlpn: String = ""
    var lastJinguiAttachMaterialKeyAlgorithm: String = ""
    var loadedTransportRoutingBundle: Bool = false
    var lastServerPreferredBackendHint: String = ""
    var lastAllowExperimentalServerBackend: Bool = false
    var lastRoutingSelectedBackend: String = ""
    var lastRoutingSelectedReason: String = ""
    var lastRoutingBlockedCandidates: String = ""
    var lastRoutingTlsProviderId: String = ""
    var lastTransportTouchpoint: ?ServerTransportTouchpoint = None

    public override func listen(
        option: ServerEngineListenOption,
        app: App,
        onReady: ?((ServerEngineReadySignal) -> Unit)
    ): Unit {
        let _ = app
        listenCalled = true
        lastPort = option.port
        lastTlsCertFile = option.tlsCertFile
        lastTlsKeyFile = option.tlsKeyFile
        lastServerPreferredBackendHint = option.serverPreferredBackendHint
        lastAllowExperimentalServerBackend = option.allowExperimentalServerBackend
        let tlsIngressContext = option.loadTlsIngressContext()
        loadedTlsIngressContext = true
        lastIngressSelectedBackend =
            tlsIngressContext.transportRoutingBundle.selectionDecision.selectedBackend
        lastIngressSelectedReason =
            tlsIngressContext.transportRoutingBundle.selectionDecision.selectedReason
        lastIngressTouchpointBackend =
            tlsIngressContext.transportTouchpoint.selectedBackend
        lastIngressTouchpointProviderId =
            tlsIngressContext.transportTouchpoint.providerId
        if (
            lastServerPreferredBackendHint == "jinguissl-provider-candidate" &&
            lastAllowExperimentalServerBackend
        ) {
            let attachPlan = option.loadJinguiHttpServerAttachPlanSnapshot()
            loadedJinguiAttachPlanSnapshot = true
            lastJinguiAttachProviderId = attachPlan.providerId
            lastJinguiAttachSurface = attachPlan.attachSurface
            lastJinguiAttachPlanningStatus = attachPlan.planningStatus
            lastJinguiAttachPlanningReady = attachPlan.planningReady
            lastJinguiAttachStableStatus = attachPlan.stableAttachStatus
            lastJinguiAttachStableReady = attachPlan.stableAttachReady
            lastJinguiAttachExpectedTlsVersion = attachPlan.expectedTlsVersion
            lastJinguiAttachExpectedAlpn =
                joinText(attachPlan.expectedAlpnProtocols)
            lastJinguiAttachMaterialKeyAlgorithm =
                attachPlan.materialKeyAlgorithm
        }
        let routingBundle = option.loadTransportRoutingBundle()
        loadedTransportRoutingBundle = true
        lastRoutingSelectedBackend = routingBundle.selectionDecision.selectedBackend
        lastRoutingSelectedReason = routingBundle.selectionDecision.selectedReason
        lastRoutingBlockedCandidates = joinText(
            routingBundle.selectionDecision.blockedCandidates
        )
        lastRoutingTlsProviderId = routingBundle.tlsAttachPlan.providerId
        if (tlsIngressContext.hasPreparedTlsMaterial()) {
            let material = tlsIngressContext.loadPreparedTlsMaterial()
            loadedPreparedTlsMaterial = true
            lastPreparedTlsAlpnCount = material.normalizedAlpnProtocols.size
            lastPreparedTlsCertPemSize = material.certPem.size
        }
        lastTransportTouchpoint = option.transportTouchpoint
        if (let Some(cb) <- onReady) {
            cb(ServerEngineReadySignal())
            readyCalled = true
        }
    }

    public override func shutdown(): Unit {}
}

func joinText(values: Array<String>): String {
    if (values.size == 0) {
        return ""
    }
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += ","
        }
        first = false
        out += value
    }
    out
}

func containsText(text: String, target: String): Bool {
    let t = text.toRuneArray()
    let p = target.toRuneArray()
    if (p.size == 0) {
        return true
    }
    if (t.size < p.size) {
        return false
    }
    for (i in 0..=(t.size - p.size)) {
        var matched = true
        for (j in 0..p.size) {
            if (t[i + j] != p[j]) {
                matched = false
                break
            }
        }
        if (matched) {
            return true
        }
    }
    false
}
