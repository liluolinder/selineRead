package selineDownload

import std.sync.{Mutex, AtomicInt64, AtomicBool}
import std.fs.{File, Path, OpenMode, exists, remove, rename, Directory}
import std.io.{InputStream, SeekPosition}
import std.collection.ArrayList
import std.convert.*
import std.time.DateTime
import stdx.log.*
import stdx.encoding.json.*
import linderHttp.{Headers, HttpClient, HttpClientBuilder, Method, RequestBuilder, RetryPolicy}

/*
 * 本库的日志（一个自带、默认 OFF 的 logger）在 `download_log.cj` 里，收口在 [DownloadLogger]。
 * 写日志一律走它，不要碰 `getGlobalLogger()`。
 */

/**
 * 下载任务类
 * 支持断点续传和多线程下载
 *
 * 下载流程:
 * 1. 检查临时文件夹是否存在，以及JSON记录是否匹配
 * 2. 如果匹配，在原有基础上继续下载
 * 3. 如果不匹配，创建新的临时文件夹
 * 4. 多线程下载各分片（下载中文件为.partN，完成后重命名为.partN.comp）
 * 5. 全部下载完成后合并所有分片
 * 6. 合并完成后删除临时文件夹
 */
/**
 * 异常的消息可能是空的（某些内部错误就是空的，报错里于是只剩"未知"），至少把类型带上。
 *
 * 库里的每个 catch 都改成用它：宁可多一行 `Exception`，也不要一条没有内容的失败。
 */
private func safeMessage(error: Exception): String {
    let message = error.message
    if (!message.isEmpty()) {
        return message
    }
    "${error}"
}
/**
 * 把一次请求的地址和**实际会发出去的头**写进日志。
 *
 * 排查"同一个地址 curl 通、这里 404"时，这两样最有用：最终的头是客户端默认头叠加调用方设的那些，
 * 光读代码猜不出来。同一个地址只记一次，免得资源下载把日志刷满。
 */
private var lastLoggedRequest = ""

private func logRequest(method: String, url: String, headers: Headers): Unit {
    if (url == lastLoggedRequest) {
        return
    }
    lastLoggedRequest = url
    /* 先问一句开关，再拼那行请求头：关着的时候连字符串都不该组装。
     * 用本库自己的 logger（见 [DownloadLogger]，默认 OFF），而不是 `getGlobalLogger()` —— 后者
     * 绕过级别，会把请求头回显直接写进宿主的日志文件。 */
    if (!DownloadLogger.enabled()) {
        return
    }
    var text = ""
    for ((name, values) in headers) {
        text += "${name}=${values.toArray().toString()} "
    }
    DownloadLogger.logger.info("[请求] ${method} ${url} 头: ${text}")
}

/*
 * 本库的 HTTP 客户端：全进程共用**一个**（见 `sharedHttpClient`），所以它的连接池上限是进程级设置，
 * 而不是"每个任务各自的"。
 *
 * 宿主在开始下载之前调 [setMaxConnectionsPerHost] 设好；没调就用 [DEFAULT_MAX_CONNECTIONS_PER_HOST]。
 * 之所以做成"设置一次"而不是从每个 `DownloadConfig` 读：同一个主机如果每个任务各按自己的上限去建连接，
 * 上游看到的压力就是这些上限之和，而池化复用本身也就失去意义了。
 */

/** 同一主机同时保持的连接数上限（默认 16）。 */
let DEFAULT_MAX_CONNECTIONS_PER_HOST: Int64 = 16

private var configuredMaxConnectionsPerHost: Int64 = DEFAULT_MAX_CONNECTIONS_PER_HOST
private let clientLock: Mutex = Mutex()
private var sharedHttpClientCache: ?HttpClient = None

/**
 * 设置同一主机的最大连接数（**进程级**，客户端建好之后不再生效）。
 *
 * 调用时机：宿主开始下载之前。传小于 1 的值按 1 处理。
 *
 * 这是我们这个下载库对外唯一"进程级"的设置，所以单独一个函数、并在名字里写清楚是"设置连接数"——
 * 不要以为它跟着某个 `DownloadConfig` 走。
 */
public func setMaxConnectionsPerHost(value: Int64): Unit {
    configuredMaxConnectionsPerHost = if (value < 1) { 1 } else { value }
}

/** 当前的连接上限（便于宿主/自检确认自己设的和库理解的一致）。 */
public func maxConnectionsPerHost(): Int64 {
    configuredMaxConnectionsPerHost
}

/**
 * 复用的连接池。
 *
 * 原来每次请求都新建一个 HTTP 客户端、用完销毁：连接从不复用，于是**每个文件都要重做一次
 * TCP + TLS 握手** —— 而握手恰恰是这类网络里最容易失败的一步（BMCL 约 6/10 次握手被拒，
 * 日志里那行 `[HttpEngine1#connect] TLS handshake error` 就是它）。
 *
 * 现在共用一个 `HttpClient`：它按 host 维护连接组（组内复用长连接、并发超出上限时排队等待），
 * 既减少握手次数，也不影响并行分片。读/写超时统一 60 秒，对几十 KB 的 JSON 和几十 MB 的文件都够用。
 *
 * 用 `Mutex` 惰性构建而不是直接初始化一个 `let`：这样连接上限能在"开始下载之前"设进去，
 * 而不是被写死在模块加载那一刻。锁只在第一次取用时争一次，之后是无竞争的一次判断。
 */
private func sharedHttpClient(): HttpClient {
    match (sharedHttpClientCache) {
        case Some(client) => return client
        case None => ()
    }
    synchronized(clientLock) {
        match (sharedHttpClientCache) {
            case Some(client) => return client
            case None => ()
        }
        let client = HttpClientBuilder()
            .maxConnectionsPerHost(configuredMaxConnectionsPerHost)
            /*
             * 空闲连接只留 5 秒。
             *
             * 池是"按 host 分组、并发超出上限就排队"，而空闲连接**仍然占着名额**（LinderHttp 默认留
             * 3 分钟）。连续下载几千个小文件时，那个默认值会让池在几分钟内被空闲连接占满，之后新请求
             * 全被拒 —— `Too many connections to the same server!`，每个拒绝还要叠 5 次重试，
             * 于是"越往后越慢"（实测末尾掉到 27 个文件/分钟）。
             *
             * 这里的连接复用发生在相邻请求之间，5 秒足够；再长只是占名额。
             */
            .idleConnectionTimeout(Duration.second * 5)
            .readTimeout(Duration.second * 60)
            .writeTimeout(Duration.second * 60)
            // 重试只保留「建连/传输失败时再试一次」：超时不重试（读超时已 60s），
            // 状态码不重试（本类自己按 maxRetries 处理），避免与下方重试循环叠加。
            .retry(RetryPolicy(maxAttempts: 2, initialBackoff: Duration.millisecond * 300,
                retryOnTimeout: false, retryOnStatus: []))
            .build()
        sharedHttpClientCache = Some(client)
        client
    }
}

/** 这次请求实际会带上的头：库的默认头（`accept`、`user-agent`）由客户端统一合并，这里只放调用方设的那些。 */
private func effectiveHeaders(config: DownloadConfig): Headers {
    let headers = Headers()
    for ((key, value) in config.headers) {
        headers.set(key, value)
    }
    headers
}

/** 按任务配置起一个池化请求（地址 + 自定义头）；method 与 Range 由调用方接着加。 */
private func pooledRequest(config: DownloadConfig, method: Method): RequestBuilder {
    let request = sharedHttpClient().request(method, config.url)
    for ((key, value) in config.headers) {
        request.header(key, value)
    }
    request
}

public class DownloadTask {
    private let config: DownloadConfig
    private var status: DownloadStatus = DownloadStatus.Pending
    private let progressMutex: Mutex = Mutex()
    private let downloadedBytes: AtomicInt64 = AtomicInt64(0)
    private let isCancelled: AtomicBool = AtomicBool(false)
    private let isPaused: AtomicBool = AtomicBool(false)
    private var futures: ArrayList<Future<Unit>> = ArrayList<Future<Unit>>()
    private var progressCallback: ?(DownloadProgress) -> Unit = None
    private var errorCallback: ?(Exception) -> Unit = None
    private var startCallback: ?() -> Unit = None
    private var pauseCallback: ?() -> Unit = None
    private var resumeCallback: ?() -> Unit = None
    private var cancelCallback: ?() -> Unit = None
    private var retryCallback: ?(Int64, Int64) -> Unit = None // (当前重试次数, 最大重试次数)
    private var completeCallback: ?() -> Unit = None // 下载完成回调
    /**
     * 正在合并的那个后台任务；没有合并时为空。
     *
     * 合并是异步跑的（跟分片下载同一个模式），但**不能对调用方异步**：原先"分片下完"就把状态置成
     * Completed 并回调，mergePartFiles() 还在后台写文件 —— 调用方拿到"完成"就去看文件，看到的是
     * 写到一半的内容（sha1 不符、大小不对）。所以合并任务在这里登记一份，[await] 收尾时等它真正结束。
     */
    private var activeMergeFuture: ?Future<Unit> = None
    private let mergeMutex: Mutex = Mutex()
    /*
     * 本库自己的 logger（见 [DownloadLogger]，默认什么都不写）。
     *
     * 做成**属性**而不是 `let logger = DownloadLogger.logger` 那样的字段：字段是建任务时的快照，
     * 而 `DownloadLogger.level` 一改就会换一个 logger 实例 —— 于是先建的任务会一直拿着旧实例
     * （级别还是 OFF），宿主明明打开了级别却看不到它的日志。属性每次读当下那一个，没有快照问题。
     */
    private prop logger: Logger {
        get() {
            DownloadLogger.logger
        }
    }

    // 速度计算相关
    private let speedMutex: Mutex = Mutex()
    private var lastSpeedCheckTime: Int64 = 0 // 上次检查时间(纳秒)
    private var lastSpeedCheckBytes: Int64 = 0 // 上次检查时的已下载字节数
    private var currentSpeed: Float64 = 0.0 // 当前速度(字节/秒)，使用浮点数提高精度
    private let speedSampleInterval: Int64 = 500000000 // 采样间隔500毫秒，提高响应速度

    // 进度回调节流相关
    private var lastProgressCallbackTime: Int64 = 0 // 上次触发进度回调的时间(纳秒)
    private let progressCallbackInterval: Int64 = 100000000 // 进度回调间隔100毫秒

    // 分片文件信息
    private let partFilesMutex: Mutex = Mutex()
    private var partFiles: ArrayList<String> = ArrayList<String>() // 存储分片文件路径
    private var partSizes: ArrayList<Int64> = ArrayList<Int64>() // 每个分片的预期大小

    // 临时文件夹路径
    private var tempDir: String = ""
    // JSON信息文件路径
    private var infoJsonPath: String = ""

    public init(config: DownloadConfig) {
        this.config = config
        logger.info("创建下载任务", ("url", config.url), ("savePath", config.savePath))
    }

    /**
     * 设置进度回调
     */
    public func setProgressCallback(callback: (DownloadProgress) -> Unit): DownloadTask {
        this.progressCallback = callback
        this
    }

    /**
     * 设置错误回调
     */
    public func setErrorCallback(callback: (Exception) -> Unit): DownloadTask {
        this.errorCallback = callback
        this
    }

    /**
     * 设置开始下载回调
     */
    public func setStartCallback(callback: () -> Unit): DownloadTask {
        this.startCallback = callback
        this
    }

    /**
     * 设置暂停下载回调
     */
    public func setPauseCallback(callback: () -> Unit): DownloadTask {
        this.pauseCallback = callback
        this
    }

    /**
     * 设置继续下载回调
     */
    public func setResumeCallback(callback: () -> Unit): DownloadTask {
        this.resumeCallback = callback
        this
    }

    /**
     * 设置取消下载回调
     */
    public func setCancelCallback(callback: () -> Unit): DownloadTask {
        this.cancelCallback = callback
        this
    }

    /**
     * 设置重试回调
     * 参数: (当前重试次数, 最大重试次数)
     */
    public func setRetryCallback(callback: (Int64, Int64) -> Unit): DownloadTask {
        this.retryCallback = callback
        this
    }

    /**
     * 设置下载完成回调
     */
    public func setCompleteCallback(callback: () -> Unit): DownloadTask {
        this.completeCallback = callback
        this
    }

    /**
     * 获取当前状态
     */
    public func getStatus(): DownloadStatus {
        status
    }

    /**
     * 获取已下载字节数
     */
    public func getDownloadedBytes(): Int64 {
        downloadedBytes.load()
    }

    /**
     * 检测服务器是否支持断点续传
     * 使用HEAD请求获取文件大小 + 实际Range请求测试
     */
    private func checkRangeSupport(): Bool {
        try {
            // 第一步: 使用HEAD请求获取文件信息
            let headRequest = pooledRequest(config, Method.Head)
            logRequest("HEAD", config.url, effectiveHeaders(config))
            let headResponse = headRequest.send()

            if (headResponse.status != 200) {
                let errorMsg = "[预下载检测错误] HEAD请求失败, HTTP状态码: ${headResponse.status}"
                logger.error(errorMsg)
                if (let Some(callback) <- errorCallback) {
                    callback(Exception(errorMsg))
                }
                return false
            }

            if (let Some(lengthStr) <- headResponse.header("content-length")) {
                config.totalSize = Int64.parse(lengthStr)
                logger.info("获取到文件大小", ("totalSize", config.totalSize))
            } else {
                logger.warn("响应头中缺少Content-Length字段,无法获取文件大小")
            }

            // 检查Accept-Ranges头
            if (let Some(acceptRanges) <- headResponse.header("accept-ranges")) {
                if (acceptRanges.contains("bytes")) {
                    logger.info("检测到Accept-Ranges: bytes,服务器支持断点续传")
                    return true
                }
            }

            if (config.totalSize > 0) {
                logger.info("开始测试Range请求...")
                // 只请求前1个字节进行测试
                let testResponse = pooledRequest(config, Method.Get)
                    .header("Range", "bytes=0-0")
                    .send()
                /*
                 * 这个探测响应只用来读 Content-Range 头，正文一律不要。
                 * 对规矩的服务器它只有 1 字节；但有的 CDN 会无视 Range 直接回整个文件——
                 * 那样正文会超过「自动落地」阈值而变成流式租约，不读就会一直占着连接池槽位。
                 * 显式 close 一次，两种服务器都不会留下未归还的租约（close 是幂等的）。
                 */
                testResponse.close()

                // 检查Content-Range头
                if (let Some(contentRange) <- testResponse.header("content-range")) {
                    logger.info("检测到Content-Range头,服务器支持断点续传")
                    return true
                }

                logger.info("服务器不支持断点续传")
                return false
            }

            false
        } catch (e: Exception) {
            let errorMsg = "[预下载检测错误] ${safeMessage(e)}"
            logger.error(errorMsg)
            if (let Some(callback) <- errorCallback) {
                callback(Exception(errorMsg))
            }
            false
        }
    }

    /**
     * 开始下载
     */
    public func start(): Unit {
        match (status) {
            case DownloadStatus.Downloading => return
            case _ => ()
        }

        logger.info("开始下载")
        status = DownloadStatus.Checking

        // 触发开始下载回调
        if (let Some(callback) <- startCallback) {
            callback()
        }

        // 处理重复文件名
        if (!handleExistingFile()) {
            // 跳过下载
            return
        }

        /*
         * 调用方明确禁用断点续传、或明确要求不做预探测时，跳过 HEAD。
         *
         * 探测（HEAD + Range 试请求）只服务于分片：不分片时它拿到的 totalSize 只影响进度条的分母，却要多
         * 发一到两个请求——而这类"探测请求"恰恰是中间层最爱回 404 的东西（实测 CurseForge 的 CDN 对 Range
         * 一律 404，部分网络对 HEAD 回 404 而 GET 200）。描述符正是这样失败的：日志里先一条 HEAD 404，
         * 然后整个文件失败。单线程路径不依赖 totalSize（它从 GET 响应的 Content-Length 拿），直接进入下载。
         *
         * **海量小文件（资源对象）走的就是这条**：HEAD 占了请求量的 43%，而探测结果从来用不上
         * （`threadCount=1` 不会分片）。见 [DownloadConfig.probeBeforeDownload]。
         */
        if (!config.enableRange || !config.probeBeforeDownload) {
            config.threadCount = 1
            logger.info("已禁用断点续传，跳过预下载检测，直接单连接整包下载")
            startSingleThreadDownload()
            return
        }

        // 检测是否支持断点续传
        config.supportRange = checkRangeSupport()

        /*
         * 预下载检测没拿到文件大小（HEAD 非 200，或响应里没有 Content-Length）时，退化为单连接整包下载，
         * 而不是直接判死。
         *
         * 有些主机对 HEAD 回 404、对 GET 却一切正常，这是 CDN 的常见行为（实测 CurseForge 的 CDN 对带
         * Range 的请求一律 404、普通 GET 200）。原先这里直接 markFailed，于是"明明 GET 得下来"的文件
         * 一个字节都拿不到——版本描述符（几十 KB 的小 JSON）就是这么失败的：日志里先 HEAD 404，
         * 紧接着"无法获取文件大小（totalSize = 0）"，然后失败。
         *
         * 单线程路径不依赖 totalSize（分片才需要），进度按已下载字节上报，totalBytes 为 0 时上层会按
         * "未知总长"处理。
         */
        if (config.totalSize == 0) {
            logger.warn("预下载检测未拿到文件大小，退化为单连接整包下载")
            config.threadCount = 1
            startSingleThreadDownload()
            return
        }

        // 判断是否使用多线程下载
        // 条件: 服务器支持断点续传 且 用户启用了断点续传
        if (config.supportRange && config.enableRange) {
            // 支持断点续传且启用,使用多线程下载
            // 如果未设置线程数,则根据文件大小自动计算
            if (config.threadCount == 0) {
                config.threadCount = calculateThreadCount(config.totalSize)
                logger.info("自动计算线程数", ("fileSize", config.totalSize), ("threadCount", config.threadCount))
            }
            logger.info("服务器支持断点续传,使用多线程下载", ("totalSize", config.totalSize), ("threadCount", config.threadCount))
            startMultiThreadDownload()
        } else {
            // 不支持断点续传或未启用,使用单线程下载
            config.threadCount = 1
            if (!config.enableRange) {
                logger.info("用户禁用断点续传,使用单线程下载", ("totalSize", config.totalSize))
            } else {
                logger.info("服务器不支持断点续传,使用单线程下载", ("totalSize", config.totalSize))
            }
            startSingleThreadDownload()
        }
    }

    /**
     * 暂停下载
     */
    public func pause(): Unit {
        logger.info("暂停下载")
        isPaused.store(true)
        status = DownloadStatus.Paused

        // 触发暂停下载回调
        if (let Some(callback) <- pauseCallback) {
            callback()
        }
    }

    /**
     * 恢复下载
     */
    public func resume(): Unit {
        match (status) {
            case DownloadStatus.Paused =>
                logger.info("恢复下载")
                isPaused.store(false)
                status = DownloadStatus.Downloading

                // 触发继续下载回调
                if (let Some(callback) <- resumeCallback) {
                    callback()
                }

                start()
            case _ => ()
        }
    }

    /**
     * 取消下载
     *
     * 语义：置取消标志 + 状态改为 Cancelled + 触发一次 cancelCallback。下载线程退出后不会再覆盖该状态
     * （各下载/合并路径均先检查 isCancelled），因此调用方 `getStatus()` 当场就能稳定拿到 Cancelled。
     *
     * **这里不等下载线程退出**，等过，等出了死锁：取消最自然的调用点是进度回调，而进度回调就运行在下载
     * 线程上（只有传输途中的回调才能打断正在下的那个大文件）。于是 `f.get()` 变成"等自己"：
     * `Future.get()` 等自己的 Future 永远不会返回（实测），下载线程就永久卡在这一句上 ——
     * 分片文件的句柄不放开，调用方的 `await()` 也永远收不了尾，从外面看就是"取消以后目标目录一直原样
     * 留在那儿"，而真正的原因是没人再往下走，不是目录被占住。
     *
     * 所以：取消只负责立标志，让各下载/合并循环自己看到并退出；**等它们结束是 [await] 的职责**，
     * 由调用方的线程执行。只调 cancel() 不等 await() 的调用方拿到的状态是对的，但文件句柄要过一小会儿才放开。
     */
    public func cancel(): Unit {
        // 幂等：重复/并发调用只触发一次取消回调
        if (isCancelled.load()) {
            return
        }
        logger.info("取消下载")
        isCancelled.store(true)
        status = DownloadStatus.Cancelled

        // 触发取消下载回调
        if (let Some(callback) <- cancelCallback) {
            callback()
        }
    }

    /**
     * 等待下载**并且合并**完成。
     *
     * 返回时要么是 Completed（文件已完整落盘），要么是 Failed/Cancelled/Paused —— 不会是
     * "分片下完了、合并还在后台跑"。合并期间 [getStatus] 是 Merging，可见但不算结束。
     *
     * 合并任务必须在分片之后、`start()` 返回之前登记（见 `startMultiThreadDownload`），
     * 所以这里读得到；循环是为了兜住"登记刚好落在本次读取之后"的顺序。
     */
    public func await(): Unit {
        for (f in futures) {
            try {
                f.get()
            } catch (e: Exception) {
                if (let Some(callback) <- errorCallback) {
                    callback(e)
                }
            }
        }
        // 分片线程都结束了，合并可能才刚开始：等它真正写完。
        var guard = 0
        while (guard < 1000) {
            guard++
            var merging: ?Future<Unit> = None
            synchronized(mergeMutex) {
                merging = activeMergeFuture
            }
            match (merging) {
                case Some(future) => try {
                    future.get()
                } catch (_: Exception) {
                    /* 合并失败已经由合并流程自己 markFailed 并回调，这里只负责等它结束。 */
                }
                case None => return
            }
        }
        /* 合并迟迟不结束（磁盘极慢等）：不再无限等，让调用方看到 Merging 自己决定。 */
        logger.warn("等待合并超时，任务仍在合并中")
    }

    /**
     * 处理已存在的文件
     * 返回true表示继续下载，false表示跳过下载
     * 
     * 策略说明：
     * - Skip: 目标文件存在则跳过
     * - Delete: 不在下载前删除，而是在合并分片前删除（见mergePartFiles）
     * - Rename: 在下载前重命名目标文件
     */
    private func handleExistingFile(): Bool {
        let savePath = Path(config.savePath)
        let fileExists = exists(savePath)
        
        match (config.fileExistsAction) {
            case FileExistsAction.Skip => return handleSkipExistingFile(fileExists)
            case FileExistsAction.Delete => return handleDeleteStrategy(fileExists)
            case FileExistsAction.Rename => return handleRenameStrategy(fileExists)
        }
    }

    /**
     * Skip策略处理
     */
    private func handleSkipExistingFile(fileExists: Bool): Bool {
        if (fileExists) {
            logger.info("文件已存在，跳过下载: ${config.savePath}")
            status = DownloadStatus.Completed
            return false
        }
        return true
    }

    /**
     * Delete策略处理（不在下载前删除，合并时再删除）
     */
    private func handleDeleteStrategy(fileExists: Bool): Bool {
        if (fileExists) {
            logger.info("文件已存在，将在合并分片时删除: ${config.savePath}")
        }
        return true
    }

    /**
     * Rename策略处理
     */
    private func handleRenameStrategy(fileExists: Bool): Bool {
        if (fileExists) {
            return handleRenameExistingFile()
        }
        return true
    }

    /**
     * 重命名已存在的文件
     */
    private func handleRenameExistingFile(): Bool {
        let newPath = generateNewFilePath(config.savePath)
        config.savePath = newPath
        logger.info("文件已存在，重命名为: ${newPath}")
        return true
    }

    /**
     * 生成新的文件路径（在文件名后加(N)）
     * 例如: file.txt -> file(1).txt -> file(2).txt
     * 同时检查目标文件和.temp文件是否存在
     */
    private func generateNewFilePath(originalPath: String): String {
        // 分离目录、文件名和扩展名
        var dir = ""
        var fileName = originalPath
        var ext = ""

        // 分离目录
        match (originalPath.lastIndexOf('/')) {
            case Some(idx) =>
                dir = originalPath[..idx]
                fileName = originalPath[idx + 1..]
            case None => ()
        }

        // 分离扩展名
        match (fileName.lastIndexOf('.')) {
            case Some(idx) =>
                if (idx > 0) {
                    ext = fileName[idx..]
                    fileName = fileName[..idx]
                }
            case None => ()
        }

        // 查找可用的编号
        var num: Int64 = 1
        var newPath = originalPath
        while (true) {
            if (dir.isEmpty()) {
                newPath = "${fileName}(${num})${ext}"
            } else {
                newPath = "${dir}/${fileName}(${num})${ext}"
            }
            
            // 检查目标文件和.temp文件是否都不存在
            let tempPath = "${newPath}.temp"
            if (!exists(Path(newPath)) && !exists(Path(tempPath))) {
                break
            }
            num++
        }

        return newPath
    }

    /**
     * 计算当前下载速度
     * 返回速度(字节/秒)
     * 使用浮点数计算提高精度，并采用滑动窗口平均算法平滑速度波动
     */
    private func calculateSpeed(): Int64 {
        synchronized(speedMutex) {
            let currentTime = DateTime.now().toUnixTimeStamp().toNanoseconds() // 转换为纳秒
            let currentBytes = downloadedBytes.load()

            if (lastSpeedCheckTime == 0) {
                // 第一次检查
                lastSpeedCheckTime = currentTime
                lastSpeedCheckBytes = currentBytes
                return 0
            }

            let timeDiff = currentTime - lastSpeedCheckTime
            // 降低采样间隔到500毫秒，提高速度响应性
            if (timeDiff < speedSampleInterval) {
                return Int64(currentSpeed)
            }

            let bytesDiff = currentBytes - lastSpeedCheckBytes
            // 使用浮点数计算，避免整数除法精度丢失
            let timeDiffSeconds = Float64(timeDiff) / 1000000000.0
            let instantSpeed = Float64(bytesDiff) / timeDiffSeconds

            // 使用指数移动平均(EMA)平滑速度，权重0.3使速度变化更平滑
            // 新速度 = 0.3 * 瞬时速度 + 0.7 * 旧速度
            if (currentSpeed == 0.0) {
                currentSpeed = instantSpeed
            } else {
                currentSpeed = 0.3 * instantSpeed + 0.7 * currentSpeed
            }

            // 更新检查点
            lastSpeedCheckTime = currentTime
            lastSpeedCheckBytes = currentBytes

            return Int64(currentSpeed)
        }
    }

    /**
     * 根据文件大小自动计算线程数
     * 规则:
     * - 小于1MB: 1线程
     * - 1MB-10MB: 2线程
     * - 10MB-50MB: 4线程
     * - 50MB-100MB: 8线程
     * - 大于100MB: 16线程
     */
    private func calculateThreadCount(fileSize: Int64): Int64 {
        let mb: Int64 = 1024 * 1024

        if (fileSize < mb) {
            // 小于1MB
            1
        } else if (fileSize < 10 * mb) {
            // 1MB-10MB
            2
        } else if (fileSize < 50 * mb) {
            // 10MB-50MB
            4
        } else if (fileSize < 100 * mb) {
            // 50MB-100MB
            8
        } else {
            // 大于100MB
            16
        }
    }

    /** 最近一次失败的原因；未失败时为空串。 */
    private var failureMsg: String = ""

    /**
     * 最近一次失败的原因。
     *
     * 失败时 [getStatus] 只给一个 `Failed`，调用方看不出「为什么」—— 尤其是
     * 预下载检测失败、临时目录初始化失败这两类，任务直接返回且**不抛异常**，
     * 调用方只能拿到「文件不存在」。这里给出可读原因。
     */
    public func getFailureReason(): String {
        failureMsg
    }

    /**
     * 置为失败态并记下原因（同时写日志）。
     *
     * 所有失败路径都应当走这里，别再只写 `status = Failed` ——
     * 那样调用方无从诊断。
     */
    private func markFailed(reason: String): Unit {
        failureMsg = reason
        status = DownloadStatus.Failed
        logger.error(reason)
    }

    /**
     * 初始化临时文件夹
     *
     * 三种情况：
     * 1. 目录不存在 → 建一个空的；
     * 2. 目录存在且下载记录**有效** → 继续下载（断点续传）；
     * 3. 目录存在但记录缺失 / 不匹配 → **清掉重建**。
     *
     * 第 3 种是踩过的坑：早先只处理了「记录存在但不匹配」（把目录改名成
     * `.tmp_<时间戳>` 留着，越积越多），**完全没处理记录缺失**，于是流程落到
     * 下面的 `Directory.create` —— 在已存在的目录上建目录会抛
     * `FSException: File exists`，被 catch 后返回 false，整个任务静默中止：
     * 不抛异常、不落盘，调用方只能看到「文件不存在」。
     *
     * 实测表现：一次 Ctrl+C 打断留下的 `<文件>.tmp/`（里面只有半截 `.partN`）
     * 会让该文件**永远下载失败**，换并发数、换地址都没用。
     *
     * 失败时会把原因写进 [getFailureReason]，不再只留一个 `Failed` 状态。
     */
    private func initTempDirectory(): Bool {
        // 临时文件夹路径: savePath + ".tmp"
        tempDir = "${config.savePath}.tmp"
        infoJsonPath = "${tempDir}/download_info.json"
        let tempDirPath = Path(tempDir)

        if (exists(tempDirPath)) {
            let jsonPath = Path(infoJsonPath)
            if (exists(jsonPath) && checkDownloadInfo()) {
                logger.info("检测到有效的下载记录，继续下载", ("tempDir", tempDir))
                return true
            }
            // 记录缺失或不匹配：里面的分片一律不可信（可能是别次下载留下的、
            // 分片数与本次不同），直接清掉重下，而不是改名留着占地方。
            logger.info("临时下载记录不可用，清理后重新下载", ("tempDir", tempDir))
            if (!removeQuietly(tempDirPath)) {
                markFailed("清理过期的临时分片目录失败: ${tempDir}")
                return false
            }
        }

        // 判空再建：`Directory.create` 建在已存在的目录上会抛异常。
        if (!exists(tempDirPath)) {
            try {
                Directory.create(tempDirPath, recursive: true)
                logger.info("创建临时文件夹", ("tempDir", tempDir))
            } catch (e: Exception) {
                markFailed("创建临时文件夹失败: ${safeMessage(e)}")
                return false
            }
        }

        return true
    }

    /** 递归删除目录，失败返回 false（不抛异常）。 */
    private func removeQuietly(path: Path): Bool {
        try {
            if (exists(path)) {
                remove(path, recursive: true)
            }
            true
        } catch (e: Exception) {
            logger.error("删除目录失败: ${path} ${safeMessage(e)}")
            false
        }
    }

    /**
     * 检查下载信息是否匹配
     */
    private func checkDownloadInfo(): Bool {
        try {
            // 读取JSON文件内容
            let bytes = File.readFrom(Path(infoJsonPath))

            // 将字节转换为字符串
            let content = String.fromUtf8(bytes)

            // 解析JSON
            let jsonValue = JsonValue.fromStr(content)
            let jsonObj = jsonValue.asObject()

            // 获取保存的信息
            var savedUrl = ""
            var savedTotalSize: Int64 = 0
            var savedThreadCount: Int64 = 0
            var savedPartSizesArray: JsonArray = JsonArray()

            if (let Some(urlVal) <- jsonObj.get("url")) {
                savedUrl = urlVal.asString().getValue()
            } else {
                logger.info("JSON缺少url字段")
                return false
            }

            if (let Some(totalSizeVal) <- jsonObj.get("totalSize")) {
                savedTotalSize = totalSizeVal.asInt().getValue()
            } else {
                logger.info("JSON缺少totalSize字段")
                return false
            }

            if (let Some(threadCountVal) <- jsonObj.get("threadCount")) {
                savedThreadCount = threadCountVal.asInt().getValue()
            } else {
                logger.info("JSON缺少threadCount字段")
                return false
            }

            if (let Some(partSizesVal) <- jsonObj.get("partSizes")) {
                savedPartSizesArray = partSizesVal.asArray()
            } else {
                logger.info("JSON缺少partSizes字段")
                return false
            }

            // 检查URL是否匹配
            if (savedUrl != config.url) {
                logger.info("URL不匹配: saved=${savedUrl}, current=${config.url}")
                return false
            }

            // 检查总大小是否匹配
            if (savedTotalSize != config.totalSize) {
                logger.info("总大小不匹配: saved=${savedTotalSize}, current=${config.totalSize}")
                return false
            }

            // 检查线程数是否匹配
            if (savedThreadCount != config.threadCount) {
                logger.info("线程数不匹配: saved=${savedThreadCount}, current=${config.threadCount}")
                return false
            }

            // 计算当前预期的分片大小
            let chunkSize = config.totalSize / config.threadCount
            let expectedPartSizes = ArrayList<Int64>()
            for (i in 0..config.threadCount) {
                let expectedSize = if (i == config.threadCount - 1) {
                    config.totalSize - (i * chunkSize)
                } else {
                    chunkSize
                }
                expectedPartSizes.add(expectedSize)
            }

            // 检查分片数量是否匹配
            if (savedPartSizesArray.size() != expectedPartSizes.size) {
                logger.info("分片数量不匹配: saved=${savedPartSizesArray.size()}, current=${expectedPartSizes.size}")
                return false
            }

            // 检查每个分片大小是否匹配
            for (i in 0..expectedPartSizes.size) {
                if (let Some(partSizeVal) <- savedPartSizesArray.get(i)) {
                    let savedPartSize = partSizeVal.asInt().getValue()
                    if (savedPartSize != expectedPartSizes[i]) {
                        logger.info("分片${i}大小不匹配: saved=${savedPartSize}, current=${expectedPartSizes[i]}")
                        return false
                    }
                } else {
                    logger.info("分片${i}数据缺失")
                    return false
                }
            }

            logger.info("下载信息匹配: url=${savedUrl}, totalSize=${savedTotalSize}")
            return true
        } catch (e: Exception) {
            logger.warn("读取下载信息失败: ${safeMessage(e)}")
        }
        false
    }

    /**
     * 保存下载信息到JSON文件
     */
    private func saveDownloadInfo(): Unit {
        try {
            let threadCount = config.threadCount

            // 构建每个分片的大小数组
            let partSizesArray = JsonArray()
            synchronized(partFilesMutex) {
                for (i in 0..partSizes.size) {
                    partSizesArray.add(JsonInt(partSizes[i]))
                }
            }

            // 构建JsonObject
            let jsonObj = JsonObject()
            jsonObj.put("url", JsonString(config.url))
            jsonObj.put("totalSize", JsonInt(config.totalSize))
            jsonObj.put("threadCount", JsonInt(threadCount))
            jsonObj.put("savePath", JsonString(config.savePath))
            jsonObj.put("partSizes", partSizesArray)

            let jsonContent = jsonObj.toJsonString()

            let jsonFile = File(Path(infoJsonPath), OpenMode.Write)
            jsonFile.write(jsonContent.toArray())
            jsonFile.close()

            logger.info("保存下载信息: path=${infoJsonPath}")
        } catch (e: Exception) {
            logger.error("保存下载信息失败: ${safeMessage(e)}")
        }
    }

    /**
     * 删除临时文件夹
     */
    private func deleteTempDirectory(): Unit {
        try {
            let tempDirPath = Path(tempDir)
            if (exists(tempDirPath)) {
                // 删除文件夹内的所有文件
                deleteDirectoryContents(tempDirPath)
                // 删除文件夹本身
                remove(tempDirPath)
                logger.info("已删除临时文件夹", ("path", tempDir))
            }
        } catch (e: Exception) {
            logger.warn("删除临时文件夹失败: ${safeMessage(e)}")
        }
    }

    /**
     * 递归删除文件夹内容
     */
    private func deleteDirectoryContents(dirPath: Path): Unit {
        // 分片文件已在合并时删除，这里只删除JSON信息文件
        try {
            remove(Path(infoJsonPath))
            logger.debug("已删除信息文件: ${infoJsonPath}")
        } catch (e: Exception) {
            logger.warn("删除信息文件失败: ${safeMessage(e)}")
        }
    }

    /**
     * 单线程下载
     */
    private func startSingleThreadDownload(): Unit {
        status = DownloadStatus.Downloading
        let fut = spawn {
            try {
                downloadSingleThread()
                // downloadSingleThread 在取消/暂停时是正常 return，不能按「完成」处理，
                // 否则会把 cancel() 写入的 Cancelled 覆盖成 Completed（多线程路径已有此守卫）
                if (isCancelled.load()) {
                    status = DownloadStatus.Cancelled
                    logger.info("单线程下载已取消")
                    return
                }
                if (isPaused.load()) {
                    status = DownloadStatus.Paused
                    logger.info("单线程下载已暂停")
                    return
                }
                status = DownloadStatus.Completed
                logger.info("下载完成")
                if (let Some(callback) <- completeCallback) {
                    callback()
                }
            } catch (e: Exception) {
                // 取消/暂停过程中抛出的异常（例如连接被关闭）不应记为失败
                if (isCancelled.load()) {
                    status = DownloadStatus.Cancelled
                    logger.info("单线程下载已取消")
                    return
                }
                if (isPaused.load()) {
                    status = DownloadStatus.Paused
                    logger.info("单线程下载已暂停")
                    return
                }
                markFailed("单线程下载失败: ${safeMessage(e)}")
                if (let Some(callback) <- errorCallback) {
                    callback(e)
                }
            }
        }

        futures.add(fut)
    }

    /**
     * 多线程下载
     */
    private func startMultiThreadDownload(): Unit {
        status = DownloadStatus.Downloading

        // 初始化临时文件夹
        if (!initTempDirectory()) {
            // 失败原因已由 initTempDirectory 记进 getFailureReason()
            return
        }

        let threadCount = config.threadCount
        let chunkSize = config.totalSize / threadCount

        // 初始化分片文件列表和预期大小（使用临时文件夹路径）
        synchronized(partFilesMutex) {
            partFiles.clear()
            partSizes.clear()
            for (i in 0..threadCount) {
                // 已完成的分片文件路径（在临时文件夹内）
                let partPath = "${tempDir}/part${i}.comp"
                partFiles.add(partPath)

                // 计算每个分片的预期大小
                let expectedSize = if (i == threadCount - 1) {
                    // 最后一个分片包含剩余所有字节
                    config.totalSize - (i * chunkSize)
                } else {
                    chunkSize
                }
                partSizes.add(expectedSize)
            }
        }

        // 保存下载信息到JSON文件（partSizes已初始化）
        saveDownloadInfo()

        // 检查是否所有分片都已存在且大小正确
        let allPartsExist = checkAllPartsExist()

        if (allPartsExist) {
            // 所有分片已存在，跳过下载直接合并
            logger.info("检测到所有分片文件已存在且大小正确，跳过下载直接合并")
            downloadedBytes.store(config.totalSize)

            // 通知进度
            if (let Some(callback) <- progressCallback) {
                let progress = DownloadProgress(
                    downloadedBytes: config.totalSize,
                    totalBytes: config.totalSize,
                    speed: 0
                )
                callback(progress)
            }

            /*
             * 直接合并：走和"下完再合并"同一条路（[beginMerge]），
             * 状态同样是 Merging → Completed，并且 `await()` 会等它结束。
             */
            beginMerge()
            return
        }

        // 需要下载，启动多线程
        for (i in 0..threadCount) {
            let startPos = i * chunkSize
            let endPos = if (i == threadCount - 1) {
                config.totalSize - 1
            } else {
                (i + 1) * chunkSize - 1
            }

            let fut = spawn {
                try {
                    downloadRangeToPartFile(startPos, endPos, i)
                } catch (e: Exception) {
                    logger.error("线程${i}下载失败: ${safeMessage(e)}")
                    if (let Some(callback) <- errorCallback) {
                        callback(e)
                    }
                }
            }

            futures.add(fut)
        }

        // 复制futures列表，避免在遍历时被修改
        let downloadFutures = ArrayList<Future<Unit>>()
        for (f in futures) {
            downloadFutures.add(f)
        }

        // 启动监控线程（加入futures以便await等待）
        let monitorFuture = spawn {
            for (f in downloadFutures) {
                try {
                    f.get()
                } catch (e: Exception) {
                    /* 分片线程自己已经 catch 过并报了 errorCallback；这里只是等它结束。 */
                }
            }

            if (isCancelled.load() || isPaused.load()) {
                return
            }
            /*
             * 合并之前先确认**每个分片都齐了**。
             *
             * 分片线程重试到上限后只是记一条日志、把异常交给 errorCallback，然后正常结束 ——
             * 监控线程原先不看结果就合并，于是把「四个分片只下了一半」合成一个**截断的完整文件**：
             * 文件存在、大小不对，调用方只能看到"下载完成"或"校验不符"，而截断的字节数会作为续传
             * 起点留给下一次（`partN` 的 size 被当成"已下载"），下一次同样下不完，如此循环。
             */
            if (!checkAllPartsExist()) {
                let reason = incompleteParts()
                markFailed("分片不完整，拒绝合并：${reason}（分片线程重试到上限只记日志、不抛异常，所以" +
                    "这里必须自己拦；临时分片目录保留，下次可续传）")
                if (let Some(callback) <- errorCallback) {
                    callback(Exception(reason))
                }
                return
            }

            // 所有分片下载完成，开始合并
            logger.info("所有分片下载完成，开始合并文件...")
            beginMerge()
        }
        futures.add(monitorFuture)
    }

    /**
     * 开始合并：把状态切成 [Merging]，在后台把分片写成一个文件。
     *
     * 合并**在后台跑**（几十 MB 的读写不该占着 `await` 的调用线程），但任务登记在
     * [activeMergeFuture] 上，[await] 会等它真正结束 —— 见那里的说明。
     */
    private func beginMerge(): Unit {
        status = DownloadStatus.Merging
        logger.info("开始合并分片文件")
        let mergeFuture = spawn {
            try {
                mergePartFiles()
                deleteTempDirectory()
                /*
                 * 合并期间被取消/暂停：不覆盖那两个终态，交给它们收尾 —— 和分片线程里的守卫一致
                 * （`cancel()` 可能正好在合并写文件时把状态置成 Cancelled）。
                 */
                if (isCancelled.load()) {
                    status = DownloadStatus.Cancelled
                    logger.info("合并阶段已取消")
                    return
                }
                if (isPaused.load()) {
                    status = DownloadStatus.Paused
                    logger.info("合并阶段已暂停")
                    return
                }
                status = DownloadStatus.Completed
                logger.info("文件合并完成，下载成功")

                // 触发下载完成回调
                if (let Some(callback) <- completeCallback) {
                    callback()
                }
            } catch (e: Exception) {
                if (isCancelled.load()) {
                    status = DownloadStatus.Cancelled
                    return
                }
                if (isPaused.load()) {
                    status = DownloadStatus.Paused
                    return
                }
                markFailed("文件合并失败: ${safeMessage(e)}")
                if (let Some(callback) <- errorCallback) {
                    callback(e)
                }
            }
        }
        synchronized(mergeMutex) {
            activeMergeFuture = Some(mergeFuture)
        }
    }

    /**
     * 没下完的分片长什么样：`part2（7.9 MB/9.9 MB）`。
     *
     * 失败原因里给出分片名与实际/期望大小 —— 「下载结束但没有文件」以前只有一句话，看不出是
     * 分片没下完、还是预下载检测失败。
     */
    private func incompleteParts(): String {
        var text = ""
        synchronized(partFilesMutex) {
            for (i in 0..partFiles.size) {
                let expectedSize = partSizes[i]
                let actualSize = getFileSize(Path(partFiles[i]))
                if (actualSize != expectedSize) {
                    if (!text.isEmpty()) {
                        text += "；"
                    }
                    text += "part${i}（${actualSize}/${expectedSize} 字节）"
                }
            }
        }
        if (text.isEmpty()) {
            "分片缺失"
        } else {
            text
        }
    }

    /**
     * 获取文件大小
     */
    private func getFileSize(path: Path): Int64 {
        try {
            let file = File(path, OpenMode.Read)
            // 定位到文件末尾获取大小
            file.seek(SeekPosition.End(0))
            let size = file.position
            file.close()
            size
        } catch (e: Exception) {
            0
        }
    }

    /**
     * 检查所有分片文件是否都存在且大小正确
     */
    private func checkAllPartsExist(): Bool {
        synchronized(partFilesMutex) {
            for (i in 0..partFiles.size) {
                let partPath = partFiles[i]
                let expectedSize = partSizes[i]
                let path = Path(partPath)

                if (!exists(path)) {
                    logger.debug("分片文件不存在: ${partPath}")
                    return false
                }

                // 检查文件大小
                let actualSize = getFileSize(path)
                if (actualSize != expectedSize) {
                    logger.debug("分片文件大小不匹配: ${partPath}, 预期: ${expectedSize}, 实际: ${actualSize}")
                    return false
                }
            }
            true
        }
    }

    /**
     * Delete策略：合并前删除已存在的文件
     */
    private func deleteExistingFileForMerge(outputPath: Path): Unit {
        try {
            remove(outputPath)
            logger.info("已删除已存在的文件: ${config.savePath}")
        } catch (e: Exception) {
            logger.error("删除已存在文件失败: ${safeMessage(e)}")
            throw Exception("[文件删除错误] 无法删除已存在的文件: ${safeMessage(e)}")
        }
    }

    /**
     * 合并所有分片文件
     */
    private func mergePartFiles(): Unit {
        let outputPath = Path(config.savePath)
        logger.info("开始合并分片文件到: ${config.savePath}")

        // Delete策略：在合并前删除已存在的文件
        if (exists(outputPath)) {
            match (config.fileExistsAction) {
                case FileExistsAction.Delete => deleteExistingFileForMerge(outputPath)
                case _ => ()
            }
        }

        let outputFile = File(outputPath, OpenMode.Write)
        var mergedCount: Int64 = 0
        let totalParts: Int64 = partFiles.size

        try {
            synchronized(partFilesMutex) {
                for (partPath in partFiles) {
                    mergedCount++
                    logger.info("正在合并分片文件 [${mergedCount}/${totalParts}]: ${partPath}")

                    let partFile = File(Path(partPath), OpenMode.Read)
                    let buffer = Array<Byte>(config.bufferSize, repeat: 0)
                    var partBytesRead: Int64 = 0

                    while (true) {
                        let bytesRead = partFile.read(buffer)
                        if (bytesRead <= 0) {
                            break
                        }
                        outputFile.write(buffer[0..bytesRead])
                        partBytesRead += bytesRead
                    }

                    partFile.close()
                    logger.info("已合并分片文件: ${partPath} (${partBytesRead} 字节)")

                    // 删除分片文件
                    try {
                        remove(Path(partPath))
                        logger.info("已删除分片文件: ${partPath}")
                    } catch (e: Exception) {
                        logger.warn("删除分片文件失败: ${partPath}, ${safeMessage(e)}")
                    }
                }
            }
        } catch (e: Exception) {
            outputFile.close()
            throw Exception("[文件合并错误] ${safeMessage(e)}")
        }

        outputFile.close()
        logger.info("分片文件合并完成，共合并 ${mergedCount} 个分片")

        /*
         * 合并结果自己再量一次。
         *
         * 分片齐了仍然可能写出大小不对的文件（磁盘写失败、分片在合并途中被动过）。截断的文件
         * 会被下游当成"已经下好"（`FileExistsAction.Skip` 只看在不在），而校验只在调用方有哈希时
         * 才做 —— 不知道大小的调用方就该由这里挡住。把结果删掉并抛异常：留着比没有更糟。
         */
        if (config.totalSize > 0) {
            let mergedSize = getFileSize(outputPath)
            if (mergedSize != config.totalSize) {
                try {
                    remove(outputPath)
                } catch (e: Exception) {
                    logger.warn("删除大小不对的合并结果失败: ${safeMessage(e)}")
                }
                throw Exception("合并结果大小不符: 期望 ${config.totalSize} 字节，实际 ${mergedSize} 字节")
            }
        }
    }

    /**
     * 下载指定范围的数据到分片文件
     * 下载中文件: partN
     * 完成后重命名为: partN.comp
     */
    private func downloadRangeToPartFile(startPos: Int64, endPos: Int64, threadId: Int64): Unit {
        var retryCount: Int64 = 0
        var currentPos = startPos // 记录当前下载位置,用于断点续传

        // 下载中的临时文件路径（在临时文件夹内）
        let tempPartPath = "${tempDir}/part${threadId}"
        // 下载完成后的文件路径
        let completedPartPath = "${tempDir}/part${threadId}.comp"
        let expectedSize = endPos - startPos + 1

        // 检查已完成的分片是否存在
        let completedPath = Path(completedPartPath)
        if (exists(completedPath)) {
            let actualSize = getFileSize(completedPath)
            if (actualSize == expectedSize) {
                logger.info("检测到已完成分片 ${completedPartPath}，跳过下载")
                downloadedBytes.fetchAdd(actualSize)
                return
            } else {
                // 大小不正确，删除重新下载
                logger.warn("分片文件大小不正确，重新下载", ("path", completedPartPath), ("actual", actualSize),
                    ("expected", expectedSize))
                try {
                    remove(completedPath)
                } catch (e: Exception) {
                    logger.warn("删除无效分片文件失败: ${safeMessage(e)}")
                }
            }
        }

        // 检查临时文件是否存在（断点续传）
        let tempPath = Path(tempPartPath)
        if (exists(tempPath)) {
            let actualSize = getFileSize(tempPath)
            if (actualSize > 0 && actualSize < expectedSize) {
                // 部分下载，从断点继续
                currentPos = startPos + actualSize
                logger.info(
                    "检测到未完成分片 ${tempPartPath}，已下载 ${actualSize}/${expectedSize} 字节，从断点继续下载")
                downloadedBytes.fetchAdd(actualSize)
            } else if (actualSize >= expectedSize) {
                // 临时文件已完整，重命名为完成文件
                try {
                    rename(tempPath, to: completedPath)
                    logger.info("分片临时文件已完整，重命名为完成文件", ("from", tempPartPath), ("to", completedPartPath))
                    downloadedBytes.fetchAdd(actualSize)
                    return
                } catch (e: Exception) {
                    logger.warn("重命名分片文件失败: ${safeMessage(e)}")
                }
            } else {
                // 文件大小异常，删除重新下载
                logger.warn("分片临时文件异常，重新下载", ("path", tempPartPath), ("actual", actualSize))
                try {
                    remove(tempPath)
                } catch (e: Exception) {
                    logger.warn("删除临时分片文件失败: ${safeMessage(e)}")
                }
                currentPos = startPos
            }
        }

        while (retryCount < config.maxRetries) {
            if (isCancelled.load() || isPaused.load()) {
                return
            }

            try {
                // 创建HTTP请求
                // 设置Range头
                let rangeHeader = "bytes=${currentPos}-${endPos}"
                logger.debug("线程${threadId}请求范围: ${rangeHeader}")

                // 发送请求（池化：同 host 复用连接，避免每个分片都重做一次握手）
                logRequest("GET", config.url, effectiveHeaders(config))
                let response = pooledRequest(config, Method.Get).header("Range", rangeHeader).sendStream()

                if (response.status != 200 && response.status != 206) {
                    throw Exception("[正式下载错误] HTTP请求失败, 状态码: ${response.status}")
                }

                /*
                 * 服务器无视 Range，回了整个文件（200）。
                 *
                 * 这时响应正文是**从 0 开始的整份**，跟"接着上次断点追加"的前提正好相反：按追加落盘，
                 * 文件就会多出 N 个字节；而大小又恰好对得上（已下的前端 + N == 期望分片大小），于是被
                 * 当成完整分片合并进最终文件，最终文件整体偏移错位、sha1 必然不符 —— 日志里表现为
                 * 反复"校验不符"。有的 CDN 就是这样（预下载检测里也记着 CurseForge 对 Range 一律 404、
                 * 普通 GET 200）。
                 *
                 * 所以只认正文的实际含义：永远从 0 落盘，并把进度和位置一起回到本分片起点。
                 */
                if (response.status == 200) {
                    if (currentPos > startPos) {
                        logger.warn("服务器忽略 Range 回了 200 整份，本分片从 0 重新落盘", ("threadId", threadId),
                            ("startPos", startPos), ("currentPos", currentPos))
                        downloadedBytes.fetchAdd(-(currentPos - startPos))
                    }
                    currentPos = startPos
                    if (exists(tempPath)) {
                        remove(tempPath)
                    }
                }

                // 创建临时分片文件
                let file = try {
                    // 检查是否有已下载的部分（断点续传）
                    if (exists(tempPath) && currentPos > startPos) {
                        // 追加模式
                        File(tempPath, OpenMode.ReadWrite)
                    } else {
                        // 新建文件
                        File(tempPath, OpenMode.Write)
                    }
                } catch (e: Exception) {
                    throw Exception("[文件创建错误] 无法创建分片文件: ${safeMessage(e)}")
                }

                // 如果是断点续传，定位到文件末尾
                if (exists(tempPath) && currentPos > startPos) {
                    try {
                        file.seek(SeekPosition.End(0))
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[文件定位错误] 无法定位到文件末尾: ${safeMessage(e)}")
                    }
                }

                // 读取数据并写入文件
                let inputStream = response.stream()
                let buffer = Array<Byte>(config.bufferSize, repeat: 0)
                var totalRead: Int64 = 0

                // try/finally 兜住所有退出路径（取消/暂停的 return、读取异常），保证流式租约一定归还
                try {
                while (true) {
                    if (isCancelled.load() || isPaused.load()) {
                        file.close()
                        return
                    }

                    let bytesRead = try {
                        inputStream.read(buffer)
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[数据读取错误] 从网络读取数据失败: ${safeMessage(e)}")
                    }

                    if (bytesRead <= 0) {
                        break
                    }

                    try {
                        file.write(buffer[0..bytesRead])
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[文件写入错误] 写入分片文件失败: ${safeMessage(e)}")
                    }

                    totalRead += bytesRead
                    currentPos += bytesRead // 更新当前位置

                    // 更新进度
                    downloadedBytes.fetchAdd(bytesRead)

                    // 节流触发进度回调
                    synchronized(progressMutex) {
                        let currentTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
                        if (currentTime - lastProgressCallbackTime >= progressCallbackInterval) {
                            lastProgressCallbackTime = currentTime
                            if (let Some(callback) <- progressCallback) {
                                let speed = calculateSpeed()
                                let progress = DownloadProgress(
                                    downloadedBytes: downloadedBytes.load(),
                                    totalBytes: config.totalSize,
                                    speed: speed
                                )
                                callback(progress)
                            }
                        }
                    }
                }

                file.close()

                } finally {
                    // 读完 EOF 时租约已自动归还；这里兜住提前退出与异常路径
                    response.close()
                }

                // 下载完成，重命名临时文件为完成文件
                try {
                    rename(tempPath, to: completedPath)
                    logger.info("线程${threadId}下载完成", ("tempPath", tempPartPath),
                        ("completedPath", completedPartPath), ("totalRead", totalRead))
                } catch (e: Exception) {
                    logger.error("重命名分片文件失败: ${safeMessage(e)}")
                    throw Exception("[文件重命名错误] 无法重命名分片文件: ${safeMessage(e)}")
                }

                return
            } catch (e: Exception) {
                retryCount++
                if (retryCount < config.maxRetries) {
                    logger.warn("线程${threadId}下载失败,准备重试 ${retryCount}/${config.maxRetries}",
                        ("error", e.message), ("currentPos", currentPos))

                    // 触发重试回调
                    if (let Some(callback) <- retryCallback) {
                        callback(retryCount, config.maxRetries)
                    }

                    // 重试前等待,使用指数退避
                    sleep(Duration.second * (1 << (retryCount - 1)))
                } else {
                    throw e
                }
            }
        }
    }

    /**
     * 处理单线程下载时已存在的文件
     * 如果目标文件或临时文件已存在，则重命名当前下载的文件
     */
    private func handleExistingFilesForSingleThread(): Unit {
        let tempPath = "${config.savePath}.temp"
        let finalPath = config.savePath
        
        // 检查临时文件或目标文件是否存在
        if (exists(Path(tempPath)) || exists(Path(finalPath))) {
            // 生成新的目标文件路径
            let newSavePath = generateNewFilePath(config.savePath)
            config.savePath = newSavePath
            logger.info("文件已存在，当前下载文件重命名为: ${newSavePath}")
        }
    }   

    /**
     * 单线程下载（下载到.temp文件，完成后重命名为目标文件）
     * 不支持断点续传，每次重试都从头开始下载
     */
    private func downloadSingleThread(): Unit {
        var retryCount: Int64 = 0

        // 检查并处理已存在的文件
        handleExistingFilesForSingleThread()

        // 临时文件路径（在处理完已存在文件后再计算）
        let tempPath = "${config.savePath}.temp"
        let tempPathObj = Path(tempPath)
        let finalPath = Path(config.savePath)

        while (retryCount < config.maxRetries) {
            if (isCancelled.load() || isPaused.load()) {
                return
            }

            try {
                // 创建HTTP请求（池化：同 host 复用连接）
                logRequest("GET", config.url, effectiveHeaders(config))
                let response = pooledRequest(config, Method.Get).sendStream()

                if (response.status != 200) {
                    throw Exception("[正式下载错误] HTTP请求失败, 状态码: ${response.status}")
                }

                /*
                 * 从**这个 GET 自己的响应头**拿文件大小。
                 *
                 * 为什么必须在这里做：跳过 HEAD 之后，`config.totalSize` 就是 0，而它有两个作用 ——
                 * 1. 进度条的分母（为 0 时上层只能显示"已下多少"，没有百分比）；
                 * 2. 下面那个"读满就收尾"的短路条件（`config.totalSize > 0 && totalRead >= config.totalSize`）。
                 *    少了它，服务端 keep-alive 不关连接时最后一次 read 会阻塞到 readTimeout（60 秒），
                 *    表现就是"文件其实下完了，却卡住不动"——实测踩过。
                 *
                 * 只在原来没有大小的时候填：不覆盖 HEAD 已经拿到的值（分片路径依赖它）。
                 */
                if (config.totalSize <= 0) {
                    if (let Some(lengthText) <- response.header("content-length")) {
                        try {
                            let size = Int64.parse(lengthText.trimAscii())
                            if (size > 0) {
                                config.totalSize = size
                                logger.info("从响应头获取到文件大小", ("totalSize", size))
                            }
                        } catch (_: Exception) {
                            /* 头不合法就当没有：进度退化成"已下字节"，不影响下载本身。 */
                            ()
                        }
                    }
                }

                // 创建临时文件（每次重试都重新创建，覆盖之前的临时文件）
                let file = File(tempPathObj, OpenMode.Write)
                logger.info("创建临时文件", ("tempPath", tempPath))

                // 读取数据并写入文件
                let inputStream = response.stream()
                let buffer = Array<Byte>(config.bufferSize, repeat: 0)
                var totalRead: Int64 = 0

                // try/finally 兜住所有退出路径（取消/暂停的 return、读取异常），保证流式租约一定归还
                try {
                while (true) {
                    if (isCancelled.load() || isPaused.load()) {
                        file.close()
                        return
                    }

                    // 收尾修复：已按 Content-Length 读满就结束，不再等 EOF。
                    // 服务端 keep-alive 不关连接时，最后一次 read 会阻塞到 readTimeout(默认60s)，
                    // 表现为「文件已下完、进度 100% 后整个界面卡死」。
                    if (config.totalSize > 0 && totalRead >= config.totalSize) {
                        break
                    }

                    let bytesRead = try {
                        inputStream.read(buffer)
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[数据读取错误] 从网络读取数据失败: ${safeMessage(e)}")
                    }

                    if (bytesRead <= 0) {
                        break
                    }

                    try {
                        file.write(buffer[0..bytesRead])
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[文件写入错误] 写入文件失败: ${safeMessage(e)}")
                    }

                    totalRead += bytesRead

                    // 更新进度
                    downloadedBytes.store(totalRead)

                    // 节流触发进度回调
                    synchronized(progressMutex) {
                        let currentTime = DateTime.now().toUnixTimeStamp().toNanoseconds()
                        if (currentTime - lastProgressCallbackTime >= progressCallbackInterval) {
                            lastProgressCallbackTime = currentTime
                            if (let Some(callback) <- progressCallback) {
                                let speed = calculateSpeed()
                                let progress = DownloadProgress(
                                    downloadedBytes: totalRead,
                                    totalBytes: config.totalSize,
                                    speed: speed
                                )
                                callback(progress)
                            }
                        }
                    }
                }

                file.close()
                } finally {
                    // 单线程下载按 Content-Length 提前 break，不会读到 EOF，必须显式归还
                    response.close()
                }
                logger.info("单线程下载完成", ("totalRead", totalRead))

                // 下载完成，重命名临时文件为目标文件
                try {
                    rename(tempPathObj, to: finalPath)
                    logger.info("重命名临时文件为目标文件", ("from", tempPath), ("to", config.savePath))
                } catch (e: Exception) {
                    throw Exception("[文件重命名错误] 无法重命名临时文件: ${safeMessage(e)}")
                }

                return
            } catch (e: Exception) {
                // 取消/暂停引发的异常不重试：直接正常返回，由包装层按标志收尾为
                // Cancelled/Paused，避免「已取消」被后续重试/失败覆盖
                if (isCancelled.load() || isPaused.load()) {
                    logger.info("单线程下载因取消/暂停中断")
                    return
                }
                retryCount++
                if (retryCount < config.maxRetries) {
                    logger.warn("单线程下载失败,准备重试 ${retryCount}/${config.maxRetries}", ("error", e.message))

                    // 触发重试回调
                    if (let Some(callback) <- retryCallback) {
                        callback(retryCount, config.maxRetries)
                    }

                    sleep(Duration.second * (1 << (retryCount - 1)))
                } else {
                    // 下载失败，删除临时文件
                    try {
                        if (exists(tempPathObj)) {
                            remove(tempPathObj)
                            logger.info("下载失败，已删除临时文件", ("tempPath", tempPath))
                        }
                    } catch (deleteError: Exception) {
                        logger.warn("删除临时文件失败: ${deleteError.message}")
                    }
                    throw e
                }
            }
        }
    }
}
