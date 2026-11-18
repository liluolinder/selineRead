package seline.book.prefs;

import android.app.Activity;
import android.graphics.Color;
import android.os.Build;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

/**
 * Small Android window wrapper: edge-to-edge full screen layout plus safe-area inset reporting.
 *
 * <p>The Cangjie side mirrors this class and polls {@link #topInsetDp()} / {@link #bottomInsetDp()}
 * whenever the root view's area changes, so no Java -> Cangjie callback plumbing is required.
 */
public final class WindowBridge {
    private static final String TAG = "SelineReadWindow";

    private static volatile float topInsetDp = 0f;
    private static volatile float bottomInsetDp = 0f;
    private static volatile float density = 1f;
    private static volatile int widthPx = 0;
    private static volatile int heightPx = 0;
    private static volatile boolean attached = false;

    private WindowBridge() {
    }

    public static synchronized void attach(Activity activity) {
        if (activity == null) {
            return;
        }
        try {
            density = activity.getResources().getDisplayMetrics().density;
            Window window = activity.getWindow();
            WindowCompat.setDecorFitsSystemWindows(window, false);
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.setStatusBarContrastEnforced(false);
                window.setNavigationBarContrastEnforced(false);
            }
            WindowInsetsControllerCompat controller =
                    WindowCompat.getInsetsController(window, window.getDecorView());
            if (controller != null) {
                controller.setAppearanceLightStatusBars(true);
                controller.setAppearanceLightNavigationBars(true);
            }
            View decor = window.getDecorView();
            decor.setOnApplyWindowInsetsListener((view, insets) -> {
                WindowInsetsCompat compat = WindowInsetsCompat.toWindowInsetsCompat(insets, view);
                androidx.core.graphics.Insets bars = compat.getInsets(
                        WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
                topInsetDp = bars.top / density;
                bottomInsetDp = bars.bottom / density;
                widthPx = view.getWidth();
                heightPx = view.getHeight();
                return insets;
            });
            decor.requestApplyInsets();
            attached = true;
            Log.i(TAG, "attached, density=" + density);
        } catch (Throwable error) {
            Log.e(TAG, "attach failed", error);
        }
    }

    public static void applyFullscreen() {
        // Layout already draws edge-to-edge; status/navigation bar icons stay visible.
        if (!attached) {
            return;
        }
    }

    public static float topInsetDp() {
        return topInsetDp;
    }

    public static float bottomInsetDp() {
        return bottomInsetDp;
    }

    public static float density() {
        return density;
    }

    public static int widthPx() {
        return widthPx;
    }

    public static int heightPx() {
        return heightPx;
    }
}


