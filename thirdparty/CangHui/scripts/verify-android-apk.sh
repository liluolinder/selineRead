#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
DEVICE_SERIAL=""

if [[ "${1:-}" == "--device" && -n "${2:-}" && -z "${3:-}" ]]; then
    DEVICE_SERIAL="${2}"
elif [[ -n "${1:-}" ]]; then
    echo "usage: $0 [--device ADB_SERIAL]" >&2
    exit 64
fi

if [[ -z "${SDK_ROOT}" ]]; then
    echo "error: set ANDROID_SDK_ROOT or ANDROID_HOME" >&2
    exit 2
fi
SDK_ROOT="${SDK_ROOT%/}"

OUTPUT_DIR="${CANGHUI_ANDROID_APK_OUTPUT:-$(mktemp -d /private/tmp/canghui-android-apk-verify.XXXXXX)}"
"${ROOT_DIR}/scripts/build-android-apk.sh" "${OUTPUT_DIR}"
APK="${OUTPUT_DIR}/canghui-android-probe.apk"

BUILD_TOOLS_ROOT=""
for candidate in "${SDK_ROOT}"/build-tools/*; do
    if [[ -x "${candidate}/aapt2" \
          && -x "${candidate}/apksigner" \
          && "${candidate}" > "${BUILD_TOOLS_ROOT}" ]]; then
        BUILD_TOOLS_ROOT="${candidate}"
    fi
done

BADGING="$("${BUILD_TOOLS_ROOT}/aapt2" dump badging "${APK}")"
for expected in \
    "package: name='dev.canghui.android.probe'" \
    "minSdkVersion:'26'" \
    "targetSdkVersion:'35'" \
    "native-code: 'arm64-v8a' 'x86_64'"; do
    if [[ "${BADGING}" != *"${expected}"* ]]; then
        echo "error: APK badging is missing ${expected}" >&2
        exit 1
    fi
done

APK_LIST="$(unzip -l "${APK}")"
for expected_entry in \
    classes.dex \
    lib/arm64-v8a/libcanghui_android_surface.so \
    lib/x86_64/libcanghui_android_surface.so; do
    if [[ "${APK_LIST}" != *"${expected_entry}"* ]]; then
        echo "error: APK is missing ${expected_entry}" >&2
        exit 1
    fi
done
"${BUILD_TOOLS_ROOT}/apksigner" verify --verbose "${APK}" >/dev/null
echo "android.apk.static=ready apk=${APK}"

if [[ -z "${DEVICE_SERIAL}" ]]; then
    echo "android.apk.device=not-requested"
    exit 0
fi

command -v adb >/dev/null || { echo "error: adb is required" >&2; exit 2; }
STATE="$(adb -s "${DEVICE_SERIAL}" get-state)"
if [[ "${STATE}" != "device" ]]; then
    echo "error: ADB lease ${DEVICE_SERIAL} is not online: ${STATE}" >&2
    exit 1
fi

MODEL="$(adb -s "${DEVICE_SERIAL}" shell getprop ro.product.model | tr -d '\r')"
API_LEVEL="$(adb -s "${DEVICE_SERIAL}" shell getprop ro.build.version.sdk | tr -d '\r')"
ABI_LIST="$(adb -s "${DEVICE_SERIAL}" shell getprop ro.product.cpu.abilist | tr -d '\r')"
if [[ "${ABI_LIST}" != *"arm64-v8a"* ]]; then
    echo "error: leased device does not support arm64-v8a: ${ABI_LIST}" >&2
    exit 1
fi

PACKAGE="dev.canghui.android.probe"
COMPONENT="${PACKAGE}/dev.canghui.android.CangHuiProbeActivity"
EXTRA="dev.canghui.android.extra.PROBE_IME_TEXT"

adb -s "${DEVICE_SERIAL}" logcat -c
if [[ "$(adb -s "${DEVICE_SERIAL}" shell pm path "${PACKAGE}" | tr -d '\r')" == package:* ]]; then
    adb -s "${DEVICE_SERIAL}" uninstall "${PACKAGE}"
fi
adb -s "${DEVICE_SERIAL}" install --no-incremental -r "${APK}"
adb -s "${DEVICE_SERIAL}" shell am force-stop "${PACKAGE}"
START_RECEIPT="$(adb -s "${DEVICE_SERIAL}" shell am start -W \
    -n "${COMPONENT}" --es "${EXTRA}" CangHuiIME42)"
if [[ "${START_RECEIPT}" != *"Status: ok"* ]]; then
    echo "error: Activity launch did not report Status: ok" >&2
    echo "${START_RECEIPT}" >&2
    exit 1
fi

APP_PID=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    APP_PID="$(adb -s "${DEVICE_SERIAL}" shell pidof "${PACKAGE}" | tr -d '\r')"
    if [[ -n "${APP_PID}" ]]; then
        break
    fi
    sleep 1
done
if [[ -z "${APP_PID}" ]]; then
    echo "error: launched Android probe process is not alive" >&2
    exit 1
fi

sleep 2
adb -s "${DEVICE_SERIAL}" shell input tap 540 500
adb -s "${DEVICE_SERIAL}" shell input swipe 260 620 820 620 250
adb -s "${DEVICE_SERIAL}" shell input text Android42
adb -s "${DEVICE_SERIAL}" shell input keyevent 29
adb -s "${DEVICE_SERIAL}" shell input keyevent 66
sleep 2

LOGCAT="$(adb -s "${DEVICE_SERIAL}" logcat -d -v brief \
    -s CangHuiAndroid:I '*:S')"
for expected_log in \
    surface_attached \
    'render generation=' \
    'input_connection=created' \
    'probe_ime_committed' \
    'probe_ime_hidden=true' \
    'ime_hide_requested=' \
    'probe_multitouch=dispatched pointers=2' \
    'system_bars=IMMERSIVE_STICKY' \
    'pointer serial=' \
    'pointers=2' \
    'max=2' \
    'key serial=' \
    'ime serial='; do
    if [[ "${LOGCAT}" != *"${expected_log}"* ]]; then
        echo "error: device log is missing ${expected_log}" >&2
        echo "${LOGCAT}" >&2
        exit 1
    fi
done
IME_SHOW_COUNT="$(printf '%s\n' "${LOGCAT}" | grep -c 'ime_show_requested=' || true)"
if [[ "${IME_SHOW_COUNT}" != "1" ]]; then
    echo "error: IME must be shown exactly once by the explicit probe; observed ${IME_SHOW_COUNT}" >&2
    exit 1
fi
for counter in frame pointer key ime; do
    if [[ ! "${LOGCAT}" =~ ${counter}=[1-9][0-9]* ]]; then
        echo "error: device log never reported a non-zero ${counter} count" >&2
        exit 1
    fi
done

PACKAGE_PATH="$(adb -s "${DEVICE_SERIAL}" shell pm path "${PACKAGE}" | tr -d '\r')"
RESUMED="$(adb -s "${DEVICE_SERIAL}" shell dumpsys activity activities \
    | grep -m 1 -E 'mResumedActivity|topResumedActivity|ResumedActivity:')"
if [[ "${PACKAGE_PATH}" != package:* || "${RESUMED}" != *"${PACKAGE}"* ]]; then
    echo "error: installed package is not the resumed Activity" >&2
    exit 1
fi

adb -s "${DEVICE_SERIAL}" exec-out screencap -p \
    > "${OUTPUT_DIR}/device-screen.png"
if [[ ! -s "${OUTPUT_DIR}/device-screen.png" ]]; then
    echo "error: device screen capture is empty" >&2
    exit 1
fi

{
    printf 'serial=%s\nmodel=%s\napi=%s\nabis=%s\npid=%s\n' \
        "${DEVICE_SERIAL}" "${MODEL}" "${API_LEVEL}" "${ABI_LIST}" "${APP_PID}"
    printf 'package_path=%s\nresumed=%s\n' "${PACKAGE_PATH}" "${RESUMED}"
    printf '%s\n' "${START_RECEIPT}"
    printf '%s\n' "${LOGCAT}"
} > "${OUTPUT_DIR}/device-receipt.txt"

echo "android.apk.device=ready serial=${DEVICE_SERIAL} model=${MODEL} api=${API_LEVEL} pid=${APP_PID}"
echo "android.apk.device_receipt=${OUTPUT_DIR}/device-receipt.txt"
echo "android.apk.device_screen=${OUTPUT_DIR}/device-screen.png"
