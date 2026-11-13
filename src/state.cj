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
import zlibraryAPI4CJ.core.*
import stdx.encoding.json.*
import selineDownload.*

/** toast 语义：决定图标与颜色。 */
public enum ToastKind {
    | Info
    | Success
    | Error
}

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
    /**
     * 列表接口顺带返回的完整书籍信息（搜索/收藏的接口本身就给全量字段）。
     *
     * 有它时详情页可以直接渲染，不必再请求一次 `/book/{id}/{hash}`；
     * 热门/相似这类「精简列表」没有该值，走网络补详情。
     */
    public let info: ?BookInfo

    public init(id: Int64, hash: String, title: String, author: String, cover: String,
        meta: String, info!: ?BookInfo = None) {
        this.id = id
        this.hash = hash
        this.title = title
        this.author = author
        this.cover = cover
        this.meta = meta
        this.info = info
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
            BooklistsPayload(Option<BooklistPage>.None, friendlyErrorMessage(failure))
        }
    }

    static func loadMine(client: ZlibClient, page: Int64): BooklistsPayload {
        try {
            BooklistsPayload(Some(BooklistApi.my(client, page: page)), "")
        } catch (failure: ZlibError) {
            BooklistsPayload(Option<BooklistPage>.None, friendlyErrorMessage(failure))
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
            BooklistBooksPayload(ArrayList<BookCell>(), 0, 0, friendlyErrorMessage(failure))
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
            CommentsPayload(ArrayList<CommentCell>(), false, 0, friendlyErrorMessage(failure))
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
    /** 相关书籍：返回时直接复用，不再重新请求。 */
    let related: ArrayList<BookCell>
    let relatedLoaded: Bool
    /** 评论：同样复用，保留已展开的条数与分页偏移。 */
    let comments: ArrayList<CommentCell>
    let commentsLoaded: Bool
    let commentsDisabled: Bool
    let commentsNextOffset: Int64
    let commentsVisible: Int64
    /** 当时选中的下载版本。 */
    let formatIndex: Int64
    /** 当时是否已收藏。 */
    let saved: Bool

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
        this.related = state.detailRelated.value
        this.relatedLoaded = state.detailRelatedLoaded
        this.comments = state.comments.value
        this.commentsLoaded = state.commentsLoaded
        this.commentsDisabled = state.commentsDisabled.value
        this.commentsNextOffset = state.commentsNextOffset.value
        this.commentsVisible = state.commentsVisible.value
        this.formatIndex = state.detailFormatIndex.value
        this.saved = state.detailSaved.value
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
            error = friendlyErrorMessage(failure)
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

/**
 * 首页书墙数据源：登录用「个性化推荐」，未登录或推荐失败回退「热门」。
 *
 * 该函数不读 UI State，后台线程可直接调用（启动期首屏走的就是这条）。
 */
func landingBriefsFor(client: ZlibClient,
    loggedIn: Bool): (ArrayList<BookInfoBrief>, String) {
    if (loggedIn) {
        try {
            return (UserApi.recommended(client), "个性化推荐")
        } catch (_: ZlibError) {
            () // 未登录态/接口受限：静默回退热门
        }
    }
    (SearchApi.mostPopular(client), "热门")
}

/** 首屏数据（后台线程构造好再回投 UI，闭包只捕获不可变值）。 */
class LandingResult {
    let briefs: ArrayList<BookInfoBrief>
    let label: String
    let error: String

    init(briefs: ArrayList<BookInfoBrief>, label: String, error: String) {
        this.briefs = briefs
        this.label = label
        this.error = error
    }

    static func load(client: ZlibClient, loggedIn: Bool): LandingResult {
        try {
            let (briefs, label) = landingBriefsFor(client, loggedIn)
            LandingResult(briefs, label, "")
        } catch (failure: ZlibError) {
            LandingResult(ArrayList<BookInfoBrief>(), "", friendlyErrorMessage(failure))
        }
    }
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
            LoginOutcome(false, friendlyErrorMessage(failure), Option<ZlibClient>.None, Option<ZlibCredential>.None, "", "")
        }
    }
}

/** 用户资料刷新结果。 */
class ProfileOutcome {
    let ok: Bool
    let name: String
    let uid: String
    let quota: String
    let today: Int64
    let limit: Int64
    let error: String

    init(ok: Bool, name: String, uid: String, quota: String, today: Int64, limit: Int64,
        error: String) {
        this.ok = ok
        this.name = name
        this.uid = uid
        this.quota = quota
        this.today = today
        this.limit = limit
        this.error = error
    }

    static func load(client: ZlibClient): ProfileOutcome {
        try {
            let user = UserApi.profile(client)
            ProfileOutcome(true, user.name, "${user.id}",
                "今日 ${user.downloadsToday}/${user.downloadsLimit}",
                user.downloadsToday, user.downloadsLimit, "")
        } catch (failure: ZlibError) {
            ProfileOutcome(false, "", "", "", 0, 0, failure.detail)
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

/**
 * 用户主目录（`%USERPROFILE%`，没有就用 `$HOME`）。
 */
func homeDir(): String {
    if (let Some(value) <- getVariable("USERPROFILE")) {
        value
    } else if (let Some(value) <- getVariable("HOME")) {
        value
    } else {
        "."
    }
}

/**
 * 应用数据目录：`~/.seline-app/SelineRead`。
 *
 * 设置、账号这类**需要长期保留**的东西放这里；图片缓存仍然放临时目录（可丢）。
 * 更早的版本放在 `~/seline_read`，启动时会自动迁移过去并删掉旧目录。
 */
func appDataDir(): Path {
    Path(homeDir()).join(".seline-app").join("SelineRead")
}

/** 旧版配置目录（`~/seline_read`）：启动时一次性搬到新目录并删除。 */
func legacyHomeDataDir(): Path {
    Path(homeDir()).join("seline_read")
}

/** 旧版数据目录（`%TEMP%/SelineRead`），只用于一次性迁移。 */
private func legacyDataDir(): Path {
    Path(getVariable("TEMP") ?? ".").join("SelineRead")
}

/** 用户配置（JSON）：`~/seline_read/config.json`。 */
private func configJsonPath(): String {
    appDataDir().join("config.json").toString()
}

/** 多账号存储（JSON）：`~/seline_read/accounts.json`。 */
private func accountsJsonPath(): String {
    appDataDir().join("accounts.json").toString()
}

/** 旧版（纯文本）配置：`~/seline_read/config.txt`，只用于一次性迁移。 */
private func legacyConfigPath(): String {
    appDataDir().join("config.txt").toString()
}

/** 旧版账号文件：`~/seline_read/account.txt` / `account-list.txt`。 */
private func legacyAccountPath(name: String): String {
    appDataDir().join(name).toString()
}

/** 读文本文件（不存在/读失败返回空串）。 */
private func readTextFile(path: Path): String {
    if (!exists(path)) {
        return ""
    }
    try {
        String.fromUtf8(File.readFrom(path))
    } catch (_: Exception) {
        ""
    }
}

/** 写文本文件（自动建父目录）。 */
private func writeTextFile(path: Path, text: String): Unit {
    try {
        if (!exists(path.parent)) {
            Directory.create(path.parent, recursive: true)
        }
        File.writeTo(path, text.toArray())
    } catch (failure: Exception) {
        writeDebugLog("write ${path} failed: ${failure.message}")
    }
}

/**
 * 建目录 + 把旧版（`%TEMP%/SelineRead`）的配置/账号迁移过来。
 *
 * 只迁移一次（新位置已有文件就不动）。
 */
func ensureAppDataDir(): Unit {
    // 旧位置 ~/seline_read → 新位置 ~/.selineAPP/seline_read（搬完删掉旧目录）
    migrateFromLegacyHomeDir()
    let dir = appDataDir()
    if (!exists(dir)) {
        try {
            Directory.create(dir, recursive: true)
        } catch (_: Exception) {
            ()
        }
    }
    let legacy = legacyDataDir()
    if (!exists(legacy)) {
        return
    }
    // 旧配置（config.txt / user_config.txt）与旧账号文件都先原样搬过来；
    // 加载时会解析旧格式并自动改写成 JSON（见 loadUserConfig / loadAccounts）。
    // 注意：只有在"新目录里既没有 JSON 也没有旧文本"时才搬，避免迁移完又被搬回来。
    if (!exists(Path(configJsonPath())) && !exists(Path(legacyConfigPath()))) {
        migrateFile(legacy.join("user_config.txt"), dir.join("config.txt"))
    }
    if (!exists(Path(accountsJsonPath())) &&
        !exists(Path(legacyAccountPath("accounts.txt"))) &&
        !exists(Path(legacyAccountPath("account.txt")))) {
        migrateFile(legacy.join("account.txt"), dir.join("account.txt"))
    }
}

/**
 * 把旧版配置目录 `~/seline_read` 搬到 `~/.seline-app/SelineRead`，搬完删掉旧目录。
 *
 * 只在"新位置还没有同名文件"时搬，避免覆盖新数据。旧目录里只会有本应用的配置
 * 文件（config/accounts 及其旧文本格式），所以搬完直接整目录删除。
 */
private func migrateFromLegacyHomeDir(): Unit {
    let oldDir = legacyHomeDataDir()
    if (!exists(oldDir)) {
        return
    }
    let dir = appDataDir()
    for (name in ["config.json", "accounts.json", "config.txt", "account.txt",
        "account-list.txt", "accounts.txt"]) {
        let from = oldDir.join(name)
        let to = dir.join(name)
        if (!exists(from) || exists(to)) {
            continue
        }
        try {
            if (!exists(dir)) {
                Directory.create(dir, recursive: true)
            }
            File.writeTo(to, File.readFrom(from))
            writeDebugLog("migrated config: ${from} -> ${to}")
        } catch (_: Exception) {
            ()
        }
    }
    removeDirectoryRecursive(oldDir)
    writeDebugLog("removed legacy config dir: ${oldDir}")
}

/** 递归删除目录（std.fs 没有现成的 recursive delete）。 */
private func removeDirectoryRecursive(path: Path): Unit {
    if (!exists(path)) {
        return
    }
    try {
        for (entry in Directory.readFrom(path)) {
            if (entry.isDirectory()) {
                removeDirectoryRecursive(entry.path)
            } else {
                try {
                    remove(entry.path)
                } catch (_: Exception) {
                    ()
                }
            }
        }
    } catch (_: Exception) {
        ()
    }
    try {
        remove(path)
    } catch (_: Exception) {
        ()
    }
}

private func migrateFile(from: Path, to: Path): Unit {
    if (!exists(from) || exists(to)) {
        return
    }
    try {
        File.writeTo(to, File.readFrom(from))
        writeDebugLog("migrated ${from} -> ${to}")
    } catch (_: Exception) {
        ()
    }
}

/** 读回用户配置（不存在时返回空表）。 */
private func readUserConfig(): HashMap<String, String> {
    let result = HashMap<String, String>()
    let file = Path(legacyConfigPath())
    if (!exists(file)) {
        return result
    }
    try {
        let text = String.fromUtf8(File.readFrom(file))
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                continue
            }
            let parts = trimmed.split("=", 2)
            if (parts.size == 2) {
                result[parts[0].trimAscii()] = parts[1].trimAscii()
            }
        }
    } catch (_: Exception) {
        ()
    }
    result
}

/** 读回上次保存的凭证；没有/损坏时返回游客凭证。 */
/**
 * 一个已保存的账号（`~/seline_read/accounts.txt` 里的一行）。
 *
 * 行格式：`email|name|userId|userKey|language|default(1/0)`
 */
public class AccountEntry <: ToString {
    public var email: String
    public var name: String
    public var userId: String
    public var userKey: String
    public var language: String
    public var isDefault: Bool

    public init(email: String, name: String, userId: String, userKey: String,
        language: String, isDefault: Bool) {
        this.email = email
        this.name = name
        this.userId = userId
        this.userKey = userKey
        this.language = language
        this.isDefault = isDefault
    }

    /** 展示名：昵称 > 邮箱 > uid。 */
    public func label(): String {
        if (!name.isEmpty()) {
            return name
        }
        if (!email.isEmpty()) {
            return email
        }
        userId
    }

    /** 转成 zlib 凭证。 */
    public func credential(): ZlibCredential {
        let lang = if (language.isEmpty()) {
            ZlibCredential.anonymous().language
        } else {
            language
        }
        ZlibCredential(userId: userId, userKey: userKey, siteLanguage: lang)
    }

    public func toLine(): String {
        let flag = if (isDefault) { "1" } else { "0" }
        "${email}|${name}|${userId}|${userKey}|${language}|${flag}"
    }

    public func toString(): String {
        "${label()} (${userId})${if (isDefault) { " [默认]" } else { "" }}"
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
            normalizeCoverUrl(book.cover, siteUrl), meta, info: Some(book)))
    }
    cells
}

/**
 * 应用状态。
 *
 * `window` 用 `?DesktopApp` 保存：它在建窗口之后才有值，而 State 在之前就构造了。
 */
/**
 * 把 `ZlibError` 翻成一句用户能看懂的话（不暴露 URL / attempts 等内部诊断）。
 *
 * 内部诊断仍然写 debug 日志；页面上只显示这一句。
 */
func friendlyErrorMessage(failure: ZlibError): String {
    match (failure.kind) {
        case ZlibErrorKind.BadResponse =>
            "服务器返回了无法识别的内容（可能被风控或站点维护）"
        case ZlibErrorKind.ApiFailure =>
            if (failure.serverMessage.isEmpty()) {
                "接口返回失败"
            } else {
                "接口返回失败：${failure.serverMessage}"
            }
        case ZlibErrorKind.NotLoggedIn => "需要登录后才能访问"
        case ZlibErrorKind.NotFound => "内容不存在或已被删除"
        case ZlibErrorKind.Forbidden => "访问被拒绝（可能是站点风控）"
        case ZlibErrorKind.Closed => "客户端已关闭"
        case ZlibErrorKind.Cangjie => "网络请求失败（当前站和种子站都无法访问）"
    }
}
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
    /** 设置页左侧竖直页签：0 显示设置 / 1 下载设置 / 2 网络设置。 */
    public let settingsTab = State<Int64>(0)
    /** 显示设置：深浅色（与 darkMode 同步）。 */
    public let downloadPathInput = State<String>("")
    /** 网络设置：3 个官方站（占位，留空但不可删）+ 自定义站 + 种子站 + 当前选中站。 */
    public let officialSites = State<ArrayList<String>>(ArrayList<String>())
    public let customSites = State<ArrayList<String>>(ArrayList<String>())
    /** 种子站：单个「引导站」，只用来问出新域名（它的响应头会带 Location 重定向）。 */
    public let seedSite = State<String>("")
    public let activeSite = State<String>("")
    /** 新站输入框内容（自定义站 / 种子站）。 */
    public let siteInput = State<String>("")
    public let seedInput = State<String>("")
    public let networkMessage = State<String>("")
    /** 下载管理器（selineDownload）：任务列表 + 进度刷新计数。 */
    public let downloadItems = State<ArrayList<DownloadItem>>(ArrayList<DownloadItem>())
    public let downloadsTick = State<Int64>(0)
    private let downloadTasks = HashMap<String, DownloadTask>()
    private let downloadTaskLock = Mutex()
    private var downloadSeq: Int64 = 0
    /** 各页面的滚动位置（切页/返回后保持原位）。 */
    public let homeScroll = State<Float32>(0.0)
    public let searchScroll = State<Float32>(0.0)
    public let favoritesScroll = State<Float32>(0.0)
    public let booklistsScroll = State<Float32>(0.0)
    public let booklistDetailScroll = State<Float32>(0.0)
    public let detailScroll = State<Float32>(0.0)
    public let settingsScroll = State<Float32>(0.0)
    public let downloadsScroll = State<Float32>(0.0)
    public let accountScroll = State<Float32>(0.0)
    /** 详情页返回栈：从「相关书籍」再点进另一本时，返回能回到上一本。 */
    private let detailHistory = ArrayList<DetailSnapshot>()
    /** 深色模式（false = 浅色）。 */
    public let darkMode = State<Bool>(true)
    /** 正在做主题过渡；过渡期间构建用"目标"主题，点击那一帧仍用旧主题。 */
    private var themeSwitching: Bool = false
    private var themeTargetDark: Bool = true

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
    /** 搜索结果已加载到第几页（1 起）。 */
    private var searchPage: Int64 = 1
    /** 搜索结果还有下一页吗（滚到底自动取）。 */
    public let searchHasMore = State<Bool>(false)
    public let searchLoadingMore = State<Bool>(false)
    /** 详情页代数：每次打开/关闭/回退都 +1，过期的网络结果直接丢弃（修 A→B 串内容）。 */
    private var detailGeneration: Int64 = 0
    /** 书单详情代数（同上）。 */
    private var booklistGeneration: Int64 = 0
    /** 收藏代数（登录/登出/重载时 +1）。 */
    private var favoritesGeneration: Int64 = 0
    /** 账号资料代数（换号/登出时 +1，防止旧账号的 profile 覆盖新账号）。 */
    private var profileGeneration: Int64 = 0
    /** 右下角 toast：当前文案（空 = 不显示）。 */
    public let toastText = State<String>("")
    /** toast 语义：决定图标与颜色（信息/成功/错误）。 */
    public let toastKind = State<ToastKind>(ToastKind.Info)
    /** toast 的弹出弹簧（应用持有，跨帧稳定）。 */
    public let toastSpring = Spring(0.0, stiffness: 260.0, damping: 26.0)
    private var toastSeq: Int64 = 0
    private var lastToastedText: String = ""
    /** 是否停在图书详情页（二级页面）。 */
    public let detailOpen = State<Bool>(false)
    /** 详情页字段。 */
    public let detailTitle = State<String>("")
    public let detailAuthor = State<String>("")
    public let detailMeta = State<String>("")
    public let detailDescription = State<String>("")
    public let detailCover = State<String>("")
    public let detailLoading = State<Bool>(false)
    /** 详情页「收藏」状态（来自详情接口的 _isUserSavedBook）。 */
    public let detailSaved = State<Bool>(false)
    /** 收藏请求进行中（防止连点）。 */
    public let favoriteBusy = State<Bool>(false)
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
    /** 相关书籍是否已加载（详情页快照要读，故非 private）。 */
    var detailRelatedLoaded = false

    /* ---- 账号 ---- */
    public let loggedIn = State<Bool>(false)
    public let accountName = State<String>("")
    public let accountId = State<String>("")
    /** 今日已下载 / 每日上限（来自 /user/profile，账号页展示）。 */
    public let quotaToday = State<Int64>(0)
    public let quotaLimit = State<Int64>(0)
    /** 是否已经成功拿到过配额（没拿到时不显示 0/0）。 */
    public let quotaKnown = State<Bool>(false)
    public let quotaLoading = State<Bool>(false)
    public let loginEmail = State<String>("")
    public let loginPassword = State<String>("")
    public let loginBusy = State<Bool>(false)
    public let loginMessage = State<String>("")
    /** 已保存的账号（多账号切换）。 */
    public let accounts = State<ArrayList<AccountEntry>>(ArrayList<AccountEntry>())
    /** 登录弹窗是否打开。 */
    public let loginDialogOpen = State<Bool>(false)

    /* ---- 多账号 ---- */

    /** 读 `accounts.txt` 到内存；坏行直接跳过。 */
    private func loadAccounts(): Unit {
        accounts.value = ArrayList<AccountEntry>()
        // 新格式：JSON（~/seline_read/accounts.json）
        let jsonText = readTextFile(Path(accountsJsonPath()))
        if (!jsonText.trimAscii().isEmpty()) {
            try {
                let root = parseJsonObject(jsonText, path: "accounts.json")
                for (item in arrayFieldOf(root, "accounts")) {
                    try {
                        let obj = item.asObject()
                        let userId = readString(obj, "userId")
                        if (userId.isEmpty()) {
                            continue
                        }
                        accounts.value.add(AccountEntry(
                            readString(obj, "email"),
                            readString(obj, "name"),
                            userId,
                            readString(obj, "userKey"),
                            readString(obj, "language"),
                            readBoolOr(obj, "default", false)))
                    } catch (_: Exception) {
                        () // 单条坏数据跳过
                    }
                }
                writeDebugLog("accounts loaded(json): ${accounts.value.size}")
                return
            } catch (_: Exception) {
                writeDebugLog("accounts.json unreadable; falling back to legacy")
            }
        }
        // 旧格式：单账号 account.txt（uid|key|lang）或 accounts.txt（pipe 分隔多行）
        let legacyText = readTextFile(Path(legacyAccountPath("accounts.txt")))
        let singleText = readTextFile(Path(legacyAccountPath("account.txt")))
        let source = if (!legacyText.trimAscii().isEmpty()) {
            legacyText
        } else {
            singleText
        }
        if (!source.trimAscii().isEmpty()) {
            if (!legacyText.trimAscii().isEmpty()) {
                for (line in source.split("\n")) {
                    let trimmed = line.trimAscii()
                    if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                        continue
                    }
                    let parts = trimmed.split("|")
                    if (parts.size < 4) {
                        continue
                    }
                    let language = if (parts.size >= 5) { parts[4] } else { "" }
                    let isDefault = if (parts.size >= 6) { parts[5] == "1" } else { false }
                    accounts.value.add(AccountEntry(parts[0], parts[1], parts[2], parts[3],
                        language, isDefault))
                }
            } else {
                let parts = source.trimAscii().split("|")
                if (parts.size >= 2 && !parts[0].isEmpty()) {
                    let language = if (parts.size >= 3) { parts[2] } else { "" }
                    accounts.value.add(AccountEntry("", "", parts[0], parts[1], language, true))
                }
            }
            saveAccounts()
            try {
                remove(Path(legacyAccountPath("accounts.txt")))
                remove(Path(legacyAccountPath("account.txt")))
            } catch (_: Exception) {
                ()
            }
            writeDebugLog("legacy accounts migrated to json: ${accounts.value.size}")
        }
        writeDebugLog("accounts loaded: ${accounts.value.size}")
    }

    /** 把内存里的账号写回 `accounts.json`。 */
    public func saveAccounts(): Unit {
        ensureAppDataDir()
        let root = JsonObject()
        let list = JsonArray()
        for (entry in accounts.value) {
            let obj = JsonObject()
            obj.put("email", JsonString(entry.email))
            obj.put("name", JsonString(entry.name))
            obj.put("userId", JsonString(entry.userId))
            obj.put("userKey", JsonString(entry.userKey))
            obj.put("language", JsonString(entry.language))
            obj.put("default", JsonBool(entry.isDefault))
            list.add(obj)
        }
        root.put("accounts", list)
        writeTextFile(Path(accountsJsonPath()), root.toJsonString())
    }
    /** 默认账号（启动时只自动登录它）。 */
    public func defaultAccount(): ?AccountEntry {
        for (entry in accounts.value) {
            if (entry.isDefault) {
                return Some(entry)
            }
        }
        if (accounts.value.isEmpty()) {
            None
        } else {
            Some(accounts.value[0])
        }
    }

    /** 当前会话使用的账号（可能不在列表里，比如刚登录还没保存）。 */
    public func currentAccount(): ?AccountEntry {
        for (entry in accounts.value) {
            if (entry.userId == accountId.value) {
                return Some(entry)
            }
        }
        None
    }

    /** 设为默认账号（单选）。 */
    public func setDefaultAccount(userId: String): Unit {
        for (entry in accounts.value) {
            entry.isDefault = entry.userId == userId
        }
        saveAccounts()
        writeDebugLog("default account -> ${userId}")
    }

    /** 添加/更新一个账号；`makeDefault` 为真时把它设成默认。 */
    public func upsertAccount(credential: ZlibCredential, email: String, name: String,
        makeDefault!: Bool = false): Unit {
        if (!credential.isLoggedIn) {
            return
        }
        var found = false
        for (entry in accounts.value) {
            if (entry.userId == credential.userId) {
                entry.userKey = credential.userKey
                entry.language = credential.language
                if (!email.isEmpty()) {
                    entry.email = email
                }
                if (!name.isEmpty()) {
                    entry.name = name
                }
                found = true
                break
            }
        }
        if (!found) {
            let defaultEntry = defaultAccount()
            let hasDefault = match (defaultEntry) {
                case Some(entry) => entry.isDefault
                case None => false
            }
            accounts.value.add(AccountEntry(email, name, credential.userId,
                credential.userKey, credential.language, makeDefault || !hasDefault))
        }
        if (makeDefault) {
            setDefaultAccount(credential.userId)
        } else {
            saveAccounts()
        }
    }

    /** 用指定账号切换会话（不重新登录：直接用保存的 userId/userKey 建客户端）。 */
    public func switchToAccount(userId: String): Unit {
        var target: ?AccountEntry = None
        for (entry in accounts.value) {
            if (entry.userId == userId) {
                target = Some(entry)
                break
            }
        }
        let entry = match (target) {
            case Some(value) => value
            case None => return
        }
        let baseUrl = if (activeSite.value.isEmpty()) {
            ZlibHost.DEFAULT_URL
        } else {
            activeSite.value
        }
        let seed = if (seedSite.value.isEmpty()) {
            ZlibHost.DEFAULT_URL
        } else {
            seedSite.value
        }
        try {
            let created = ZlibClient.create(baseUrl: baseUrl, credential: entry.credential(),
                seed: seed)
            this.client = Some(ClientBox(created))
        } catch (failure: ZlibError) {
            loginMessage.value = "切换账号失败：${friendlyErrorMessage(failure)}"
            return
        }
        loggedIn.value = true
        accountId.value = entry.userId
        accountName.value = entry.label()
        // 换号后所有"按账号"的数据都要重来
        favoritesGeneration += 1
        favoritesLoaded = false
        favorites.value = ArrayList<BookCell>()
        favoritesNextPage.value = 0
        favoritesError.value = ""
        detailGeneration += 1
        detailOpen.value = false
        detailHistory.clear()
        quotaKnown.value = false
        quotaToday.value = 0
        quotaLimit.value = 0
        loginMessage.value = "已切换到 ${entry.label()}"
        writeDebugLog("switched account -> ${entry.userId}")
        refreshProfile()
        // 换号后首页推荐也应跟着账号变
        reloadPopular()
    }

    /** 从列表删除账号；删的是当前账号就退出登录。 */
    public func removeAccount(userId: String): Unit {
        let kept = ArrayList<AccountEntry>()
        var wasDefault = false
        for (entry in accounts.value) {
            if (entry.userId == userId) {
                wasDefault = entry.isDefault
                continue
            }
            kept.add(entry)
        }
        accounts.value = kept
        if (wasDefault && !kept.isEmpty()) {
            kept[0].isDefault = true
        }
        if (accountId.value == userId) {
            logout()
        }
        saveAccounts()
    }

    /** 打开/关闭登录弹窗。 */
    public func openLoginDialog(): Unit {
        loginMessage.value = ""
        loginDialogOpen.value = true
    }

    public func closeLoginDialog(): Unit {
        loginDialogOpen.value = false
        loginPassword.value = ""
    }

    /* ---- 下载 ---- */
    /** 下载目录（`%USERPROFILE%/Downloads/SelineRead`）。 */
    public let downloadDir = State<String>("")
    public let downloads = State<ArrayList<DownloadEntry>>(ArrayList<DownloadEntry>())
    public let downloading = State<Bool>(false)
    /** 下载按钮弹出的「版本选择」菜单是否打开。 */
    public let downloadMenuOpen = State<Bool>(false)
    /** 菜单正在收起（播完反向动画再卸载）。 */
    public let downloadMenuClosing = State<Bool>(false)
    /** 菜单弹出弹簧（由应用持有：overlay 每帧重建，spring 实例不能再放在控件里）。 */
    public let downloadMenuSpring = Spring(0.0, stiffness: 300.0, damping: 18.0)
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
    /** 评论是否已加载（详情页快照要读，故非 private）。 */
    var commentsLoaded: Bool = false
    /** 当前渲染多少条评论，超出时「显示更多」再追加。 */
    public let commentsVisible = State<Int64>(20)
    /** 已加载评论的 id -> 单元格索引（跨页解析「回复」的原评论）。 */
    private let commentIndex = HashMap<Int64, CommentCell>()

    private var client: ?ClientBox = None
    private var app: ?DesktopApp = None
    /* ---- 启动期网络异步：客户端就绪前发生的动作先排队，就绪后补跑 ---- */
    private var clientReadyFired: Bool = false
    private var clientReadyHooks: ArrayList<() -> Unit> = ArrayList<() -> Unit>()
    private var pendingSearchKeyword: String = ""
    private var pendingBookId: Int64 = 0
    private var pendingBookHash: String = ""
    private var pendingDownloadId: Int64 = 0
    private var pendingDownloadHash: String = ""
    private var pendingLogin: Bool = false
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
    /** 图片 worker 的 Future：退出时 join，避免运行时回收线程时踩已释放内存。 */
    private let imageWorkerFutures = ArrayList<Future<Unit>>()
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
        iconAsset = findAsset("SR.png")
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
                // 纹理属于渲染器：交给 app 管理，chui 会在 window.close() 之前 close()
                match (this.app) {
                    case Some(value) => value.manage(texture)
                    case None => ()
                }
                placeholderTexture = Some(texture)
                Some(texture)
            case None => None
        }
    }

    /** 清空搜索态（含分页标记）。 */
    private func resetSearchState(): Unit {
        lastKeyword.value = ""
        results.value = ArrayList<BookCell>()
        searchPage = 1
        searchHasMore.value = false
        searchLoadingMore.value = false
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
            resetSearchState()
        }
        tab.value = index
    }

    /**
     * 阻塞式初始化：建 API 客户端 + 拉首屏。
     *
     * 必须在建窗口之前完成：窗口会记下创建它的原生线程，之后拒绝别的线程轮询；
     * 而阻塞调用会让运行时把当前线程挪走。
     */
    public func bootstrapLocal(): Unit {
        // 持久化设置/账号都放 ~/.seline-app/SelineRead（旧位置会自动迁移）
        ensureAppDataDir()
        loadUserConfig()
        loadAccounts()
        // 启动只自动登录"默认账号"，其它账号作为备选（在账号页手动切换）
        match (defaultAccount()) {
            case Some(entry) =>
                let credential = entry.credential()
                if (credential.isLoggedIn) {
                    loggedIn.value = true
                    accountId.value = credential.userId
                    accountName.value = entry.label()
                    writeDebugLog("credential restored (default account): uid=${credential.userId}")
                }
            case None => ()
        }
        loading.value = true
        status.value = "正在加载…"
        writeDebugLog("bootstrap: local done (window can show now)")
    }

    /**
     * 启动第二步：**窗口显示之后**才做网络（建客户端、探测站点、拉首屏）。
     *
     * 建客户端/首屏请求可能要几秒甚至十几秒（网络差时），放在窗口之前会把
     * 启动卡成白屏；现在窗口先出来，首屏数据后台补，回投 UI。
     */
    public func startBackgroundBootstrap(): Unit {
        // 离线模式（UI 截图/开发用）：跳过全部网络
        if (offlineMode()) {
            writeDebugLog("bootstrap: offline mode, skip network")
            status.value = "离线模式"
            loading.value = false
            return
        }
        let defaultEntry = defaultAccount()
        let credential = match (defaultEntry) {
            case Some(entry) => entry.credential()
            case None => ZlibCredential.anonymous()
        }
        let displayName = match (defaultEntry) {
            case Some(entry) => entry.label()
            case None => credential.userId
        }
        let isLoggedIn = credential.isLoggedIn
        // 自定义站点 / 种子站：用户配置优先，没配置就用官方默认站
        let baseUrl = if (activeSite.value.isEmpty()) {
            ZlibHost.DEFAULT_URL
        } else {
            activeSite.value
        }
        let seed = if (seedSite.value.isEmpty()) {
            ZlibHost.DEFAULT_URL
        } else {
            seedSite.value
        }
        writeDebugLog("bootstrap: begin (background) base=${baseUrl} seed=${seed}")
        let _ = spawn {=>
            let created = try {
                ZlibClient.create(baseUrl: baseUrl, credential: credential, seed: seed)
            } catch (failure: ZlibError) {
                postToUi({=>
                    error.value = "创建客户端失败：${friendlyErrorMessage(failure)}"
                    status.value = "离线"
                    loading.value = false
                    writeDebugLog("bootstrap: create client failed: ${failure.detail}")
                })
                return
            }
            let site = created.currentSiteUrl()
            // 首屏列表（登录态优先个性化推荐）
            let landing = LandingResult.load(created, isLoggedIn)
            postToUi({=>
                client = Some(ClientBox(created))
                if (isLoggedIn) {
                    loggedIn.value = true
                    accountId.value = credential.userId
                    accountName.value = displayName
                }
                if (activeSite.value.isEmpty()) {
                    activeSite.value = site
                }
                adoptRefreshedSite()
                if (landing.error.isEmpty()) {
                    popular.value = cellsFromBriefs(landing.briefs, site)
                    popularVisible.value = 12
                    status.value = "${landing.label} ${popular.value.size} 本 · ${site}"
                    error.value = ""
                    writeDebugLog("popular loaded: ${popular.value.size} (${landing.label})")
                    if (!popular.value.isEmpty()) {
                        let first = popular.value[0]
                        writeDebugLog("first book: id=${first.id} hash=${first.hash}")
                        writeDebugLog("first cover url: ${first.cover}")
                        if (!first.cover.isEmpty()) {
                            let _ = imagePath(first.cover, SelineImageKind.Cover)
                        }
                    }
                } else {
                    error.value = "加载失败：${landing.error}"
                    status.value = "加载失败"
                }
                loading.value = false
                writeDebugLog("bootstrap: site=${site}")
                // 后台探测入口站 3xx（不阻塞 UI），探到再把新站写回配置
                startRedirectProbe(site)
                // 客户端就绪：补跑启动期排队的用户动作 + 刷新账号资料
                fireClientReady()
                refreshProfile()
            })
        }
    }

    /**
     * 启动时跟随站点入口的 3xx 跳转。
     *
     * Z-Library 的入口域名经常只是一层跳转（例如 `zh.eva101.ru` 302 到
     * `zh.tmdgoogle.ru`）。客户端虽然会自动跟随重定向，但配置里仍写着旧域名，
     * 每次请求都多一跳；这里探测一次，把 `Location` 直接提升为当前站并落盘。
     */
    /** 后台探测入口站 3xx（如 zh.eva101.ru -> zh.tmdgoogle.ru），不阻塞 UI。 */
    private func startRedirectProbe(site: String): Unit {
        if (site.isEmpty()) {
            return
        }
        let _ = spawn {=>
            let probe = probeSite(site, timeoutSeconds: 5)
            if (!probe.isRedirect || probe.location.isEmpty()) {
                return
            }
            let location = probe.location
            postToUi({=> applySiteRedirect(site, location) })
        }
    }

    /** 应用 3xx 探测结果：把跳转目标作为当前站（写配置 + State）。 */
    private func applySiteRedirect(current: String, location: String): Unit {
        let target = try {
            ZlibHost.of(location)
        } catch (_: ZlibError) {
            return
        }
        if (target.url == current || target.url == activeSite.value) {
            return
        }
        activeSite.value = target.url
        match (this.client) {
            case Some(box) =>
                try {
                    box.value.setCustomSite(target.url)
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
        saveUserConfig()
        writeDebugLog("startup redirect: ${current} -> ${target.url}")
    }

    /** 客户端就绪后执行（启动期网络在后台，依赖网络的验收钩子要用这个排队）。 */
    public func whenClientReady(handler: () -> Unit): Unit {
        if (clientReadyFired) {
            handler()
            return
        }
        clientReadyHooks.add(handler)
    }

    /** 客户端已可用：补跑启动期排队的动作（UI 线程）。 */
    private func fireClientReady(): Unit {
        clientReadyFired = true
        if (pendingLogin) {
            pendingLogin = false
            submitLogin()
        }
        if (!pendingSearchKeyword.isEmpty()) {
            let keyword = pendingSearchKeyword
            pendingSearchKeyword = ""
            searchText.value = keyword
            submitSearch()
        }
        if (pendingBookId > 0) {
            let id = pendingBookId
            let hash = pendingBookHash
            pendingBookId = 0
            pendingBookHash = ""
            openBookById(id, hash)
        }
        if (pendingDownloadId > 0) {
            let id = pendingDownloadId
            let hash = pendingDownloadHash
            pendingDownloadId = 0
            pendingDownloadHash = ""
            downloadById(id, hash)
        }
        for (handler in clientReadyHooks) {
            handler()
        }
        clientReadyHooks.clear()
    }

    /** 窗口建立后挂上；之后后台结果才回得来。 */
    public func attach(app: DesktopApp): Unit {
        this.app = app
        if (offlineMode()) {
            return
        }
        // 恢复出来的凭证要真的打一次接口才知道还有效（改密码/风控会让旧 key 失效）
        refreshProfile()
    }

    /**
     * 窗口关闭后收尾。
     *
     * **不要在这里 close 纹理**：`app.run` 返回时窗口与渲染器已经销毁，
     * 此时再 `SDL_DestroyTexture` 会访问已释放的渲染器，退出时随机触发
     * `0xc0000374` 堆损坏。纹理通过 `app.manage()` 交给 chui，在
     * `window.close()` **之前**统一释放。
     */
    public func shutdown(): Unit {
        writeDebugLog("shutdown: begin")
        synchronized(imageQueueLock) {
            imageWorkersStopped = true
        }
        // 等所有图片 worker 真正退出：主线程返回时若它们还活着，Cangjie 运行时
        // 回收线程对象会踩到已释放内存（PageHeap 已抓到 CJ_CJThreadFree 内的 AV）。
        for (worker in imageWorkerFutures) {
            try {
                worker.get()
            } catch (_: Exception) {
                ()
            }
        }
        writeDebugLog("shutdown: workers joined")
        writeDebugLog("shutdown: workers flagged")
        coverTextures.clear()
        decodedImages.clear()
        pendingImages.clear()
        placeholderTexture = None
        // 不在这里 close 网络客户端：有在途图片请求时 LinderHttp 的
        // close() 会等待连接回收，实测能挂住几十秒（窗口已关、进程却退不掉）。
        // 进程马上就被 terminateSelf 结束，socket 交给系统回收。
        client = None
        writeDebugLog("shutdown: client dropped")
        writeDebugLog("shutdown: end")
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

    /**
     * 首页书墙数据源：登录后用「个性化推荐」，未登录或推荐接口失败回退「热门」。
     *
     * 两个接口返回的都是精简列表（id/hash/标题/作者/封面），卡片点击后再补详情。
     */
    private func fetchLandingBriefs(clientValue: ZlibClient): (ArrayList<BookInfoBrief>, String) {
        landingBriefsFor(clientValue, loggedIn.value)
    }

    private func loadPopularBlocking(clientValue: ZlibClient): Unit {
        loading.value = true
        try {
            let (briefs, sourceLabel) = fetchLandingBriefs(clientValue)
            popular.value = cellsFromBriefs(briefs, clientValue.currentSiteUrl())
            popularVisible.value = 12
            status.value = "${sourceLabel} ${popular.value.size} 本 · ${clientValue.currentSiteUrl()}"
            error.value = ""
            writeDebugLog("popular loaded: ${popular.value.size} (${sourceLabel})")
        } catch (failure: ZlibError) {
            error.value = "加载热门失败：${friendlyErrorMessage(failure)}"
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
                let (briefs, sourceLabel) = fetchLandingBriefs(clientBox.value)
                let cells = cellsFromBriefs(briefs, clientBox.value.currentSiteUrl())
                postToUi({=>
                    popular.value = cells
                    popularVisible.value = 12
                    status.value = "${sourceLabel} ${cells.size} 本 · ${clientBox.value.currentSiteUrl()}"
                    loading.value = false
                    error.value = ""
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    error.value = "加载热门失败：${friendlyErrorMessage(failure)}"
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
        // 启动期客户端还在后台创建：先排队，等客户端就绪再真正搜
        match (this.client) {
            case None =>
                pendingSearchKeyword = keyword
                writeDebugLog("search queued until client ready")
                return
            case Some(_) => ()
        }
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
            resetSearchState()
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
        searchPage = 1
        searchHasMore.value = false
        searchLoadingMore.value = false
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
                    searchPage = 1
                    searchHasMore.value = page.pagination.hasMore()
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
                    error.value = "搜索失败：${friendlyErrorMessage(failure)}"
                    loading.value = false
                })
            }
        }
    }

    /**
     * 搜索结果「滚到底」：取下一页并追加。
     *
     * 搜索接口支持 `page`，但之前只取了第一页，所以往下滚没有更多内容。
     * 和 `submitSearch` 共用 `searchGeneration`：期间换了关键词，旧页结果直接丢。
     */
    public func loadMoreSearch(): Unit {
        if (loading.value || searchLoadingMore.value || !searchHasMore.value) {
            return
        }
        let keyword = lastKeyword.value
        if (keyword.isEmpty()) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None => return
        }
        let generation = searchGeneration
        let nextPage = searchPage + 1
        searchLoadingMore.value = true
        let _ = spawn {=>
            try {
                let page = SearchApi.search(clientBox.value, keyword, page: nextPage, limit: 20)
                let cells = cellsFromBooks(page.books, clientBox.value.currentSiteUrl())
                postToUi({=>
                    if (generation != searchGeneration) {
                        writeDebugLog("drop stale search page: ${keyword} #${nextPage}")
                        return
                    }
                    searchPage = nextPage
                    searchHasMore.value = page.pagination.hasMore()
                    searchLoadingMore.value = false
                    if (cells.isEmpty()) {
                        searchHasMore.value = false
                        return
                    }
                    for (cell in cells) {
                        results.value.add(cell)
                    }
                    status.value = "搜索「${keyword}」：已加载 ${results.value.size} 本"
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    if (generation != searchGeneration) {
                        return
                    }
                    searchLoadingMore.value = false
                    // 出错不自动重试，避免滚到底反复请求；把「还有更多」关掉即可
                    searchHasMore.value = false
                    writeDebugLog("search page failed: ${failure.detail}")
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
            resetSearchState()
            tab.value = TAB_HOME
        }
    }

    /** 验收用：延迟 delayMs 后打开「相关书籍」里的第一本（验证详情返回栈）。 */
    @When[debug]
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

    /** 验收用：延迟后设置任意页面的滚动位置（内容加载完再滚）。 */
    @When[debug]
    public func postScrollForTest(target: State<Float32>, value: Float32): Unit {
        match (app) {
            case Some(appRef) =>
                let _ = appRef.postToUi({=>
                    target.value = value
                    writeDebugLog("scroll -> ${value}")
                })
            case None => ()
        }
    }

    /** 验收用：延迟后设置详情页滚动位置（内容加载完再滚）。 */
    @When[debug]
    public func postDetailScrollForTest(value: Float32): Unit {
        match (app) {
            case Some(appRef) =>
                let _ = appRef.postToUi({=>
                    detailScroll.value = value
                    writeDebugLog("detail scroll -> ${value}")
                })
            case None => ()
        }
    }

    /** 验收用：自检下载管理器（离线时应显示「失败」而不是崩溃）。 */
    @When[debug]
    public func runDownloadSelfTest(): Unit {
        let _ = spawn {=>
            sleep(800 * Duration.millisecond)
            postToUi({=>
                let id = startDownload(24126585, "217fd6", "下载自检")
                writeDebugLog("dlselftest: created ${id}")
            })
            sleep(3000 * Duration.millisecond)
            postToUi({=>
                for (item in downloadItems.value) {
                    writeDebugLog("dlselftest: item ${item.taskId} status=${item.status} " +
                        "err=${item.error} progress=${item.percent()}")
                }
            })
        }
    }

    /**
     * 验收用（本地 mock eapi）：打开 111（服务端故意慢 4s）→ 150ms 后打开 222（立即返回）。
     *
     * 期望：最终详情是 222 / MOCK-B，111 的迟到响应被丢弃。
     */
    @When[debug]
    public func runMockRaceSelfTest(): Unit {
        let _ = spawn {=>
            sleep(900 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("mockrace: open 111 (slow)")
                openBookById(111, "mockhash")
            })
            sleep(150 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("mockrace: open 222 (fast)")
                openBookById(222, "mockhash")
            })
            sleep(7000 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("mockrace result: id=${detailId.value} title=${detailTitle.value} " +
                    "loading=${detailLoading.value} (expect 222 / MOCK-B")
            })
        }
    }

    /**
     * 验收用：把所有页面的错误/空态一次性摆出来（截图给设计看）。
     *
     * 只是往 State 里写文案，不请求网络。
     */
    @When[debug]
    public func forceErrorStatesForShot(mode: String): Unit {
        let site = "zh.eva101.ru"
        detailOpen.value = false
        booklistOpen.value = false
        // 首页 / 搜索
        error.value = "加载热门失败：站点 ${site} 返回 503 Service Unavailable，可能是站方维护或网络被阻断"
        loading.value = false
        popular.value = ArrayList<BookCell>()
        lastKeyword.value = if (mode == "search") { "三体" } else { "" }
        results.value = ArrayList<BookCell>()
        // 收藏（未登录态 + 错误态都摆上）
        favoritesError.value = "收藏加载失败：请求超时（${site} 30s 无响应）"
        favoritesLoading.value = false
        favorites.value = ArrayList<BookCell>()
        // 书单
        booklistsError.value = "书单加载失败：服务器返回 502 Bad Gateway"
        booklistsLoading.value = false
        booklists.value = ArrayList<BooklistCell>()
        // 书单详情（只在 mode=booklist 时打开，否则会盖住别的页面）
        if (mode == "booklist") {
        booklistOpen.value = true
        }
        if (mode == "booklist") {
        booklistId.value = 424242
        booklistTitle.value = "科幻小说精选"
        booklistAuthor.value = "mock"
        booklistDescription.value = ""
        booklistBooks.value = ArrayList<BookCell>()
        booklistError.value = "加载书单内容失败：网络连接被重置"
        booklistLoading.value = false
        }
        // 详情（只在 mode=detail 时打开）
        if (mode == "detail") {
        detailOpen.value = true
        detailId.value = 24126585
        detailHash.value = "217fd6"
        detailTitle.value = "毛泽东选集(1-7卷)"
        detailAuthor.value = "毛泽东"
        detailMeta.value = "epub · 2.78 MB"
        detailLoading.value = false
        detailError.value = "加载详情失败：下载链接签名过期，请刷新站点后重试"
        detailRelatedError.value = "相关书籍加载失败：429 Too Many Requests"
        commentsError.value = "加载评论失败：服务器错误（500）"
        }
        // 下载
        // 设置/网络
        networkMessage.value = "当前站和种子站都不可用，刷新失败"
        // 账号
        loginMessage.value = "登录失败：账号或密码错误"
        writeDebugLog("force error states for shot")
    }

    /** 验收用（离线可跑）：造一批假搜索结果，用来截图确认「加载更多」页脚渲染。 */
    @When[debug]
    public func forceFakeSearchForShot(): Unit {
        lastKeyword.value = "fake"
        tab.value = TAB_HOME
        detailOpen.value = false
        loading.value = false
        let cells = ArrayList<BookCell>()
        for (index in 0..20) {
            cells.add(BookCell(Int64(index + 1), "fake${index}", "测试书籍 ${index + 1}",
                "作者 ${index + 1}", "epub · 1.2 MB", ""))
        }
        results.value = cells
        searchPage = 1
        searchHasMore.value = true
        searchLoadingMore.value = false
        status.value = "搜索「fake」：${cells.size} 本"
    }

    /**
     * 验收用（离线可跑）：搜索分页的状态机不能在失败后卡死。
     *
     * 手动把 hasMore 置真 → loadMoreSearch（站点 503 时会失败）→
     * 期望 loadingMore 归位、hasMore 关掉，不会无限重试。
     */
    @When[debug]
    public func runSearchPagingOfflineTest(): Unit {
        let _ = spawn {=>
            sleep(900 * Duration.millisecond)
            postToUi({=>
                lastKeyword.value = "selftest"
                searchPage = 1
                searchHasMore.value = true
                searchLoadingMore.value = false
                writeDebugLog("searchpaging: before hasMore=${searchHasMore.value}")
                loadMoreSearch()
            })
            sleep(15000 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("searchpaging: after loadingMore=${searchLoadingMore.value} " +
                    "hasMore=${searchHasMore.value} (expect false/false)")
            })
        }
    }

    /**
     * 验收用（离线可跑）：直接喂一个「上一本书」的过期详情结果，验证它会被丢弃。
     *
     * 步骤：开 A → 记录代数 → 开 B → 用 A 的代数调用 applyDetailPayload，
     * 期望栏目仍然是 B；再用当前代数调一次，期望这次真的生效。
     */
    @When[debug]
    public func runStalePayloadSelfTest(): Unit {
        let _ = spawn {=>
            sleep(700 * Duration.millisecond)
            postToUi({=>
                openBook(BookCell(111, "hashA", "书 A", "作者 A", "", ""))
                let staleGeneration = detailGeneration
                openBook(BookCell(222, "hashB", "书 B", "作者 B", "", ""))
                // 伪造 A 的迟到响应
                let info = BookInfo()
                info.title = "STALE-A"
                let payload = DetailPayload(Some(info), ArrayList<BookFormat>(), "")
                applyDetailPayload(payload, staleGeneration)
                writeDebugLog("staletest: after stale apply title=${detailTitle.value} " +
                    "id=${detailId.value} (expect 书 B / 222)")
                // 同代数再喂一次：应当生效（证明守卫没有一刀切）
                let info2 = BookInfo()
                info2.title = "FRESH-B"
                let payload2 = DetailPayload(Some(info2), ArrayList<BookFormat>(), "")
                applyDetailPayload(payload2, detailGeneration)
                writeDebugLog("staletest: after fresh apply title=${detailTitle.value} " +
                    "id=${detailId.value} (expect FRESH-B / 222)")
                // 评论：过期分页结果同样必须被丢弃
                comments.value = ArrayList<CommentCell>()
                let staleComments = CommentsPayload(ArrayList<CommentCell>(), false, 20, "")
                applyComments(staleComments, true, staleGeneration)
                writeDebugLog("staletest: after stale comments commentError='${commentsError.value}' " +
                    "loading=${commentsLoading.value} (expect empty/false)")
            })
        }
    }

    /**
     * 验收用：自检「A 未返回就点 B」的竞态。
     *
     * 等首页加载完 → 打开第 1 本 → 150ms 后立刻打开第 2 本 →
     * 等两本书的请求都回来，看最终显示的是不是 B。
     */
    @When[debug]
    public func runDetailRaceSelfTest(): Unit {
        let _ = spawn {=>
            sleep(3000 * Duration.millisecond)
            postToUi({=>
                if (popular.value.size < 2) {
                    writeDebugLog("race test: popular not enough (${popular.value.size})")
                    return
                }
                let a = popular.value[0]
                let b = popular.value[1]
                writeDebugLog("race test: A=${a.id} ${a.title} | B=${b.id} ${b.title}")
                openBook(a)
            })
            sleep(150 * Duration.millisecond)
            postToUi({=>
                if (popular.value.size >= 2) {
                    let b = popular.value[1]
                    writeDebugLog("race test: opening B=${b.id} ${b.title}")
                    openBook(b)
                }
            })
            sleep(8000 * Duration.millisecond)
            postToUi({=>
                let expected = if (popular.value.size >= 2) { popular.value[1].id } else { -1 }
                writeDebugLog("race result: id=${detailId.value} expected=${expected} " +
                    "title=${detailTitle.value} descLen=${detailDescription.value.size} " +
                    "loading=${detailLoading.value}")
            })
        }
    }

    /** 验收用：自检搜索结果分页（第 1 页 → 自动加载第 2 页）。 */
    @When[debug]
    public func runSearchPagingSelfTest(keyword: String): Unit {
        let _ = spawn {=>
            sleep(1200 * Duration.millisecond)
            postToUi({=>
                searchText.value = keyword
                submitSearch()
            })
            sleep(4000 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("search paging: page1 count=${results.value.size} hasMore=${searchHasMore.value}")
                loadMoreSearch()
            })
            sleep(4000 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("search paging: after page2 count=${results.value.size} " +
                    "hasMore=${searchHasMore.value} loadingMore=${searchLoadingMore.value}")
            })
        }
    }

    /** 验收用：自检详情返回栈（离线也能跑，不依赖网络数据）。 */
    @When[debug]
    public func runNavStackSelfTest(): Unit {
        let _ = spawn {=>
            sleep(900 * Duration.millisecond)
            postToUi({=>
                writeDebugLog("navselftest: open A id=${detailId.value}")
                openBook(BookCell(111, "hashA", "书 A", "作者 A", "", ""))
                writeDebugLog("navselftest: A opened id=${detailId.value} history=${detailHistory.size}")
            })
            sleep(400 * Duration.millisecond)
            postToUi({=>
                openBook(BookCell(222, "hashB", "书 B", "作者 B", "", ""))
                writeDebugLog("navselftest: B opened id=${detailId.value} history=${detailHistory.size}")
            })
            sleep(400 * Duration.millisecond)
            postToUi({=>
                closeDetail()
                writeDebugLog("navselftest: after back id=${detailId.value} title=${detailTitle.value} history=${detailHistory.size}")
            })
            sleep(300 * Duration.millisecond)
            postToUi({=>
                closeDetail()
                writeDebugLog("navselftest: after 2nd back open=${detailOpen.value} id=${detailId.value}")
            })
        }
    }

    /** 验收用：延迟 delayMs 后点「返回」。 */
    @When[debug]
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
    @When[debug]
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
    @When[debug]
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
        searchPage = 1
        searchHasMore.value = false
        searchLoadingMore.value = false
        tab.value = TAB_HOME
    }

    /* -------------------------------------------------- 详情 */

    /** 打开图书详情页（二级页面）。 */
    public func openBook(cell: BookCell): Unit {
        writeDebugLog("openBook: ${cell.id} ${cell.title}")
        // 先让上一本书还在路上的请求全部作废（见 applyDetailPayload 的 generation 检查）
        detailGeneration += 1
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
        detailSaved.value = false
        favoriteBusy.value = false
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
        let generation = detailGeneration
        let id = cell.id
        let hash = cell.hash
        match (cell.info) {
            case Some(info) =>
                // 搜索/收藏接口本来就返回完整书籍信息：直接渲染，不再请求详情。
                writeDebugLog("detail: from list (no fetch) id=${id}")
                // 只后台补「可选格式」（下载版本菜单需要，详情页本身不需要）。
                applyBookInfo(info)
                detailLoading.value = false
                let _ = spawn {=>
                    let formats = loadFormatsSafely(clientBox.value, id, hash)
                    postToUi({=> applyDetailFormats(formats, generation) })
                }
            case None =>
                writeDebugLog("detail: fetch required id=${id}")
                let _ = spawn {=>
                    let payload = DetailPayload.load(clientBox.value, id, hash)
                    postToUi({=> applyDetailPayload(payload, generation) })
                }
        }
    }

    /**
     * 把后台详情结果写回 State（UI 线程）。
     *
     * `generation` 必须仍是当前详情代数：A 还没返回就点开 B 时，A 的结果要丢掉，
     * 否则会把 B 的页面覆盖成 A 的内容。
     */
    private func applyDetailPayload(payload: DetailPayload, generation: Int64): Unit {
        if (generation != detailGeneration) {
            writeDebugLog("drop stale detail payload: gen=${generation} current=${detailGeneration}")
            return
        }
        match (payload.info) {
            case Some(info) =>
                applyBookInfo(info)
            case None =>
                detailError.value = "加载详情失败：${payload.error}"
        }
        detailFormats.value = payload.formats
        detailLoading.value = false
    }

    /** 把一本书的完整信息写进详情页 State（列表已经带全量数据时直接渲染）。 */
    private func applyBookInfo(info: BookInfo): Unit {
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
        detailSaved.value = info.saved()
        detailError.value = ""
    }

    /** 拉「可选格式」：失败时返回空列表（详情页本身不受影响）。 */
    private func loadFormatsSafely(client: ZlibClient, id: Int64, hash: String): ArrayList<BookFormat> {
        try {
            BookApi.formats(client, id, hash)
        } catch (_: ZlibError) {
            ArrayList<BookFormat>()
        }
    }

    /** 后台补「可选格式」的结果（列表已给详情时只差这一项）。 */
    private func applyDetailFormats(formats: ArrayList<BookFormat>, generation: Int64): Unit {
        if (generation != detailGeneration) {
            return
        }
        detailFormats.value = formats
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
    /** 详情加载失败后的「重试」：按当前 id/hash 重新拉一次详情。 */
    public func retryDetail(): Unit {
        if (detailId.value <= 0 || detailHash.value.isEmpty()) {
            return
        }
        detailError.value = ""
        openBookById(detailId.value, detailHash.value)
    }

    /** 评论加载失败后的「重试」。 */
    public func retryComments(): Unit {
        commentsError.value = ""
        commentsLoaded = false
        commentsLoading.value = false
        ensureCommentsLoaded()
    }

    /* -------------------------------------------------- 收藏 */

    /**
     * 详情页「收藏 / 取消收藏」。
     *
     * 收藏只需要 book id；失败时用 toast 说明原因（登录过期会被明确提示）。
     * 成功后让「收藏」页下次进入时重新拉取。
     */
    public func toggleDetailFavorite(): Unit {
        if (!loggedIn.value) {
            showToastNow("收藏需要登录：请先在「账号」页登录")
            return
        }
        if (detailLoading.value) {
            showToastNow("正在获取中，请稍后")
            return
        }
        if (favoriteBusy.value || detailId.value <= 0) {
            return
        }
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                showToastNow("客户端未就绪", kind: ToastKind.Error)
                return
        }
        let id = detailId.value
        let saving = !detailSaved.value
        favoriteBusy.value = true
        let _ = spawn {=>
            try {
                if (saving) {
                    BookApi.save(clientBox.value, id)
                } else {
                    BookApi.unsave(clientBox.value, id)
                }
                postToUi({=>
                    favoriteBusy.value = false
                    // 请求期间换了书：不要改动当前详情页的收藏态
                    if (detailId.value == id) {
                        detailSaved.value = saving
                    }
                    invalidateFavorites()
                    showToastNow(if (saving) { "已收藏" } else { "已取消收藏" },
                kind: if (saving) { ToastKind.Success } else { ToastKind.Info })
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    favoriteBusy.value = false
                    showToastNow("收藏失败：${friendlyErrorMessage(failure)}", kind: ToastKind.Error)
                })
            }
        }
    }

    /** 收藏变了：收藏页下次进入时重新拉一次。 */
    public func invalidateFavorites(): Unit {
        favoritesLoaded = false
        favoritesNextPage.value = 0
        if (!favoritesLoading.value) {
            favorites.value = ArrayList<BookCell>()
        }
    }

    /** 验收用：延迟后点一次「收藏」按钮。 */
    @When[debug]
    public func scheduleToggleFavoriteForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> toggleDetailFavorite() })
        }
    }

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
        let generation = detailGeneration
        writeDebugLog("loadRelated: id=${id} gen=${generation}")
        detailRelatedLoading.value = true
        detailRelatedError.value = ""
        let _ = spawn {=>
            try {
                let briefs = BookApi.similar(clientBox.value, id, hash)
                let cells = cellsFromBriefs(briefs, clientBox.value.currentSiteUrl())
                postToUi({=>
                    if (generation != detailGeneration) {
                        writeDebugLog("drop stale related: gen=${generation}")
                        return
                    }
                    detailRelated.value = cells
                    detailRelatedLoaded = true
                    detailRelatedLoading.value = false
                })
            } catch (failure: ZlibError) {
                postToUi({=>
                    if (generation != detailGeneration) {
                        return
                    }
                    detailRelatedError.value = "相关书籍加载失败：${friendlyErrorMessage(failure)}"
                    detailRelatedLoading.value = false
                })
            }
        }
    }

    /** 验收/脚本用：没有列表项时按 id + hash 直接打开详情页。 */
    public func openBookById(id: Int64, hash: String): Unit {
        match (this.client) {
            case None =>
                pendingBookId = id
                pendingBookHash = hash
                writeDebugLog("openBook queued until client ready: id=${id}")
                return
            case Some(_) => ()
        }
        openBook(BookCell(id, hash, "（加载中…）", "", "", ""))
    }

    /** 验收用：按热门列表下标打开一本书（走真实卡片路径，带封面）。 */
    @When[debug]
    public func openPopularForTest(index: Int64): Unit {
        if (index < 0 || index >= Int64(popular.value.size)) {
            writeDebugLog("openPopularForTest: index ${index} out of range ${popular.value.size}")
            return
        }
        openBook(popular.value[index])
    }

    /** 验收用：延时切换侧栏展开状态（观察动画）。 */
    @When[debug]
    public func scheduleRailToggleForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> railExpanded.value = !railExpanded.value })
        }
    }

    /** 验收用：等搜索结果出来后打开第 index 本。 */
    @When[debug]
    public func openSearchResultForTest(index: Int64): Unit {
        let _ = spawn {=>
            var tries: Int64 = 0
            while (tries < 240) {
                sleep(50 * Duration.millisecond)
                tries += 1
                postToUi({=>
                    if (!detailOpen.value && results.value.size > index) {
                        openBook(results.value[index])
                    }
                })
            }
        }
    }

    /** 验收用：切到收藏页，等收藏加载完后打开第 index 本。 */
    @When[debug]
    public func openFavoriteForTest(index: Int64): Unit {
        tab.value = TAB_FAVORITES
        let _ = spawn {=>
            var tries: Int64 = 0
            while (tries < 200) {
                sleep(50 * Duration.millisecond)
                tries += 1
                postToUi({=>
                    if (!detailOpen.value && favorites.value.size > index) {
                        openBook(favorites.value[index])
                    }
                })
            }
        }
    }

    /** 关闭详情页，回到来处。 */
    public func closeDetail(): Unit {
        detailGeneration += 1
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
        detailGeneration += 1
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
        detailFormatIndex.value = snapshot.formatIndex
        detailSaved.value = snapshot.saved
        favoriteBusy.value = false
        // 相关书籍 / 评论直接复用快照：不再清空重拉，返回时页面内容与滚动位置保持不变。
        detailRelated.value = snapshot.related
        detailRelatedError.value = ""
        detailRelatedLoading.value = false
        detailRelatedLoaded = snapshot.relatedLoaded
        comments.value = snapshot.comments
        commentsError.value = ""
        commentsDisabled.value = snapshot.commentsDisabled
        commentsNextOffset.value = snapshot.commentsNextOffset
        commentsVisible.value = snapshot.commentsVisible
        commentsLoaded = snapshot.commentsLoaded
        // 只有当时还没加载过的分段才补一次请求
        if (snapshot.section == 1 && !snapshot.commentsLoaded) {
            ensureCommentsLoaded()
        } else if (snapshot.section == 2 && !snapshot.relatedLoaded) {
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
    @When[debug]
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
        booklistGeneration += 1
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
        booklistGeneration += 1
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
        let generation = booklistGeneration
        booklistLoading.value = true
        let _ = spawn {=>
            let payload = BooklistBooksPayload.load(clientBox.value, readlistId, page, site)
            postToUi({=> applyBooklistBooks(payload, page, generation) })
        }
    }

    private func applyBooklistBooks(payload: BooklistBooksPayload, page: Int64, generation: Int64): Unit {
        // 期间点开了别的书单：这批结果属于上一个书单，丢掉
        if (generation != booklistGeneration) {
            writeDebugLog("drop stale booklist books: gen=${generation} page=${page}")
            return
        }
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
                // 启动期客户端还在后台创建：先记下，就绪后自动重试
                pendingLogin = true
                loginMessage.value = "正在连接…"
                writeDebugLog("login queued until client ready")
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
        favoritesGeneration += 1
        favoritesLoaded = false
        favorites.value = ArrayList<BookCell>()
        favoritesNextPage.value = 0
        writeDebugLog("login ok: uid=${outcome.uid} name=${outcome.name}")
        accountName.value = outcome.name
        accountId.value = outcome.uid
        loginMessage.value = "登录成功"
        loginPassword.value = ""
        let loginEmailValue = loginEmail.value
        match (outcome.credential) {
            case Some(credential) =>
                // 新账号加入账号列表；列表里还没有默认账号时它就是默认
                upsertAccount(credential, loginEmailValue, outcome.name)
            case None => ()
        }
        loginDialogOpen.value = false
        loginPassword.value = ""
        loginMessage.value = "登录成功"
        refreshProfile()
        // 登录后首页从「热门」换成「个性化推荐」
        reloadPopular()
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
        // 只退出当前会话；已保存的账号仍留在列表里（下次可切换回来）
        loggedIn.value = false
        favoritesGeneration += 1
        profileGeneration += 1
        favoritesLoaded = false
        favorites.value = ArrayList<BookCell>()
        favoritesNextPage.value = 0
        favoritesError.value = ""
        accountName.value = ""
        accountId.value = ""
        quotaKnown.value = false
        quotaToday.value = 0
        quotaLimit.value = 0
        quotaLoading.value = false
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
            ZlibClient.create(baseUrl: site, seed: site)
        } catch (_: ZlibError) {
            ZlibClient.create()
        }
        this.client = Some(ClientBox(anonymous))
        // 回到游客态：首页换回热门
        reloadPopular()
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
        profileGeneration += 1
        let generation = profileGeneration
        quotaLoading.value = true
        let _ = spawn {=>
            let outcome = ProfileOutcome.load(clientBox.value)
            postToUi({=> applyProfileOutcome(outcome, generation) })
        }
    }

    private func applyProfileOutcome(outcome: ProfileOutcome, generation: Int64): Unit {
        // 期间换号/登出了：旧账号的资料不能写进来
        if (generation != profileGeneration) {
            writeDebugLog("drop stale profile: gen=${generation}")
            return
        }
        quotaLoading.value = false
        if (!outcome.ok) {
            // 凭证失效（改密码/风控）时提示用户重新登录，但不静默清掉本地状态
            loginMessage.value = "账号状态失效：${outcome.error}"
            return
        }
        quotaToday.value = outcome.today
        quotaLimit.value = outcome.limit
        quotaKnown.value = true
        if (!outcome.name.isEmpty()) {
            accountName.value = outcome.name
        }
        if (!outcome.uid.isEmpty()) {
            accountId.value = outcome.uid
        }
        loginMessage.value = "已登录 · ${outcome.quota}"
        writeDebugLog("profile ok: ${outcome.quota}")
    }

    /* -------------------------------------------------- 设置 / 网络配置 */

    /** 启动时读回配置（主题 / 下载目录 / 站点）。 */
    /**
     * 首次运行（或配置里站点为空）时，把库内默认站点落盘。
     *
     * - `activeSite` 默认 `ZlibHost.DEFAULT_URL`；
     * - `seedSites` 默认 = `ZlibHost.MIRRORS`（官方镜像候选，换站用）；
     * - `officialSites` 是只读的官方候选列表（设置页展示/可直接点选）。
     */
    private func seedDefaultSitesIfNeeded(): Unit {
        officialSites.value = ArrayList<String>()
        for (mirror in ZlibHost.MIRRORS) {
            officialSites.value.add(mirror)
        }
        var changed = false
        if (activeSite.value.isEmpty()) {
            activeSite.value = ZlibHost.DEFAULT_URL
            changed = true
        }
        if (seedSite.value.isEmpty()) {
            seedSite.value = ZlibHost.DEFAULT_URL
            changed = true
        }
        if (changed) {
            saveUserConfig()
            writeDebugLog("seeded default sites: active=${activeSite.value} seed=${seedSite.value}")
        }
    }

    private func loadUserConfig(): Unit {
        // 新格式：JSON（~/seline_read/config.json）
        let jsonText = readTextFile(Path(configJsonPath()))
        if (!jsonText.trimAscii().isEmpty()) {
            try {
                let obj = parseJsonObject(jsonText, path: "config.json")
                let theme = readString(obj, "theme")
                if (!theme.isEmpty()) {
                    let dark = theme != "light"
                    darkMode.value = dark
                    setSelineTheme(if (dark) { SelineTheme.dark() } else { SelineTheme.light() })
                }
                let dir = readString(obj, "downloadDir")
                if (!dir.isEmpty()) {
                    downloadDir.value = dir
                }
                activeSite.value = readString(obj, "activeSite")
                customSites.value = ArrayList<String>()
                for (item in arrayFieldOf(obj, "customSites")) {
                    let text = item.asString().getValue().trimAscii()
                    if (!text.isEmpty()) {
                        customSites.value.add(text)
                    }
                }
                // 单个种子站；兼容旧版 seedSites 数组（取第一个）
                seedSite.value = readString(obj, "seedSite")
                if (seedSite.value.isEmpty()) {
                    let legacySeeds = arrayFieldOf(obj, "seedSites")
                    if (!legacySeeds.isEmpty()) {
                        seedSite.value = legacySeeds[0].asString().getValue().trimAscii()
                    }
                }
                downloadPathInput.value = downloadDir.value
                seedDefaultSitesIfNeeded()
                writeDebugLog("config loaded(json): dark=${darkMode.value} sites=${customSites.value.size} seed=${seedSite.value} active=${activeSite.value}")
                return
            } catch (_: Exception) {
                writeDebugLog("config.json unreadable; falling back to legacy config.txt")
            }
        }
        // 旧格式：key=value 文本，读一次后改写成 JSON
        let legacyText = readTextFile(Path(legacyConfigPath()))
        if (!legacyText.trimAscii().isEmpty()) {
            let config = readUserConfig()
        match (config.get("theme")) {
            case Some(value) =>
                let dark = value != "light"
                darkMode.value = dark
                setSelineTheme(if (dark) { SelineTheme.dark() } else { SelineTheme.light() })
            case None => ()
        }
        match (config.get("downloadDir")) {
            case Some(value) => if (!value.isEmpty()) {
                downloadDir.value = value
            }
            case None => ()
        }
        downloadPathInput.value = downloadDir.value
        match (config.get("activeSite")) {
            case Some(value) => activeSite.value = value
            case None => ()
        }
        // 自定义站（多行，用 | 分隔）
        match (config.get("customSites")) {
            case Some(value) => for (item in value.split("|")) {
                let trimmed = item.trimAscii()
                if (!trimmed.isEmpty()) {
                    customSites.value.add(trimmed)
                }
            }
            case None => ()
        }
        match (config.get("seedSites")) {
            case Some(value) => for (item in value.split("|")) {
                let trimmed = item.trimAscii()
                if (!trimmed.isEmpty() && seedSite.value.isEmpty()) {
                    seedSite.value = trimmed
                }
            }
            case None => ()
        }
        match (config.get("seedSite")) {
            case Some(value) => if (!value.trimAscii().isEmpty()) {
                seedSite.value = value.trimAscii()
            }
            case None => ()
        }
            saveUserConfig()
            try {
                remove(Path(legacyConfigPath()))
            } catch (_: Exception) {
                ()
            }
            writeDebugLog("legacy config migrated to json")
        }
        seedDefaultSitesIfNeeded()
        downloadPathInput.value = downloadDir.value
        writeDebugLog("user config loaded: dark=${darkMode.value} sites=${customSites.value.size} seed=${seedSite.value} active=${activeSite.value}")
    }

    /** 把当前配置写回磁盘（JSON：`~/seline_read/config.json`）。 */
    public func saveUserConfig(): Unit {
        let obj = JsonObject()
        obj.put("theme", JsonString(if (darkMode.value) { "dark" } else { "light" }))
        obj.put("downloadDir", JsonString(downloadDir.value))
        obj.put("activeSite", JsonString(activeSite.value))
        let custom = JsonArray()
        for (site in customSites.value) {
            custom.add(JsonString(site))
        }
        obj.put("customSites", custom)
        obj.put("seedSite", JsonString(seedSite.value))
        writeTextFile(Path(configJsonPath()), obj.toJsonString())
    }
    /** 设置页页签切换。 */
    public func selectSettingsTab(index: Int64): Unit {
        if (index >= 0 && index <= 2) {
            settingsTab.value = index
        }
    }

    /** 下载路径输入框：应用到 downloadDir 并持久化。 */
    public func applyDownloadPath(): Unit {
        let value = downloadPathInput.value.trimAscii()
        if (value.isEmpty()) {
            return
        }
        downloadDir.value = value
        try {
            Directory.create(Path(value), recursive: true)
        } catch (_: Exception) {
            ()
        }
        saveUserConfig()
        networkMessage.value = "下载目录已保存：${value}"
    }

    /** 添加一个自定义站点（会去重并规范成 `https://host`）。 */
    public func addCustomSite(): Unit {
        let value = normalizeSiteInput(siteInput.value)
        if (value.isEmpty()) {
            networkMessage.value = "站点地址不能为空"
            return
        }
        for (existing in customSites.value) {
            if (existing == value) {
                networkMessage.value = "已经在列表里：${value}"
                return
            }
        }
        customSites.value.add(value)
        siteInput.value = ""
        networkMessage.value = "已添加站点：${value}"
        saveUserConfig()
    }

    /** 删除自定义站点（官方 3 个占位不可删）。 */
    public func removeCustomSite(url: String): Unit {
        for (index in 0..customSites.value.size) {
            if (customSites.value[index] == url) {
                customSites.value.remove(at: index)
                if (activeSite.value == url) {
                    activeSite.value = if (customSites.value.isEmpty()) {
                        ""
                    } else {
                        customSites.value[0]
                    }
                    applyActiveSite()
                }
                networkMessage.value = "已删除站点：${url}"
                saveUserConfig()
                return
            }
        }
    }

    /** 保存种子站（单个引导站）。 */
    public func applySeedSite(): Unit {
        var value = normalizeSiteInput(seedInput.value)
        if (value.isEmpty()) {
            value = seedSite.value
        }
        if (value.isEmpty()) {
            value = ZlibHost.DEFAULT_URL
        }
        seedSite.value = value
        seedInput.value = ""
        saveUserConfig()
        rebuildClientWithSeed()
        networkMessage.value = "种子站已保存：${value}"
        writeDebugLog("seed site -> ${value}")
    }

    /** 种子站变了要重建客户端（ZlibSites 的种子列表只在创建时传入）。 */
    private func rebuildClientWithSeed(): Unit {
        let box = match (this.client) {
            case Some(value) => value
            case None => return
        }
        let current = box.value
        let baseUrl = current.sites.customUrl()
        let credential = current.credential
        let seed = if (seedSite.value.isEmpty()) {
            ZlibHost.DEFAULT_URL
        } else {
            seedSite.value
        }
        try {
            let rebuilt = ZlibClient.create(baseUrl: baseUrl, credential: credential, seed: seed)
            current.close()
            this.client = Some(ClientBox(rebuilt))
        } catch (failure: ZlibError) {
            writeDebugLog("rebuild client for seed failed: ${failure.detail}")
        }
    }
    /** 用单选框选中某个站点：立刻切到它并持久化。 */
    public func selectActiveSite(url: String): Unit {
        activeSite.value = url
        applyActiveSite()
        saveUserConfig()
        networkMessage.value = "当前站点：${url}"
    }

    /** 把 activeSite 应用到客户端。 */
    public func applyActiveSite(): Unit {
        let url = activeSite.value
        if (url.isEmpty()) {
            return
        }
        match (this.client) {
            case Some(box) =>
                try {
                    box.value.setCustomSite(url)
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
    }

    /**
     * 种子站回退成功后：把新站点**覆盖**到自定义站点列表与当前站点，并持久化。
     *
     * zlibraryAPI4CJ 内部换站后 `currentSiteUrl()` 就是新地址；这里把它写回配置，
     * 下次启动直接用新地址，不用再走一遍种子站。
     */
    public func adoptRefreshedSite(): Unit {
        let current = match (this.client) {
            case Some(box) => box.value.currentSiteUrl()
            case None => ""
        }
        if (current.isEmpty() || current == activeSite.value) {
            return
        }
        writeDebugLog("site refreshed -> ${current}")
        // 覆盖：原来选中的自定义站换成新地址
        var replaced = false
        for (index in 0..customSites.value.size) {
            if (customSites.value[index] == activeSite.value) {
                customSites.value[index] = current
                replaced = true
            }
        }
        if (!replaced && !customSites.value.isEmpty()) {
            customSites.value[0] = current
        }
        activeSite.value = current
        saveUserConfig()
        status.value = "站点已更新：${current}"
    }

    /** 「重新拉取站点」：走种子站换新地址，成功后覆盖自定义站点。 */
    public func refreshSiteNow(): Unit {
        match (this.client) {
            case Some(box) =>
                let refreshed = try {
                    box.value.refreshSite(force: true)
                } catch (_: ZlibError) {
                    false
                }
                if (refreshed) {
                    adoptRefreshedSite()
                    networkMessage.value = "站点已更新：${box.value.currentSiteUrl()}"
                } else {
                    networkMessage.value = "当前站和种子站都不可用，刷新失败"
                }
            case None => networkMessage.value = "客户端未就绪"
        }
    }

    /** 规范化用户输入的站点地址。 */
    private func normalizeSiteInput(raw: String): String {
        var value = raw.trimAscii()
        if (value.isEmpty()) {
            return ""
        }
        if (value.endsWith("/")) {
            value = value[0..value.size - 1]
        }
        if (!value.startsWith("http://") && !value.startsWith("https://")) {
            value = "https://" + value
        }
        value
    }

    /* -------------------------------------------------- 主题 */


    /**
     * 切换深浅色：用 chui 自带的圆形揭示过渡（`DesktopApp.transitionTheme`）。
     *
     * 它会冻结新旧两帧，再以**鼠标位置（= 刚点的主题按钮）**为圆心、
     * 用 `renderer.texturedCircle` 把新主题从圆内逐渐扩散出来 —— 颜色是跟着
     * 辐射边界走的，而不是整体瞬切。
     */
    /** 构建期钩子：主题过渡期间让"新帧"用目标主题构建（否则构建期抓色仍是旧主题）。 */
    public func prepareThemeBuild(): Unit {
        if (themeSwitching) {
            setSelineTheme(if (themeTargetDark) { SelineTheme.dark() } else { SelineTheme.light() })
        }
    }

    public func toggleTheme(originX: Float32, originY: Float32): Unit {
        if (themeSwitching) {
            return
        }
        let nextDark = !darkMode.value
        themeTargetDark = nextDark
        themeSwitching = true
        // 注意：**不立刻**改 darkMode —— 点击这一帧要按旧主题构建，chui 才会冻出正确的"旧帧"
        let ms = themeTransitionMs()
        writeDebugLog("theme: transition -> dark=${nextDark} (${ms}ms)")
        match (app) {
            case Some(value) =>
                value.transitionTheme(selineChuiThemeFor(nextDark), durationMs: UInt64(ms))
            case None =>
                setSelineTheme(if (nextDark) { SelineTheme.dark() } else { SelineTheme.light() })
                darkMode.value = nextDark
                themeSwitching = false
        }
        // chui 不会回调过渡结束：自己按 duration 收尾
        let _ = spawn {=>
            sleep((ms + 150) * Duration.millisecond)
            postToUi({=>
                darkMode.value = themeTargetDark
                themeSwitching = false
                saveUserConfig()
                writeDebugLog("theme: finalized dark=${darkMode.value}")
            })
        }
    }


    /** 验收用：从侧栏主题按钮位置触发一次切换。 */
    @When[debug]
    public func postThemeToggleForTest(): Unit {
        let appRef = match (app) {
            case Some(value) => value
            case None => return
        }
        let _ = appRef.postToUi({=> toggleTheme(0.0, 0.0)})
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
        writeDebugLog("theme: switched dark=${nextDark}")
    }

    /** 验收用：造几个假账号，用来截图账号页/登录弹窗。 */
    @When[debug]
    public func forceFakeAccountsForShot(openDialog: Bool): Unit {
        accounts.value = ArrayList<AccountEntry>()
        accounts.value.add(AccountEntry("liluo@example.com", "liluo", "43928338",
            "fakekey1", "zh", true))
        accounts.value.add(AccountEntry("work@example.com", "工作账号", "51234001",
            "fakekey2", "zh", false))
        accounts.value.add(AccountEntry("", "", "33445566", "fakekey3", "en", false))
        if (openDialog) {
            loginDialogOpen.value = true
        }
        writeDebugLog("fake accounts for shot: ${accounts.value.size}")
    }

    /* -------------------------------------------------- Toast */

    /** 弹一条 toast（右下角），3.2 秒后自动消失；`kind` 决定图标与颜色。 */
    public func showToast(text: String, kind!: ToastKind = ToastKind.Info): Unit {
        if (text.isEmpty()) {
            return
        }
        toastSeq += 1
        let seq = toastSeq
        toastText.value = text
        toastKind.value = kind
        toastSpring.reset(0.0)
        writeDebugLog("toast: ${text}")
        let _ = spawn {=>
            sleep(3200 * Duration.millisecond)
            postToUi({=>
                if (seq == toastSeq) {
                    toastText.value = ""
                }
            })
        }
    }

    /**
     * 页面渲染时调用：错误文案变了才弹 toast（避免每帧重复弹）。
     *
     * 用 `spawn + postToUi` 延后到构建之外再写 State：构建期写 State 会触发重建。
     */
    public func toastIfChanged(text: String): Unit {
        if (text.isEmpty()) {
            lastToastedText = ""
            return
        }
        if (text == lastToastedText) {
            return
        }
        lastToastedText = text
        let copy = text
        let _ = spawn {=>
            postToUi({=> showToast(copy, kind: ToastKind.Error) })
        }
    }

    /**
     * 立即弹一条 toast，**不走文案去重**。
     *
     * `toastIfChanged` 是给"页面错误态"用的：同一句话只弹一次。
     * 用户主动点按钮（如未登录点下载）每次都应该有反馈，用这个。
     */
    public func showToastNow(text: String, kind!: ToastKind = ToastKind.Info): Unit {
        lastToastedText = text
        showToast(text, kind: kind)
    }

    /** 验收用：延时弹一条指定语义的 toast（截图/联调用）。 */
    @When[debug]
    public func showToastAfterForTest(delayMs: Int64, text: String, kind!: ToastKind): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> showToastNow(text, kind: kind) })
        }
    }

    /** 验收用：循环弹同一条 toast，保证截图时一定能拍到。 */
    @When[debug]
    public func startToastLoopForTest(text: String, kind!: ToastKind): Unit {
        let _ = spawn {=>
            while (true) {
                sleep(1200 * Duration.millisecond)
                postToUi({=> showToastNow(text, kind: kind) })
            }
        }
    }

    /** 点击/切换页面时立即收起 toast。 */
    public func dismissToast(): Unit {
        toastSeq += 1
        toastText.value = ""
        toastSpring.reset(0.0)
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
        favoritesGeneration += 1
        let generation = favoritesGeneration
        favoritesLoading.value = true
        if (reset) {
            favoritesError.value = ""
        }
        let _ = spawn {=>
            try {
                let page = UserApi.saved(clientBox.value, page: target, limit: 20)
                // 收藏接口的元素不带 `_isUserSavedBook`，但这个列表本身就是已收藏
                for (book in page.books) {
                    book.isUserSavedBook = Some(true)
                }
                let cells = cellsFromBooks(page.books, clientBox.value.currentSiteUrl())
                writeDebugLog("favorites loaded: page=${target} count=${cells.size} " +
                    "current=${page.pagination.current} total=${page.pagination.totalItems}")
                postToUi({=>
                    // 期间登出/换号/重载了：这批结果已过期
                    if (generation != favoritesGeneration) {
                        writeDebugLog("drop stale favorites: gen=${generation}")
                        return
                    }
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
                    if (generation != favoritesGeneration) {
                        return
                    }
                    favoritesError.value = "收藏加载失败：${friendlyErrorMessage(failure)}"
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

    /**
     * 点「下载」按钮：未登录时直接提示（详情页不再常驻「下载需要先登录」文案），
     * 已登录才展开下载菜单。
     */
    public func toggleDownloadMenuOrPrompt(): Unit {
        if (!loggedIn.value) {
            showToastNow("下载需要登录：请先在「账号」页登录")
            return
        }
        if (detailLoading.value) {
            showToastNow("正在获取中，请稍后")
            return
        }
        toggleDownloadMenu()
    }

    /** 用按钮当前矩形打开下载菜单（锚点只在打开瞬间取一次）。 */
    public func openDownloadMenu(): Unit {
        // 详情还在加载：格式列表和下载链接都还没拿到，弹菜单只会给一个不可用的
        // 「默认下载链接（原书）」，所以这里先提示「正在获取中」。
        if (detailLoading.value) {
            showToastNow("正在获取中，请稍后")
            return
        }
        menuAnchorX = downloadAnchor.x
        menuAnchorY = downloadAnchor.y + downloadAnchor.h + 6.0
        downloadMenuSpring.reset(0.0)
        downloadMenuClosing.value = false
        downloadMenuOpen.value = true
    }

    /** 验收用：延迟 delayMs 后打开下载菜单（等按钮完成 layout）。 */
    @When[debug]
    public func scheduleOpenDownloadMenuForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> openDownloadMenu() })
        }
    }

    /** 菜单锚点（打开时锁定）。 */
    /**
     * 菜单左上角 X。
     *
     * 优先用按钮**当前**矩形（每帧 layout 上报）：锚点锁死在打开瞬间时，
     * 只要那一帧按钮还没完成布局（宽高为 0）或窗口刚变过尺寸，菜单就会飘到别处。
     * 按钮在固定工具栏里，位置本来就稳定，用实时值更安全。
     */
    public func downloadMenuX(): Float32 {
        if (downloadAnchor.w > 0.0) {
            downloadAnchor.x
        } else {
            menuAnchorX
        }
    }

    public func downloadMenuY(): Float32 {
        if (downloadAnchor.w > 0.0) {
            downloadAnchor.y + downloadAnchor.h + 6.0
        } else {
            menuAnchorY
        }
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
        let generation = detailGeneration
        commentsLoading.value = true
        commentsError.value = ""
        let _ = spawn {=>
            let payload = CommentsPayload.load(clientBox.value, bookId, offset)
            postToUi({=> applyComments(payload, reset, generation) })
        }
    }

    private func applyComments(payload: CommentsPayload, reset: Bool, generation: Int64): Unit {
        // 期间换了书：这批评论属于上一本，丢掉
        if (generation != detailGeneration) {
            writeDebugLog("drop stale comments: gen=${generation} current=${detailGeneration}")
            return
        }
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

    /** 验收用：延迟后点一次「下载」按钮（未登录走提示，已登录开菜单）。 */
    @When[debug]
    public func scheduleClickDownloadForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> toggleDownloadMenuOrPrompt() })
        }
    }

    /** 验收用：延迟后调用 downloadBook（验证「正在获取中，请稍后」提示）。 */
    @When[debug]
    public func scheduleDownloadBookForTest(delayMs: Int64): Unit {
        let _ = spawn {=>
            sleep(delayMs * Duration.millisecond)
            postToUi({=> downloadBook() })
        }
    }

    /** 验收/脚本用：直接按 id + hash 下载（会走与详情页按钮完全相同的路径）。 */
    public func downloadById(id: Int64, hash: String): Unit {
        match (this.client) {
            case None =>
                pendingDownloadId = id
                pendingDownloadHash = hash
                writeDebugLog("download queued until client ready: id=${id}")
                return
            case Some(_) => ()
        }
        detailId.value = id
        detailHash.value = hash
        detailFormatIndex.value = 0
        downloadBook()
    }

    /** 验收用：登录成功后自动下载指定书。 */
    @When[debug]
    public func setAutoDownload(id: Int64, hash: String): Unit {
        autoDownloadTarget = "${id}|${hash}"
    }

    /** 下载当前详情页选中的版本（走 selineDownload；zlib 不支持 Range，单线程）。 */
    public func downloadBook(): Unit {
        if (!loggedIn.value) {
            // 用户主动点击：每次都弹（不能走 toastIfChanged 的去重，否则第二次点击没反馈）
            showToastNow("下载需要登录：请先在「账号」页登录")
            return
        }
        if (detailId.value <= 0 || detailHash.value.isEmpty() || detailLoading.value) {
            // 详情还没回来：下载链接还在路上
            showToastNow("正在获取中，请稍后")
            return
        }
        // 链接由后台线程换（BookApi.file），先给即时反馈
        showToastNow("正在获取中，请稍后")
        let target = chosenTarget()
        let title = if (detailTitle.value.isEmpty()) {
            "书籍 ${target.id}"
        } else {
            detailTitle.value
        }
        let taskId = startDownload(target.id, target.hash, title, cover: detailCover.value)
        showToastNow("已加入下载队列（${taskId}）", kind: ToastKind.Success)
        detailError.value = ""
    }

    /**
     * 新建一个下载任务并立即开始。
     *
     * 阻塞的「换下载链接 + 下载」都在后台线程；进度通过 `postToUi` 写回。
     * 返回 taskId（下载页用它停止任务）。
     */
    public func startDownload(bookId: Int64, hash: String, title: String,
        cover!: String = ""): String {
        downloadSeq += 1
        let taskId = "${bookId}-${downloadSeq}"
        let item = DownloadItem(taskId, title, cover: cover)
        downloadItems.value.add(item)
        downloadsTick.value += 1
        writeDebugLog("download start: ${taskId} ${title}")
        let clientBox = match (this.client) {
            case Some(value) => value
            case None =>
                item.status = DL_FAILED
                item.error = "客户端未就绪"
                downloadsTick.value += 1
                return taskId
        }
        let dirValue = downloadDir.value
        let _ = spawn {=>
            try {
                let info = BookApi.file(clientBox.value, bookId, hash)
                if (!info.available()) {
                    postToUi({=>
                        item.status = DL_FAILED
                        item.error = "服务端没有提供可下载链接（可能没有权限）"
                        downloadsTick.value += 1
                    })
                    return
                }
                let fileName = info.fileName()
                try {
                    Directory.create(Path(dirValue), recursive: true)
                } catch (_: Exception) {
                    ()
                }
                let savePath = Path(dirValue).join(fileName).toString()
                let config = DownloadConfig()
                    .setUrl(info.downloadLink)
                    .setSavePath(savePath)
                    .setThreadCount(1)
                    .setEnableRange(false)
                    .setFileExistsAction(FileExistsAction.Rename)
                let task = DownloadTask(config)
                task.setProgressCallback({progress =>
                    postToUi({=>
                        item.downloadedBytes = progress.downloadedBytes
                        item.totalBytes = progress.totalBytes
                        item.speedText = progress.formattedSpeed
                        item.fileName = fileName
                        if (item.status != DL_STOPPED) {
                            item.status = DL_RUNNING
                        }
                        downloadsTick.value += 1
                    })
                })
                task.setCompleteCallback({=>
                    postToUi({=>
                        item.downloadedBytes = item.totalBytes
                        item.speedText = ""
                        item.status = DL_COMPLETED
                        downloadsTick.value += 1
                        writeDebugLog("download complete: ${taskId} ${fileName}")
                    })
                })
                task.setErrorCallback({failure =>
                    postToUi({=>
                        item.speedText = ""
                        item.status = DL_FAILED
                        item.error = failure.message
                        downloadsTick.value += 1
                        writeDebugLog("download failed: ${taskId} ${failure.message}")
                    })
                })
                task.setCancelCallback({=>
                    postToUi({=>
                        item.speedText = ""
                        if (item.status != DL_COMPLETED) {
                            item.status = DL_STOPPED
                        }
                        downloadsTick.value += 1
                    })
                })
                synchronized(downloadTaskLock) {
                    downloadTasks[taskId] = task
                }
                postToUi({=>
                    item.fileName = fileName
                    item.status = DL_RUNNING
                    downloadsTick.value += 1
                })
                task.start()
                task.await()
            } catch (failure: ZlibError) {
                postToUi({=>
                    item.status = DL_FAILED
                    item.error = failure.detail
                    downloadsTick.value += 1
                })
            } catch (failure: Exception) {
                postToUi({=>
                    item.status = DL_FAILED
                    item.error = failure.message
                    downloadsTick.value += 1
                })
            }
        }
        taskId
    }

    /** 停止下载（zlib 不支持断点续传，停止后不保留恢复）。 */
    public func stopDownload(taskId: String): Unit {
        let task = synchronized(downloadTaskLock) {
            match (downloadTasks.get(taskId)) {
                case Some(value) => Some(value)
                case None => Option<DownloadTask>.None
            }
        }
        match (task) {
            case Some(value) =>
                try {
                    value.cancel()
                    writeDebugLog("download cancel: ${taskId}")
                } catch (_: Exception) {
                    ()
                }
            case None => writeDebugLog("download cancel: task not found ${taskId}")
        }
    }

    /** 清掉已结束的下载记录。 */
    public func clearFinishedDownloads(): Unit {
        let kept = ArrayList<DownloadItem>()
        for (item in downloadItems.value) {
            if (item.active()) {
                kept.add(item)
            }
        }
        downloadItems.value = kept
        downloadsTick.value += 1
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
        // 纹理的生命周期归 chui 的 managed resources：它在 window.close() **之前**
        // 统一 close()，避免渲染器销毁后再 SDL_DestroyTexture（会导致堆损坏）。
        match (this.app) {
            case Some(value) => value.manage(texture)
            case None => ()
        }
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
            let worker = spawn {=> imageWorkerLoop() }
            imageWorkerFutures.add(worker)
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