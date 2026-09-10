package chui.testkit

import chui.component.{ComponentContext, ViewportSpec}
import chui.host.{HostCapability, HostPlatform, HostProfile}

/** A desktop-rendered layout target, not a platform-runtime proof. */
public struct PreviewCase {
    public let id: String
    public let label: String
    public let targetHost: HostProfile
    public let viewport: ViewportSpec

    public init(id: String, label: String, targetHost: HostProfile, viewport: ViewportSpec) {
        this.id = id
        this.label = label
        this.targetHost = targetHost
        this.viewport = viewport
    }

    public func componentContext(): ComponentContext {
        ComponentContext(targetHost, viewport)
    }
}

/** Default cross-platform common-layout review matrix for one desktop gallery run. */
public func commonPreviewMatrix(): Array<PreviewCase> {
    [
        PreviewCase(
            "android-phone",
            "Android phone",
            commonTargetHost(HostPlatform.Android),
            ViewportSpec("android-390x844", "390 x 844", 390.0, 844.0)
        ),
        PreviewCase(
            "harmony-phone",
            "Harmony phone",
            commonTargetHost(HostPlatform.HarmonyOS),
            ViewportSpec("harmony-412x915", "412 x 915", 412.0, 915.0)
        ),
        PreviewCase(
            "common-tablet",
            "Common tablet",
            commonTargetHost(HostPlatform.HarmonyOS),
            ViewportSpec("tablet-800x1100", "800 x 1100", 800.0, 1100.0)
        ),
        PreviewCase(
            "desktop",
            "Desktop",
            commonTargetHost(HostPlatform.Desktop),
            ViewportSpec("desktop-1280x760", "1280 x 760", 1280.0, 760.0)
        ),
        PreviewCase(
            "ios-layout-planned",
            "iOS layout planned",
            commonTargetHost(HostPlatform.IOS),
            ViewportSpec("ios-393x852", "393 x 852", 393.0, 852.0)
        )
    ]
}

private func commonTargetHost(platform: HostPlatform): HostProfile {
    HostProfile(
        platform,
        capabilities: [
            HostCapability.Clipboard,
            HostCapability.Lifecycle,
            HostCapability.Ime,
            HostCapability.Network,
            HostCapability.OpenUrl
        ]
    )
}
