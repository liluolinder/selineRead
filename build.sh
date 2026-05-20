#!/bin/bash
#!/usr/bin/env bash
set -e

# Build configuration
export buildType="${1}"
export buildTarget="${2}"
export cangjieFolder="cangjie-${buildTarget}"

# Script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)

# Base paths
CJMP_UI_PATH="$CJMP_SDK_HOME/cjmp-ui"
CJMP_ENGINE_PATH="$CJMP_SDK_HOME/ui-engine"
CJMP_TOOL_PATH="$CJMP_SDK_HOME/cjmp-tools"
CJMP_LIBS_PATH="$CJMP_SDK_HOME/cjmp-libs"
CANGJIE_STDX_PATH="$CJMP_TOOL_PATH/third_party/cangjie-stdx"

# Platform-specific configuration
if [[ "${buildTarget}" == "android" ]]; then
    cangjieTarget="aarch64-linux-android26"
    export ANDROID_CJ_FRONTEND="$CJMP_UI_PATH/android"
    export ANDROID_NDK_DIR="$ANDROID_SDK_ROOT/ndk/26.3.11579264"
    export ANDROID_ENGINE_PATH="$CJMP_ENGINE_PATH/android"
    export ANDROID_CANGJIE_PATH="$CJMP_TOOL_PATH/third_party/cangjie-android"
    export ANDROID_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/linux_android_aarch64_cjnative/dynamic/stdx"
    export ANDROID_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/android/dynamic"
    export ANDROID_BRIDGE="$SCRIPT_DIR/android/app/build/intermediates/cmake/${buildType}/obj/arm64-v8a"
    os_name=$(uname -s)
    if [ "$os_name" = "Darwin" ]; then
        export SYSTEM_STRING="darwin-x86_64"
    else
        export SYSTEM_STRING="windows-x86_64"
    fi
    lib_share_path="$ANDROID_NDK_DIR/toolchains/llvm/prebuilt/${SYSTEM_STRING}/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

elif [[ "${buildTarget}" == "ios" ]]; then
    cangjieTarget="aarch64-apple-ios"
    platform_name="iphoneos"
    export cangjieFolder="cangjie-ios"
    export IOS_SDK_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
    export IOS_CJ_FRONTEND="$CJMP_UI_PATH/ios"
    export IOS_CANGJIE_PATH="$CJMP_TOOL_PATH/third_party/cangjie-ios/runtime/lib/ios_aarch64_cjnative"
    export IOS_ENGINE_PATH="$CJMP_ENGINE_PATH/ios/libkeels_ios.framework"
    export IOS_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/ios_aarch64_cjnative/dynamic/stdx"
    export IOS_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/ios/dynamic"
    export IOS_BRIDGE="$SCRIPT_DIR/ios/oc_bridge"

elif [[ "${buildTarget}" == "ios-sim" ]]; then
    cangjieTarget="aarch64-apple-ios-simulator"
    platform_name="iphonesimulator"
    export cangjieFolder="cangjie-ios"
    export IOS_SIM_SDK_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
    export IOS_SIM_CJ_FRONTEND="$CJMP_UI_PATH/ios-sim"
    export IOS_SIM_CANGJIE_PATH="$CJMP_TOOL_PATH/third_party/cangjie-ios/runtime/lib/ios_simulator_aarch64_cjnative"
    export IOS_SIM_ENGINE_PATH="$CJMP_ENGINE_PATH/ios-sim/libkeels_ios.framework"
    export IOS_SIM_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/ios_simulator_aarch64_cjnative/dynamic/stdx"
    export IOS_SIM_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/ios-sim-arm64/dynamic"
    export IOS_BRIDGE="$SCRIPT_DIR/ios/oc_bridge"
fi

if [[ "${buildTarget}" == "ios" ]] || [[ "${buildTarget}" == "ios-sim" ]]; then 
    # compile oc_bridge code
    oc_bridge_dir="$SCRIPT_DIR/ios/oc_bridge"
    echo "Compiling Objective-C code in $oc_bridge_dir"
    if [[ "${buildTarget}" == "ios" ]]; then
        SDK="iphoneos"
        SDK_PATH="$IOS_SDK_DIR"
    else
        SDK="iphonesimulator"
        SDK_PATH="$IOS_SIM_SDK_DIR"
    fi
    xcrun --sdk $SDK clang \
        -dynamiclib \
        -arch arm64 \
        -isysroot "$SDK_PATH" \
        -framework Foundation \
        -install_name @rpath/libjniseline_read.dylib \
        "$oc_bridge_dir/seline_read.m" "$oc_bridge_dir/seline_read_ffi.m" \
        -o "$oc_bridge_dir/libjniseline_read.dylib"

    echo "Compiled libjniseline_read.dylib to $oc_bridge_dir"
fi

# Build type configuration
if [[ "${buildType}" == "debug" ]]; then
    cangjieExtraArgs="-g"
else
    cangjieExtraArgs=""
fi

# Build cangjie libraries
build_path="$SCRIPT_DIR/build"
src_path="$SCRIPT_DIR/lib"

cd $src_path
cp cjpm.toml cjpm.toml.backup
cleanup() {
    if [ -f cjpm.toml.backup ]; then
        mv cjpm.toml.backup cjpm.toml
    fi
}
trap cleanup EXIT INT TERM
if [[ "${buildTarget}" == "ios" || "${buildTarget}" == "ios-sim" ]]; then
    python3 $CJMP_TOOL_PATH/tools/keels_tools/utils/update_toml.py $src_path/cjpm.toml
fi
source "$CJMP_TOOL_PATH/third_party/${cangjieFolder}/envsetup.sh"
cjpm build --no-feature-deduce --target-dir "${build_path}" --target="${cangjieTarget}" ${cangjieExtraArgs}
cleanup
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
        done < <(find "$input_dir" -maxdepth 1 -name "*.${ext}" -type f -print0 2>/dev/null)
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

    local PYTHON_SCRIPT="$CJMP_TOOL_PATH/tools/keels_tools/utils/dependency.py"

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
        if [[ -f "$dep_path" ]]; then
            local dep_file_name
            dep_file_name=$(basename "$dep_path")
            local dest_path="$output_dir/$dep_file_name"
            # Skip if source and destination are the same file
            if [[ -f "$dest_path" ]] && [[ "$(realpath "$dep_path")" == "$(realpath "$dest_path")" ]]; then
                echo "Skipped (same file): $dep_file_name"
                continue
            fi
            cp -f "$dep_path" "$output_dir/" && ((copied_count++)) || true
        fi
    done < "$dep_file"

    echo "Dependency copy completed. Total files copied: $copied_count"

    rm -f "$dep_file" || true
}

inputDir="${build_path}/${cangjieTarget}/${buildType}/ohos_app_cangjie_entry"
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
    copy_libs "$ANDROID_ENGINE_PATH" "$outputDir" "jar" # keels_android_adapter.jar
    copy_libs "$inputDir" "$outputDir/arm64-v8a" "so" "cjo" # libohos_app_cangjie_entry.so; ohos_app_cangjie_entry.cjo
    copy_libs "$ANDROID_BRIDGE" "$outputDir/arm64-v8a" "so"
    cp "${lib_share_path}" "$outputDir/arm64-v8a" #libc++_shared.so

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$outputDir/arm64-v8a" "android" "$ANDROID_CANGJIE_PATH" "$ANDROID_CJ_FRONTEND" "$ANDROID_CANGJIE_STDX_PATH" "$ANDROID_CJMP_LIBS_PATH")"
    copy_dependencies "$outputDir/arm64-v8a" "$dep_file"
    cp "$ANDROID_ENGINE_PATH/arm64-v8a/libkeels_android.so" "$outputDir/arm64-v8a" # libkeels_android.so

elif [[ "${buildTarget}" == "ios" ]]; then
    # output: dependency storage path
    frameworksDir="./ios/frameworks"

     # Clean and recreate output directory
    if [[ -d "$frameworksDir" ]]; then
        rm -rf "$frameworksDir"
    fi
    mkdir -p "$frameworksDir"

    # copy: main library files
    copy_libs "$inputDir" "$frameworksDir" "dylib" # libohos_app_cangjie_entry.dylib
    copy_libs "$IOS_BRIDGE" "$frameworksDir" "dylib" # libjniseline_read.dylib
    cp -r "$IOS_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$frameworksDir" "ios" "$IOS_CANGJIE_PATH" "$IOS_CJ_FRONTEND" "$IOS_CANGJIE_STDX_PATH" "$IOS_CJMP_LIBS_PATH")"
    copy_dependencies "$frameworksDir" "$dep_file"

elif [[ "${buildTarget}" == "ios-sim" ]]; then
    # output: dependency storage path
    frameworksDir="./ios/frameworks"

     # Clean and recreate output directory
    if [[ -d "$frameworksDir" ]]; then
        rm -rf "$frameworksDir"
    fi
    mkdir -p "$frameworksDir"

    # copy: main library files
    copy_libs "$inputDir" "$frameworksDir" "dylib" # libohos_app_cangjie_entry.dylib
    copy_libs "$IOS_BRIDGE" "$frameworksDir" "dylib" # libjniseline_read.dylib
    cp -r "$IOS_SIM_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$frameworksDir" "ios" "$IOS_SIM_CANGJIE_PATH" "$IOS_SIM_CJ_FRONTEND" "$IOS_SIM_CANGJIE_STDX_PATH" "$IOS_SIM_CJMP_LIBS_PATH")"
    copy_dependencies "$frameworksDir" "$dep_file"
fi
