/*
 * 下载管理器（基于 selineDownload 库）。
 *
 * zlib 的下载链接**不支持 Range / 多线程**，所以这里固定单线程、关闭断点续传：
 * 只需要「进度 + 停止」，不需要恢复。
 *
 * 线程模型与图片一致：下载线程只做阻塞 IO，进度/状态通过 `AppState.postToUi`
 * 投回 UI 线程再写 State，避免跨线程碰 UI。
 */
package seline_read

import std.collection.ArrayList
import selineDownload.*

/** 下载任务在界面上的状态文案。 */
let DL_PENDING: String = "等待中"
let DL_RUNNING: String = "下载中"
let DL_COMPLETED: String = "已完成"
let DL_STOPPED: String = "已停止"
let DL_FAILED: String = "失败"

/** 下载列表里的一项（可变对象：进度回调原地更新，避免每 100ms 重建整个列表）。 */
public class DownloadItem <: ToString {
    public let taskId: String
    public let title: String
    public var fileName: String
    public var totalBytes: Int64
    public var downloadedBytes: Int64
    public var speedText: String
    public var status: String
    public var error: String

    public init(taskId: String, title: String) {
        this.taskId = taskId
        this.title = title
        this.fileName = ""
        this.totalBytes = 0
        this.downloadedBytes = 0
        this.speedText = ""
        this.status = DL_PENDING
        this.error = ""
    }

    /** 是否还在进行中（决定要不要显示「停止」）。 */
    public func active(): Bool {
        status == DL_PENDING || status == DL_RUNNING
    }

    /** 0..100 的百分比。 */
    public func percent(): Float32 {
        if (totalBytes <= 0) {
            return 0.0
        }
        let value = Float32(downloadedBytes) / Float32(totalBytes) * 100.0
        if (value < 0.0) {
            0.0
        } else if (value > 100.0) {
            100.0
        } else {
            value
        }
    }

    /** 进度文案：`1.2 MB / 2.8 MB · 512 KB/s`。 */
    public func progressText(): String {
        if (totalBytes <= 0) {
            return formatBytes(downloadedBytes)
        }
        let base = "${formatBytes(downloadedBytes)} / ${formatBytes(totalBytes)}"
        if (!speedText.isEmpty() && active()) {
            "${base} · ${speedText}"
        } else {
            base
        }
    }

    public func toString(): String {
        "${title} [${status}] ${progressText()}"
    }
}

/** 字节数转人类可读文本（整数除法，避免浮点格式化依赖）。 */
public func formatBytes(bytes: Int64): String {
    if (bytes < 1024) {
        return "${bytes} B"
    }
    if (bytes < 1024 * 1024) {
        return "${bytes / 1024} KB"
    }
    if (bytes < 1024 * 1024 * 1024) {
        let hundredths = bytes * 100 / (1024 * 1024)
        return "${hundredths / 100}.${hundredths % 100} MB"
    }
    let hundredths = bytes * 100 / (1024 * 1024 * 1024)
    "${hundredths / 100}.${hundredths % 100} GB"
}
