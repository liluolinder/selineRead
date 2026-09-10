# CangHui sdl 上游与适配记录

## 目的

记录 `sdl/` 包及其 `.sdl3/` 运行时库的上游来源、版本、归属与已知缺口。
本文件是内部归属记录，不进入对外发布叙事；对外以 `README.md` 和 `NOTICE` 为准。

## SDL3

- 上游仓库: <https://github.com/libsdl-org/SDL.git>
- 参考发布线: `3.4.12`（见 HarmonyHap/CangHUI/UPSTREAM.md）
- 参考 revision: `f87239e71e42da91ca317a12eefb82cfbf3393eb`
- License: Zlib（见本目录 `LICENSE`）
- 说明: 本地 `.sdl3/` 中的 Windows DLL 是否精确对应上述 revision **未在 Cangku 仓库内独立验证**；
  来源/构建命令未留存，按诚实原则标为 `unknown / 待验证`。

## SDL3_ttf

- 上游仓库: <https://github.com/libsdl-org/SDL_ttf.git>
- 参考发布线: `3.2.2`（见 HarmonyHap/CangHUI/UPSTREAM.md）
- 参考 revision: `a1ce3670aec736ecbf0936c43f2f0cc53aa61e5b`
- License: Zlib（见本目录 `LICENSE`）
- 说明: 同上，Windows DLL 来源未在 Cangku 仓库内独立验证，标为 `unknown / 待验证`。

## `.sdl3/` Windows DLL（git 跟踪）

用途：Windows 构建与运行时链接库。`sdl/cjpm.toml` 以 path 依赖引用
`./.sdl3`；`cuic bootstrap/doctor` 在 Windows 上要求这些 DLL 存在；部署文档要求
分发可执行文件时同时携带 `SDL3.dll` 与 `SDL3_ttf.dll`。

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `SDL3.dll` | 5,366,478 | `49db50085edc74c2b5962f010e2416557188dcc67d6fb8a61381de2a2cd3a287` |
| `SDL3_ttf.dll` | 3,112,157 | `9a3defa81cfb71a48256333f1a015ee72a9b7d82311891cdc87afcb9f23ec5a9` |
| `libSDL3.dll` | 5,366,478 | `49db50085edc74c2b5962f010e2416557188dcc67d6fb8a61381de2a2cd3a287` |
| `libSDL3_ttf.dll` | 3,112,157 | `9a3defa81cfb71a48256333f1a015ee72a9b7d82311891cdc87afcb9f23ec5a9` |

- `libSDL3.dll` / `libSDL3_ttf.dll` 是 cjpm/cjc 链接名；`SDL3.dll` / `SDL3_ttf.dll`
  是 Windows 运行时加载名。两对文件内容相同（SHA-256 一致）。
- 来源/构建参数：**unknown**（仓库内未留存下载 URL、构建脚本或校验记录）；
  如后续能确认，应在本文件补版本、来源与复现方式。
- 保留决策（D1=A）：保留这些 DLL 以保证 Windows 用户开箱即用；不得在未提供
  等价自动下载/校验脚本前删除。

## Cangjie sdl 包装

- `sdl/` 是 Cangjie 对 SDL3 / SDL3_ttf 的 FFI 包装，归属 CangHui。
- macOS 本地 dylib（`libSDL3.dylib` / `libSDL3_ttf.dylib`）为本地生成/Homebrew
  来源，不进入 git 跟踪；`scripts/bootstrap-macos.sh` 负责准备。
- Linux 使用系统 `pkg-config` 提供的 SDL3/SDL3_ttf 开发包（见 `cuic doctor`）。

## 边界

- 本文件不构成对 SDL3/SDL3_ttf 上游二进制完整性的认证。
- 未覆盖 Linux/Android/iOS/HarmonyOS 平台库的逐项来源记录（另有
  HarmonyHap/CangHUI/UPSTREAM.md）。
