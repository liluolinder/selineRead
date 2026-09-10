package SelineRead

import chui.*
import selineDownload.*
import std.collection.ArrayList
import std.env.*
import std.fs.{Directory, Path, exists}
import std.process.{ProcessRedirect, launch}
import std.sync.{AtomicInt64, AtomicBool, AtomicReference}
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.dataModel.*

// 统一的异步请求封装：后台线程请求，postToUi 回到 UI 线程更新 State

// ===== 下载事件通道（无锁轮询 · 多槽位）=====
// 下载线程绝不调用 postToUi（其内部有互斥锁，主循环每帧也在争用；主绿色线程
// 一旦在该锁上 park 可能被调度器迁移，触发 SDL owner 校验闪退/卡死——封面
// worker 同理，见 covers.cj 注释）。改为：每个下载任务独占一个槽位，下载线程
// 只写该槽的原子量，UI 线程每帧 pollDownloadRefresh 读取所有槽并落到 State。
// 多槽位使多本书可以同时下载且互不覆盖事件。
//
// 事件码：0=无事件 1=进度更新 2=下载成功 3=下载失败 4=错误 5=已取消。
// 写侧先写文本/percent，最后置 hasEvent；读侧读到即消费。
class DlMessageBox {
    var s: String = ""
}

class DlTaskBox {
    var task: ?DownloadTask = None
}

/** 单个下载任务的事件槽位（一个任务独占，读写互不干扰）。 */
class DlSlot {
    let event: AtomicInt64 = AtomicInt64(0)
    let percent: AtomicInt64 = AtomicInt64(0)
    let hasEvent: AtomicBool = AtomicBool(false)
    /** 取消请求标志：任务尚未创建底层 DownloadTask 时也能可靠取消。 */
    let cancelRequested: AtomicBool = AtomicBool(false)
    let text: AtomicReference<DlMessageBox> = AtomicReference<DlMessageBox>(DlMessageBox())
    let taskRef: AtomicReference<DlTaskBox> = AtomicReference<DlTaskBox>(DlTaskBox())
}

/** 槽位数量 = 允许的最大并发下载数。 */
let DL_SLOT_COUNT: Int64 = 16
let dlSlots: Array<DlSlot> = Array<DlSlot>(DL_SLOT_COUNT, {_ => DlSlot()})

/** UI 线程分配空闲槽位：只统计仍在进行中的任务，返回 -1 表示已满。 */
func allocDlSlot(state: AppState): Int64 {
    let used = Array<Bool>(DL_SLOT_COUNT, repeat: false)
    for (t in state.downloadTasks.value) {
        if ((t.status == "下载中" || t.status == "等待中") && t.slot >= 0 && t.slot < DL_SLOT_COUNT) {
            used[t.slot] = true
        }
    }
    for (i in 0..DL_SLOT_COUNT) {
        if (!used[i]) {
            return i
        }
    }
    -1
}

/** 写侧：重置槽位（新任务开始前调用）。 */
func resetDlSlot(slot: Int64): Unit {
    if (slot < 0 || slot >= DL_SLOT_COUNT) {
        return
    }
    let s = dlSlots[slot]
    s.event.store(0)
    s.hasEvent.store(false)
    s.percent.store(0)
    s.cancelRequested.store(false)
    s.text.store(DlMessageBox())
    s.taskRef.store(DlTaskBox())
}

/** 写侧：发布文本（速度 / 保存路径 / 错误消息）。 */
func dlSlotText(slot: Int64, msg: String): Unit {
    if (slot < 0 || slot >= DL_SLOT_COUNT) {
        return
    }
    let box = DlMessageBox()
    box.s = msg
    dlSlots[slot].text.store(box)
}

/** 写侧：发布事件（先文本/percent，最后置 hasEvent）。 */
func dlSlotPost(slot: Int64, event: Int64, pct: Int64): Unit {
    if (slot < 0 || slot >= DL_SLOT_COUNT) {
        return
    }
    let s = dlSlots[slot]
    s.percent.store(pct)
    s.event.store(event)
    s.hasEvent.store(true)
}

/** 取消指定槽位的下载（UI 线程调用）。 */
func cancelDownloadSlot(slot: Int64): Unit {
    if (slot < 0 || slot >= DL_SLOT_COUNT) {
        return
    }
    let s = dlSlots[slot]
    // 先置标志：任务可能还没创建底层 DownloadTask（正在获取下载信息）
    s.cancelRequested.store(true)
    match (s.taskRef.load().task) {
        case Some(t) => t.cancel()
        case None => ()
    }
}

// UI 线程每帧调用：把各槽位的事件落到 UI State
func pollDownloadRefresh(app: DesktopApp, state: AppState): Unit {
    let tasks = state.downloadTasks.value
    var changed = false
    // 有任务进入终态（完成/失败/取消）时刷新一次账号额度
    var refreshQuota = false
    for (i in 0..tasks.size) {
        let slot = tasks[i].slot
        if (slot < 0 || slot >= DL_SLOT_COUNT) {
            continue
        }
        let s = dlSlots[slot]
        if (!s.hasEvent.load()) {
            continue
        }
        // 只把事件投递给「进行中」的任务：已完成/失败/已取消的任务会释放槽位，
        // 新任务可能复用同一 slot。若在下标更小的终态任务上先消费 hasEvent，
        // 新任务的进度/完成事件就会被吞掉（表现为进度条和完成提示串到已完成
        // 的那一行）。因此必须在消费 hasEvent 之前判断任务是否仍在进行。
        let st = tasks[i].status
        if (st != "下载中" && st != "等待中") {
            continue
        }
        s.hasEvent.store(false)
        let event = s.event.load()
        changed = true
        if (event == 1) {
            tasks[i].percent = Float64(s.percent.load())
            tasks[i].status = "下载中"
            tasks[i].speed = s.text.load().s
        } else if (event == 2) {
            tasks[i].percent = 100.0
            tasks[i].status = "已完成"
            tasks[i].filePath = s.text.load().s
            state.toaster.show("下载完成：${tasks[i].bookName}", kind: ToastKind.Success, durationMs: 4000)
            refreshQuota = true
        } else if (event == 3) {
            tasks[i].status = "失败"
            refreshQuota = true
        } else if (event == 5) {
            tasks[i].status = "已取消"
            refreshQuota = true
        } else if (event == 4) {
            let msg = s.text.load().s
            tasks[i].status = "失败"
            state.toaster.show(msg, kind: ToastKind.Error, durationMs: 4000)
            refreshQuota = true
        }
    }
    if (changed) {
        state.downloadTasks.value = tasks
    }
    if (refreshQuota) {
        refreshUserProfile(app, state)
    }
}

/** 后台刷新账号信息，更新「今日额度 X / Y」（下载后额度会变化）。失败静默。 */
func refreshUserProfile(app: DesktopApp, state: AppState): Unit {
    let userOpt = state.currentUser.value
    if (userOpt.isNone()) {
        return
    }
    let u = userOpt.getOrThrow()
    spawn { =>
        try {
            let res = u.getPersonalInfo()
            if (res.success == UInt8(1)) {
                match (res.userInfo) {
                    case Some(fresh) =>
                        let text = "今日额度 ${fresh.todayDownloadNum} / ${fresh.downloadLimit}"
                        app.postToUi({ =>
                            state.downloadLimit.value = text
                            // 直接弹出最新额度：「不允许下载」多半就是额度用尽，
                            // 服务端不返回 error 文案时这是最直接的线索
                            state.toaster.show(text, kind: ToastKind.Info, durationMs: 3000)
                        })
                    case None => ()
                }
            }
        } catch (_: Exception) {
            // 额度刷新失败不打扰用户
            ()
        }
    }
}

func fetchRecommend(app: DesktopApp, state: AppState) {
    if (state.isHomeLoading.value) {
        return
    }
    // 换数据集（首次/重试）回到顶部；滚动位置本身由 AppState 持有以跨详情页存活
    state.homeGridScroll.value = 0.0
    state.homeListScroll.value = 0.0
    state.isHomeLoading.value = true
    state.homeError.value = ""
    state.homeSkeletonOn.value = true
    state.toaster.show("正在加载推荐书籍...", kind: ToastKind.Info)
    spawn { =>
        try {
            let res = state.client.getRecommendBook()
            app.postToUi({ =>
                state.isHomeLoading.value = false
                state.homeSkeletonOn.value = false
                if (res.success == UInt8(1)) {
                    state.recommendBooks.value = res.books ?? Array<BookInfoBrief>()
                    state.toaster.show("推荐书籍加载完成", kind: ToastKind.Success)
                } else {
                    state.homeError.value = res.errorInfo ?? "获取推荐失败"
                    state.toaster.show(state.homeError.value, kind: ToastKind.Error, durationMs: 4000)
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                state.isHomeLoading.value = false
                state.homeSkeletonOn.value = false
                state.homeError.value = e.toString()
                state.toaster.show("推荐加载失败: ${e.toString()}", kind: ToastKind.Error, durationMs: 4000)
            })
        }
    }
}

// 搜索请求序号（仅 UI 线程读写）：每次提交新搜索 +1，用于丢弃过期响应。
// 场景：搜 A 未返回时又搜 B，A 的响应不能再覆盖 B 的结果/骨架屏状态。
private var searchReqSeq: Int64 = 0

func doSearch(app: DesktopApp, state: AppState) {
    let word = state.searchInput.value.trimAscii()
    if (word.isEmpty()) {
        return
    }
    // 新搜索结果回到顶部
    state.homeGridScroll.value = 0.0
    state.homeListScroll.value = 0.0
    state.isHomeLoading.value = true
    state.homeError.value = ""
    state.searchPage.value = UInt16(1)
    state.searchNextPage.value = UInt16(2)
    state.searchTotalPages.value = UInt64(1)
    // 递增请求序号并记录生效搜索词：上一次的初始搜索与翻页请求就此作废
    searchReqSeq += 1
    let seq = searchReqSeq
    state.searchActiveQuery.value = word
    state.isSearchLoadingMore.value = false
    state.homeSkeletonOn.value = true
    state.toaster.show("正在搜索「${word}」...", kind: ToastKind.Info)
    let client = state.client
    spawn { =>
        try {
            let res = client.search(message: word, page: UInt16(1))
            app.postToUi({ =>
                // 过期响应（期间已提交新搜索）：结果与 loading 状态都不许动
                if (seq != searchReqSeq) {
                    return
                }
                state.isHomeLoading.value = false
                state.homeSkeletonOn.value = false
                if (res.success == UInt8(1)) {
                    state.searchBooks.value = searchRows(res.books)
                    state.isSearchMode.value = true
                    state.searchTotalPages.value = max(UInt64(1), res.pagination.totalPages)
                    state.searchNextPage.value = UInt16(2)
                    if (res.books.isEmpty()) {
                        state.homeError.value = "未搜索到相关书籍"
                        state.toaster.show("未搜索到相关书籍", kind: ToastKind.Warning)
                    } else {
                        state.toaster.show(
                            "第 1 页 / 共 ${state.searchTotalPages.value} 页 · 已加载 ${state.searchBooks.value.size} 本",
                            kind: ToastKind.Success)
                    }
                } else {
                    state.homeError.value = "未搜索到相关书籍"
                    state.toaster.show("搜索失败，请稍后重试", kind: ToastKind.Error, durationMs: 4000)
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                if (seq != searchReqSeq) {
                    return
                }
                state.isHomeLoading.value = false
                state.homeSkeletonOn.value = false
                state.homeError.value = e.toString()
                state.toaster.show("搜索失败: ${e.toString()}", kind: ToastKind.Error, durationMs: 4000)
            })
        }
    }
}

/** 搜索结果滑动到底部时继续获取下一页（toast 告知当前页/总页数）。 */
func loadMoreSearch(app: DesktopApp, state: AppState) {
    if (!state.isSearchMode.value || state.isHomeLoading.value || state.isSearchLoadingMore.value) {
        return
    }
    let next = state.searchNextPage.value
    if (UInt64(next) > state.searchTotalPages.value) {
        return
    }
    // 以「当前生效的搜索词」为准（不是输入框内容）：用户改了输入框但没提交时不会误判
    let word = state.searchActiveQuery.value
    if (word.isEmpty()) {
        return
    }
    // 绑定当前搜索的序号：期间提交新搜索则本次响应作废
    let seq = searchReqSeq
    state.isSearchLoadingMore.value = true
    state.toaster.show("正在获取page:${next}", kind: ToastKind.Info, durationMs: 2000)
    let client = state.client
    spawn { =>
        try {
            let res = client.search(message: word, page: next)
            app.postToUi({ =>
                // 过期响应（期间已提交新搜索/退出搜索）：丢弃，且不改「加载中」标志——
                // 新搜索已把它重置过，可能已有新的请求在飞，改了会破坏去重
                if (seq != searchReqSeq || !state.isSearchMode.value) {
                    return
                }
                state.isSearchLoadingMore.value = false
                if (res.success == UInt8(1) && !res.books.isEmpty()) {
                    let merged = ArrayList<BookInfoBrief>()
                    for (b in state.searchBooks.value) {
                        merged.add(b)
                    }
                    for (b in searchRows(res.books)) {
                        merged.add(b)
                    }
                    state.searchBooks.value = merged.toArray()
                    state.searchTotalPages.value = max(UInt64(1), res.pagination.totalPages)
                    state.searchNextPage.value = next + UInt16(1)
                    state.toaster.show(
                        "第 ${next} 页 / 共 ${state.searchTotalPages.value} 页 · 已加载 ${state.searchBooks.value.size} 本",
                        kind: ToastKind.Info, durationMs: 2500)
                } else {
                    // 该页无数据：推进页码，避免反复请求同一页
                    state.searchNextPage.value = next + UInt16(1)
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                if (seq != searchReqSeq || !state.isSearchMode.value) {
                    return
                }
                state.isSearchLoadingMore.value = false
                state.toaster.show("加载第 ${next} 页失败", kind: ToastKind.Error, durationMs: 3000)
            })
        }
    }
}

/** BookInfo → 首页卡片模型（搜索与收藏共用）。 */
func searchRows(books: Array<BookInfo>): Array<BookInfoBrief> {
    let rows = ArrayList<BookInfoBrief>()
    for (b in books) {
        let card = BookInfoBrief()
        card.id = b.id
        card.title = b.title
        match (b.author) {
            case Some(a) => card.author = a
            case None => card.author = ""
        }
        card.cover = b.cover
        card.hash = b.hash
        rows.add(card)
    }
    rows.toArray()
}

func backToRecommend(app: DesktopApp, state: AppState) {
    state.isSearchMode.value = false
    state.homeError.value = ""
    // 退出搜索：递增序号让在飞的搜索/翻页响应全部作废，并解除翻页锁
    searchReqSeq += 1
    state.searchActiveQuery.value = ""
    state.isSearchLoadingMore.value = false
    state.isHomeLoading.value = false
    state.homeSkeletonOn.value = false
    // 搜索态 → 推荐是换数据集，回到顶部
    state.homeGridScroll.value = 0.0
    state.homeListScroll.value = 0.0
    if (state.recommendBooks.value.isEmpty()) {
        fetchRecommend(app, state)
    }
}

// 搜索框清空检测：TextField 无变更回调，改为每帧比对上次输入。
// 处于搜索态且输入被清空时自动回到推荐列表。
private var lastSearchText: String = ""

func pollSearchClear(app: DesktopApp, state: AppState) {
    let cur = state.searchInput.value
    if (cur == lastSearchText) {
        return
    }
    lastSearchText = cur
    if (state.isSearchMode.value && cur.trimAscii().isEmpty()) {
        backToRecommend(app, state)
    }
}

func doLogin(app: DesktopApp, state: AppState) {
    let email = state.emailInput.value.trimAscii()
    let password = state.passwordInput.value
    if (email.isEmpty() || password.isEmpty()) {
        state.loginError.value = "账号和密码不能为空"
        return
    }
    if (state.isLoggingIn.value) {
        return
    }
    state.isLoggingIn.value = true
    state.loginError.value = ""
    let client = state.client
    spawn { =>
        try {
            let res = client.login(email: email, password: password)
            let ok = res.success == UInt8(1)
            if (ok) {
                // 凭据落盘在后台线程完成，UI 线程不做文件 IO
                saveCredentials(email, password)
            }
            app.postToUi({ =>
                state.isLoggingIn.value = false
                if (ok) {
                    applyLogin(app, state, res.userInfo, fallbackName: email)
                    state.passwordInput.value = ""
                } else {
                    state.loginError.value = res.errorInfo ?? "登录失败，请检查账号密码"
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                state.isLoggingIn.value = false
                state.loginError.value = e.toString()
            })
        }
    }
}

/**
 * 启动时用已保存的账号密码静默登录。
 * 读文件与登录请求都在后台线程完成（UI 线程零 IO），失败只提示、不阻断使用。
 */
func tryAutoLogin(app: DesktopApp, state: AppState) {
    if (state.isLoggingIn.value || state.currentUser.value.isSome()) {
        return
    }
    let client = state.client
    state.isLoggingIn.value = true
    spawn { =>
        let saved = loadCredentials()
        if (saved.isNone()) {
            app.postToUi({ => state.isLoggingIn.value = false })
            return
        }
        let (email, password) = saved.getOrThrow()
        // 预填登录框：自动登录失败时用户只需补/改密码
        app.postToUi({ =>
            state.emailInput.value = email
            state.passwordInput.value = password
            state.toaster.show("自动登录中...", kind: ToastKind.Info)
        })
        try {
            let res = client.login(email: email, password: password)
            let ok = res.success == UInt8(1)
            app.postToUi({ =>
                state.isLoggingIn.value = false
                state.passwordInput.value = ""
                if (ok) {
                    applyLogin(app, state, res.userInfo, fallbackName: email)
                    state.toaster.show("已自动登录", kind: ToastKind.Success, durationMs: 3000)
                } else {
                    state.loginError.value = res.errorInfo ?? "自动登录失败"
                    state.toaster.show("自动登录失败，请手动登录", kind: ToastKind.Warning, durationMs: 4000)
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                state.isLoggingIn.value = false
                state.passwordInput.value = ""
                state.loginError.value = e.toString()
                state.toaster.show("自动登录失败，请检查网络", kind: ToastKind.Warning, durationMs: 4000)
            })
        }
    }
}

func applyLogin(app: DesktopApp, state: AppState, user: Option<ZlibUserInfo>, fallbackName!: String = "") {
    state.currentUser.value = user
    match (user) {
        case Some(u) =>
            state.userName.value = u.name
            state.downloadLimit.value = "今日额度 ${u.todayDownloadNum} / ${u.downloadLimit}"
        case None =>
            state.userName.value = fallbackName
            state.downloadLimit.value = ""
    }
    // 登录成功后立即拉取一次收藏，进入书架即可直接看到内容。
    // 先解锁：上一次会话若有用飞未返回的收藏请求，isShelfLoading 会一直是 true，
    // 导致 fetchSavedPage 直接 return（表现为登录后收藏一直不出来）
    if (state.currentUser.value.isSome()) {
        state.isShelfLoading.value = false
        fetchSaved(app, state)
    }
}

func doLogout(state: AppState) {
    // 删除已保存的账号密码（后台线程，UI 线程不做文件 IO）
    spawn { => clearCredentials() }
    state.currentUser.value = None
    state.userName.value = ""
    state.downloadLimit.value = ""
    state.emailInput.value = ""
    state.passwordInput.value = ""
    state.savedBooks.value = Array<BookInfo>()
    state.savedPage.value = UInt64(1)
    state.savedTotalPages.value = UInt64(1)
    state.isShelfLoading.value = false
    state.shelfError.value = ""
    state.loginError.value = ""
}

func fetchSaved(app: DesktopApp, state: AppState) {
    // 重新拉取一律从第 1 页开始（否则会从上次停留的页继续，出现内容错乱）
    state.savedPage.value = UInt64(1)
    fetchSavedPage(app, state, reset: true)
}

func fetchSavedPage(app: DesktopApp, state: AppState, reset!: Bool) {
    let user = state.currentUser.value
    if (user.isNone() || state.isShelfLoading.value) {
        return
    }
    if (!reset && state.savedPage.value > state.savedTotalPages.value) {
        return
    }
    state.isShelfLoading.value = true
    state.shelfError.value = ""
    let u = user.getOrThrow()
    let page = state.savedPage.value
    // 全量重拉（登录后 / 手动刷新 / 重试）与滑到底部续页各自提示进度
    if (reset) {
        state.toaster.show("获取收藏中...", kind: ToastKind.Info)
    } else {
        state.toaster.show("正在获取page:${page}", kind: ToastKind.Info, durationMs: 2000)
    }
    spawn { =>
        try {
            let res = u.getSaved(page: page)
            app.postToUi({ =>
                // 期间已登出/换账号：丢弃过期响应，且不动 isShelfLoading
                // （新登录流程已重置过，可能已有新请求在飞）
                let stillSame = match (state.currentUser.value) {
                    case Some(cur) => cur.id == u.id
                    case None => false
                }
                if (!stillSame) {
                    return
                }
                state.isShelfLoading.value = false
                if (res.success == UInt8(1)) {
                    if (reset) {
                        state.savedBooks.value = res.books
                    } else {
                        let merged = ArrayList<BookInfo>()
                        for (b in state.savedBooks.value) {
                            merged.add(b)
                        }
                        for (b in res.books) {
                            merged.add(b)
                        }
                        state.savedBooks.value = merged.toArray()
                    }
                    state.savedPage.value = res.pagination.current + UInt64(1)
                    state.savedTotalPages.value = res.pagination.totalPages
                    let loaded = state.savedBooks.value.size
                    if (reset) {
                        state.toaster.show("收藏加载完成，共 ${loaded} 本", kind: ToastKind.Success)
                    } else {
                        state.toaster.show("已加载 ${loaded} 本 · 第 ${page} 页 / 共 ${state.savedTotalPages.value} 页",
                            kind: ToastKind.Info, durationMs: 2500)
                    }
                } else {
                    state.shelfError.value = "获取收藏失败"
                    state.toaster.show("获取收藏失败", kind: ToastKind.Error, durationMs: 4000)
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                let stillSame = match (state.currentUser.value) {
                    case Some(cur) => cur.id == u.id
                    case None => false
                }
                if (!stillSame) {
                    return
                }
                state.isShelfLoading.value = false
                state.shelfError.value = e.toString()
                state.toaster.show("获取收藏失败: ${e.toString()}", kind: ToastKind.Error, durationMs: 4000)
            })
        }
    }
}

func loadMoreSaved(app: DesktopApp, state: AppState) {
    if (state.savedPage.value > state.savedTotalPages.value) {
        return
    }
    fetchSavedPage(app, state, reset: false)
}

// =====================================================================
// 书籍详情：拉取全量信息（brief.getBookInfo）+ 收藏 / 取消收藏
//（eapi cookie 由登录用户 id + remixUserKey 拼出）
// =====================================================================

/** 后台拉取书籍全量信息并刷新详情页（秒开的摘要页先展示，缺省项随后补齐）。 */
func fetchBookDetail(app: DesktopApp, state: AppState, brief: BookInfoBrief) {
    let cookie: String = match (state.currentUser.value) {
        case Some(u) => u.cookie
        case None => ""
    }
    // 进入详情即置骨架：全量信息返回前显示占位屏
    state.detailSkeletonOn.value = true
    state.toaster.show("正在加载书籍详情...", kind: ToastKind.Info)
    spawn { =>
        try {
            let res = brief.getBookInfo(cookie: cookie)
            app.postToUi({ =>
                state.detailSkeletonOn.value = false
                // 详情已切走或换了书则丢弃过期响应
                if (state.detailVisible.value) {
                    match (state.detailBook.value) {
                        case Some(cur) =>
                            if (cur.id == brief.id && res.success == UInt8(1)) {
                                match (res.book) {
                                    case Some(full) =>
                                        // 保留摘要秒开时已知的收藏态（全量接口未登录时该字段可能缺失）
                                        if (full.isUserSavedBook.isNone()) {
                                            full.isUserSavedBook = cur.isUserSavedBook
                                        }
                                        state.detailBook.value = Some(full)
                                        state.detailFavTick.value = state.detailFavTick.value + Int64(1)
                                        state.toaster.show("《${full.title}》详情加载完成", kind: ToastKind.Success)
                                    case None =>
                                        state.detailMsg.value = "获取书籍详情失败"
                                        state.toaster.show("获取书籍详情失败", kind: ToastKind.Error, durationMs: 4000)
                                }
                            }
                        case None => ()
                    }
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                state.detailSkeletonOn.value = false
                if (state.detailVisible.value) {
                    state.detailMsg.value = "获取详情失败: ${e.toString()}"
                }
                state.toaster.show("详情加载失败: ${e.toString()}", kind: ToastKind.Error, durationMs: 4000)
            })
        }
    }
}

func toggleFavorite(app: DesktopApp, state: AppState) {
    let bookOpt = state.detailBook.value
    if (bookOpt.isNone()) {
        return
    }
    let userOpt = state.currentUser.value
    if (userOpt.isNone()) {
        state.detailMsg.value = "登录后才能收藏书籍"
        return
    }
    let book = bookOpt.getOrThrow()
    let u = userOpt.getOrThrow()
    let cookie = u.cookie
    // 目标状态：当前未收藏 → 收藏；已收藏 → 取消
    let target = !(book.isUserSavedBook ?? false)
    state.detailMsg.value = ""
    state.toaster.show(if (target) { "正在收藏..." } else { "正在取消收藏..." }, kind: ToastKind.Info)
    spawn { =>
        try {
            let ok = if (target) { book.saveBook(cookie: cookie) } else { book.unSaveBook(cookie: cookie) }
            app.postToUi({ =>
                if (ok) {
                    book.isUserSavedBook = Some(target)
                    // 同步本地收藏列表：取消收藏立即移除、收藏立即追加。
                    // 不走 fetchSaved 全量重拉——那会把列表重置回第 1 页，
                    // 丢掉已加载的分页并让滚动位置跳变。
                    syncSavedList(state, book, target)
                    // 触发详情页重渲染（按钮文案切换）
                    state.detailFavTick.value = state.detailFavTick.value + Int64(1)
                    state.toaster.show(if (target) { "已收藏《${book.title}》" } else { "已取消收藏" },
                        kind: ToastKind.Success)
                } else {
                    state.detailMsg.value = if (target) { "收藏失败" } else { "取消收藏失败" }
                }
            })
        } catch (e: Exception) {
            app.postToUi({ =>
                state.detailMsg.value = e.toString()
            })
        }
    }
}

/**
 * 收藏态变更后同步本地收藏列表（不重新请求，保留已加载分页与滚动位置）。
 * - 收藏：不在列表中则追加到末尾
 * - 取消收藏：从列表中移除
 */
func syncSavedList(state: AppState, book: BookInfo, saved: Bool): Unit {
    let cur = state.savedBooks.value
    if (saved) {
        for (b in cur) {
            if (b.id == book.id) {
                return // 已在列表中，无需追加
            }
        }
        let next = ArrayList<BookInfo>()
        for (b in cur) {
            next.add(b)
        }
        next.add(book)
        state.savedBooks.value = next.toArray()
    } else {
        var removed = false
        let next = ArrayList<BookInfo>()
        for (b in cur) {
            if (b.id == book.id) {
                removed = true
            } else {
                next.add(b)
            }
        }
        if (removed) {
            state.savedBooks.value = next.toArray()
        }
    }
}

// =====================================================================
// 书籍下载：getDownloadInfo（需登录 cookie）→ 保存到系统「下载」目录
// =====================================================================

/** 系统下载目录（%USERPROFILE%\Downloads），不存在则创建。
 * 若用户在设置中自定义了下载路径，则优先使用自定义路径。 */
func downloadsDir(): String {
    if (!gDownloadPath.isEmpty()) {
        try {
            if (!exists(Path(gDownloadPath))) {
                Directory.create(Path(gDownloadPath), recursive: true)
            }
        } catch (_: Exception) {
            ()
        }
        return gDownloadPath
    }
    let home = match (getVariable("USERPROFILE")) {
        case Some(h) => h.trimAscii()
        case None => "."
    }
    let dir = "${home}\\Downloads"
    try {
        if (!exists(Path(dir))) {
            Directory.create(Path(dir), recursive: true)
        }
    } catch (_: Exception) {
        ()
    }
    dir
}

/** 在系统资源管理器中打开下载目录（UI 线程调用，进程创建很快）。 */
func openDownloadsFolder(): Unit {
    let dir = downloadsDir()
    try {
        let _ = launch("explorer.exe", [dir],
            stdIn: ProcessRedirect.Discard,
            stdOut: ProcessRedirect.Inherit,
            stdErr: ProcessRedirect.Inherit)
    } catch (_: Exception) {
        // 打不开就静默忽略（例如 explorer 不存在），不打断 UI
    }
}

/** 下载当前详情页书籍到系统下载目录；未登录时提示先登录。
 * 允许多本书同时下载；同一本书已在下时弹确认框询问是否取消。 */
func downloadBook(app: DesktopApp, state: AppState) {
    let bookOpt = state.detailBook.value
    if (bookOpt.isNone()) {
        return
    }
    let userOpt = state.currentUser.value
    if (userOpt.isNone()) {
        state.detailMsg.value = "登录后才能下载书籍"
        state.toaster.show("请先登录账号后再下载", kind: ToastKind.Warning)
        return
    }
    let book = bookOpt.getOrThrow()
    // 同一本书已在下 → 弹确认框询问是否取消（而不是直接忽略）
    if (activeDownloadTask(state, book.id).isSome()) {
        state.cancelTargetBookId.value = book.id
        state.cancelTargetTitle.value = book.title
        state.showCancelDownload.value = true
        return
    }
    let slot = allocDlSlot(state)
    if (slot < 0) {
        state.toaster.show("同时下载的任务已达上限", kind: ToastKind.Warning)
        return
    }
    resetDlSlot(slot)
    let u = userOpt.getOrThrow()
    let cookie = u.cookie
    state.detailMsg.value = ""
    state.toaster.show("正在获取下载信息...", kind: ToastKind.Info)
    let dir = downloadsDir()
    let bookName = book.title
    // 添加到下载管理列表
    let taskInfo = DownloadTaskInfo(bookId: book.id, bookName: bookName, coverUrl: book.cover,
        percent: 0.0, status: "等待中", filePath: "", speed: "", slot: slot)
    let tasks = state.downloadTasks.value
    tasks.add(taskInfo)
    state.downloadTasks.value = tasks
    // 下载线程只写该任务独占的槽位原子量，绝不调用 postToUi（见文件顶部注释）
    spawn { =>
        try {
            let res = book.getDownloadInfo(cookie: cookie)
            if (res.success != UInt8(1)) {
                dlSlotText(slot, res.errorInfo ?? "获取下载信息失败")
                dlSlotPost(slot, 4, 0)
            } else if (let Some(info) <- res.file) {
                if (!info.allowDownload) {
                    // 服务端确实返回了 allowDownload=false（不是解析问题：字段缺失会抛异常）。
                    // 带上 error 文案（若有），便于区分「每日额度用尽」与「书籍本身受限」。
                    let reason = match (res.errorInfo) {
                        case Some(e) => if (e.isEmpty()) { "" } else { "：${e}" }
                        case None => ""
                    }
                    dlSlotText(slot, "该书籍不允许下载${reason}")
                    dlSlotPost(slot, 4, 0)
                } else {
                    // SelineDownload 单线程下载：Z-Library 不支持断点续传，多线程分片会拖住 UI
                    let link = info.downloadLink.getOrThrow().replace("%", "")
                    let ext = info.extension ?? ""
                    let rawName = info.fileName
                    let fileName = if (rawName.isEmpty()) {
                        if (ext.isEmpty()) { "${book.id}" } else { "${book.id}.${ext}" }
                    } else {
                        rawName
                    }
                    let savePath = "${dir}\\${fileName}"
                    let config = DownloadConfig()
                        .setUrl(link)
                        .setSavePath(savePath)
                        .setThreadCount(1)
                        .setEnableRange(false)
                        .setFileExistsAction(FileExistsAction.Rename)
                        // 不重试：库内重试走 sleep(1s/2s/4s/8s) 阻塞式退避会卡住 UI，
                        // 且 Z-Library 签名链接重试基本无效（失败由用户手动再点）
                        .setMaxRetries(1)
                        // 读超时收紧到 30s：默认 60s 时任何一次卡住的 socket 读都会拖死 UI
                        .setReadTimeout(Duration.second * 30)
                    let task = DownloadTask(config)
                    // 发布任务引用到本槽位，供 UI 线程取消
                    let taskBox = DlTaskBox()
                    taskBox.task = Some(task)
                    dlSlots[slot].taskRef.store(taskBox)
                    // 若在获取下载信息期间已被取消，直接收尾，不再发起下载
                    if (dlSlots[slot].cancelRequested.load()) {
                        dlSlotPost(slot, 5, 0)
                    } else {
                        let lastPct = AtomicInt64(-1)
                        task.setProgressCallback({ p =>
                            let pct = Int64(p.progress)
                            // 节流：整数百分比变化才写入，UI 线程每帧轮询消费
                            if (lastPct.load() != pct) {
                                lastPct.store(pct)
                                // 写侧顺序：先速度文本，再 percent/event，最后置 hasEvent
                                dlSlotText(slot, p.formattedSpeed)
                                dlSlotPost(slot, 1, pct)
                            }
                        })
                        task.start()
                        task.await()
                        // Cangjie 枚举未派生 Equatable，不能用 ==，改 match 判成败
                        match (task.getStatus()) {
                            case DownloadStatus.Completed =>
                                // 取消请求已发出时，即使底层恰好跑完也按「已取消」收尾
                                if (dlSlots[slot].cancelRequested.load()) {
                                    dlSlotPost(slot, 5, 0)
                                } else {
                                    dlSlotText(slot, savePath)
                                    dlSlotPost(slot, 2, 100)
                                }
                            case DownloadStatus.Cancelled =>
                                dlSlotPost(slot, 5, 0)
                            case _ =>
                                dlSlotPost(slot, 3, 0)
                        }
                    }
                }
            } else {
                dlSlotText(slot, "获取下载信息失败")
                dlSlotPost(slot, 4, 0)
            }
        } catch (e: Exception) {
            dlSlotText(slot, "下载失败: ${e.toString()}")
            dlSlotPost(slot, 4, 0)
        }
    }
}
