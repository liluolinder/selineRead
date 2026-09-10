# 🚀 selineDownload - 仓颉文件下载库

基于 [linderHttp](https://gitcode.com/LiquidStudio/LinderHttp) 和仓颉 1.1.0 开发的高性能文件下载库，支持断点续传和多线程下载。

## ✨ 特性

- 🔄 **断点续传** - 支持从上次中断的位置继续下载，下载记录自动保存
- ⚡ **多线程下载** - 支持多线程并发下载，自动根据文件大小计算最优线程数
- 🔍 **HEAD请求检测** - 自动检测服务器是否支持断点续传
- 📊 **进度回调** - 实时获取下载进度、速度、已下载字节数等信息
- 🔁 **错误重试** - 完善的错误处理和自动重试机制
- ⏯️ **任务控制** - 支持暂停、恢复、取消下载任务
- 📁 **文件管理** - 支持重复文件名处理（删除/重命名/跳过）
- 🔧 **自定义请求头** - 支持添加自定义HTTP请求头
- 📦 **下载管理器** - 统一管理多个下载任务

## 🎯 快速开始

### 1. 基本下载

```cangjie
package example

import selineDownload.{DownloadConfig, DownloadTask}

main(): Int64 {
    // 创建下载配置
    let config = DownloadConfig()
        .setUrl("https://example.com/file.zip")
        .setSavePath("./download/file.zip")

    // 创建下载任务
    let task = DownloadTask(config)

    // 设置进度回调
    task.setProgressCallback({ progress =>
        println("📊 下载进度: ${progress.progress}%")
        println("📥 已下载: ${progress.downloadedBytes} / ${progress.totalBytes} 字节")
        println("⚡ 速度: ${progress.formattedSpeed}")  // 自动格式化速度，如 "1.5 MB/s"
    })

    // 设置错误回调
    task.setErrorCallback({ e =>
        println("❌ 下载失败: ${e.message}")
    })

    // 开始下载
    task.start()

    // 等待下载完成
    task.await()

    println("✅ 下载完成!")
    return 0
}
```

### 2. 多线程下载（自动计算线程数）

```cangjie
import selineDownload.{DownloadConfig, DownloadTask}
import std.time.Duration

main(): Int64 {
    let config = DownloadConfig()
        .setUrl("https://example.com/largefile.zip")
        .setSavePath("./download/largefile.zip")
        // 不设置线程数，系统会根据文件大小自动计算
        // < 10MB: 1线程, < 50MB: 4线程, < 100MB: 8线程, >= 100MB: 16线程
        .setBufferSize(16384)           // 16KB缓冲区
        .setMaxRetries(5)               // 最大重试5次
        .setReadTimeout(Duration.second * 120)  // 读取超时120秒

    let task = DownloadTask(config)
    
    task.setProgressCallback({ progress =>
        println("进度: ${progress.progress}% | 速度: ${progress.formattedSpeed}")
    })

    task.start()
    task.await()
    
    return 0
}
```

### 3. 手动指定线程数

```cangjie
let config = DownloadConfig()
    .setUrl("https://example.com/largefile.zip")
    .setSavePath("./download/largefile.zip")
    .setThreadCount(8)  // 手动指定8个线程
```

### 4. 重复文件名处理

```cangjie
import selineDownload.{DownloadConfig, DownloadTask, FileExistsAction}

main(): Int64 {
    // 策略1: 跳过已存在的文件
    let config1 = DownloadConfig()
        .setUrl("https://example.com/file.zip")
        .setSavePath("./download/file.zip")
        .setFileExistsAction(FileExistsAction.Skip)  // 文件存在则跳过

    // 策略2: 删除已存在的文件（在合并分片时删除）
    let config2 = DownloadConfig()
        .setUrl("https://example.com/file.zip")
        .setSavePath("./download/file.zip")
        .setFileExistsAction(FileExistsAction.Delete)  // 文件存在则覆盖

    // 策略3: 重命名文件（默认策略）
    // file.zip -> file(1).zip -> file(2).zip ...
    let config3 = DownloadConfig()
        .setUrl("https://example.com/file.zip")
        .setSavePath("./download/file.zip")
        .setFileExistsAction(FileExistsAction.Rename)  // 文件存在则重命名

    let task = DownloadTask(config1)
    task.start()
    task.await()
    
    return 0
}
```

### 5. 自定义请求头

```cangjie
import std.collection.HashMap

main(): Int64 {
    // 方式1: 链式添加请求头
    let config1 = DownloadConfig()
        .setUrl("https://example.com/file.zip")
        .setSavePath("./download/file.zip")
        .addHeader("User-Agent", "MyDownloader/1.0")
        .addHeader("Authorization", "Bearer token123")
        .addHeader("Referer", "https://example.com")

    // 方式2: 批量设置请求头
    let headers = HashMap<String, String>()
    headers.put("User-Agent", "MyDownloader/1.0")
    headers.put("Authorization", "Bearer token123")

    let config2 = DownloadConfig()
        .setUrl("https://example.com/file.zip")
        .setSavePath("./download/file.zip")
        .setHeaders(headers)

    let task = DownloadTask(config1)
    task.start()
    task.await()
    
    return 0
}
```

### 6. 暂停、恢复和取消下载

```cangjie
import selineDownload.{DownloadConfig, DownloadTask, DownloadStatus}

main(): Int64 {
    let config = DownloadConfig()
        .setUrl("https://example.com/largefile.zip")
        .setSavePath("./download/largefile.zip")

    let task = DownloadTask(config)
    task.start()

    // 模拟用户操作
    spawn {
        sleep(Duration.second * 5)
        println("⏸️ 暂停下载...")
        task.pause()  // 暂停下载，进度会自动保存

        sleep(Duration.second * 3)
        println("▶️ 恢复下载...")
        task.resume()  // 从断点继续下载
    }

    task.await()
    println("✅ 下载完成!")
    return 0
}
```

### 7. 使用下载管理器

```cangjie
import selineDownload.{DownloadManager, DownloadConfig, DownloadStatus, FileExistsAction}

main(): Int64 {
    let manager = DownloadManager()

    // 创建多个下载任务
    let task1 = manager.createTask("video", DownloadConfig()
        .setUrl("https://example.com/video.mp4")
        .setSavePath("./download/video.mp4")
        .setFileExistsAction(FileExistsAction.Rename))

    let task2 = manager.createTask("music", DownloadConfig()
        .setUrl("https://example.com/music.mp3")
        .setSavePath("./download/music.mp3")
        .setThreadCount(4))

    let task3 = manager.createTask("doc", DownloadConfig()
        .setUrl("https://example.com/document.pdf")
        .setSavePath("./download/document.pdf")
        .setFileExistsAction(FileExistsAction.Skip))

    // 设置进度回调
    task1.setProgressCallback({ progress =>
        println("📹 视频: ${progress.progress}% - ${progress.formattedSpeed}")
    })
    task2.setProgressCallback({ progress =>
        println("🎵 音乐: ${progress.progress}% - ${progress.formattedSpeed}")
    })
    task3.setProgressCallback({ progress =>
        println("📄 文档: ${progress.progress}% - ${progress.formattedSpeed}")
    })

    // 启动所有任务
    task1.start()
    task2.start()
    task3.start()

    // 等待所有任务完成
    task1.await()
    task2.await()
    task3.await()

    println("✅ 所有下载任务完成!")
    return 0
}
```

### 8. 完整示例（带日志）

```cangjie
package example

import selineDownload.{DownloadConfig, DownloadTask, DownloadStatus, FileExistsAction}
import stdx.log.*
import stdx.logger.*
import std.io.BufferedOutputStream
import std.fs.{File, Path, Directory, exists}
import std.time.DateTime

main(): Int64 {
    // 创建日志目录
    let logDir = Path("./log")
    if (!exists(logDir)) {
        Directory.create(logDir, recursive: true)
    }

    // 创建日志文件
    let timestamp = DateTime.now().toUnixTimeStamp().toSeconds()
    let logFileName = "./log/download_${timestamp}.log"
    let logFile = File(logFileName, OpenMode.Write)
    let fileOutput = BufferedOutputStream(logFile)
    let fileLogger = SimpleLogger(fileOutput)
    fileLogger.level = LogLevel.DEBUG
    setGlobalLogger(fileLogger)
    println("📝 日志文件: ${logFileName}")

    // 创建下载配置
    let config = DownloadConfig()
        .setUrl("https://example.com/largefile.zip")
        .setSavePath("./download/largefile.zip")
        .setFileExistsAction(FileExistsAction.Rename)
        .setMaxRetries(5)

    let task = DownloadTask(config)

    // 设置进度回调
    task.setProgressCallback({ progress =>
        let bar = generateProgressBar(progress.progress)
        println("\r${bar} ${progress.progress}% | ${progress.formattedSpeed}     ", end: "")
        fileLogger.info("下载进度", ("downloaded", progress.downloadedBytes), 
                        ("total", progress.totalBytes), ("speed", progress.formattedSpeed))
    })

    // 设置错误回调
    task.setErrorCallback({ e =>
        println("\n❌ 下载失败: ${e.message}")
        fileLogger.error("下载错误", ("message", e.message))
    })

    println("🚀 开始下载...")
    task.start()
    task.await()

    // 关闭日志
    fileOutput.flush()
    logFile.close()

    println("\n✅ 下载完成! 日志已保存到: ${logFileName}")
    return 0
}

// 生成进度条
func generateProgressBar(progress: Float64): String {
    let width = 30
    let filled = Int64(progress * width / 100.0)
    var bar = "["
    for (i in 0..width) {
        if (i < filled) {
            bar = bar + "="
        } else if (i == filled) {
            bar = bar + ">"
        } else {
            bar = bar + " "
        }
    }
    bar = bar + "]"
    return bar
}
```

## 📖 API 文档

### DownloadConfig

下载配置类，用于配置下载任务的各种参数。支持链式调用。

| 方法 | 参数 | 说明 | 默认值 |
|------|------|------|--------|
| `setUrl(url: String)` | 下载URL | 设置下载地址 | `""` |
| `setSavePath(path: String)` | 保存路径 | 设置文件保存路径 | `""` |
| `setThreadCount(count: Int64)` | 线程数 | 设置下载线程数，0表示自动计算 | `0` |
| `setConnectTimeout(timeout: Duration)` | 超时时间 | 设置连接超时时间 | `30秒` |
| `setReadTimeout(timeout: Duration)` | 超时时间 | 设置读取超时时间 | `60秒` |
| `setBufferSize(size: Int64)` | 缓冲区大小 | 设置缓冲区大小(字节) | `8192` (8KB) |
| `setMaxRetries(retries: Int64)` | 重试次数 | 设置最大重试次数 | `5` |
| `addHeader(key: String, value: String)` | 请求头 | 添加自定义请求头 | - |
| `setHeaders(headers: HashMap<String, String>)` | 请求头Map | 批量设置请求头 | - |
| `setFileExistsAction(action: FileExistsAction)` | 处理策略 | 设置重复文件名处理策略 | `Rename` |

### FileExistsAction

重复文件名处理策略枚举。

| 值 | 说明 |
|----|------|
| `Delete` | 删除已存在的文件（在合并分片时删除） |
| `Rename` | 在文件名后加(N)，如 `file(1).txt`、`file(2).txt` |
| `Skip` | 跳过下载，直接标记为完成 |

### DownloadTask

下载任务类，支持断点续传和多线程下载。

| 方法 | 说明 |
|------|------|
| `start(): Unit` | 开始下载 |
| `pause(): Unit` | 暂停下载，保存当前进度 |
| `resume(): Unit` | 恢复下载，从断点继续 |
| `cancel(): Unit` | 取消下载 |
| `await(): Unit` | 等待下载完成 |
| `getStatus(): DownloadStatus` | 获取当前状态 |
| `getDownloadedBytes(): Int64` | 获取已下载字节数 |
| `setProgressCallback(callback)` | 设置进度回调 |
| `setErrorCallback(callback)` | 设置错误回调 |

### DownloadStatus

下载状态枚举。

| 值 | 说明 |
|----|------|
| `Pending` | ⏳ 等待中 |
| `Checking` | 🔍 检测中（检测服务器支持） |
| `Downloading` | 📥 下载中 |
| `Paused` | ⏸️ 已暂停 |
| `Completed` | ✅ 已完成 |
| `Failed` | ❌ 失败 |
| `Cancelled` | 🚫 已取消 |

### DownloadProgress

下载进度信息类。

| 属性 | 类型 | 说明 |
|------|------|------|
| `downloadedBytes` | `Int64` | 已下载字节数 |
| `totalBytes` | `Int64` | 总字节数 |
| `speed` | `Int64` | 下载速度(字节/秒) |
| `progress` | `Float64` | 下载百分比 (0-100) |
| `formattedSpeed` | `String` | 格式化的速度字符串，如 "1.5 MB/s" |

### DownloadManager

下载管理器，管理多个下载任务。

| 方法 | 说明 |
|------|------|
| `createTask(taskId: String, config: DownloadConfig)` | 创建下载任务 |
| `getTask(taskId: String)` | 获取下载任务 |
| `removeTask(taskId: String)` | 删除下载任务 |
| `getAllTaskIds()` | 获取所有任务ID |
| `cancelAll()` | 取消所有任务 |
| `pauseAll()` | 暂停所有任务 |
| `resumeAll()` | 恢复所有任务 |

## ⚙️ 工作原理

### 断点续传检测

1. 使用 HEAD 请求检测服务器是否支持断点续传
2. 检查响应头中的 `Accept-Ranges` 字段是否为 `bytes`
3. 从 `Content-Length` 头获取文件总大小

### 多线程下载

1. 根据线程数将文件分成多个块
2. 每个线程负责下载一个块
3. 使用 `Range` 头指定每个线程的下载范围
4. 所有线程完成后合并文件

### 断点续传实现

1. 创建临时目录 `.tmp` 存放分片文件和下载信息
2. 下载信息以 JSON 格式保存 (`download_info.json`)
3. 每个分片下载完成后重命名为 `.comp` 标记完成
4. 暂停时保留已下载的分片
5. 恢复时检测未完成的分片，从断点继续下载

### 自动线程数计算

| 文件大小 | 线程数 |
|---------|--------|
| < 10 MB | 1 |
| < 50 MB | 4 |
| < 100 MB | 8 |
| >= 100 MB | 16 |

## ⚠️ 注意事项

1. **服务器支持** - 断点续传需要服务器支持 `Range` 请求
2. **文件权限** - 确保保存路径有写入权限
3. **线程数选择** - 建议线程数不超过 CPU 核心数的 2 倍，或使用自动计算
4. **缓冲区大小** - 根据网络情况调整缓冲区大小，建议 8KB-64KB
5. **重试机制** - 网络不稳定时可增加重试次数
6. **临时文件** - 下载过程中会创建 `.tmp` 临时目录，请勿手动删除

## 📦 依赖

- 仓颉 1.1.0
- [linderHttp](https://gitcode.com/LiquidStudio/LinderHttp)
- stdx 1.1.0

## 📄 许可证

本项目采用 [木兰宽松许可证，第2版（Mulan PSL v2）](./LICENSE) 进行授权。

```
Copyright (c) 2024 linderSeline

Licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan PSL v2.
```

---

Made with ❤️ by linderSeline
