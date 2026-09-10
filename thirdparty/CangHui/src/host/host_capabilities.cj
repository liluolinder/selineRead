package chui.host

import std.collection.ArrayList

/** Platforms that may host the same common CangHui component source. */
public enum HostPlatform <: Equatable<HostPlatform> {
    | Desktop
    | Android
    | HarmonyOS
    | IOS

    public operator func ==(other: HostPlatform): Bool {
        hostPlatformName(this) == hostPlatformName(other)
    }

    public operator func !=(other: HostPlatform): Bool {
        !(this == other)
    }
}

/** Platform services that common components may request from their host. */
public enum HostCapability <: Equatable<HostCapability> {
    | FileOpen
    | FileSave
    | Clipboard
    | SecureStorage
    | Lifecycle
    | WindowControl
    | Ime
    | Accessibility
    | MediaSession
    | NativeSurface
    | AudioOutput
    | DragDrop
    | Notifications
    | Network
    | OpenUrl
    | TouchInput
    | SafeArea
    | ApplicationStorage
    | SystemTheme
    | BackgroundTasks
    | MediaLibrary

    public operator func ==(other: HostCapability): Bool {
        hostCapabilityName(this) == hostCapabilityName(other)
    }

    public operator func !=(other: HostCapability): Bool {
        !(this == other)
    }
}

/** A platform identity plus the services the current host implements. */
public struct HostProfile {
    public let platform: HostPlatform
    public let capabilities: Array<HostCapability>

    public init(platform: HostPlatform, capabilities!: Array<HostCapability> = []) {
        this.platform = platform
        this.capabilities = uniqueCapabilities(capabilities)
    }

    public func supports(capability: HostCapability): Bool {
        for (candidate in capabilities) {
            if (candidate == capability) {
                return true
            }
        }
        false
    }

    public func supportsAll(required: Array<HostCapability>): Bool {
        missing(required).isEmpty()
    }

    public func missing(required: Array<HostCapability>): Array<HostCapability> {
        let result = ArrayList<HostCapability>()
        for (capability in required) {
            if (!supports(capability)) {
                result.add(capability)
            }
        }
        result.toArray()
    }
}

public func hostPlatformName(platform: HostPlatform): String {
    match (platform) {
        case HostPlatform.Desktop => "desktop"
        case HostPlatform.Android => "android"
        case HostPlatform.HarmonyOS => "harmonyos"
        case HostPlatform.IOS => "ios"
    }
}

public func hostCapabilityName(capability: HostCapability): String {
    match (capability) {
        case HostCapability.FileOpen => "file-open"
        case HostCapability.FileSave => "file-save"
        case HostCapability.Clipboard => "clipboard"
        case HostCapability.SecureStorage => "secure-storage"
        case HostCapability.Lifecycle => "lifecycle"
        case HostCapability.WindowControl => "window-control"
        case HostCapability.Ime => "ime"
        case HostCapability.Accessibility => "accessibility"
        case HostCapability.MediaSession => "media-session"
        case HostCapability.NativeSurface => "native-surface"
        case HostCapability.AudioOutput => "audio-output"
        case HostCapability.DragDrop => "drag-drop"
        case HostCapability.Notifications => "notifications"
        case HostCapability.Network => "network"
        case HostCapability.OpenUrl => "open-url"
        case HostCapability.TouchInput => "touch-input"
        case HostCapability.SafeArea => "safe-area"
        case HostCapability.ApplicationStorage => "application-storage"
        case HostCapability.SystemTheme => "system-theme"
        case HostCapability.BackgroundTasks => "background-tasks"
        case HostCapability.MediaLibrary => "media-library"
    }
}

private func uniqueCapabilities(values: Array<HostCapability>): Array<HostCapability> {
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
