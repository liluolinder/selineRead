package chui.kmode

import std.sync.Mutex

/**
 * Transport-neutral relay SPI. Implementations own delivery, cursor and ACK;
 * kMode owns the opaque payload contract. Credentials must stay out of logs.
 */
public interface KModeChannelModule {
    func name(): String
    func connect(config: KModeChannelConfig): Unit
    func send(
        payload: String,
        idempotencyKey: String,
        correlationId: String,
        replyTo: String
    ): String
    func poll(afterCursor: Int64): KModeChannelBatch
    func ack(messageId: String, state: String): Unit
    func resumeCursor(): Int64
}

public class KModeChannelConfig {
    public let channelId: String
    public let clientId: String
    public let claimToken: String
    public let protocol: String
    public let payloadProtocol: String
    public let schemaRef: String
    public let resumeCursor: Int64

    public init(
        channelId: String,
        clientId: String,
        claimToken: String,
        protocol!: String = KMODE_CHANNEL_PROTOCOL,
        payloadProtocol!: String = KMODE_PROTOCOL,
        schemaRef!: String = KMODE_SCHEMA_REF,
        resumeCursor!: Int64 = 0
    ) {
        if (channelId.isEmpty() || clientId.isEmpty() || claimToken.isEmpty() ||
            protocol.isEmpty() || payloadProtocol.isEmpty() || schemaRef.isEmpty()) {
            throw IllegalArgumentException(
                "kMode channel config requires relay, payload and client identity fields"
            )
        }
        this.channelId = channelId
        this.clientId = clientId
        this.claimToken = claimToken
        this.protocol = protocol
        this.payloadProtocol = payloadProtocol
        this.schemaRef = schemaRef
        this.resumeCursor = resumeCursor
    }
}

public class KModeChannelMessage {
    public let messageId: String
    public let cursor: Int64
    public let payload: String
    public let correlationId: String
    public let replyTo: String

    public init(
        messageId: String,
        cursor: Int64,
        payload: String,
        correlationId!: String = "",
        replyTo!: String = ""
    ) {
        this.messageId = messageId
        this.cursor = cursor
        this.payload = payload
        this.correlationId = correlationId
        this.replyTo = replyTo
    }
}

public class KModeChannelBatch {
    public let messages: Array<KModeChannelMessage>
    public let nextCursor: Int64

    public init(messages: Array<KModeChannelMessage>, nextCursor: Int64) {
        this.messages = messages
        this.nextCursor = nextCursor
    }
}

let kModeChannelMutex = Mutex()
var kModeChannelOverride: ?KModeChannelModule = None

@When[debug]
public func overrideKModeChannelModule(
    module: KModeChannelModule,
    policy!: KModePolicy = KModePolicy()
): Unit {
    if (!policy.enabled || !policy.allows(KModeCapability.Admin)) {
        throw IllegalStateException("kMode channel override requires enabled admin mode")
    }
    synchronized(kModeChannelMutex) {
        kModeChannelOverride = Some(module)
    }
}

@When[!debug]
public func overrideKModeChannelModule(
    _module: KModeChannelModule,
    policy!: KModePolicy = KModePolicy()
): Unit {
    let _ = _module
    if (policy.enabled) { () }
    throw IllegalStateException("kMode channel override is unavailable in release builds")
}

@When[debug]
public func currentKModeChannelModule(): ?KModeChannelModule {
    var current: ?KModeChannelModule = None
    synchronized(kModeChannelMutex) {
        current = kModeChannelOverride
    }
    current
}

@When[!debug]
public func currentKModeChannelModule(): ?KModeChannelModule {
    None
}

@When[debug]
public func clearKModeChannelModule(
    policy!: KModePolicy = KModePolicy()
): Unit {
    if (!policy.enabled || !policy.allows(KModeCapability.Admin)) {
        throw IllegalStateException("kMode channel clear requires enabled admin mode")
    }
    synchronized(kModeChannelMutex) {
        kModeChannelOverride = None
    }
}

@When[!debug]
public func clearKModeChannelModule(
    policy!: KModePolicy = KModePolicy()
): Unit {
    if (policy.enabled) { () }
    throw IllegalStateException("kMode channel clear is unavailable in release builds")
}
