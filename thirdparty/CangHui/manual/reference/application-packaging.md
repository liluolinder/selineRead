# Application Packaging

**English** | [中文](application-packaging.zh-CN.md)

`canghui.toml` is the project-side declaration for application identity, logical
assets and system-surface policy. The declaration is consumed by `cuic` and is
kept separate from platform-specific providers.

## Minimal declaration

```toml
[application]
name = "Demo"
identifier = "dev.example.demo"
version = "1.0.0"
publisher = "Celading"

[assets]
application-icon = "assets/app.png"
resources = ["assets/data", "assets/i18n"]

[system]
single-instance = true
status-item = true
notifications = true
settings = true
```

Asset paths are project-relative. Absolute paths, `~`, `..` traversal,
symbolic links anywhere in a declared asset tree, and missing declared files
are rejected. The recursive symbolic-link check prevents a resource directory
from importing files outside the project during packaging. Logical asset roles are declared once;
`cuic` does not guess a status or notification icon from the application icon.
The application name must also be a portable artifact name: Windows-reserved
characters, device names and leading or trailing spaces/dots are rejected.

## Deterministic plan

Run:

```text
cuic package plan macos .
cuic package plan windows . --json
cuic package plan linux . --json
```

The command validates the manifest and prints a stable plan containing identity,
input assets, intended generated files, provider state and signing gates. It is
a plan-only operation: it does not build an application bundle, generate a
Windows resource, sign an artifact or publish a package. Those operations remain
later provider and release stages.

The same manifest and target produce the same plan fields. `project` is included
in JSON as evidence of the resolved input project; consumers should treat paths
inside the plan as project-relative unless a tool explicitly documents otherwise.

## Unsigned artifact generation

```text
cuic package build macos .
cuic package build windows . --output dist/windows-input --json
cuic package build linux . --output dist/linux-input --json
```

`package build` writes a bounded unsigned artifact and a
`canghui-packaging-receipt.json` using the
`canghui.packaging-artifact.v0` schema. On macOS the receipt is sealed inside
`Contents/Resources`; Windows and Linux keep it at the artifact root. The default destination is
`dist/<Name>.app` on macOS and `dist/<Name>` on Windows or Linux. `--output`
accepts one project-relative directory. Traversal, absolute destinations and
non-empty output directories are rejected, so the command never replaces an
existing artifact implicitly. The output may not be nested inside a declared
resource directory, which prevents a generated artifact from recursively
copying itself into its own resource tree.

On a macOS host, the macOS route first runs the normal locked `cuic build`
pipeline and copies the resulting executable into `Contents/MacOS`. The bundle
also contains `Info.plist`, `PkgInfo`, declared resources and logical icon-role
assets. Keeping the receipt under `Contents/Resources` avoids adding unsealed
files to the `.app` root when a downstream release gate signs the bundle. The receipt deliberately records that native runtime dependencies are
still host-managed and that the unsigned bundle has not been launched. It also
records that release trim/strip, the release security audit and publisher
signing/notarization have not been verified.

Windows and Linux routes are cross-host-safe input generators. They do not
pretend to cross-compile an executable:

- Windows receives an executable manifest, version-resource source,
  AppUserModelID, declared assets and resources.
- Linux receives a desktop entry, `share/applications`, an icon tree and
  application resource tree.

Icon bytes are never relabelled as another format. A real `.icns` or `.ico`
uses the native destination name; PNG, SVG and other inputs keep their original
extension and remain visible as a conversion or provider gate.

## Platform boundary

- macOS can generate an unsigned local `.app`; signing, notarization,
  self-contained runtime closure and launch acceptance remain gated.
- Windows generates resource/compiler inputs; a PE executable, compiled
  resources, signing and MSIX publication remain gated.
- Linux generates a desktop/package input tree; native-host executable replay,
  system installation, tray and notification behavior remain gated.

`cuic doctor` reports whether the declaration and all referenced assets are
ready and whether both packaging schemas are present, but readiness is not
runtime or release proof.

For the release compiler contract, privileged-channel negative replay,
Developer ID/Hardened Runtime signing and notarization gates, see
[Security And Release Provenance](security-and-release.md). An unsigned
`package build` receipt is never publisher or store evidence.

Mobile hosts use a separate staged receipt because a platform input tree,
signed package and device replay are different facts. See
[Mobile Application Host](mobile-application-host.md) and
`canghui-mobile-host-package-v0.schema.json`.
