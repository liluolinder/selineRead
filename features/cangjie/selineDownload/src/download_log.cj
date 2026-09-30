/*
 * 这个库的日志：一个属于它自己的 logger，**默认什么都不做**。
 *
 * 为什么单独一个文件：这是这份源码里唯一决定「日志往哪写、写不写」的地方。它原先散落在
 * `download_task.cj` 里（那个文件是下载任务实现），于是"哪些调用点在写日志"要靠通读实现文件才知道，
 * 而漏看一处就会破坏"默认不写"这个结论 —— 实际上原来就有两处漏了：`logRequest` 直接调
 * `getGlobalLogger()` 绕过了级别，`DownloadTask.logger` 又是构造时的快照且从未设过级别。
 *
 * 为什么默认什么都不做：本库原先用 `getGlobalLogger()`。启动器把那个全局 logger 设成 INFO 并指向
 * `~/.sml/launcher.log`，于是本库每条 INFO —— 分片进度、断点续传探测、每个分片的合并与重命名、
 * 每次重试 —— 都原样进了用户的日志文件。一次整合包安装几十个文件、每个文件几十行，日志很快以 MB 计，
 * 而其中绝大多数对用户没有意义：用户要看的是「装到哪了 / 失败了」，那是宿主自己的进度回调在管。
 *
 * 所以默认的**落点**是一个空流（不是标准错误）：库没被要求记日志时，一行都不该出现在任何地方 ——
 * 包括宿主可能重定向出去的标准错误。
 *
 * 要日志就两件事：把 [DownloadLogger.sink] 指到一个流（文件、标准输出、别的），把
 * [DownloadLogger.level] 打开。**流由宿主持有**：库不替它开关文件、也绝不关它 —— 库不该决定宿主的
 * 文件生命周期。
 *
 * ```cangjie
 * let log = File(Path("download.log"), OpenMode.Append)
 * DownloadLogger.sink = log
 * DownloadLogger.level = LogLevel.INFO
 * ```
 */
package selineDownload

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
 * 做成一个全静态的类而不是几个模块级函数：库的其它部分都是 class 形态（[DownloadManager] /
 * [DownloadTask] / [DownloadConfig]），日志没有理由例外；而且"默认不写"这件事现在有一个**名字**
 * 可以指向，不必靠读文件顶部的几条 `let` 才能确认。
 *
 * 不收实例（`private init`）：这里没有状态可言，只有"一个落点、一个级别、一个 logger"。
 */
public class DownloadLogger {

    /** 日志的落点。默认空流（丢弃）。 */
    private static var currentSink: OutputStream = NullOutputStream()

    /** 当前级别。默认 OFF。 */
    private static var currentLevel: LogLevel = LogLevel.OFF

    /** 接在当前落点上的 logger；随落点或级别变化而重建。 */
    private static var current: Logger = makeLogger()

    private init() {}

    /** 本库唯一的日志出口；写日志一律用它，不要再碰 `getGlobalLogger()`。 */
    public static prop logger: Logger {
        get() {
            current
        }
    }

    /**
     * 日志写到哪。给一个 `OutputStream` 即可。
     *
     * **所有权归调用方**：库不关它、也不替它缓冲。再赋一次值就换落点，logger 跟着重建。
     *
     * 写文件 —— 追加，不覆盖历史：
     *
     * ```cangjie
     * import std.fs.{File, OpenMode, Path, exists, Directory}
     *
     * let directory = Path("logs")
     * let path = directory.join("download.log")
     * if (!exists(directory)) {
     *     Directory.create(directory, recursive: true)   // 目录要先建，File 不会替你建
     * }
     * let file = File(path, OpenMode.Append)             // Write 会清掉旧内容，排查场景一般用 Append
     * DownloadLogger.sink = file
     * DownloadLogger.level = LogLevel.INFO
     * ```
     *
     * 写控制台：
     *
     * ```cangjie
     * import std.env.{getStdErr, getStdOut}
     *
     * DownloadLogger.sink = getStdErr()   // 诊断信息，别混进程序自己的标准输出
     * DownloadLogger.sink = getStdOut()   // 确实要跟正常输出排在一起时才用这个
     * DownloadLogger.level = LogLevel.INFO
     * ```
     *
     * 两件事都要给：落点决定"往哪去"，级别决定"啰不啰嗦"。只给级别而落点还是默认的空流，就什么都
     * 不会出现 —— 这是刻意的，见类型开头的说明。
     */
    public static mut prop sink: OutputStream {
        get() {
            currentSink
        }
        set(value) {
            currentSink = value
            current = makeLogger()
        }
    }

    /**
     * 日志级别：读就是当前级别，写就是开关。默认已关。
     *
     * 落点没换过时，只打开级别也什么都不写（默认落点是空流）—— 两件事都要给是刻意的：
     * 「级别」管啰不啰嗦，「落点」管往哪里去。混成一个开关，会让"我就想看看"变成往用户的日志文件里灌。
     */
    public static mut prop level: LogLevel {
        get() {
            currentLevel
        }
        set(value) {
            currentLevel = value
            current = makeLogger()
        }
    }

    /** 按当前落点与级别建一个 logger。 */
    private static func makeLogger(): Logger {
        let logger = SimpleLogger(currentSink)
        logger.level = currentLevel
        logger
    }

    /**
     * 日志是否开着。
     *
     * 写日志前先问一句，省掉组装消息的开销 —— `logRequest` 会拼一整行请求头，关着的时候连字符串
     * 都不该组装。
     */
    static func enabled(): Bool {
        currentLevel != LogLevel.OFF
    }
}
