package dev.canghui.android;

import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

public final class CangHuiNativeSurfaceHost
        implements SurfaceHolder.Callback2, AutoCloseable {
    static {
        System.loadLibrary("canghui_android_surface");
    }

    private long nativeHandle = nativeCreate();
    private long generation = 0;
    private SurfaceHolder holder;

    public CangHuiNativeSurfaceHost() {
        if (nativeHandle == 0) {
            throw new IllegalStateException("Unable to allocate CangHui Android surface host");
        }
    }

    public synchronized void bind(SurfaceView surfaceView) {
        if (surfaceView == null) {
            throw new IllegalArgumentException("surfaceView must not be null");
        }
        ensureOpen();
        unbindLocked();
        holder = surfaceView.getHolder();
        holder.addCallback(this);
        attachLocked(holder.getSurface());
    }

    public synchronized void unbind() {
        ensureOpen();
        unbindLocked();
    }

    public synchronized long generation() {
        ensureOpen();
        generation = nativeGeneration(nativeHandle);
        return generation;
    }

    public synchronized int width() {
        ensureOpen();
        return nativeWidth(nativeHandle);
    }

    public synchronized int height() {
        ensureOpen();
        return nativeHeight(nativeHandle);
    }

    public synchronized long render() {
        ensureOpen();
        return nativeRender(nativeHandle);
    }

    public synchronized long pointerEvent(
            int action, int actionIndex, int[] pointerIds, float[] pointerXs,
            float[] pointerYs, float[] pressures, long eventTimeNanos) {
        ensureOpen();
        return nativePointerEvent(
                nativeHandle, action, actionIndex, pointerIds, pointerXs,
                pointerYs, pressures, eventTimeNanos);
    }

    public synchronized long keyEvent(
            int action, int keyCode, int unicodeCodePoint, int metaState,
            int repeatCount, long eventTimeNanos) {
        ensureOpen();
        return nativeKeyEvent(
                nativeHandle, action, keyCode, unicodeCodePoint, metaState,
                repeatCount, eventTimeNanos);
    }

    public synchronized long imeEvent(
            int kind, String text, int selectionStart, int selectionEnd) {
        ensureOpen();
        return nativeImeEvent(
                nativeHandle, kind, text, selectionStart, selectionEnd);
    }

    public synchronized String receipt() {
        ensureOpen();
        return nativeReceipt(nativeHandle);
    }

    @Override
    public synchronized void surfaceCreated(SurfaceHolder callbackHolder) {
        if (callbackHolder == holder && nativeHandle != 0) {
            attachLocked(callbackHolder.getSurface());
        }
    }

    @Override
    public synchronized void surfaceChanged(
            SurfaceHolder callbackHolder, int format, int width, int height) {
        if (callbackHolder == holder && nativeHandle != 0) {
            attachLocked(callbackHolder.getSurface());
        }
    }

    @Override
    public synchronized void surfaceDestroyed(SurfaceHolder callbackHolder) {
        if (callbackHolder == holder && nativeHandle != 0) {
            generation = nativeDetachSurface(nativeHandle, generation);
        }
    }

    @Override
    public synchronized void surfaceRedrawNeeded(SurfaceHolder callbackHolder) {
        if (callbackHolder == holder && nativeHandle != 0) {
            nativeRender(nativeHandle);
        }
    }

    @Override
    public synchronized void close() {
        if (nativeHandle == 0) {
            return;
        }
        unbindLocked();
        nativeDestroy(nativeHandle);
        nativeHandle = 0;
        generation = 0;
    }

    private void attachLocked(Surface surface) {
        if (surface == null || !surface.isValid()) {
            return;
        }
        long attachedGeneration = nativeAttachSurface(nativeHandle, surface);
        if (attachedGeneration > 0) {
            generation = attachedGeneration;
        }
    }

    private void unbindLocked() {
        if (holder != null) {
            holder.removeCallback(this);
            holder = null;
        }
        generation = nativeDetachSurface(nativeHandle, generation);
    }

    private void ensureOpen() {
        if (nativeHandle == 0) {
            throw new IllegalStateException("CangHui Android surface host is closed");
        }
    }

    private static native long nativeCreate();
    private static native long nativeAttachSurface(long handle, Surface surface);
    private static native long nativeDetachSurface(long handle, long expectedGeneration);
    private static native void nativeDestroy(long handle);
    private static native long nativeGeneration(long handle);
    private static native int nativeWidth(long handle);
    private static native int nativeHeight(long handle);
    private static native long nativeRender(long handle);
    private static native long nativePointerEvent(
            long handle, int action, int actionIndex, int[] pointerIds,
            float[] pointerXs, float[] pointerYs, float[] pressures,
            long eventTimeNanos);
    private static native long nativeKeyEvent(
            long handle, int action, int keyCode, int unicodeCodePoint,
            int metaState, int repeatCount, long eventTimeNanos);
    private static native long nativeImeEvent(
            long handle, int kind, String text, int selectionStart,
            int selectionEnd);
    private static native String nativeReceipt(long handle);
}
