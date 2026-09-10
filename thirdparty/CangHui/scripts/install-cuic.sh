#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="${CANGHUI_REPOSITORY:-https://github.com/Celading/CangHui.git}"
REF="${CANGHUI_REF:-main}"
INSTALL_ROOT="${CUIC_INSTALL_ROOT:-${HOME}/.cjpm}"
SOURCE_ROOT=""

usage() {
    cat <<'EOF'
Install the CangHui CLI without retaining a full framework checkout.

Usage:
  install-cuic.sh [--ref <branch|tag|commit>] [--repository <git-url>]
                  [--root <install-root>] [--source <local-canghui-root>]

The default install root is $HOME/.cjpm. --source is intended for framework
development and installer verification; normal installs use a sparse Git fetch
containing only tools/cuic.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref)
            [[ $# -ge 2 ]] || { printf '%s\n' '--ref requires a value' >&2; exit 2; }
            REF="$2"
            shift 2
            ;;
        --repository)
            [[ $# -ge 2 ]] || { printf '%s\n' '--repository requires a value' >&2; exit 2; }
            REPOSITORY="$2"
            shift 2
            ;;
        --root)
            [[ $# -ge 2 ]] || { printf '%s\n' '--root requires a value' >&2; exit 2; }
            INSTALL_ROOT="$2"
            shift 2
            ;;
        --source)
            [[ $# -ge 2 ]] || { printf '%s\n' '--source requires a value' >&2; exit 2; }
            SOURCE_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

command -v cjpm >/dev/null 2>&1 || {
    printf '%s\n' 'cjpm is required; install and activate Cangjie 1.1.3 or newer.' >&2
    exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/canghui-cuic-install.XXXXXX")"
trap 'rm -rf "${WORK_DIR}"' EXIT

if [[ -n "${SOURCE_ROOT}" ]]; then
    [[ -f "${SOURCE_ROOT}/tools/cuic/cjpm.toml" ]] || {
        printf 'CangHui tools/cuic not found under %s\n' "${SOURCE_ROOT}" >&2
        exit 1
    }
    mkdir -p "${WORK_DIR}/CangHui/tools"
    cp -R "${SOURCE_ROOT}/tools/cuic" "${WORK_DIR}/CangHui/tools/cuic"
else
    command -v git >/dev/null 2>&1 || {
        printf '%s\n' 'git is required for the sparse cuic installation.' >&2
        exit 1
    }
    CHECKOUT="${WORK_DIR}/CangHui"
    git init -q "${CHECKOUT}"
    git -C "${CHECKOUT}" remote add origin "${REPOSITORY}"
    git -C "${CHECKOUT}" sparse-checkout init --cone
    git -C "${CHECKOUT}" sparse-checkout set tools/cuic
    git -C "${CHECKOUT}" fetch -q --depth 1 origin "${REF}"
    git -C "${CHECKOUT}" checkout -q --detach FETCH_HEAD
fi

SOURCE_REVISION="$(git -C "${SOURCE_ROOT:-${CHECKOUT}}" rev-parse HEAD 2>/dev/null || true)"
[[ "${SOURCE_REVISION}" =~ ^[0-9a-fA-F]{40}$ ]] || SOURCE_REVISION="unknown"
BUILD_CHANNEL="release"
if [[ -n "${SOURCE_ROOT}" ]]; then
    BUILD_CHANNEL="local-source"
    if [[ -n "$(git -C "${SOURCE_ROOT}" status --porcelain -- tools/cuic 2>/dev/null || true)" ]]; then
        SOURCE_REVISION="${SOURCE_REVISION}+dirty"
    fi
fi
cat > "${WORK_DIR}/CangHui/tools/cuic/src/build_identity.cj" <<EOF
package cuic

let CUIC_BUILD_CHANNEL = "${BUILD_CHANNEL}"
let CUIC_BUILD_REVISION = "${SOURCE_REVISION}"

func renderCuicVersion(): String {
    "cuic \${VERSION} (\${CUIC_BUILD_CHANNEL}@\${CUIC_BUILD_REVISION})"
}
EOF

mkdir -p "${INSTALL_ROOT}"
cjpm install --path "${WORK_DIR}/CangHui/tools/cuic" --root "${INSTALL_ROOT}"
"${INSTALL_ROOT}/bin/cuic" version
printf 'cuic installed at %s\n' "${INSTALL_ROOT}/bin/cuic"
