package ignite.client

import ignite.escapeJsonText

public class ClientTransportTouchpoint {
    public let candidateOrder: String
    public let selectedBackend: String
    public let selectedReason: String
    public let fallbackChain: String
    public let providerId: String
    public let cryptoProviderId: String
    public let publicPath: String
    public let riskLevel: String
    public let transportTags: String

    public init(
        candidateOrder: String,
        selectedBackend: String,
        selectedReason: String,
        fallbackChain: String,
        providerId: String,
        cryptoProviderId: String,
        publicPath: String,
        riskLevel: String,
        transportTags: String
    ) {
        this.candidateOrder = candidateOrder
        this.selectedBackend = selectedBackend
        this.selectedReason = selectedReason
        this.fallbackChain = fallbackChain
        this.providerId = providerId
        this.cryptoProviderId = cryptoProviderId
        this.publicPath = publicPath
        this.riskLevel = riskLevel
        this.transportTags = transportTags
    }

    public func toJson(): String {
        #"{"candidateOrder":"# + "\"" + touchpointEscapeJson(candidateOrder) + "\"" +
        #","selectedBackend":"# + "\"" + touchpointEscapeJson(selectedBackend) + "\"" +
        #","selectedReason":"# + "\"" + touchpointEscapeJson(selectedReason) + "\"" +
        #","fallbackChain":"# + "\"" + touchpointEscapeJson(fallbackChain) + "\"" +
        #","providerId":"# + "\"" + touchpointEscapeJson(providerId) + "\"" +
        #","cryptoProviderId":"# + "\"" + touchpointEscapeJson(cryptoProviderId) + "\"" +
        #","publicPath":"# + "\"" + touchpointEscapeJson(publicPath) + "\"" +
        #","riskLevel":"# + "\"" + touchpointEscapeJson(riskLevel) + "\"" +
        #","transportTags":"# + "\"" + touchpointEscapeJson(transportTags) + "\"" +
        #"}"#
    }

    public func toLogLine(): String {
        "[ignite.client.transport] selectedBackend=${selectedBackend} providerId=${providerId} cryptoProviderId=${cryptoProviderId} publicPath=${publicPath} riskLevel=${riskLevel} transportTags=${transportTags} candidateOrder=${candidateOrder} fallbackChain=${fallbackChain}; reason=${selectedReason}"
    }
}

func buildClientTransportTouchpoint(selection: TransportSelectionDecision): ClientTransportTouchpoint {
    ClientTransportTouchpoint(
        selection.candidateOrder,
        selection.selectedBackend,
        selection.selectedReason,
        selection.fallbackChain,
        selection.providerId,
        selection.cryptoProviderId,
        selection.publicPath,
        selection.riskLevel,
        selection.observabilityTags
    )
}

func touchpointEscapeJson(value: String): String {
    escapeJsonText(value)
}
