features {os.ohos}
package ohos_app_cangjie_entry.model


internal import ohos.window.*
internal import ohos.base.BusinessException
internal import ohos.device_info.DeviceInfo
internal import ohos.display.*
import ohos.concurrency.launch

// ---------------------------------------------------------------------------
// HarmonyOS 窗口实现（对齐 Moeasync window_util.cj）。
//
// 避让区取三类最大值，避免挖孔屏 / 手势条被漏算；像素按内容区宽度换算成 vp。
// ---------------------------------------------------------------------------

/// px -> vp：使用显示设备的 densityPixels 换算（ArkUI 的 .px 在非 UI 组件里不可靠）。
private func px2vp(px: Int64): Float64 {
    try {
        let density = Float64(getDefaultDisplaySync().densityPixels)
        if (density > 0.0) {
            Float64(px) / density
        } else {
            Float64(px)
        }
    } catch (_: Exception) {
        Float64(px)
    }
}


specific public class WindowUtil {
    private static var mainWindow: ?Window = None

    specific public init() {}

    specific public static func initWindow(stage: WindowStage): Unit {
        try {
            let window = stage.getMainWindow()
            mainWindow = Some(window)
            try {
                window.setWindowLayoutFullScreen(true)
            } catch (_: BusinessException) {
                ()
            }
            WindowUtil.bindListeners(window, stage)
            WindowUtil.updateAvoidArea(0.0)
            WindowUtil.updateScreenSize(0.0)
            WindowUtil.checkIsPcMode()
        } catch (_: Exception) {
            mainWindow = None
        }
    }

    /// 监听窗口尺寸 / 避让区 / 形态 / 前后台变化。
    private static func bindListeners(window: Window, stage: WindowStage): Unit {
        try {
            window.on(
                WindowCallbackType.WindowSizeChange,
                cb1 { _: Size => launch { =>
                    WindowUtil.updateScreenSize(0.0)
                    WindowUtil.updateAvoidArea(0.0)
                } }
            )
        } catch (_: Exception) {
            ()
        }
        try {
            window.on(
                WindowCallbackType.WindowAvoidAreaChange,
                cb1 { _: AvoidAreaOptions => launch { => WindowUtil.updateAvoidArea(0.0) } }
            )
        } catch (_: Exception) {
            ()
        }
        try {
            window.on(WindowCallbackType.WindowStatusChange, cb1 { _: WindowStatusType => launch { => WindowUtil.checkIsPcMode() } })
        } catch (_: Exception) {
            ()
        }
        try {
            stage.on(
                WindowCallbackType.WindowStageEvent,
                cb1 { event: WindowStageEventType => launch { =>
                    match (event) {
                        case WindowStageEventType.PAUSED => windowData().inInBackground = true
                        case _ => windowData().inInBackground = false
                    }
                } }
            )
        } catch (_: Exception) {
            ()
        }
    }

    specific public static func applyFullscreen(): Unit {
        match (mainWindow) {
            case Some(window) =>
                try {
                    window.setWindowLayoutFullScreen(true)
                } catch (_: BusinessException) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func updateAvoidArea(widthVp: Float64): Unit {
        let data = windowData()
        match (mainWindow) {
            case Some(window) =>
                try {
                    let cutout = window.getWindowAvoidArea(AvoidAreaType.TYPE_CUTOUT)
                    let system = window.getWindowAvoidArea(AvoidAreaType.TYPE_SYSTEM)
                    let navi = window.getWindowAvoidArea(AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
                    data.topRectHeight = px2vp(
                        max(Int64(cutout.topRect.height), Int64(system.topRect.height))
                    )
                    data.bottomRectHeight = px2vp(
                        max(max(Int64(navi.bottomRect.height), Int64(system.bottomRect.height)), Int64(cutout.bottomRect.height))
                    )
                    data.leftRectHeight = px2vp(max(Int64(cutout.leftRect.width), Int64(system.leftRect.width)))
                    data.rightRectHeight = px2vp(max(Int64(cutout.rightRect.width), Int64(system.rightRect.width)))
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func updateScreenSize(widthVp: Float64): Unit {
        let data = windowData()
        match (mainWindow) {
            case Some(window) =>
                try {
                    let rect = window.getWindowProperties().windowRect
                    data.windowWidth = px2vp(Int64(rect.width))
                    data.windowHeight = px2vp(Int64(rect.height))
                    data.isWide = data.windowWidth >= 700.0
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func setKeepScreenOn(status: Bool): Unit {
        match (mainWindow) {
            case Some(window) =>
                try {
                    window.setWindowKeepScreenOn(status)
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func setWindowBrightness(brightness: Float64): Unit {
        match (mainWindow) {
            case Some(window) =>
                try {
                    window.setWindowBrightness(Float32(brightness))
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func setPreferredOrientation(orientation: Int32): Unit {
        // 当前 SDK 的 WindowOrientation 名称与文档不一致，暂不接线。
        ()
    }

    specific public static func setStatusBarVisible(visible: Bool): Unit {
        match (mainWindow) {
            case Some(window) =>
                try {
                    window.setWindowSystemBarEnable(if (visible) {
                        ["status"]
                    } else {
                        Array<String>()
                    })
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func setNavigationBarVisible(visible: Bool): Unit {
        match (mainWindow) {
            case Some(window) =>
                try {
                    window.setWindowSystemBarEnable(if (visible) {
                        ["navigation"]
                    } else {
                        Array<String>()
                    })
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    specific public static func checkIsPcMode(): Unit {
        let data = windowData()
        let deviceType = DeviceInfo.deviceType.toAsciiUpper()
        data.isInPcMode = deviceType.contains("PC") || deviceType.contains("2IN1")
    }
}





















