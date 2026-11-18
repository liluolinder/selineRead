#include <jni.h>
#include <dlfcn.h>
#include <android/log.h>
#include <stdio.h>
#include <string.h>

#define LOG_TAG "SelineOpenSSL"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static void* load_one(const char* dir, const char* name) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/%s", dir, name);
    void* handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if (handle == NULL) {
        LOGE("dlopen %s failed: %s", path, dlerror());
    } else {
        LOGI("dlopen %s ok", path);
    }
    return handle;
}

// Load the errno compatibility shim first with RTLD_GLOBAL, then OpenSSL 3.
// SelineRead ships libcrypto.so / libssl.so in jniLibs; stdx TLS then resolves
// them by SONAME (libcrypto.so.3 / libssl.so.3).
JNIEXPORT jboolean JNICALL
Java_seline_book_read_OpenSslPreload_load(JNIEnv* env, jclass clazz, jstring dir) {
    if (dir == NULL) {
        return JNI_FALSE;
    }
    const char* nativeDir = (*env)->GetStringUTFChars(env, dir, NULL);
    if (nativeDir == NULL) {
        return JNI_FALSE;
    }

    void* shim = load_one(nativeDir, "liberrno_shim.so");
    void* crypto = load_one(nativeDir, "libcrypto.so");
    void* ssl = load_one(nativeDir, "libssl.so");

    (*env)->ReleaseStringUTFChars(env, dir, nativeDir);
    return (shim != NULL && crypto != NULL && ssl != NULL) ? JNI_TRUE : JNI_FALSE;
}
