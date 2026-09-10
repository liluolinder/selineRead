package SelineRead

import chui.*
import selineDownload.*
import std.collection.HashSet
import std.collection.concurrent.*
import std.convert.*
import std.env.*
import std.fs.{Directory, Path, exists, remove}
import std.sync.AtomicBool

// 封面缓存：selineDownload 下载到 %TEMP%\SelineRead\covers（文件名用书籍 id），
// 下载完成后在后台线程解码转 BMP。
//
// 线程模型（重要）：SDL 事件轮询线程是主绿色线程，任何导致它 park /
// 被调度器迁移的操作（锁、阻塞 IO、甚至运行期高频 spawn 引发的负载均衡）
// 都会触发 SDL owner 校验失败闪退。因此：
//  - UI 线程（ensureCover/coverBmpReady）只查内存并发集合 + 非阻塞入队，
//    绝不 spawn、绝不碰文件系统；
//  - 全部封面工作（扫描缓存、下载、转码）由 app.run 之前创建的
//    单个常驻 worker 线程串行完成。

private let coverManager: DownloadManager = DownloadManager()
private let coverQueue = LinkedBlockingQueue<(UInt64, String)>(512)
// 已入队/处理中的封面 id（UI 线程去重，worker 完成后移除）
private let coverInFlight = ConcurrentHashMap<UInt64, Bool>(concurrencyLevel: 8)
// 下载或转换失败过的封面 id：本次会话不再重试
private let coverFailed = ConcurrentHashMap<UInt64, Bool>(concurrencyLevel: 8)
// 原始文件已下载、BMP 已就绪的封面 id（UI 线程只查，零文件 IO）
private let coverDownloaded = ConcurrentHashMap<UInt64, Bool>(concurrencyLevel: 8)
private let coverReady = ConcurrentHashMap<UInt64, Bool>(concurrencyLevel: 8)
// 缓存目录是否已确认存在
private let coverDirEnsured = ConcurrentHashMap<Bool, Bool>(concurrencyLevel: 2)
// 刷新通知：worker 只置无锁脏标志，绝不调用 postToUi（其内部有互斥锁，
// 主循环每帧也在争用；主绿色线程一旦在该锁上 park 就可能被调度器迁移，
// 触发 SDL owner 校验闪退）。改为 UI 线程每帧主动轮询此标志。
private let coverDirty = AtomicBool(false)

// worker 线程调用：仅置脏标志（无锁、无阻塞）
func notifyCoversChanged(app: DesktopApp, state: AppState): Unit {
    coverDirty.store(true)
}

// ===== 分帧揭示（第二次启动未响应的修复）=====
// 二次启动时磁盘上已有全部缩略图，首帧所有可见卡片的 ImageView 同时
// 同步读盘+上传纹理，一帧内几十次 IO 拖死主循环。改为每帧只放行
// COVER_REVEAL_PER_FRAME 张真图，其余先显示首字占位，后续帧陆续点亮。
private let COVER_REVEAL_PER_FRAME: Int64 = 64
// 仅 UI 线程访问（build 与 pollCoverRefresh 都在 UI 线程），无需并发集合
private var coverRevealBudget: Int64 = 0
private let revealedCovers = HashSet<UInt64>()

// UI 线程每帧调用：脏标志置位则自增版本触发重绘（由 UI 线程自己消费，
// 不存在跨线程锁交互）。同时重置每帧的封面揭示预算。
func pollCoverRefresh(state: AppState): Unit {
    coverRevealBudget = COVER_REVEAL_PER_FRAME
    // 只由 worker 完成信号驱动揭示帧。v10 实锤：任何「待揭示数>0 就续帧」
    // 的逻辑都会变成每帧 bump—— LazyGrid 的未挂载条目永远不会走到揭示门，
    // 待揭示数永不归零，形成永久重绘循环。滚动/交互帧自然会把已就绪的
    // 封面点亮，无需应用层推进。
    if (coverDirty.load()) {
        coverDirty.store(false)
        state.coverVersion.value = state.coverVersion.value + Int64(1)
    }
}

// 包内共享：封面缓存目录（temp\SelineRead\covers）
func coverCacheDir(): String {
    let temp = match (getVariable("TEMP")) {
        case Some(t) => t.trimAscii()
        case None => "."
    }
    "${temp}\\SelineRead\\covers"
}

func coverFilePath(id: UInt64): String {
    "${coverCacheDir()}\\cover-${id}.img"
}

// 缩略图 BMP 路径（worker 负责生成它）。v2 用 .tbmp 后缀以区别于
// 旧版未降采样的大 BMP，促使旧缓存自动重建
func coverBmpPath(id: UInt64): String {
    "${coverCacheDir()}\\cover-${id}.tbmp"
}

// ===== UI 线程路径：纯内存查询，无文件 IO / 锁 / spawn =====

// BMP 是否已就绪（cover_widget 的 coverView 调用）
func coverBmpReady(id: UInt64): Bool {
    coverReady.contains(id)
}

// 分帧揭示放行门（UI 线程调用）：本帧预算内才允许这张封面显示真图
// 并消耗预算，超出预算返回 false（本帧先显示占位），同时自增版本号——
// build 期间的 State 写入会让 run 循环排出一帧新渲染，形成"每帧揭示
// COVER_REVEAL_PER_FRAME 张、直到全部点亮"的自续循环。
// 已揭示过的封面直接放行——纹理已被 chui 按路径缓存，重放行无 IO。
func requestCoverReveal(id: UInt64, state: AppState): Bool {
    if (revealedCovers.contains(id)) {
        return true
    }
    if (coverRevealBudget <= 0) {
        // 绝不在 build 期写状态推进揭示——每次 build 都 bump 会形成重绘
        // 循环（v7/v8 快照实锤）。推进由 pollCoverRefresh 按待揭示数驱动
        return false
    }
    coverRevealBudget -= 1
    revealedCovers.add(id)
    return true
}

// 请求封面（UI 线程调用）：查内存集合去重后非阻塞入队，worker 消费
func ensureCover(app: DesktopApp, state: AppState, id: UInt64, url: String) {
    if (url.isEmpty() || id == UInt64(0)) {
        return
    }
    if (coverReady.contains(id) || coverDownloaded.contains(id)) {
        return
    }
    if (coverInFlight.contains(id) || coverFailed.contains(id)) {
        return
    }
    coverInFlight.add(id, true)
    coverQueue.add((id, url))
}

// 封面 worker 数量：首屏封面由「一张张串行下载+转码」改为并发拉取。
// 仍必须在 app.run 之前创建（运行期 UI 线程不再 spawn）。
private let COVER_WORKER_COUNT: Int64 = 4
// 首轮缓存扫描是否完成：其余 worker 等它结束后再开始消费队列，
// 否则可能与扫描路径对同一个 id 并发转码（共用同一个 .tmp 文件）
private let coverScanDone = AtomicBool(false)

// 创建常驻封面 worker（必须在 app.run 之前调用，此后 UI 线程不再 spawn）
func startCoverWorker(app: DesktopApp, state: AppState): Unit {
    var i: Int64 = 0
    while (i < COVER_WORKER_COUNT) {
        let isFirst = i == 0
        spawn { =>
            if (isFirst) {
                // 先扫已有缓存，让老封面立即可用（异常也不能卡住其他 worker 的等待）
                try {
                    scanExistingCovers()
                } catch (_: Exception) {
                    ()
                }
                notifyCoversChanged(app, state)
                coverScanDone.store(true)
            } else {
                // 等扫描完成（毫秒级），避免重复入队/并发转码同一张封面
                while (!coverScanDone.load()) {
                    sleep(Duration.millisecond * 5)
                }
            }
            while (true) {
                // 阻塞出队（worker 线程 park 无碍）
                let (id, url) = coverQueue.remove()
                processCover(app, state, id, url)
            }
        }
        i += 1
    }
}

// worker 线程执行：单个封面的 下载→解码转BMP→通知刷新
func processCover(app: DesktopApp, state: AppState, id: UInt64, url: String): Unit {
    var ok = false
    try {
        ensureCoverCacheDir()
        let config = DownloadConfig()
        config.setUrl(url)
        config.setSavePath(coverFilePath(id))
        config.setFileExistsAction(FileExistsAction.Skip)
        let task = coverManager.createTask("cover-${id}", config)
        task.start()
        task.await()
        ok = coverIsReady(id) && convertCoverOnce(id)
    } catch (_: Exception) {
        ok = false
    }
    coverInFlight.remove(id)
    if (ok) {
        coverDownloaded.add(id, true)
        coverReady.add(id, true)
        notifyCoversChanged(app, state)
    } else {
        coverFailed.add(id, true)
    }
}

// ===== 以下均仅在 worker 线程执行 =====

// 后台确认目录存在
func ensureCoverCacheDir(): Unit {
    if (coverDirEnsured.contains(true)) {
        return
    }
    try {
        Directory.create(Path(coverCacheDir()), recursive: true)
        coverDirEnsured.add(true, true)
    } catch (_: Exception) {
        ()
    }
}

func coverIsReady(id: UInt64): Bool {
    try {
        exists(Path(coverFilePath(id)))
    } catch (_: Exception) {
        false
    }
}

// 从 "cover-<id>.bmp/.img" 提取书籍 id；非封面文件返回 None
func parseCoverId(name: String): Option<UInt64> {
    if (!name.startsWith("cover-")) {
        return None
    }
    let dotOpt = name.lastIndexOf(".")
    match (dotOpt) {
        case Some(dot) =>
            if (dot <= 6) {
                return None
            }
            let idText = name.toArray()[6..dot].toString()
            // Int64.parse 失败时抛异常，非 Option 返回
            try {
                return Some(UInt64(Int64.parse(idText)))
            } catch (_: Exception) {
                return None
            }
        case None => None
    }
}

// 启动时把磁盘上已就绪的封面录入内存集合
func scanExistingCovers(): Unit {
    ensureCoverCacheDir()
    try {
        for (entry in Directory.readFrom(Path(coverCacheDir()))) {
            let name = entry.name
            match (parseCoverId(name)) {
                case Some(pid) =>
                    if (name.endsWith(".tbmp")) {
                        coverReady.add(pid, true)
                    } else if (name.endsWith(".bmp")) {
                        // 旧版未降采样的大 BMP：删除，等 worker 重新生成缩略图
                        try {
                            remove(Path("${coverCacheDir()}\\${name}"))
                        } catch (_: Exception) {
                            ()
                        }
                    } else if (name.endsWith(".img")) {
                        // 已下载但未转换，补一次转换
                        coverDownloaded.add(pid, true)
                        if (convertCoverOnce(pid)) {
                            coverReady.add(pid, true)
                        } else {
                            coverFailed.add(pid, true)
                        }
                    }
                case None => ()
            }
        }
    } catch (_: Exception) {
        ()
    }
}
