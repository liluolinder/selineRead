package selineDownload

import std.sync.{Mutex, AtomicInt64, AtomicBool}
import std.fs.{File, Path, OpenMode, exists, remove, rename, Directory}
import std.io.{InputStream, SeekPosition}
import std.collection.ArrayList
import std.convert.*
import std.time.DateTime
import stdx.log.*
import stdx.encoding.json.*
import linderHttp.{LinderHttpClient, HttpHeader, RequestMethod, RequestUrl}

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
    private let logger: Logger = getGlobalLogger()

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
            let headHttp = LinderHttpClient(
                url: RequestUrl.from(config.url),
                method: RequestMethod.HEAD,
                readTimeout: config.readTimeout,
                writeTimeout: config.writeTimeout
            )

            // 设置自定义请求头
            for ((key, value) in config.headers) {
                headHttp.headers.set(key: key, value: value)
            }

            let headResponse = headHttp.send()

            if (headResponse.status != 200) {
                let errorMsg = "[预下载检测错误] HEAD请求失败, HTTP状态码: ${headResponse.status}"
                logger.error(errorMsg)
                if (let Some(callback) <- errorCallback) {
                    callback(Exception(errorMsg))
                }
                return false
            }

            if (let Some(contentLength) <- headResponse.getHeader("content-length")) {
                let lengthStr = contentLength[0]
                config.totalSize = Int64.parse(lengthStr)
                logger.info("获取到文件大小", ("totalSize", config.totalSize))
            } else {
                logger.warn("响应头中缺少Content-Length字段,无法获取文件大小")
            }

            // 检查Accept-Ranges头
            if (let Some(acceptRanges) <- headResponse.getHeader("accept-ranges")) {
                if (acceptRanges.contains("bytes")) {
                    logger.info("检测到Accept-Ranges: bytes,服务器支持断点续传")
                    return true
                }
            }

            if (config.totalSize > 0) {
                logger.info("开始测试Range请求...")
                let testHttp = LinderHttpClient(
                    url: RequestUrl.from(config.url),
                    method: RequestMethod.GET,
                    readTimeout: config.readTimeout,
                    writeTimeout: config.writeTimeout
                )

                // 设置自定义请求头（在设置Range之前）
                for ((key, value) in config.headers) {
                    testHttp.headers.set(key: key, value: value)
                }

                // 只请求前1个字节进行测试
                testHttp.headers.set(key: "Range", value: "bytes=0-0")

                let testResponse = testHttp.send()

                // 检查Content-Range头
                if (let Some(contentRange) <- testResponse.getHeader("content-range")) {
                    logger.info("检测到Content-Range头,服务器支持断点续传")
                    return true
                }

                logger.info("服务器不支持断点续传")
                return false
            }

            false
        } catch (e: Exception) {
            let errorMsg = "[预下载检测错误] ${e.message}"
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

        // 检测是否支持断点续传
        config.supportRange = checkRangeSupport()

        // 如果预下载检测失败(totalSize为0),直接退出
        if (config.totalSize == 0) {
            status = DownloadStatus.Failed
            logger.error("预下载检测失败,无法获取文件大小,终止下载")
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
     */
    public func cancel(): Unit {
        logger.info("取消下载")
        isCancelled.store(true)
        status = DownloadStatus.Cancelled

        // 触发取消下载回调
        if (let Some(callback) <- cancelCallback) {
            callback()
        }

        // 等待所有线程结束
        for (f in futures) {
            try {
                f.get()
            } catch (e: Exception) {
                // 忽略异常
            }
        }
        futures.clear()
    }

    /**
     * 等待下载完成
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

    /**
     * 初始化临时文件夹
     * 检查是否存在有效的下载信息，如果匹配则继续，否则创建新文件夹
     */
    private func initTempDirectory(): Bool {
        // 临时文件夹路径: savePath + ".tmp"
        tempDir = "${config.savePath}.tmp"
        infoJsonPath = "${tempDir}/download_info.json"
        let tempDirPath = Path(tempDir)

        // 检查临时文件夹是否存在
        if (exists(tempDirPath)) {
            // 检查JSON信息文件是否存在
            let jsonPath = Path(infoJsonPath)
            if (exists(jsonPath)) {
                // 读取并检查JSON信息
                if (checkDownloadInfo()) {
                    logger.info("检测到有效的下载记录，继续下载", ("tempDir", tempDir))
                    return true
                } else {
                    // 信息不匹配，创建新的临时文件夹（带时间戳）
                    let timestamp = DateTime.now().toUnixTimeStamp().toSeconds()
                    let newTempDir = "${config.savePath}.tmp_${timestamp}"
                    logger.info("下载信息不匹配，创建新临时文件夹", ("oldDir", tempDir), ("newDir", newTempDir))

                    // 重命名旧文件夹
                    try {
                        rename(tempDirPath, to: Path(newTempDir))
                        logger.info("已保留旧临时文件夹", ("path", newTempDir))
                    } catch (e: Exception) {
                        logger.warn("重命名旧临时文件夹失败: ${e.message}")
                    }
                }
            }
        }

        // 创建新的临时文件夹
        try {
            Directory.create(tempDirPath, recursive: true)
            logger.info("创建临时文件夹", ("tempDir", tempDir))
        } catch (e: Exception) {
            logger.error("创建临时文件夹失败: ${e.message}")
            return false
        }

        return true
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
            logger.warn("读取下载信息失败: ${e.message}")
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
            logger.error("保存下载信息失败: ${e.message}")
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
            logger.warn("删除临时文件夹失败: ${e.message}")
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
            logger.warn("删除信息文件失败: ${e.message}")
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
                status = DownloadStatus.Completed
                logger.info("下载完成")
                if (let Some(callback) <- completeCallback) {
                    callback()
                }
            } catch (e: Exception) {
                status = DownloadStatus.Failed
                logger.error("下载失败: ${e.message}")
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
            status = DownloadStatus.Failed
            logger.error("初始化临时文件夹失败")
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

            // 直接合并（加入futures以便await等待）
            let mergeFuture = spawn {
                try {
                    mergePartFiles()
                    deleteTempDirectory()
                    status = DownloadStatus.Completed
                    logger.info("文件合并完成，下载成功")
                    
                    // 触发下载完成回调
                    if (let Some(callback) <- completeCallback) {
                        callback()
                    }
                } catch (e: Exception) {
                    status = DownloadStatus.Failed
                    logger.error("文件合并失败: ${e.message}")
                    if (let Some(callback) <- errorCallback) {
                        callback(e)
                    }
                }
            }
            futures.add(mergeFuture)
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
                    logger.error("线程${i}下载失败: ${e.message}")
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
                    // 忽略
                }
            }

            if (!isCancelled.load() && !isPaused.load()) {
                // 所有分片下载完成，开始合并
                logger.info("所有分片下载完成，开始合并文件...")
                try {
                    mergePartFiles()
                    deleteTempDirectory()
                    status = DownloadStatus.Completed
                    logger.info("文件合并完成，下载成功")
                    
                    // 触发下载完成回调
                    if (let Some(callback) <- completeCallback) {
                        callback()
                    }
                } catch (e: Exception) {
                    status = DownloadStatus.Failed
                    logger.error("文件合并失败: ${e.message}")
                    if (let Some(callback) <- errorCallback) {
                        callback(e)
                    }
                }
            }
        }
        futures.add(monitorFuture)
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
            logger.error("删除已存在文件失败: ${e.message}")
            throw Exception("[文件删除错误] 无法删除已存在的文件: ${e.message}")
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
                        logger.warn("删除分片文件失败: ${partPath}, ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            outputFile.close()
            throw Exception("[文件合并错误] ${e.message}")
        }

        outputFile.close()
        logger.info("分片文件合并完成，共合并 ${mergedCount} 个分片")
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
                    logger.warn("删除无效分片文件失败: ${e.message}")
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
                    logger.warn("重命名分片文件失败: ${e.message}")
                }
            } else {
                // 文件大小异常，删除重新下载
                logger.warn("分片临时文件异常，重新下载", ("path", tempPartPath), ("actual", actualSize))
                try {
                    remove(tempPath)
                } catch (e: Exception) {
                    logger.warn("删除临时分片文件失败: ${e.message}")
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
                let http = LinderHttpClient(
                    url: RequestUrl.from(config.url),
                    method: RequestMethod.GET,
                    readTimeout: config.readTimeout,
                    writeTimeout: config.writeTimeout
                )

                // 设置自定义请求头（在设置Range之前）
                for ((key, value) in config.headers) {
                    http.headers.set(key: key, value: value)
                }

                // 设置Range头
                let rangeHeader = "bytes=${currentPos}-${endPos}"
                http.headers.set(key: "Range", value: rangeHeader)
                logger.debug("线程${threadId}请求范围: ${rangeHeader}")

                // 发送请求
                let response = http.send()

                if (response.status != 200 && response.status != 206) {
                    throw Exception("[正式下载错误] HTTP请求失败, 状态码: ${response.status}")
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
                    throw Exception("[文件创建错误] 无法创建分片文件: ${e.message}")
                }

                // 如果是断点续传，定位到文件末尾
                if (exists(tempPath) && currentPos > startPos) {
                    try {
                        file.seek(SeekPosition.End(0))
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[文件定位错误] 无法定位到文件末尾: ${e.message}")
                    }
                }

                // 读取数据并写入文件
                let inputStream = response.getBodyStream()
                let buffer = Array<Byte>(config.bufferSize, repeat: 0)
                var totalRead: Int64 = 0

                while (true) {
                    if (isCancelled.load() || isPaused.load()) {
                        file.close()
                        return
                    }

                    let bytesRead = try {
                        inputStream.read(buffer)
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[数据读取错误] 从网络读取数据失败: ${e.message}")
                    }

                    if (bytesRead <= 0) {
                        break
                    }

                    try {
                        file.write(buffer[0..bytesRead])
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[文件写入错误] 写入分片文件失败: ${e.message}")
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

                // 下载完成，重命名临时文件为完成文件
                try {
                    rename(tempPath, to: completedPath)
                    logger.info("线程${threadId}下载完成", ("tempPath", tempPartPath),
                        ("completedPath", completedPartPath), ("totalRead", totalRead))
                } catch (e: Exception) {
                    logger.error("重命名分片文件失败: ${e.message}")
                    throw Exception("[文件重命名错误] 无法重命名分片文件: ${e.message}")
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
                // 创建HTTP请求
                let http = LinderHttpClient(
                    url: RequestUrl.from(config.url),
                    method: RequestMethod.GET,
                    readTimeout: config.readTimeout,
                    writeTimeout: config.writeTimeout
                )

                // 设置自定义请求头
                for ((key, value) in config.headers) {
                    http.headers.set(key: key, value: value)
                }

                // 发送请求
                let response = http.send()

                if (response.status != 200) {
                    throw Exception("[正式下载错误] HTTP请求失败, 状态码: ${response.status}")
                }

                // 创建临时文件（每次重试都重新创建，覆盖之前的临时文件）
                let file = File(tempPathObj, OpenMode.Write)
                logger.info("创建临时文件", ("tempPath", tempPath))

                // 读取数据并写入文件
                let inputStream = response.getBodyStream()
                let buffer = Array<Byte>(config.bufferSize, repeat: 0)
                var totalRead: Int64 = 0

                while (true) {
                    if (isCancelled.load() || isPaused.load()) {
                        file.close()
                        return
                    }

                    let bytesRead = try {
                        inputStream.read(buffer)
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[数据读取错误] 从网络读取数据失败: ${e.message}")
                    }

                    if (bytesRead <= 0) {
                        break
                    }

                    try {
                        file.write(buffer[0..bytesRead])
                    } catch (e: Exception) {
                        file.close()
                        throw Exception("[文件写入错误] 写入文件失败: ${e.message}")
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
                logger.info("单线程下载完成", ("totalRead", totalRead))

                // 下载完成，重命名临时文件为目标文件
                try {
                    rename(tempPathObj, to: finalPath)
                    logger.info("重命名临时文件为目标文件", ("from", tempPath), ("to", config.savePath))
                } catch (e: Exception) {
                    throw Exception("[文件重命名错误] 无法重命名临时文件: ${e.message}")
                }

                return
            } catch (e: Exception) {
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
