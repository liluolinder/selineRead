#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FFI_DIR="${PROJECT_ROOT}/sdl/.sdl3"

if ! command -v brew >/dev/null 2>&1; then
    printf 'Homebrew is required to locate SDL3 and SDL3_ttf.\n' >&2
    exit 1
fi

SDL3_PREFIX="$(brew --prefix sdl3)"
SDL3_TTF_PREFIX="$(brew --prefix sdl3_ttf)"

mkdir -p "${FFI_DIR}"
ln -sfn "${SDL3_PREFIX}/lib/libSDL3.dylib" "${FFI_DIR}/libSDL3.dylib"
ln -sfn "${SDL3_TTF_PREFIX}/lib/libSDL3_ttf.dylib" "${FFI_DIR}/libSDL3_ttf.dylib"

printf 'Linked SDL3 and SDL3_ttf into %s\n' "${FFI_DIR}"
