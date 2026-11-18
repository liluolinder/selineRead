package seline.book.prefs;

/**
 * The single class mirrored into Cangjie by java-mirror-gen.
 *
 * <p>Public surface deliberately restricted to String / long / boolean / void so that the
 * generated mirror only needs the pre-mirrored java.lang types and no transitive closure.
 */
public final class PrefsBridge {
    private PrefsBridge() {
    }

    public static String getString(String key, String defValue) {
        return PrefsStore.require().getString(key, defValue);
    }

    public static void setString(String key, String value) {
        PrefsStore.require().edit().putString(key, value).commit();
    }

    public static long getLong(String key, long defValue) {
        return PrefsStore.require().getLong(key, defValue);
    }

    public static void setLong(String key, long value) {
        PrefsStore.require().edit().putLong(key, value).commit();
    }

    public static boolean getBool(String key, boolean defValue) {
        return PrefsStore.require().getBoolean(key, defValue);
    }

    public static void setBool(String key, boolean value) {
        PrefsStore.require().edit().putBoolean(key, value).commit();
    }

    public static boolean has(String key) {
        return PrefsStore.require().contains(key);
    }

    public static void remove(String key) {
        PrefsStore.require().edit().remove(key).commit();
    }

    public static void clear() {
        PrefsStore.require().edit().clear().commit();
    }

    /** No-op: every setter already commits synchronously. Kept for HOS flush() symmetry. */
    public static void flush() {
    }

    /** Absolute path of the app-private files directory (used for book downloads). */
    public static String filesDir() {
        return PrefsStore.requireContext().getFilesDir().getAbsolutePath();
    }

    public static String cacheDir() {
        return PrefsStore.requireContext().getCacheDir().getAbsolutePath();
    }
}
