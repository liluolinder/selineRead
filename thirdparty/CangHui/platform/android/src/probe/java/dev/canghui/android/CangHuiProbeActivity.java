package dev.canghui.android;

import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.InputDevice;
import android.view.MotionEvent;

/** Device-only launcher used by the Android adapter acceptance probe. */
public final class CangHuiProbeActivity extends CangHuiSurfaceActivity {
    public static final String EXTRA_IME_TEXT =
            "dev.canghui.android.extra.PROBE_IME_TEXT";

    private static final String TAG = "CangHuiAndroid";
    private boolean probeCommitted;
    private String probeText = "CangHuiIME";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setSystemBarsMode(CangHuiSystemBarsMode.IMMERSIVE_STICKY);
        String requestedText = getIntent().getStringExtra(EXTRA_IME_TEXT);
        if (requestedText != null) {
            probeText = requestedText;
        }
        Log.i(TAG, "probe_activity=created");
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && !probeCommitted) {
            probeCommitted = true;
            surfaceView().postDelayed(() -> {
                dispatchMultiTouchProbe();
                showInputMethod();
                surfaceView().commitProbeText(probeText);
                emitReceipt("probeIme");
                surfaceView().postDelayed(() -> {
                    hideInputMethod();
                    emitReceipt("probeImeHidden");
                    Log.i(TAG, "probe_ime_hidden=true");
                }, 800L);
            }, 400L);
        }
    }

    private void dispatchMultiTouchProbe() {
        long downTime = SystemClock.uptimeMillis();
        MotionEvent.PointerProperties[] properties = {
            pointerProperties(0), pointerProperties(1)
        };
        MotionEvent.PointerCoords[] coordinates = {
            pointerCoordinates(240.0f, 360.0f),
            pointerCoordinates(760.0f, 720.0f)
        };

        dispatchProbeEvent(downTime, downTime, MotionEvent.ACTION_DOWN,
                1, properties, coordinates);
        dispatchProbeEvent(
                downTime, downTime + 10L,
                MotionEvent.ACTION_POINTER_DOWN
                        | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT),
                2, properties, coordinates);
        coordinates[0].x += 40.0f;
        coordinates[1].x -= 40.0f;
        dispatchProbeEvent(downTime, downTime + 20L, MotionEvent.ACTION_MOVE,
                2, properties, coordinates);
        dispatchProbeEvent(
                downTime, downTime + 30L,
                MotionEvent.ACTION_POINTER_UP
                        | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT),
                2, properties, coordinates);
        dispatchProbeEvent(downTime, downTime + 40L, MotionEvent.ACTION_UP,
                1, properties, coordinates);
        Log.i(TAG, "probe_multitouch=dispatched pointers=2");
    }

    private void dispatchProbeEvent(
            long downTime, long eventTime, int action, int pointerCount,
            MotionEvent.PointerProperties[] properties,
            MotionEvent.PointerCoords[] coordinates) {
        MotionEvent event = MotionEvent.obtain(
                downTime, eventTime, action, pointerCount,
                properties, coordinates, 0, 0, 1.0f, 1.0f,
                0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
        surfaceView().dispatchTouchEvent(event);
        event.recycle();
    }

    private MotionEvent.PointerProperties pointerProperties(int id) {
        MotionEvent.PointerProperties properties =
                new MotionEvent.PointerProperties();
        properties.id = id;
        properties.toolType = MotionEvent.TOOL_TYPE_FINGER;
        return properties;
    }

    private MotionEvent.PointerCoords pointerCoordinates(float x, float y) {
        MotionEvent.PointerCoords coordinates = new MotionEvent.PointerCoords();
        coordinates.x = x;
        coordinates.y = y;
        coordinates.pressure = 0.7f;
        coordinates.size = 0.1f;
        return coordinates;
    }
}
