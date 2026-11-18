features {os.android}
package ohos_app_cangjie_entry.model

internal import java.lang.*
internal import kit.AbilityKit.UIAbilityContext
internal import mirrors.*
import ohos.concurrency.launch
import std.collection.ArrayList
import std.collection.HashMap
import std.sync.Mutex

// ---------------------------------------------------------------------------
// Android 首选项实现（Java SharedPreferences）。
//
// ArkData 的 PreferencesValueType 在 Android 不存在，因此这里用等价的本地
// 枚举承载类型信息；JNI 调用要求线程已 attach，读走内存缓存。
//
// 重要限制：Cangjie `spawn` 工作线程不能直接调用 Java 互操作。ART 在
// AttachCurrentThread 时按自己的栈布局校验当前线程栈（Thread::InitStackHwm），
// 而 Cangjie 线程的栈不满足该假设，会触发 SIGABRT：
//   Check failed: FindStackTop() > reinterpret_cast<void*>(tlsPtr_.stack_end)
// 因此所有 SharedPreferences（JNI）访问都必须落在 UI 线程：
//   * putValue / clear / deleteValue 只更新内存缓存，真正写入通过 `launch`
//     投递到 UI 线程执行；
//   * getValue 未命中缓存时直读 Java；应用启动时会在 UI 线程把设置键读一遍，
//     因此工作线程后续的读取都会命中缓存。
// ---------------------------------------------------------------------------

let preferencesUtilLogName = "PreferencesUtil"

enum AndroidPrefValue {
    | Str(String)
    | Int(Int64)
    | Float(Float64)
    | Flag(Bool)
    | StrArray(Array<String>)
}

extend AndroidPrefValue {
    static func of<T>(value: T): AndroidPrefValue {
        match (value) {
            case text: String => AndroidPrefValue.Str(text)
            case number: Int64 => AndroidPrefValue.Int(number)
            case real: Float64 => AndroidPrefValue.Float(real)
            case flag: Bool => AndroidPrefValue.Flag(flag)
            case texts: Array<String> => AndroidPrefValue.StrArray(texts)
            case _ => throw Exception("${preferencesUtilLogName}:类型不支持")
        }
    }

    func get<T>(): T {
        match (this) {
            case Str(value) => (value as T) ?? throw Exception("${preferencesUtilLogName}:存储类型String与期望类型不匹配")
            case Int(value) => (value as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Int64与期望类型不匹配")
            case Float(value) => (value as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Float64与期望类型不匹配")
            case Flag(value) => (value as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Bool与期望类型不匹配")
            case StrArray(value) => (value as T) ?? throw Exception("${preferencesUtilLogName}:存储类型Array<String>与期望类型不匹配")
        }
    }
}

/// 待写入 SharedPreferences 的操作，只在 UI 线程消费。
enum AndroidPrefOp {
    | Put(String, AndroidPrefValue)
    | Remove(String)
    | Clear
}

var androidCache: HashMap<String, HashMap<String, AndroidPrefValue>> =
    HashMap<String, HashMap<String, AndroidPrefValue>>()
var androidFilesDir: String = ""
var androidCacheDir: String = ""
var pendingPrefOps: ArrayList<AndroidPrefOp> = ArrayList<AndroidPrefOp>()
var flushScheduled: Bool = false
let prefsLock = Mutex()

private func readJavaString(value: Option<JString>): String {
    match (value) {
        case Some(text) => text.toString()
        case None => ""
    }
}

specific public class PreferencesUtil {
    specific public init() {}

    private static func bucket(prefName: String): HashMap<String, AndroidPrefValue> {
        match (androidCache.get(prefName)) {
            case Some(value) => value
            case None =>
                let created = HashMap<String, AndroidPrefValue>()
                androidCache.add(prefName, created)
                created
        }
    }

    private static func scheduleFlush(): Unit {
        prefsLock.lock()
        if (flushScheduled) {
            prefsLock.unlock()
            return
        }
        flushScheduled = true
        prefsLock.unlock()
        launch({ => PreferencesUtil.flushPending() })
    }

    /// 在 UI 线程把队列里的操作写入 SharedPreferences。
    private static func flushPending(): Unit {
        let ops = ArrayList<AndroidPrefOp>()
        prefsLock.lock()
        for (op in pendingPrefOps) {
            ops.add(op)
        }
        pendingPrefOps.clear()
        flushScheduled = false
        prefsLock.unlock()
        for (op in ops) {
            match (op) {
                case Put(key, value) =>
                    match (value) {
                        case Str(text) => PrefsBridge.setString(JString(key), JString(text))
                        case Int(number) => PrefsBridge.setLong(JString(key), number)
                        case Flag(flag) => PrefsBridge.setBool(JString(key), flag)
                        case _ => ()
                    }
                case Remove(key) => PrefsBridge.remove(JString(key))
                case Clear => PrefsBridge.clear()
            }
        }
        if (ops.size > 0) {
            PrefsBridge.flush()
        }
    }

    specific public static func attach(context: UIAbilityContext): Unit {
        androidFilesDir = readJavaString(PrefsBridge.filesDir())
        androidCacheDir = readJavaString(PrefsBridge.cacheDir())
        // PrefsStore.attach(this) 已由 Activity 在仓颉运行时启动前完成。
    }

    specific public static func loadPreference(name: String): Unit {
        ()
    }

    specific public static func deletePreference(name: String): Unit {
        PreferencesUtil.clear(name)
    }

    specific public static func putValue<T>(prefName: String, key: String, value: T): Unit {
        let stored = AndroidPrefValue.of<T>(value)
        prefsLock.lock()
        PreferencesUtil.bucket(prefName).add(key, stored)
        pendingPrefOps.add(AndroidPrefOp.Put(key, stored))
        prefsLock.unlock()
        PreferencesUtil.scheduleFlush()
    }

    specific public static func getValue<T>(prefName: String, key: String, defValue: T): T {
        prefsLock.lock()
        let cached = PreferencesUtil.bucket(prefName).get(key)
        prefsLock.unlock()
        match (cached) {
            case Some(value) => return value.get<T>()
            case None => ()
        }
        let fallback = AndroidPrefValue.of<T>(defValue)
        let loaded = match (fallback) {
            case Str(text) =>
                match (PrefsBridge.getString(JString(key), JString(text))) {
                    case Some(value) => AndroidPrefValue.Str(value.toString())
                    case None => fallback
                }
            case Int(number) => AndroidPrefValue.Int(PrefsBridge.getLong(JString(key), number))
            case Flag(flag) => AndroidPrefValue.Flag(PrefsBridge.getBool(JString(key), flag))
            case _ => fallback
        }
        prefsLock.lock()
        PreferencesUtil.bucket(prefName).add(key, loaded)
        prefsLock.unlock()
        loaded.get<T>()
    }

    specific public static func hasValue(prefName: String, key: String): Bool {
        prefsLock.lock()
        let exists = PreferencesUtil.bucket(prefName).contains(key)
        prefsLock.unlock()
        if (exists) {
            return true
        }
        PrefsBridge.has(JString(key))
    }

    specific public static func clear(prefName: String): Unit {
        prefsLock.lock()
        PreferencesUtil.bucket(prefName).clear()
        pendingPrefOps.add(AndroidPrefOp.Clear)
        prefsLock.unlock()
        PreferencesUtil.scheduleFlush()
    }

    specific public static func deleteValue(prefName: String, key: String): Unit {
        prefsLock.lock()
        PreferencesUtil.bucket(prefName).remove(key)
        pendingPrefOps.add(AndroidPrefOp.Remove(key))
        prefsLock.unlock()
        PreferencesUtil.scheduleFlush()
    }
}

specific public class AppPaths {
    specific public init() {}

    specific public static func attach(context: UIAbilityContext): Unit {
        androidFilesDir = readJavaString(PrefsBridge.filesDir())
        androidCacheDir = readJavaString(PrefsBridge.cacheDir())
    }

    specific public static func filesDir(): String {
        androidFilesDir
    }

    specific public static func cacheDir(): String {
        androidCacheDir
    }
}
