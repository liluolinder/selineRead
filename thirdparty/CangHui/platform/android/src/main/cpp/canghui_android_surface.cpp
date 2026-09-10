#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <mutex>
#include <new>
#include <string>
#include <vector>

namespace {

constexpr const char* kLogTag = "CangHuiAndroid";

struct SurfaceHost final {
    std::mutex mutex;
    ANativeWindow* window = nullptr;
    std::int64_t generation = 0;
    std::int64_t frameCount = 0;
    std::int64_t pointerEventCount = 0;
    std::int64_t keyEventCount = 0;
    std::int64_t imeEventCount = 0;
    std::int32_t width = 0;
    std::int32_t height = 0;
    std::int32_t lastPointerAction = -1;
    std::int32_t lastPointerX = -1;
    std::int32_t lastPointerY = -1;
    std::int32_t activePointerCount = 0;
    std::int32_t maxPointerCount = 0;
    std::int32_t lastKeyAction = -1;
    std::int32_t lastKeyCode = -1;
    std::int32_t lastImeKind = -1;
    std::string lastImeText;
    std::vector<std::int32_t> pointerXs;
    std::vector<std::int32_t> pointerYs;

    ~SurfaceHost() {
        if (window != nullptr) {
            ANativeWindow_release(window);
        }
    }
};

SurfaceHost* surfaceHost(jlong handle) {
    return reinterpret_cast<SurfaceHost*>(handle);
}

std::uint8_t eventColor(std::int64_t count, std::uint8_t base) {
    return static_cast<std::uint8_t>(base + (count * 37) % (255 - base));
}

bool renderLocked(SurfaceHost* host) {
    if (host == nullptr || host->window == nullptr) {
        return false;
    }

    if (ANativeWindow_setBuffersGeometry(
            host->window, 0, 0, WINDOW_FORMAT_RGBA_8888) != 0) {
        __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                            "render_failed stage=set_geometry generation=%lld",
                            static_cast<long long>(host->generation));
        return false;
    }

    ANativeWindow_Buffer buffer{};
    if (ANativeWindow_lock(host->window, &buffer, nullptr) != 0) {
        __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                            "render_failed stage=lock generation=%lld",
                            static_cast<long long>(host->generation));
        return false;
    }

    host->width = buffer.width;
    host->height = buffer.height;
    const std::uint8_t red = eventColor(host->pointerEventCount, 32);
    const std::uint8_t green = eventColor(host->keyEventCount, 48);
    const std::uint8_t blue = eventColor(host->imeEventCount, 64);
    const std::uint32_t background = 0xff000000U |
        (static_cast<std::uint32_t>(blue) << 16U) |
        (static_cast<std::uint32_t>(green) << 8U) |
        static_cast<std::uint32_t>(red);

    auto* pixels = static_cast<std::uint32_t*>(buffer.bits);
    for (std::int32_t y = 0; y < buffer.height; ++y) {
        std::uint32_t* row = pixels + y * buffer.stride;
        std::fill(row, row + buffer.width, background);
    }

    for (std::size_t index = 0; index < host->pointerXs.size(); ++index) {
        const std::int32_t left = std::max(0, host->pointerXs[index] - 24);
        const std::int32_t right = std::min(buffer.width, host->pointerXs[index] + 24);
        const std::int32_t top = std::max(0, host->pointerYs[index] - 24);
        const std::int32_t bottom = std::min(buffer.height, host->pointerYs[index] + 24);
        for (std::int32_t y = top; y < bottom; ++y) {
            std::uint32_t* row = pixels + y * buffer.stride;
            std::fill(row + left, row + right, 0xffffffffU);
        }
    }

    ANativeWindow_unlockAndPost(host->window);
    host->frameCount += 1;
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "render generation=%lld frame=%lld size=%dx%d pointer=%lld key=%lld ime=%lld",
        static_cast<long long>(host->generation),
        static_cast<long long>(host->frameCount), host->width, host->height,
        static_cast<long long>(host->pointerEventCount),
        static_cast<long long>(host->keyEventCount),
        static_cast<long long>(host->imeEventCount));
    return true;
}

jlong currentGeneration(SurfaceHost* host) {
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    return static_cast<jlong>(host->generation);
}

std::string javaString(JNIEnv* env, jstring value) {
    if (value == nullptr) {
        return {};
    }
    const char* utf = env->GetStringUTFChars(value, nullptr);
    if (utf == nullptr) {
        return {};
    }
    std::string result(utf);
    env->ReleaseStringUTFChars(value, utf);
    return result;
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeCreate(
    JNIEnv*, jclass) {
    return reinterpret_cast<jlong>(new (std::nothrow) SurfaceHost());
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeAttachSurface(
    JNIEnv* env, jclass, jlong handle, jobject surface) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr || surface == nullptr) {
        return 0;
    }

    ANativeWindow* nextWindow = ANativeWindow_fromSurface(env, surface);
    if (nextWindow == nullptr) {
        return 0;
    }

    std::lock_guard<std::mutex> lock(host->mutex);
    if (host->window != nullptr) {
        ANativeWindow_release(host->window);
    }
    host->window = nextWindow;
    host->width = ANativeWindow_getWidth(nextWindow);
    host->height = ANativeWindow_getHeight(nextWindow);
    host->generation += 1;
    __android_log_print(ANDROID_LOG_INFO, kLogTag,
                        "surface_attached generation=%lld size=%dx%d",
                        static_cast<long long>(host->generation),
                        host->width, host->height);
    renderLocked(host);
    return static_cast<jlong>(host->generation);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeDetachSurface(
    JNIEnv*, jclass, jlong handle, jlong expectedGeneration) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }

    std::lock_guard<std::mutex> lock(host->mutex);
    if (expectedGeneration != static_cast<jlong>(host->generation)) {
        __android_log_print(ANDROID_LOG_WARN, kLogTag,
                            "surface_detach_stale expected=%lld actual=%lld",
                            static_cast<long long>(expectedGeneration),
                            static_cast<long long>(host->generation));
        return static_cast<jlong>(host->generation);
    }
    if (host->window != nullptr) {
        ANativeWindow_release(host->window);
        host->window = nullptr;
        host->width = 0;
        host->height = 0;
        host->generation += 1;
        __android_log_print(ANDROID_LOG_INFO, kLogTag,
                            "surface_detached generation=%lld",
                            static_cast<long long>(host->generation));
    }
    return static_cast<jlong>(host->generation);
}

extern "C" JNIEXPORT void JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeDestroy(
    JNIEnv*, jclass, jlong handle) {
    delete surfaceHost(handle);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeGeneration(
    JNIEnv*, jclass, jlong handle) {
    return currentGeneration(surfaceHost(handle));
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeWidth(
    JNIEnv*, jclass, jlong handle) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    return static_cast<jint>(host->width);
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeHeight(
    JNIEnv*, jclass, jlong handle) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    return static_cast<jint>(host->height);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeRender(
    JNIEnv*, jclass, jlong handle) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    renderLocked(host);
    return static_cast<jlong>(host->frameCount);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativePointerEvent(
    JNIEnv* env, jclass, jlong handle, jint action, jint actionIndex,
    jintArray pointerIds, jfloatArray pointerXs, jfloatArray pointerYs,
    jfloatArray pressures, jlong eventTimeNanos) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr || pointerIds == nullptr || pointerXs == nullptr
        || pointerYs == nullptr || pressures == nullptr) {
        return 0;
    }

    const jsize pointerCount = env->GetArrayLength(pointerIds);
    if (pointerCount < 1 || pointerCount > 16
        || env->GetArrayLength(pointerXs) != pointerCount
        || env->GetArrayLength(pointerYs) != pointerCount
        || env->GetArrayLength(pressures) != pointerCount
        || actionIndex < 0 || actionIndex >= pointerCount) {
        return 0;
    }

    jint ids[16]{};
    jfloat xs[16]{};
    jfloat ys[16]{};
    jfloat pointerPressures[16]{};
    env->GetIntArrayRegion(pointerIds, 0, pointerCount, ids);
    env->GetFloatArrayRegion(pointerXs, 0, pointerCount, xs);
    env->GetFloatArrayRegion(pointerYs, 0, pointerCount, ys);
    env->GetFloatArrayRegion(pressures, 0, pointerCount, pointerPressures);
    if (env->ExceptionCheck()) {
        return 0;
    }

    std::lock_guard<std::mutex> lock(host->mutex);
    host->pointerEventCount += 1;
    host->lastPointerAction = action;
    host->lastPointerX = static_cast<std::int32_t>(xs[actionIndex]);
    host->lastPointerY = static_cast<std::int32_t>(ys[actionIndex]);
    host->activePointerCount = pointerCount;
    if (action == 1 || action == 3) {
        host->activePointerCount = 0;
    } else if (action == 6) {
        host->activePointerCount = pointerCount - 1;
    }
    host->maxPointerCount = std::max(
        host->maxPointerCount, static_cast<std::int32_t>(pointerCount));
    host->pointerXs.clear();
    host->pointerYs.clear();
    for (jsize index = 0; index < pointerCount; ++index) {
        host->pointerXs.push_back(static_cast<std::int32_t>(xs[index]));
        host->pointerYs.push_back(static_cast<std::int32_t>(ys[index]));
    }
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "pointer serial=%lld action=%d action_index=%d pointers=%d active=%d max=%d id=%d x=%.1f y=%.1f pressure=%.3f time_ns=%lld",
        static_cast<long long>(host->pointerEventCount), action, actionIndex,
        pointerCount, host->activePointerCount, host->maxPointerCount,
        ids[actionIndex], static_cast<double>(xs[actionIndex]),
        static_cast<double>(ys[actionIndex]),
        static_cast<double>(pointerPressures[actionIndex]),
        static_cast<long long>(eventTimeNanos));
    renderLocked(host);
    return static_cast<jlong>(host->pointerEventCount);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeKeyEvent(
    JNIEnv*, jclass, jlong handle, jint action, jint keyCode,
    jint unicodeCodePoint, jint metaState, jint repeatCount,
    jlong eventTimeNanos) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    host->keyEventCount += 1;
    host->lastKeyAction = action;
    host->lastKeyCode = keyCode;
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "key serial=%lld action=%d code=%d unicode=%d meta=%d repeat=%d time_ns=%lld",
        static_cast<long long>(host->keyEventCount), action, keyCode,
        unicodeCodePoint, metaState, repeatCount,
        static_cast<long long>(eventTimeNanos));
    renderLocked(host);
    return static_cast<jlong>(host->keyEventCount);
}

extern "C" JNIEXPORT jlong JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeImeEvent(
    JNIEnv* env, jclass, jlong handle, jint kind, jstring text,
    jint selectionStart, jint selectionEnd) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return 0;
    }
    const std::string value = javaString(env, text);
    std::lock_guard<std::mutex> lock(host->mutex);
    host->imeEventCount += 1;
    host->lastImeKind = kind;
    host->lastImeText = value;
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "ime serial=%lld kind=%d text=%s selection=%d:%d",
        static_cast<long long>(host->imeEventCount), kind,
        value.c_str(), selectionStart, selectionEnd);
    renderLocked(host);
    return static_cast<jlong>(host->imeEventCount);
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeReceipt(
    JNIEnv* env, jclass, jlong handle) {
    SurfaceHost* host = surfaceHost(handle);
    if (host == nullptr) {
        return env->NewStringUTF("closed=true");
    }
    std::lock_guard<std::mutex> lock(host->mutex);
    char receipt[512];
    std::snprintf(
        receipt, sizeof(receipt),
        "generation=%lld attached=%s size=%dx%d frame=%lld pointer=%lld key=%lld ime=%lld active_pointers=%d max_pointers=%d last_pointer=%d@%d,%d last_key=%d/%d last_ime=%d:%s",
        static_cast<long long>(host->generation),
        host->window == nullptr ? "false" : "true", host->width, host->height,
        static_cast<long long>(host->frameCount),
        static_cast<long long>(host->pointerEventCount),
        static_cast<long long>(host->keyEventCount),
        static_cast<long long>(host->imeEventCount),
        host->activePointerCount, host->maxPointerCount,
        host->lastPointerAction, host->lastPointerX, host->lastPointerY,
        host->lastKeyAction, host->lastKeyCode,
        host->lastImeKind, host->lastImeText.c_str());
    return env->NewStringUTF(receipt);
}
