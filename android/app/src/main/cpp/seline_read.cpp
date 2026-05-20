#include "seline_read.h"
#include <android/log.h>
#include <cstdlib>
#include <cstring>
#include <jni.h>

JavaVM *g_javaVm = nullptr;
JNIEnv *g_jniEnv = nullptr;
jobject g_cls = nullptr;

#define LOGTAG "SELINE_READ_JNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOGTAG, __VA_ARGS__)

static const char *CopyJavaStringResult(jstring str) {
  if (str == nullptr) {
    return nullptr;
  }

  const char *chars = g_jniEnv->GetStringUTFChars(str, nullptr);
  if (chars == nullptr) {
    g_jniEnv->DeleteLocalRef(str);
    return nullptr;
  }

  char *copy = strdup(chars);
  g_jniEnv->ReleaseStringUTFChars(str, chars);
  g_jniEnv->DeleteLocalRef(str);
  return copy;
}

jint JNI_OnLoad(JavaVM *vm, void *reserved) {
  g_javaVm = vm;

  if (vm->GetEnv((void **)&g_jniEnv, JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }

  jclass myClass =
      g_jniEnv->FindClass("seline/book/read/seline_read");
  g_cls = g_jniEnv->NewGlobalRef(myClass);
  if (g_cls == nullptr) {
    LOGE("class not found.");
    return JNI_ERR;
  }

  return JNI_VERSION_1_6;
}

const char *FfiLogicTest() {
  if (g_javaVm == nullptr) {
    LOGE("JavaVM not initialized");
    return nullptr;
  }
  jclass cls = (jclass)g_cls;
  jmethodID ffiLogicTest =
      g_jniEnv->GetStaticMethodID(cls, "logicTest", "()Ljava/lang/String;");
  jstring result = (jstring)g_jniEnv->CallStaticObjectMethod(cls, ffiLogicTest);
  return CopyJavaStringResult(result);
}

int FfiGetStatusBarHeight() {
  if (g_javaVm == nullptr) {
    LOGE("JavaVM not initialized");
    return 0;
  }
  jclass cls = (jclass)g_cls;
  jmethodID method =
      g_jniEnv->GetStaticMethodID(cls, "getStatusBarHeight", "()I");
  if (method == nullptr) {
    LOGE("getStatusBarHeight method not found");
    return 0;
  }
  return g_jniEnv->CallStaticIntMethod(cls, method);
}

int FfiGetNavigationBarHeight() {
  if (g_javaVm == nullptr) {
    LOGE("JavaVM not initialized");
    return 0;
  }
  jclass cls = (jclass)g_cls;
  jmethodID method =
      g_jniEnv->GetStaticMethodID(cls, "getNavigationBarHeight", "()I");
  if (method == nullptr) {
    LOGE("getNavigationBarHeight method not found");
    return 0;
  }
  return g_jniEnv->CallStaticIntMethod(cls, method);
}

void FfiFreeString(const char *str) {
  free((void *)str);
}
