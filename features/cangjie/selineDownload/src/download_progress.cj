package selineDownload

/**
 * 下载进度信息类
 */
public class DownloadProgress {
    /**
     * 已下载字节数
     */
    public var downloadedBytes: Int64 = 0

    /**
     * 总字节数
     */
    public var totalBytes: Int64 = 0

    /**
     * 下载速度(字节/秒)
     */
    public var speed: Int64 = 0

    /**
     * 下载百分比(保留两位小数)
     */
    public prop progress: Float64 {
        get() {
            if (totalBytes == 0) {
                0.0
            } else {
                let rawProgress = (Float64(downloadedBytes) / Float64(totalBytes)) * 100.0
                // 保留两位小数
                let scaled = rawProgress * 100.0
                let rounded = Int64(scaled)
                Float64(rounded) / 100.0
            }
        }
    }

    /**
     * 格式化的速度字符串(如 "1.5 MB/s")
     */
    public prop formattedSpeed: String {
        get() {
            let kb: Int64 = 1024
            let mb: Int64 = 1024 * 1024

            if (speed < kb) {
                "${speed} B/s"
            } else if (speed < mb) {
                let kbSpeed = Float64(speed) / Float64(kb)
                let rounded = Int64(kbSpeed * 100.0)
                "${Float64(rounded) / 100.0} KB/s"
            } else {
                let mbSpeed = Float64(speed) / Float64(mb)
                let rounded = Int64(mbSpeed * 100.0)
                "${Float64(rounded) / 100.0} MB/s"
            }
        }
    }

    public init() {}

    public init(downloadedBytes!: Int64, totalBytes!: Int64, speed!: Int64) {
        this.downloadedBytes = downloadedBytes
        this.totalBytes = totalBytes
        this.speed = speed
    }
}
