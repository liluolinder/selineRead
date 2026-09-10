# Multiplatform Doctor

**English** | [中文](doctor.zh-CN.md)

`cuic doctor` reports CangHui development readiness without implying that every
listed platform is implemented or validated on the current host.

```bash
./tools/cuic/bin/cuic doctor
./tools/cuic/bin/cuic doctor macos --verbose
./tools/cuic/bin/cuic doctor ios --json
```

The optional target accepts `macos`, `windows`, `linux`, `ios`, `harmonyos`, or
`android`. When omitted, it defaults to the current host platform. Every report
still includes all platform groups so missing cross-platform work remains
visible.

## Status Model

| Status | Meaning |
|---|---|
| `ready` | The check is available and passed on this host. |
| `degraded` | The capability remains usable or inspectable, but a non-blocking part is incomplete. |
| `blocked` | The requested target cannot proceed until the reported requirement is repaired. |
| `unsupported` | This CangHui version or the current host cannot perform the capability. |

Repair actions are classified as `automatic`, `manual`, `unsupported`, or
`none`. Human output shows the action next to each affected check.

## Exit Status

The process returns a nonzero status only when a global check or the explicitly
requested target contains `blocked` or `unsupported` checks. A limitation in an
unrequested platform remains visible but does not fail an otherwise usable
host workflow. `degraded` never fails the command by itself.

For an application with a Git dependency, the global project group is blocked
when `cjpm.lock` is missing or its CangHui commit differs from the manifest.
Run `cuic dependency update` only after reviewing the manifest pin; doctor and
build-like commands never repair the lock implicitly.

This makes the following pattern suitable for CI:

```bash
./tools/cuic/bin/cuic doctor macos --json > doctor.json
```

The JSON document follows
[`canghui.doctor.v0`](../../contracts/canghui-doctor-v0.schema.json). Without
`--verbose`, every `evidence` field is an empty string. Verbose mode may include
tool versions and filesystem locations, but signing identities and connected
device identities are summarized rather than emitted.

New reports include `cliProvenance` beside the stable `cliVersion`. Its
`channel` is `development`, `local-source`, or `release`; `revision` is an exact
Git commit for installed artifacts, carries `+dirty` for a local-source build
with uncommitted input, or is the honest `unembedded` marker for a direct
repository build. The field is optional in the v0 schema so previously stored
reports remain valid.

## Check Groups

The report covers:

- Cangjie compiler and package-manager availability;
- repository, package, and integrated CLI alignment;
- macOS, Windows, Linux, iOS, HarmonyOS/OpenHarmony, and Android readiness;
- SDL runtime or development-library availability where applicable;
- bundled HarmonyOS Sans and its license receipt;
- Symbol core, optional providers, and on-demand generation;
- kMode and `cui.probe.v0` duplicate-registry health.

Signing and connected-device commands run only when `ios` or `harmonyos` is
explicitly requested. This keeps the default desktop diagnosis bounded and
predictable.

The iOS group reports the static-package bootstrap and native-surface adapter
separately. The current adapter includes the integer-only C ABI, UIKit
`CAMetalLayer`, lifecycle and safe-area ingress, touch forwarding,
`CADisplayLink`, generation-gated detach/reattach replay, and a simulator/device
verifier. Full CangHui scene rendering, IME, accessibility, application
packaging and product acceptance remain separate platform work.

Set `CANGHUI_IOS_HOME` or `CANGJIE_IOS_HOME` when the iOS SDK is installed outside
the default `/Library/Frameworks/Cangjie/1.3.0-alpha-ios` location.
