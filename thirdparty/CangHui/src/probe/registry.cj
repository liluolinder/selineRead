package chui.probe

import std.collection.ArrayList
import std.sync.Mutex

let probeRegistryMutex = Mutex()
let probeEndpoints = ArrayList<ProbeEndpoint>()

/** Macro-generated package initialization installs one bounded probe here. */
public class ProbeRegistration {
    public let endpoint: ProbeEndpoint

    public init(
        name: String,
        description: String,
        handler: ProbeHandler,
        kind!: ProbeKind = ProbeKind.Function
    ) {
        this.endpoint = registerProbeEndpoint(ProbeEndpoint(name, description, kind, handler))
    }
}

public func registerProbeEndpoint(endpoint: ProbeEndpoint): ProbeEndpoint {
    synchronized(probeRegistryMutex) {
        for (existing in probeEndpoints) {
            if (existing.name == endpoint.name) {
                throw IllegalStateException("duplicate probe registration: " + endpoint.name)
            }
        }
        probeEndpoints.add(endpoint)
    }
    endpoint
}

public func listProbeEndpoints(): Array<ProbeEndpoint> {
    let copy = ArrayList<ProbeEndpoint>()
    synchronized(probeRegistryMutex) {
        for (endpoint in probeEndpoints) { copy.add(endpoint) }
    }
    sortProbeEndpoints(copy.toArray())
}

public func findProbeEndpoint(name: String): ?ProbeEndpoint {
    var found: ?ProbeEndpoint = None
    synchronized(probeRegistryMutex) {
        for (endpoint in probeEndpoints) {
            if (endpoint.name == name) {
                found = Some(endpoint)
                break
            }
        }
    }
    found
}

public func renderProbeEndpointList(json!: Bool = false): String {
    let endpoints = listProbeEndpoints()
    if (!json) {
        let out = StringBuilder()
        var first = true
        for (endpoint in endpoints) {
            if (!first) { out.append("\n") }
            first = false
            out.append(endpoint.name)
        }
        return out.toString()
    }
    let out = StringBuilder()
    out.append("{\"protocol\":\"")
    out.append(CUI_PROBE_PROTOCOL)
    out.append("\",\"probes\":[")
    var first = true
    for (endpoint in endpoints) {
        if (!first) { out.append(",") }
        first = false
        out.append("{\"name\":")
        out.append(probeJsonQuote(endpoint.name))
        out.append(",\"kind\":")
        out.append(probeJsonQuote(probeKindName(endpoint.kind)))
        out.append(",\"description\":")
        out.append(probeJsonQuote(endpoint.description))
        out.append("}")
    }
    out.append("]}")
    out.toString()
}

public func describeProbeEndpoint(name: String, json!: Bool = false): String {
    match (findProbeEndpoint(name)) {
        case Some(endpoint) =>
            if (json) {
                "{\"protocol\":" + probeJsonQuote(CUI_PROBE_PROTOCOL) +
                    ",\"name\":" + probeJsonQuote(endpoint.name) +
                    ",\"kind\":" + probeJsonQuote(probeKindName(endpoint.kind)) +
                    ",\"description\":" + probeJsonQuote(endpoint.description) + "}"
            } else {
                endpoint.name + "|" + probeKindName(endpoint.kind) + "|" + endpoint.description
            }
        case None => throw IllegalArgumentException("unknown probe: " + name)
    }
}

public func runProbeEndpoint(name: String, payload!: String = ""): String {
    match (findProbeEndpoint(name)) {
        case Some(endpoint) => endpoint.run(payload)
        case None => throw IllegalArgumentException("unknown probe: " + name)
    }
}

public func probeJsonQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}

func sortProbeEndpoints(values: Array<ProbeEndpoint>): Array<ProbeEndpoint> {
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
