package selineDownload

import std.collection.HashMap

/**
 * 重复文件名处理策略
 */
public enum FileExistsAction {
    | Delete // 删除已存在的文件
    | Rename // 在文件名后加(N)，如 file(1).txt
    | Skip // 跳过下载
}

/**
 * 下载配置类
 * 用于配置下载任务的各种参数
 */
public class DownloadConfig {
    /**
     * 下载URL
     */
    public var url: String = ""

    /**
     * 保存路径
     */
    public var savePath: String = ""

    /**
     * 线程数(默认为0,表示自动根据文件大小决定)
     */
    public var threadCount: Int64 = 0

    /**
     * 发送请求超时时间(默认60秒)
     */
    public var writeTimeout: Duration = Duration.minute 

    /**
     * 读取超时时间(默认60秒,对于大文件和网络不稳定环境更友好)
     */
    public var readTimeout: Duration = Duration.minute 

    /**
     * 是否支持断点续传
     */
    public var supportRange: Bool = false

    /**
     * 是否启用断点续传(默认true)
     * 如果设置为false,即使服务器支持断点续传,也使用单线程下载
     */
    public var enableRange: Bool = true

    /**
     * 文件总大小
     */
    public var totalSize: Int64 = 0

    /**
     * 每个线程的缓冲区大小(默认8KB)
     */
    public var bufferSize: Int64 = 8192

    /**
     * 最大重试次数(默认5次,对于网络不稳定环境更友好)
     */
    public var maxRetries: Int64 = 5

    /**
     * 自定义请求头
     */
    public var headers: HashMap<String, String> = HashMap<String, String>()

    /**
     * 重复文件名处理策略(默认重命名)
     */
    public var fileExistsAction: FileExistsAction = FileExistsAction.Rename

    /**
     * 同一个主机允许同时保持多少条连接（也是本库的**并发上限**）。
     *
     * 本库共用一个 `HttpClient`（见 `download_task.cj` 的 `sharedHttpClient`），它按 host 维护连接组：
     * 组内复用长连接，**并发超出这个数时请求排队等待**。所以这个值决定"同时能有几个文件真的在传"。
     *
     * 默认 16。原先写死 8：宿主即使把并发调到 16，多出来的请求也只是在池里排队 —— 滑块拉过 8 没有任何效果。
     *
     * 调高不是无代价的：同时开更多连接会让某些镜像限流、也更容易撞上握手失败（这类网络里握手本来就
     * 脆弱）。所以它是个配置而不是一个更大的常量，网络环境不友好时可以调回来。
     *
     * **只在客户端第一次被使用之前生效**：客户端是进程级共享的，建好之后改这个字段不会重建它。
     */
    public var maxConnectionsPerHost: Int64 = 16

    public init() {}

    /**
     * 设置下载URL
     */
    public func setUrl(url: String): DownloadConfig {
        this.url = url
        this
    }

    /**
     * 设置保存路径
     */
    public func setSavePath(path: String): DownloadConfig {
        this.savePath = path
        this
    }

    /**
     * 设置线程数
     */
    public func setThreadCount(count: Int64): DownloadConfig {
        this.threadCount = count
        this
    }

    /**
     * 设置发送请求超时时间
     */
    public func setWriteTimeout(timeout: Duration): DownloadConfig {
        this.writeTimeout = timeout
        this
    }

    /**
     * 设置读取超时时间
     */
    public func setReadTimeout(timeout: Duration): DownloadConfig {
        this.readTimeout = timeout
        this
    }

    /**
     * 设置缓冲区大小
     */
    public func setBufferSize(size: Int64): DownloadConfig {
        this.bufferSize = size
        this
    }

    /**
     * 设置最大重试次数
     */
    public func setMaxRetries(retries: Int64): DownloadConfig {
        this.maxRetries = retries
        this
    }

    /**
     * 添加自定义请求头
     * 注意：请求头会在发送分片请求前设置
     */
    public func addHeader(key: String, value: String): DownloadConfig {
        this.headers.add(key, value)
        this
    }

    /**
     * 批量设置请求头
     */
    public func setHeaders(headers: HashMap<String, String>): DownloadConfig {
        this.headers = headers
        this
    }

    /**
     * 设置重复文件名处理策略
     */
    public func setFileExistsAction(action: FileExistsAction): DownloadConfig {
        this.fileExistsAction = action
        this
    }

    /**
     * 设置是否启用断点续传
     */
    public func setEnableRange(enable: Bool): DownloadConfig {
        this.enableRange = enable
        return this
    }

    /**
     * 是否在正式下载前做一次 HEAD 预探测（拿文件大小、判断服务器是否支持 Range）。
     *
     * 默认 `true`：探测只服务于**分片**（分片需要总大小来切段，也需要知道服务器支不支持 Range）。
     * 关掉它（配合 `setEnableRange(false)`）就是"一个连接、一个请求、整包下完"，适合海量小文件：
     *
     * - 每个文件少发一个请求，几千个文件就是几千个请求省掉 —— 实测资源阶段 HEAD 占请求量的 43%；
     * - 这些探测请求会在连接池里反复占名额，是"下载越往后越慢"的一部分成因；
     * - 代价是这次的进度分母只能从 **GET 响应自己的 Content-Length** 拿（拿得到就没有代价，
     *   见 `downloadSingleThread`）。拿不到时进度按已下字节上报，总数未知。
     *
     * 与 `setEnableRange(false)` 的区别：那个还会照常探测（多一个请求），这个明确要求**不探测**。
     * 两者都关掉时 `downloadSingleThread` 走"直接 GET"的路径。
     */
    public var probeBeforeDownload: Bool = true

    /**
     * 设置是否做 HEAD 预探测。见 [probeBeforeDownload]。
     */
    public func setProbeBeforeDownload(enabled: Bool): DownloadConfig {
        this.probeBeforeDownload = enabled
        return this
    }
}
