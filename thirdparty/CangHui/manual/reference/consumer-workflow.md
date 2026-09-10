# Lightweight Consumer Workflow

**English** | [中文](consumer-workflow.zh-CN.md)

CangHui applications can depend on the framework without keeping a sibling source checkout or copying the
framework into every project. The workflow has three independently versioned parts:

- `cuic`: an installable command built from `tools/cuic`;
- the application: a normal executable CJPM module;
- `chui`: a public Git dependency pinned by `commitId` and frozen by `cjpm.lock`.

## Install cuic

The installer performs a sparse Git fetch containing only `tools/cuic`, compiles the command, and installs it
under `$HOME/.cjpm/bin` by default:

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

Select a reviewed tag, branch, or commit when required:

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | \
  bash -s -- --ref <reviewed-branch-or-commit>
```

## Create And Run An Application

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic dependency update
cuic doctor macos
cuic package plan macos .
cuic package build macos .
cuic build macos
cuic run macos
```

`cuic init` also creates `canghui.toml`. Its `[application]`, `[assets]` and `[system]` tables provide the
validated application identity and logical resource graph used by `cuic package plan` and `cuic package build`.
The plan command is read-only. The build command creates a bounded unsigned artifact and receipt while keeping
signing, notarization, native runtime closure and publication behind platform gates. The `[scripts]` table is automatically discovered, allowing a project
to replace host-specific wrapper files with named, shell-free lifecycle pipelines:

```bash
cuic check
cuic dev
cuic snapshot-ui
```

The pipeline steps remain normal `cuic` commands; platform selection still follows the current host unless a
step names a supported platform explicitly. Script discovery is static project metadata and remains available
before the application can build or initialize runtime state.

The generated dependency is shaped as follows:

```toml
[dependencies]
chui = { git = "https://github.com/Celading/CangHui.git", commitId = "<reviewed-commit>" }
```

`cuic dependency update` is the explicit dependency mutation step. It asks CJPM to resolve the reviewed
manifest pin, stores Git source under the configured user cache (normally `$HOME/.cjpm/git`), and writes the
resolved commit to `cjpm.lock`. Later build-like commands reuse that cache and fail closed if the lock is absent
or its CangHui commit differs from the manifest; they never run `cjpm update` implicitly. Commit `cjpm.lock`
with the application and rerun the explicit command only when intentionally refreshing dependency resolution.

On macOS, `cuic` copies the installed Homebrew SDL3 and SDL3_ttf libraries into a staging cache keyed by the
resolved CangHui root. It supplies that directory through both the compile-time `LIBRARY_PATH` and runtime
dynamic-library path, without modifying the CJPM source checkout. Linux uses `pkg-config`; Windows uses the
framework's declared DLL surface. Platform doctor output remains the authority for incomplete adapters.

## Local Framework Development

Use an explicit path only when modifying CangHui itself or working offline with a prepared checkout:

```bash
cuic init HelloCangHuiDev --canghui-path ../CangHui
```

`CANGHUI_FRAMEWORK_ROOT` is also an explicit command-level override for commands without an owning consumer
dependency. An initialized consumer's manifest/lock remains authoritative because CJPM will link that declared
source; use `--canghui-path` when the application itself must build a local framework checkout. The older
`CANGUI_FRAMEWORK_ROOT` name is retained for compatibility.

## Scope

Git consumption is not a central-package publication. The user cache contains one source checkout per resolved
commit, while application projects remain small and portable. Desktop host proof does not imply complete iOS,
HarmonyOS, Android, Windows, or Linux application packaging.
