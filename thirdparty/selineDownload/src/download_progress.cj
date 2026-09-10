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
     * 格式化的速度字符串(如 "1.22 MB/s"，固定两位小数)
     */
    public prop formattedSpeed: String {
        get() {
            let kb: Int64 = 1024
            let mb: Int64 = 1024 * 1024

            if (speed < kb) {
                "${speed} B/s"
            } else if (speed < mb) {
                formatSpeed(speed, kb, "KB/s")
            } else {
                formatSpeed(speed, mb, "MB/s")
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

/**
 * 速度格式化：bytes/秒 → "X.XX <单位>"。
 * 用整数运算四舍五入到百分位，避免 Float64 插值打印出 1.220000 这类冗余小数。
 */
func formatSpeed(speed: Int64, unit: Int64, suffix: String): String {
    let hundredths = (speed * 100 + unit / 2) / unit
    let whole = hundredths / 100
    let frac = hundredths % 100
    let fracText = if (frac < 10) {
        "0${frac}"
    } else {
        "${frac}"
    }
    "${whole}.${fracText} ${suffix}"
}
