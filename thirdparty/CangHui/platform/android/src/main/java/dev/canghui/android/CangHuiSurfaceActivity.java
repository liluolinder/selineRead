package dev.canghui.android;

import android.app.Activity;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;

/**
 * Minimal Activity owner for the CangHui native-surface bootstrap.
 *
 * <p>The Activity owns the Java host lifetime. Surface creation and replacement
 * remain owned by {@link CangHuiNativeSurfaceHost}'s generation-safe
 * {@code SurfaceHolder.Callback2} implementation.</p>
 */
@SuppressWarnings("deprecation")
public class CangHuiSurfaceActivity extends Activity {
    private static final String TAG = "CangHuiAndroid";

    private CangHuiNativeSurfaceHost surfaceHost;
    private CangHuiAndroidView surfaceView;
    private CangHuiSystemBarsMode systemBarsMode = CangHuiSystemBarsMode.VISIBLE;
    private int originalStatusBarColor;
    private int originalNavigationBarColor;
    private boolean originalNavigationBarContrastEnforced;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        originalStatusBarColor = window.getStatusBarColor();
        originalNavigationBarColor = window.getNavigationBarColor();
        if (Build.VERSION.SDK_INT >= 29) {
            originalNavigationBarContrastEnforced =
                    window.isNavigationBarContrastEnforced();
        }
        surfaceHost = new CangHuiNativeSurfaceHost();
        surfaceView = new CangHuiAndroidView(this, surfaceHost);
        setContentView(surfaceView);
        applySystemBarsMode();
    }

    @Override
    protected void onStart() {
        super.onStart();
        surfaceHost.bind(surfaceView);
        surfaceView.requestFocus();
        emitReceipt("onStart");
    }

    @Override
    protected void onStop() {
        surfaceHost.unbind();
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        surfaceHost.close();
        surfaceHost = null;
        surfaceView = null;
        super.onDestroy();
    }

    protected final CangHuiNativeSurfaceHost surfaceHost() {
        if (surfaceHost == null) {
            throw new IllegalStateException("CangHui Android surface host is not active");
        }
        return surfaceHost;
    }

    protected final CangHuiAndroidView surfaceView() {
        if (surfaceView == null) {
            throw new IllegalStateException("CangHui Android surface view is not active");
        }
        return surfaceView;
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            applySystemBarsMode();
        }
        if (hasFocus && surfaceView != null) {
            emitReceipt("windowFocus");
        }
    }

    public final void showInputMethod() {
        surfaceView().showInputMethod();
    }

    public final void hideInputMethod() {
        surfaceView().hideInputMethod();
    }

    public final CangHuiSystemBarsMode systemBarsMode() {
        return systemBarsMode;
    }

    public final void setSystemBarsMode(CangHuiSystemBarsMode mode) {
        if (mode == null) {
            throw new IllegalArgumentException("system bars mode must not be null");
        }
        systemBarsMode = mode;
        applySystemBarsMode();
    }

    private void applySystemBarsMode() {
        Window window = getWindow();
        View decorView = window.getDecorView();
        boolean visible = systemBarsMode == CangHuiSystemBarsMode.VISIBLE;
        boolean immersive =
                systemBarsMode == CangHuiSystemBarsMode.IMMERSIVE_STICKY;

        if (visible) {
            window.setStatusBarColor(originalStatusBarColor);
            window.setNavigationBarColor(originalNavigationBarColor);
            if (Build.VERSION.SDK_INT >= 29) {
                window.setNavigationBarContrastEnforced(
                        originalNavigationBarContrastEnforced);
            }
        } else {
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            if (Build.VERSION.SDK_INT >= 29) {
                window.setNavigationBarContrastEnforced(false);
            }
        }

        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(visible);
            WindowInsetsController controller = window.getInsetsController();
            if (controller != null) {
                int types = WindowInsets.Type.statusBars()
                        | WindowInsets.Type.navigationBars();
                if (immersive) {
                    controller.setSystemBarsBehavior(
                            WindowInsetsController
                                    .BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                    controller.hide(types);
                } else {
                    controller.show(types);
                }
            }
        } else {
            int flags = View.SYSTEM_UI_FLAG_VISIBLE;
            if (!visible) {
                flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
            }
            if (immersive) {
                flags |= View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
            }
            decorView.setSystemUiVisibility(flags);
        }
        Log.i(TAG, "system_bars=" + systemBarsMode.name());
    }

    protected final void emitReceipt(String stage) {
        if (surfaceHost != null) {
            Log.i(TAG, "activity=" + stage + " receipt=" + surfaceHost.receipt());
        }
    }
}
