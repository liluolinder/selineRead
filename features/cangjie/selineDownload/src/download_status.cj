package selineDownload

/**
 * 下载状态枚举
 */
public enum DownloadStatus {
    | Pending // 等待中
    | Checking // 检测中
    | Downloading // 下载中
    /**
     * 分片已下完，正在合并成一个文件。
     *
     * 多线程下载的最后一段不是网络，而是把 `partN.comp` 依次写进目标文件：几十 MB 也要读写一遍，
     * 期间"进度 100%"早已到顶，界面上却什么也看不到。这个状态就是那一段 —— 调用方应当把它当成
     * **还没结束**：`getStatus()` 是 Merging 时文件还在写，不许读、不许判完成。
     */
    | Merging // 合并分片中
    | Paused // 已暂停
    | Completed // 已完成
    | Failed // 失败
    | Cancelled // 已取消
}
