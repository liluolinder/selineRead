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
import std.sync.*
import std.time.*
import std.fs.{Directory, File, Path, exists, remove}
import chui.*
import seline_ui.*
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.search.*
import zlibraryAPI4CJ.book.*
import zlibraryAPI4CJ.login.*
import zlibraryAPI4CJ.user.*
import zlibraryAPI4CJ.booklist.*
import zlibraryAPI4CJ.comment.*

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

/** 书单卡片（ViewModel）：书单元信息 + 预览封面。 */
public class BooklistCell {
    public let id: Int64
    public let title: String
    public let author: String
    public let description: String
    public let booksCount: Int64
    public let viewsCount: Int64
    public let favoritesCount: Int64
    public let covers: ArrayList<String>

    public init(id: Int64, title: String, author: String, description: String,
        booksCount: Int64, viewsCount: Int64, favoritesCount: Int64,
        covers: ArrayList<String>) {
        this.id = id
        this.title = title
        this.author = author
        this.description = description
        this.booksCount = booksCount
        this.viewsCount = viewsCount
        this.favoritesCount = favoritesCount
        this.covers = covers
    }
}

/** 把 papi 书单页归一化成卡片；封面优先用 `coverUrl`，否则补站点前缀。 */
func booklistCells(page: BooklistPage, siteUrl: String): ArrayList<BooklistCell> {
    let cells = ArrayList<BooklistCell>()
    for (readlist in page.readlists) {
        let covers = ArrayList<String>()
        match (page.previewOf(readlist.id)) {
            case Some(previews) =>
                for (preview in previews) {
                    let url = if (!preview.coverUrl.isEmpty()) {
                        preview.coverUrl
                    } else {
                        normalizeCoverUrl(preview.cover, siteUrl)
                    }
                    if (!url.isEmpty()) {
                        covers.add(url)
                    }
                }
            case None => ()
        }
        cells.add(BooklistCell(readlist.id, readlist.title, readlist.ownerName(page),
            readlist.description, readlist.booksCount, readlist.viewsCount,
            readlist.favoritesCount, covers))
    }
    cells
}

/** 书单列表后台结果。 */
class BooklistsPayload {
    let page: ?BooklistPage
    let error: String

    init(page: ?BooklistPage, error: String) {
        this.page = page
        this.error = error
    }

    static func load(client: ZlibClient, page: Int64, searchQuery: String): BooklistsPayload {
        try {
            BooklistsPayload(Some(BooklistApi.list(client, page: page,
                searchQuery: searchQuery)), "")
        } catch (failure: ZlibError) {
            BooklistsPayload(Option<BooklistPage>.None, failure.detail)
        }
    }

    static func loadMine(client: ZlibClient, page: Int64): BooklistsPayload {
        try {
            BooklistsPayload(Some(BooklistApi.my(client, page: page)), "")
        } catch (failure: ZlibError) {
            BooklistsPayload(Option<BooklistPage>.None, failure.detail)
        }
    }
}

/** 书单内的书后台结果。 */
class BooklistBooksPayload {
    let cells: ArrayList<BookCell>
    let totalPages: Int64
    let totalItems: Int64
    let error: String

    init(cells: ArrayList<BookCell>, totalPages: Int64, totalItems: Int64, error: String) {
        this.cells = cells
        this.totalPages = totalPages
        this.totalItems = totalItems
        this.error = error
    }

    static func load(client: ZlibClient, readlistId: Int64, page: Int64,
        siteUrl: String): BooklistBooksPayload {
        try {
            let result = BooklistApi.books(client, readlistId, page: page)
            BooklistBooksPayload(cellsFromBooks(result.books, siteUrl),
                result.totalPages, result.totalItems, "")
        } catch (failure: ZlibError) {
            BooklistBooksPayload(ArrayList<BookCell>(), 0, 0, failure.detail)
        }
    }
}

/** 详情页的一条评论（ViewModel）。 */
public class CommentCell {
    public let id: Int64
    public let parentId: Int64
    public let author: String
    public let dateRelative: String
    public let text: String
    public let likes: Int64
    public let liked: Bool
    public let isReply: Bool
    /** 被回复那条评论的作者 / 正文（父评论不在已加载范围时为空）。 */
    public var parentAuthor: String
    public var parentText: String

    public init(id: Int64, parentId: Int64, author: String, dateRelative: String,
        text: String, likes: Int64, liked: Bool, isReply: Bool,
        parentAuthor!: String = "", parentText!: String = "") {
        this.id = id
        this.parentId = parentId
        this.author = author
        this.dateRelative = dateRelative
        this.text = text
        this.likes = likes
        this.liked = liked
        this.isReply = isReply
        this.parentAuthor = parentAuthor
        this.parentText = parentText
    }
}

/** 评论后台结果。 */
class CommentsPayload {
    let cells: ArrayList<CommentCell>
    let disabled: Bool
    let nextOffset: Int64
    let error: String

    init(cells: ArrayList<CommentCell>, disabled: Bool, nextOffset: Int64, error: String) {
        this.cells = cells
        this.disabled = disabled
        this.nextOffset = nextOffset
        this.error = error
    }

    static func load(client: ZlibClient, bookId: Int64, offset: Int64): CommentsPayload {
        try {
            let page = CommentApi.book(client, bookId, offset: offset)
            let cells = ArrayList<CommentCell>()
            // 先建立 id -> (作者, 正文) 索引，好让「回复」能显示被回复的原评论
            let index = HashMap<Int64, (String, String)>()
            for (comment in page.comments) {
                let author = if (comment.user.name.isEmpty()) { "读者" } else {
                    comment.user.name
                }
                index[comment.id] = (author, comment.text)
            }
            for (comment in page.comments) {
                let author = if (comment.user.name.isEmpty()) { "读者" } else {
                    comment.user.name
                }
                var parentAuthor = ""
                var parentText = ""
                if (comment.parentId != 0) {
                    match (index.get(comment.parentId)) {
                        case Some(value) =>
                            parentAuthor = value[0]
                            parentText = value[1]
                        case None => ()
                    }
                }
                cells.add(CommentCell(comment.id, comment.parentId, author,
                    comment.dateRelative, comment.text, comment.likes, comment.liked,
                    comment.parentId != 0, parentAuthor: parentAuthor,
                    parentText: parentText))
            }
            // 本页满 100 条才可能还有下一段；服务端忽略 limit、固定最多 100
            let next = if (page.comments.size >= 100) {
                page.nextOffset(offset)
            } else {
                0
            }
            writeDebugLog("comments loaded: offset=${offset} count=${cells.size} disabled=${page.commentsDisabled}")
            CommentsPayload(cells, page.commentsDisabled, next, "")
        } catch (failure: ZlibError) {
            writeDebugLog("comments failed: ${failure.detail}")
            CommentsPayload(ArrayList<CommentCell>(), false, 0, failure.detail)
        }
    }
}

/** 下载按钮的位置（菜单弹出锚点）。普通可变对象：每帧由按钮 layout 写入，不需要触发重建。 */
public class DownloadMenuAnchor {
    public var x: Float32 = 0.0
    public var y: Float32 = 0.0
    public var w: Float32 = 0.0
    public var h: Float32 = 0.0

    public init() {}
}

/** 详情页快照：从详情页再进一本书时压栈，返回时恢复。 */
class DetailSnapshot {
    let id: Int64
    let hash: String
    let title: String
    let author: String
    let meta: String
    let cover: String
    let description: String
    let formats: ArrayList<BookFormat>
    let section: Int64
    let year: String
    let publisher: String
    let identifier: String
    let language: String
    let pages: String
    let edition: String
    let series: String
    let extension: String
    let filesize: String
    let scroll: Float32

    init(state: AppState) {
        this.id = state.detailId.value
        this.hash = state.detailHash.value
        this.title = state.detailTitle.value
        this.author = state.detailAuthor.value
        this.meta = state.detailMeta.value
        this.cover = state.detailCover.value
        this.description = state.detailDescription.value
        this.formats = state.detailFormats.value
        this.section = state.detailSection.value
        this.year = state.detailYear.value
        this.publisher = state.detailPublisher.value
        this.identifier = state.detailIdentifier.value
        this.language = state.detailLanguage.value
        this.pages = state.detailPages.value
        this.edition = state.detailEdition.value
        this.series = state.detailSeries.value
        this.extension = state.detailExtension.value
        this.filesize = state.detailFilesize.value
        this.scroll = state.detailScroll.value
    }
}

/** 图片后台任务：下载+解码，或只解码本地缓存。 */
enum ImageJobKind {
    | FetchAndDecode
    | DecodeCached
}

/** 一条图片后台任务（worker 池消费，避免每张图 spawn 一个线程）。 */
class ImageJob {
    let kind: ImageJobKind
    let url: String
    let path: String
    let imageKind: SelineImageKind

    init(kind: ImageJobKind, url: String, path: String, imageKind: SelineImageKind) {
        this.kind = kind
        this.url = url
        this.path = path
        this.imageKind = imageKind
    }
}

/** 图片 worker 数量与同时下载上限。 */
let IMAGE_WORKERS: Int64 = 3
let IMAGE_FETCH_LIMIT: Int64 = 4

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
    /** 验收用：强制显示骨架（截图/回归用）。 */
    public let forceSkeleton = State<Bool>(false)
    /** 各页面的滚动位置（切页/返回后保持原位）。 */
    public let homeScroll = State<Float32>(0.0)
    public let searchScroll = State<Float32>(0.0)
    public let favoritesScroll = State<Float32>(0.0)
    public let booklistsScroll = State<Float32>(0.0)
    public let booklistDetailScroll = State<Float32>(0.0)
    public let detailScroll = State<Float32>(0.0)
    /** 详情页返回栈：从「相关书籍」再点进另一本时，返回能回到上一本。 */
    private let detailHistory = ArrayList<DetailSnapshot>()
    /** 深色模式（false = 浅色）。 */
    public let darkMode = State<Bool>(true)
    /** 主题切换的辐射动画：进度 0..1；active 为 true 时在根上盖一层圆形遮罩。 */
    public let themeReveal = State<Float32>(0.0)
    public let themeRevealing = State<Bool>(false)
    private var themeRevealX: Float32 = 0.0
    private var themeRevealY: Float32 = 0.0
    /** 热门列表。 */
    public let popular = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    /** 首屏只渲染这么多张卡片，滚到底再追加（避免一次重绘 100 张卡）。 */
    public let popularVisible = State<Int64>(12)
    /** 搜索结果。 */
    public let results = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    /** 最近一次搜索关键词；空串表示「没在搜索态」。 */
    public let lastKeyword = State<String>("")
    /** 搜索请求序号：只接受最后一次搜索的返回，A/B 竞态时丢弃过期的 A。 */
    private var searchGeneration: Int64 = 0
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
    /** 详情页分段：0 书籍信息 / 1 书籍评论 / 2 相关书籍。 */
    public let detailSection = State<Int64>(0)
    /** 书籍信息（两列展示）。 */
    public let detailYear = State<String>("")
    public let detailPublisher = State<String>("")
    public let detailIdentifier = State<String>("")
    public let detailLanguage = State<String>("")
    public let detailPages = State<String>("")
    public let detailEdition = State<String>("")
    public let detailSeries = State<String>("")
    public let detailExtension = State<String>("")
    public let detailFilesize = State<String>("")
    /** 简介滚动区的偏移（固定高度、自己处理滚轮）。 */
    public let detailDescriptionOffset = State<Float32>(0.0)
    /** 简介按宽度折行的缓存（key = 宽度|文本）。 */
    private let wrappedDescriptionCache = HashMap<String, ArrayList<String>>()
    /** 相关书籍（BookApi.similar）。 */
    public let detailRelated = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    public let detailRelatedLoading = State<Bool>(false)
    public let detailRelatedError = State<String>("")
    private var detailRelatedLoaded = false

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
    /** 下载按钮弹出的「版本选择」菜单是否打开。 */
    public let downloadMenuOpen = State<Bool>(false)
    /** 菜单正在收起（播完反向动画再卸载）。 */
    public let downloadMenuClosing = State<Bool>(false)
    /** 下载按钮在窗口里的矩形（由按钮每帧 layout 写入）。 */
    public let downloadAnchor = DownloadMenuAnchor()
    /** 打开菜单时锁定的锚点（滚动/布局变化时菜单不跟着动，避免反复缩放）。 */
    private var menuAnchorX: Float32 = 0.0
    private var menuAnchorY: Float32 = 0.0

    /* ---- 书单（papi） ---- */
    /** 书单列表。 */
    public let booklists = State<ArrayList<BooklistCell>>(ArrayList<BooklistCell>())
    public let booklistsLoading = State<Bool>(false)
    public let booklistsError = State<String>("")
    /** 书单搜索关键词（标题栏搜索框在「书单」页签时用它）。 */
    public let booklistQuery = State<String>("")
    /** 下一页页码；0 表示没有更多。 */
    public let booklistsNextPage = State<Int64>(0)
    /** 是否看「我的书单」（需要登录）。 */
    public let booklistsMine = State<Bool>(false)
    /** 是否停在书单详情（二级页面）。 */
    public let booklistOpen = State<Bool>(false)
    public let booklistId = State<Int64>(0)
    public let booklistTitle = State<String>("")
    public let booklistAuthor = State<String>("")
    public let booklistDescription = State<String>("")
    public let booklistBooks = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    public let booklistLoading = State<Bool>(false)
    public let booklistError = State<String>("")
    public let booklistNextPage = State<Int64>(1)
    public let booklistTotal = State<Int64>(0)

    /* ---- 详情页评论 ---- */
    public let comments = State<ArrayList<CommentCell>>(ArrayList<CommentCell>())
    public let commentsLoading = State<Bool>(false)
    public let commentsError = State<String>("")
    public let commentsDisabled = State<Bool>(false)
    /** 下一段评论的 offset；0 表示没有更多。 */
    public let commentsNextOffset = State<Int64>(0)
    /** 评论是否已经发起过加载（懒加载：滚到评论区才请求）。 */
    private var commentsLoaded: Bool = false
    /** 当前渲染多少条评论，超出时「显示更多」再追加。 */
    public let commentsVisible = State<Int64>(20)
    /** 已加载评论的 id -> 单元格索引（跨页解析「回复」的原评论）。 */
    private let commentIndex = HashMap<Int64, CommentCell>()

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
    /** 图片后台队列 + 固定 worker（替代「每张图 spawn 一个线程」）。 */
    private let imageQueue = ArrayList<ImageJob>()
    private let imageQueueLock = Mutex()
    private var imageWorkersStarted = false
    private var imageWorkersStopped = false
    /** 正在下载的图片数（仅 UI 线程读写）。 */
    private var activeFetches: Int64 = 0
    /** 应用图标资源路径（标题栏与窗口图标用）。 */
    private var iconAsset: String = ""
    /** 默认封面图资源路径（图片占位用）。 */
    private var placeholderAsset: String = ""
    private var placeholderDecoded: ?DecodedImage = None
    private var placeholderTexture: ?SelineImageTexture = None
    /** 验收开关：登录成功后自动下载 `id|hash`。 */
    private var autoDownloadTarget: String = ""
    /** 书单列表是否已成功加载过（构建期懒加载用）。 */
    private var booklistsLoaded: Bool = false
    /** 书单请求序号：书单搜索 A/B 竞态时只接受最后一次。 */
    private var booklistsGeneration: Int64 = 0

    /* ---- 收藏（eapi /user/book/saved） ---- */
    public let favorites = State<ArrayList<BookCell>>(ArrayList<BookCell>())
    public let favoritesLoading = State<Bool>(false)
    public let favoritesError = State<String>("")
    /** 下一页页码；0 表示没有更多（或未登录）。 */
    public let favoritesNextPage = State<Int64>(0)
    private var favoritesLoaded: Bool = false
    /** 验收开关：书单第一次加载成功后自动打开第一份。 */
    private var autoOpenFirstBooklist: Bool = false

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
        // 随 exe 分发的资源：应用图标 / 默认封面
        iconAsset = findAsset("zlib.png")
        placeholderAsset = findAsset("default_cover.png")
        writeDebugLog("assets: icon=${iconAsset} placeholder=${placeholderAsset}")
    }

    /** 应用图标路径（空串表示没有）。 */
    public func iconPath(): String {
        iconAsset
    }


    /** 文本按宽截断缓存：同一文本/字号/宽度只测量一次。 */
    private let fittedTextCache = HashMap<String, String>()

    /** 按可用宽度截断文本（带缓存，避免每帧对每张卡片重复测量）。 */
    public func fittedText(ctx: UiContext, text: String, maxWidth: Float32,
        pointSize: Float32, bold: Bool, family: String): String {
        let key = "${Int64(maxWidth)}|${pointSize}|${bold}|${text}"
        match (fittedTextCache.get(key)) {
            case Some(value) => return value
            case None => ()
        }
        let fitted = fitTextWidth(ctx, text, maxWidth, pointSize,
            selineFontStyle(bold: bold), family)
        fittedTextCache[key] = fitted
        fitted
    }

    /** 默认封面纹理（懒加载，UI 线程 draw 时创建一次）。 */
    public func placeholderCoverTexture(ctx: UiContext): ?SelineImageTexture {
        match (placeholderTexture) {
            case Some(value) => return Some(value)
            case None => ()
        }
        if (placeholderDecoded.isNone() && !placeholderAsset.isEmpty()) {
            placeholderDecoded = decodeImageFile(placeholderAsset)
        }
        match (placeholderDecoded) {
            case Some(image) =>
                let texture = SelineImageTexture(ctx.renderer, image)
                placeholderTexture = Some(texture)
                Some(texture)
            case None => None
        }
    }

    /** 侧栏导航：切一级页签，并退出详情页。 */
    public func tabSelectFromRail(index: Int64): Unit {
        writeDebugLog("rail tab -> ${index}")
        detailOpen.value = false
        booklistOpen.value = false
        downloadMenuOpen.value = false
        detailHistory.clear()
        // 点「热门」= 退出搜索态，回到推荐墙
        if (index == TAB_HOME && !lastKeyword.value.isEmpty()) {
            searchGeneration += 1
            lastKeyword.value = ""
            results.value = ArrayList<BookCell>()
        }
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
        // 离线模式（UI 截图/开发用）：跳过阻塞式首屏请求
        if ((getVariable("SELINE_READ_OFFLINE") ?? "") == "1") {
            writeDebugLog("bootstrap: offline mode, skip popular")
            status.value = "离线模式"
            return
        }
        loadPopularBlocking(created)
    }

    /** 窗口建立后挂上；之后后台结果才回得来。 */
    public func attach(app: DesktopApp): Unit {
        this.app = app
        if ((getVariable("SELINE_READ_OFFLINE") ?? "") == "1") {
            return
        }
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
        synchronized(imageQueueLock) {
            imageWorkersStopped = true
        }
        coverTextures.clear()
        decodedImages.clear()
        pendingImages.clear()
        match (placeholderTexture) {
            case Some(texture) =>
                try {
                    texture.close()
                } catch (_: Exception) {
                    ()
                }
                placeholderTexture = None
            case None => ()
        }
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
            popularVisible.value = 12
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
                    popularVisible.value = 12
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
        // 「书单」页签下，标题栏搜索框搜的是书单，不是书
        if (tab.value == TAB_BOOKLISTS) {
            booklistQuery.value = keyword
            booklistsLoaded = false
            booklistsError.value = ""
            booklists.value = ArrayList<BooklistCell>()
            booklistsNextPage.value = 0
            loadBooklists()
            return
        }
        searchGeneration += 1
        if (keyword.isEmpty()) {
            lastKeyword.value = ""
            results.value = ArrayList<BookCell>()
            tab.value = TAB_HOME
            return
        }
        let generation = searchGeneration
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                error.value = "客户端未就绪"
                return
        }
        // 搜索不再是独立页签：结果显示在「热门」页签里
        detailOpen.value = false
        booklistOpen.value = false
        tab.value = TAB_HOME
        lastKeyword.value = keyword
        results.value = ArrayList<BookCell>()
        loading.value = true
        error.value = ""
        let _ = spawn {=>
            try {
                let page = SearchApi.search(clientBox.value, keyword, limit: 20)
                let cells = cellsFromBooks(page.books, clientBox.value.currentSiteUrl())
                postToUi({=>
                    // 期间又搜了别的词：这次结果已经过期，直接丢弃
                    if (generation != searchGeneration) {
                        writeDebugLog("drop stale search result: ${keyword}")
                        return
                    }
                    results.value = cells
                    lastKeyword.value = keyword
                    status.value = "搜索「${keyword}」：${cells.size} 本"
                    loading.value = false
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    if (generation != searchGeneration) {
                        writeDebugLog("drop stale search error: ${keyword}")
                        return
                    }
                    error.value = "搜索失败：${failure.detail}"
                    loading.value = false
                })
            }
        }
    }

    /** 首页「继续向下滚动」：每次多揭示 24 张卡片（渲染量有上限）。 */
    public func showMorePopular(): Unit {
        let total = Int64(popular.value.size)
        if (popularVisible.value >= total) {
            return
        }
        let next = popularVisible.value + 24
        popularVisible.value = if (next > total) { total } else { next }
    }

    /**
     * 标题栏搜索框内容变化：清空时退出搜索态。
     *
     * - 书单页签：清空书单搜索词，重新加载公开书单（留在书单页）；
     * - 其他页签：回到热门墙；
     * - 详情/书单详情内清空输入框不跳页。
     */
    public func onSearchTextChanged(text: String): Unit {
        if (!text.trimAscii().isEmpty()) {
            return
        }
        if (detailOpen.value || booklistOpen.value) {
            return
        }
        if (tab.value == TAB_BOOKLISTS) {
            if (!booklistQuery.value.isEmpty()) {
                booklistQuery.value = ""
                booklistsLoaded = false
                booklists.value = ArrayList<BooklistCell>()
                booklistsNextPage.value = 0
                loadBooklists()
            }
            return
        }
        if (!lastKeyword.value.isEmpty()) {
            searchGeneration += 1
            lastKeyword.value = ""
            results.value = ArrayList<BookCell>()
            tab.value = TAB_HOME
        }
    }

    /** 验收用：延迟 delayMs 后打开「相关书籍」里的第一本（验证详情返回栈）。 */
    public func scheduleOpenFirstRelatedForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=>
                if (!detailRelated.value.isEmpty()) {
                    writeDebugLog("test: open related ${detailRelated.value[0].id}")
                    openBook(detailRelated.value[0])
                }
            })
        }
    }

    /** 验收用：延迟 delayMs 后点「返回」。 */
    public func scheduleCloseDetailForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=>
                writeDebugLog("test: closeDetail (history=${detailHistory.size})")
                closeDetail()
            })
        }
    }

    /** 验收用：延迟 delayMs 后清空搜索框，验证「清空即回热门」。 */
    public func scheduleClearSearchForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=>
                searchText.value = ""
                onSearchTextChanged("")
            })
        }
    }

    /** 验收用：延迟 delayMs 后自动搜索一次（模拟「A 未返回时又搜 B」的竞态）。 */
    public func scheduleSearchForTest(keyword: String, delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=>
                searchText.value = keyword
                submitSearch()
            })
        }
    }

    /** 退出搜索态，回到热门列表。 */
    public func exitSearch(): Unit {
        searchGeneration += 1
        lastKeyword.value = ""
        results.value.clear()
        tab.value = TAB_HOME
    }

    /* -------------------------------------------------- 详情 */

    /** 打开图书详情页（二级页面）。 */
    public func openBook(cell: BookCell): Unit {
        writeDebugLog("openBook: ${cell.id} ${cell.title}")
        // 已经在详情页（从「相关书籍」点进来）：把上一本压栈，返回可回退
        if (detailOpen.value && detailId.value > 0) {
            detailHistory.add(DetailSnapshot(this))
        }
        detailScroll.value = 0.0
        detailOpen.value = true
        detailTitle.value = cell.title
        detailAuthor.value = cell.author
        detailMeta.value = cell.meta
        detailCover.value = cell.cover
        detailId.value = cell.id
        detailHash.value = cell.hash
        detailFormatIndex.value = 0
        downloadMessage.value = ""
        comments.value = ArrayList<CommentCell>()
        commentsError.value = ""
        commentsDisabled.value = false
        commentsNextOffset.value = 0
        commentsVisible.value = 20
        commentsLoaded = false
        commentIndex.clear()
        // 不在打开详情时立刻拉评论：切到「书籍评论」分段时才加载
        detailDescription.value = ""
        detailFormats.value = ArrayList<BookFormat>()
        detailSection.value = 0
        detailRelated.value = ArrayList<BookCell>()
        detailRelatedError.value = ""
        detailRelatedLoaded = false
        detailYear.value = ""
        detailPublisher.value = ""
        detailIdentifier.value = ""
        detailLanguage.value = ""
        detailPages.value = ""
        detailEdition.value = ""
        detailSeries.value = ""
        detailExtension.value = ""
        detailFilesize.value = ""
        detailDescriptionOffset.value = 0.0
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
                detailYear.value = if (info.year > 0) { info.year.toString() } else { "" }
                detailPublisher.value = match (info.publisher) {
                    case Some(value) => value
                    case None => ""
                }
                detailIdentifier.value = match (info.identifier) {
                    case Some(value) => value
                    case None => ""
                }
                detailLanguage.value = info.language
                detailPages.value = if (info.pages > 0) { info.pages.toString() } else { "" }
                detailEdition.value = match (info.edition) {
                    case Some(value) => value
                    case None => ""
                }
                detailSeries.value = info.series
                detailExtension.value = info.extension
                detailFilesize.value = info.filesizeString
                detailCover.value = normalizeCoverUrl(info.cover, currentSite())
                detailError.value = ""
            case None =>
                detailError.value = "加载详情失败：${payload.error}"
        }
        detailFormats.value = payload.formats
        detailLoading.value = false
    }

    /** 详情页分段切换：评论/相关书籍第一次点开才加载。 */
    public func selectDetailSection(index: Int64): Unit {
        if (index < 0 || index > 2 || index == detailSection.value) {
            return
        }
        detailSection.value = index
        if (index == 1) {
            ensureCommentsLoaded()
        }
        if (index == 2) {
            ensureRelatedLoaded()
        }
    }

    /** 相关书籍懒加载：第一次进入「相关书籍」分段才请求。 */
    public func ensureRelatedLoaded(): Unit {
        if (detailRelatedLoaded || detailRelatedLoading.value || !detailRelatedError.value.isEmpty()) {
            return
        }
        loadRelated()
    }

    /** 按可用宽度把简介折行（缓存，避免每帧重新测量）。 */
    public func wrappedDescriptionLines(ctx: UiContext, text: String,
        width: Float32): ArrayList<String> {
        let key = "${Int64(width)}|${text}"
        match (wrappedDescriptionCache.get(key)) {
            case Some(value) => return value
            case None => ()
        }
        let lines = wrapTextByWidth(ctx, text, max(80.0, width),
            selineTheme().fontBody, selineTheme().fontFamily)
        wrappedDescriptionCache[key] = lines
        lines
    }

    /** 「重新加载」按钮：清掉错误后重试。 */
    public func reloadRelated(): Unit {
        detailRelatedError.value = ""
        detailRelatedLoaded = false
        detailRelatedLoading.value = false
        loadRelated()
    }

    private func loadRelated(): Unit {
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                detailRelatedError.value = "客户端未就绪"
                return
        }
        let id = detailId.value
        let hash = detailHash.value
        if (id <= 0 || hash.isEmpty()) {
            return
        }
        detailRelatedLoading.value = true
        detailRelatedError.value = ""
        let _ = spawn {=>
            try {
                let briefs = BookApi.similar(clientBox.value, id, hash)
                let cells = cellsFromBriefs(briefs, clientBox.value.currentSiteUrl())
                postToUi({=>
                    if (detailId.value != id) {
                        return
                    }
                    detailRelated.value = cells
                    detailRelatedLoaded = true
                    detailRelatedLoading.value = false
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    if (detailId.value != id) {
                        return
                    }
                    detailRelatedError.value = "相关书籍加载失败：${failure.detail}"
                    detailRelatedLoading.value = false
                })
            }
        }
    }

    /** 验收/脚本用：没有列表项时按 id + hash 直接打开详情页。 */
    public func openBookById(id: Int64, hash: String): Unit {
        openBook(BookCell(id, hash, "（加载中…）", "", "", ""))
    }

    /** 关闭详情页，回到来处。 */
    public func closeDetail(): Unit {
        downloadMenuOpen.value = false
        if (!detailHistory.isEmpty()) {
            let previous = detailHistory[detailHistory.size - 1]
            detailHistory.remove(at: detailHistory.size - 1)
            restoreDetail(previous)
            return
        }
        detailOpen.value = false
    }

    /** 恢复上一本详情（不重新请求；评论按需重新加载）。 */
    private func restoreDetail(snapshot: DetailSnapshot): Unit {
        detailId.value = snapshot.id
        detailHash.value = snapshot.hash
        detailTitle.value = snapshot.title
        detailAuthor.value = snapshot.author
        detailMeta.value = snapshot.meta
        detailCover.value = snapshot.cover
        detailDescription.value = snapshot.description
        detailFormats.value = snapshot.formats
        detailExtension.value = snapshot.extension
        detailFilesize.value = snapshot.filesize
        detailYear.value = snapshot.year
        detailPublisher.value = snapshot.publisher
        detailIdentifier.value = snapshot.identifier
        detailLanguage.value = snapshot.language
        detailPages.value = snapshot.pages
        detailEdition.value = snapshot.edition
        detailSeries.value = snapshot.series
        detailSection.value = snapshot.section
        detailScroll.value = snapshot.scroll
        detailLoading.value = false
        detailError.value = ""
        detailRelated.value = ArrayList<BookCell>()
        detailRelatedError.value = ""
        detailRelatedLoaded = false
        comments.value = ArrayList<CommentCell>()
        commentsError.value = ""
        commentsNextOffset.value = 0
        commentsVisible.value = 20
        commentsLoaded = false
        commentIndex.clear()
        if (snapshot.section == 1) {
            ensureCommentsLoaded()
        } else if (snapshot.section == 2) {
            ensureRelatedLoaded()
        }
        writeDebugLog("detail back: ${snapshot.id} ${snapshot.title}")
    }

    /* -------------------------------------------------- 书单 */

    /** 构建期懒加载：第一次进入「书单」页签时拉一次列表。 */
    public func ensureBooklistsLoaded(): Unit {
        if (booklistsLoaded || booklistsLoading.value || !booklistsError.value.isEmpty()) {
            return
        }
        loadBooklists()
    }

    /** 验收用：书单列表第一次加载成功后自动打开第一份。 */
    public func setAutoOpenFirstBooklist(): Unit {
        autoOpenFirstBooklist = true
    }

    /** 刷新/搜索公开书单。 */
    public func loadBooklists(reset!: Bool = true): Unit {
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                booklistsError.value = "客户端未就绪"
                return
        }
        let targetPage = if (reset) { 1 } else { booklistsNextPage.value }
        if (targetPage <= 0) {
            return
        }
        let query = booklistQuery.value
        let mine = booklistsMine.value
        booklistsGeneration += 1
        let generation = booklistsGeneration
        booklistsLoading.value = true
        booklistsError.value = ""
        let _ = spawn {=>
            let payload = if (mine) {
                BooklistsPayload.loadMine(clientBox.value, targetPage)
            } else {
                BooklistsPayload.load(clientBox.value, targetPage, query)
            }
            postToUi({=>
                if (generation != booklistsGeneration) {
                    writeDebugLog("drop stale booklists result: page=${targetPage}")
                    return
                }
                applyBooklists(payload, reset)
            })
        }
    }

    /** 切换「公开书单 / 我的书单」。 */
    public func setBooklistsMine(value: Bool): Unit {
        if (booklistsMine.value == value) {
            return
        }
        booklistsMine.value = value
        booklistsLoaded = false
        booklists.value = ArrayList<BooklistCell>()
        booklistsNextPage.value = 0
        booklistsError.value = ""
        loadBooklists()
    }

    private func applyBooklists(payload: BooklistsPayload, reset: Bool): Unit {
        booklistsLoading.value = false
        match (payload.page) {
            case Some(page) =>
                let cells = booklistCells(page, currentSite())
                if (reset) {
                    booklists.value = cells
                } else {
                    for (cell in cells) {
                        booklists.value.add(cell)
                    }
                }
                booklistsNextPage.value = page.nextPage
                booklistsError.value = ""
                booklistsLoaded = true
            case None =>
                booklistsError.value = "加载书单失败：${payload.error}"
        }
        if (autoOpenFirstBooklist && !booklists.value.isEmpty()) {
            autoOpenFirstBooklist = false
            openBooklist(booklists.value[0])
        }
    }

    /** 打开一份书单（二级页面）。 */
    public func openBooklist(cell: BooklistCell): Unit {
        booklistOpen.value = true
        booklistId.value = cell.id
        booklistTitle.value = cell.title
        booklistAuthor.value = cell.author
        booklistDescription.value = cell.description
        booklistBooks.value = ArrayList<BookCell>()
        booklistTotal.value = 0
        booklistNextPage.value = 1
        booklistError.value = ""
        loadBooklistBooks(1)
    }

    /** 关闭书单详情。 */
    public func closeBooklist(): Unit {
        booklistOpen.value = false
    }

    /** 加载书单里的某一页书。 */
    public func loadBooklistBooks(page: Int64): Unit {
        let readlistId = booklistId.value
        if (readlistId <= 0) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                booklistError.value = "客户端未就绪"
                return
        }
        let site = currentSite()
        booklistLoading.value = true
        let _ = spawn {=>
            let payload = BooklistBooksPayload.load(clientBox.value, readlistId, page, site)
            postToUi({=> applyBooklistBooks(payload, page) })
        }
    }

    private func applyBooklistBooks(payload: BooklistBooksPayload, page: Int64): Unit {
        booklistLoading.value = false
        if (!payload.error.isEmpty()) {
            booklistError.value = "加载书单内容失败：${payload.error}"
            return
        }
        if (page <= 1) {
            booklistBooks.value = payload.cells
        } else {
            for (cell in payload.cells) {
                booklistBooks.value.add(cell)
            }
        }
        booklistTotal.value = payload.totalItems
        booklistNextPage.value = if (page < payload.totalPages) { page + 1 } else { 0 }
    }

    /** 继续加载书单里的书（滚到底时调用）。 */
    public func loadMoreBooklistBooks(): Unit {
        let next = booklistNextPage.value
        if (next > 0 && !booklistLoading.value) {
            loadBooklistBooks(next)
        }
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
        favoritesLoaded = false
        favorites.value = ArrayList<BookCell>()
        favoritesNextPage.value = 0
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
        favoritesLoaded = false
        favorites.value = ArrayList<BookCell>()
        favoritesNextPage.value = 0
        favoritesError.value = ""
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

    /* -------------------------------------------------- 主题 */

    /** 从某个点（侧栏按钮）开始「往外辐射」地切换深浅色。 */
    public func toggleTheme(originX: Float32, originY: Float32): Unit {
        if (themeRevealing.value) {
            return
        }
        themeRevealX = originX
        themeRevealY = originY
        themeReveal.value = 0.0
        themeRevealing.value = true
        writeDebugLog("theme: reveal start -> dark=${!darkMode.value}")
    }

    public func themeRevealOriginX(): Float32 {
        themeRevealX
    }

    public func themeRevealOriginY(): Float32 {
        themeRevealY
    }

    /** 验收用：从侧栏主题按钮位置触发一次切换。 */
    public func postThemeToggleForTest(): Unit {
        let appRef = match (app) {
            case Some(value) => value
            case None => return
        }
        let _ = appRef.postToUi({=> toggleTheme(28.0, 700.0)})
    }

    /** 动画结束：真正切换到目标主题（同时换 seline_ui 与 chui 两套 token）。 */
    public func applyThemeSwitch(): Unit {
        let nextDark = !darkMode.value
        darkMode.value = nextDark
        setSelineTheme(if (nextDark) { SelineTheme.dark() } else { SelineTheme.light() })
        match (app) {
            case Some(value) =>
                try {
                    value.setTheme(selineChuiTheme())
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
        themeRevealing.value = false
        themeReveal.value = 0.0
        writeDebugLog("theme: switched dark=${nextDark}")
    }

    /* -------------------------------------------------- 收藏 */

    /** 收藏页构建期懒加载：登录后第一次进入才请求。 */
    public func ensureFavoritesLoaded(): Unit {
        if (!loggedIn.value) {
            return
        }
        if (favoritesLoaded || favoritesLoading.value) {
            return
        }
        loadFavorites(reset: true)
    }

    /** 拉取收藏（`UserApi.saved`，分页）。 */
    public func loadFavorites(reset!: Bool = true): Unit {
        if (!loggedIn.value) {
            favoritesError.value = "登录后查看收藏"
            favoritesLoading.value = false
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                favoritesError.value = "客户端未就绪"
                return
        }
        let target = if (reset) { 1 } else { favoritesNextPage.value }
        if (target <= 0) {
            return
        }
        favoritesLoading.value = true
        if (reset) {
            favoritesError.value = ""
        }
        let _ = spawn {=>
            try {
                let page = UserApi.saved(clientBox.value, page: target, limit: 20)
                let cells = cellsFromBooks(page.books, clientBox.value.currentSiteUrl())
                writeDebugLog("favorites loaded: page=${target} count=${cells.size} " +
                    "current=${page.pagination.current} total=${page.pagination.totalItems}")
                postToUi({=>
                    if (reset) {
                        favorites.value = cells
                    } else {
                        for (cell in cells) {
                            favorites.value.add(cell)
                        }
                    }
                    favoritesNextPage.value = if (page.pagination.hasMore()) {
                        page.pagination.nextPage()
                    } else {
                        0
                    }
                    favoritesLoaded = true
                    favoritesLoading.value = false
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    favoritesError.value = "收藏加载失败：${failure.detail}"
                    favoritesLoading.value = false
                })
            }
        }
    }

    /* -------------------------------------------------- 下载菜单 */

    /** 打开/关闭下载版本菜单；打开时把当前按钮位置锁成菜单锚点。 */
    public func toggleDownloadMenu(): Unit {
        if (downloadMenuOpen.value) {
            downloadMenuOpen.value = false
            return
        }
        openDownloadMenu()
    }

    /** 用按钮当前矩形打开下载菜单（锚点只在打开瞬间取一次）。 */
    public func openDownloadMenu(): Unit {
        menuAnchorX = downloadAnchor.x
        menuAnchorY = downloadAnchor.y + downloadAnchor.h + 6.0
        downloadMenuClosing.value = false
        downloadMenuOpen.value = true
    }

    /** 验收用：延迟 delayMs 后打开下载菜单（等按钮完成 layout）。 */
    public func scheduleOpenDownloadMenuForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> openDownloadMenu() })
        }
    }

    /** 菜单锚点（打开时锁定）。 */
    public func downloadMenuX(): Float32 {
        menuAnchorX
    }

    public func downloadMenuY(): Float32 {
        menuAnchorY
    }

    /** 关闭下载菜单：先播收起动画，动画结束再卸载。 */
    public func closeDownloadMenu(): Unit {
        if (!downloadMenuOpen.value || downloadMenuClosing.value) {
            return
        }
        downloadMenuClosing.value = true
        let _ = spawn {=>
            sleep(140 * Duration.millisecond)
            postToUi({=>
                downloadMenuOpen.value = false
                downloadMenuClosing.value = false
            })
        }
    }

    /**
     * 下载菜单的条目：第一项是「默认下载链接（原书）」，
     * 之后是服务端给的可选格式（每项都有自己的 id/hash）。
     */
    public func downloadMenuItems(): Array<SelineMenuItem> {
        let items = ArrayList<SelineMenuItem>()
        let defaultLabel = if (detailMeta.value.isEmpty()) {
            "默认下载链接（原书）"
        } else {
            "${detailMeta.value}（原书）"
        }
        items.add(SelineMenuItem(defaultLabel, {=> selectDownloadFormat(0)},
            glyph: "download"))
        var index: Int64 = 0
        for (format in detailFormats.value) {
            let position = index + 1
            let label = if (format.sizeText().isEmpty()) {
                format.extension
            } else {
                "${format.extension} · ${format.sizeText()}"
            }
            items.add(SelineMenuItem(label, {=> selectDownloadFormat(position)},
                glyph: "download"))
            index += 1
        }
        items.toArray()
    }

    /** 选中某个版本并立即下载（0 = 原书）。 */
    public func selectDownloadFormat(index: Int64): Unit {
        detailFormatIndex.value = index
        downloadMenuOpen.value = false
        downloadMenuClosing.value = false
        downloadBook()
    }

    /* -------------------------------------------------- 评论 */

    /** 加载评论；`reset=true` 从 offset 0 开始，否则续接。 */
    public func loadComments(reset: Bool): Unit {
        let bookId = detailId.value
        if (bookId <= 0) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None => return
        }
        let offset = if (reset) { 0 } else { comments.value.size }
        commentsLoading.value = true
        commentsError.value = ""
        let _ = spawn {=>
            let payload = CommentsPayload.load(clientBox.value, bookId, offset)
            postToUi({=> applyComments(payload, reset) })
        }
    }

    private func applyComments(payload: CommentsPayload, reset: Bool): Unit {
        commentsLoading.value = false
        if (!payload.error.isEmpty()) {
            commentsError.value = "加载评论失败：${payload.error}"
            return
        }
        if (reset) {
            comments.value = payload.cells
            commentsVisible.value = 20
            commentsLoaded = true
            commentIndex.clear()
        } else {
            for (cell in payload.cells) {
                comments.value.add(cell)
            }
        }
        // 跨页解析「回复」的原评论：父评论可能在更早的分页里
        for (cell in payload.cells) {
            commentIndex[cell.id] = cell
        }
        for (cell in comments.value) {
            if (!cell.isReply || !cell.parentText.isEmpty() || cell.parentId == 0) {
                continue
            }
            match (commentIndex.get(cell.parentId)) {
                case Some(parent) =>
                    cell.parentAuthor = parent.author
                    cell.parentText = parent.text
                case None => ()
            }
        }
        commentsDisabled.value = payload.disabled
        commentsNextOffset.value = payload.nextOffset
    }

    /** 评论区哨兵可见时调用：第一次才真正请求（懒加载）。 */
    public func ensureCommentsLoaded(): Unit {
        if (commentsLoaded || commentsLoading.value || !commentsError.value.isEmpty()) {
            return
        }
        if (detailId.value <= 0) {
            return
        }
        loadComments(true)
    }

    /** 「显示更多」：先揭示已加载的评论，再按需拉下一段。 */
    public func showMoreComments(): Unit {
        let loaded = Int64(comments.value.size)
        if (commentsVisible.value < loaded) {
            let next = commentsVisible.value + 20
            commentsVisible.value = if (next > loaded) { loaded } else { next }
            return
        }
        loadMoreComments()
    }

    /** 「加载更多评论」。 */
    public func loadMoreComments(): Unit {
        if (commentsNextOffset.value <= 0 || commentsLoading.value) {
            return
        }
        loadComments(false)
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
        enqueueImageJob(ImageJob(ImageJobKind.DecodeCached, url, path, SelineImageKind.Cover))
    }

    private func scheduleImageFetch(url: String, kind: SelineImageKind,
        imageStore: SelineImageStore): Unit {
        if (failedCovers.contains(url) || pendingImages.contains(url)) {
            return
        }
        // 同时压太多 HTTPS 请求会拖慢整体（底层 TLS 在部分环境下还不稳定），
        // 限制并发，其余任务排队由固定 worker 顺序处理。
        if (activeFetches >= IMAGE_FETCH_LIMIT) {
            return
        }
        match (this.client) {
            case Some(_) => ()
            case None => return
        }
        pendingImages[url] = true
        activeFetches += 1
        enqueueImageJob(ImageJob(ImageJobKind.FetchAndDecode, url, "", kind))
    }

    private func enqueueImageJob(job: ImageJob): Unit {
        startImageWorkers()
        synchronized(imageQueueLock) {
            imageQueue.add(job)
        }
    }

    /** 固定 worker：线程数恒定，下载/解码都走队列，不再每张图 spawn 一个线程。 */
    private func startImageWorkers(): Unit {
        if (imageWorkersStarted) {
            return
        }
        imageWorkersStarted = true
        writeDebugLog("image workers: ${IMAGE_WORKERS} (fetch limit ${IMAGE_FETCH_LIMIT})")
        var index: Int64 = 0
        while (index < IMAGE_WORKERS) {
            let _ = spawn {=> imageWorkerLoop() }
            index += 1
        }
    }

    private func imageWorkerLoop(): Unit {
        while (true) {
            var job: ?ImageJob = None
            var stop = false
            synchronized(imageQueueLock) {
                if (!imageQueue.isEmpty()) {
                    job = Some(imageQueue[0])
                    imageQueue.remove(at: 0)
                } else if (imageWorkersStopped) {
                    stop = true
                }
            }
            match (job) {
                case Some(value) =>
                    try {
                        runImageJob(value)
                    } catch (_: Exception) {
                        ()
                    }
                case None =>
                    if (stop) {
                        return
                    }
                    sleep(8 * Duration.millisecond)
            }
        }
    }

    private func runImageJob(job: ImageJob): Unit {
        match (job.kind) {
            case ImageJobKind.DecodeCached =>
                let decoded = decodeImageFile(job.path)
                postToUi({=> finishImageDecode(job, decoded) })
            case ImageJobKind.FetchAndDecode =>
                let clientBox = match (this.client) {
                    case Some(value) => value
                    case None =>
                        postToUi({=> finishImageFetch(job, Option<DecodedImage>.None) })
                        return
                }
                let storeValue = match (this.store) {
                    case Some(value) => value
                    case None =>
                        postToUi({=> finishImageFetch(job, Option<DecodedImage>.None) })
                        return
                }
                let result = storeValue.fetchDecoded(job.url, job.imageKind, {link =>
                    try {
                        Some(clientBox.value.fetchBytes(link))
                    } catch (_: ZlibError) {
                        Option<Array<Byte>>.None
                    }
                })
                postToUi({=> finishImageFetch(job, result) })
        }
    }

    /** 下载+解码完成（UI 线程）：存像素或标记失败。 */
    private func finishImageFetch(job: ImageJob, result: ?DecodedImage): Unit {
        pendingImages.remove(job.url)
        if (activeFetches > 0) {
            activeFetches -= 1
        }
        match (result) {
            case Some(image) =>
                decodedImages[job.url] = image
            case None =>
                failedCovers[job.url] = true
        }
    }

    /** 纯解码完成（UI 线程）：存像素；缓存损坏删掉重下一次。 */
    private func finishImageDecode(job: ImageJob, decoded: ?DecodedImage): Unit {
        match (decoded) {
            case Some(image) =>
                decodedImages[job.url] = image
                pendingImages.remove(job.url)
            case None =>
                pendingImages.remove(job.url)
                let retries = match (decodeRetries.get(job.url)) {
                    case Some(value) => value
                    case None => 0
                }
                if (retries < 1) {
                    decodeRetries[job.url] = retries + 1
                    try {
                        remove(Path(job.path))
                    } catch (_: Exception) {
                        ()
                    }
                    match (this.store) {
                        case Some(storeValue) =>
                            scheduleImageFetch(job.url, SelineImageKind.Cover, storeValue)
                        case None => ()
                    }
                } else {
                    failedCovers[job.url] = true
                }
        }
    }
    /* -------------------------------------------------- UI 线程投递 */

    /** 把一段状态更新投递到 UI 线程执行（窗口未建好时丢弃）。 */
    private func postToUi(action: () -> Unit): Unit {
        match (app) {
            case Some(value) =>
                try {
                    let _ = value.postToUi(action)
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }
}
