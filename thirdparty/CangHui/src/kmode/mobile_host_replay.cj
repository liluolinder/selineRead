package chui.kmode

import std.collection.ArrayList
import std.convert.*
import chui.host.{MobileHostCallbackContext, MobileHostPackageReceipt, renderMobileHostSemanticReplay}

/**
 * Builds a kMode handler for one consumer-owned mobile receipt.
 *
 * Payload lines use `actionId|lifecycleEpoch|surfaceGeneration`. An empty
 * payload renders only the staged receipt. Consumers should expose the handler
 * through `@KModeLink` so cuic can reject endpoint collisions before launch.
 */
public func mobileHostReplayHandler(receipt: MobileHostPackageReceipt): KModeHandler {
    { payload: String =>
        renderMobileHostSemanticReplay(receipt, contexts: parseMobileHostReplayPayload(payload))
    }
}

public func parseMobileHostReplayPayload(payload: String): Array<MobileHostCallbackContext> {
    let contexts = ArrayList<MobileHostCallbackContext>()
    if (payload.isEmpty()) { return contexts.toArray() }
    if (payload.size > 65536) {
        throw IllegalArgumentException("mobile host replay payload exceeds 65536 bytes")
    }
    for (line in payload.split("\n")) {
        if (line.isEmpty()) { continue }
        let parts = line.split("|")
        if (parts.size != 3 || parts[0].isEmpty() || parts[0].size > 256) {
            throw IllegalArgumentException(
                "mobile host replay payload lines must be actionId|lifecycleEpoch|surfaceGeneration"
            )
        }
        contexts.add(MobileHostCallbackContext(
            parts[0],
            Int64.parse(parts[1]),
            Int64.parse(parts[2])
        ))
        if (contexts.size > 256) {
            throw IllegalArgumentException("mobile host replay payload exceeds 256 callbacks")
        }
    }
    contexts.toArray()
}
