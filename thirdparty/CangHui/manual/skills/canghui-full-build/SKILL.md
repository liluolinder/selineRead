---
name: canghui-full-build
description: Build and validate CangHui Multiplatform from a clean checkout, including chui, sdl, cuic, public docs, version mirrors, and a generated external consumer. Use for release-branch, integration, or full-regression acceptance without claiming platform or device proof that was not replayed.
---

# CangHui Full Build

Use this skill for a release candidate or integration packet that must prove the
public CangHui repository as one unit. Run it from the repository root. Preserve
unrelated user changes and report every skipped platform gate as a gap.

## Preflight

Record the checkout and toolchain before changing or testing anything:

```bash
git status --short --branch
cjc --version
cjpm --version
```

Confirm that `cjpm.toml` declares the root package as `chui`. Read
`README.md`, `manual/index.md`, `manual/getting-started/agent-first-workflow.md`,
and the documents directly related to the change. When the change touches application UI,
also read `manual/guide/how-to/agent-ui-review.md` and prefer cuic ASCII/framework
capture before OS screenshots. Do not infer a successful platform runtime from a
common-source build.

On macOS, prepare missing SDL dependencies with the checked-in bootstrap:

```bash
bash scripts/bootstrap-macos.sh
export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-/opt/homebrew/lib}"
```

Do not copy an unverified dynamic library from an arbitrary build tree.

## Required Gate

Run every command below. Any non-zero exit is a release-candidate failure:

```bash
cjpm build
cjpm test
(cd sdl && cjpm test)
(cd tools/cuic && cjpm test && cjpm build)
bash scripts/test-chui-matrix.sh all
bash tools/cuic/scripts/test-cli.sh
bash tools/cuic/scripts/test-install.sh
bash scripts/audit-network-control-surface.sh
bash scripts/verify-privileged-release-exclusion.sh
python3 manual/skills/canghui-full-build/scripts/audit_public_surface.py
git diff --check
```

Record the actual `TOTAL` and `PASSED` counts from each suite; never copy a
historical count into the receipt.

The release-exclusion gate deliberately builds both release and debug cuic plus
a dedicated CangHui consumer. Release must refuse kMode/probe execution, pview,
debug and device capture even when historical environment/argv opt-ins are
injected; debug must retain the explicit bounded stdio workflow. A source scan
or a release-only green test is not a substitute for this dual proof.

The package matrix discovers every source-owned positive `chui` consumer under
`bench/`, `examples/`, `packages/` and `tools/release-fixtures/`, then builds
and tests it. The discovered `tools/cuic/testdata/duplicate-probe` project is
an intentional negative fixture and remains covered by the CLI smoke. Scene3D
consumers record a native-supply gap when
`CANGHUI_SCENE3D_BGFX_MACOS_NATIVE_DIR` is absent. For any packet that touches
or claims native Scene3D, set `CANGHUI_MATRIX_REQUIRE_NATIVE=1` so that such a
skip fails the gate.

The CLI and install smokes create disposable applications using a local
`[dependencies].chui` path and `import chui.*`. If that step is not available,
create an equivalent disposable consumer outside the repository, build it, and
remove or retain it only according to the caller's cleanup policy.

When a shared `cuic` command is being delivered on the current host, install it
through `scripts/install-cuic.sh` and replay the install smoke with
`CANGHUI_SHARED_CUIC=/absolute/path/to/cuic`. This additionally proves that the
shared binary recognizes and builds the disposable external `chui` consumer;
matching a version string alone is insufficient.

## Conditional Scene3D Native Gate

This gate is required when the change or public claim touches `src/scene3d`,
`packages/scene3d-bgfx`, the native host, shader/geometry resources, or native
3D behavior. It is not part of an ordinary framework build because bgfx4cj
source and native archives remain external optional inputs.

Use an exact bgfx4cj Git checkout and an archive directory accepted by the
checked-in contract. Do not copy archives from an arbitrary build tree or edit
CJPM manifests to make the proof pass. Record both external revisions and run:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/verify-scene3d-bgfx-native-supply.sh \
  /tmp/canghui-scene3d-native-supply.json

BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/verify-scene3d-bgfx-metal-capture.sh \
  /tmp/canghui-scene3d-metal.png \
  /tmp/canghui-scene3d-native-supply.json

BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/verify-scene3d-bgfx-metal-embedded.sh \
  /tmp/canghui-scene3d-metal-embedded.bmp
```

The embedded gate prepares a same-host native pack, tests the checked-in
provider, builds the checked-in consumer manifest and captures it with
`cuic prnt`. It must not copy provider source or synthesize substitute manifests.
The application manifest should contain only its normal `chui` and
`canghui_scene3d_bgfx` dependencies; native archive propagation belongs to the
provider's `[ffi.c]` surface.

For close-lifecycle changes, also replay a normal non-capture loop through an
SDL quit request and require clean detach. A fixed-frame capture is not a
substitute for the normal close path.

When entity scale/rotation or `Scene3DCameraSnapshot` changes, the native capture
must include at least one non-default transform and a non-default camera. A core
unit test alone proves contract shaping, not that the optional driver consumes
the frame values.

Generic provider capture proves the CangHui provider only. A product-level 3D
claim additionally requires a consumer-owned mapping, user entry, fallback,
normal lifecycle, current-session transfer (when a companion window is used),
final artifact launch, and product visual review. Record the consumer revision
and keep product types, meshes and policy out of CangHui.

## Optional Platform Evidence

Only run platform or device steps when they are explicitly in scope and the
required host is available. `cuic device list` is discovery; commands that
install, launch, debug, or capture a device require the caller's authority.

`cuic prnt --device` currently represents the documented system-screenshot
fallback. It does not prove CangHui scene rendering, a complete HarmonyOS host,
store packaging, signing, installation, or LTS readiness. Record those facts as
separate gates.

For UI changes, use deterministic evidence in this order: `cuic pview` or
`cuic probe ascii` for geometry/semantics, `cuic prnt` for framework pixels,
event tests for interaction, then OS/device capture only for platform composition.
Probe/pview execution requires a debug cuic; release refusal is expected and must
not be worked around with historical environment flags.

## Conditional Security And Publisher Gate

When the packet touches kMode, probe execution, cuic debug/capture, channel SPI,
packaging, signing, release scripts or security claims, also run the debug test
variants so the positive developer path and the release refusal path are both
covered:

```bash
cjpm test -g
(cd tools/cuic && cjpm test -g)
```

For a macOS artifact, `cuic package build` remains an unsigned input and its
receipt is not publisher evidence. Before any listing/publisher claim, build
every source-owned Cangjie package with the current toolchain's
`--trimpath <exact-absolute-source-prefix> --strip-all` contract, assemble the
runtime closure, and run:

```bash
./scripts/audit-macos-release.sh --candidate /path/To.app
./scripts/audit-macos-release.sh --publisher /path/To.app
```

The publisher gate must independently prove Developer ID authority, team id,
Hardened Runtime, secure timestamp, safe entitlements, Gatekeeper acceptance
and a stapled notarization ticket. The opt-in
`scripts/sign-notarize-macos.sh` accepts a signing identity label and Keychain
notary-profile reference, never raw credentials on argv. If those publisher
inputs are unavailable, report `source-complete / publisher-incomplete`; do not
weaken or skip the gate. App Store Connect submission/review remains a separate
owner receipt.

## Public Surface Review

The bundled audit script checks Markdown links, internal-path leakage, skill
metadata, the `chui` public roots, version mirrors in the manifest, README
badges, manual and built-in Symbol provider. It also rejects the retired
`docs/` root and internal governance matrices if they reappear in the public
repository. Review its result together with the actual diff; automated text
checks do not replace API or platform-boundary judgment.

Before closeout, also confirm that active Cangjie source files remain below the
repository's 4000-line guard and that compatibility identifiers such as
`cui.probe.v0`, `CUI_*`, `cuic`, and `--cui-path` were not renamed merely for
branding consistency.

## Receipt

Return a compact receipt containing:

- branch and exact commit;
- `cjc` and `cjpm` versions plus host target;
- build and suite results with actual counts;
- public-audit and CLI-smoke results;
- source network/control audit and release/debug privileged-channel replay;
- release and debug test totals for security/control-plane packets;
- conditional Scene3D native supply, Metal capture and consumer evidence when
  the packet touches native 3D;
- macOS candidate/publisher audit results, or the exact external signing,
  notarization and store gaps;
- platform/device steps replayed or explicitly not replayed;
- remaining release, signing, runtime, or consumer gaps.

Do not create a tag, merge a hosted branch, change dependencies, or publish a
release unless the caller separately authorized that action.
