package seline.book.read;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowManager;

import ohos.stage.ability.adapter.StageActivity;


public class EntryEntryAbilityActivity extends StageActivity {
    static {
        System.loadLibrary("jniseline_read");
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.e("HiHelloWorld", "EntryEntryAbilityActivity");

        Intent intent = getIntent();
        if (intent != null) {
            intent.putExtra("test", "test");
            intent.putExtra("bundleName", "bundleName");
            intent.putExtra("moduleName", "moduleName");
            intent.putExtra("unittest", "unittest");
            intent.putExtra("timeout", "101");
        }

        setInstanceName("seline.book.read:entry:EntryAbility:");
        super.onCreate(savedInstanceState);
        setupImmersiveMode();
        setupWindowInsetsListener();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUI();
        }
    }

    @SuppressWarnings("deprecation")
    private void setupImmersiveMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            getWindow().getAttributes().layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
        } else {
            getWindow().setFlags(
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            );
        }
        hideSystemUI();
    }

    @SuppressWarnings("deprecation")
    private void hideSystemUI() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
        );
    }

    @SuppressWarnings("deprecation")
    private void setupWindowInsetsListener() {
        View decorView = getWindow().getDecorView();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            decorView.setOnApplyWindowInsetsListener((v, insets) -> {
                int statusBarTop = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout()).top;
                int navBarBottom = insets.getInsets(WindowInsets.Type.navigationBars()).bottom;
                seline_read.setStatusBarHeight(statusBarTop);
                seline_read.setNavigationBarHeight(navBarBottom);
                return v.onApplyWindowInsets(insets);
            });
        } else {
            decorView.setOnApplyWindowInsetsListener((v, insets) -> {
                seline_read.setStatusBarHeight(insets.getSystemWindowInsetTop());
                seline_read.setNavigationBarHeight(insets.getSystemWindowInsetBottom());
                return v.onApplyWindowInsets(insets);
            });
        }
    }
}
