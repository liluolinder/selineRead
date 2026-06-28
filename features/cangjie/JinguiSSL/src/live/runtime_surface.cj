package jinguissl.live

import jinguissl.runtime.*

public class ContractRuntimeSurfaceInfo {
    public let packageName: String
    public let compatibilityMarker: Int64
    public let runtimeVersionTag: String

    public init(packageName: String, compatibilityMarker: Int64, runtimeVersionTag: String) {
        this.packageName = packageName
        this.compatibilityMarker = compatibilityMarker
        this.runtimeVersionTag = runtimeVersionTag
    }
}

public func contractRuntimeSurfaceInfo(): ContractRuntimeSurfaceInfo {
    let desc = jinguiRuntimeSurfaceDescriptor()
    ContractRuntimeSurfaceInfo(
        desc.packageName,
        desc.compatibilityMarker,
        desc.runtimeVersionTag
    )
}
