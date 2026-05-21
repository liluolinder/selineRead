# ifndef SELINE_READ_H
# define SELINE_READ_H

#include <jni.h>

extern "C" {
void InitJni(JNIEnv *env);
const char *FfiLogicTest(void);
void FfiFreeString(const char *str);
int FfiGetStatusBarHeight(void);
int FfiGetNavigationBarHeight(void);
}

# endif
