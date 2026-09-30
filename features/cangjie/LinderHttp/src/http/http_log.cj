/*
 * 这个库的日志：一个属于它自己的 logger，**默认什么都不做**。
 *
 * 单独一个文件，理由和 `selineDownload` 的 `download_log.cj` 一样：这是整个库里**唯一**决定
 * 「日志往哪写、写不写」的地方。原先它散落在 `client.cj` 的 `buildTransportClient` 里，那个函数是
 * 建传输客户端的，日志跟它没关系，而且落点被写死成标准输出：
 *
 *     let transportLogger = SimpleLogger(getStdOut())
 *     transportLogger.level = config.transportLogLevel
 *
 * 两个问题：
 * 1. **落点写死**。宿主把标准输出重定向到文件，框架日志就混进了它的日志；而宿主想写文件也没门路。
 * 2. 没有落点也被写死成"标准输出"这件事，让"默认关闭"变成一个需要解释的约定（级别默认 OFF 是好的，
 *    但落点不该由库来选）。
 *
 * 现在：默认落点是空流（丢弃），想记日志就把 [HttpLogger.sink] 指到文件或控制台，再打开
 * [HttpLogger.level]。
 *
 * ```cangjie
 * let log = File(Path("http.log"), OpenMode.Append)
 * HttpLogger.sink = log
 * HttpLogger.level = LogLevel.INFO
 * ```
 *
 * **流由宿主持有**：库不关它、也不替它缓冲 —— 库不该决定宿主的文件生命周期。
 */
package linderHttp.http

import std.io.OutputStream
import stdx.log.{LogLevel, Logger}
import stdx.logger.SimpleLogger

/**
 * 什么都不写的输出流，作为本库日志的默认落点。
 *
 * 标准库没有现成的空流实现，所以自己写一个：它只有"把字节丢掉"这一个语义，正是"默认不记"需要的
 * 东西，也免得为了一个开关去引一个文件或控制台句柄。
 */
class NullOutputStream <: OutputStream {
    init() {}

    public func write(buffer: Array<Byte>): Unit {
        /* 丢掉。 */
        let _ = buffer
    }

    public func flush(): Unit {
        ()
    }
}

/**
 * 本库日志的收口。
 *
 * 做成一个全静态的类而不是几个模块级函数：库的其它部分都是 class 形态（`HttpClient` /
 * `HttpClientBuilder` / `HttpRequest`），日志没有理由例外；而且"默认不写"这件事现在有一个**名字**
 * 可以指向。
 *
 * 不收实例（`private init`）：这里没有状态可言，只有"一个落点、一个级别"。
 */
public class HttpLogger {

    /** 日志的落点。默认空流（丢弃）。 */
    private static var currentSink: OutputStream = NullOutputStream()

    /** 当前级别。默认 OFF。 */
    private static var currentLevel: LogLevel = LogLevel.OFF

    private init() {}

    /**
     * 日志写到哪。给一个 `OutputStream` 即可。
     *
     * **所有权归调用方**：库不关它、也不替它缓冲。
     *
     * 写文件 —— 追加，不覆盖历史：
     *
     * ```cangjie
     * import std.fs.{File, OpenMode, Path, exists, Directory}
     *
     * let directory = Path("logs")
     * let path = directory.join("http.log")
     * if (!exists(directory)) {
     *     Directory.create(directory, recursive: true)   // 目录要先建，File 不会替你建
     * }
     * let file = File(path, OpenMode.Append)             // Write 会清掉旧内容，排查场景一般用 Append
     * HttpLogger.sink = file
     * HttpLogger.level = LogLevel.INFO
     * ```
     *
     * 写控制台：
     *
     * ```cangjie
     * import std.env.{getStdErr, getStdOut}
     *
     * HttpLogger.sink = getStdErr()   // 诊断信息，别混进程序自己的标准输出
     * HttpLogger.sink = getStdOut()   // 确实要跟正常输出排在一起时才用这个
     * HttpLogger.level = LogLevel.INFO
     * ```
     */
    public static mut prop sink: OutputStream {
        get() {
            currentSink
        }
        set(value) {
            currentSink = value
        }
    }

    /**
     * 日志级别：读就是当前级别，写就是开关。默认已关。
     *
     * 落点没换过时，只打开级别也什么都不写（默认落点是空流）—— 两件事都要给是刻意的：
     * 「级别」管啰不啰嗦，「落点」管往哪里去。混成一个开关，会让"我就想看看"变成往宿主的输出里灌。
     *
     * 注意：这里设的是**默认值**。单个客户端自己的 `ClientConfig.transportLogLevel` 仍然优先 ——
     * 那是一个客户端的显式选择，见 `ClientConfig.transportLogger()`。
     */
    public static mut prop level: LogLevel {
        get() {
            currentLevel
        }
        set(value) {
            currentLevel = value
        }
    }

    /**
     * 按级别建一个接到当前落点上的 logger。
     *
     * `SimpleLogger` 除了底下的流之外没有状态，所以"一个落点 + 各自一个级别"这种做法是安全的：
     * 每个需要日志的客户端拿自己的一份，都写到同一个流上。
     */
    static func logger(level: LogLevel): Logger {
        let logger = SimpleLogger(currentSink)
        logger.level = level
        logger
    }
}
