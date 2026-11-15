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

/** 应用配置（`~/.seline-app/SelineRead/config.json`）。 */
@JsonSerializable
public class AppConfig {
    /** `dark` / `light`。 */
    public var theme: String = "dark"
    /** 下载目录绝对路径；空串表示用默认目录。 */
    public var downloadDir: String = ""
    /** 当前选中的站点（官方地址或自定义站点）。 */
    public var activeSite: String = ""
    /** 自定义站点（数组，可增删）。 */
    public var customSites: ArrayList<String> = ArrayList<String>()
    /** 种子站（单值，仅对自定义站点生效）。 */
    public var seedSite: String = ""
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
        writeTextFile(Path(path), config.toJson())
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
        writeTextFile(Path(path), config.toJson())
    } catch (failure: Exception) {
        writeDebugLog("accounts.json serialize failed: ${failure.message}")
    }
}
