@NonProduct
features {}
package ohos_app_cangjie_entry.model

internal import kit.AbilityKit.UIAbilityContext

// ---------------------------------------------------------------------------
// 首选项封装：common 侧只声明接口，具体读写由各平台 specific class 实现。
//   HarmonyOS -> lib/hos/utils/preferences_hos.cj（kit.ArkData Preferences）
//   Android   -> lib/android/utils/preferences_android.cj（SharedPreferences）
// ---------------------------------------------------------------------------

public let SELINE_PREFS_NAME: String = "seline_prefs"

common public class PreferencesUtil {
    common public init()

    /// 绑定 Ability 上下文，必须在任何读写之前调用。
    common public static func attach(context: UIAbilityContext): Unit

    /// 打开（或创建）首选项文件并缓存。
    common public static func loadPreference(name: String): Unit

    /// 删除首选项文件及其缓存。
    common public static func deletePreference(name: String): Unit

    /// 写入键值，按 value 的运行时类型选择存储类型。
    common public static func putValue<T>(prefName: String, key: String, value: T): Unit

    /// 读取键值，缺失或类型不匹配时返回 defValue。
    common public static func getValue<T>(prefName: String, key: String, defValue: T): T

    /// key 是否存在。
    common public static func hasValue(prefName: String, key: String): Bool

    /// 清空首选项文件。
    common public static func clear(prefName: String): Unit

    /// 删除单个 key。
    common public static func deleteValue(prefName: String, key: String): Unit
}
/// App 私有目录（下载文件落在 `<filesDir>/downloads`）。
common public class AppPaths {
    common public init()

    /// 绑定 Ability 上下文，必须在读取目录之前调用。
    common public static func attach(context: UIAbilityContext): Unit

    /// App 私有文件目录。
    common public static func filesDir(): String

    /// App 缓存目录。
    common public static func cacheDir(): String
}



