#include "seline_read.h"
#include <android/log.h>
#include <cstdlib>
#include <cstring>
#include <jni.h>

JavaVM *g_javaVm = nullptr;
jobject g_cls = nullptr;
jobject g_avoidCls = nullptr;

#define LOGTAG "SELINE_READ_JNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOGTAG, __VA_ARGS__)

static JNIEnv *GetJniEnv() {
  if (g_javaVm == nullptr) {
    return nullptr;
  }
  JNIEnv *env = nullptr;
  if (g_javaVm->GetEnv((void **)&env, JNI_VERSION_1_6) != JNI_OK) {
    if (g_javaVm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
      LOGE("AttachCurrentThread failed");
      return nullptr;
    }
  }
  return env;
}

static const char *CopyJavaStringResult(JNIEnv *env, jstring str) {
  if (str == nullptr) {
    return nullptr;
  }

  const char *chars = env->GetStringUTFChars(str, nullptr);
  if (chars == nullptr) {
    env->DeleteLocalRef(str);
    return nullptr;
  }

  char *copy = strdup(chars);
  env->ReleaseStringUTFChars(str, chars);
  env->DeleteLocalRef(str);
  return copy;
}

jint JNI_OnLoad(JavaVM *vm, void *reserved) {
  g_javaVm = vm;

  JNIEnv *env = nullptr;
  if (vm->GetEnv((void **)&env, JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }

  jclass myClass =
      env->FindClass("seline/book/read/seline_read");
  g_cls = env->NewGlobalRef(myClass);
  if (g_cls == nullptr) {
    LOGE("class not found.");
    return JNI_ERR;
  }

  jclass avoidClass =
      env->FindClass("seline/book/read/avoidSafeArea");
  g_avoidCls = env->NewGlobalRef(avoidClass);
  if (g_avoidCls == nullptr) {
    LOGE("avoidSafeArea class not found.");
    return JNI_ERR;
  }

  return JNI_VERSION_1_6;
}

const char *FfiLogicTest() {
  JNIEnv *env = GetJniEnv();
  if (env == nullptr || g_cls == nullptr) {
    LOGE("JNI not initialized");
    return nullptr;
  }
  jclass cls = (jclass)g_cls;
  jmethodID ffiLogicTest =
      env->GetStaticMethodID(cls, "logicTest", "()Ljava/lang/String;");
  jstring result = (jstring)env->CallStaticObjectMethod(cls, ffiLogicTest);
  return CopyJavaStringResult(env, result);
}

void FfiFreeString(const char *str) {
  free((void *)str);
}

int FfiGetStatusBarHeight() {
  JNIEnv *env = GetJniEnv();
  if (env == nullptr || g_avoidCls == nullptr) {
    LOGE("JNI not initialized");
    return 0;
  }
  jclass cls = (jclass)g_avoidCls;
  jmethodID method =
      env->GetStaticMethodID(cls, "getStatusBarHeight", "()I");
  if (method == nullptr) {
    LOGE("getStatusBarHeight method not found");
    return 0;
  }
  return env->CallStaticIntMethod(cls, method);
}

int FfiGetNavigationBarHeight() {
  JNIEnv *env = GetJniEnv();
  if (env == nullptr || g_avoidCls == nullptr) {
    LOGE("JNI not initialized");
    return 0;
  }
  jclass cls = (jclass)g_avoidCls;
  jmethodID method =
      env->GetStaticMethodID(cls, "getNavigationBarHeight", "()I");
  if (method == nullptr) {
    LOGE("getNavigationBarHeight method not found");
    return 0;
  }
  return env->CallStaticIntMethod(cls, method);
}
