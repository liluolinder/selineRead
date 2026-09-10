package chui.system

class ApplicationShellTestCounter {
    var value: Int64 = 0
}

@Test
func applicationManifestValidatesActionsSettingsAssetsAndStatusReferences(): Unit {
    let manifest = ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        assets: [AppAsset(AppAssetRole.ApplicationIcon, "assets/demo.icns")],
        actions: [AppAction("file.open", "Open")],
        settings: [AppSetting("appearance.dark", AppSettingValue.Boolean(false))],
        applicationMenu: Some(AppMenuBar(menus: [
            AppMenu("file", "File", actionIds: ["file.open"])
        ])),
        statusItem: Some(AppStatusItem("Demo", actionIds: ["file.open"]))
    )
    @Expect(validateApplicationManifest(manifest).isEmpty())
}

@Test
func applicationManifestRejectsDuplicateAndUnknownDeclarations(): Unit {
    let manifest = ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        assets: [
            AppAsset(AppAssetRole.ApplicationIcon, "assets/demo.icns"),
            AppAsset(AppAssetRole.ApplicationIcon, "assets/demo-2.icns")
        ],
        actions: [AppAction("file.open", "Open"), AppAction("file.open", "Open again")],
        settings: [
            AppSetting("appearance.dark", AppSettingValue.Boolean(false)),
            AppSetting("appearance.dark", AppSettingValue.Boolean(true))
        ],
        applicationMenu: Some(AppMenuBar(menus: [
            AppMenu("file", "File", actionIds: ["missing.menu.action"])
        ])),
        statusItem: Some(AppStatusItem("Demo", actionIds: ["missing.action"]))
    )
    let errors = validateApplicationManifest(manifest)
    @Expect(errors.size, 5)
}

@Test
func headlessSystemShellKeepsActionNotificationAndSettingsSemantics(): Unit {
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        actions: [AppAction("app.open", "Open")],
        settings: [AppSetting("appearance.dark", AppSettingValue.Boolean(false))],
        applicationMenu: Some(AppMenuBar(menus: [
            AppMenu("app", "Application", actionIds: ["app.open"])
        ])),
        statusItem: Some(AppStatusItem("Demo", actionIds: ["app.open"]))
    ),
        provider: provider)
    @Expect(shell.capability(SystemSurface.StatusItem), SystemSurfaceState.Fallback)
    @Expect(shell.notificationPermission(), NotificationPermissionState.NotRequired)
    let invoked = ApplicationShellTestCounter()
    @Expect(shell.registerAction(AppAction("app.open", "Open"), { => invoked.value += 1 }).ok())
    @Expect(shell.invokeAction("app.open").ok())
    @Expect(invoked.value, 1)
    @Expect(shell.notify(SystemNotification("notice", "Ready")).status, SystemShellResultStatus.Queued)
    @Expect(shell.writeSetting("appearance.dark", AppSettingValue.Boolean(true)).ok())
    match (shell.readSetting("appearance.dark")) {
        case Some(AppSettingValue.Boolean(value)) => @Expect(value)
        case _ => @Fail("headless setting was not retained")
    }
    @Expect(provider.actionCount(), 1)
    @Expect(provider.notificationCount(), 1)
    let projection = shell.projectSystemSurfaces()
    @Expect(projection.ok())
    @Expect(provider.applicationMenuCount(), 1)
}

@Test
func applicationShellNotificationPermissionGatesDelivery(): Unit {
    let pendingProvider = HeadlessSystemShellProvider(
        notificationPermission: NotificationPermissionState.NotDetermined
    )
    let pending = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0")
    ), provider: pendingProvider)
    @Expect(pending.notify(SystemNotification("pending", "Pending")).status,
        SystemShellResultStatus.PermissionRequired)
    @Expect(pending.requestNotificationPermission().status, SystemShellResultStatus.Queued)
    @Expect(pendingProvider.notificationCount(), 0)

    let denied = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0")
    ), provider: HeadlessSystemShellProvider(
        notificationPermission: NotificationPermissionState.Denied
    ))
    @Expect(denied.notify(SystemNotification("denied", "Denied")).status,
        SystemShellResultStatus.Denied)

    let unsupported = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0")
    ), provider: HeadlessSystemShellProvider(
        notificationPermission: NotificationPermissionState.Unsupported
    ))
    @Expect(unsupported.notify(SystemNotification("unsupported", "Unsupported")).status,
        SystemShellResultStatus.Unsupported)
}

@Test
func applicationShellRoutesExactDeepLinksToStableActions(): Unit {
    let invoked = ApplicationShellTestCounter()
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        actions: [AppAction("app.settings", "Settings")],
        deepLinks: [AppDeepLinkRoute("demo://app/settings", "app.settings")]
    ), provider: provider)
    @Expect(shell.registerAction(AppAction("app.settings", "Settings"), { => invoked.value += 1 }).ok())
    @Expect(shell.projectDeepLinks().ok())
    @Expect(shell.projectDeepLinks().ok())
    @Expect(provider.deepLinkCount(), 1)
    @Expect(shell.notify(SystemNotification("settings", "Settings available",
        deepLink: Some("demo://app/settings"))).status, SystemShellResultStatus.Queued)
    @Expect(shell.notify(SystemNotification("unknown-link", "Unknown link",
        deepLink: Some("demo://app/unknown"))).status, SystemShellResultStatus.Failed)
    @Expect(shell.handleDeepLink("demo://app/settings").ok())
    @Expect(invoked.value, 1)
    @Expect(shell.handleDeepLink("demo://app/unknown").status, SystemShellResultStatus.Failed)
}

@Test
func applicationManifestRejectsDuplicateOrUnknownDeepLinkRoutes(): Unit {
    let errors = validateApplicationManifest(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        actions: [AppAction("app.open", "Open")],
        deepLinks: [
            AppDeepLinkRoute("demo://app/open", "app.open"),
            AppDeepLinkRoute("demo://app/open", "app.missing")
        ]
    ))
    @Expect(errors.size, 2)
}

@Test
func applicationShellNotificationActionsMustBeRegisteredOrDeclared(): Unit {
    let shell = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0")
    ))
    @Expect(shell.notify(SystemNotification("unknown", "Unknown",
        actionIds: ["app.open"])).status, SystemShellResultStatus.Failed)
    @Expect(shell.registerAction(AppAction("app.open", "Open"), { => () }).ok())
    @Expect(shell.notify(SystemNotification("known", "Known",
        actionIds: ["app.open"])).status, SystemShellResultStatus.Queued)
}

@Test
func applicationShellProjectionRejectsDuplicateOrUnknownSurfaceActions(): Unit {
    let duplicate = AppMenuBar(menus: [
        AppMenu("file", "File", actionIds: ["file.open", "file.open"])
    ])
    let shell = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        actions: [AppAction("file.open", "Open")]
    ))
    @Expect(shell.setApplicationMenu(duplicate).status, SystemShellResultStatus.Failed)
    @Expect(shell.setStatusItem(AppStatusItem("Demo", actionIds: ["missing.action"])).status,
        SystemShellResultStatus.Failed)
}

@Test
func applicationShellProjectionAcceptsRuntimeRegisteredActions(): Unit {
    let shell = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0")
    ))
    @Expect(shell.registerAction(AppAction("app.quit", "Quit"), { => () }).ok())
    @Expect(shell.setApplicationMenu(AppMenuBar(menus: [
        AppMenu("app", "Application", actionIds: ["app.quit"])
    ])).ok())
    @Expect(shell.setStatusItem(AppStatusItem("Demo", actionIds: ["app.quit"])).ok())
}

@Test
func applicationShellRefusesSensitiveSettingDowngrade(): Unit {
    let shell = ApplicationShell(ApplicationManifest(
        AppIdentity("Demo", "dev.example.demo", "1.0.0"),
        settings: [AppSetting("account.token", AppSettingValue.Text(""), sensitive: true)]
    ))
    let result = shell.writeSetting("account.token", AppSettingValue.Text("secret"))
    @Expect(result.status, SystemShellResultStatus.Unsupported)
    @Expect(shell.readSetting("account.token").isNone())
}

@Test
func applicationShellNamesStayStableForDoctorAndPackaging(): Unit {
    @Expect(CANGHUI_APPLICATION_SHELL_PROTOCOL, "canghui.application-shell.v0")
    @Expect(appAssetRoleName(AppAssetRole.StatusItemIcon), "status-item-icon")
    @Expect(systemSurfaceName(SystemSurface.Notification), "notification")
    @Expect(systemSurfaceStateName(SystemSurfaceState.PermissionRequired), "permission-required")
    @Expect(systemShellResultStatusName(SystemShellResultStatus.Applied), "applied")
    @Expect(systemShellResultStatusName(SystemShellResultStatus.Denied), "denied")
    @Expect(notificationPermissionStateName(NotificationPermissionState.NotDetermined), "not-determined")
}
