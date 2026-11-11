/*
 * 应用状态（MVVM 的 ViewModel/Model 层）。
 *
 * 约定与 `seline_bili` 一致：
 *   - 全应用的可变 UI 状态都在 `AppState` 里，由 `State<T>` 持有；
 *   - **只有 UI 线程写 State**：后台任务（网络/解码）把结果通过
 *     `DesktopApp.postToUi` 投回来，再在本类的方法里写入；
 *   - 页面函数（View）只读 State 并声明控件，构建闭包里不发请求。
 *
 * 依赖方向不反转：AppState → zlibraryAPI4CJ / seline_ui / chui。
 */
package seline_read

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, remove}
import chui.*
import seline_ui.*
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.search.*
import zlibraryAPI4CJ.book.*
import zlibraryAPI4CJ.login.*
import zlibraryAPI4CJ.user.*

/**
 * 网格里的一本书（列表项的 ViewModel）。
 *
 * 热门/搜索返回的是两套结构（`BookInfoBrief` / `BookInfo`），但列表只需要
 * 这几个字段，所以进网格前统一成这个类型，页面不必按来源分支。
 */
public class BookCell {
    public let id: Int64
    public let hash: String
    public let title: String
    public let author: String
    public let cover: String
    public let meta: String

    public init(id: Int64, hash: String, title: String, author: String, cover: String,
        meta: String) {
        this.id = id
        this.hash = hash
        this.title = title
        this.author = author
        this.cover = cover
        this.meta = meta
    }
}

/** 本地下载列表的一项（本会话记录）。 */
public class DownloadEntry {
    public let name: String
    public let size: Int64

    public init(name: String, size: Int64) {
        this.name = name
        this.size = size
    }

    /** 人类可读大小。 */
    public func sizeText(): String {
        if (size >= 1024 * 1024) {
            "${size / (1024 * 1024)} MB"
        } else if (size >= 1024) {
            "${size / 1024} KB"
        } else {
            "${size} B"
        }
    }
}

/** 把 `ZlibClient` 装进不可变对象，方便后台闭包安全捕获。 */
class ClientBox {
    let value: ZlibClient

    init(value: ZlibClient) {
        this.value = value
    }
}

/** 详情页后台结果（不可变，方便回投闭包捕获）。 */
class DetailPayload {
    let info: ?BookInfo
    let formats: ArrayList<BookFormat>
    let error: String

    init(info: ?BookInfo, formats: ArrayList<BookFormat>, error: String) {
        this.info = info
        this.formats = formats
        this.error = error
    }

    /** 拉详情 + 可选格式；两部分失败互不影响。 */
    static func load(client: ZlibClient, id: Int64, hash: String): DetailPayload {
        var info: ?BookInfo = None
        var error = ""
        try {
            info = Some(BookApi.info(client, id, hash))
        } catch (failure: ZlibError) {
            error = failure.detail
        }
        var formats = ArrayList<BookFormat>()
        try {
            formats = BookApi.formats(client, id, hash)
        } catch (_: ZlibError) {
            // 没有可选格式不影响详情页
            ()
        }
        DetailPayload(info, formats, error)
    }
}

/** 封面 URL 归一化：相对路径补站点前缀；占位图直接当没有封面。 */
func normalizeCoverUrl(raw: String, siteUrl: String): String {
    if (raw.isEmpty() || raw.contains("cover-not-exists")) {
        return ""
    }
    if (raw.startsWith("//")) {
        return "https:" + raw
    }
    if (raw.startsWith("/")) {
        return siteUrl + raw
    }
    raw
}

/** 把 `BookInfoBrief` 列表归一化成网格项。 */
func cellsFromBriefs(briefs: ArrayList<BookInfoBrief>, siteUrl: String): ArrayList<BookCell> {
    let cells = ArrayList<BookCell>()
    for (brief in briefs) {
        cells.add(BookCell(brief.id, brief.hash, brief.title, brief.author,
            normalizeCoverUrl(brief.cover, siteUrl), ""))
    }
    cells
}

/** 登录后台结果（不可变，方便回投闭包捕获）。 */
class LoginOutcome {
    let ok: Bool
    let message: String
    let client: ?ZlibClient
    let credential: ?ZlibCredential
    let name: String
    let uid: String

    init(ok: Bool, message: String, client: ?ZlibClient, credential: ?ZlibCredential,
        name: String, uid: String) {
        this.ok = ok
        this.message = message
        this.client = client
        this.credential = credential
        this.name = name
        this.uid = uid
    }

    static func load(client: ZlibClient, email: String, password: String): LoginOutcome {
        try {
            let result = LoginApi.login(client, email, password)
            let name = if (result.user.name.isEmpty()) { email } else { result.user.name }
            LoginOutcome(true, "", Some(result.withClient(client)), Some(result.credential),
                name, "${result.user.id}")
        } catch (failure: ZlibError) {
            LoginOutcome(false, failure.detail, Option<ZlibClient>.None, Option<ZlibCredential>.None, "", "")
        }
    }
}

/** 用户资料刷新结果。 */
class ProfileOutcome {
    let ok: Bool
    let name: String
    let uid: String
    let quota: String
    let error: String

    init(ok: Bool, name: String, uid: String, quota: String, error: String) {
        this.ok = ok
        this.name = name
        this.uid = uid
        this.quota = quota
        this.error = error
    }

    static func load(client: ZlibClient): ProfileOutcome {
        try {
            let user = UserApi.profile(client)
            ProfileOutcome(true, user.name, "${user.id}",
                "今日 ${user.downloadsToday}/${user.downloadsLimit}", "")
        } catch (failure: ZlibError) {
            ProfileOutcome(false, "", "", "", failure.detail)
        }
    }
}

/** 下载目标（原书 或 某个格式版本）。 */
class DownloadTarget {
    let id: Int64
    let hash: String

    init(id: Int64, hash: String) {
        this.id = id
        this.hash = hash
    }
}

/** 下载后台结果。 */
class DownloadOutcome {
    let ok: Bool
    let message: String
    let fileName: String
    let bytes: Int64

    init(ok: Bool, message: String, fileName: String, bytes: Int64) {
        this.ok = ok
        this.message = message
        this.fileName = fileName
        this.bytes = bytes
    }

    static func load(client: ZlibClient, target: DownloadTarget, dir: Path): DownloadOutcome {
        try {
            let info = BookApi.file(client, target.id, target.hash)
            if (!info.available()) {
                return DownloadOutcome(false, "服务端没有提供可下载链接（可能没有权限）", "", 0)
            }
            let written = BookApi.download(client, info, dir)
            DownloadOutcome(true, "", info.fileName(), written)
        } catch (failure: ZlibError) {
            DownloadOutcome(false, failure.detail, "", 0)
        }
    }
}

/** 账号持久化文件：`%TEMP%/SelineRead/account.txt`。 */
private func accountFilePath(): String {
    let temp = getVariable("TEMP") ?? "."
    Path(temp).join("SelineRead").join("account.txt").toString()
}

/** 读回上次保存的凭证；没有/损坏时返回游客凭证。 */
private func loadSavedCredential(): ZlibCredential {
    let path = accountFilePath()
    if (!exists(Path(path))) {
        return ZlibCredential.anonymous()
    }
    try {
        let text = String.fromUtf8(File.readFrom(Path(path))).trimAscii()
        let parts = text.split("|")
        if (parts.size < 2 || parts[0].isEmpty() || parts[1].isEmpty()) {
            return ZlibCredential.anonymous()
        }
        let language = if (parts.size >= 3 && !parts[2].isEmpty()) {
            parts[2]
        } else {
            ZlibCredential.anonymous().language
        }
        ZlibCredential(userId: parts[0], userKey: parts[1], siteLanguage: language)
    } catch (_: Exception) {
        ZlibCredential.anonymous()
    }
}

/** 把登录凭证落盘（只保存 userId/userKey/siteLanguage）。 */
private func saveCredential(credential: ZlibCredential): Unit {
    if (!credential.isLoggedIn) {
        return
    }
    try {
        let dir = Path(getVariable("TEMP") ?? ".").join("SelineRead")
        if (!exists(dir)) {
            Directory.create(dir, recursive: true)
        }
        let text = "${credential.userId}|${credential.userKey}|${credential.language}"
        File.writeTo(Path(accountFilePath()), text.toArray())
    } catch (failure: Exception) {
        writeDebugLog("save credential failed: ${failure.message}")
    }
}

/** 删除落盘凭证。 */
private func deleteCredential(): Unit {
    try {
        let path = Path(accountFilePath())
        if (exists(path)) {
            remove(path)
        }
    } catch (_: Exception) {
        ()
    }
}

/** 把 `BookInfo` 列表（搜索结果）归一化成网格项。 */
func cellsFromBooks(books: ArrayList<BookInfo>, siteUrl: String): ArrayList<BookCell> {
    let cells = ArrayList<BookCell>()
    for (book in books) {
        var author = ""
        if (let Some(value) <- book.author) {
            author = value
        }
        let meta = if (book.extension.isEmpty()) {
            ""
        } else {
            "${book.extension} · ${book.filesizeString}"
        }
        cells.add(BookCell(book.id, book.hash, book.title, author,
            normalizeCoverUrl(book.cover, siteUrl), meta))
    }
    cells
}

/**
 * 应用状态。
 *
 * `window` 用 `?DesktopApp` 保存：它在建窗口之后才有值，而 State 在之前就构造了。
 */
public class AppState {
    /** 当前一级页签：0 热门 / 1 搜索 / 2 下载 / 3 设置。 */
    public let tab = State<Int64>(0)
    /** 标题栏搜索框内容。 */
    public let searchText = State<String>("")
    /** 侧栏是否展开（宽版带文字 / 窄版只有图标）。 */
    public let railExpanded = State<Bool>(false)
    /** 「分区」折叠组是否展开。 */
    public let railZonesOpen = State<Bool>(false)
    /** 侧栏动画**是否已经走完**（0 = 收起，1 = 展开）。 */
    public let railProgress = State<Float32>(0.0)
    /** 状态栏文案。 */
    public let status = State<String>("正在连接 Z-Library…")
    /** 最近一次错误（非空时页面顶部显示红色提示条）。 */
    public let error = State<String>("")
    /** 是否正在加载首页数据。 */
    public let loading = State<Bool>(false)
    /** 热门列表。 */
    public let popular = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    /** 搜索结果。 */
    public let results = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    /** 最近一次搜索关键词；空串表示「没在搜索态」。 */
    public let lastKeyword = State<String>("")
    /** 是否停在图书详情页（二级页面）。 */
    public let detailOpen = State<Bool>(false)
    /** 详情页字段。 */
    public let detailTitle = State<String>("")
    public let detailAuthor = State<String>("")
    public let detailMeta = State<String>("")
    public let detailDescription = State<String>("")
    public let detailCover = State<String>("")
    public let detailLoading = State<Bool>(false)
    public let detailError = State<String>("")
    public let detailFormats = State<ArrayList<BookFormat>>(ArrayList<BookFormat>())
    /** 当前详情页的 id / hash（下载要用）。 */
    public let detailId = State<Int64>(0)
    public let detailHash = State<String>("")
    /** 选中的下载版本：0 = 原书，1..N = `detailFormats[index-1]`。 */
    public let detailFormatIndex = State<Int64>(0)

    /* ---- 账号 ---- */
    public let loggedIn = State<Bool>(false)
    public let accountName = State<String>("")
    public let accountId = State<String>("")
    public let loginEmail = State<String>("")
    public let loginPassword = State<String>("")
    public let loginBusy = State<Bool>(false)
    public let loginMessage = State<String>("")

    /* ---- 下载 ---- */
    /** 下载目录（`%USERPROFILE%/Downloads/SelineRead`）。 */
    public let downloadDir = State<String>("")
    public let downloads = State<ArrayList<DownloadEntry>>(ArrayList<DownloadEntry>())
    public let downloading = State<Bool>(false)
    public let downloadMessage = State<String>("")

    private var client: ?ClientBox = None
    private var app: ?DesktopApp = None
    private var store: ?SelineImageStore = None

    /** URL → 已上传的纹理（UI 线程）。 */
    private let coverTextures = HashMap<String, SelineImageTexture>()
    /** URL → 后台解好的像素，等 UI 线程上传。 */
    private let decodedImages = HashMap<String, DecodedImage>()
    /** URL → 是否已有后台任务在跑（防重复下载）。 */
    private let pendingImages = HashMap<String, Bool>()
    /** 下载/解码失败的 URL：不再重试，避免每帧重复请求。 */
    private let failedCovers = HashMap<String, Bool>()
    /** 解码失败后的重试次数（缓存文件损坏时删掉重下一次）。 */
    private let decodeRetries = HashMap<String, Int64>()
    /** 验收开关：登录成功后自动下载 `id|hash`。 */
    private var autoDownloadTarget: String = ""

    /* -------------------------------------------------- 生命周期 */

    /** 初始化图片缓存目录：`%TEMP%/SelineRead`（即 `/temp/SelineRead`）。必须在建窗口之前调用。 */
    public func prepareImageStore(): Unit {
        let temp = getVariable("TEMP") ?? "."
        let root = Path(temp).join("SelineRead").toString()
        store = Some(SelineImageStore(root))
        writeDebugLog("image cache: ${root}")
        let profile = getVariable("USERPROFILE") ?? temp
        let books = Path(profile).join("Downloads").join("SelineRead").toString()
        downloadDir.value = books
    }

    /** 侧栏导航：切一级页签，并退出详情页。 */
    public func tabSelectFromRail(index: Int64): Unit {
        writeDebugLog("rail tab -> ${index}")
        detailOpen.value = false
        tab.value = index
    }

    /**
     * 阻塞式初始化：建 API 客户端 + 拉首屏。
     *
     * 必须在建窗口之前完成：窗口会记下创建它的原生线程，之后拒绝别的线程轮询；
     * 而阻塞调用会让运行时把当前线程挪走。
     */
    public func bootstrap(): Unit {
        let credential = loadSavedCredential()
        let created = try {
            ZlibClient.create(baseUrl: ZlibHost.DEFAULT_URL, credential: credential,
                seeds: [ZlibHost.DEFAULT_URL])
        } catch (failure: ZlibError) {
            error.value = "创建客户端失败：${failure.detail}"
            status.value = "离线"
            writeDebugLog("bootstrap: create client failed: ${failure.detail}")
            return
        }
        client = Some(ClientBox(created))
        if (credential.isLoggedIn) {
            loggedIn.value = true
            accountId.value = credential.userId
            accountName.value = credential.userId
            writeDebugLog("credential restored: uid=${credential.userId}")
        }
        writeDebugLog("bootstrap: site=${created.currentSiteUrl()}")
        loadPopularBlocking(created)
    }

    /** 窗口建立后挂上；之后后台结果才回得来。 */
    public func attach(app: DesktopApp): Unit {
        this.app = app
        // 恢复出来的凭证要真的打一次接口才知道还有效（改密码/风控会让旧 key 失效）
        refreshProfile()
    }

    /** 窗口关闭后释放纹理与网络客户端。 */
    public func shutdown(): Unit {
        for ((_, texture) in coverTextures) {
            try {
                texture.close()
            } catch (_: Exception) {
                ()
            }
        }
        coverTextures.clear()
        decodedImages.clear()
        pendingImages.clear()
        match (client) {
            case Some(box) =>
                try {
                    box.value.close()
                } catch (_: Exception) {
                    ()
                }
                client = None
            case None => ()
        }
    }

    /** 取窗口；未 attach 时返回 None（调用即 bug，页面里打印一次即可）。 */
    public func windowOrNone(): ?DesktopApp {
        app
    }

    /** 当前站点地址（相对封面/链接补全用）。 */
    private func currentSite(): String {
        match (this.client) {
            case Some(box) => box.value.currentSiteUrl()
            case None => ZlibHost.DEFAULT_URL
        }
    }

    /** 取窗口；未 attach 时抛异常（标题栏等必须存在的场景用）。 */
    public func window(): DesktopApp {
        match (app) {
            case Some(value) => value
            case None => throw IllegalStateException("window not attached")
        }
    }

    /* -------------------------------------------------- 热门 */

    private func loadPopularBlocking(clientValue: ZlibClient): Unit {
        loading.value = true
        try {
            let briefs = SearchApi.mostPopular(clientValue)
            popular.value = cellsFromBriefs(briefs, clientValue.currentSiteUrl())
            status.value = "热门 ${popular.value.size} 本 · ${clientValue.currentSiteUrl()}"
            error.value = ""
            writeDebugLog("popular loaded: ${popular.value.size}")
        } catch (failure: ZlibError) {
            error.value = "加载热门失败：${failure.detail}"
            status.value = "加载失败"
            writeDebugLog("popular failed: ${failure.detail}")
        } catch (failure: Exception) {
            error.value = "加载热门失败：${failure.message}"
            status.value = "加载失败"
            writeDebugLog("popular failed (unexpected): ${failure.message}")
        } finally {
            loading.value = false
        }
        // 首页第一张封面在启动期就开始下载，缩短首屏空白时间
        if (!popular.value.isEmpty()) {
            let first = popular.value[0]
            writeDebugLog("first book: id=${first.id} hash=${first.hash}")
            writeDebugLog("first cover url: ${first.cover}")
            if (!first.cover.isEmpty()) {
                let _ = imagePath(first.cover, SelineImageKind.Cover)
            }
        }
    }

    /** 重新拉热门（后台线程 + 回投 UI）。 */
    public func reloadPopular(): Unit {
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                error.value = "客户端未就绪"
                return
        }
        loading.value = true
        error.value = ""
        let _ = spawn {=>
            try {
                let briefs = SearchApi.mostPopular(clientBox.value)
                let cells = cellsFromBriefs(briefs, clientBox.value.currentSiteUrl())
                postToUi({=>
                    popular.value = cells
                    status.value = "热门 ${cells.size} 本 · ${clientBox.value.currentSiteUrl()}"
                    loading.value = false
                    error.value = ""
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    error.value = "加载热门失败：${failure.detail}"
                    loading.value = false
                })
            }
        }
    }

    /* -------------------------------------------------- 搜索 */

    /** 回车提交搜索。 */
    public func submitSearch(): Unit {
        let keyword = searchText.value.trimAscii()
        writeDebugLog("submitSearch: '${keyword}'")
        if (keyword.isEmpty()) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                error.value = "客户端未就绪"
                return
        }
        tab.value = 1
        loading.value = true
        error.value = ""
        let _ = spawn {=>
            try {
                let page = SearchApi.search(clientBox.value, keyword, limit: 20)
                let cells = cellsFromBooks(page.books, clientBox.value.currentSiteUrl())
                postToUi({=>
                    results.value = cells
                    lastKeyword.value = keyword
                    status.value = "搜索「${keyword}」：${cells.size} 本"
                    loading.value = false
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    error.value = "搜索失败：${failure.detail}"
                    loading.value = false
                })
            }
        }
    }

    /** 退出搜索态，回到热门列表。 */
    public func exitSearch(): Unit {
        lastKeyword.value = ""
        results.value.clear()
        tab.value = 0
    }

    /* -------------------------------------------------- 详情 */

    /** 打开图书详情页（二级页面）。 */
    public func openBook(cell: BookCell): Unit {
        writeDebugLog("openBook: ${cell.id} ${cell.title}")
        detailOpen.value = true
        detailTitle.value = cell.title
        detailAuthor.value = cell.author
        detailMeta.value = cell.meta
        detailCover.value = cell.cover
        detailId.value = cell.id
        detailHash.value = cell.hash
        detailFormatIndex.value = 0
        downloadMessage.value = ""
        detailDescription.value = ""
        detailFormats.value = ArrayList<BookFormat>()
        detailLoading.value = true
        detailError.value = ""
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                detailLoading.value = false
                detailError.value = "客户端未就绪"
                return
        }
        // 详情页首帧来自列表项，网络数据随后补上（不阻塞 UI）
        let id = cell.id
        let hash = cell.hash
        let _ = spawn {=>
            let payload = DetailPayload.load(clientBox.value, id, hash)
            postToUi({=> applyDetailPayload(payload) })
        }
    }

    /** 把后台详情结果写回 State（UI 线程）。 */
    private func applyDetailPayload(payload: DetailPayload): Unit {
        match (payload.info) {
            case Some(info) =>
                detailTitle.value = info.title
                var author = ""
                if (let Some(value) <- info.author) {
                    author = value
                }
                detailAuthor.value = author
                detailMeta.value = "${info.extension} · ${info.filesizeString}"
                detailDescription.value = info.description
                detailCover.value = normalizeCoverUrl(info.cover, currentSite())
                detailError.value = ""
            case None =>
                detailError.value = "加载详情失败：${payload.error}"
        }
        detailFormats.value = payload.formats
        detailLoading.value = false
    }

    /** 验收/脚本用：没有列表项时按 id + hash 直接打开详情页。 */
    public func openBookById(id: Int64, hash: String): Unit {
        openBook(BookCell(id, hash, "（加载中…）", "", "", ""))
    }

    /** 关闭详情页，回到来处。 */
    public func closeDetail(): Unit {
        detailOpen.value = false
    }

    /* -------------------------------------------------- 账号 */

    /** 用设置页填的邮箱/密码登录。 */
    public func submitLogin(): Unit {
        let email = loginEmail.value.trimAscii()
        let password = loginPassword.value
        if (email.isEmpty() || password.isEmpty()) {
            loginMessage.value = "请输入邮箱和密码"
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                loginMessage.value = "客户端未就绪"
                return
        }
        loginBusy.value = true
        loginMessage.value = ""
        let _ = spawn {=>
            let outcome = LoginOutcome.load(clientBox.value, email, password)
            postToUi({=> applyLoginOutcome(outcome) })
        }
    }

    private func applyLoginOutcome(outcome: LoginOutcome): Unit {
        loginBusy.value = false
        match (outcome.client) {
            case Some(value) =>
                // 新客户端共享旧客户端的连接池，直接替换即可
                this.client = Some(ClientBox(value))
            case None => ()
        }
        if (!outcome.ok) {
            loginMessage.value = "登录失败：${outcome.message}"
            writeDebugLog("login failed: ${outcome.message}")
            return
        }
        loggedIn.value = true
        writeDebugLog("login ok: uid=${outcome.uid} name=${outcome.name}")
        accountName.value = outcome.name
        accountId.value = outcome.uid
        loginMessage.value = "登录成功"
        loginPassword.value = ""
        match (outcome.credential) {
            case Some(credential) => saveCredential(credential)
            case None => ()
        }
        refreshProfile()
        triggerAutoDownload()
    }

    /** 验收开关：登录成功后立即下载预先指定的书。 */
    private func triggerAutoDownload(): Unit {
        if (autoDownloadTarget.isEmpty()) {
            return
        }
        let parts = autoDownloadTarget.split("|")
        autoDownloadTarget = ""
        if (parts.size < 2) {
            return
        }
        let id = Int64.tryParse(parts[0]) ?? 0
        if (id > 0) {
            downloadById(id, parts[1])
        }
    }

    /** 退出登录：删凭证、换回游客客户端。 */
    public func logout(): Unit {
        deleteCredential()
        loggedIn.value = false
        accountName.value = ""
        accountId.value = ""
        loginMessage.value = "已退出登录"
        let site = match (this.client) {
            case Some(box) => box.value.currentSiteUrl()
            case None => ZlibHost.DEFAULT_URL
        }
        match (this.client) {
            case Some(box) =>
                try {
                    box.value.close()
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
        let anonymous = try {
            ZlibClient.create(baseUrl: site, seeds: [site])
        } catch (_: ZlibError) {
            ZlibClient.create()
        }
        this.client = Some(ClientBox(anonymous))
    }

    /** 拉一次 `/user/profile`，补全昵称与下载配额。 */
    public func refreshProfile(): Unit {
        if (!loggedIn.value) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None => return
        }
        let _ = spawn {=>
            let outcome = ProfileOutcome.load(clientBox.value)
            postToUi({=> applyProfileOutcome(outcome) })
        }
    }

    private func applyProfileOutcome(outcome: ProfileOutcome): Unit {
        if (!outcome.ok) {
            // 凭证失效（改密码/风控）时提示用户重新登录，但不静默清掉本地状态
            loginMessage.value = "账号状态失效：${outcome.error}"
            return
        }
        if (!outcome.name.isEmpty()) {
            accountName.value = outcome.name
        }
        if (!outcome.uid.isEmpty()) {
            accountId.value = outcome.uid
        }
        loginMessage.value = "已登录 · ${outcome.quota}"
        writeDebugLog("profile ok: ${outcome.quota}")
    }

    /* -------------------------------------------------- 下载 */

    /** 当前详情页选中的下载版本。 */
    private func chosenTarget(): DownloadTarget {
        let index = detailFormatIndex.value
        let formats = detailFormats.value
        if (index > 0 && index <= Int64(formats.size)) {
            let format = formats[index - 1]
            return DownloadTarget(format.id, format.hash)
        }
        DownloadTarget(detailId.value, detailHash.value)
    }

    /** 验收/脚本用：直接按 id + hash 下载（会走与详情页按钮完全相同的路径）。 */
    public func downloadById(id: Int64, hash: String): Unit {
        detailId.value = id
        detailHash.value = hash
        detailFormatIndex.value = 0
        downloadBook()
    }

    /** 验收用：登录成功后自动下载指定书。 */
    public func setAutoDownload(id: Int64, hash: String): Unit {
        autoDownloadTarget = "${id}|${hash}"
    }

    /** 下载当前详情页选中的版本。 */
    public func downloadBook(): Unit {
        if (!loggedIn.value) {
            detailError.value = "下载需要登录：请到「设置」页登录"
            return
        }
        if (detailId.value <= 0 || detailHash.value.isEmpty()) {
            detailError.value = "详情还没加载完，请稍候"
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                detailError.value = "客户端未就绪"
                return
        }
        let target = chosenTarget()
        let dir = Path(downloadDir.value)
        downloading.value = true
        downloadMessage.value = ""
        let _ = spawn {=>
            let outcome = DownloadOutcome.load(clientBox.value, target, dir)
            postToUi({=> applyDownloadOutcome(outcome) })
        }
    }

    private func applyDownloadOutcome(outcome: DownloadOutcome): Unit {
        downloading.value = false
        if (!outcome.ok) {
            detailError.value = "下载失败：${outcome.message}"
            return
        }
        downloads.value.add(DownloadEntry(outcome.fileName, outcome.bytes))
        downloadMessage.value = "已下载：${outcome.fileName}（${outcome.bytes} 字节）→ ${downloadDir.value}"
        detailError.value = ""
    }

    /* -------------------------------------------------- 网络封面 */

    /**
     * 返回封面本地路径；未命中时安排后台下载+解码并返回 None。
     *
     * 缓存命中也要排一次解码：文件在磁盘上不等于有像素。
     */
    public func imagePath(url: String, kind: SelineImageKind): Option<String> {
        if (url.isEmpty()) {
            return None
        }
        let imageStore = match (this.store) {
            case Some(value) => value
            case None => return None
        }
        let cached = imageStore.fastPath(url, kind)
        if (cached.isSome()) {
            scheduleDecode(cached.getOrThrow(), url)
            return cached
        }
        scheduleImageFetch(url, kind, imageStore)
        Option<String>.None
    }

    /** 已建好的封面纹理。 */
    public func coverTexture(url: String): Option<SelineImageTexture> {
        coverTextures.get(url)
    }

    /** 取后台解好的像素（取出即删，避免长期占内存）。 */
    public func takeDecodedImage(url: String): Option<DecodedImage> {
        match (decodedImages.get(url)) {
            case Some(value) =>
                decodedImages.remove(url)
                Some(value)
            case None => None
        }
    }

    /** 记住新纹理（同时清掉下载标记）。 */
    public func rememberCoverTexture(url: String, texture: SelineImageTexture): Unit {
        coverTextures[url] = texture
        pendingImages.remove(url)
    }

    private func scheduleDecode(path: String, url: String): Unit {
        if (failedCovers.contains(url) || pendingImages.contains(url) ||
            decodedImages.contains(url) || coverTextures.contains(url)) {
            return
        }
        pendingImages[url] = true
        let _ = spawn {=>
            let decoded = decodeImageFile(path)
            postToUi({=>
                match (decoded) {
                    case Some(image) =>
                        decodedImages[url] = image
                        pendingImages.remove(url)
                        ()
                    case None =>
                        pendingImages.remove(url)
                        let retries = match (decodeRetries.get(url)) {
                            case Some(value) => value
                            case None => 0
                        }
                        if (retries < 1) {
                            decodeRetries[url] = retries + 1
                            // 缓存文件可能损坏（上次下载中断）：删掉重新下一次
                            try {
                                remove(Path(path))
                            } catch (_: Exception) {
                                ()
                            }
                            match (this.store) {
                                case Some(storeValue) =>
                                    scheduleImageFetch(url, SelineImageKind.Cover, storeValue)
                                case None => ()
                            }
                        } else {
                            failedCovers[url] = true
                        }
                }
            })
        }
    }

    private func scheduleImageFetch(url: String, kind: SelineImageKind,
        imageStore: SelineImageStore): Unit {
        if (failedCovers.contains(url) || pendingImages.contains(url)) {
            return
        }
        // 首页一次会画出很多封面；同时压太多 HTTPS 请求会拖慢整体
        // （底层 TLS 在部分环境下还不稳定），限制并发、后面的帧再补。
        if (pendingImages.size >= 6) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None => return
        }
        pendingImages[url] = true
        let _ = spawn {=>
            let result = imageStore.fetchDecoded(url, kind, {link =>
                try {
                    Some(clientBox.value.fetchBytes(link))
                } catch (_: ZlibError) {
                    Option<Array<Byte>>.None
                }
            })
            postToUi({=>
                match (result) {
                    case Some(image) =>
                        decodedImages[url] = image
                        pendingImages.remove(url)
                        ()
                    case None =>
                        pendingImages.remove(url)
                        failedCovers[url] = true
                        ()
                }
            })
        }
    }

    /* -------------------------------------------------- UI 线程投递 */

    /** 把一段状态更新投递到 UI 线程执行（窗口未建好时丢弃）。 */
    private func postToUi(action: () -> Unit): Unit {
        match (app) {
            case Some(value) =>
                let _ = value.postToUi(action)
            case None => ()
        }
    }
}
