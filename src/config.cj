/*
 * JSON 配置（`config.json` / `accounts.json`）。
 *
 * 序列化统一交给 CJson 的 `@JsonSerializable`：加字段只改类，不用手写
 * `JsonObject` 拼装/逐字段读取；读写共用同一份结构，坏文件或缺失字段按默认值回退。
 *
 * 不做旧格式兼容：字段就是下面定义的这些，多余字段忽略、缺失字段用默认值。
 */
package seline_read

import std.collection.{ArrayList, HashMap}
import std.fs.{Directory, File, Path, exists}
// `stdx.encoding.json` 不是给手写解析用的：CJson 宏生成的 `fromJsonValue` / `toJsonValue`
// 直接用 `JsonValue` / `JsonObject` / `JsonString` 等类型，宏展开后需要它们在作用域里。
import stdx.encoding.json.*
import CJson.*
import CJson.jsonmacro.*

// ---------------------------------------------------------------------------
// 配置按设置页的分类分组，JSON 也一样分层（不是把所有字段平铺在一层）。
// 加字段时先想清楚它属于哪一类，再加到对应的子结构里。
// ---------------------------------------------------------------------------

/** 显示设置（`config.json` → `display`）。 */
@JsonSerializable
public class DisplaySettings {
    /** `dark` / `light`。 */
    public var theme: String = "dark"
}

/** 下载设置（`config.json` → `download`）。 */
@JsonSerializable
public class DownloadSettings {
    /** 下载目录绝对路径；空串表示用默认目录。 */
    public var dir: String = ""
}

/** 网络设置（`config.json` → `network`）。 */
@JsonSerializable
public class NetworkSettings {
    /** 当前选中的站点（官方地址或自定义站点）。 */
    public var activeSite: String = ""
    /** 自定义站点（数组，可增删）。 */
    public var customSites: ArrayList<String> = ArrayList<String>()
    /** 种子站（单值，仅对自定义站点生效）。 */
    public var seedSite: String = ""
}

/**
 * 应用配置（`~/.seline-app/SelineRead/config.json`）。
 *
 * ```json
 * {
 *   "display":  { "theme": "dark" },
 *   "download": { "dir": "C:\\Users\\me\\Downloads\\SelineRead" },
 *   "network":  { "activeSite": "https://zh.z-library.sk",
 *                 "customSites": ["https://example.com"],
 *                 "seedSite": "https://zh.eva101.ru" }
 * }
 * ```
 */
@JsonSerializable
public class AppConfig {
    public var display: DisplaySettings = DisplaySettings()
    public var download: DownloadSettings = DownloadSettings()
    public var network: NetworkSettings = NetworkSettings()
}

/** 已保存账号（`accounts.json` 的列表项）。 */
@JsonSerializable
public class AccountConfig {
    public var email: String = ""
    public var name: String = ""
    public var userId: String = ""
    public var userKey: String = ""
    public var language: String = ""
    /** 是否默认账号（JSON 字段名沿用 `default`）。 */
    @JsonName["default"]
    public var isDefault: Bool = false
}

/** 账号文件（`~/.seline-app/SelineRead/accounts.json`）。 */
@JsonSerializable
public class AccountsConfig {
    public var accounts: ArrayList<AccountConfig> = ArrayList<AccountConfig>()
}

/** 读文本文件（不存在/读失败返回空串）。 */
private func readTextFile(path: Path): String {
    if (!exists(path)) {
        return ""
    }
    try {
        String.fromUtf8(File.readFrom(path))
    } catch (_: Exception) {
        ""
    }
}

/** 写文本文件（自动建父目录）。 */
private func writeTextFile(path: Path, text: String): Unit {
    try {
        if (!exists(path.parent)) {
            Directory.create(path.parent, recursive: true)
        }
        File.writeTo(path, text.toArray())
    } catch (failure: Exception) {
        writeDebugLog("write ${path} failed: ${failure.message}")
    }
}

/** 缩进字符串（level 层，每层 2 个空格）。 */
private func indentText(level: Int64): String {
    let builder = StringBuilder()
    var index: Int64 = 0
    while (index < level) {
        builder.append("  ")
        index += 1
    }
    builder.toString()
}

/**
 * 把 JSON DOM 格式化成多行文本。
 *
 * 配置文件是给人看的（改了哪个字段要能一眼看到），`toJson()` 默认输出是一整行，
 * 所以落盘前统一过一遍这里；数组/对象递归缩进，标量交给 `toString()` 自己转义。
 */
private func prettyJson(value: JsonValue, level: Int64): String {
    match (value.kind()) {
        case JsObject =>
            let fields = value.asObject().getFields()
            if (fields.isEmpty()) {
                return "{}"
            }
            let builder = StringBuilder()
            builder.append("{\n")
            var index: Int64 = 0
            for ((key, item) in fields) {
                builder.append(indentText(level + 1))
                builder.append("\"")
                builder.append(key)
                builder.append("\": ")
                builder.append(prettyJson(item, level + 1))
                index += 1
                if (index < fields.size) {
                    builder.append(",")
                }
                builder.append("\n")
            }
            builder.append(indentText(level))
            builder.append("}")
            builder.toString()
        case JsArray =>
            let items = value.asArray().getItems()
            if (items.isEmpty()) {
                return "[]"
            }
            let builder = StringBuilder()
            builder.append("[\n")
            var index: Int64 = 0
            for (item in items) {
                builder.append(indentText(level + 1))
                builder.append(prettyJson(item, level + 1))
                index += 1
                if (index < items.size) {
                    builder.append(",")
                }
                builder.append("\n")
            }
            builder.append(indentText(level))
            builder.append("]")
            builder.toString()
        case _ => value.toString()
    }
}

/** 序列化成"给人看"的 JSON 文本（缩进多行）。 */
private func toPrettyJson(text: String): String {
    prettyJson(JsonValue.fromStr(text), 0) + "\n"
}
/** 读应用配置；文件缺失或损坏给默认值。 */
func readAppConfig(path: String): AppConfig {
    let text = readTextFile(Path(path)).trimAscii()
    if (text.isEmpty() || !text.startsWith("{")) {
        return AppConfig()
    }
    try {
        AppConfig.fromJson(text)
    } catch (_: Exception) {
        writeDebugLog("config.json unreadable; using defaults")
        AppConfig()
    }
}

/** 写应用配置。 */
func writeAppConfig(path: String, config: AppConfig): Unit {
    try {
        writeTextFile(Path(path), toPrettyJson(config.toJson()))
    } catch (failure: Exception) {
        writeDebugLog("config.json serialize failed: ${failure.message}")
    }
}

/** 读账号文件；文件缺失或损坏给空表。 */
func readAccountsConfig(path: String): AccountsConfig {
    let text = readTextFile(Path(path)).trimAscii()
    if (text.isEmpty() || !text.startsWith("{")) {
        return AccountsConfig()
    }
    try {
        AccountsConfig.fromJson(text)
    } catch (_: Exception) {
        writeDebugLog("accounts.json unreadable; ignored")
        AccountsConfig()
    }
}

/** 写账号文件。 */
func writeAccountsConfig(path: String, config: AccountsConfig): Unit {
    try {
        writeTextFile(Path(path), toPrettyJson(config.toJson()))
    } catch (failure: Exception) {
        writeDebugLog("accounts.json serialize failed: ${failure.message}")
    }
}
