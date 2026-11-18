features {os.android}
package ohos_app_cangjie_entry.model


internal import ohos.window.WindowStage
internal import mirrors.*

// ---------------------------------------------------------------------------
// Android 窗口实现（与 HOS 同一套 WindowUtil 契约）。
//
// Java 的 WindowBridge 在 EntryEntryAbilityActivity 里 attach，负责
// edge-to-edge 与 WindowInsets 上报；这里把像素换算成 vp 后写入 WindowData。
// 方向 / 状态栏 / 亮度等能力在 Android 侧暂未接线，保持空实现。
// ---------------------------------------------------------------------------

specific public class WindowUtil {
    specific public init() {}

    private static func density(): Float64 {
        let value = Float64(WindowBridge.density())
        if (value <= 0.0) {
            1.0
        } else {
            value
        }
    }

    specific public static func initWindow(stage: WindowStage): Unit {
        WindowBridge.applyFullscreen()
        WindowUtil.updateAvoidArea(0.0)
        WindowUtil.updateScreenSize(0.0)
        WindowUtil.checkIsPcMode()
    }

    specific public static func applyFullscreen(): Unit {
        WindowBridge.applyFullscreen()
    }

    specific public static func updateAvoidArea(widthVp: Float64): Unit {
        let data = windowData()
        data.topRectHeight = Float64(WindowBridge.topInsetDp())
        data.bottomRectHeight = Float64(WindowBridge.bottomInsetDp())
        data.leftRectHeight = 0.0
        data.rightRectHeight = 0.0
    }

    specific public static func updateScreenSize(widthVp: Float64): Unit {
        let data = windowData()
        let scale = WindowUtil.density()
        data.windowWidth = if (widthVp > 0.0) {
            widthVp
        } else {
            Float64(WindowBridge.widthPx()) / scale
        }
        data.windowHeight = Float64(WindowBridge.heightPx()) / scale
        data.isWide = data.windowWidth >= 700.0
    }

    specific public static func setKeepScreenOn(status: Bool): Unit {
        ()
    }

    specific public static func setWindowBrightness(brightness: Float64): Unit {
        ()
    }

    specific public static func setPreferredOrientation(orientation: Int32): Unit {
        ()
    }

    specific public static func setStatusBarVisible(visible: Bool): Unit {
        ()
    }

    specific public static func setNavigationBarVisible(visible: Bool): Unit {
        ()
    }

    specific public static func checkIsPcMode(): Unit {
        let probe = "probe"
        let _ = probe.toString()
        windowData().isInPcMode = false
    }
}








