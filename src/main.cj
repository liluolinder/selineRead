/*
 * Seline Read 的启动编排。
 *
 * 关键顺序（与 seline_bili 一致，也是框架的硬要求）：
 *   attachHiddenConsole → 阻塞式初始化 → 在原生线程上建窗口 → 跑帧循环
 *
 * 「阻塞式初始化」必须**在建窗口之前**完成：窗口会记下创建它的原生线程，
 * 之后拒绝别的线程轮询；而阻塞调用会让运行时把当前线程挪走。
 */
package seline_read

import std.convert.*
import std.env.getVariable
import std.fs.{Path, exists}
import chui.*
import seline_ui.*
import seline_read.platform.*


/** 普通窗口态的圆角（最大化时框架会保留，后续可跟随窗口状态归零）。 */
let WINDOW_CORNER_RADIUS: Float32 = 12.0

/**
 * 启动参数解析结果。
 *
 * 单独建类型而不是三个局部变量：UI 闭包要捕获这些值，
 * 而仓颉不允许逃逸闭包捕获 `var`。
 */
class LaunchOptions {
    let shotPath: String
    let initialTab: Int64
    let searchKeyword: String
    let railOpen: Bool
    let login: Bool
    let downloadTarget: String
    let bookTarget: String
    let settleFrames: UInt64
    let booklistAutoOpen: Bool
    let openDownloadMenu: Bool
    let perf: Bool
    let gpuDriver: String
    let noVsync: Bool
    let zoom: Float32
    let plainWindow: Bool
    let blank: Bool

    init(shotPath: String, initialTab: Int64, searchKeyword: String, railOpen: Bool,
        login: Bool, downloadTarget: String, bookTarget: String, settleFrames: UInt64,
        booklistAutoOpen: Bool, openDownloadMenu: Bool, perf: Bool, gpuDriver: String,
        noVsync: Bool, zoom: Float32, plainWindow: Bool, blank: Bool) {
        this.shotPath = shotPath
        this.initialTab = initialTab
        this.searchKeyword = searchKeyword
        this.railOpen = railOpen
        this.login = login
        this.downloadTarget = downloadTarget
        this.bookTarget = bookTarget
        this.settleFrames = settleFrames
        this.booklistAutoOpen = booklistAutoOpen
        this.openDownloadMenu = openDownloadMenu
        this.perf = perf
        this.gpuDriver = gpuDriver
        this.noVsync = noVsync
        this.zoom = zoom
        this.plainWindow = plainWindow
        this.blank = blank
    }
}

/** 解析验收开关（不影响正常使用）。 */
func parseLaunchOptions(args: Array<String>): LaunchOptions {
    var shotPath = ""
    var initialTab: Int64 = 0
    var keyword = ""
    var railOpen = false
    var login = false
    var downloadTarget = ""
    var bookTarget = ""
    var settleFrames: UInt64 = UInt64(720)
    var booklistAutoOpen = false
    var openDownloadMenu = false
    var perf = false
    var gpuDriver = ""
    var noVsync = false
    var zoom: Float32 = 1.0
    var plainWindow = false
    var blank = false
    for (arg in args) {
        // 验收用：把渲染器后备缓冲导出成 PNG，拍完自动关窗
        if (arg.startsWith("--shot=")) {
            shotPath = arg[7..]
        }
        if (arg.startsWith("--tab=")) {
            initialTab = Int64.parse(arg[6..])
        }
        // 验收用：启动后直接执行一次搜索
        if (arg.startsWith("--search=")) {
            keyword = arg[9..]
        }
        // 验收用：启动即展开侧栏
        if (arg == "--rail") {
            railOpen = true
        }
        // 验收：用 ZLIB_TEST_EMAIL / ZLIB_TEST_PASSWORD 自动登录
        if (arg == "--login") {
            login = true
        }
        // 验收：`--download=<id>|<hash>` 直接走下载路径
        if (arg.startsWith("--download=")) {
            downloadTarget = arg[11..]
        }
        // 验收：`--book=<id>|<hash>` 直接打开详情页
        if (arg.startsWith("--book=")) {
            bookTarget = arg[7..]
        }
        // 验收：截图前等待的帧数（网络/解码慢时可加大）
        if (arg.startsWith("--settle=")) {
            settleFrames = UInt64.parse(arg[9..])
        }
        // 验收：书单列表第一次加载成功后自动打开第一份
        if (arg == "--bl-open") {
            booklistAutoOpen = true
        }
        // 验收：直接展开下载版本菜单（配合 --book=）
        if (arg == "--dl-menu") {
            openDownloadMenu = true
        }
        // 验收：打印帧耗时统计（HOME/DETAIL 卡顿排查）
        if (arg == "--perf") {
            perf = true
        }
        // 验收：强制 SDL 渲染驱动（direct3d11 / direct3d12 / vulkan / software）
        if (arg.startsWith("--gpu=")) {
            gpuDriver = arg[6..]
        }
        // 验收：关闭 vsync（测真实渲染耗时 / 滚动跟手）
        if (arg == "--novsync") {
            noVsync = true
        }
        // 验收：UI 缩放（影响后备像素量，用于诊断渲染成本）
        if (arg.startsWith("--zoom=")) {
            zoom = Float32.parse(arg[7..])
        }
        // 诊断：退化为系统边框普通窗口（排查无边框/圆角软合成成本）
        if (arg == "--plain-window") {
            plainWindow = true
        }
        // 诊断：只画一个空根节点，测渲染地板
        if (arg == "--blank") {
            blank = true
        }
    }
    LaunchOptions(shotPath, initialTab, keyword, railOpen, login, downloadTarget, bookTarget,
        settleFrames, booklistAutoOpen, openDownloadMenu, perf, gpuDriver, noVsync, zoom, plainWindow, blank)
}

/**
 * 压测用帧追踪计数器（闭包不能捕获 var，用对象字段）。
 *
 * `SELINE_READ_FRAME_TRACE=1` + `--perf` 时，每帧往调试日志写一行
 * `F <帧号> <帧间隔ms>`，`scripts/stress_pages.ps1` 读它算 p95/p99。
 */
class FrameTraceState {
    var tick: Int64 = 0
}

/** 帧耗时统计（`--perf` 时启用）：用于证明/回归性能优化。 */


main(args: Array<String>): Int64 {
    let options = parseLaunchOptions(args)
    // 第一件事：挂隐藏控制台，让将来可能的子进程有得继承，不闪黑框
    attachHiddenConsole()

    let state = AppState()
    state.prepareImageStore()
    // 启动第一步：只读本地配置/账号（**不做任何网络**），窗口立刻能出来
    writeDebugLog("bootstrap: begin")
    try {
        state.bootstrapLocal()
    } catch (failure: Exception) {
        writeDebugLog("bootstrap failed: ${failure.message}")
        state.error.value = "初始化失败：${failure.message}"
    }
    writeDebugLog("bootstrap: local done")
    if (options.initialTab > 0) {
        state.tab.value = options.initialTab
    }
    writeDebugLog("startup: popular=${state.popular.value.size} tab=${state.tab.value}")

    // 之后全部跑在专用原生线程上
    runUiOnNativeThread({=>
        try {
        // 可选：强制渲染驱动（默认让 SDL 自选；本机疑似落到 software 渲染）
        var hintSettings: Array<SdlHintSetting> = []
        if (!options.gpuDriver.isEmpty()) {
            hintSettings = [SdlHintSetting(SdlHint.CustomHint("SDL_RENDER_DRIVER"),
                options.gpuDriver)]
            writeDebugLog("render driver hint: ${options.gpuDriver}")
        }
        // 字体回退：系统字体缺字时用一份覆盖面更广的 CJK 字体兜底
        match (resolveFallbackFont()) {
            case Some(path) =>
                Fonts.registerBundledFallback(path)
                writeDebugLog("fallback font: ${path}")
            case None => writeDebugLog("fallback font: none")
        }
        let app = DesktopApp(
            windowSpecFor(options),
            theme: selineChuiTheme(),

            hints: hintSettings,
            // 验收用：`--shot=<path>` 由框架在 present 之后从渲染器后备缓冲读回像素，
            // 与窗口是否在前台、有没有被遮挡无关；拍完自动关窗。
            capture: if (options.shotPath.isEmpty()) {
                Option<DesktopCaptureRequest>.None
            } else {
                Some(DesktopCaptureRequest(options.shotPath, settleFrames: options.settleFrames))
            }
        )
        app.setMinimumSize(900, 600)
        // 任务栏/窗口图标：从 assets/SR.png 读入 PNG Surface
        let iconPath = state.iconPath()
        if (!iconPath.isEmpty()) {
            try {
                app.setWindowIcon(SdlSurface.loadPng(iconPath))
                writeDebugLog("window icon: ${iconPath}")
            } catch (failure: Exception) {
                writeDebugLog("window icon failed: ${failure.message}")
            }
        } else {
            writeDebugLog("window icon: asset missing")
        }
        state.attach(app)

        // 窗口摆到主显示器可用区域正中（以前由系统默认放在右下角）
        centerWindowOnDisplay(app, options)
        startResizeCursorLoop(state)
        // 启动第二步：窗口已经能显示，网络（建客户端/首屏）放到后台补
        state.startBackgroundBootstrap()
        // 启动期验收/诊断探针（仅 debug 构建编译进去）
        applyDebugProbes(state, options, app)

        writeDebugLog("window ready")
        // 压测探针：`--perf` 时逐帧记录帧间隔（scripts/stress_pages.ps1 用）
        let frameTrace = options.perf
        let traceState = FrameTraceState()
        let perf = PerfStats(options.perf)

        app.run {
            // FrameHandler 必须在根部且每帧都跑：侧栏弹簧只在帧回调里推进。
            // 缺了这层，点「展开侧栏」永远不会动。
            // 只在「侧栏动画中 / 验收截图 / perf」时持续请求帧：
            // 静态页面交给 chui 的脏帧机制，避免空转重绘整棵树（首页 100 张卡
            // 每帧重绘会直接吃满 CPU）。
            FrameHandler(onFrame: {info =>
                if (frameTrace) {
                    traceState.tick += 1
                    writeDebugLog("F ${traceState.tick} ${info.deltaMs}")

                }
                state.beginFrameTextureBudget()
                state.beginFrameTextBudget()
                let _ = scrollInertia.tick(Float32(info.deltaMs))
                railAdvance(state, Float32(info.deltaMs))
                perf.onFrame(Float32(info.deltaMs))
            }, keepsAlive: {=>
                railAnimating(state) || scrollInertia.animating() || options.perf ||
                    !options.shotPath.isEmpty()
            }) {
                // 主题过渡：这一帧按目标主题构建（构建期抓到的颜色才会跟着揭示走）
                state.prepareThemeBuild()
                if (options.blank) {
                    VStack { }.fillWidth().fillHeight()
                } else {
                    appShell(state)
                }
            }
        }
        writeDebugLog("window closed")
        perf.summary()
        state.shutdown()
        // 直接结束进程，不走「main 返回 → Cangjie 运行时线程收尾」这条路径：
        // 退出时仍有 spawn 出去的后台线程存活，运行时回收线程时会在
        // libcangjie-runtime 的 CJ_CJThreadFree 里踩到已释放内存
        // （0xc0000374 / 0xc0000005，PageHeap 抓包已确认）。
        // 窗口/纹理/渲染器已由 chui 在 window.close() 之前释放。
        terminateSelf(0)
        } catch (failure: Exception) {
            writeDebugLog("ui thread failed: ${failure.message}")
        }
    })
    0
}

/** 窗口规格：默认无边框 + 透明圆角（自绘标题栏）；`--plain-window` 用系统边框做诊断。 */
/**
 * 把窗口默认尺寸收敛到「显示器可用区域」内（逻辑像素）。
 *
 * 高分屏（如 150%/200% 缩放）下 1280x820 的逻辑尺寸会换算成超过屏幕物理尺寸的
 * 窗口，底部/右侧被裁掉；这里按 `可用物理尺寸 / DPI 缩放` 算出可用逻辑尺寸，
 * 留 6% 边距后取较小值。查不到显示器信息时退回原尺寸。
 */
func fitWindowToDisplay(width: Float32, height: Float32): (Float32, Float32) {
    try {
        let info = primaryDisplayInfo()
        let scale = if (info.geometry.contentScale > Float32(0.1)) {
            info.geometry.contentScale
        } else {
            Float32(1.0)
        }
        let usableW = info.geometry.usableBounds.w / scale
        let usableH = info.geometry.usableBounds.h / scale
        if (usableW <= Float32(1.0) || usableH <= Float32(1.0)) {
            return (width, height)
        }
        let margin: Float32 = Float32(0.94)
        var fitW = width
        var fitH = height
        let maxW = usableW * margin
        let maxH = usableH * margin
        if (fitW > maxW) {
            fitW = maxW
        }
        if (fitH > maxH) {
            fitH = maxH
        }
        writeDebugLog("window fit: usable=${usableW}x${usableH} logical -> ${fitW}x${fitH}")
        (fitW, fitH)
    } catch (_: Exception) {
        (width, height)
    }
}
/** 把窗口摆到主显示器可用区域的正中（坐标是物理像素）。 */
func centerWindowOnDisplay(app: DesktopApp, options: LaunchOptions): Unit {
    try {
        let info = primaryDisplayInfo()
        let scale = if (info.geometry.contentScale > Float32(0.1)) {
            info.geometry.contentScale
        } else {
            Float32(1.0)
        }
        let (logicalW, logicalH) = if (options.plainWindow) {
            fitWindowToDisplay(1200.0, 780.0)
        } else {
            fitWindowToDisplay(1280.0, 820.0)
        }
        let windowW = Float32(Int32(logicalW)) * scale
        let windowH = Float32(Int32(logicalH)) * scale
        let area = info.geometry.usableBounds
        let x = Int32(area.x + (area.w - windowW) * Float32(0.5))
        let y = Int32(area.y + (area.h - windowH) * Float32(0.5))
        app.setWindowPosition(x, y)
        writeDebugLog("window centered: (${x}, ${y}) window=${windowW}x${windowH} area=${area.w}x${area.h}")
    } catch (_: Exception) {
        ()
    }
}

func windowSpecFor(options: LaunchOptions): WindowSpec {
    if (options.plainWindow) {
        let (plainW, plainH) = fitWindowToDisplay(1200.0, 780.0)
        return WindowSpec("Seline Read", Int32(plainW), Int32(plainH), resizable: true,
            frameless: false, decorated: true, transparent: false, cornerRadius: 0.0,
            scaling: Some(WindowScaleSettings(followSystem: true, zoom: 1.0)),
            supersample: 1, vsync: true)
    }
    let (fitW, fitH) = fitWindowToDisplay(1280.0, 820.0)
    WindowSpec("Seline Read", Int32(fitW), Int32(fitH),
        // 自绘标题栏：系统不能再画一条
        frameless: true,
        cornerRadius: WINDOW_CORNER_RADIUS,
        scaling: Some(WindowScaleSettings(followSystem: true, zoom: options.zoom)),
        supersample: 1,
        vsync: !options.noVsync)
}
/**
 * 找一份覆盖较广的 CJK 字体做回退（缺字时自动用它补）。
 *
 * 顺序：`SELINE_READ_FALLBACK_FONT` → 程序旁 `assets/fonts/` → Windows 自带字体。
 * 找不到返回 None（保持框架默认行为，不影响启动）。
 */
func resolveFallbackFont(): ?String {
    let custom = customFallbackFont()
    let candidates = [
        custom,
        Path("assets").join("fonts").join("HarmonyOS_Sans_SC.ttf").toString(),
        Path("target").join("release").join("bin").join("assets").join("fonts")
            .join("HarmonyOS_Sans_SC.ttf").toString(),
        "C:\\Windows\\Fonts\\msyh.ttc",
        "C:\\Windows\\Fonts\\msyhbd.ttc",
        "C:\\Windows\\Fonts\\simhei.ttf",
        "C:\\Windows\\Fonts\\simsun.ttc",
        "C:\\Windows\\Fonts\\Deng.ttf"
    ]
    for (candidate in candidates) {
        if (!candidate.isEmpty() && exists(Path(candidate))) {
            return Some(candidate)
        }
    }
    None<String>
}

