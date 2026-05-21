package seline.book.read;

import android.os.Build;
import android.util.Log;
import android.view.View;
import android.view.WindowInsets;
import android.view.Window;
import android.view.WindowManager;

public class avoidSafeArea {
    private static final String TAG = "avoidSafeArea";
    private static View decorView = null;

    @SuppressWarnings("deprecation")
    public static int getStatusBarHeight() {
        if (decorView == null) {
            return 0;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsets insets = decorView.getRootWindowInsets();
            if (insets != null) {
                return insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout()).top;
            }
        } else {
            WindowInsets insets = decorView.getRootWindowInsets();
            if (insets != null) {
                return insets.getSystemWindowInsetTop();
            }
        }
        return 0;
    }

    @SuppressWarnings("deprecation")
    public static int getNavigationBarHeight() {
        if (decorView == null) {
            return 0;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsets insets = decorView.getRootWindowInsets();
            if (insets != null) {
                return insets.getInsets(WindowInsets.Type.navigationBars()).bottom;
            }
        } else {
            WindowInsets insets = decorView.getRootWindowInsets();
            if (insets != null) {
                return insets.getSystemWindowInsetBottom();
            }
        }
        return 0;
    }

    @SuppressWarnings("deprecation")
    public static void setupImmersive(Window window) {
        decorView = window.getDecorView();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams lp = window.getAttributes();
            lp.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(lp);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false);
        } else {
            window.setFlags(
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            );
        }
        decorView.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
        );
    }

    @SuppressWarnings("deprecation")
    public static void hideSystemUI(Window window) {
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
        );
    }
}
