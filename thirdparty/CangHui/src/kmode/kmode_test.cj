package chui.kmode

@When[debug]
class FakeKModeChannelModule <: KModeChannelModule {
    public var connected = false
    public var sentPayload = ""
    public var sentIdempotencyKey = ""
    public var ackedMessageId = ""
    public var cursor: Int64 = 7

    public func name(): String { "fake" }

    public func connect(config: KModeChannelConfig): Unit {
        connected = config.protocol == KMODE_CHANNEL_PROTOCOL &&
            config.payloadProtocol == KMODE_PROTOCOL &&
            config.schemaRef == KMODE_SCHEMA_REF &&
            config.resumeCursor == 7
    }

    public func send(
        payload: String,
        idempotencyKey: String,
        _correlationId: String,
        _replyTo: String
    ): String {
        sentPayload = payload
        sentIdempotencyKey = idempotencyKey
        "message-1"
    }

    public func poll(afterCursor: Int64): KModeChannelBatch {
        KModeChannelBatch(
            [KModeChannelMessage("message-1", afterCursor + 1, "opaque")],
            afterCursor + 1
        )
    }

    public func ack(messageId: String, state: String): Unit {
        ackedMessageId = messageId + ":" + state
    }

    public func resumeCursor(): Int64 { cursor }
}

@When[debug]
@Test
func kModeDebugTestBuildCarriesTheEnabledGate(): Unit {
    @Expect(kModeDebugDefault())
    @Expect(kModeEnabled())
    @Expect(KModePolicy(enabled: true).enabled)
}

@When[!debug]
@Test
func kModeReleaseTestBuildFailsClosedEvenForExplicitPolicy(): Unit {
    @Expect(!kModeDebugDefault())
    @Expect(!kModeEnabled())
    @Expect(!KModePolicy(enabled: true).enabled)
    let response = dispatchKModeRequest(
        KModeRequest(0, KModeOperation.Health),
        policy: KModePolicy(enabled: true)
    )
    @Expect(!response.ok)
    @Expect(response.status, "disabled")
}

@Test
func kModeProtocolRoundTripsUtf8Payloads(): Unit {
    let request = KModeRequest(17, KModeOperation.Invoke, endpoint: "tests.echo", payload: "仓颉|GUI\nready")
    let decodedRequest = decodeKModeRequest(encodeKModeRequest(request))
    @Expect(decodedRequest.id, Int64(17))
    @Expect(decodedRequest.endpoint, "tests.echo")
    @Expect(decodedRequest.payload, "仓颉|GUI\nready")

    let response = KModeResponse(17, true, "ok", payload: "完成", errorCode: 0)
    let decodedResponse = decodeKModeResponse(encodeKModeResponse(response))
    @Expect(decodedResponse.ok)
    @Expect(decodedResponse.payload, "完成")
}

@Test
func kModePolicyFailsClosedAndReportsForbidden(): Unit {
    let disabled = dispatchKModeRequest(
        KModeRequest(1, KModeOperation.Health),
        policy: KModePolicy(enabled: false)
    )
    @Expect(!disabled.ok)
    @Expect(disabled.status, "disabled")

    if (kModeDebugDefault()) {
        let forbidden = dispatchKModeRequest(
            KModeRequest(2, KModeOperation.List),
            policy: KModePolicy(enabled: true, capabilities: [KModeCapability.Invoke])
        )
        @Expect(!forbidden.ok)
        @Expect(forbidden.status, "forbidden")
    }
}

@When[debug]
@Test
func kModeRegistryDescribesInvokesAndRejectsDuplicates(): Unit {
    let name = "tests.runtime.echo"
    let endpoint = registerKModeEndpoint(KModeEndpoint(
        name,
        "test echo endpoint",
        KModeCapability.Invoke,
        { value: String => "echo:" + value }
    ))
    @Expect(endpoint.name, name)

    let policy = KModePolicy(
        enabled: true,
        capabilities: [KModeCapability.Inspect, KModeCapability.Invoke]
    )
    let described = dispatchKModeRequest(
        KModeRequest(3, KModeOperation.Describe, endpoint: name),
        policy: policy
    )
    @Expect(described.ok)
    @Expect(described.payload, name + "|invoke|test echo endpoint")

    let invoked = dispatchKModeRequest(
        KModeRequest(4, KModeOperation.Invoke, endpoint: name, payload: "value"),
        policy: policy
    )
    @Expect(invoked.ok)
    @Expect(invoked.payload, "echo:value")

    let missing = dispatchKModeRequest(
        KModeRequest(5, KModeOperation.Invoke, endpoint: "tests.runtime.missing"),
        policy: policy
    )
    @Expect(!missing.ok)
    @Expect(missing.status, "not-found")

    var rejected = false
    try {
        let _ = registerKModeEndpoint(KModeEndpoint(
            name,
            "duplicate endpoint",
            KModeCapability.Invoke,
            { value: String => value }
        ))
    } catch (_: IllegalStateException) {
        rejected = true
    }
    @Expect(rejected)
}

@When[debug]
@Test
func kModeChannelOverrideIsAdminGatedAndKeepsRelayOpaque(): Unit {
    @Expect(KMODE_CHANNEL_PROTOCOL, "canghui.kmode.channel.v0")
    let module = FakeKModeChannelModule()
    var rejected = false
    try {
        overrideKModeChannelModule(module, policy: KModePolicy(enabled: false))
    } catch (_: IllegalStateException) {
        rejected = true
    }
    @Expect(rejected)

    let admin = KModePolicy(enabled: true, capabilities: [KModeCapability.Admin])
    overrideKModeChannelModule(module, policy: admin)
    module.connect(KModeChannelConfig("channel", "client", "one-use-claim", resumeCursor: 7))
    @Expect(module.connected)
    @Expect(module.send("{\"nested\":[1,true,null]}", "idem-1", "corr-1", ""), "message-1")
    @Expect(module.sentPayload, "{\"nested\":[1,true,null]}")
    @Expect(module.sentIdempotencyKey, "idem-1")
    let batch = module.poll(module.resumeCursor())
    @Expect(batch.nextCursor, Int64(8))
    @Expect(batch.messages[0].payload, "opaque")
    module.ack(batch.messages[0].messageId, "consumed")
    @Expect(module.ackedMessageId, "message-1:consumed")
    clearKModeChannelModule(policy: admin)
    @Expect(currentKModeChannelModule().isNone())
}
