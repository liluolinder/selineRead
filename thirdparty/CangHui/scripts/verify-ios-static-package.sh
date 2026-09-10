#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-simulator}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ROOT="${2:-${PROJECT_ROOT}/target/ios-static-package-probe}"
CANGJIE_IOS_HOME="${CANGJIE_IOS_HOME:-${CANGHUI_IOS_HOME:-${CANGJIE_HOME:-}}}"
DEPLOYMENT_TARGET="${CANGHUI_IOS_DEPLOYMENT_TARGET:-13.0}"
EXECUTABLE_NAME="CangHuiBootstrapProbe"
EXPECTED_RESULT="CANGHUI_IOS_SURFACE result passed=1"
COMPILED_APP_DIR=""

# shellcheck source=scripts/lib/ios-provisioning-profile.sh
source "${PROJECT_ROOT}/scripts/lib/ios-provisioning-profile.sh"

if [[ -z "${CANGJIE_IOS_HOME}" ]]; then
    printf 'Set CANGJIE_IOS_HOME to a Cangjie SDK with iOS targets.\n' >&2
    exit 1
fi

for command_name in xcrun plutil; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf '%s is required.\n' "${command_name}" >&2
        exit 1
    fi
done

mkdir -p "${OUTPUT_ROOT}"

runtime_archive() {
    local runtime_dir="$1"
    local name="$2"
    local path="${runtime_dir}/${name}"
    if [[ ! -f "${path}" ]]; then
        printf 'Required Cangjie runtime input is missing: %s\n' "${path}" >&2
        exit 1
    fi
    printf '%s\n' "${path}"
}

build_static_libraries() {
    CANGJIE_HOME="${CANGJIE_IOS_HOME}" \
        "${PROJECT_ROOT}/scripts/build-ios-host-staticlibs.sh" "$1" \
        "${OUTPUT_ROOT}/staticlibs"
}

compile_probe_app() {
    local kind="$1"
    local sdk="$2"
    local runtime_name="$3"
    local host_archive="$4"
    local bundle_id="$5"
    local build_dir="${OUTPUT_ROOT}/${kind}"
    local app_dir="${build_dir}/${EXECUTABLE_NAME}.app"
    local runtime_dir="${CANGJIE_IOS_HOME}/lib/${runtime_name}"
    local clang
    local sdk_path
    local minimum_flag

    clang="$(xcrun --sdk "${sdk}" --find clang)"
    sdk_path="$(xcrun --sdk "${sdk}" --show-sdk-path)"
    if [[ "${kind}" == "simulator" ]]; then
        minimum_flag="-mios-simulator-version-min=${DEPLOYMENT_TARGET}"
    else
        minimum_flag="-miphoneos-version-min=${DEPLOYMENT_TARGET}"
    fi

    rm -rf "${build_dir}"
    mkdir -p "${app_dir}"
    mkdir -p "${build_dir}/modules"
    cp "${PROJECT_ROOT}/platform/ios/probe/Info.plist" "${app_dir}/Info.plist"
    plutil -replace CFBundleIdentifier -string "${bundle_id}" "${app_dir}/Info.plist"

    "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
        -fobjc-arc -fblocks -fmodules \
        -fmodules-cache-path="${build_dir}/modules" \
        -I "${PROJECT_ROOT}/platform/ios/include" \
        -c "${PROJECT_ROOT}/platform/ios/bootstrap/CangHuiRuntimeBootstrap.m" \
        -o "${build_dir}/CangHuiRuntimeBootstrap.o"
    for source in \
        CangHuiUIKitHostView.m \
        CangHuiMetalSurfaceView.m \
        CangHuiDisplayLinkDriver.m \
        CangHuiNativeSceneSurfaceView.m
    do
        "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
            -fobjc-arc -fblocks -fmodules \
            -fmodules-cache-path="${build_dir}/modules" \
            -I "${PROJECT_ROOT}/platform/ios/include" \
            -c "${PROJECT_ROOT}/platform/ios/runtime/${source}" \
            -o "${build_dir}/${source%.m}.o"
    done
    "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
        -fobjc-arc -fblocks -fmodules \
        -fmodules-cache-path="${build_dir}/modules" \
        -I "${PROJECT_ROOT}/platform/ios/include" \
        -c "${PROJECT_ROOT}/platform/ios/probe/AppDelegate.m" \
        -o "${build_dir}/AppDelegate.o"

    "${clang}" -arch arm64 "${minimum_flag}" -isysroot "${sdk_path}" \
        "${build_dir}/AppDelegate.o" \
        "${build_dir}/CangHuiRuntimeBootstrap.o" \
        "${build_dir}/CangHuiUIKitHostView.o" \
        "${build_dir}/CangHuiMetalSurfaceView.o" \
        "${build_dir}/CangHuiDisplayLinkDriver.o" \
        "${build_dir}/CangHuiNativeSceneSurfaceView.o" \
        "$(runtime_archive "${runtime_dir}" section.o)" \
        "$(runtime_archive "${runtime_dir}" cjstart.o)" \
        "${host_archive}" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-collection.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-math.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-sync.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-time.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-binary.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-convert.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-io.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-std-core.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-runtime.a)" \
        "$(runtime_archive "${runtime_dir}" libboundscheck-static.a)" \
        "$(runtime_archive "${runtime_dir}" libcangjie-thread.a)" \
        -framework UIKit -framework Foundation -framework QuartzCore -framework Metal -lc++ \
        -Wl,-no_compact_unwind \
        -o "${app_dir}/${EXECUTABLE_NAME}"

    COMPILED_APP_DIR="${app_dir}"
}

wait_for_result() {
    local log_file="$1"
    local launch_pid="$2"
    local attempts=0

    while (( attempts < 200 )); do
        if grep -Fq "${EXPECTED_RESULT}" "${log_file}"; then
            kill "${launch_pid}" >/dev/null 2>&1 || true
            wait "${launch_pid}" >/dev/null 2>&1 || true
            cat "${log_file}"
            printf 'CangHui iOS static-package probe passed.\n'
            return 0
        fi
        if ! kill -0 "${launch_pid}" >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
        attempts=$((attempts + 1))
    done

    kill "${launch_pid}" >/dev/null 2>&1 || true
    wait "${launch_pid}" >/dev/null 2>&1 || true
    cat "${log_file}" >&2
    printf 'Expected probe result was not observed: %s\n' "${EXPECTED_RESULT}" >&2
    return 1
}

resolve_simulator_device() {
    local requested="${CANGHUI_IOS_SIMULATOR_DEVICE:-booted}"
    local selected="${requested}"
    local available_devices

    available_devices="$(xcrun simctl list devices available)"
    if [[ "${requested}" == "booted" && "${available_devices}" != *'(Booted)'* ]]; then
        selected="$(
            awk -F '[()]' \
                '/^[[:space:]]+.*\([0-9A-F-]+\) \((Shutdown|Booted)\)/ { print $2; exit }' \
                <<< "${available_devices}"
        )"
        if [[ -z "${selected}" ]]; then
            printf 'No available iOS simulator was found.\n' >&2
            return 1
        fi
    fi

    if [[ "${selected}" != "booted" ]]; then
        xcrun simctl boot "${selected}" >/dev/null 2>&1 || true
        xcrun simctl bootstatus "${selected}" -b >&2
    fi
    printf '%s\n' "${selected}"
}

verify_simulator() {
    local bundle_id="${CANGHUI_IOS_SIMULATOR_BUNDLE_ID:-dev.canghui.bootstrap.probe}"
    local device
    local app_dir
    local log_file="${OUTPUT_ROOT}/simulator-console.log"

    build_static_libraries simulator
    device="$(resolve_simulator_device)"
    compile_probe_app simulator iphonesimulator \
        ios_simulator_aarch64_cjnative \
        "${OUTPUT_ROOT}/staticlibs/libcanghui_host_ios_simulator.a" \
        "${bundle_id}"
    app_dir="${COMPILED_APP_DIR}"
    xcrun simctl install "${device}" "${app_dir}"
    : > "${log_file}"
    xcrun simctl launch --terminate-running-process --console \
        "${device}" "${bundle_id}" >"${log_file}" 2>&1 &
    wait_for_result "${log_file}" "$!"
}

verify_device() {
    : "${CANGHUI_IOS_DEVICE:?set CANGHUI_IOS_DEVICE to a CoreDevice identifier, UDID or name}"
    : "${CANGHUI_IOS_BUNDLE_ID:?set CANGHUI_IOS_BUNDLE_ID to the signed application identifier}"
    : "${CANGHUI_IOS_CODESIGN_IDENTITY:?set CANGHUI_IOS_CODESIGN_IDENTITY to an Apple Development identity}"
    : "${CANGHUI_IOS_PROVISIONING_PROFILE:?set CANGHUI_IOS_PROVISIONING_PROFILE to a .mobileprovision path}"

    local app_dir
    local build_dir="${OUTPUT_ROOT}/device"
    local profile_plist="${build_dir}/profile.plist"
    local entitlements="${build_dir}/entitlements.plist"
    local application_identifier
    local allowed_bundle
    local log_file="${OUTPUT_ROOT}/device-console.log"

    build_static_libraries device
    compile_probe_app device iphoneos ios_aarch64_cjnative \
        "${OUTPUT_ROOT}/staticlibs/libcanghui_host_ios.a" \
        "${CANGHUI_IOS_BUNDLE_ID}"
    app_dir="${COMPILED_APP_DIR}"

    decode_ios_provisioning_profile \
        "${CANGHUI_IOS_PROVISIONING_PROFILE}" "${profile_plist}"
    printf 'CangHui provisioning profile decoder: %s\n' \
        "${CANGHUI_IOS_PROFILE_DECODER_USED}"
    plutil -extract Entitlements xml1 -o "${entitlements}" "${profile_plist}"
    plutil -remove keychain-access-groups "${entitlements}" >/dev/null 2>&1 || true
    application_identifier="$(plutil -extract Entitlements.application-identifier raw -o - "${profile_plist}")"
    allowed_bundle="${application_identifier#*.}"
    if [[ "${allowed_bundle}" == *'*' ]]; then
        if [[ "${CANGHUI_IOS_BUNDLE_ID}" != "${allowed_bundle%\*}"* ]]; then
            printf 'Bundle id %s is outside provisioning profile %s.\n' \
                "${CANGHUI_IOS_BUNDLE_ID}" "${allowed_bundle}" >&2
            exit 1
        fi
    elif [[ "${CANGHUI_IOS_BUNDLE_ID}" != "${allowed_bundle}" ]]; then
        printf 'Bundle id %s does not match provisioning profile %s.\n' \
            "${CANGHUI_IOS_BUNDLE_ID}" "${allowed_bundle}" >&2
        exit 1
    fi

    cp "${CANGHUI_IOS_PROVISIONING_PROFILE}" "${app_dir}/embedded.mobileprovision"
    codesign --force --sign "${CANGHUI_IOS_CODESIGN_IDENTITY}" \
        --entitlements "${entitlements}" --generate-entitlement-der \
        --timestamp=none "${app_dir}"
    codesign --verify --deep --strict "${app_dir}"
    xcrun devicectl device install app --device "${CANGHUI_IOS_DEVICE}" "${app_dir}"

    : > "${log_file}"
    xcrun devicectl device process launch \
        --device "${CANGHUI_IOS_DEVICE}" \
        --terminate-existing --console --timeout 25 \
        "${CANGHUI_IOS_BUNDLE_ID}" >"${log_file}" 2>&1 &
    wait_for_result "${log_file}" "$!"
}

case "${MODE}" in
    simulator)
        verify_simulator
        ;;
    device)
        verify_device
        ;;
    all)
        verify_simulator
        verify_device
        ;;
    *)
        printf 'usage: %s [simulator|device|all] [output-dir]\n' "$0" >&2
        exit 2
        ;;
esac
