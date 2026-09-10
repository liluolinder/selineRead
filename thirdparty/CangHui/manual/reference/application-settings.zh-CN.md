# 类型化应用设置

[English](application-settings.md) | **中文**

`chui.system` 将类型化应用设置 schema 与存储 provider 分离。普通 provider
可以提供框架 fallback；敏感设置必须使用报告为 native 的 secure provider。

```cangjie
let runtime = AppSettingsRuntime(
    AppSettingsSchema("demo.settings", 2),
    [
        AppSetting("appearance.theme", AppSettingValue.Text("system")),
        AppSetting("account.token", AppSettingValue.Text(""), sensitive: true)
    ],
    HeadlessSettingsProvider()
)
```

## Provider 边界

`AppSettingsProvider` 负责值和持久化 schema 版本，并分别报告 ordinary 与
secure 存储状态。`HeadlessSettingsProvider` 用于 kMode、CI 和不支持原生能力
的宿主，它是内存 fallback，不会冒充原生 secure 存储。

`AppSettingsRuntime` 负责公开 schema 规则：

- provider 没有值时才读取声明的默认值；
- 未知 key 和类型不匹配的值会被拒绝；
- 没有 native secure storage 时，敏感值读写都会 fail-closed；
- 迁移必须沿显式、递增的 schema 版本执行；
- 迁移可以重命名 key 并转换类型兼容的值；
- 缺失迁移步骤、存储版本更新或存在歧义分支时失败，不会伪装成已完成。

迁移结果会记录起始版本、目标版本、变更 key 和类型化状态。headless provider
只适合语义回放，不证明 Keychain、Windows Credential Manager、XDG secret
storage 或其他原生持久化后端。

公开契约见
[`canghui-application-settings-v0.schema.json`](../../contracts/canghui-application-settings-v0.schema.json)。
