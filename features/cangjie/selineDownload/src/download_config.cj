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
        this
    }
}
