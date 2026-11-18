#!/usr/bin/env bash
set -e

BUILD_CONFIGURATION_FAILED_EXIT_CODE=1
BUILD_ARTIFACT_NOT_FOUND_EXIT_CODE=1

# Recover CJMP_SDK_HOME before locating tools. Xcode invokes this script from a
# non-interactive shell where ~/.zshrc may be the only configured source.
if [[ -z "${CJMP_SDK_HOME:-}" && -f "${HOME}/.zshrc" && -x "/bin/zsh" ]]; then
    CJMP_SDK_HOME="$(/bin/zsh -ic 'print -r -- "${CJMP_SDK_HOME:-}"' 2>/dev/null | tail -n 1)"
    export CJMP_SDK_HOME
fi
if [[ -z "${CJMP_SDK_HOME:-}" ]]; then
    echo "error: CJMP_SDK_HOME is not set. Configure it in the build environment or ~/.zshrc." >&2
    exit 3
fi

# Script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
CJMP_TOOL_PATH="$CJMP_SDK_HOME/cjmp-tools"
# Keep helpers aligned with the Tools version that generated this build script.
active_tools_source_root="${KEELS_ACTIVE_TOOLS_SOURCE_ROOT:-$CJMP_TOOL_PATH/tools}"
BUILD_ARGS_PARSER="$active_tools_source_root/keels_tools/utils/parse_build_args.py"
BUILD_ARGS_FILE=$(mktemp "${TMPDIR:-/tmp}/keels-build-args.XXXXXX")

if [[ ! -f "$BUILD_ARGS_PARSER" ]]; then
    echo "error: build argument parser not found: $BUILD_ARGS_PARSER" >&2
    rm -f "$BUILD_ARGS_FILE"
    exit "$BUILD_CONFIGURATION_FAILED_EXIT_CODE"
fi
if ! python3 "$BUILD_ARGS_PARSER" --format sh --program "$0" -- "$@" > "$BUILD_ARGS_FILE"; then
    rm -f "$BUILD_ARGS_FILE"
    exit "$BUILD_CONFIGURATION_FAILED_EXIT_CODE"
fi
# Do not let an inherited value hide an incompatible SDK argument parser.
unset iosBuildStage
source "$BUILD_ARGS_FILE"
rm -f "$BUILD_ARGS_FILE"

if [[ "$2" == "ios" || "$2" == "ios-sim" ]]; then
    case "${iosBuildStage:-}" in
        interop|cangjie|artifact) ;;
        *)
            echo "error: iOS build stage is missing or invalid. Use interop, cangjie or artifact with a matching CJMP Tools argument parser: $BUILD_ARGS_PARSER" >&2
            exit "$BUILD_CONFIGURATION_FAILED_EXIT_CODE"
            ;;
    esac
    ios_artifacts_script_path="$active_tools_source_root/keels_tools/utils/ios_artifacts.py"
    if [[ "$iosBuildStage" == "artifact" && ! -f "$ios_artifacts_script_path" ]]; then
        echo "error: iOS artifact helper not found: $ios_artifacts_script_path. Use the CJMP Tools version matching this project." >&2
        exit "$BUILD_CONFIGURATION_FAILED_EXIT_CODE"
    fi
fi

use_lto=false
if [[ "${KEELS_LTO:-}" == "1" || "${KEELS_LTO:-}" == "true" || "$ltoRequested" == "true" ]]; then
    use_lto=true
fi
if [[ "$use_lto" == true ]]; then
    if [[ ! -f "$SCRIPT_DIR/lto_build_helper.sh" ]]; then
        echo "error: lto helper not found: $SCRIPT_DIR/lto_build_helper.sh" >&2
        exit 1
    fi
    . "$SCRIPT_DIR/lto_build_helper.sh"
fi

# Build configuration
export buildType="${1}"
export buildTarget="${2}"
export buildProfile
export cangjieFolder="cangjie-${buildTarget}"

# Base paths
CJMP_UI_PATH="$CJMP_SDK_HOME/cjmp-ui"
CJMP_ENGINE_PATH="$CJMP_SDK_HOME/ui-engine"
CJMP_TEST_PATH="$CJMP_SDK_HOME/cjmp-test"
CJMP_LIBS_PATH="$CJMP_SDK_HOME/cjmp-libs"
CJMP_TOOLS_LIBS_PATH="$CJMP_TOOL_PATH/libs"
CANGJIE_STDX_PATH="$CJMP_TOOL_PATH/third_party/cangjie-stdx"

# Platform-specific configuration
if [[ "${buildTarget}" == "android" ]]; then
    cangjiePath="${CJMP_TOOL_PATH}/third_party/cangjie-android"
    cangjiePlatform="linux_android_aarch64_cjnative"
    cangjieTarget="aarch64-linux-android26"
    export ANDROID_CJ_FRONTEND="$CJMP_UI_PATH/android/dynamic/ohos"
    export ANDROID_CJ_MACRO="$CJMP_UI_PATH/android/macro/ohos"
    if [[ -z "${ANDROID_NDK_DIR:-}" ]]; then
        echo "Android NDK path was not provided by the build environment." >&2
        exit 3
    fi
    if [[ ! -d "${ANDROID_NDK_DIR}" ]]; then
        echo "Android NDK directory does not exist: ${ANDROID_NDK_DIR}" >&2
        exit 3
    fi
    export ANDROID_ENGINE_PATH="$CJMP_ENGINE_PATH/android"
    export ANDROID_PROFILE_ENGINE_LIB_PATH="${ANDROID_PROFILE_ENGINE_LIB_PATH:-$CJMP_ENGINE_PATH/android/arm64-v8a/profile/libkeels_android.so}"
    export ANDROID_CANGJIE_PATH="$cangjiePath"
    export ANDROID_CANGJIE_RUNTIME_PATH="${cangjiePath}/runtime/lib/${cangjiePlatform}"
    export ANDROID_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/linux_android_aarch64_cjnative/dynamic/stdx"
    export ANDROID_TEST_PATH="$CJMP_TEST_PATH/android/ohos"
    export ANDROID_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/android/dynamic"
    export FFI_BRIDGE="${cmakeBridgePath:-$SCRIPT_DIR/android/app/build/intermediates/cmake/${buildType}/obj/arm64-v8a}"
    os_name=$(uname -s)
    if [ "$os_name" = "Darwin" ]; then
        export SYSTEM_STRING="darwin-x86_64"
    else
        export SYSTEM_STRING="windows-x86_64"
    fi
    lib_share_path="$ANDROID_NDK_DIR/toolchains/llvm/prebuilt/${SYSTEM_STRING}/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

elif [[ "${buildTarget}" == "ios" ]]; then
    cangjiePath="${CJMP_TOOL_PATH}/third_party/cangjie-ios"
    cangjiePlatform="ios_aarch64_cjnative"
    cangjieTarget="aarch64-apple-ios"
    platform_name="iphoneos"
    export cangjieFolder="cangjie-ios"
    export IOS_SDK_DIR="$(xcrun --sdk iphoneos --show-sdk-path)"
    export IOS_CJ_FRONTEND="$CJMP_UI_PATH/ios/dynamic/ohos"
    export IOS_CJ_MACRO="$CJMP_UI_PATH/ios/macro/ohos"
    export IOS_CANGJIE_PATH="${cangjiePath}/runtime/lib/${cangjiePlatform}"
    export IOS_ENGINE_PATH="$CJMP_ENGINE_PATH/ios/libkeels_ios.framework"
    export IOS_PROFILE_ENGINE_PATH="${IOS_PROFILE_ENGINE_PATH:-$CJMP_ENGINE_PATH/ios/profile/libkeels_ios.framework}"
    export IOS_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/ios_aarch64_cjnative/dynamic/stdx"
    export IOS_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/ios/dynamic"
    export IOS_TEST_PATH="$CJMP_TEST_PATH/ios/ohos"
    export FFI_BRIDGE="${CJMP_NATIVE_BRIDGE_DIR:-$SCRIPT_DIR/ios/oc_bridge}"
    SDK_PATH="$IOS_SDK_DIR"

elif [[ "${buildTarget}" == "ios-sim" ]]; then
    cangjiePath="${CJMP_TOOL_PATH}/third_party/cangjie-ios"
    cangjiePlatform="ios_simulator_aarch64_cjnative"
    cangjieTarget="aarch64-apple-ios-simulator"
    platform_name="iphonesimulator"
    export cangjieFolder="cangjie-ios"
    export IOS_SIM_SDK_DIR="$(xcrun --sdk iphonesimulator --show-sdk-path)"
    export IOS_SIM_CJ_FRONTEND="$CJMP_UI_PATH/ios-sim"
    export IOS_SIM_CANGJIE_PATH="${cangjiePath}/runtime/lib/${cangjiePlatform}"
    export IOS_SIM_ENGINE_PATH="$CJMP_ENGINE_PATH/ios-sim/libkeels_ios.framework"
    export IOS_SIM_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/ios_simulator_aarch64_cjnative/dynamic/stdx"
    export IOS_SIM_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/ios-sim-arm64/dynamic"
    export IOS_SIM_TEST_PATH="$CJMP_TEST_PATH/ios-sim/ohos"
    export FFI_BRIDGE="${CJMP_NATIVE_BRIDGE_DIR:-$SCRIPT_DIR/ios/oc_bridge}"
    SDK_PATH="$IOS_SIM_SDK_DIR"

fi

if [[ "$use_lto" == true ]]; then
    lto_prepare_build "$buildTarget" "$SCRIPT_DIR"
    source "$SCRIPT_DIR/.keels/lto/build-env.sh"
fi
# Tune generated mirrors
# Usage: tune_mirrors <dir_with_mirrors>
# [TODO] this tuning will be reduced/removed when toolchain gets ObjCInteropGen with all issues fixed
tune_mirrors() {
    local dir_with_mirrors="$1"

    # with UIKit
    if [[ -f "${dir_with_mirrors}/CIImage.cj" ]]; then
        sed -i '' '/CGImage/d' ${dir_with_mirrors}/CIImage.cj
    fi
    
    if [[ -f "${dir_with_mirrors}/UIImage.cj" ]]; then
        sed -i '' '/CGImage/d' ${dir_with_mirrors}/UIImage.cj
    fi

    if [[ -f "${dir_with_mirrors}/UIColor.cj" ]]; then
        sed -i '' '/CGColor/d' ${dir_with_mirrors}/UIColor.cj
    fi
    
    if [[ -f "${dir_with_mirrors}/UIBezierPath.cj" ]]; then
        sed -i '' '/CGPath/d' ${dir_with_mirrors}/UIBezierPath.cj
    fi

    if [[ -f "${dir_with_mirrors}/UIMenuElement.cj" ]]; then
        sed -i '' '/public open prop image/d' ${dir_with_mirrors}/UIMenuElement.cj
        sed -i '' '/public open prop title/d' ${dir_with_mirrors}/UIMenuElement.cj
    fi

    if [[ -f "${dir_with_mirrors}/UIResponder.cj" ]]; then
        perl -0777 -i -pe 's/\@ObjCOptional\n    \@ForeignName.* func copy.* Unit//g' ${dir_with_mirrors}/UIResponder.cj
    fi

    if [[ -f "${dir_with_mirrors}/UIGestureRecognizer.cj" ]]; then
        perl -0777 -i -pe 's/\@ObjCOptional\n    \@ForeignName.* func gestureRecognizerShouldBegin.* Bool//g' ${dir_with_mirrors}/UIGestureRecognizer.cj
    fi

    if [[ -f "${dir_with_mirrors}/CIBarcodeDescriptor.cj" ]]; then
        sed -i '' '/errorCorrectionLevel/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/errorCorrectedPayload/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/isCompact/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/layerCount/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/dataCodewordCount/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/errorCorrectedPayload/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/symbolVersion/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/maskPattern/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/rowCount/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/columnCount/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
        sed -i '' '/eccVersion/d' ${dir_with_mirrors}/CIBarcodeDescriptor.cj
    fi
    
    if [[ -f "${dir_with_mirrors}/CIFeature.cj" ]]; then
        sed -i '' '/eftEyePosition/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/ightEyePosition/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/outhPosition/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/rackingID/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/rackingFrameCount/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/aceAngle/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/hasSmile/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/EyeClosed/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/topLeft/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/topRight/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/bottomLeft/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/bottomRight/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/topLeft/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/topRight/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/bottomLeft/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/bottomRight/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/symbolDescriptor/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/var bounds/d' ${dir_with_mirrors}/CIFeature.cj
        sed -i '' '/prop bounds/d' ${dir_with_mirrors}/CIFeature.cj
    fi

    if [[ -f "${dir_with_mirrors}/UIGraphicsRenderer.cj" ]]; then
        sed -i '' '/CGContext/d' ${dir_with_mirrors}/UIGraphicsRenderer.cj    
    fi

    if [[ -f "${dir_with_mirrors}/UIStepper.cj" ]]; then
        sed -i '' '/dividerImageForLeftSegmentStateRightSegmentState/d' ${dir_with_mirrors}/UIStepper.cj
    fi

    if [[ -f "${dir_with_mirrors}/math.cj" ]]; then
        sed -i '' '/__inline_/d' ${dir_with_mirrors}/math.cj
        sed -i '' '/__sincos/d' ${dir_with_mirrors}/math.cj
        sed -i '' '/): Float16/d' ${dir_with_mirrors}/math.cj
    fi

    if [[ -f "${dir_with_mirrors}/_stdlib.cj" ]]; then
        sed -i '' '/_Exit/d' ${dir_with_mirrors}/_stdlib.cj
        sed -i '' '/mktemp/d' ${dir_with_mirrors}/_stdlib.cj
        sed -i '' '/mkstemp/d' ${dir_with_mirrors}/_stdlib.cj
        sed -i '' '/setkey/d' ${dir_with_mirrors}/_stdlib.cj
        sed -i '' '/swab/d' ${dir_with_mirrors}/_stdlib.cj
    fi

    if [[ -f "${dir_with_mirrors}/unistd.cj" ]]; then
        sed -i '' '/swab/d' ${dir_with_mirrors}/unistd.cj
        sed -i '' '/valloc/d' ${dir_with_mirrors}/unistd.cj
        sed -i '' '/getsubopt/d' ${dir_with_mirrors}/unistd.cj
    fi

    if [[ -f "${dir_with_mirrors}/mig.cj" ]]; then
        sed -i '' '/mig_strncpy_zerofill/d' ${dir_with_mirrors}/mig.cj
    fi

    if [[ -f "${dir_with_mirrors}/listener.cj" ]]; then
        perl -0777 -i -pe 's/\@ObjCMirror\n.* func xpc_listener_set_peer_code_signing_requirement.* Int32//g' ${dir_with_mirrors}/listener.cj
    fi

    if [[ -f "${dir_with_mirrors}/session.cj" ]]; then
        perl -0777 -i -pe 's/\@ObjCMirror\n.* func xpc_session_set_peer_code_signing_requirement.* Int32//g' ${dir_with_mirrors}/session.cj
    fi
}

# CJMP required interoplib to be placed properly: by package and along with cjo
# Usage: copy_interop_libraries <dst_path>
copy_interop_libraries() {
    local dst_path="$1"
    cjMods="$cangjiePath/modules/$cangjiePlatform"
    cjLibs="$cangjiePath/runtime/lib/$cangjiePlatform"
    if [[ "${buildTarget}" == "android" ]]; then
        mkdir -p "$dst_path/java"
        cp "$cjLibs/libjava.internal.so" "$cjMods/java.internal.cjo" "$dst_path/java/"
        cp "$cjLibs/libjava.lang.so"     "$cjMods/java.lang.cjo"     "$dst_path/java/"

    elif [[ "${buildTarget}" == "ios" || "${buildTarget}" == "ios-sim" ]]; then
        mkdir -p "${dst_path}/objc"
        cp "${cjLibs}/libobjc.internal.dylib" "${cjMods}/objc.internal.cjo" "${dst_path}/objc/"
        cp "${cjLibs}/libobjc.lang.dylib"     "${cjMods}/objc.lang.cjo"     "${dst_path}/objc/"

    fi
}

# Generated objc mirrors
# Usage: gen_objc_mirrors <dir_with_mirrors> <mirror_gen_config> <mirror_gen_backup_config>
gen_objc_mirrors() {
    local dir_with_mirrors="$1"
    local mirror_gen_config="$2"
    local mirror_gen_backup_config="$3"
    echo Generating mirrors with ObjCInteropGen
    cd "$(dirname $mirror_gen_config)"

    if [[ -d "$dir_with_mirrors" ]]; then
        rm -rf "$dir_with_mirrors"
    fi

    cp -p "$mirror_gen_config" "$mirror_gen_backup_config"

    # inject system include paths
    # [TODO] change arguments to "${mirror_gen_config}" "${platform_name}" "12.0"
    #        when update_objc_mirrors_toml.py in toolchain is upgraded
    python3 "$active_tools_source_root/keels_tools/utils/update_objc_mirrors_toml.py" "$platform_name" "$mirror_gen_config"

    # inject target options
    # [TODO] remove it when update_objc_mirrors_toml.py in toolchain is upgraded
    if [[ "${platform_name}" == "iphoneos" ]]; then
        targetOpts='"-DTARGET_OS_IPHONE", "-target", "arm64-apple-ios12.0",'
    else
        targetOpts='"-DTARGET_OS_SIMULATOR", "-target", "arm64-apple-ios12.0-simulator",'
    fi
    sed -i "" "s/# <target options placeholder>/${targetOpts}/" "${mirror_gen_config}"

    ObjCInteropGen "$mirror_gen_config"

    cd - > /dev/null
    echo "ObjCInteropGen mirror generation success"
}

# Build type configuration
if [[ "${buildType}" == "debug" ]]; then
    cangjieExtraArgs="-g --debug"
else
    cangjieExtraArgs="--release"
fi

# Build cangjie libraries
build_path="${CANGJIE_BUILD_DIR:-$SCRIPT_DIR/build}"
src_path="${KEELS_CJ_SRC_PATH:-$SCRIPT_DIR/lib}"
packageOutputRoot="${build_path}/${cangjieTarget}/${buildType}"

cjpm_path="$src_path/cjpm.toml"
cjpm_backup_path=""
dependency_cjpm_path="$SCRIPT_DIR/lib/cjpm.toml"
dependency_cjpm_backup_path=""
# Properly place interop libraries for mirror generation and Cangjie compilation.
export SCRIPT_BUILD_PATH="$packageOutputRoot"
if [[ "${iosBuildStage}" != "artifact" ]]; then
    copy_interop_libraries "$SCRIPT_BUILD_PATH"
fi
IOS_MIRRORS="${src_path}/ios/cangjie_bridge"
mirror_gen_config="${IOS_MIRRORS}/objc_mirrors.toml"
mirror_gen_backup_config=""
mirror_gen_config_lastused="${IOS_MIRRORS}/objc_mirrors.last_used.toml"
featureArgs=""
featureArgs="$featureArgs ${KEELS_LTO_CJPM_ARGS:-}"
cd "$src_path"

restore_tomls() {
    if [[ -n "$cjpm_backup_path" && -f "$cjpm_backup_path" ]]; then
        mv "$cjpm_backup_path" "$cjpm_path"
    fi
    if [[ -n "$dependency_cjpm_backup_path" && -f "$dependency_cjpm_backup_path" ]]; then
        mv "$dependency_cjpm_backup_path" "$dependency_cjpm_path"
    fi
    if [[ -n "$mirror_gen_backup_config" && -f "$mirror_gen_backup_config" ]]; then
        cp -p -f "$mirror_gen_config" "$mirror_gen_config_lastused"
        mv "$mirror_gen_backup_config" "$mirror_gen_config"
    fi
}

source "$CJMP_TOOL_PATH/third_party/${cangjieFolder}/envsetup.sh"

if [[ "$iosBuildStage" == "cangjie" ]]; then
    cjpm_backup_path=$(mktemp "${cjpm_path}.backup.XXXXXX")
    cp "$cjpm_path" "$cjpm_backup_path"
    trap restore_tomls EXIT
    update_toml_script_path="$active_tools_source_root/keels_tools/utils/update_toml.py"
    if [[ ! -f "$update_toml_script_path" ]]; then
        echo "error: update_toml.py not found: $update_toml_script_path" >&2
        exit 1
    fi
    echo "CJMP Tools source: $active_tools_source_root"
    python3 "$update_toml_script_path" "$cjpm_path"
    if [[ "${KEELS_IS_TEST_BUILD:-false}" == "true" && -f "$dependency_cjpm_path" ]]; then
        dependency_cjpm_backup_path=$(mktemp "${dependency_cjpm_path}.backup.XXXXXX")
        cp "$dependency_cjpm_path" "$dependency_cjpm_backup_path"
        python3 "$update_toml_script_path" "$dependency_cjpm_path"
    fi
fi

if [[ "$buildTarget" == "android" || "$iosBuildStage" == "cangjie" ]]; then
    cjpm build --target-dir "$build_path" --target="$cangjieTarget" $cangjieExtraArgs $featureArgs
    if [[ "$iosBuildStage" == "cangjie" ]]; then
        restore_tomls
        trap - EXIT
    fi
fi
# generate mirrors only when needed
if [[ "$iosBuildStage" == "interop" ]]; then
    dir_with_mirrors="${IOS_MIRRORS}/mirrors"
    if [[ ! -d "$dir_with_mirrors" || "$mirror_gen_config" -nt "$mirror_gen_config_lastused" ]]; then
        mirror_gen_backup_config=$(mktemp "${mirror_gen_config}.backup.XXXXXX")
        gen_objc_mirrors "$dir_with_mirrors" "$mirror_gen_config" "$mirror_gen_backup_config"

        # cleanup mirrors explicitly until ObjCInteropGen works perfect
        tune_mirrors "${dir_with_mirrors}"
    fi
fi

cd $SCRIPT_DIR

# Copy files with specified extensions
# Usage: copy_libs <input_dir> <output_dir> <extension1> [extension2] ...
copy_libs() {
    local input_dir="$1"
    local output_dir="$2"
    shift 2
    local extensions=("$@")
    echo "extension: $extensions"

    if [[ ! -d "$input_dir" ]]; then
        echo "error: $input_dir not exist"
        return 1
    fi

    local file_count=0

    # Process each extension
    for ext in "${extensions[@]}"; do
        ext="${ext#.}"
        # Use find with maxdepth 1 to search only current directory (not subdirectories)
        while IFS= read -r -d '' file; do
            echo "copy: $(basename "$file")"
            cp -f "$file" "$output_dir/"
            ((file_count++)) || true
        # Archive products may expose dylibs as links into UninstalledProducts.
        done < <(find -L "$input_dir" -maxdepth 1 -name "*.${ext}" -type f -print0 2>/dev/null)
    done

    if [[ $file_count -gt 0 ]]; then
        echo "Success! Copied $file_count files to $output_dir"
    else
        echo "No matching files found"
    fi
}

# Analyze library dependencies
# Usage: analyze_dependencies <target_dir> <platform> <search_path1> [search_path2] ...
analyze_dependencies() {
    local target_dir="$1"
    local platform="$2"
    shift 2
    local search_paths=("$@")

    if [[ ! -d "$target_dir" ]]; then
        echo "error: target_dir not exist: $target_dir" >&2
        return 1
    fi

    local PYTHON_SCRIPT="$active_tools_source_root/keels_tools/utils/dependency.py"

    local dep_file
    if command -v mktemp >/dev/null 2>&1; then
        dep_file=$(mktemp -t cj_deps_XXXXXX)
    else
        dep_file="$SCRIPT_DIR/cj_deps_$$.txt"
        : > "$dep_file"
    fi

    python3 "$PYTHON_SCRIPT" "$target_dir" "$platform" "${search_paths[@]}" > "$dep_file"

    echo "$dep_file"
}

# Copy dependency files
# Usage: copy_dependencies <output_dir> <dependency1> [dependency2] ...
copy_dependencies() {
    local output_dir="$1"
    local dep_file="$2"

    echo "Starting to copy dependencies to: $output_dir"
    local copied_count=0

    mkdir -p "$output_dir"

    if [[ ! -f "$dep_file" ]]; then
        echo "warning: dependency list file not found: $dep_file"
        return 0
    fi

    while IFS= read -r dep_path; do
        [[ -z "$dep_path" ]] && continue
        if [[ -f "$dep_path" ]] || [[ -d "$dep_path" ]]; then
            local dep_file_name
            dep_file_name=$(basename "$dep_path")
            local dep_output_dir="$output_dir"
            if [[ "$dep_file_name" == *.jar ]] || [[ "$dep_file_name" == *.aar ]]; then
                dep_output_dir=$(dirname "$output_dir")
            fi
            mkdir -p "$dep_output_dir"
            local dest_path="$dep_output_dir/$dep_file_name"
            # Skip if source and destination resolve to the same path
            if [[ -e "$dest_path" ]] && [[ "$(realpath "$dep_path")" == "$(realpath "$dest_path")" ]]; then
                echo "Skipped (same file): $dep_file_name"
                continue
            fi
            if [[ -d "$dep_path" ]]; then
                cp -Rf "$dep_path" "$dep_output_dir/" && ((copied_count++)) || true
            else
                cp -f "$dep_path" "$dep_output_dir/" && ((copied_count++)) || true
            fi
        fi
    done < "$dep_file"

    echo "Dependency copy completed. Total files copied: $copied_count"

    rm -f "$dep_file" || true
}

copy_package_libs() {
    local input_dir="$1"
    local output_dir="$2"
    local copy_cjo="$3"
    shift 3
    local extensions=("$@")

    if [[ ! -d "$input_dir" ]]; then
        echo "error: $input_dir not exist"
        return 1
    fi

    if [[ "$copy_cjo" == "true" ]]; then
        copy_libs "$input_dir" "$output_dir" "${extensions[@]}" "cjo"
    else
        copy_libs "$input_dir" "$output_dir" "${extensions[@]}"
    fi
}

fix_ios_dylib_rpaths() {
    local frameworks_dir="$1"

    if [[ ! -d "$frameworks_dir" ]]; then
        echo "error: $frameworks_dir not exist"
        return 1
    fi

    while IFS= read -r -d '' dylib; do
        local dylib_name
        dylib_name=$(basename "$dylib")
        install_name_tool -id "@rpath/$dylib_name" "$dylib"
    done < <(find "$frameworks_dir" -maxdepth 1 -type f -name "*.dylib" -print0 2>/dev/null)

    while IFS= read -r -d '' dylib; do
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            [[ "$dep" != /* ]] && continue
            local dep_name
            dep_name=$(basename "$dep")
            if [[ -f "$frameworks_dir/$dep_name" ]]; then
                install_name_tool -change "$dep" "@rpath/$dep_name" "$dylib"
            fi
        done < <(otool -L "$dylib" | awk 'NR > 1 { print $1 }')
    done < <(find "$frameworks_dir" -maxdepth 1 -type f -name "*.dylib" -print0 2>/dev/null)
}

cangjiePackageName="${KEELS_CJ_PACKAGE_NAME:-ohos_app_cangjie_entry}"
if [[ "${buildTarget}" == "android" ]]; then
    sourceSet="android"
elif [[ "${buildTarget}" == "ios" ]] || [[ "${buildTarget}" == "ios-sim" ]]; then
    sourceSet=ios
fi
if [[ "${KEELS_IS_TEST_BUILD:-false}" == "true" ]]; then
    inputDir="${packageOutputRoot}/${cangjiePackageName}"
else
    inputDir="${packageOutputRoot}/${cangjiePackageName}/${sourceSet}/product"
fi
if [[ "${buildTarget}" == "android" ]]; then
    # output: dependency storage path
    outputDir="${SCRIPT_DIR}/android/app/libs"
    # Clean and recreate output directory
    if [[ -d "$outputDir" ]]; then
        rm -rf "$outputDir"
    fi
    mkdir -p "$outputDir"
    mkdir -p "$outputDir/arm64-v8a"

    # copy: main library files
    copy_libs "$ANDROID_CANGJIE_PATH/lib" "$outputDir" "jar" # library-loader.jar
    copy_package_libs "$inputDir/../../../mirrors" "$outputDir/arm64-v8a" false "so"

    copy_libs "$ANDROID_ENGINE_PATH" "$outputDir" "jar" # keels_android_adapter.jar
    copy_package_libs "$inputDir" "$outputDir/arm64-v8a" false "so"
    cp "${lib_share_path}" "$outputDir/arm64-v8a" #libc++_shared.so

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$outputDir/arm64-v8a" "android" "$packageOutputRoot" "$ANDROID_CANGJIE_RUNTIME_PATH" "$ANDROID_CJ_FRONTEND" "$ANDROID_CANGJIE_STDX_PATH" "$ANDROID_CJMP_LIBS_PATH" "$ANDROID_TEST_PATH")"
    copy_dependencies "$outputDir/arm64-v8a" "$dep_file"
    if [[ "${buildProfile}" == "true" ]]; then
        cp "$ANDROID_PROFILE_ENGINE_LIB_PATH" "$outputDir/arm64-v8a" # libkeels_android.so
        cp "$CJMP_TOOLS_LIBS_PATH/android/libdevtools_debugger.so" "$outputDir/arm64-v8a" # libdevtools_debugger.so
    else
        cp "$ANDROID_ENGINE_PATH/arm64-v8a/libkeels_android.so" "$outputDir/arm64-v8a" # libkeels_android.so
    fi
    if [[ "$use_lto" == true ]]; then
        lto_finalize_android "$inputDir/libohos_app_cangjie_entry.so" "$outputDir/arm64-v8a" "$SCRIPT_DIR"
    fi

elif [[ "${iosBuildStage}" == "artifact"  ]] && [[ "${buildTarget}" == "ios" ]]; then
    # output: dependency storage path
    frameworksDir="${CJMP_ARTIFACTS_DIR:-./ios/frameworks}"
     # Clean and recreate output directory
    if [[ -d "$frameworksDir" ]]; then
        rm -rf "$frameworksDir"
    fi
    mkdir -p "$frameworksDir"

    # copy: main library files
    copy_package_libs "$inputDir" "$frameworksDir" false "dylib"
    if [[ "${buildProfile}" == "true" ]]; then
        cp -r "$IOS_PROFILE_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework
        cp "$CJMP_TOOLS_LIBS_PATH/ios/libdevtools_debugger.dylib" "$frameworksDir" # libdevtools_debugger.dylib
    else
        cp -r "$IOS_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework
    fi
    if [[ "$use_lto" == true ]]; then
        lto_finalize_ios "$inputDir/libohos_app_cangjie_entry.dylib" "$frameworksDir/libkeels_ios.framework" "$SCRIPT_DIR"
    fi
    find "$frameworksDir" -name "*.dSYM" -type d -prune -exec rm -rf {} + 2>/dev/null || true

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$frameworksDir" "ios" "$packageOutputRoot" "$IOS_CANGJIE_PATH" "$IOS_CJ_FRONTEND" "$IOS_CANGJIE_STDX_PATH" "$IOS_CJMP_LIBS_PATH" "$IOS_TEST_PATH")"
    copy_dependencies "$frameworksDir" "$dep_file"
    fix_ios_dylib_rpaths "$frameworksDir"

elif [[ "${iosBuildStage}" == "artifact" ]] && [[ "${buildTarget}" == "ios-sim" ]]; then
    # output: dependency storage path
    frameworksDir="${CJMP_ARTIFACTS_DIR:-./ios/frameworks}"

     # Clean and recreate output directory
    if [[ -d "$frameworksDir" ]]; then
        rm -rf "$frameworksDir"
    fi
    mkdir -p "$frameworksDir"

    # copy: main library files
    copy_package_libs "$inputDir" "$frameworksDir" false "dylib"
    cp -r "$IOS_SIM_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework
    find "$frameworksDir" -name "*.dSYM" -type d -prune -exec rm -rf {} + 2>/dev/null || true

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$frameworksDir" "ios" "$packageOutputRoot" "$IOS_SIM_CANGJIE_PATH" "$IOS_SIM_CJ_FRONTEND" "$IOS_SIM_CANGJIE_STDX_PATH" "$IOS_SIM_CJMP_LIBS_PATH" "$IOS_SIM_TEST_PATH")"
    copy_dependencies "$frameworksDir" "$dep_file"
    fix_ios_dylib_rpaths "$frameworksDir"
fi

if [[ "${iosBuildStage}" == "artifact" ]]; then
    python3 "$ios_artifacts_script_path" --frameworks-dir "$frameworksDir"
fi
