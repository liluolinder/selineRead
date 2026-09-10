package dev.canghui.android;

import android.content.Context;
import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.util.Log;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.SurfaceView;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;

/** Android input and IME ingress for the generation-safe native surface host. */
public final class CangHuiAndroidView extends SurfaceView {
    private static final String TAG = "CangHuiAndroid";

    private static final int IME_COMPOSING = 1;
    private static final int IME_COMMIT = 2;
    private static final int IME_DELETE = 3;
    private static final int IME_FINISH = 4;
    private static final int IME_SELECTION = 5;

    private final CangHuiNativeSurfaceHost surfaceHost;

    public CangHuiAndroidView(
            Context context, CangHuiNativeSurfaceHost surfaceHost) {
        super(context);
        if (surfaceHost == null) {
            throw new IllegalArgumentException("surfaceHost must not be null");
        }
        this.surfaceHost = surfaceHost;
        setFocusable(true);
        setFocusableInTouchMode(true);
        setContentDescription("CangHui Android renderer and text input surface");
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        int pointerCount = event.getPointerCount();
        int[] pointerIds = new int[pointerCount];
        float[] pointerXs = new float[pointerCount];
        float[] pointerYs = new float[pointerCount];
        float[] pressures = new float[pointerCount];
        for (int index = 0; index < pointerCount; index += 1) {
            pointerIds[index] = event.getPointerId(index);
            pointerXs[index] = event.getX(index);
            pointerYs[index] = event.getY(index);
            pressures[index] = event.getPressure(index);
        }
        surfaceHost.pointerEvent(
                event.getActionMasked(), event.getActionIndex(), pointerIds,
                pointerXs, pointerYs, pressures,
                event.getEventTime() * 1_000_000L);
        if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
            requestFocus();
        } else if (event.getActionMasked() == MotionEvent.ACTION_UP) {
            performClick();
        }
        return true;
    }

    @Override
    public boolean performClick() {
        super.performClick();
        return true;
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (event.isSystem()) {
            return super.onKeyDown(keyCode, event);
        }
        surfaceHost.keyEvent(
                KeyEvent.ACTION_DOWN, keyCode, event.getUnicodeChar(),
                event.getMetaState(), event.getRepeatCount(),
                event.getEventTime() * 1_000_000L);
        return true;
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (event.isSystem()) {
            return super.onKeyUp(keyCode, event);
        }
        surfaceHost.keyEvent(
                KeyEvent.ACTION_UP, keyCode, event.getUnicodeChar(),
                event.getMetaState(), event.getRepeatCount(),
                event.getEventTime() * 1_000_000L);
        return true;
    }

    @Override
    public boolean onCheckIsTextEditor() {
        return true;
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
        outAttrs.inputType = InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES;
        outAttrs.imeOptions = EditorInfo.IME_ACTION_DONE
                | EditorInfo.IME_FLAG_NO_EXTRACT_UI;
        outAttrs.initialSelStart = 0;
        outAttrs.initialSelEnd = 0;
        Log.i(TAG, "input_connection=created receipt=" + surfaceHost.receipt());
        return new CangHuiInputConnection();
    }

    public void showInputMethod() {
        post(() -> {
            requestFocus();
            InputMethodManager manager =
                    (InputMethodManager) getContext().getSystemService(
                            Context.INPUT_METHOD_SERVICE);
            if (manager != null) {
                manager.restartInput(this);
                boolean requested = manager.showSoftInput(
                        this, InputMethodManager.SHOW_IMPLICIT);
                Log.i(TAG, "ime_show_requested=" + requested
                        + " receipt=" + surfaceHost.receipt());
            }
        });
    }

    public void hideInputMethod() {
        InputMethodManager manager =
                (InputMethodManager) getContext().getSystemService(
                        Context.INPUT_METHOD_SERVICE);
        if (manager != null) {
            boolean requested = manager.hideSoftInputFromWindow(
                    getWindowToken(), 0);
            Log.i(TAG, "ime_hide_requested=" + requested
                    + " receipt=" + surfaceHost.receipt());
        }
    }

    public void commitProbeText(String text) {
        EditorInfo attrs = new EditorInfo();
        InputConnection connection = onCreateInputConnection(attrs);
        connection.commitText(text == null ? "" : text, 1);
        Log.i(TAG, "probe_ime_committed receipt=" + surfaceHost.receipt());
    }

    private final class CangHuiInputConnection extends BaseInputConnection {
        private final SpannableStringBuilder editable = new SpannableStringBuilder();

        CangHuiInputConnection() {
            super(CangHuiAndroidView.this, true);
            Selection.setSelection(editable, 0);
        }

        @Override
        public Editable getEditable() {
            return editable;
        }

        @Override
        public boolean setComposingText(CharSequence text, int newCursorPosition) {
            reportIme(IME_COMPOSING, text);
            return super.setComposingText(text, newCursorPosition);
        }

        @Override
        public boolean commitText(CharSequence text, int newCursorPosition) {
            reportIme(IME_COMMIT, text);
            return super.commitText(text, newCursorPosition);
        }

        @Override
        public boolean deleteSurroundingText(int beforeLength, int afterLength) {
            reportIme(IME_DELETE, beforeLength + ":" + afterLength);
            return super.deleteSurroundingText(beforeLength, afterLength);
        }

        @Override
        public boolean finishComposingText() {
            reportIme(IME_FINISH, "");
            return super.finishComposingText();
        }

        @Override
        public boolean setSelection(int start, int end) {
            surfaceHost.imeEvent(IME_SELECTION, "", start, end);
            return super.setSelection(start, end);
        }

        private void reportIme(int kind, CharSequence text) {
            int start = Selection.getSelectionStart(editable);
            int end = Selection.getSelectionEnd(editable);
            surfaceHost.imeEvent(
                    kind, text == null ? "" : text.toString(), start, end);
        }
    }
}
