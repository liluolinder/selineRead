# Typed Application Settings

**English** | [中文](application-settings.zh-CN.md)

The `chui.system` settings layer separates a typed application schema from the
storage provider. An ordinary provider may offer a framework fallback; a
sensitive setting requires a provider that reports native `secure` storage.

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

## Provider boundary

`AppSettingsProvider` owns values and the persisted schema version. It reports
`ordinary` and `secure` storage separately and supports idempotent removal.
`HeadlessSettingsProvider` is an in-memory fallback for kMode, CI and unsupported
hosts. It never claims native secure storage.

`AppSettingsRuntime` owns the public schema rules:

- reads return the declared default only when no provider value exists;
- writes reject unknown keys and values with the wrong type;
- sensitive reads and writes fail closed without native secure storage;
- migrations advance through explicit, increasing schema versions;
- a migration can rename a key and transform its typed value;
- missing migration steps, newer stored schemas and ambiguous branches fail
  without pretending the schema is current.

## Migration

```cangjie
let result = runtime.migrate([
    AppSettingMigration(
        "demo.settings", 0, 1, "appearance.mode",
        targetKey: "appearance.theme"
    )
])
```

Migration results include the original version, resulting version, changed keys
and a typed status. The headless provider is useful for semantic replay, but it
does not prove Keychain, Windows Credential Manager, XDG secret storage or any
other native persistence backend.

The public shape is recorded in
[`canghui-application-settings-v0.schema.json`](../../contracts/canghui-application-settings-v0.schema.json).
