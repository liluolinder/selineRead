package jinguissl.live

import jinguissl.runtime.*
import std.collection.ArrayList

// --- Old-live wrapper for the runtime-owned startup profile catalog ---
// This file exposes the runtime catalog through the contract live package
// without modifying live.cj. It proves the runtime catalog is reachable
// from the contract layer and aligns with the existing profile list.
// No dependency on JinguiSSL or jinguissl_core types.

public class ContractLiveStartupProfileCatalogEntry {
    public let label: String
    public let requiresHttpTls: Bool
    public let requiresSsh: Bool
    public let requiresX509: Bool
    public let requiresAcceleration: Bool
    public let notes: Array<String>
    public let requireRandom: Bool
    public let requireCurrentReleasePrimaryBackend: Bool
    public let requireDirectStdxTlsServerConfigBridge: Bool
    public let defaultAesEngineKind: Int64
    public let defaultAesBackendHint: String

    public init(
        label: String,
        requiresHttpTls: Bool,
        requiresSsh: Bool,
        requiresX509: Bool,
        requiresAcceleration: Bool,
        notes: Array<String>,
        requireRandom: Bool,
        requireCurrentReleasePrimaryBackend: Bool,
        requireDirectStdxTlsServerConfigBridge: Bool,
        defaultAesEngineKind: Int64,
        defaultAesBackendHint: String
    ) {
        this.label = label
        this.requiresHttpTls = requiresHttpTls
        this.requiresSsh = requiresSsh
        this.requiresX509 = requiresX509
        this.requiresAcceleration = requiresAcceleration
        this.notes = notes.clone()
        this.requireRandom = requireRandom
        this.requireCurrentReleasePrimaryBackend = requireCurrentReleasePrimaryBackend
        this.requireDirectStdxTlsServerConfigBridge = requireDirectStdxTlsServerConfigBridge
        this.defaultAesEngineKind = defaultAesEngineKind
        this.defaultAesBackendHint = defaultAesBackendHint
    }
}

public func contractLiveListStartupProfileCatalog(): Array<ContractLiveStartupProfileCatalogEntry> {
    let entries = jinguiListStartupProfileCatalog()
    let result = ArrayList<ContractLiveStartupProfileCatalogEntry>()
    for (entry in entries) {
        result.add(ContractLiveStartupProfileCatalogEntry(
            entry.label,
            entry.requiresHttpTls,
            entry.requiresSsh,
            entry.requiresX509,
            entry.requiresAcceleration,
            entry.notes.clone(),
            entry.requireRandom,
            entry.requireCurrentReleasePrimaryBackend,
            entry.requireDirectStdxTlsServerConfigBridge,
            entry.defaultAesEngineKind,
            entry.defaultAesBackendHint
        ))
    }
    result.toArray()
}
