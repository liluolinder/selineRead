package chui.kmode

import std.collection.ArrayList
import std.sync.Mutex
import chui.probe.{describeProbeEndpoint, renderProbeEndpointList, runProbeEndpoint}

private let PROBE_LIST_ENDPOINT = "cui.probe.list"
private let PROBE_DESCRIBE_ENDPOINT = "cui.probe.describe"
private let PROBE_RUN_ENDPOINT = "cui.probe.run"

let kModeRegistryMutex = Mutex()
let kModeEndpoints = ArrayList<KModeEndpoint>()

/** Macro-generated package initialization installs one endpoint here. */
public class KModeRegistration {
    public let endpoint: KModeEndpoint

    public init(
        name: String,
        description: String,
        capability: KModeCapability,
        handler: KModeHandler
    ) {
        this.endpoint = registerKModeEndpoint(
            KModeEndpoint(name, description, capability, handler)
        )
    }
}

@When[debug]
public func registerKModeEndpoint(endpoint: KModeEndpoint): KModeEndpoint {
    synchronized(kModeRegistryMutex) {
        for (existing in kModeEndpoints) {
            if (existing.name == endpoint.name) {
                throw IllegalStateException(
                    "duplicate kMode endpoint registration: " + endpoint.name
                )
            }
        }
        kModeEndpoints.add(endpoint)
    }
    endpoint
}

@When[!debug]
public func registerKModeEndpoint(endpoint: KModeEndpoint): KModeEndpoint {
    endpoint
}

@When[debug]
public func listKModeEndpoints(): Array<KModeEndpoint> {
    let copy = ArrayList<KModeEndpoint>()
    synchronized(kModeRegistryMutex) {
        for (endpoint in kModeEndpoints) {
            copy.add(endpoint)
        }
    }
    sortKModeEndpoints(copy.toArray())
}

@When[!debug]
public func listKModeEndpoints(): Array<KModeEndpoint> {
    []
}

@When[debug]
public func findKModeEndpoint(name: String): ?KModeEndpoint {
    var found: ?KModeEndpoint = None
    synchronized(kModeRegistryMutex) {
        for (endpoint in kModeEndpoints) {
            if (endpoint.name == name) {
                found = Some(endpoint)
                break
            }
        }
    }
    found
}

@When[!debug]
public func findKModeEndpoint(_name: String): ?KModeEndpoint {
    let _ = _name
    None
}

@When[debug]
public func dispatchKModeRequest(
    request: KModeRequest,
    policy!: KModePolicy = KModePolicy()
): KModeResponse {
    if (!policy.enabled) {
        return KModeResponse(
            request.id,
            false,
            "disabled",
            errorCode: -32000,
            errorMessage: "kMode is disabled"
        )
    }
    match (request.operation) {
        case KModeOperation.Health =>
            if (!policy.allows(KModeCapability.Inspect)) {
                capabilityDenied(request, KModeCapability.Inspect)
            } else {
                KModeResponse(request.id, true, "ready", payload: KMODE_PROTOCOL)
            }
        case KModeOperation.List =>
            if (!policy.allows(KModeCapability.Inspect)) {
                capabilityDenied(request, KModeCapability.Inspect)
            } else {
                KModeResponse(request.id, true, "ok", payload: renderKModeEndpointList())
            }
        case KModeOperation.Describe =>
            if (!policy.allows(KModeCapability.Inspect)) {
                capabilityDenied(request, KModeCapability.Inspect)
            } else {
                describeKModeEndpoint(request)
            }
        case KModeOperation.Invoke =>
            invokeKModeEndpoint(request, policy)
        case KModeOperation.Shutdown =>
            if (!policy.allows(KModeCapability.Admin)) {
                capabilityDenied(request, KModeCapability.Admin)
            } else {
                KModeResponse(request.id, true, "stopping")
            }
    }
}

@When[!debug]
public func dispatchKModeRequest(
    request: KModeRequest,
    policy!: KModePolicy = KModePolicy()
): KModeResponse {
    if (policy.enabled) { () }
    KModeResponse(
        request.id,
        false,
        "disabled",
        errorCode: -32000,
        errorMessage: "kMode is unavailable in release builds"
    )
}

func renderKModeEndpointList(): String {
    var out = ""
    var first = true
    for (endpoint in listKModeEndpoints()) {
        if (!first) {
            out += "\n"
        }
        first = false
        out += endpoint.name
    }
    for (name in [PROBE_LIST_ENDPOINT, PROBE_DESCRIBE_ENDPOINT, PROBE_RUN_ENDPOINT]) {
        if (!first) { out += "\n" }
        first = false
        out += name
    }
    out
}

func describeKModeEndpoint(request: KModeRequest): KModeResponse {
    if (request.endpoint == PROBE_LIST_ENDPOINT) {
        return KModeResponse(request.id, true, "ok", payload: PROBE_LIST_ENDPOINT + "|inspect|list registered cui.probe.v0 probes")
    }
    if (request.endpoint == PROBE_DESCRIBE_ENDPOINT) {
        return KModeResponse(request.id, true, "ok", payload: PROBE_DESCRIBE_ENDPOINT + "|inspect|describe one cui.probe.v0 probe")
    }
    if (request.endpoint == PROBE_RUN_ENDPOINT) {
        return KModeResponse(request.id, true, "ok", payload: PROBE_RUN_ENDPOINT + "|invoke|run one bounded cui.probe.v0 probe")
    }
    match (findKModeEndpoint(request.endpoint)) {
        case Some(endpoint) =>
            KModeResponse(
                request.id,
                true,
                "ok",
                payload: endpoint.name + "|" +
                    kModeCapabilityName(endpoint.capability) + "|" +
                    endpoint.description
            )
        case None => missingKModeEndpoint(request)
    }
}

func invokeKModeEndpoint(request: KModeRequest, policy: KModePolicy): KModeResponse {
    if (request.endpoint == PROBE_LIST_ENDPOINT || request.endpoint == PROBE_DESCRIBE_ENDPOINT) {
        if (!policy.allows(KModeCapability.Inspect)) {
            return capabilityDenied(request, KModeCapability.Inspect)
        }
        try {
            let payload = if (request.endpoint == PROBE_LIST_ENDPOINT) {
                renderProbeEndpointList(json: request.payload == "json")
            } else {
                let parts = splitProbeTransportPayload(request.payload)
                describeProbeEndpoint(parts[0], json: parts[1] == "json")
            }
            return KModeResponse(request.id, true, "ok", payload: payload)
        } catch (error: Exception) {
            return KModeResponse(request.id, false, "handler-error", errorCode: -32010, errorMessage: error.message)
        }
    }
    if (request.endpoint == PROBE_RUN_ENDPOINT) {
        if (!policy.allows(KModeCapability.Invoke)) {
            return capabilityDenied(request, KModeCapability.Invoke)
        }
        try {
            let parts = splitProbeTransportPayload(request.payload)
            return KModeResponse(request.id, true, "ok", payload: runProbeEndpoint(parts[0], payload: parts[1]))
        } catch (error: Exception) {
            return KModeResponse(request.id, false, "handler-error", errorCode: -32010, errorMessage: error.message)
        }
    }
    match (findKModeEndpoint(request.endpoint)) {
        case Some(endpoint) =>
            if (!policy.allows(endpoint.capability)) {
                return KModeResponse(
                    request.id,
                    false,
                    "forbidden",
                    errorCode: -32003,
                    errorMessage: "kMode capability denied: " +
                        kModeCapabilityName(endpoint.capability)
                )
            }
            try {
                KModeResponse(request.id, true, "ok", payload: endpoint.invoke(request.payload))
            } catch (error: Exception) {
                KModeResponse(
                    request.id,
                    false,
                    "handler-error",
                    errorCode: -32010,
                    errorMessage: error.message
                )
            }
        case None => missingKModeEndpoint(request)
    }
}

func splitProbeTransportPayload(payload: String): Array<String> {
    let runes = payload.toRuneArray()
    var index: Int64 = 0
    while (index < runes.size) {
        if (runes[index] == r'\n') {
            return [substringProbe(payload, 0, index), substringProbe(payload, index + 1, runes.size)]
        }
        index += 1
    }
    [payload, ""]
}

func substringProbe(value: String, start: Int64, end: Int64): String {
    let runes = value.toRuneArray()
    let out = StringBuilder()
    var i = start
    while (i < end && i < runes.size) {
        out.append(runes[i].toString())
        i += 1
    }
    out.toString()
}

func missingKModeEndpoint(request: KModeRequest): KModeResponse {
    KModeResponse(
        request.id,
        false,
        "not-found",
        errorCode: -32601,
        errorMessage: "unknown kMode endpoint: " + request.endpoint
    )
}

func capabilityDenied(
    request: KModeRequest,
    capability: KModeCapability
): KModeResponse {
    KModeResponse(
        request.id,
        false,
        "forbidden",
        errorCode: -32003,
        errorMessage: "kMode operation " + kModeOperationName(request.operation) +
            " requires " + kModeCapabilityName(capability)
    )
}

func sortKModeEndpoints(values: Array<KModeEndpoint>): Array<KModeEndpoint> {
    var i: Int64 = 0
    while (i < values.size) {
        var j: Int64 = i + 1
        while (j < values.size) {
            if (values[j].name < values[i].name) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}
