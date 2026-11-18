package mirrors

import java.lang.*

@JavaMirror["seline.book.prefs.PrefsBridge"]
public class PrefsBridge {
    public static func getString(key: ?JString, defValue: ?JString): ?JString

    public static func setString(key: ?JString, value: ?JString): Unit

    public static func getLong(key: ?JString, defValue: Int64): Int64

    public static func setLong(key: ?JString, value: Int64): Unit

    public static func getBool(key: ?JString, defValue: Bool): Bool

    public static func setBool(key: ?JString, value: Bool): Unit

    public static func has(key: ?JString): Bool

    public static func remove(key: ?JString): Unit

    public static func clear(): Unit

    public static func flush(): Unit

    public static func filesDir(): ?JString

    public static func cacheDir(): ?JString
}