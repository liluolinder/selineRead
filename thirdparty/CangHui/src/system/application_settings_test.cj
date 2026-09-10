package chui.system

@Test
func appSettingsRuntimeUsesDefaultsAndRejectsTypeOrSecureDowngrade(): Unit {
    let provider = HeadlessSettingsProvider()
    let runtime = AppSettingsRuntime(
        AppSettingsSchema("demo.settings", 1),
        [
            AppSetting("appearance.dark", AppSettingValue.Boolean(false)),
            AppSetting("account.token", AppSettingValue.Text(""), sensitive: true)
        ],
        provider
    )
    @Expect(runtime.capability(AppSettingStorage.Ordinary), SystemSurfaceState.Fallback)
    @Expect(runtime.capability(AppSettingStorage.Secure), SystemSurfaceState.Unsupported)
    match (runtime.read("appearance.dark")) {
        case Some(AppSettingValue.Boolean(value)) => @Expect(!value)
        case _ => @Fail("ordinary default was not readable")
    }
    let wrongType = runtime.write("appearance.dark", AppSettingValue.Text("true"))
    @Expect(wrongType.status, SystemShellResultStatus.Failed)
    @Expect(runtime.write("appearance.dark", AppSettingValue.Boolean(true)).ok())
    match (runtime.read("appearance.dark")) {
        case Some(AppSettingValue.Boolean(value)) => @Expect(value)
        case _ => @Fail("ordinary provider value was not retained")
    }
    @Expect(runtime.read("account.token").isNone())
    @Expect(runtime.write("account.token", AppSettingValue.Text("secret")).status,
        SystemShellResultStatus.Unsupported)
}

@Test
func appSettingsRuntimeMigratesOrderedRenamesAndPersistsSchemaVersion(): Unit {
    let provider = HeadlessSettingsProvider()
    @Expect(provider.write("appearance.mode", AppSettingValue.Text("dark")).ok())
    let runtime = AppSettingsRuntime(
        AppSettingsSchema("demo.settings", 2),
        [AppSetting("appearance.theme", AppSettingValue.Text("light"))],
        provider
    )
    let result = runtime.migrate([
        AppSettingMigration(
            "demo.settings", 0, 1, "appearance.mode", targetKey: "appearance.theme"
        ),
        AppSettingMigration(
            "demo.settings", 1, 2, "appearance.theme", transform: {value =>
                match (value) {
                    case AppSettingValue.Text(text) => AppSettingValue.Text(text + "-v2")
                    case _ => value
                }
            }
        )
    ])
    @Expect(result.ok())
    @Expect(result.fromVersion, Int64(0))
    @Expect(result.toVersion, Int64(2))
    @Expect(result.changedKeys.size, Int64(2))
    @Expect(provider.schemaVersion(), Int64(2))
    @Expect(!provider.contains("appearance.mode"))
    match (runtime.read("appearance.theme")) {
        case Some(AppSettingValue.Text(value)) => @Expect(value, "dark-v2")
        case _ => @Fail("migrated setting was not readable")
    }
}

@Test
func appSettingsRuntimeStopsAtMissingMigrationAndNewerStoredSchema(): Unit {
    let missing = HeadlessSettingsProvider()
    let missingRuntime = AppSettingsRuntime(
        AppSettingsSchema("demo.settings", 2),
        [AppSetting("appearance.theme", AppSettingValue.Text("light"))],
        missing
    )
    let missingResult = missingRuntime.migrate([
        AppSettingMigration("demo.settings", 1, 2, "appearance.theme")
    ])
    @Expect(missingResult.status, SystemShellResultStatus.Failed)
    @Expect(missing.schemaVersion(), Int64(0))

    let newer = HeadlessSettingsProvider()
    @Expect(newer.setSchemaVersion(3).ok())
    let newerRuntime = AppSettingsRuntime(
        AppSettingsSchema("demo.settings", 2),
        [AppSetting("appearance.theme", AppSettingValue.Text("light"))],
        newer
    )
    @Expect(newerRuntime.migrate([]).status, SystemShellResultStatus.Failed)
}

@Test
func appSettingsRuntimeRefusesSecureMigrationWithoutNativeProvider(): Unit {
    let provider = HeadlessSettingsProvider()
    @Expect(provider.write("account.token", AppSettingValue.Text("opaque")).ok())
    let runtime = AppSettingsRuntime(
        AppSettingsSchema("demo.settings", 1),
        [AppSetting("account.token", AppSettingValue.Text(""), sensitive: true)],
        provider
    )
    let result = runtime.migrate([
        AppSettingMigration("demo.settings", 0, 1, "account.token")
    ])
    @Expect(result.status, SystemShellResultStatus.Unsupported)
    @Expect(provider.schemaVersion(), Int64(0))
}

@Test
func headlessIdentityProviderReportsFallbackAndQueuedApply(): Unit {
    let initial = AppIdentity("Demo", "dev.example.demo", "1.0.0")
    let provider = HeadlessApplicationIdentityProvider(initial)
    @Expect(provider.state(), SystemSurfaceState.Fallback)
    @Expect(provider.current().version, "1.0.0")
    @Expect(provider.apply(AppIdentity("Demo", "dev.example.demo", "2.0.0")).status,
        SystemShellResultStatus.Queued)
    @Expect(provider.current().version, "2.0.0")
}
