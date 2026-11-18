#!/usr/bin/env bash

lto_relink_driver() {
    local driver="$CJMP_TOOL_PATH/tools/keels_tools/utils/lto_relink.py"
    if [[ ! -f "$driver" ]]; then
        echo "error: lto relink driver not found: $driver" >&2
        return 1
    fi
    python3 "$driver" "$@"
}

lto_verbose_args() {
    if [[ "${KEELS_VERBOSE:-}" == "1" || "${KEELS_VERBOSE:-}" == "true" ]]; then
        printf '%s\n' --verbose
    fi
}

lto_prepare_build() {
    local platform_name="$1"
    local project_root="$2"
    local -a verbose_args=()
    [[ -n "$(lto_verbose_args)" ]] && verbose_args+=(--verbose)
    lto_relink_driver prepare \
        --platform "$platform_name" \
        --sdk-home "$CJMP_SDK_HOME" \
        --output "$project_root/.keels/lto/build-env.sh" \
        --format sh \
        "${verbose_args[@]}"
}

lto_finalize_android() {
    local entry_lib="$1"
    local package_dir="$2"
    local project_root="$3"
    local -a verbose_args=()
    [[ -n "$(lto_verbose_args)" ]] && verbose_args+=(--verbose)
    lto_relink_driver finalize-android \
        --sdk-home "$CJMP_SDK_HOME" \
        --ndk "$ANDROID_NDK_DIR" \
        --system-string "$SYSTEM_STRING" \
        --entry-lib "$entry_lib" \
        --package-dir "$package_dir" \
        --project-root "$project_root" \
        --relink-dependency "${BASH_SOURCE[0]}" \
        --metadata-policy fallback \
        "${verbose_args[@]}"
}

lto_finalize_ios() {
    local entry_lib="$1"
    local package_framework="$2"
    local project_root="$3"
    local -a verbose_args=()
    [[ -n "$(lto_verbose_args)" ]] && verbose_args+=(--verbose)
    lto_relink_driver finalize-ios \
        --sdk-home "$CJMP_SDK_HOME" \
        --ios-sdk "$IOS_SDK_DIR" \
        --entry-lib "$entry_lib" \
        --package-framework "$package_framework" \
        --project-root "$project_root" \
        --relink-dependency "${BASH_SOURCE[0]}" \
        --metadata-policy fallback \
        "${verbose_args[@]}"
}
