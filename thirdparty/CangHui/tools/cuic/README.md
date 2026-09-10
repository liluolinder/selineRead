# CangHui CLI

`cuic` is the integrated, Cangjie-built lifecycle CLI for CangHui framework development and generated applications.
It lives under `tools/cuic`; the former standalone layout remains a compatibility source only.

Install only the CLI with a sparse Git fetch:

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

Framework contributors can still build and run the integrated command from this checkout:

```bash
cd tools/cuic
cjpm build
./bin/cuic doctor macos --verbose
```

The repository launchers rebuild the integrated binary when `src/` or `cjpm.toml` is newer than the current
binary. An installed `cuic` remains a fixed compiled artifact until it is explicitly reinstalled or upgraded.
`cuic version` keeps the semantic version and appends a provenance channel and revision. Sparse installs report
`release@<commit>`, local-source installs report `local-source@<commit>` (plus `+dirty` when applicable), and a
direct repository build reports `development@unembedded` instead of claiming an unproven source revision.

`bin/cuic` and `bin\\cuic.ps1` are thin launchers. Command parsing and lifecycle orchestration live in
the compiled Cangjie executable under `src/`.

## Commands

```text
cuic init <directory> [--name <package>] [--platform <platform>]
    [--canghui-path <path> | --canghui-git <url> --canghui-commit <commit>]
cuic doctor [target] [--project <directory>] [--json] [--verbose]
cuic bootstrap [platform]
cuic font <status|install> [platform]
cuic kmode diff [project]
cuic kmode list [project]
cuic kmode describe [project] <endpoint>
cuic kmode call [project] <endpoint> [payload]
cuic probe diff [project]
cuic probe list [project] [--json]
cuic probe describe [project] <probe> [--json]
cuic probe run [project] <probe> [--script <file>|--events <script>] [--json]
cuic scripts init|list [project]
cuic scripts run <name> [project]
cuic dependency update [project]
cuic package plan [macos|windows|linux] [project] [--json]
cuic package build [macos|windows|linux] [project] [--output <dir>] [--json]
cuic symbol list|discover [material|ant|arco] [--json]
cuic symbol generate <provider:name[@export]>... --output <file.cj> [--package <name>]
cuic build [platform] [project]
cuic test [platform] [project]
cuic run [platform] [project|example]
cuic prnt [platform] [project|example] [--output <file.bmp|file.png>] [--frames <count>] [-- <app args...>]
cuic clean [project]
cuic examples
cuic version
```

## Project Scripts

`cuic` automatically discovers named lifecycle pipelines from `canghui.toml` in the application project.
`cuic init` writes a portable starting set:

```toml
[application]
name = "demo"
identifier = "dev.canghui.demo"
version = "0.1.0"
publisher = ""

[assets]
resources = []

[system]
single-instance = true
status-item = false
notifications = true
settings = true

[scripts]
check = ["doctor", "test", "build"]
dev = ["run"]
snapshot-ui = ["prnt --output dist/preview.png"]
```

Run the scripts with either the explicit or shorthand surface:

```bash
cuic scripts list
cuic scripts run check
cuic check
```

Each array item is parsed as an existing `cuic` lifecycle action. The runner injects the owning project and
uses the host platform when a platform is omitted. It does not invoke a shell, so the same manifest works on
macOS, Linux, and Windows and cannot silently become an arbitrary command-execution surface. Current portable
steps are `doctor`, `build`, `test`, `run`, `prnt`, and `clean`.

`cuic package plan` validates identity and project-relative assets, then emits
the stable `canghui.packaging-plan.v0` shape for macOS, Windows or Linux. It is
read-only and does not create bundles, resources, signatures or publications.

`cuic package build` creates an unsigned local artifact in a new project-relative
directory. macOS performs the normal locked build and writes a `.app` bundle;
Windows writes manifest/version-resource inputs; Linux writes desktop-entry and
resource inputs. Every result carries a `canghui.packaging-artifact.v0` receipt.
The macOS receipt is stored under `Contents/Resources` so a downstream signer
does not inherit an unsealed file at the bundle root.
Existing non-empty output directories, absolute output paths and traversal are
rejected. Signing, native runtime closure and publication remain separate gates.

Existing projects can add the default manifest once with `cuic scripts init`. Runtime application state is a
separate concern: `State`, `rememberState`, and `StateStore` are reactive/in-memory facilities, while
`HostApplicationStorage` only supplies host directories. CangHui does not currently expose an
`AppStorage.init()` persistent global key-value implementation, and project script discovery deliberately does
not depend on the application having built or started.

On macOS and Linux use `bin/cuic`. On Windows use `bin\\cuic.cmd` or `bin\\cuic.ps1`.

From a directory containing `cjpm.toml`, bare `cuic run` runs that current
application. Outside a Cangjie project, the same command retains the built-in
`notepad` example fallback. An explicit project or example always wins.

## Framework Resolution

`cuic` resolves CangHui in this order:

1. the repository that owns the integrated `tools/cuic` command
2. `CANGHUI_FRAMEWORK_ROOT`, then the legacy `CANGUI_FRAMEWORK_ROOT`, as explicit development overrides
3. the target project's local path dependency or pinned Git dependency frozen by a matching `cjpm.lock`
4. the CJPM Git cache, normally `$HOME/.cjpm/git/chui/<commit>`
5. a sibling `CangHui/`, then the legacy `CangjieGUI/` alias

The application does not contain a framework copy. `cuic dependency update` is the explicit operation that
delegates dependency resolution to CJPM and writes the lock/cache state. Build, test, run, kMode/probe execution,
snapshot and lifecycle-alias commands fail closed when the lock is absent or differs from the manifest pin; they
do not run an implicit update. `cuic` then prepares the target host's SDL runtime in the resolved cache before
execution.

## Initialization

`init` creates a minimal executable Cangjie application with a public Git dependency pinned by `commitId`,
source entrypoint, runtime-rpath configuration, Git ignore file, and target-platform handoff commands.

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic dependency update
cuic build macos
cuic run macos
```

`cuic dependency update` creates or deliberately refreshes `cjpm.lock`; commit that file with the application
to preserve the exact resolved source. A missing lock or a manifest/lock commit mismatch blocks all build-like
commands until the explicit update succeeds.
Framework development can opt into a local checkout without changing the default consumer model:

```bash
cuic init HelloCangHuiDev --canghui-path ../CangHui
```

## kMode Headless Control

`cuic kmode` invokes CangHui functions without opening a window or traversing the layout tree. Applications
register a top-level `(String) -> String` function with `@KModeLink["stable.endpoint"]` and call
`runKModeStdioIfRequested()` before constructing `DesktopApp`.

```bash
./bin/cuic kmode diff component-gallery
./bin/cuic kmode list component-gallery
./bin/cuic kmode describe component-gallery gallery.viewport.class
./bin/cuic kmode call component-gallery gallery.viewport.class 800
./bin/cuic kmode call mobile-host-replay mobile.demo.host.replay 'player.toggle|4|9'
```

`diff` scans the project, recursive local path dependencies, and the resolved CangHui Git cache. `build`, `test`, and `run` execute the same
preflight automatically. Duplicate names report every source location; the macro-generated symbol and runtime
registry remain additional fail-closed layers.

The CLI sets `CANGHUI_KMODE=1` and `CANGHUI_KMODE_TRANSPORT=stdio` only for the supervised child process.
It does not provide arbitrary shell execution. Optional relay persistence belongs in an external
`KModeChannelModule` implementation; URLs, credentials and sessions are not CLI configuration.
The `mobile-host-replay` consumer demonstrates staged iOS, Android and HarmonyOS
package receipts plus lifecycle/surface-generation callback rejection. Its
`mobile.demo.ios.provider.replay` endpoint binds the checked-in iOS UIKit input
tree through `IOSMobileApplicationHostProvider`. It opens no window and does
not generate or prove an IPA, APK or HAP.

## No-Image Probes

`cuic probe` runs explicit function and component probes through the same supervised child process while keeping
the public `cui.probe.v0` data model independent from kMode transport. Component probes can assert stable trees,
rectangles, semantic state, event routes, callback activation, logical-time animation samples, and Draw IR without
opening a window.

```bash
./bin/cuic probe diff component-gallery
./bin/cuic probe list component-gallery --json
./bin/cuic probe describe component-gallery gallery.primary-button --json
./bin/cuic probe run component-gallery gallery.primary-button \
  --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
  --json
```

The scanner follows recursive local path dependencies plus the resolved framework cache and reports every duplicate source location before the
child build. Macro-generated symbols and the runtime registry remain fail-closed backstops. See
[`manual/reference/probe.md`](../../manual/reference/probe.md) for annotation, scripting, assertion, and report details.

## Platform Matrix

| Platform | doctor | bootstrap | build/test/run | Current boundary |
|---|---:|---:|---:|---|
| macOS | yes | Cangjie-managed Homebrew SDL copy | native host | current arm64 host proven |
| Windows | yes | bundled DLL check | native host | structural preservation; run on Windows for runtime proof |
| Linux | yes | Cangjie-managed pkg-config SDL copy | native host | implementation present; Linux host proof pending |
| iOS | grouped diagnostic | no | static host contracts only | package initialization, signing and renderer return remain blocked |
| HarmonyOS/OpenHarmony | grouped diagnostic | no | external host required | this repository does not ship an ArkTS/HAP host |
| Android | grouped diagnostic | no | Activity/native-surface NDK bootstrap | Cangjie renderer, input/IME, APK packaging and runner not implemented |

The CLI intentionally rejects unconfigured cross-host builds and unsupported Android execution.
`doctor` always displays every platform group, while its exit status considers only global checks and the
requested target. See [`manual/reference/doctor.md`](../../manual/reference/doctor.md) for status, JSON schema, privacy, and CI behavior.

## Fonts

CangHui owns the unmodified HarmonyOS Sans asset and license. Git-based applications use the font from the
resolved framework cache while supervised build/run commands expose it to the renderer, so each project does not
carry another font copy. Local-path initialization retains the project asset copy for framework-development
compatibility. `font install` remains optional; normal supervised rendering does not require host installation.

Recommended macOS installation:

```bash
./bin/cuic font status macos
./bin/cuic font install macos
./bin/cuic font status macos
```

`install` copies the framework-owned font to `~/Library/Fonts/HarmonyOS_Sans_SC.ttf`. Restart running CangHui
applications after installation. Users may instead open the TTF with Font Book or copy it into `~/Library/Fonts/`.

Component, Theme, application, bundled, and system fallback behavior is documented in
[`manual/reference/fonts.md`](../../manual/reference/fonts.md).

## Symbols

`symbol list` reports the adapted provider inventory, frozen upstream revision,
license, aliases, variants, and source paths. `symbol generate` validates those
catalogs and writes a declared-subset registry for an application:

```bash
./bin/cuic symbol list --json
./bin/cuic symbol generate material:add@primary_add ant:check arco:right \
  --output ../../packages/gallery-components/src/gallery_symbols.cj \
  --package canghui_gallery_components
```

Generated export names must be unique across providers. Alias-equivalent
canonical duplicates are rejected. Provider packages remain optional and the
complete upstream icon collections are not bundled. See
[`manual/reference/symbols.md`](../../manual/reference/symbols.md) for registration and fallback rules.

The CLI-owned font is distributed unmodified under the
[HarmonyOS Sans Fonts License Agreement](../../assets/fonts/HARMONYOS_SANS_LICENSE.txt). Its upstream package source is:

```text
https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyManage/011/111/111/0000000000011111111.20260627152129.89276966309836366526585265125586:50001231000000:2800:A0161E048334FE0271F9F5ECBBD5070D17381C7846125F4D7109DBC7B532C715.zip?needInitFileName=true
```

## Window Capture

`prnt` exposes CangHui's renderer-level capture interface. It builds the project, launches the resulting
application executable directly, and injects a `DesktopCaptureRequest` through the host environment.
It does not depend on `cjpm run` forwarding application arguments. The application renders 48 frames,
reads the resolved SDL renderer pixels, writes a BMP, and exits. The CLI can retain BMP or convert it
to PNG with ImageMagick, macOS `sips`, or Windows System.Drawing.

```bash
./bin/cuic prnt macos notepad --output snapshots/notepad.png
./bin/cuic prnt macos ../HelloCangHui -o snapshots/hello.bmp
./bin/cuic prnt macos component-gallery --output snapshots/symbols.png \
  -- --preview desktop --section symbols
./bin/cuic prnt macos component-gallery --output snapshots/reveal.png --frames 12 \
  -- --preview desktop --transition-theme light
```

This captures the application render surface rather than the surrounding desktop and does not require
the operating system's screen-recording permission.

On macOS, `prnt` defaults the captured child process to the Cangjie runtime's
`cjProcessorNum=1`. Cangjie cjthreads use an M:N scheduler, while SDL/AppKit
requires window creation and event polling to stay on one native thread. This
capture-only boundary lets an application launch or wait for child processes
before `DesktopApp.run` without moving SDL polling to another scheduler worker.
An explicitly configured `cjProcessorNum` is preserved for diagnostics. For a
directly launched macOS application that performs blocking startup work after
constructing `DesktopApp`, use `cjProcessorNum=1 cjpm run`; normal background
work should instead prepare immutable results and deliver them through
`DesktopApp.postToUi` after the event loop starts.
