# selineDownload API 参考文档

> **版本**: 1.0.2
> **语言**: 仓颉 (Cangjie) 1.1.0
> **作者**: linderSeline
> **仓库**: https://gitcode.com/LiquidStudio/selineDownload
> **许可证**: 木兰宽松许可证, 第2版 (Mulan PSL v2)

---

## 概述

selineDownload 是一个基于仓颉语言开发的高性能文件下载库，底层依赖 [linderHttp](https://gitcode.com/LiquidStudio/LinderHttp) 进行 HTTP 通信。支持断点续传和多线程并发下载。

### 核心能力

| 特性 | 说明 |
|------|------|
| **断点续传** | 自动检测服务器支持情况，从上次中断位置继续下载，下载记录自动保存为 JSON |
| **多线程下载** | 根据文件大小自动计算最优线程数，也可手动指定 |
| **HEAD 请求检测** | 自动检测服务器是否支持 `Range` 请求和 `Accept-Ranges: bytes` |
| **进度回调** | 实时获取下载进度、速度、已下载字节数等信息 |
| **错误重试** | 内置指数退避重试机制 |
| **任务控制** | 支持暂停、恢复、取消下载任务 |
| **文件冲突处理** | 支持删除已存在文件 / 自动重命名 / 跳过三种策略 |
| **自定义请求头** | 支持添加自定义 HTTP 请求头 |
| **任务管理器** | 统一管理多个下载任务的创建、查询、删除和批量控制 |

---

## 包导入

```cangjie
import selineDownload.*
```

---

## 一、枚举类型

---

### 1.1 `FileExistsAction`

**文件路径**: `src/download_config.cj`

重复文件名处理策略枚举。

```cangjie
public enum FileExistsAction {
    | Delete // 删除已存在的文件（在合并分片时删除）
    | Rename // 在文件名后加 (N)，如 file(1).txt、file(2).txt
    | Skip   // 跳过下载，直接标记为完成
}
```

| 枚举值 | 说明 |
|--------|------|
| `Delete` | 目标文件已存在时，在合并分片前将其删除，实现覆盖写入 |
| `Rename` | 目标文件已存在时，自动生成新路径 `file(1).txt` → `file(2).txt`... |
| `Skip` | 目标文件已存在时，直接标记为 `Completed`，跳过下载 |

---

### 1.2 `DownloadStatus`

**文件路径**: `src/download_status.cj`

下载任务的完整状态枚举。

```cangjie
public enum DownloadStatus {
    | Pending     // 等待中
    | Checking    // 检测中（检测服务器是否支持断点续传）
    | Downloading // 下载中
    | Paused      // 已暂停
    | Completed   // 已完成
    | Failed      // 失败
    | Cancelled   // 已取消
}
```

| 枚举值 | 说明 |
|--------|------|
| `Pending` | 任务已创建但尚未开始 |
| `Checking` | 正在发送 HEAD 请求检测服务器支持情况 |
| `Downloading` | 正在下载中（单线程或多线程） |
| `Paused` | 已暂停，分片文件保留在 `.tmp` 目录中 |
| `Completed` | 下载完成且分片已合并 |
| `Failed` | 重试次数耗尽后仍然失败 |
| `Cancelled` | 调用 `cancel()` 后取消 |

**状态流转图**:

```
Pending → Checking → Downloading → Completed
                         ↕
                       Paused
                         ↓
                      Cancelled
                      Failed
```

---

## 二、数据类

---

### 2.1 `DownloadProgress`

**文件路径**: `src/download_progress.cj`

下载进度信息类，通过 `DownloadTask.setProgressCallback()` 的回调参数获取。

```cangjie
public class DownloadProgress {
    public var downloadedBytes: Int64  // 已下载字节数
    public var totalBytes: Int64       // 总字节数
    public var speed: Int64            // 下载速度（字节/秒）
    public prop progress: Float64      // 下载百分比（0.00 - 100.00，保留两位小数）
    public prop formattedSpeed: String // 格式化的速度字符串，如 "1.50 MB/s"
}
```

#### 属性说明

| 属性 | 类型 | 说明 |
|------|------|------|
| `downloadedBytes` | `Int64` | 已下载的累计字节数 |
| `totalBytes` | `Int64` | 通过 HEAD 请求获取的文件总大小 |
| `speed` | `Int64` | 瞬时下载速度（字节/秒），使用 EMA 指数移动平均平滑 |
| `progress` | `Float64`（属性） | 只读，自动计算 `downloadedBytes / totalBytes * 100` |
| `formattedSpeed` | `String`（属性） | 只读，自动格式化速度，规则：<br>`< 1024` → `"X B/s"`<br>`< 1024*1024` → `"X.XX KB/s"`<br>`≥ 1024*1024` → `"X.XX MB/s"` |

#### 构造函数

```cangjie
public init(downloadedBytes: Int64, totalBytes: Int64, speed: Int64)
```

---

## 三、配置类

---

### 3.1 `DownloadConfig`

**文件路径**: `src/download_config.cj`

下载配置类，所有 setter 方法均返回 `DownloadConfig` 自身，支持链式调用。

```cangjie
public class DownloadConfig {

    // —— 字段（公开可读写）——

    public var url: String                              // 下载 URL
    public var savePath: String                         // 文件保存路径
    public var threadCount: Int64                       // 线程数（0 = 自动计算）
    public var writeTimeout: Duration                   // 发送请求超时（默认 60s）
    public var readTimeout: Duration                    // 读取超时（默认 60s）
    public var supportRange: Bool                       // 服务器是否支持 Range
    public var enableRange: Bool                        // 是否启用断点续传（默认 true）
    public var totalSize: Int64                         // 文件总大小（由 HEAD 请求自动填充）
    public var bufferSize: Int64                        // 缓冲区大小（默认 8192 = 8KB）
    public var maxRetries: Int64                        // 最大重试次数（默认 5）
    public var headers: HashMap<String, String>         // 自定义请求头
    public var fileExistsAction: FileExistsAction       // 文件冲突策略（默认 Rename）
}
```

#### 构造方法

```cangjie
public init()
```

#### 链式 Setter 方法汇总

| 方法签名 | 说明 | 默认值 |
|---------|------|--------|
| `setUrl(url: String): DownloadConfig` | 设置下载 URL | `""` |
| `setSavePath(path: String): DownloadConfig` | 设置文件保存路径 | `""` |
| `setThreadCount(count: Int64): DownloadConfig` | 设置线程数（0=自动） | `0` |
| `setWriteTimeout(timeout: Duration): DownloadConfig` | 设置发送请求超时 | `60s` |
| `setReadTimeout(timeout: Duration): DownloadConfig` | 设置读取超时 | `60s` |
| `setBufferSize(size: Int64): DownloadConfig` | 设置缓冲区大小（字节） | `8192` |
| `setMaxRetries(retries: Int64): DownloadConfig` | 设置最大重试次数 | `5` |
| `addHeader(key: String, value: String): DownloadConfig` | 添加单个自定义请求头 | — |
| `setHeaders(headers: HashMap<String, String>): DownloadConfig` | 批量设置自定义请求头 | 空 Map |
| `setFileExistsAction(action: FileExistsAction): DownloadConfig` | 设置文件冲突处理策略 | `Rename` |
| `setEnableRange(enable: Bool): DownloadConfig` | 设置是否启用断点续传 | `true` |

#### 自动线程数计算规则

当 `threadCount == 0` 时，根据文件大小自动决定：

| 文件大小 | 线程数 |
|---------|--------|
| < 1 MB | 1 |
| 1 MB ~ 10 MB | 2 |
| 10 MB ~ 50 MB | 4 |
| 50 MB ~ 100 MB | 8 |
| ≥ 100 MB | 16 |

---

## 四、核心类

---

### 4.1 `DownloadTask`

**文件路径**: `src/download_task.cj`

下载任务类，封装了断点续传和多线程下载的核心逻辑。

```cangjie
public class DownloadTask
```

#### 构造方法

```cangjie
public init(config: DownloadConfig)
```

**参数**:

| 参数 | 类型 | 说明 |
|------|------|------|
| `config` | `DownloadConfig` | 下载配置对象 |

---

#### 任务控制方法

##### `start(): Unit`

开始下载。自动执行以下步骤：
1. 检查并处理已存在的文件（按 `fileExistsAction` 策略）
2. 发送 HEAD 请求检测服务器是否支持 Range
3. 获取 `Content-Length` 填充 `totalSize`
4. 自动计算线程数（若未手动指定）
5. 根据服务器能力决定单线程 / 多线程下载

**状态迁移**: `Pending` → `Checking` → `Downloading`

---

##### `pause(): Unit`

暂停下载。设置暂停标志，分片文件保留在 `.tmp` 临时目录中。

**状态迁移**: `Downloading` → `Paused`

---

##### `resume(): Unit`

恢复下载。重置暂停标志，重新调用 `start()` 方法，自动检测临时目录中的已下载分片并续传。

**前置条件**: 当前状态必须为 `Paused`

**状态迁移**: `Paused` → `Downloading`

---

##### `cancel(): Unit`

取消下载。设置取消标志，等待所有线程结束后清空 `futures` 列表。

**状态迁移**: `*` → `Cancelled`

---

##### `await(): Unit`

阻塞等待所有下载线程完成。遍历 `futures` 列表调用 `f.get()`，若线程抛出异常则触发错误回调。

---

#### 状态查询方法

##### `getStatus(): DownloadStatus`

获取当前任务状态。

**返回值**: `DownloadStatus` 枚举值

---

##### `getDownloadedBytes(): Int64`

获取当前已下载的字节数（原子操作）。

**返回值**: 已下载字节数

---

#### 回调设置方法

所有回调 setter 均返回 `DownloadTask` 本身，支持链式调用。

| 方法签名 | 回调参数 | 触发时机 |
|---------|---------|---------|
| `setProgressCallback(callback: (DownloadProgress) -> Unit): DownloadTask` | `DownloadProgress` | 每 100ms 触发一次，携带进度、速度信息 |
| `setErrorCallback(callback: (Exception) -> Unit): DownloadTask` | `Exception` | 下载过程中发生不可恢复的错误时 |
| `setStartCallback(callback: () -> Unit): DownloadTask` | 无 | `start()` 方法调用后立即触发 |
| `setPauseCallback(callback: () -> Unit): DownloadTask` | 无 | `pause()` 方法调用后触发 |
| `setResumeCallback(callback: () -> Unit): DownloadTask` | 无 | `resume()` 方法调用后触发 |
| `setCancelCallback(callback: () -> Unit): DownloadTask` | 无 | `cancel()` 方法调用后触发 |
| `setRetryCallback(callback: (Int64, Int64) -> Unit): DownloadTask` | `(当前重试次数, 最大重试次数)` | 每次重试前触发 |
| `setCompleteCallback(callback: () -> Unit): DownloadTask` | 无 | 下载完成且分片合并成功后触发 |

---

#### 内部机制说明

##### 速度计算（`calculateSpeed`）

- 采样间隔：500ms
- 使用**指数移动平均（EMA）**平滑瞬时速度：`当前速度 = 0.3 × 瞬时速度 + 0.7 × 上次速度`
- 首次采样直接使用瞬时速度

##### 进度回调频率

- 间隔控制：100ms（`progressCallbackInterval`）
- 超过间隔才会触发回调，避免高频通知

##### 重试策略（指数退避）

```cangjie
sleep(Duration.second * (1 << (retryCount - 1)))
// 第 1 次重试等待 1s
// 第 2 次重试等待 2s
// 第 3 次重试等待 4s
// 第 4 次重试等待 8s
// ...
```

##### 多线程下载流程

1. 在 `{savePath}.tmp/` 下创建临时目录
2. 保存 `download_info.json`（记录 url、totalSize、threadCount、partSizes）
3. 将文件按线程数均分为多个 `Range`（最后一片包含剩余字节）
4. 每个线程写入 `partN` 临时文件，完成后重命名为 `partN.comp`
5. 所有 `.comp` 文件就绪后，按顺序合并到目标文件
6. 合并完成后删除 `.tmp` 临时目录

##### 断点续传检测流程

1. HEAD 请求 → 检查 `Accept-Ranges: bytes`
2. 若 HEAD 未返回 `Accept-Ranges`，发送 `Range: bytes=0-0` 进行实测
3. 检查响应是否包含 `Content-Range` 头
4. 同时通过 HEAD 获取 `Content-Length` 填充 `totalSize`

##### 续传恢复流程

1. 检查 `.tmp/download_info.json` 是否存在
2. 对比 JSON 中的 url、totalSize、threadCount、partSizes 是否全部匹配
3. 不匹配则重命名旧 `.tmp` 目录（加时间戳），创建新目录
4. 匹配则检测已有的 `.comp` 文件，已完成的跳过
5. 未完成的 `.partN` 文件从实际已写入字节数处继续下载

##### 单线程下载

- 不依赖 Range 支持，适用于不支持断点续传的服务器
- 下载到 `{savePath}.temp` 文件，完成后重命名为目标文件
- 每次重试时清空重写 `.temp` 文件（不会续传）

---

### 4.2 `DownloadManager`

**文件路径**: `src/download_manager.cj`

下载管理器，统一管理多个下载任务。内部使用 `Mutex` 保证线程安全。

```cangjie
public class DownloadManager
```

#### 构造方法

```cangjie
public init()
```

#### 方法汇总

##### `createTask(taskId: String, config: DownloadConfig): DownloadTask`

创建并注册一个新的下载任务。

| 参数 | 类型 | 说明 |
|------|------|------|
| `taskId` | `String` | 任务唯一标识 |
| `config` | `DownloadConfig` | 下载配置 |

**返回值**: 新创建的 `DownloadTask` 对象

---

##### `getTask(taskId: String): ?DownloadTask`

根据任务 ID 获取下载任务。

| 参数 | 类型 | 说明 |
|------|------|------|
| `taskId` | `String` | 任务 ID |

**返回值**: `Some(DownloadTask)` 或 `None`

---

##### `removeTask(taskId: String): Bool`

删除指定下载任务。

| 参数 | 类型 | 说明 |
|------|------|------|
| `taskId` | `String` | 任务 ID |

**返回值**: `true`（删除成功）/ `false`（任务不存在）

---

##### `getAllTaskIds(): Array<String>`

获取所有已注册任务 ID 的数组。

**返回值**: 任务 ID 数组

---

##### `cancelAll(): Unit`

取消所有任务。遍历每个任务调用 `cancel()`，然后清空任务列表。

---

##### `pauseAll(): Unit`

暂停所有正在下载的任务。遍历每个任务调用 `pause()`。

---

##### `resumeAll(): Unit`

恢复所有已暂停的任务。遍历每个任务调用 `resume()`。

---

## 五、典型使用示例

---

### 5.1 基本下载

```cangjie
let config = DownloadConfig()
    .setUrl("https://example.com/file.zip")
    .setSavePath("./download/file.zip")

let task = DownloadTask(config)

task.setProgressCallback({ progress =>
    println("进度: ${progress.progress}% | 速度: ${progress.formattedSpeed}")
})

task.setErrorCallback({ e =>
    println("下载失败: ${e.message}")
})

task.start()
task.await()
```

---

### 5.2 带完整生命周期的下载

```cangjie
let task = DownloadTask(config)
    .setStartCallback({ => println("开始下载...") })
    .setProgressCallback({ p => println("${p.progress}% - ${p.formattedSpeed}") })
    .setRetryCallback({ (current, max) => println("重试 ${current}/${max}") })
    .setCompleteCallback({ => println("下载完成!") })
    .setErrorCallback({ e => println("错误: ${e.message}") })
    .setPauseCallback({ => println("已暂停") })
    .setResumeCallback({ => println("已恢复") })
    .setCancelCallback({ => println("已取消") })

task.start()
task.await()
```

---

### 5.3 使用下载管理器管理多任务

```cangjie
let manager = DownloadManager()
let t1 = manager.createTask("video", DownloadConfig()
    .setUrl("https://example.com/video.mp4")
    .setSavePath("./download/video.mp4"))
let t2 = manager.createTask("doc", DownloadConfig()
    .setUrl("https://example.com/doc.pdf")
    .setSavePath("./download/doc.pdf")
    .setFileExistsAction(FileExistsAction.Skip))

t1.start()
t2.start()

t1.await()
t2.await()
```

---

### 5.4 禁用断点续传

```cangjie
let config = DownloadConfig()
    .setUrl("https://example.com/file.zip")
    .setSavePath("./download/file.zip")
    .setEnableRange(false)  // 即使服务器支持，也使用单线程下载
```

---

## 六、依赖关系

| 依赖 | 版本 |
|------|------|
| 仓颉编译器 | 1.1.0 |
| linderHttp | 1.0.0 |
| stdx | 1.1.0 |

---

## 七、项目文件清单

| 文件 | 说明 |
|------|------|
| `src/download_config.cj` | 下载配置类 + 文件冲突枚举 |
| `src/download_task.cj` | 下载任务核心逻辑（~1415 行） |
| `src/download_manager.cj` | 多任务管理器 |
| `src/download_progress.cj` | 进度信息类 |
| `src/download_status.cj` | 状态枚举 |
| `cjpm.toml` | 项目配置与依赖声明 |

---

*文档生成日期: 2026-05-08*
*基于 selineDownload v1.0.2 源码自动生成*
