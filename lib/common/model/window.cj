@NonProduct
features {}
package ohos_app_cangjie_entry.model

internal import ohos.state_manage.*
internal import ohos.window.WindowStage
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish

// ---------------------------------------------------------------------------
// 窗口数据（对齐 Moeasync window_util.cj 的 WindowData）。
//
// 注册在 AppStorage 的 "windowData" 键上；业务层通过 SelineViewModel.window
// 访问，组件也可用 @StorageLink["windowData"] 直接绑定。
// ---------------------------------------------------------------------------

public let WINDOW_DATA_KEY: String = "windowData"

let _ = AppStorage.setOrCreate<WindowData>(WINDOW_DATA_KEY, WindowData())

@Observed
public class WindowData {
    /// 顶部避让区（状态栏 / 挖孔），vp。
    @Publish
    public var topRectHeight: Float64 = 0.0
    /// 底部避让区（导航条 / 手势条），vp。
    @Publish
    public var bottomRectHeight: Float64 = 0.0
    /// 左侧避让区（横屏挖孔），vp。
    @Publish
    public var leftRectHeight: Float64 = 0.0
    /// 右侧避让区（横屏挖孔），vp。
    @Publish
    public var rightRectHeight: Float64 = 0.0
    /// 窗口宽度，vp。
    @Publish
    public var windowWidth: Float64 = 0.0
    /// 窗口高度，vp。
    @Publish
    public var windowHeight: Float64 = 0.0
    /// 装饰栏高度。
    @Publish
    public var decorBarHeight: Int32 = 50
    /// 应用是否退到后台。
    @Publish
    public var inInBackground: Bool = false
    /// 是否为 PC / 2in1 形态或自由多窗。
    @Publish
    public var isInPcMode: Bool = false
    /// 是否宽屏（>= 700vp）。
    @Publish
    public var isWide: Bool = false
}

/// 全局窗口数据（AppStorage: "windowData"）。
public func windowData(): WindowData {
    AppStorage.get<WindowData>(WINDOW_DATA_KEY).getOrThrow()
}

common public class WindowUtil {
    common public init()

    /// 初始化窗口：记录 WindowStage、设置全屏布局、刷新避让区与尺寸。
    /// 必须在窗口内容加载完成之后调用（HOS 上过早调用会卡住启动）。
    common public static func initWindow(stage: WindowStage): Unit

    /// 重新应用全屏布局（幂等）。
    common public static func applyFullscreen(): Unit

    /// 刷新避让区（切前后台、避让区变化后调用）。
    common public static func updateAvoidArea(widthVp: Float64): Unit

    /// 刷新窗口尺寸。
    common public static func updateScreenSize(widthVp: Float64): Unit

    /// 保持屏幕常亮。
    common public static func setKeepScreenOn(status: Bool): Unit

    /// 设置窗口亮度（0.0 ~ 1.0，负数恢复系统亮度）。
    common public static func setWindowBrightness(brightness: Float64): Unit

    /// 设置屏幕方向：0 竖屏，1 横屏，2 反向竖屏，3 反向横屏，4 自动。
    common public static func setPreferredOrientation(orientation: Int32): Unit

    /// 显示/隐藏状态栏。
    common public static func setStatusBarVisible(visible: Bool): Unit

    /// 显示/隐藏底部导航条。
    common public static func setNavigationBarVisible(visible: Bool): Unit

    /// 刷新是否为 PC 形态。
    common public static func checkIsPcMode(): Unit
}




