package seline.book.prefs;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Holds the Android application context and the SharedPreferences handle.
 *
 * <p>Only primitive/string accessors are exposed through {@link PrefsBridge}; no Android type
 * ever escapes to the Cangjie mirror layer.
 */
public final class PrefsStore {
    private static final String FILE = "seline_prefs";

    private static volatile Context appContext;
    private static volatile SharedPreferences prefs;

    private PrefsStore() {
    }

    /** Call once per process, from Application.onCreate() or the entry Activity. */
    public static synchronized void attach(Context context) {
        if (context == null) {
            return;
        }
        Context app = context.getApplicationContext();
        appContext = app != null ? app : context;
        if (prefs == null) {
            prefs = appContext.getSharedPreferences(FILE, Context.MODE_PRIVATE);
        }
    }

    static Context requireContext() {
        Context context = appContext;
        if (context == null) {
            throw new IllegalStateException("PrefsStore.attach() has not been called");
        }
        return context;
    }

    static SharedPreferences require() {
        SharedPreferences value = prefs;
        if (value == null) {
            throw new IllegalStateException("PrefsStore.attach() has not been called");
        }
        return value;
    }
}
