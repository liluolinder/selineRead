package SelineRead

import chui.*
import chui.primaryDisplayInfo
import std.collection.ArrayList
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.common.canAccessZlib
import zlibraryAPI4CJ.common.zlibBaseUrl
import zlibraryAPI4CJ.dataModel.*

/*
 * UI 原生线程钉扎（根治「未响应」）
 *
 * 根因链（v13~v15 write-ring/看门狗实锤）：Cangjie 绿色线程调度器会在主绿
 * 线程 park 后把它迁移到其他 OS 线程；Win32 窗口消息队列绑定在创建窗口的
 * 原 OS 线程上，迁移后 SDL_PollEvent 在新线程永远收不到消息 → 窗口 5 秒
 * 无人泵消息 → Windows 判「未响应」，输入全丢。
 *
 * 方案：CreateThread 创建 1:1 原生 OS 线程执行 uiThreadMain（窗口创建 +
 * 事件泵 + 渲染主循环）。原生线程不受调度器管理，消息队列归属永不变。
 * main 只负责准备状态并阻塞等待窗口关闭。
 */
@C
foreign func cui_start_native(cb: CFunc<() -> Unit>): Unit

// main → 原生线程的 AppState 传递（先写后启动线程，顺序即发布）
var gAppState: ?AppState = None

// 原生线程入口：窗口创建 + 主循环全部钉在这里。
// 任何异常都不能逃逸进 C shim（跨过 C 栈抛异常是未定义行为），全部就地捕获。
@C
func uiThreadMain(): Unit {
    try {
        let state = match (gAppState) {
            case Some(s) => s
            case None => AppState()
        }
        // ---- 加载持久化设置 ----
        let (savedUrl, savedTheme, savedDlPath) = loadSettings()
        applyZlibUrl(savedUrl)
        applyDownloadPath(savedDlPath)
        state.themeMode.value = savedTheme
        state.downloadPath.value = savedDlPath
        state.settingsZlibUrl.value = savedUrl
        // ---- 查询主显示器信息，适配 scale ----
        // SDL 的 usableBounds 返回物理像素，WindowSpec 的 width/height 是
        // 逻辑像素（创建窗口时会被 scale 放大）。我们保持固定的逻辑窗口
        // 尺寸（1200×800），只让 scale 跟随系统 DPI，这样布局不受影响。
        let displayInfo = primaryDisplayInfo()
        let dpiScale = displayInfo.geometry.contentScale
        // scale 跟随系统 DPI：直接取 contentScale，不四舍五入
        // 限制在 1.0x ~ 2.5x 之间，避免极端值
        let scale = max(1.0, min(2.5, dpiScale))
        // 窗口初始尺寸：固定 1200×800 逻辑像素（和原来一样）
        // 但确保物理像素不超出显示器可用区域
        let winW = Int32(1200)
        let winH = Int32(800)
        // 最小尺寸：固定 800×600 逻辑像素
        let minW = Int32(800)
        let minH = Int32(600)
        // frameless + cornerRadius：去掉系统窗口装饰，自绘标题栏（拖拽/最小化/最大化/关闭）
        let app = DesktopApp(WindowSpec("SelineRead", winW, winH, frameless: true, cornerRadius: 12.0, scale: scale,),
            theme: selineTheme(state.themeMode.value))
        app.setMinimumSize(minW, minH)
        // 设置主题切换回调，供侧边栏按钮和设置弹窗调用
        state.applyTheme = { mode =>
            let ox = state.themeOriginX.value
            let oy = state.themeOriginY.value
            // 深色→浅色：正向扩散；浅色→深色：反向收缩（从外向内）
            let reverse = (state.themeMode.value == 2)
            app.transitionThemeAt(selineTheme(mode), ox, oy, durationMs: UInt64(500), reverse: reverse)
            saveSettings(zlibBaseUrl, mode, state.downloadPath.value)
        }
        // 任务栏/窗口图标：surface 需存活至窗口关闭
        let icon = SdlSurface.loadPng("assets/icon.png")
        app.setWindowIcon(icon)
        // 常驻封面 worker：绿色线程，只做下载/解码并置脏标志，不泵消息，
        // 在哪个线程 spawn 都可以
        startCoverWorker(app, state)
        app.run {
            // 每帧消费封面刷新脏标志（worker 只置标志，绝不 postToUi）
            pollCoverRefresh(state)
            // 每帧消费下载事件（下载线程只写原子变量，绝不 postToUi）
            pollDownloadRefresh(app, state)
            // 搜索框被清空时自动回到推荐列表
            pollSearchClear(app, state)
            if (!state.started.value) {
                state.started.value = true
                // 启动时先检测域名，检测完成后再加载推荐和登录，避免多个 toast 同时堆叠
                state.toaster.show("正在检测 Z-Library 域名...", kind: ToastKind.Info)
                spawn { =>
                    try {
                        let oldUrl = zlibBaseUrl
                        let ok = canAccessZlib(autoRedirect: true)
                        let newUrl = zlibBaseUrl
                        if (ok && oldUrl != newUrl) {
                            app.postToUi({ => state.toaster.show("已自动切换至新域名: ${newUrl}", kind: ToastKind.Success) })
                        } else if (ok) {
                            app.postToUi({ => state.toaster.show("Z-Library 域名可用", kind: ToastKind.Success) })
                        } else {
                            app.postToUi({ => state.toaster.show("Z-Library 域名暂不可用，请检查网络或稍后重试", kind: ToastKind.Error) })
                        }
                    } catch (_: Exception) {
                        app.postToUi({ => state.toaster.show("Z-Library 域名检测失败，请检查网络", kind: ToastKind.Error) })
                    }
                    // 检测完成后串行加载推荐和登录
                    app.postToUi({ =>
                        fetchRecommend(app, state)
                        tryAutoLogin(app, state)
                    })
                }
            }
            rootView(app, state)
        }
    } catch (e: Exception) {
        // 异常不得逃逸进 C shim（跨 C 栈抛异常是未定义行为），就地吞掉
        ()
    }
}

/// 全局应用状态（立即模式：每帧重建视图，State 驱动刷新）
class AppState {
    public let client: ZlibClient = ZlibClient()

    // ---- 首页（推荐 / 搜索共用）----
    public let recommendBooks: State<Array<BookInfoBrief>> = State<Array<BookInfoBrief>>(Array<BookInfoBrief>())
    public let searchBooks: State<Array<BookInfoBrief>> = State<Array<BookInfoBrief>>(Array<BookInfoBrief>())
    public let isHomeLoading: State<Bool> = State<Bool>(false)
    public let homeError: State<String> = State<String>("")
    public let isSearchMode: State<Bool> = State<Bool>(false)
    public let searchInput: State<String> = State<String>("")
    public let showType: State<Int64> = State<Int64>(0) // 0 瀑布卡片 1 列表
    // 首页滚动位置由外部持有：进入详情页时 homeView 被销毁重建，
    // 滚动偏移若留在控件内部就会归零（返回首页回到顶部），故提升到 AppState
    public let homeGridScroll: State<Float32> = State<Float32>(0.0)
    public let homeListScroll: State<Float32> = State<Float32>(0.0)
    public let searchPage: State<UInt16> = State<UInt16>(1)
    /** 搜索结果的下一页页码（用于滑动到底部继续获取）。 */
    public let searchNextPage: State<UInt16> = State<UInt16>(2)
    public let searchTotalPages: State<UInt64> = State<UInt64>(1)
    public let isSearchLoadingMore: State<Bool> = State<Bool>(false)
    /** 当前生效的搜索词（只在 doSearch 提交时更新）：用于丢弃过期的翻页响应。 */
    public let searchActiveQuery: State<String> = State<String>("")
    // 封面下载完成计数，自增触发依赖封面的视图重绘
    public let coverVersion: State<Int64> = State<Int64>(0)

    // ---- 书架（只做 Z-Library 收藏）----
    /** 卡片/列表切换：0=卡片网格 1=列表（与首页各自独立）。 */
    public let shelfShowType: State<Int64> = State<Int64>(0)
    public let savedBooks: State<Array<BookInfo>> = State<Array<BookInfo>>(Array<BookInfo>())
    public let isShelfLoading: State<Bool> = State<Bool>(false)
    public let shelfError: State<String> = State<String>("")
    public let savedPage: State<UInt64> = State<UInt64>(1)
    public let savedTotalPages: State<UInt64> = State<UInt64>(1)
    public let shelfGridScroll: State<Float32> = State<Float32>(0.0)
    public let shelfListScroll: State<Float32> = State<Float32>(0.0)

    // ---- 账号 ----
    public let emailInput: State<String> = State<String>("")
    public let passwordInput: State<String> = State<String>("")
    public let isLoggingIn: State<Bool> = State<Bool>(false)
    public let loginError: State<String> = State<String>("")
    public let currentUser: State<Option<ZlibUserInfo>> = State<Option<ZlibUserInfo>>(Option<ZlibUserInfo>.None)
    public let userName: State<String> = State<String>("")
    public let downloadLimit: State<String> = State<String>("")

    // ---- 窗口级 ----
    public let currentTab: State<Int64> = State<Int64>(0)
    // 首帧标记：保证 fetchRecommend 只在 app.run 首帧触发一次
    public let started: State<Bool> = State<Bool>(false)
    public let showAccount: State<Bool> = State<Bool>(false)
    public let showSetting: State<Bool> = State<Bool>(false)
    public let showAbout: State<Bool> = State<Bool>(false)
    // 无边框窗口标题栏拖拽状态
    public let windowDrag: WindowDragState = WindowDragState()
    /** 右下角提示弹窗（加载开始/成功/失败）。 */
    public let toaster: Toaster = Toaster()
    /** 首页骨架屏开关（推荐/搜索请求期间为 true）。 */
    public let homeSkeletonOn: State<Bool> = State<Bool>(false)
    /** 详情页骨架屏开关（拉取全量详情期间为 true）。 */
    public let detailSkeletonOn: State<Bool> = State<Bool>(false)
    // 内容区宽度（WidthProbe 在 layout 期上报），驱动瀑布流自适应列数
    public let contentWidth: State<Float64> = State<Float64>(1000.0)

    // ---- 设置（持久化到 settings.json） ----
    /** 主题模式：0=跟随系统, 1=深色, 2=浅色 */
    public let themeMode: State<Int64> = State<Int64>(0)
    /** 下载目录路径 */
    public let downloadPath: State<String> = State<String>("")
    /** 设置界面中的 Z-Library 域名输入（与运行时 zlibBaseUrl 分离） */
    public let settingsZlibUrl: State<String> = State<String>("")
    /** 主题切换原点坐标（供 transitionThemeAt 使用） */
    public let themeOriginX: State<Float32> = State<Float32>(80.0)
    public let themeOriginY: State<Float32> = State<Float32>(600.0)
    /** 主题切换回调（由 native_ui.cj 在创建 DesktopApp 后设置） */
    public var applyTheme: (Int64) -> Unit = { _ => () }

    // ---- 侧边栏（1.0=展开 0.0=收起，宽度过渡动画进度）----
    // 侧栏默认收起（参考 SelineDebugToolBox），展开由用户点击触发
    public let sidebarExpanded: State<Bool> = State<Bool>(false)
    public let sidebarAnim: State<Float32> = State<Float32>(0.0)

    // ---- 书籍详情 ----
    // 详情页可见性与当前书籍（推荐/搜索先以摘要秒开，后台 getBookInfo 补全量）
    public let detailVisible: State<Bool> = State<Bool>(false)
    // 打开详情时所处的页签：详情只在该页签下显示，切走再切回仍保留详情
    public let detailTab: State<Int64> = State<Int64>(0)
    public let detailBook: State<Option<BookInfo>> = State<Option<BookInfo>>(Option<BookInfo>.None)
    // 详情页收藏操作提示；收藏状态变更计数（触发重渲染）
    public let detailMsg: State<String> = State<String>("")
    public let detailFavTick: State<Int64> = State<Int64>(0)

    // ---- 下载管理 ----
    /** 下载任务列表（支持多本书同时下载）。 */
    public let downloadTasks: State<ArrayList<DownloadTaskInfo>> = State<ArrayList<DownloadTaskInfo>>(ArrayList<DownloadTaskInfo>())
    /** 同一本书重复点击下载时的「是否取消」确认框。 */
    public let showCancelDownload: State<Bool> = State<Bool>(false)
    public let cancelTargetBookId: State<UInt64> = State<UInt64>(UInt64(0))
    public let cancelTargetTitle: State<String> = State<String>("")
}

/** 下载任务摘要信息（UI 展示用）。 */
public class DownloadTaskInfo {
    public var bookId: UInt64 = UInt64(0)
    public var bookName: String = ""
    public var coverUrl: String = ""
    public var percent: Float64 = 0.0
    public var status: String = "" // "下载中", "已完成", "失败", "已取消"
    public var filePath: String = ""
    public var speed: String = ""
    /** 事件槽位（0..DL_SLOT_COUNT-1），下载线程只写该槽的原子量。 */
    public var slot: Int64 = -1

    public init() {}

    public init(bookId!: UInt64, bookName!: String, coverUrl!: String, percent!: Float64,
        status!: String, filePath!: String, speed!: String, slot!: Int64) {
        this.bookId = bookId
        this.bookName = bookName
        this.coverUrl = coverUrl
        this.percent = percent
        this.status = status
        this.filePath = filePath
        this.speed = speed
        this.slot = slot
    }
}
