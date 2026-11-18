features {os.ohos}
package ohos_app_cangjie_entry.model

internal import kit.AbilityKit.*
internal import kit.ArkData.*
import ohos.ark_interop_helper.StageContext
import std.collection.HashMap

// ---------------------------------------------------------------------------
// HarmonyOS 首选项实现（kit.ArkData Preferences）。
// ---------------------------------------------------------------------------

let preferencesUtilLogName = "PreferencesUtil"

extend PreferencesValueType {
    public static func of<T>(value: T): PreferencesValueType {
        match (value) {
            case stringV: String => PreferencesValueType.string(stringV)
            case intV: Int64 => PreferencesValueType.integer(intV)
            case floatV: Float64 => PreferencesValueType.double(floatV)
            case boolV: Bool => PreferencesValueType.bool(boolV)
            case stringArrayV: Array<String> => PreferencesValueType.stringArray(stringArrayV)
            case floatArrayV: Array<Float64> => PreferencesValueType.doubleArray(floatArrayV)
            case boolArrayV: Array<Bool> => PreferencesValueType.boolArray(boolArrayV)
            case _ => throw Exception("${preferencesUtilLogName}:类型不支持")
        }
    }

    public func get<T>(): T {
        match (this) {
            case string(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型String与期望类型不匹配")
            case integer(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Int64与期望类型不匹配")
            case double(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Float64与期望类型不匹配")
            case bool(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Bool与期望类型不匹配")
            case stringArray(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Array<String>与期望类型不匹配")
            case doubleArray(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Array<Float64>与期望类型不匹配")
            case boolArray(v) => (v as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Array<Bool>与期望类型不匹配")
            case _ => throw Exception("${preferencesUtilLogName}:类型不支持")
        }
    }
}

var hosFilesDir: String = "."
var hosCacheDir: String = "."
var hosContext: ?UIAbilityContext = None
var hosPrefMap: HashMap<String, Preferences> = HashMap<String, Preferences>()

specific public class PreferencesUtil {
    specific public init() {}

    private static func stageContextValue(): StageContext {
        match (hosContext) {
            case Some(value) => getStageContext(value)
            case None => throw IllegalStateException("${preferencesUtilLogName}:attach() 未调用")
        }
    }

    private static func prefsOf(name: String): Preferences {
        match (hosPrefMap.get(name)) {
            case Some(value) => value
            case None =>
                let opened = Preferences.getPreferences(PreferencesUtil.stageContextValue(), name)
                hosPrefMap.add(name, opened)
                opened
        }
    }

    specific public static func attach(context: UIAbilityContext): Unit {
        hosContext = Some(context)
        hosFilesDir = context.filesDir
        hosCacheDir = context.cacheDir
        try {
            PreferencesUtil.loadPreference(SELINE_PREFS_NAME)
        } catch (_: Exception) {
            ()
        }
    }

    specific public static func loadPreference(name: String): Unit {
        try {
            PreferencesUtil.prefsOf(name)
        } catch (_: Exception) {
            ()
        }
    }

    specific public static func deletePreference(name: String): Unit {
        try {
            Preferences.deletePreferences(PreferencesUtil.stageContextValue(), name)
        } catch (_: Exception) {
            ()
        }
        hosPrefMap.remove(name)
    }

    specific public static func putValue<T>(prefName: String, key: String, value: T): Unit {
        try {
            let target = PreferencesUtil.prefsOf(prefName)
            target.put(key, PreferencesValueType.of<T>(value))
            target.flush()
        } catch (_: Exception) {
            ()
        }
    }

    specific public static func getValue<T>(prefName: String, key: String, defValue: T): T {
        try {
            let target = PreferencesUtil.prefsOf(prefName)
            target.get(key, PreferencesValueType.of<T>(defValue)).get<T>()
        } catch (_: Exception) {
            defValue
        }
    }

    specific public static func hasValue(prefName: String, key: String): Bool {
        try {
            PreferencesUtil.prefsOf(prefName).has(key)
        } catch (_: Exception) {
            false
        }
    }

    specific public static func clear(prefName: String): Unit {
        try {
            let target = PreferencesUtil.prefsOf(prefName)
            target.clear()
            target.flush()
        } catch (_: Exception) {
            ()
        }
    }

    specific public static func deleteValue(prefName: String, key: String): Unit {
        try {
            let target = PreferencesUtil.prefsOf(prefName)
            target.delete(key)
            target.flush()
        } catch (_: Exception) {
            ()
        }
    }

}

specific public class AppPaths {
    specific public init() {}

    specific public static func attach(context: UIAbilityContext): Unit {
        hosFilesDir = context.filesDir
        hosCacheDir = context.cacheDir
    }

    specific public static func filesDir(): String {
        hosFilesDir
    }

    specific public static func cacheDir(): String {
        hosCacheDir
    }
}








