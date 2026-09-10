# 应用 Shell

[English](application-shell.md) | **中文**

`chui.system` 是 CangHui 的系统级应用能力契约。应用身份、资源、Action、设置、
通知、菜单和状态项保留在同一个仓颉模型中；平台 Provider 明确报告对应能力是
native、fallback、permission-required 还是 unsupported。

```cangjie
let manifest = ApplicationManifest(
    AppIdentity("Demo", "dev.example.demo", "1.0.0"),
    actions: [AppAction("file.open", "Open")],
    applicationMenu: Some(AppMenuBar(menus: [
        AppMenu("file", "File", actionIds: ["file.open"])
    ]))
)
let shell = ApplicationShell(manifest)
let surfaces = shell.projectSystemSurfaces()
```

默认的 `HeadlessSystemShellProvider` 用于 kMode、CI 和不支持原生能力的宿主。
它提供确定性回放，但 fallback 或 queued 结果不等于真实系统能力已经完成。

## 稳定 Action 标识

Action 使用 `file.open`、`app.settings`、`app.quit` 这类带分段的稳定 ID。
应用菜单、状态项、通知按钮、应用内命令和 kMode 都引用同一个 ID。重复 ID、
未知引用和同 URI 冲突路由会在进入平台 Provider 前失败。

```cangjie
shell.registerAction(AppAction("app.settings", "Settings"), { => openSettings() })
shell.invokeAction("app.settings")
```

`AppMenuBar` 与 `AppStatusItem` 只保存稳定 Action ID。
`projectSystemSurfaces()` 会通过同一 Provider 边界投影菜单和状态项，并返回
`AppSurfaceProjectionResult`。

## 通知与 Deep Link

通知权限状态包括 `not-determined`、`granted`、`denied`、`not-required` 和
`unsupported`。权限未确定时使用 `requestNotificationPermission()`；其结果会
明确表示 applied、queued、denied 或 unsupported。`notify()` 在权限不允许时
拒绝投递。Headless 回放使用 `not-required` 并记录 queued，不冒充操作系统投递。

Deep Link 使用精确 URI 匹配，不提供通配或前缀匹配：

```cangjie
let route = AppDeepLinkRoute("demo://app/settings", "app.settings")
shell.registerDeepLink(route)
shell.handleDeepLink("demo://app/settings")
```

目标 Action 必须已经声明或注册；真正处理 URI 时还必须存在运行时 handler。
通知携带的 Deep Link 也必须对应已声明或注册的路由。

## 能力状态

| 状态 | 含义 |
| --- | --- |
| `native` | 平台 Provider 已接入真实系统能力。 |
| `fallback` | CangHui 提供可见或无头替代。 |
| `permission-required` | 系统 API 存在，但需要用户授权。 |
| `unsupported` | 当前宿主或 Provider 不支持该能力。 |

公开契约见
[`canghui-application-shell-v0.json`](../../contracts/canghui-application-shell-v0.json)。
工程身份、逻辑资源、确定性规划与无签名产物见
[应用打包](application-packaging.zh-CN.md)，类型化
设置与迁移见[应用设置](application-settings.zh-CN.md)。
