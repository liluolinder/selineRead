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

    init(shotPath: String, initialTab: Int64, searchKeyword: String, railOpen: Bool,
        login: Bool, downloadTarget: String) {
        this.shotPath = shotPath
        this.initialTab = initialTab
        this.searchKeyword = searchKeyword
        this.railOpen = railOpen
        this.login = login
        this.downloadTarget = downloadTarget
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
    }
    LaunchOptions(shotPath, initialTab, keyword, railOpen, login, downloadTarget)
}

main(args: Array<String>): Int64 {
    let options = parseLaunchOptions(args)
    // 第一件事：挂隐藏控制台，让将来可能的子进程有得继承，不闪黑框
    attachHiddenConsole()

    let state = AppState()
    state.prepareImageStore()
    // 网络首屏全部阻塞式完成，且在建窗口之前
    writeDebugLog("bootstrap: begin")
    try {
        state.bootstrap()
    } catch (failure: Exception) {
        writeDebugLog("bootstrap failed: ${failure.message}")
        state.error.value = "初始化失败：${failure.message}"
    }
    writeDebugLog("bootstrap: done")
    if (options.initialTab > 0) {
        state.tab.value = options.initialTab
    }
    writeDebugLog("startup: popular=${state.popular.value.size} tab=${state.tab.value}")

    // 之后全部跑在专用原生线程上
    runUiOnNativeThread({=>
        try {
        let app = DesktopApp(
            WindowSpec(
                "Seline Read",
                1280,
                820,
                // 自绘标题栏：系统不能再画一条
                frameless: true,
                cornerRadius: WINDOW_CORNER_RADIUS,
                scaling: Some(WindowScaleSettings(followSystem: true, zoom: 1.0)),
                supersample: 1
            ),
            theme: selineChuiTheme(),
            // 验收用：`--shot=<path>` 由框架在 present 之后从渲染器后备缓冲读回像素，
            // 与窗口是否在前台、有没有被遮挡无关；拍完自动关窗。
            capture: if (options.shotPath.isEmpty()) {
                Option<DesktopCaptureRequest>.None
            } else {
                Some(DesktopCaptureRequest(options.shotPath, settleFrames: UInt64(720)))
            }
        )
        app.setMinimumSize(1000, 680)
        state.attach(app)
        if (options.railOpen) {
            state.railExpanded.value = true
            state.railZonesOpen.value = true
        }
        // 验收开关必须在 attach 之后：后台结果靠 `postToUi` 回投，
        // 窗口没建好时那条通道会直接丢弃。
        if (!options.searchKeyword.isEmpty()) {
            state.searchText.value = options.searchKeyword
            state.submitSearch()
        }
        if (options.login) {
            let email = getVariable("ZLIB_TEST_EMAIL") ?? ""
            let password = getVariable("ZLIB_TEST_PASSWORD") ?? ""
            if (!email.isEmpty() && !password.isEmpty()) {
                state.loginEmail.value = email
                state.loginPassword.value = password
                state.submitLogin()
            } else {
                writeDebugLog("--login: ZLIB_TEST_EMAIL/PASSWORD not set")
            }
        }
        if (!options.downloadTarget.isEmpty()) {
            let parts = options.downloadTarget.split("|")
            if (parts.size >= 2) {
                let bookId = Int64.tryParse(parts[0]) ?? 0
                if (bookId > 0) {
                    if (options.login) {
                        state.setAutoDownload(bookId, parts[1])
                    } else {
                        state.downloadById(bookId, parts[1])
                    }
                }
            }
        }
        writeDebugLog("window ready")
        app.run {
            // FrameHandler 必须在根部且每帧都跑：侧栏弹簧只在帧回调里推进。
            // 缺了这层，点「展开侧栏」永远不会动。
            FrameHandler(onFrame: {info =>
                railAdvance(state, Float32(info.deltaMs))
            }) {
                appShell(state)
            }
        }
        writeDebugLog("window closed")
        state.shutdown()
        } catch (failure: Exception) {
            writeDebugLog("ui thread failed: ${failure.message}")
        }
    })
    0
}
