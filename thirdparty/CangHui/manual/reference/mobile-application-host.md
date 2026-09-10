# Mobile Application Host

**English** | [中文](mobile-application-host.zh-CN.md)

`canghui.mobile-application-host.v0` is the common boundary between CangHui and
an iOS, Android or HarmonyOS application host. It complements the existing
lifecycle, viewport, touch, storage and native-surface contracts; it does not
replace the platform SDK or generate a store-ready package.

## Provider boundary

Each platform provider implements `MobileApplicationHostProvider` and reports:

- platform and package kind;
- current application lifecycle and lifecycle epoch;
- current native-surface generation;
- permission state for requested host capabilities, retained in the receipt;
- the highest package evidence stage actually reached.

Native callbacks carry `MobileHostCallbackContext`. A callback is accepted only
when both its lifecycle epoch and surface generation match the current receipt.
This prevents a recreated scene, Activity, Ability or native surface from
delivering an old action into the current Cangjie UI owner queue.

## Evidence stages

| Stage | Meaning | Explicit non-claim |
| --- | --- | --- |
| `contract-ready` | The provider can consume the public contract. | No package input tree exists. |
| `input-tree` | Platform metadata, assets and native inputs exist. | The result is not installable. |
| `signed-package` | A platform package has valid signing evidence. | No physical-device runtime is proven. |
| `device-proven` | The signed package passed a recorded device replay. | Store publication and production readiness remain separate. |

The public transition predicate permits only one forward step, and a Provider
must reject rollback when applying a new receipt. `MobileHostPackageReceipt`
rejects a package kind that does not match its platform, an empty input tree
after the first stage, duplicate capability permission entries, unsigned
installability claims and device claims without a passed device replay. The
JSON schema carries the same stage prerequisites; cross-item duplicate
permission checks remain runtime validation.

## Current platform state

- iOS/iPadOS has a UIKit `CAMetalLayer` native-surface adapter and historical
  simulator/device bootstrap proof. `IOSMobileApplicationHostProvider` now binds
  the existing iOS input tree to the receipt and rejects lifecycle/surface-stale
  receipt replay. A fresh time-valid development profile has also passed a
  physical-device `devicectl` installation. After device trust was enabled, the
  same probe launched and reported a ready Metal drawable, 31 clear frames,
  detach/reattach generation replay and synthetic touch, pointer and trait
  ingress. Those facts prove the static-package probe only; the full declarative
  CangHui scene and product acceptance remain open. The verification script accepts both the macOS
  `security cms` decoder and an `openssl smime` compatibility fallback without
  copying profile contents into project evidence.
- Android has a Java/JNI/NDK `SurfaceView` bootstrap. Cangjie Android runtime
  linkage, a product APK and device replay remain open.
- HarmonyOS consumes the same contract through an independently implemented
  Ability/XComponent or OHNativeWindow provider. This repository does not ship
  an ArkTS project or HAP and therefore does not claim HarmonyOS runtime proof.

Run `cuic doctor ios`, `cuic doctor android` or `cuic doctor harmonyos` to see
the local toolchain facts together with this common provider boundary.

## Headless semantic replay

`canghui.mobile-host-replay.v0` renders a staged receipt together with callback
acceptance decisions without opening a window. `mobileHostReplayHandler`
accepts zero or more payload lines in the form
`actionId|lifecycleEpoch|surfaceGeneration`. It reports `current`,
`stale-lifecycle`, `stale-surface` or `stale-lifecycle-and-surface` for each
callback and preserves the receipt's unsigned, signing and device-proof facts.

Consumers should wrap the handler in their own `@KModeLink` function. This
keeps endpoint ownership in the application and lets `cuic kmode diff` reject
duplicate names across the dependency graph. Runtime replay requires a debug
build (`cjpm -g`); release applications retain no executable kMode route. The
`examples/mobile-host-replay` project demonstrates the pattern and carries
unsigned iOS, Android and HarmonyOS input-tree fixtures. It does not generate
an IPA, APK or HAP and does not turn headless replay into device proof.

The example also exposes `mobile.demo.ios.provider.replay`. It stages the
checked-in UIKit probe, bootstrap, runtime and include files through
`IOSMobileApplicationHostProvider`, then reports the same current/stale callback
decisions. The endpoint is a semantic input-tree proof only; it does not run
UIKit, Metal, Xcode signing or an iPad.

## External signer preparation

`canghui.mobile-signing-preparation.v0` creates a non-secret handoff receipt
from an unsigned `input-tree`. The request contains only an output name and
opaque capability labels such as `ios-signing-identity` and
`ios-provisioning-profile`; it accepts no certificate, key, profile contents,
passwords, shell commands or paths. A complete declaration becomes
`requirements-satisfied`, while missing labels remain `blocked`. This state
does not assert that the current host actually owns a valid signing identity;
`cuic doctor` and the platform signer remain authoritative for that fact.

Preparation never advances the mobile package receipt. Its JSON always reports
`signedPackage=false` and `installable=false`; Xcode or another platform-owned
signer must produce independently verified signing evidence before the common
receipt can advance to `signed-package`.

## External signer receipt binding

`canghui.mobile-external-signer-receipt.v0` binds opaque signer metadata to the
preparation output name, lifecycle epoch, native-surface generation and bounded
source binding. It validates a `sha256:` artifact digest shape and rejects stale
or mismatched bindings. The accepted state means only that the receipt matches
the current preparation contract; it does not verify signature bytes, execute a
signer, or advance `MobileHostPackageReceipt`. The common receipt remains at
`input-tree` until a platform owner independently verifies the signed package.

## Signed package evidence

`canghui.mobile-signed-package-evidence.v0` is the next explicit gate. A
platform owner supplies bounded labels for the verifier tool, verification
policy and verification receipt, plus the verified artifact size and the same
`sha256:` digest, output name and source binding carried by the accepted signer
receipt. CangHui rejects failed outcomes, stale lifecycle or surface facts,
digest/output mismatches and receipts that are not rooted in the current
unsigned input tree.

An `applied` receipt may advance `MobileHostPackageReceipt` from `input-tree`
to `signed-package`. `IOSMobileApplicationHostProvider` refuses a direct
input-tree-to-signed transition through `applyPackageReceipt`; platform code
must use `applySignedPackageEvidence` for this stage. CangHui still does not
run `codesign`, `apksigner`, a HAP signer or their verification commands.

At this stage `installable=true` means only that the artifact is eligible for
an installation attempt. The receipt explicitly keeps
`installationProven=false` and `deviceProven=false`; installation, launch,
rendering and physical-device replay are later and independent evidence.

## Installation attempt receipt

`canghui.mobile-installation-attempt.v0` records one result reported by a
platform-owner-controlled installer boundary. The request repeats the signed
artifact output name, `sha256:` digest and size, then adds bounded opaque labels
for the platform owner, target device class, installer tool, installation
policy and external receipt ID. It deliberately does not accept a device UDID,
filesystem path, command line, credential or package bytes.

The receipt is `recorded` only when the current package remains at
`signed-package` and the applied signed-package evidence still matches the
application identity, lifecycle epoch, native-surface generation and exact
predecessor input tree. A matched `failed` outcome records the failed attempt
without proving installation. A matched `installed` outcome may report
`installationProven=true`, but it does not advance `MobileHostPackageReceipt`.

CangHui does not execute or independently verify the installer. Every
installation receipt therefore keeps `launchProven=false`,
`renderingProven=false` and `deviceProven=false`. Launch observation, rendered
surface evidence and semantic device replay require later independent receipts.
