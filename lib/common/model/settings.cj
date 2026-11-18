@NonProduct
features {}
package ohos_app_cangjie_entry.model


import std.collection.*


// ---------------------------------------------------------------------------
// Persisted application settings. All storage goes through the platform
// preferences facade declared in prefs.cj, so this file stays platform-neutral.
// ---------------------------------------------------------------------------

public let DEFAULT_BASE_URL: String = "https://zh.eva101.ru"
public let DEFAULT_SEED_URL: String = "https://z-library.sk"

let KEY_BASE_URL: String = "seline.base_url"
let KEY_SEED_URL: String = "seline.seed_url"
let KEY_COOKIE: String = "seline.cookie"
let KEY_ACCOUNT_NAME: String = "seline.account_name"
let KEY_ACCOUNT_EMAIL: String = "seline.account_email"
let KEY_SEARCH_ORDER: String = "seline.search_order"
let KEY_DOWNLOADS: String = "seline.downloads"
let KEY_FIRST_LAUNCH: String = "seline.first_launch"

public class SelineSettings {
    public static func baseUrl(): String {
        PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_BASE_URL, DEFAULT_BASE_URL)
    }

    public static func setBaseUrl(value: String): Unit {
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_BASE_URL, value)
    }

    public static func seedUrl(): String {
        PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_SEED_URL, DEFAULT_SEED_URL)
    }

    public static func setSeedUrl(value: String): Unit {
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_SEED_URL, value)
    }

    public static func cookie(): String {
        PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_COOKIE, "")
    }

    public static func saveLogin(cookie: String, name: String, email: String): Unit {
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_COOKIE, cookie)
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_ACCOUNT_NAME, name)
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_ACCOUNT_EMAIL, email)
    }

    public static func clearLogin(): Unit {
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_COOKIE, "")
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_ACCOUNT_NAME, "")
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_ACCOUNT_EMAIL, "")
    }

    public static func accountName(): String {
        PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_ACCOUNT_NAME, "")
    }

    public static func accountEmail(): String {
        PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_ACCOUNT_EMAIL, "")
    }

    public static func searchOrder(): String {
        PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_SEARCH_ORDER, "relevance")
    }

    public static func setSearchOrder(value: String): Unit {
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_SEARCH_ORDER, value)
    }

    public static func markLaunched(): Unit {
        PreferencesUtil.putValue<Bool>(SELINE_PREFS_NAME, KEY_FIRST_LAUNCH, true)
    }

    public static func downloadsDir(): String {
        AppPaths.filesDir() + "/downloads"
    }

    public static func addDownload(item: LocalDownload): Unit {
        let line = sanitize(item.title) + "\t" + sanitize(item.fileName) + "\t" + sanitize(item.path)
        let previous = PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_DOWNLOADS, "")
        let next = if (previous.size == 0) {
            line
        } else {
            line + "\n" + previous
        }
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_DOWNLOADS, next)
    }

    public static func downloads(): ArrayList<LocalDownload> {
        let result = ArrayList<LocalDownload>()
        let raw = PreferencesUtil.getValue<String>(SELINE_PREFS_NAME, KEY_DOWNLOADS, "")
        if (raw.size == 0) {
            return result
        }
        let lines = raw.split("\n", removeEmpty: true)
        var count = 0
        for (line in lines) {
            if (count >= 100) {
                break
            }
            let parts = line.split("\t")
            if (parts.size >= 3) {
                result.add(LocalDownload(parts[0], parts[1], parts[2]))
                count += 1
            }
        }
        result
    }

    public static func clearDownloads(): Unit {
        PreferencesUtil.putValue<String>(SELINE_PREFS_NAME, KEY_DOWNLOADS, "")
    }

    public static func clearAll(): Unit {
        PreferencesUtil.clear(SELINE_PREFS_NAME)
    }

    private static func sanitize(value: String): String {
        value.replace("\t", " ").replace("\n", " ").replace("\r", " ")
    }
}

public class LocalDownload {
    public var title: String
    public var fileName: String
    public var path: String

    public init(title: String, fileName: String, path: String) {
        this.title = title
        this.fileName = fileName
        this.path = path
    }
}




















