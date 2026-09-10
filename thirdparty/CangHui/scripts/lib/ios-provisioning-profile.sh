#!/usr/bin/env bash

CANGHUI_IOS_PROFILE_DECODER_USED=""

decode_ios_provisioning_profile() {
    local input_path="$1"
    local output_path="$2"
    local temporary_path="${output_path}.tmp.$$"

    rm -f "${output_path}" "${temporary_path}"

    if command -v security >/dev/null 2>&1 && \
        security cms -D -i "${input_path}" -o "${temporary_path}" \
            >/dev/null 2>&1; then
        mv "${temporary_path}" "${output_path}"
        CANGHUI_IOS_PROFILE_DECODER_USED="security-cms"
        return 0
    fi

    rm -f "${temporary_path}"
    if command -v openssl >/dev/null 2>&1 && \
        openssl smime -inform der -verify -noverify -in "${input_path}" \
            -out "${temporary_path}" >/dev/null 2>&1; then
        mv "${temporary_path}" "${output_path}"
        CANGHUI_IOS_PROFILE_DECODER_USED="openssl-smime"
        return 0
    fi

    rm -f "${temporary_path}"
    CANGHUI_IOS_PROFILE_DECODER_USED=""
    printf 'Unable to decode provisioning profile: %s\n' "${input_path}" >&2
    return 1
}
