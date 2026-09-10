#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-/private/tmp/canghui-android-native-surface}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ -z "${SDK_ROOT}" ]]; then
    echo "error: set ANDROID_SDK_ROOT or ANDROID_HOME" >&2
    exit 2
fi
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

if [[ -z "${NDK_ROOT}" || ! -f "${NDK_ROOT}/build/cmake/android.toolchain.cmake" ]]; then
    echo "error: Android NDK with CMake toolchain was not found" >&2
    exit 2
fi

ANDROID_JAR=""
for candidate in "${SDK_ROOT}"/platforms/android-*/android.jar; do
    if [[ -f "${candidate}" && "${candidate}" > "${ANDROID_JAR}" ]]; then
        ANDROID_JAR="${candidate}"
    fi
done
if [[ -z "${ANDROID_JAR}" ]]; then
    echo "error: no Android platform android.jar was found" >&2
    exit 2
fi

command -v cmake >/dev/null || { echo "error: cmake is required" >&2; exit 2; }
command -v ninja >/dev/null || { echo "error: ninja is required" >&2; exit 2; }
command -v javac >/dev/null || { echo "error: javac is required" >&2; exit 2; }

mkdir -p "${OUTPUT_DIR}/java" "${OUTPUT_DIR}/jni"
javac -Xlint:-options -source 8 -target 8 \
    -classpath "${ANDROID_JAR}" \
    -d "${OUTPUT_DIR}/java" \
    -h "${OUTPUT_DIR}/jni" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiNativeSurfaceHost.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiAndroidView.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiSystemBarsMode.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiSurfaceActivity.java"

for abi in arm64-v8a x86_64; do
    build_dir="${OUTPUT_DIR}/native/${abi}"
    cmake -Wno-deprecated -S "${ROOT_DIR}/platform/android" -B "${build_dir}" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="${abi}" \
        -DANDROID_PLATFORM=android-26 \
        -DANDROID_STL=c++_static \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build "${build_dir}"
done

printf 'android_sdk=%s\nandroid_ndk=%s\nandroid_jar=%s\n' \
    "${SDK_ROOT}" "${NDK_ROOT}" "${ANDROID_JAR}" \
    > "${OUTPUT_DIR}/build-receipt.txt"

echo "android-native-surface-build=pass"
echo "output=${OUTPUT_DIR}"
