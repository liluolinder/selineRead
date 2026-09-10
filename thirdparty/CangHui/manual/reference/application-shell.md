# Application Shell

**English** | [中文](application-shell.zh-CN.md)

`chui.system` is the CangHui contract for system-level application behavior.
It keeps application identity, assets, actions, settings and notifications in
one Cangjie model while platform providers decide whether a system surface is
native, a framework fallback, permission-gated or unsupported.

```cangjie
let manifest = ApplicationManifest(
    AppIdentity("Demo", "dev.example.demo", "1.0.0"),
    assets: [AppAsset(AppAssetRole.ApplicationIcon, "assets/demo.icns")],
    actions: [AppAction("file.open", "Open")],
    applicationMenu: Some(AppMenuBar(menus: [
        AppMenu("file", "File", actionIds: ["file.open"])
    ]))
)
let shell = ApplicationShell(manifest)
let surfaces = shell.projectSystemSurfaces()
let permission = shell.notificationPermission()
let result = shell.notify(SystemNotification("ready", "Ready"))
```

The default `HeadlessSystemShellProvider` is deterministic and is intended for
kMode, CI and unsupported-host probes. Native providers are implemented by
platform adapters; a fallback result is not a native runtime claim.

## Stable Action Identity

Actions use dotted IDs such as `file.open`, `app.settings` and `app.quit`.
The same ID is the join key for native menus, status-item menus, keyboard
shortcuts, in-window command palettes and kMode. Providers must reject duplicate
IDs rather than silently replacing a callback.

`AppMenuBar` and `AppStatusItem` contain only stable action IDs. Calling
`projectSystemSurfaces()` sends both declared surfaces through the same provider
boundary and returns an `AppSurfaceProjectionResult`. Headless hosts record the
projection as `queued`; a real native menu or status item is only claimed by a
platform provider with a host replay.

Runtime handlers remain Cangjie functions:

```cangjie
shell.registerAction(AppAction("app.settings", "Settings"), { => openSettings() })
shell.invokeAction("app.settings")
```

Sensitive settings are never downgraded into the headless fallback. They require
a provider that reports native `secure-settings` support.

## Notifications and Deep Links

Notification permission is explicit: `not-determined`, `granted`, `denied`,
`not-required` or `unsupported`. `notify()` returns a typed result and refuses
delivery before permission is granted. Headless replay uses `not-required` and
queues the notification without claiming an OS delivery.

Use `requestNotificationPermission()` when the state is `not-determined`; the
returned result records whether the request was applied, queued, denied or
unsupported.

Deep links use exact routes rather than wildcard or prefix matching:

```cangjie
let route = AppDeepLinkRoute("demo://app/settings", "app.settings")
shell.registerDeepLink(route)
shell.handleDeepLink("demo://app/settings")
```

The target action must be declared or registered, and a runtime handler must be
present before the link can invoke application code. Duplicate URIs and unknown
actions fail closed.

## Capability States

| State | Meaning |
| --- | --- |
| `native` | The platform provider owns the real system surface. |
| `fallback` | CangHui can provide a visible or headless substitute. |
| `permission-required` | The API exists but needs user authorization. |
| `unsupported` | The current host/provider cannot provide the surface. |

The public contract is recorded in
[`canghui-application-shell-v0.json`](../../contracts/canghui-application-shell-v0.json).
Project-side identity and logical assets are declared in `canghui.toml`; see
the [application packaging guide](application-packaging.md) for validation,
deterministic planning and unsigned macOS, Windows and Linux artifact inputs.
Typed storage and schema
migration are described in [application settings](application-settings.md).
