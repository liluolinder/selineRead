package SelineRead

import stdx.encoding.json.*
import std.env.*
import std.fs.{Directory, File, Path, exists}
import zlibraryAPI4CJ.common.changeUrl
import zlibraryAPI4CJ.common.zlibBaseUrl

/**
 * 应用设置持久化：保存到 %APPDATA%\SelineRead\settings.json
 * 字段：
 *   - zlibUrl: Z-Library 域名地址
 *   - themeMode: 0=跟随系统, 1=深色, 2=浅色
 *   - downloadPath: 书籍下载目录
 */

/** 设置目录（APPDATA\SelineRead） */
func settingsDir(): String {
    let appData = match (getVariable("APPDATA")) {
        case Some(p) => p.trimAscii()
        case None => match (getVariable("TEMP")) {
            case Some(t) => t.trimAscii()
            case None => "."
        }
    }
    "${appData}\\SelineRead"
}

/** 设置文件路径 */
func settingsPath(): String {
    "${settingsDir()}\\settings.json"
}

/** 默认下载目录 */
func defaultDownloadPath(): String {
    match (getVariable("USERPROFILE")) {
        case Some(p) => "${p.trimAscii()}\\Downloads\\SelineRead"
        case None => "${settingsDir()}\\downloads"
    }
}

/** 确保设置目录存在 */
func ensureSettingsDir(): Unit {
    try {
        let dir = Path(settingsDir())
        if (!exists(dir)) {
            Directory.create(dir)
        }
    } catch (_: Exception) {
        ()
    }
}

/** 读取文件全部内容为字符串 */
func readFileContent(path: String): String {
    let bytes = File.readFrom(Path(path))
    String.fromUtf8(bytes)
}

/** 加载设置，返回 (zlibrary域名, 主题模式, 下载路径) */
func loadSettings(): (String, Int64, String) {
    let path = settingsPath()
    try {
        let content = readFileContent(path)
        let json = JsonValue.fromStr(content).asObject()
        let url = match (json.get("zlibUrl")) {
            case Some(v) => v.asString().getValue()
            case None => zlibBaseUrl
        }
        let theme = match (json.get("themeMode")) {
            case Some(v) => v.asInt().getValue()
            case None => Int64(0)
        }
        let dlPath = match (json.get("downloadPath")) {
            case Some(v) => v.asString().getValue()
            case None => defaultDownloadPath()
        }
        (url, theme, dlPath)
    } catch (_: Exception) {
        (zlibBaseUrl, Int64(0), defaultDownloadPath())
    }
}

/** 保存设置 */
func saveSettings(zlibUrl: String, themeMode: Int64, downloadPath: String): Unit {
    ensureSettingsDir()
    let json = JsonObject()
    json.put("zlibUrl", JsonString(zlibUrl))
    json.put("themeMode", JsonInt(themeMode))
    json.put("downloadPath", JsonString(downloadPath))
    try {
        let content = json.toJsonString()
        let file = File(settingsPath(), Write)
        file.write(content.toArray())
        file.flush()
        file.close()
    } catch (_: Exception) {
        ()
    }
}

/** 应用 Z-Library 域名设置 */
func applyZlibUrl(url: String): Unit {
    if (!url.isEmpty() && url != zlibBaseUrl) {
        changeUrl(url)
    }
}

/** 全局当前下载路径：设置里保存后即时生效（downloadsDir() 优先读它）。 */
var gDownloadPath: String = ""

/** 应用下载路径设置（确保目录存在） */
func applyDownloadPath(path: String): Unit {
    gDownloadPath = path
    if (path.isEmpty()) {
        return
    }
    try {
        let dir = Path(path)
        if (!exists(dir)) {
            Directory.create(dir)
        }
    } catch (_: Exception) {
        ()
    }
}
