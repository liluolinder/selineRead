package chui.system

import std.collection.ArrayList

public let CANGHUI_APPLICATION_SETTINGS_PROTOCOL = "canghui.application-settings.v0"

public enum AppSettingStorage <: Equatable<AppSettingStorage> {
    | Ordinary
    | Secure

    public operator func ==(other: AppSettingStorage): Bool {
        appSettingStorageName(this) == appSettingStorageName(other)
    }

    public operator func !=(other: AppSettingStorage): Bool {
        !(this == other)
    }
}

public func appSettingStorageName(storage: AppSettingStorage): String {
    match (storage) {
        case AppSettingStorage.Ordinary => "ordinary"
        case AppSettingStorage.Secure => "secure"
    }
}

public struct AppSettingsSchema {
    public let id: String
    public let version: Int64

    public init(id: String, version: Int64) {
        if (id.isEmpty()) { throw IllegalArgumentException("settings schema id must not be empty") }
        if (version < 0) { throw IllegalArgumentException("settings schema version must not be negative") }
        this.id = id
        this.version = version
    }
}

public type AppSettingMigrationHandler = (AppSettingValue) -> AppSettingValue

public struct AppSettingMigration {
    public let schemaId: String
    public let fromVersion: Int64
    public let toVersion: Int64
    public let key: String
    public let targetKey: String
    public let transform: AppSettingMigrationHandler

    public init(
        schemaId: String,
        fromVersion: Int64,
        toVersion: Int64,
        key: String,
        targetKey!: String = "",
        transform!: AppSettingMigrationHandler = {value => value}
    ) {
        if (schemaId.isEmpty()) { throw IllegalArgumentException("settings migration schema id must not be empty") }
        if (fromVersion < 0 || toVersion <= fromVersion) {
            throw IllegalArgumentException("settings migration versions must increase")
        }
        validateAppSettingKey(key)
        let resolvedTarget = if (targetKey.isEmpty()) { key } else { targetKey }
        validateAppSettingKey(resolvedTarget)
        this.schemaId = schemaId
        this.fromVersion = fromVersion
        this.toVersion = toVersion
        this.key = key
        this.targetKey = resolvedTarget
        this.transform = transform
    }
}

public struct AppSettingsMigrationResult {
    public let status: SystemShellResultStatus
    public let fromVersion: Int64
    public let toVersion: Int64
    public let changedKeys: Array<String>
    public let message: String

    public init(
        status: SystemShellResultStatus,
        fromVersion: Int64,
        toVersion: Int64,
        changedKeys!: Array<String> = [],
        message!: String = ""
    ) {
        this.status = status
        this.fromVersion = fromVersion
        this.toVersion = toVersion
        this.changedKeys = changedKeys
        this.message = message
    }

    public func ok(): Bool {
        status == SystemShellResultStatus.Applied || status == SystemShellResultStatus.Queued
    }
}

/** Provider boundary for typed project settings and schema-version metadata. */
public interface AppSettingsProvider {
    func state(storage: AppSettingStorage): SystemSurfaceState
    func schemaVersion(): Int64
    func setSchemaVersion(version: Int64): SystemShellResult
    func contains(key: String): Bool
    func read(key: String): ?AppSettingValue
    func write(key: String, value: AppSettingValue): SystemShellResult
    func remove(key: String): SystemShellResult
}

/** In-memory ordinary-settings provider used by kMode, CI and fallback hosts. */
public class HeadlessSettingsProvider <: AppSettingsProvider {
    private let keys = ArrayList<String>()
    private let values = ArrayList<AppSettingValue>()
    private var currentSchemaVersion: Int64 = 0

    public func state(storage: AppSettingStorage): SystemSurfaceState {
        match (storage) {
            case AppSettingStorage.Secure => SystemSurfaceState.Unsupported
            case AppSettingStorage.Ordinary => SystemSurfaceState.Fallback
        }
    }

    public func schemaVersion(): Int64 { currentSchemaVersion }

    public func setSchemaVersion(version: Int64): SystemShellResult {
        if (version < currentSchemaVersion) {
            return SystemShellResult(SystemShellResultStatus.Failed,
                message: "settings schema version cannot move backwards")
        }
        currentSchemaVersion = version
        SystemShellResult(SystemShellResultStatus.Applied, message: "headless settings schema version updated")
    }

    public func contains(key: String): Bool {
        validateAppSettingKey(key)
        for (existing in keys) {
            if (existing == key) { return true }
        }
        false
    }

    public func read(key: String): ?AppSettingValue {
        validateAppSettingKey(key)
        for (i in 0..keys.size) {
            if (keys[i] == key) { return Some(values[i]) }
        }
        None
    }

    public func write(key: String, value: AppSettingValue): SystemShellResult {
        validateAppSettingKey(key)
        for (i in 0..keys.size) {
            if (keys[i] == key) {
                values[i] = value
                return SystemShellResult(SystemShellResultStatus.Applied, message: "headless setting updated")
            }
        }
        keys.add(key)
        values.add(value)
        SystemShellResult(SystemShellResultStatus.Applied, message: "headless setting stored")
    }

    public func remove(key: String): SystemShellResult {
        validateAppSettingKey(key)
        for (i in 0..keys.size) {
            if (keys[i] == key) {
                keys.remove(at: i)
                values.remove(at: i)
                return SystemShellResult(SystemShellResultStatus.Applied, message: "headless setting removed")
            }
        }
        SystemShellResult(SystemShellResultStatus.Applied, message: "headless setting was already absent")
    }
}

/** Typed settings facade: defaults are read-only fallbacks, writes are provider-backed. */
public class AppSettingsRuntime {
    public let schema: AppSettingsSchema
    public let settings: Array<AppSetting>
    private let provider: AppSettingsProvider

    public init(schema: AppSettingsSchema, settings: Array<AppSetting>, provider: AppSettingsProvider) {
        this.schema = schema
        this.settings = settings
        this.provider = provider
        let errors = validateRuntimeSettings(settings)
        if (!errors.isEmpty()) {
            throw IllegalArgumentException(renderRuntimeSettingErrors(errors))
        }
    }

    public func capability(storage: AppSettingStorage): SystemSurfaceState {
        provider.state(storage)
    }

    public func read(key: String): ?AppSettingValue {
        match (findSetting(settings, key)) {
            case None => None
            case Some(setting) =>
                if (setting.sensitive && provider.state(AppSettingStorage.Secure) != SystemSurfaceState.Native) {
                    return None
                }
                match (provider.read(key)) {
                    case Some(value) => Some(value)
                    case None => Some(setting.defaultValue)
                }
        }
    }

    public func write(key: String, value: AppSettingValue): SystemShellResult {
        match (findSetting(settings, key)) {
            case None => SystemShellResult(SystemShellResultStatus.Failed,
                message: "unknown application setting: " + key)
            case Some(setting) =>
                if (!appSettingValueMatches(setting.defaultValue, value)) {
                    return SystemShellResult(SystemShellResultStatus.Failed,
                        message: "setting value type does not match: " + key)
                }
                if (setting.sensitive && provider.state(AppSettingStorage.Secure) != SystemSurfaceState.Native) {
                    return SystemShellResult(SystemShellResultStatus.Unsupported,
                        message: "sensitive setting requires a native secure-settings provider")
                }
                provider.write(key, value)
        }
    }

    public func migrate(migrations: Array<AppSettingMigration>): AppSettingsMigrationResult {
        let originalVersion = provider.schemaVersion()
        if (originalVersion > schema.version) {
            return AppSettingsMigrationResult(SystemShellResultStatus.Failed,
                originalVersion, schema.version,
                message: "stored settings schema is newer than the application schema")
        }
        var current = originalVersion
        let changed = ArrayList<String>()
        let used = Array<Bool>(migrations.size, { _ => false })
        while (current < schema.version) {
            var selected = -1
            for (i in 0..migrations.size) {
                if (!used[i] && migrations[i].schemaId == schema.id &&
                    migrations[i].fromVersion == current && migrations[i].toVersion <= schema.version) {
                    if (selected >= 0) {
                        return AppSettingsMigrationResult(SystemShellResultStatus.Failed,
                            originalVersion, current, changedKeys: changed.toArray(),
                            message: "multiple settings migrations start at schema version " + current.toString())
                    }
                    selected = i
                }
            }
            if (selected < 0) {
                return AppSettingsMigrationResult(SystemShellResultStatus.Failed,
                    originalVersion, current, changedKeys: changed.toArray(),
                    message: "no settings migration reaches schema version " + schema.version.toString())
            }
            let migration = migrations[selected]
            used[selected] = true
            if (containsSensitiveSetting(migration.key) && provider.contains(migration.key) &&
                provider.state(AppSettingStorage.Secure) != SystemSurfaceState.Native) {
                return AppSettingsMigrationResult(SystemShellResultStatus.Unsupported,
                    originalVersion, current, changedKeys: changed.toArray(),
                    message: "secure setting migration requires a native secure-settings provider")
            }
            match (provider.read(migration.key)) {
                case Some(value) =>
                    let result = write(migration.targetKey, migration.transform(value))
                    if (!result.ok()) {
                        return AppSettingsMigrationResult(result.status, originalVersion, current,
                            changedKeys: changed.toArray(), message: result.message)
                    }
                    if (migration.targetKey != migration.key) {
                        let removed = provider.remove(migration.key)
                        if (!removed.ok()) {
                            return AppSettingsMigrationResult(removed.status, originalVersion, current,
                                changedKeys: changed.toArray(), message: removed.message)
                        }
                    }
                    changed.add(migration.targetKey)
                case None => ()
            }
            current = migration.toVersion
            let versionResult = provider.setSchemaVersion(current)
            if (!versionResult.ok()) {
                return AppSettingsMigrationResult(versionResult.status, originalVersion, current,
                    changedKeys: changed.toArray(), message: versionResult.message)
            }
        }
        AppSettingsMigrationResult(SystemShellResultStatus.Applied,
            originalVersion, current, changedKeys: changed.toArray(), message: "settings schema migration complete")
    }

    private func containsSensitiveSetting(key: String): Bool {
        match (findSetting(settings, key)) {
            case Some(setting) => setting.sensitive
            case None => false
        }
    }
}

public interface AppIdentityProvider {
    func state(): SystemSurfaceState
    func current(): AppIdentity
    func apply(identity: AppIdentity): SystemShellResult
}

/** Headless identity provider records the requested identity without claiming native registration. */
public class HeadlessApplicationIdentityProvider <: AppIdentityProvider {
    private var identity: AppIdentity

    public init(identity: AppIdentity) {
        this.identity = identity
    }

    public func state(): SystemSurfaceState { SystemSurfaceState.Fallback }
    public func current(): AppIdentity { identity }

    public func apply(identity: AppIdentity): SystemShellResult {
        this.identity = identity
        SystemShellResult(SystemShellResultStatus.Queued,
            message: "application identity captured by headless provider")
    }
}

func validateRuntimeSettings(settings: Array<AppSetting>): Array<String> {
    let errors = ArrayList<String>()
    validateUniqueSettings(settings, errors)
    errors.toArray()
}

func renderRuntimeSettingErrors(errors: Array<String>): String {
    var result = "invalid application settings schema"
    for (error in errors) { result = result + "; " + error }
    result
}

func appSettingValueMatches(expected: AppSettingValue, actual: AppSettingValue): Bool {
    match (expected) {
        case AppSettingValue.Text(_) =>
            match (actual) {
                case AppSettingValue.Text(_) => true
                case _ => false
            }
        case AppSettingValue.Boolean(_) =>
            match (actual) {
                case AppSettingValue.Boolean(_) => true
                case _ => false
            }
        case AppSettingValue.Integer(_) =>
            match (actual) {
                case AppSettingValue.Integer(_) => true
                case _ => false
            }
    }
}
