# ifndef SELINE_READ_H
# define SELINE_READ_H

#include <jni.h>

extern "C" {
void InitJni(JNIEnv *env);
const char *FfiLogicTest(void);
int FfiGetStatusBarHeight(void);
int FfiGetNavigationBarHeight(void);
void FfiFreeString(const char *str);
}

# endif
