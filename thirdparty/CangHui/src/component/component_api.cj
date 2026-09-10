package chui.component

import std.collection.ArrayList
import chui.host.{HostCapability, HostPlatform, HostProfile}

/** Compatibility result before a component package is mounted. */
public enum ComponentCompatibility {
    | Compatible
    | UnsupportedPlatform(HostPlatform)
    | MissingCapabilities(Array<HostCapability>)
}

/** Source-package metadata shared by desktop and platform hosts. */
public struct ComponentPackageDescriptor {
    public let id: String
    public let displayName: String
    public let version: String
    public let minimumCuiVersion: String
    public let supportedPlatforms: Array<HostPlatform>
    public let requiredCapabilities: Array<HostCapability>

    public init(
        id: String,
        displayName: String,
        version: String,
        minimumCuiVersion!: String = componentApiVersion(),
        supportedPlatforms!: Array<HostPlatform> = [],
        requiredCapabilities!: Array<HostCapability> = []
    ) {
        if (id.isEmpty()) {
            throw IllegalArgumentException("component package id must not be empty")
        }
        if (displayName.isEmpty()) {
            throw IllegalArgumentException("component package display name must not be empty")
        }
        if (version.isEmpty()) {
            throw IllegalArgumentException("component package version must not be empty")
        }
        this.id = id
        this.displayName = displayName
        this.version = version
        this.minimumCuiVersion = minimumCuiVersion
        this.supportedPlatforms = uniquePlatforms(supportedPlatforms)
        this.requiredCapabilities = uniqueRequiredCapabilities(requiredCapabilities)
    }

    /** An empty platform list means the package is common-source and platform-neutral. */
    public func supportsPlatform(platform: HostPlatform): Bool {
        if (supportedPlatforms.isEmpty()) {
            return true
        }
        for (candidate in supportedPlatforms) {
            if (candidate == platform) {
                return true
            }
        }
        false
    }

    public func compatibility(host: HostProfile): ComponentCompatibility {
        if (!supportsPlatform(host.platform)) {
            return ComponentCompatibility.UnsupportedPlatform(host.platform)
        }
        let missing = host.missing(requiredCapabilities)
        if (!missing.isEmpty()) {
            return ComponentCompatibility.MissingCapabilities(missing)
        }
        ComponentCompatibility.Compatible
    }
}

/** A static CJPM package exposes metadata while its components remain typed APIs. */
public interface ComponentPackage {
    func descriptor(): ComponentPackageDescriptor
}

/** Common input shared by a real platform host and the desktop gallery. */
public struct ComponentContext {
    public let host: HostProfile
    public let viewport: ViewportSpec

    public init(host: HostProfile, viewport: ViewportSpec) {
        this.host = host
        this.viewport = viewport
    }
}

public func componentApiVersion(): String {
    "0.1.0"
}

private func uniquePlatforms(values: Array<HostPlatform>): Array<HostPlatform> {
    let result = ArrayList<HostPlatform>()
    for (value in values) {
        var seen = false
        for (existing in result) {
            if (existing == value) {
                seen = true
                break
            }
        }
        if (!seen) {
            result.add(value)
        }
    }
    result.toArray()
}

private func uniqueRequiredCapabilities(values: Array<HostCapability>): Array<HostCapability> {
    let result = ArrayList<HostCapability>()
    for (value in values) {
        var seen = false
        for (existing in result) {
            if (existing == value) {
                seen = true
                break
            }
        }
        if (!seen) {
            result.add(value)
        }
    }
    result.toArray()
}
