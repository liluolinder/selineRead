package chui.system

import std.collection.ArrayList

/** Stable public protocol for CangHui system-level application integration. */
public let CANGHUI_APPLICATION_SHELL_PROTOCOL = "canghui.application-shell.v0"

public enum AppAssetRole <: Equatable<AppAssetRole> {
    | ApplicationIcon
    | StatusItemIcon
    | NotificationIcon
    | DocumentIcon
    | MonochromeIcon
    | Resource

    public operator func ==(other: AppAssetRole): Bool {
        appAssetRoleName(this) == appAssetRoleName(other)
    }

    public operator func !=(other: AppAssetRole): Bool {
        !(this == other)
    }
}

public func appAssetRoleName(role: AppAssetRole): String {
    match (role) {
        case AppAssetRole.ApplicationIcon => "application-icon"
        case AppAssetRole.StatusItemIcon => "status-item-icon"
        case AppAssetRole.NotificationIcon => "notification-icon"
        case AppAssetRole.DocumentIcon => "document-icon"
        case AppAssetRole.MonochromeIcon => "monochrome-icon"
        case AppAssetRole.Resource => "resource"
    }
}

public struct AppAsset {
    public let role: AppAssetRole
    public let path: String
    public let darkPath: ?String
    public let scale: Int64

    public init(role: AppAssetRole, path: String, darkPath!: ?String = None, scale!: Int64 = 1) {
        if (path.isEmpty()) {
            throw IllegalArgumentException("application asset path must not be empty")
        }
        if (scale <= 0) {
            throw IllegalArgumentException("application asset scale must be positive")
        }
        this.role = role
        this.path = path
        this.darkPath = darkPath
        this.scale = scale
    }
}

public struct AppIdentity {
    public let name: String
    public let identifier: String
    public let version: String
    public let publisher: String
    public let url: ?String

    public init(
        name: String,
        identifier: String,
        version: String,
        publisher!: String = "",
        url!: ?String = None
    ) {
        if (name.isEmpty() || identifier.isEmpty() || version.isEmpty()) {
            throw IllegalArgumentException("application name, identifier and version must not be empty")
        }
        this.name = name
        this.identifier = identifier
        this.version = version
        this.publisher = publisher
        this.url = url
    }
}

public struct AppAction {
    public let id: String
    public let title: String
    public let shortcut: ?String

    public init(id: String, title: String, shortcut!: ?String = None) {
        validateAppActionId(id)
        if (title.isEmpty()) {
            throw IllegalArgumentException("application action title must not be empty")
        }
        this.id = id
        this.title = title
        this.shortcut = shortcut
    }
}

public type AppActionHandler = () -> Unit

public class AppActionRegistry {
    private let actions = ArrayList<AppAction>()
    private let handlers = ArrayList<AppActionHandler>()

    public func register(action: AppAction, handler: AppActionHandler): SystemShellResult {
        if (contains(action.id)) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: "duplicate application action: " + action.id)
        }
        actions.add(action)
        handlers.add(handler)
        SystemShellResult(SystemShellResultStatus.Applied, message: "application action registered")
    }

    public func invoke(id: String): SystemShellResult {
        validateAppActionId(id)
        for (i in 0..actions.size) {
            if (actions[i].id == id) {
                handlers[i]()
                return SystemShellResult(SystemShellResultStatus.Applied,
                    message: "application action invoked")
            }
        }
        SystemShellResult(SystemShellResultStatus.Failed, message: "unknown application action: " + id)
    }

    public func contains(id: String): Bool {
        for (action in actions) {
            if (action.id == id) { return true }
        }
        false
    }

    public func size(): Int64 { actions.size }
}

public struct AppStatusItem {
    public let tooltip: String
    public let iconRole: AppAssetRole
    public let actionIds: Array<String>

    public init(tooltip: String, iconRole!: AppAssetRole = AppAssetRole.StatusItemIcon,
        actionIds!: Array<String> = []) {
        if (tooltip.isEmpty()) {
            throw IllegalArgumentException("status item tooltip must not be empty")
        }
        for (actionId in actionIds) {
            validateAppActionId(actionId)
        }
        this.tooltip = tooltip
        this.iconRole = iconRole
        this.actionIds = actionIds
    }
}

public enum AppSettingValue {
    | Text(String)
    | Boolean(Bool)
    | Integer(Int64)
}

public struct AppSetting {
    public let key: String
    public let defaultValue: AppSettingValue
    public let sensitive: Bool

    public init(key: String, defaultValue: AppSettingValue, sensitive!: Bool = false) {
        validateAppSettingKey(key)
        this.key = key
        this.defaultValue = defaultValue
        this.sensitive = sensitive
    }
}

public struct SystemNotification {
    public let id: String
    public let title: String
    public let body: String
    public let group: ?String
    public let deepLink: ?String
    public let actionIds: Array<String>

    public init(
        id: String,
        title: String,
        body!: String = "",
        group!: ?String = None,
        deepLink!: ?String = None,
        actionIds!: Array<String> = []
    ) {
        if (id.isEmpty() || title.isEmpty()) {
            throw IllegalArgumentException("notification id and title must not be empty")
        }
        for (actionId in actionIds) {
            validateAppActionId(actionId)
        }
        match (deepLink) {
            case Some(uri) => validateAppDeepLinkUri(uri)
            case None => ()
        }
        this.id = id
        this.title = title
        this.body = body
        this.group = group
        this.deepLink = deepLink
        this.actionIds = actionIds
    }
}

public enum SystemSurface <: Equatable<SystemSurface> {
    | ApplicationMenu
    | StatusItem
    | Notification
    | Settings
    | SecureSettings
    | AppIcon
    | Taskbar
    | Badge
    | DeepLink

    public operator func ==(other: SystemSurface): Bool {
        systemSurfaceName(this) == systemSurfaceName(other)
    }

    public operator func !=(other: SystemSurface): Bool {
        !(this == other)
    }
}

public func systemSurfaceName(surface: SystemSurface): String {
    match (surface) {
        case SystemSurface.ApplicationMenu => "application-menu"
        case SystemSurface.StatusItem => "status-item"
        case SystemSurface.Notification => "notification"
        case SystemSurface.Settings => "settings"
        case SystemSurface.SecureSettings => "secure-settings"
        case SystemSurface.AppIcon => "app-icon"
        case SystemSurface.Taskbar => "taskbar"
        case SystemSurface.Badge => "badge"
        case SystemSurface.DeepLink => "deep-link"
    }
}

public enum SystemSurfaceState <: Equatable<SystemSurfaceState> {
    | Native
    | Fallback
    | Unsupported
    | PermissionRequired

    public operator func ==(other: SystemSurfaceState): Bool {
        systemSurfaceStateName(this) == systemSurfaceStateName(other)
    }

    public operator func !=(other: SystemSurfaceState): Bool {
        !(this == other)
    }
}

public func systemSurfaceStateName(state: SystemSurfaceState): String {
    match (state) {
        case SystemSurfaceState.Native => "native"
        case SystemSurfaceState.Fallback => "fallback"
        case SystemSurfaceState.Unsupported => "unsupported"
        case SystemSurfaceState.PermissionRequired => "permission-required"
    }
}

public enum SystemShellResultStatus <: Equatable<SystemShellResultStatus> {
    | Applied
    | Queued
    | PermissionRequired
    | Denied
    | Unsupported
    | Failed

    public operator func ==(other: SystemShellResultStatus): Bool {
        systemShellResultStatusName(this) == systemShellResultStatusName(other)
    }

    public operator func !=(other: SystemShellResultStatus): Bool {
        !(this == other)
    }
}

public func systemShellResultStatusName(status: SystemShellResultStatus): String {
    match (status) {
        case SystemShellResultStatus.Applied => "applied"
        case SystemShellResultStatus.Queued => "queued"
        case SystemShellResultStatus.PermissionRequired => "permission-required"
        case SystemShellResultStatus.Denied => "denied"
        case SystemShellResultStatus.Unsupported => "unsupported"
        case SystemShellResultStatus.Failed => "failed"
    }
}

public struct SystemShellResult {
    public let status: SystemShellResultStatus
    public let message: String

    public init(status: SystemShellResultStatus, message!: String = "") {
        this.status = status
        this.message = message
    }

    public func ok(): Bool {
        status == SystemShellResultStatus.Applied || status == SystemShellResultStatus.Queued
    }
}

public struct ApplicationManifest {
    public let identity: AppIdentity
    public let assets: Array<AppAsset>
    public let actions: Array<AppAction>
    public let settings: Array<AppSetting>
    public let applicationMenu: ?AppMenuBar
    public let statusItem: ?AppStatusItem
    public let deepLinks: Array<AppDeepLinkRoute>

    public init(
        identity: AppIdentity,
        assets!: Array<AppAsset> = [],
        actions!: Array<AppAction> = [],
        settings!: Array<AppSetting> = [],
        applicationMenu!: ?AppMenuBar = None,
        statusItem!: ?AppStatusItem = None,
        deepLinks!: Array<AppDeepLinkRoute> = []
    ) {
        this.identity = identity
        this.assets = assets
        this.actions = actions
        this.settings = settings
        this.applicationMenu = applicationMenu
        this.statusItem = statusItem
        this.deepLinks = deepLinks
    }
}

public interface SystemShellProvider {
    func state(surface: SystemSurface): SystemSurfaceState
    func registerAction(action: AppAction): SystemShellResult
    func setApplicationMenu(menu: AppMenuBar): SystemShellResult
    func setStatusItem(item: AppStatusItem): SystemShellResult
    func notificationPermission(): NotificationPermissionState
    func requestNotificationPermission(): SystemShellResult
    func notify(notification: SystemNotification): SystemShellResult
    func registerDeepLink(route: AppDeepLinkRoute): SystemShellResult
    func readSetting(key: String): ?AppSettingValue
    func writeSetting(key: String, value: AppSettingValue): SystemShellResult
}

/** Deterministic provider used by kMode, headless tests and unsupported hosts. */
public class HeadlessSystemShellProvider <: SystemShellProvider {
    private let registeredActions = ArrayList<AppAction>()
    private let notifications = ArrayList<SystemNotification>()
    private let settingKeys = ArrayList<String>()
    private let settingValues = ArrayList<AppSettingValue>()
    private let deepLinks = ArrayList<AppDeepLinkRoute>()
    private var applicationMenu: ?AppMenuBar = None
    private let notificationPermissionState: NotificationPermissionState

    public init(notificationPermission!: NotificationPermissionState = NotificationPermissionState.NotRequired) {
        this.notificationPermissionState = notificationPermission
    }

    public func state(surface: SystemSurface): SystemSurfaceState {
        match (surface) {
            case SystemSurface.SecureSettings => SystemSurfaceState.Unsupported
            case _ => SystemSurfaceState.Fallback
        }
    }

    public func registerAction(action: AppAction): SystemShellResult {
        for (existing in registeredActions) {
            if (existing.id == action.id) {
                return SystemShellResult(SystemShellResultStatus.Failed,
                    message: "duplicate application action: " + action.id)
            }
        }
        registeredActions.add(action)
        SystemShellResult(SystemShellResultStatus.Applied, message: "headless action registered")
    }

    public func setStatusItem(_: AppStatusItem): SystemShellResult {
        SystemShellResult(SystemShellResultStatus.Queued, message: "status item captured by headless provider")
    }

    public func setApplicationMenu(menu: AppMenuBar): SystemShellResult {
        applicationMenu = Some(menu)
        SystemShellResult(SystemShellResultStatus.Queued, message: "application menu captured by headless provider")
    }

    public func notificationPermission(): NotificationPermissionState {
        notificationPermissionState
    }

    public func requestNotificationPermission(): SystemShellResult {
        match (notificationPermissionState) {
            case NotificationPermissionState.NotDetermined =>
                SystemShellResult(SystemShellResultStatus.Queued,
                    message: "notification permission request captured by headless provider")
            case NotificationPermissionState.Granted | NotificationPermissionState.NotRequired =>
                SystemShellResult(SystemShellResultStatus.Applied,
                    message: "notification permission is already available")
            case NotificationPermissionState.Denied =>
                SystemShellResult(SystemShellResultStatus.Denied,
                    message: "notification permission is denied")
            case NotificationPermissionState.Unsupported =>
                SystemShellResult(SystemShellResultStatus.Unsupported,
                    message: "notifications are unsupported")
        }
    }

    public func notify(notification: SystemNotification): SystemShellResult {
        notifications.add(notification)
        SystemShellResult(SystemShellResultStatus.Queued, message: "notification captured by headless provider")
    }

    public func registerDeepLink(route: AppDeepLinkRoute): SystemShellResult {
        for (existing in deepLinks) {
            if (existing.uri == route.uri) {
                if (existing.actionId == route.actionId) {
                    return SystemShellResult(SystemShellResultStatus.Applied,
                        message: "application deep link was already captured")
                }
                return SystemShellResult(SystemShellResultStatus.Failed,
                    message: "conflicting application deep link: " + route.uri)
            }
        }
        deepLinks.add(route)
        SystemShellResult(SystemShellResultStatus.Queued,
            message: "deep link captured by headless provider")
    }

    public func readSetting(key: String): ?AppSettingValue {
        for (i in 0..settingKeys.size) {
            if (settingKeys[i] == key) {
                return Some(settingValues[i])
            }
        }
        None
    }

    public func writeSetting(key: String, value: AppSettingValue): SystemShellResult {
        validateAppSettingKey(key)
        for (i in 0..settingKeys.size) {
            if (settingKeys[i] == key) {
                settingValues[i] = value
                return SystemShellResult(SystemShellResultStatus.Applied, message: "headless setting updated")
            }
        }
        settingKeys.add(key)
        settingValues.add(value)
        SystemShellResult(SystemShellResultStatus.Applied, message: "headless setting stored")
    }

    public func actionCount(): Int64 { registeredActions.size }
    public func notificationCount(): Int64 { notifications.size }
    public func deepLinkCount(): Int64 { deepLinks.size }
    public func applicationMenuCount(): Int64 {
        match (applicationMenu) {
            case Some(menu) => menu.menus.size
            case None => 0
        }
    }
}

public class ApplicationShell {
    public let manifest: ApplicationManifest
    private let provider: SystemShellProvider
    private let actionRegistry = AppActionRegistry()
    private let registeredDeepLinks = ArrayList<AppDeepLinkRoute>()

    public init(manifest: ApplicationManifest, provider!: SystemShellProvider = HeadlessSystemShellProvider()) {
        let errors = validateApplicationManifest(manifest)
        if (!errors.isEmpty()) {
            throw IllegalArgumentException(renderApplicationManifestErrors(errors))
        }
        this.manifest = manifest
        this.provider = provider
    }

    public func capability(surface: SystemSurface): SystemSurfaceState {
        provider.state(surface)
    }

    public func registerAction(action: AppAction, handler: AppActionHandler): SystemShellResult {
        if (actionRegistry.contains(action.id)) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: "duplicate application action: " + action.id)
        }
        let providerResult = provider.registerAction(action)
        if (!providerResult.ok()) { return providerResult }
        actionRegistry.register(action, handler)
    }

    public func invokeAction(id: String): SystemShellResult {
        actionRegistry.invoke(id)
    }

    public func setApplicationMenu(menu: AppMenuBar): SystemShellResult {
        let errors = ArrayList<String>()
        for (entry in menu.menus) {
            validateRuntimeActionReferences(entry.actionIds, "menu " + entry.id, errors)
        }
        if (!errors.isEmpty()) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: renderApplicationManifestErrors(errors.toArray()))
        }
        provider.setApplicationMenu(menu)
    }

    public func setStatusItem(item: AppStatusItem): SystemShellResult {
        let errors = ArrayList<String>()
        validateRuntimeActionReferences(item.actionIds, "status item", errors)
        if (!errors.isEmpty()) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: renderApplicationManifestErrors(errors.toArray()))
        }
        provider.setStatusItem(item)
    }

    public func projectSystemSurfaces(): AppSurfaceProjectionResult {
        let menuResult = match (manifest.applicationMenu) {
            case Some(menu) => setApplicationMenu(menu)
            case None => SystemShellResult(SystemShellResultStatus.Applied,
                message: "application menu was not declared")
        }
        let statusResult = match (manifest.statusItem) {
            case Some(item) => setStatusItem(item)
            case None => SystemShellResult(SystemShellResultStatus.Applied,
                message: "status item was not declared")
        }
        AppSurfaceProjectionResult(menuResult, statusResult)
    }

    public func notify(notification: SystemNotification): SystemShellResult {
        let errors = ArrayList<String>()
        validateRuntimeActionReferences(notification.actionIds, "notification " + notification.id, errors)
        if (!errors.isEmpty()) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: renderApplicationManifestErrors(errors.toArray()))
        }
        match (notification.deepLink) {
            case Some(uri) =>
                if (!containsDeepLink(uri)) {
                    return SystemShellResult(SystemShellResultStatus.Failed,
                        message: "notification references unknown deep link: " + uri)
                }
            case None => ()
        }
        match (provider.notificationPermission()) {
            case NotificationPermissionState.NotDetermined =>
                return SystemShellResult(SystemShellResultStatus.PermissionRequired,
                    message: "notification permission has not been determined")
            case NotificationPermissionState.Denied =>
                return SystemShellResult(SystemShellResultStatus.Denied,
                    message: "notification permission is denied")
            case NotificationPermissionState.Unsupported =>
                return SystemShellResult(SystemShellResultStatus.Unsupported,
                    message: "notifications are unsupported")
            case NotificationPermissionState.Granted | NotificationPermissionState.NotRequired => ()
        }
        provider.notify(notification)
    }

    public func notificationPermission(): NotificationPermissionState {
        provider.notificationPermission()
    }

    public func requestNotificationPermission(): SystemShellResult {
        provider.requestNotificationPermission()
    }

    public func registerDeepLink(route: AppDeepLinkRoute): SystemShellResult {
        let errors = ArrayList<String>()
        validateRuntimeActionReferences([route.actionId], "deep link " + route.uri, errors)
        if (!errors.isEmpty()) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: renderApplicationManifestErrors(errors.toArray()))
        }
        for (existing in registeredDeepLinks) {
            if (existing.uri == route.uri) {
                if (existing.actionId == route.actionId) {
                    return SystemShellResult(SystemShellResultStatus.Applied,
                        message: "application deep link was already registered")
                }
                return SystemShellResult(SystemShellResultStatus.Failed,
                    message: "conflicting application deep link: " + route.uri)
            }
        }
        let providerResult = provider.registerDeepLink(route)
        if (!providerResult.ok()) { return providerResult }
        registeredDeepLinks.add(route)
        providerResult
    }

    public func projectDeepLinks(): SystemShellResult {
        var status = SystemShellResultStatus.Applied
        for (route in manifest.deepLinks) {
            let result = registerDeepLink(route)
            if (!result.ok()) { return result }
            if (result.status == SystemShellResultStatus.Queued) {
                status = SystemShellResultStatus.Queued
            }
        }
        SystemShellResult(status, message: "application deep links projected")
    }

    public func handleDeepLink(uri: String): SystemShellResult {
        validateAppDeepLinkUri(uri)
        for (route in registeredDeepLinks) {
            if (route.uri == uri) { return invokeAction(route.actionId) }
        }
        for (route in manifest.deepLinks) {
            if (route.uri == uri) { return invokeAction(route.actionId) }
        }
        SystemShellResult(SystemShellResultStatus.Failed,
            message: "unknown application deep link: " + uri)
    }

    private func containsDeepLink(uri: String): Bool {
        for (route in registeredDeepLinks) {
            if (route.uri == uri) { return true }
        }
        for (route in manifest.deepLinks) {
            if (route.uri == uri) { return true }
        }
        false
    }

    public func readSetting(key: String): ?AppSettingValue {
        provider.readSetting(key)
    }

    public func writeSetting(key: String, value: AppSettingValue): SystemShellResult {
        match (findSetting(manifest.settings, key)) {
            case Some(setting) =>
                if (setting.sensitive && provider.state(SystemSurface.SecureSettings) != SystemSurfaceState.Native) {
                    return SystemShellResult(SystemShellResultStatus.Unsupported,
                        message: "sensitive setting requires a native secure-settings provider")
                }
            case None =>
                return SystemShellResult(SystemShellResultStatus.Failed,
                    message: "unknown application setting: " + key)
        }
        provider.writeSetting(key, value)
    }

    private func validateRuntimeActionReferences(actionIds: Array<String>, surface: String,
        errors: ArrayList<String>): Unit {
        for (i in 0..actionIds.size) {
            let id = actionIds[i]
            if (!containsAction(manifest.actions, id) && !actionRegistry.contains(id)) {
                errors.add(surface + " references unknown action: " + id)
            }
            for (j in (i + 1)..actionIds.size) {
                if (id == actionIds[j]) {
                    errors.add(surface + " references duplicate action: " + id)
                }
            }
        }
    }
}

public func validateApplicationManifest(manifest: ApplicationManifest): Array<String> {
    let errors = ArrayList<String>()
    validateUniqueActions(manifest.actions, errors)
    validateUniqueSettings(manifest.settings, errors)
    validateAssetRoles(manifest.assets, errors)
    validateDeepLinkRoutes(manifest.deepLinks, manifest.actions, errors)
    match (manifest.applicationMenu) {
        case Some(menu) => validateMenuActionReferences(menu, manifest.actions, errors)
        case None => ()
    }
    match (manifest.statusItem) {
        case Some(item) =>
            validateStatusActionReferences(item, manifest.actions, errors)
        case None => ()
    }
    errors.toArray()
}

func validateUniqueActions(actions: Array<AppAction>, errors: ArrayList<String>): Unit {
    for (i in 0..actions.size) {
        for (j in (i + 1)..actions.size) {
            if (actions[i].id == actions[j].id) {
                errors.add("duplicate application action: " + actions[i].id)
            }
        }
    }
}

func validateUniqueSettings(settings: Array<AppSetting>, errors: ArrayList<String>): Unit {
    for (i in 0..settings.size) {
        for (j in (i + 1)..settings.size) {
            if (settings[i].key == settings[j].key) {
                errors.add("duplicate application setting: " + settings[i].key)
            }
        }
    }
}

func validateAssetRoles(assets: Array<AppAsset>, errors: ArrayList<String>): Unit {
    for (i in 0..assets.size) {
        for (j in (i + 1)..assets.size) {
            if (assets[i].role == assets[j].role && assets[i].scale == assets[j].scale) {
                errors.add("duplicate application asset role and scale: " + appAssetRoleName(assets[i].role))
            }
        }
    }
}

func containsAction(actions: Array<AppAction>, id: String): Bool {
    for (action in actions) {
        if (action.id == id) { return true }
    }
    false
}

func findSetting(settings: Array<AppSetting>, key: String): ?AppSetting {
    for (setting in settings) {
        if (setting.key == key) { return Some(setting) }
    }
    None
}

func renderApplicationManifestErrors(errors: Array<String>): String {
    var result = "invalid application manifest"
    for (error in errors) {
        result = result + "; " + error
    }
    result
}

public func validateAppActionId(id: String): Unit {
    validateDottedIdentifier(id, "application action")
}

public func validateAppSettingKey(key: String): Unit {
    validateDottedIdentifier(key, "application setting")
}

func validateDottedIdentifier(value: String, label: String): Unit {
    if (value.isEmpty()) {
        throw IllegalArgumentException(label + " identifier must not be empty")
    }
    var segmentStart = true
    for (r in value.toRuneArray()) {
        if (r == r'.') {
            if (segmentStart) {
                throw IllegalArgumentException(label + " identifier has an empty segment: " + value)
            }
            segmentStart = true
            continue
        }
        let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
        let digit = r >= r'0' && r <= r'9'
        if ((!letter && !digit && r != r'-' && r != r'_') || (segmentStart && !letter)) {
            throw IllegalArgumentException("invalid " + label + " identifier: " + value)
        }
        segmentStart = false
    }
    if (segmentStart) {
        throw IllegalArgumentException(label + " identifier must not end with a dot: " + value)
    }
}
