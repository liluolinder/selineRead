#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${CANGHUI_ANDROID_OUTPUT:-/private/tmp/canghui-android-native-surface}"
REQUIRE_CANGJIE=false

if [[ "${1:-}" == "--require-cangjie" ]]; then
    REQUIRE_CANGJIE=true
elif [[ -n "${1:-}" ]]; then
    echo "usage: $0 [--require-cangjie]" >&2
    exit 64
fi

"${ROOT_DIR}/scripts/build-android-native-surface.sh" "${OUTPUT_DIR}"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
SDK_ROOT="${SDK_ROOT%/}"
if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    NDK_ROOT="${ANDROID_NDK_ROOT%/}"
else
    NDK_ROOT=""
    for candidate in "${SDK_ROOT}"/ndk/*; do
        if [[ -d "${candidate}" && "${candidate}" > "${NDK_ROOT}" ]]; then
            NDK_ROOT="${candidate}"
        fi
    done
fi

PREBUILT_ROOT=""
for candidate in \
    "${NDK_ROOT}/toolchains/llvm/prebuilt/darwin-arm64" \
    "${NDK_ROOT}/toolchains/llvm/prebuilt/darwin-x86_64" \
    "${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64"; do
    if [[ -x "${candidate}/bin/llvm-nm" ]]; then
        PREBUILT_ROOT="${candidate}"
        break
    fi
done
if [[ -z "${PREBUILT_ROOT}" ]]; then
    echo "error: LLVM inspection tools were not found in the selected NDK" >&2
    exit 2
fi

EXPECTED_SYMBOLS=(
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeCreate
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeAttachSurface
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeDetachSurface
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeDestroy
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeGeneration
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeWidth
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeHeight
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeRender
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativePointerEvent
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeKeyEvent
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeImeEvent
    Java_dev_canghui_android_CangHuiNativeSurfaceHost_nativeReceipt
)

for abi in arm64-v8a x86_64; do
    library="${OUTPUT_DIR}/native/${abi}/libcanghui_android_surface.so"
    [[ -f "${library}" ]] || { echo "error: missing ${library}" >&2; exit 1; }
    header="$("${PREBUILT_ROOT}/bin/llvm-readelf" -h "${library}")"
    expected_machine="AArch64"
    if [[ "${abi}" == "x86_64" ]]; then
        expected_machine="Advanced Micro Devices X86-64"
    fi
    if [[ "${header}" != *"Machine:"*"${expected_machine}"* ]]; then
        echo "error: ${abi} library has the wrong ELF machine" >&2
        exit 1
    fi
    dynamic="$("${PREBUILT_ROOT}/bin/llvm-readelf" -d "${library}")"
    if [[ "${dynamic}" == *"libc++_shared.so"* ]]; then
        echo "error: ${abi} unexpectedly depends on libc++_shared.so" >&2
        exit 1
    fi
    symbols="$("${PREBUILT_ROOT}/bin/llvm-nm" -D --defined-only "${library}")"
    for expected in "${EXPECTED_SYMBOLS[@]}"; do
        if [[ "${symbols}" != *" ${expected}"* ]]; then
            echo "error: ${abi} is missing JNI export ${expected}" >&2
            exit 1
        fi
    done
    echo "android.native_surface.${abi}=ready library=${library}"
done

CLASS_FILE="${OUTPUT_DIR}/java/dev/canghui/android/CangHuiNativeSurfaceHost.class"
[[ -f "${CLASS_FILE}" ]] || { echo "error: Java host class was not compiled" >&2; exit 1; }
ACTIVITY_CLASS_FILE="${OUTPUT_DIR}/java/dev/canghui/android/CangHuiSurfaceActivity.class"
[[ -f "${ACTIVITY_CLASS_FILE}" ]] || { echo "error: Java Activity host class was not compiled" >&2; exit 1; }
VIEW_CLASS_FILE="${OUTPUT_DIR}/java/dev/canghui/android/CangHuiAndroidView.class"
[[ -f "${VIEW_CLASS_FILE}" ]] || { echo "error: Java input/IME view class was not compiled" >&2; exit 1; }
SYSTEM_BARS_CLASS_FILE="${OUTPUT_DIR}/java/dev/canghui/android/CangHuiSystemBarsMode.class"
[[ -f "${SYSTEM_BARS_CLASS_FILE}" ]] || { echo "error: Java system-bars API class was not compiled" >&2; exit 1; }
JNI_HEADER="${OUTPUT_DIR}/jni/dev_canghui_android_CangHuiNativeSurfaceHost.h"
[[ -f "${JNI_HEADER}" ]] || { echo "error: javac did not generate the JNI contract header" >&2; exit 1; }
echo "android.java_surface_host=ready class=${CLASS_FILE}"

ACTIVITY_BYTECODE="$(javap -classpath "${OUTPUT_DIR}/java" -c -p \
    dev.canghui.android.CangHuiSurfaceActivity)"
for lifecycle_method in onCreate onStart onStop onDestroy setSystemBarsMode showInputMethod hideInputMethod; do
    if [[ "${ACTIVITY_BYTECODE}" != *"${lifecycle_method}"* ]]; then
        echo "error: Activity host bytecode is missing ${lifecycle_method}" >&2
        exit 1
    fi
done
for lifecycle_call in \
    'CangHuiNativeSurfaceHost.bind' \
    'CangHuiNativeSurfaceHost.unbind' \
    'CangHuiNativeSurfaceHost.close'; do
    if [[ "${ACTIVITY_BYTECODE}" != *"${lifecycle_call}"* ]]; then
        echo "error: Activity host bytecode is missing ${lifecycle_call}" >&2
        exit 1
    fi
done
echo "android.activity_surface_lifecycle=ready class=${ACTIVITY_CLASS_FILE}"

VIEW_BYTECODE="$(javap -classpath "${OUTPUT_DIR}/java" -c -p \
    dev.canghui.android.CangHuiAndroidView)"
for input_method in onTouchEvent onKeyDown onKeyUp onCreateInputConnection showInputMethod hideInputMethod; do
    if [[ "${VIEW_BYTECODE}" != *"${input_method}"* ]]; then
        echo "error: Android input view bytecode is missing ${input_method}" >&2
        exit 1
    fi
done
IME_BYTECODE="$(javap -classpath "${OUTPUT_DIR}/java" -c -p \
    'dev.canghui.android.CangHuiAndroidView$CangHuiInputConnection')"
for ime_method in setComposingText commitText deleteSurroundingText finishComposingText setSelection; do
    if [[ "${IME_BYTECODE}" != *"${ime_method}"* ]]; then
        echo "error: Android IME bridge bytecode is missing ${ime_method}" >&2
        exit 1
    fi
done
echo "android.input_ime_bridge=ready class=${VIEW_CLASS_FILE}"
echo "android.system_bars_api=ready class=${SYSTEM_BARS_CLASS_FILE}"
if [[ -n "${JAVA_HOME:-}" && ! -d "${JAVA_HOME}" ]]; then
    echo "android.gradle_environment=degraded reason=JAVA_HOME-not-directory value=${JAVA_HOME}"
else
    echo "android.gradle_environment=ready java_home=${JAVA_HOME:-command-path}"
fi

CANGJIE_ROOT="${CANGJIE_HOME:-}"
CANGJIE_MODULES=""
CANGJIE_RUNTIME=""
if [[ -n "${CANGJIE_ROOT}" ]]; then
    for candidate in "${CANGJIE_ROOT}"/modules/linux_android*_aarch64_cjnative; do
        if [[ -d "${candidate}" ]]; then
            CANGJIE_MODULES="${candidate}"
            break
        fi
    done
    for candidate in "${CANGJIE_ROOT}"/runtime/lib/linux_android*_aarch64_cjnative; do
        if [[ -d "${candidate}" ]]; then
            CANGJIE_RUNTIME="${candidate}"
            break
        fi
    done
fi

if [[ -n "${CANGJIE_MODULES}" && -n "${CANGJIE_RUNTIME}" ]]; then
    echo "cangjie.android=ready modules=${CANGJIE_MODULES} runtime=${CANGJIE_RUNTIME}"
    echo "android.first_slice=ready cangjie_bridge=available"
    exit 0
fi

echo "cangjie.android=blocked reason=missing-android-cross-sdk root=${CANGJIE_ROOT:-unset}"
echo "required.modules=modules/linux_android_aarch64_cjnative"
echo "required.runtime=runtime/lib/linux_android*_aarch64_cjnative"
if [[ "${REQUIRE_CANGJIE}" == true ]]; then
    echo "android.first_slice=partial cangjie_bridge=blocked"
    exit 2
fi

echo "android.first_slice=ready-ndk-only cangjie_bridge=blocked"
