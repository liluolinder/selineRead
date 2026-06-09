package selineDownload

/**
 * 下载状态枚举
 */
public enum DownloadStatus {
    | Pending // 等待中
    | Checking // 检测中
    | Downloading // 下载中
    | Paused // 已暂停
    | Completed // 已完成
    | Failed // 失败
    | Cancelled // 已取消
}
