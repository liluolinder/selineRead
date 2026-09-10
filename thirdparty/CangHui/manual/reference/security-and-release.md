# Security And Release Provenance

**English** | [中文](security-and-release.zh-CN.md)

CangHui separates developer inspection from distributable application
behavior. This boundary is enforced by compiler conditions and independently
replayed against final executables; an environment variable is not a release
security boundary.

## Privileged developer surface

| Surface | Release build | Debug build (`-g`) |
| --- | --- | --- |
| application kMode stdio entry | always refuses, including historical env/argv opt-ins | available only after an explicit stdio request |
| explicit `KModePolicy(enabled: true)` | clamped to disabled | capability policy applies |
| `KModeChannelModule` override | refuses | admin policy required; the module still owns transport authentication |
| `cuic kmode` / `probe` execution and `pview` | refuses | available |
| one-shot `cuic shell` UI event script | refuses; app opt-in/result markers are absent | fixed debug-child whitelist; exits after use |
| `cuic debug` and `prnt --device/--app` | refuses | available where the platform route is implemented |
| `kmode diff` / `probe diff` | static source collision check remains available | available |

The repository does not ship a socket, listener, remote relay implementation
or `KModeChannelModule` implementation. The channel interface is a
transport-neutral SPI, not a hidden transport. A future remote module must own
claim verification, identity binding, replay prevention, capability scope,
rate/buffer limits and secret redaction, then pass a separate native-platform
security review. Locality, loopback and a device forward are not
authentication.

`cuic shell` is not another transport. It does not attach to an arbitrary PID,
read a command stream from stdin, listen on a socket/pipe, or interpret shell
text. cuic gives only the debug child it starts a whitelist script bounded to
128 commands and 64 KiB. The app routes ordinary hit/focus/key events, emits a
structured observation, and exits.

cuic also keeps host execution and diagnostics out of the shell-text boundary.
Windows build arguments and environment are passed separately to `cjpm`, so
project-controlled `cmd.exe` metacharacters are not expanded as a second
command. Verbose doctor evidence conservatively redacts absolute host paths,
credential-bearing URLs, secret/key/token/cookie shapes and local identities.

Run both source and binary gates:

```bash
./scripts/audit-network-control-surface.sh
./scripts/verify-privileged-release-exclusion.sh
```

The second command builds release and debug variants of cuic and a dedicated
consumer fixture. It proves the release application ignores the old
`CANGHUI_KMODE` / transport / argv route while the debug fixture can still
complete a bounded health/shutdown stdio replay.

## Reverse engineering and modified copies

Source-level gates do not make machine code impossible to inspect or patch.
They remove the privileged path from the authentic release execution policy.
Publisher signing, Hardened Runtime and notarization then make replacement,
injection and untrusted redistribution detectable and rejectable by macOS.
They do not prevent an attacker from creating a separately signed or unsigned
fork and persuading someone to run it. Distribution identity, download hashes
and update-channel ownership remain product responsibilities.

## Release compiler contract

Every source-built Cangjie executable and source dependency must be compiled
with the current toolchain's release options:

```text
--trimpath <exact-absolute-source-prefix> --strip-all
```

`--trimpath` requires the actual absolute prefix used by that build and is not
a portable value to commit to a public `cjpm.toml`. Options on one root package
do not prove that independently built or cached dependencies were trimmed.
Build automation must apply the rule to every source-owned package, then audit
the assembled artifact. CangHui deliberately fails the candidate gate when a
developer path, release kMode opt-in or excessive application symbol table
remains.

## macOS evidence chain

`cuic package build` produces an unsigned input artifact. Its receipt now states
that trim/strip, the release security audit and publisher signing/notarization
have not been verified. For a real Developer ID distribution:

1. build the complete application/runtime closure with the compiler contract;
2. run the candidate audit;
3. sign nested Mach-O code and the app with Hardened Runtime and secure
   timestamp;
4. submit through a keychain notary profile, staple the ticket, then run the
   publisher audit.

```bash
./scripts/audit-macos-release.sh --candidate dist/MyApp.app

CANGHUI_DEVELOPER_ID_APPLICATION='Developer ID Application: Publisher (TEAMID)' \
CANGHUI_NOTARY_PROFILE='notary-keychain-profile' \
./scripts/sign-notarize-macos.sh dist/MyApp.app

./scripts/audit-macos-release.sh --publisher dist/MyApp.app
```

The signing command accepts only an identity label and a Keychain profile
reference. It does not accept a password, private key or API secret on argv.
The publisher audit verifies deep/strict code signature validity, Developer ID
authority, team identity, Hardened Runtime, secure timestamp, dangerous
entitlement absence, Gatekeeper assessment, stapled notarization, runtime paths,
source-path leakage, release debug markers and application symbol posture.

Developer ID notarization proves a direct-distribution artifact. App Store
Connect submission, store review and publication are separate owner receipts
and are never inferred from this gate.
