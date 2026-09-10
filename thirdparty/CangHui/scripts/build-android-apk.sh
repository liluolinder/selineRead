#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$(mktemp -d /private/tmp/canghui-android-apk.XXXXXX)}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ -z "${SDK_ROOT}" ]]; then
    echo "error: set ANDROID_SDK_ROOT or ANDROID_HOME" >&2
    exit 2
fi
SDK_ROOT="${SDK_ROOT%/}"

if [[ -e "${OUTPUT_DIR}" && -n "$(ls -A "${OUTPUT_DIR}" 2>/dev/null)" ]]; then
    echo "error: APK output directory must be absent or empty: ${OUTPUT_DIR}" >&2
    exit 2
fi
mkdir -p "${OUTPUT_DIR}"

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

BUILD_TOOLS_ROOT=""
for candidate in "${SDK_ROOT}"/build-tools/*; do
    if [[ -x "${candidate}/aapt2" \
          && -x "${candidate}/d8" \
          && -x "${candidate}/zipalign" \
          && -x "${candidate}/apksigner" \
          && "${candidate}" > "${BUILD_TOOLS_ROOT}" ]]; then
        BUILD_TOOLS_ROOT="${candidate}"
    fi
done
if [[ -z "${BUILD_TOOLS_ROOT}" ]]; then
    echo "error: complete Android build-tools were not found" >&2
    exit 2
fi

for command_name in javac jar keytool zip shasum; do
    command -v "${command_name}" >/dev/null \
        || { echo "error: ${command_name} is required" >&2; exit 2; }
done

NATIVE_OUTPUT="${OUTPUT_DIR}/native-build"
ANDROID_SDK_ROOT="${SDK_ROOT}" \
    "${ROOT_DIR}/scripts/build-android-native-surface.sh" "${NATIVE_OUTPUT}"

CLASSES_DIR="${OUTPUT_DIR}/classes"
JNI_DIR="${OUTPUT_DIR}/jni"
DEX_DIR="${OUTPUT_DIR}/dex"
PACKAGE_DIR="${OUTPUT_DIR}/package"
mkdir -p "${CLASSES_DIR}" "${JNI_DIR}" "${DEX_DIR}" \
    "${PACKAGE_DIR}/lib/arm64-v8a" "${PACKAGE_DIR}/lib/x86_64"

javac -Xlint:-options -source 8 -target 8 \
    -classpath "${ANDROID_JAR}" \
    -d "${CLASSES_DIR}" \
    -h "${JNI_DIR}" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiNativeSurfaceHost.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiAndroidView.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiSystemBarsMode.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiSurfaceActivity.java" \
    "${ROOT_DIR}/platform/android/src/main/java/dev/canghui/android/CangHuiDrawIrView.java" \
    "${ROOT_DIR}/platform/android/src/probe/java/dev/canghui/android/CangHuiProbeActivity.java" \
    "${ROOT_DIR}/platform/android/src/probe/java/dev/canghui/android/CangHuiDrawIrDemoActivity.java"

jar cf "${OUTPUT_DIR}/classes.jar" -C "${CLASSES_DIR}" .
"${BUILD_TOOLS_ROOT}/d8" \
    --lib "${ANDROID_JAR}" \
    --min-api 26 \
    --output "${DEX_DIR}" \
    "${OUTPUT_DIR}/classes.jar"

UNSIGNED_APK="${OUTPUT_DIR}/canghui-android-probe-unsigned.apk"
ALIGNED_APK="${OUTPUT_DIR}/canghui-android-probe-aligned.apk"
SIGNED_APK="${OUTPUT_DIR}/canghui-android-probe.apk"

"${BUILD_TOOLS_ROOT}/aapt2" link \
    -I "${ANDROID_JAR}" \
    --manifest "${ROOT_DIR}/platform/android/AndroidManifest.xml" \
    --min-sdk-version 26 \
    --target-sdk-version 35 \
    -o "${UNSIGNED_APK}"

cp "${DEX_DIR}/classes.dex" "${PACKAGE_DIR}/classes.dex"
cp "${NATIVE_OUTPUT}/native/arm64-v8a/libcanghui_android_surface.so" \
    "${PACKAGE_DIR}/lib/arm64-v8a/libcanghui_android_surface.so"
cp "${NATIVE_OUTPUT}/native/x86_64/libcanghui_android_surface.so" \
    "${PACKAGE_DIR}/lib/x86_64/libcanghui_android_surface.so"
(
    cd "${PACKAGE_DIR}"
    zip -q -r "${UNSIGNED_APK}" classes.dex lib
)

"${BUILD_TOOLS_ROOT}/zipalign" -f -p 4 "${UNSIGNED_APK}" "${ALIGNED_APK}"

KEYSTORE="${OUTPUT_DIR}/canghui-android-probe.p12"
keytool -genkeypair \
    -keystore "${KEYSTORE}" \
    -storetype PKCS12 \
    -storepass android \
    -keypass android \
    -alias canghui-android-probe \
    -keyalg RSA \
    -keysize 2048 \
    -validity 3650 \
    -dname "CN=CangHui Android Adapter Probe,O=CangHui,C=CN" \
    -noprompt >/dev/null

"${BUILD_TOOLS_ROOT}/apksigner" sign \
    --ks "${KEYSTORE}" \
    --ks-key-alias canghui-android-probe \
    --ks-pass pass:android \
    --key-pass pass:android \
    --out "${SIGNED_APK}" \
    "${ALIGNED_APK}"
"${BUILD_TOOLS_ROOT}/apksigner" verify --verbose --print-certs "${SIGNED_APK}" \
    > "${OUTPUT_DIR}/signature-receipt.txt"
"${BUILD_TOOLS_ROOT}/aapt2" dump badging "${SIGNED_APK}" \
    > "${OUTPUT_DIR}/package-receipt.txt"
shasum -a 256 "${SIGNED_APK}" > "${OUTPUT_DIR}/sha256.txt"

printf 'android_sdk=%s\nandroid_build_tools=%s\nandroid_jar=%s\n' \
    "${SDK_ROOT}" "${BUILD_TOOLS_ROOT}" "${ANDROID_JAR}" \
    > "${OUTPUT_DIR}/build-receipt.txt"

echo "android.apk=ready package=dev.canghui.android.probe"
echo "android.apk.path=${SIGNED_APK}"
echo "android.apk.output=${OUTPUT_DIR}"
