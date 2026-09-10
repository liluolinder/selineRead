package chui.host

/** Application lifecycle states reported by a mobile or embedded host. */
public enum AppLifecycleState <: Equatable<AppLifecycleState> {
    | Launching
    | Active
    | Inactive
    | Background
    | Suspended
    | Terminating

    public operator func ==(other: AppLifecycleState): Bool {
        appLifecycleStateName(this) == appLifecycleStateName(other)
    }

    public operator func !=(other: AppLifecycleState): Bool {
        !(this == other)
    }
}

public func appLifecycleStateName(state: AppLifecycleState): String {
    match (state) {
        case AppLifecycleState.Launching => "launching"
        case AppLifecycleState.Active => "active"
        case AppLifecycleState.Inactive => "inactive"
        case AppLifecycleState.Background => "background"
        case AppLifecycleState.Suspended => "suspended"
        case AppLifecycleState.Terminating => "terminating"
    }
}

/** Host-provided system theme preference before application overrides. */
public enum SystemThemePreference <: Equatable<SystemThemePreference> {
    | Light
    | Dark
    | Unspecified

    public operator func ==(other: SystemThemePreference): Bool {
        systemThemePreferenceName(this) == systemThemePreferenceName(other)
    }

    public operator func !=(other: SystemThemePreference): Bool {
        !(this == other)
    }
}

public func systemThemePreferenceName(preference: SystemThemePreference): String {
    match (preference) {
        case SystemThemePreference.Light => "light"
        case SystemThemePreference.Dark => "dark"
        case SystemThemePreference.Unspecified => "unspecified"
    }
}

/** Logical safe-area insets supplied by the platform host. */
public struct SafeAreaInsets {
    public let top: Float32
    public let right: Float32
    public let bottom: Float32
    public let left: Float32

    public init(
        top!: Float32 = 0.0,
        right!: Float32 = 0.0,
        bottom!: Float32 = 0.0,
        left!: Float32 = 0.0
    ) {
        if (top < 0.0 || right < 0.0 || bottom < 0.0 || left < 0.0) {
            throw IllegalArgumentException("safe-area insets must not be negative")
        }
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public func horizontal(): Float32 {
        left + right
    }

    public func vertical(): Float32 {
        top + bottom
    }
}

/** Logical viewport plus host scale and safe-area facts. */
public struct HostViewportMetrics {
    public let width: Float32
    public let height: Float32
    public let scale: Float32
    public let safeArea: SafeAreaInsets

    public init(
        width: Float32,
        height: Float32,
        scale!: Float32 = 1.0,
        safeArea!: SafeAreaInsets = SafeAreaInsets()
    ) {
        if (width <= 0.0 || height <= 0.0 || scale <= 0.0) {
            throw IllegalArgumentException("host viewport dimensions and scale must be positive")
        }
        this.width = width
        this.height = height
        this.scale = scale
        this.safeArea = safeArea
    }

    public func contentWidth(): Float32 {
        let value = width - safeArea.horizontal()
        if (value > 0.0) { value } else { 0.0 }
    }

    public func contentHeight(): Float32 {
        let value = height - safeArea.vertical()
        if (value > 0.0) { value } else { 0.0 }
    }
}

public enum TouchPhase <: Equatable<TouchPhase> {
    | Began
    | Moved
    | Ended
    | Cancelled

    public operator func ==(other: TouchPhase): Bool {
        touchPhaseName(this) == touchPhaseName(other)
    }

    public operator func !=(other: TouchPhase): Bool {
        !(this == other)
    }
}

public func touchPhaseName(phase: TouchPhase): String {
    match (phase) {
        case TouchPhase.Began => "began"
        case TouchPhase.Moved => "moved"
        case TouchPhase.Ended => "ended"
        case TouchPhase.Cancelled => "cancelled"
    }
}

public struct TouchPoint {
    public let id: Int64
    public let x: Float32
    public let y: Float32

    public init(id: Int64, x: Float32, y: Float32) {
        if (id < 0) {
            throw IllegalArgumentException("touch id must not be negative")
        }
        this.id = id
        this.x = x
        this.y = y
    }
}

public struct TouchEvent {
    public let phase: TouchPhase
    public let points: Array<TouchPoint>
    public let timestampMillis: Int64

    public init(phase: TouchPhase, points: Array<TouchPoint>, timestampMillis: Int64) {
        this.phase = phase
        this.points = points
        this.timestampMillis = timestampMillis
    }
}

/** Host-owned resource reference. locator may be a path, bookmark or opaque token. */
public struct PlatformResourceRef {
    public let id: String
    public let displayName: String
    public let locator: String

    public init(id: String, displayName: String, locator: String) {
        if (id.isEmpty() || displayName.isEmpty() || locator.isEmpty()) {
            throw IllegalArgumentException("platform resource identity fields must not be empty")
        }
        this.id = id
        this.displayName = displayName
        this.locator = locator
    }
}

public enum FilePickerMode {
    | OpenFile
    | OpenFiles
    | SaveFile
    | SelectDirectory
}

public struct FilePickerRequest {
    public let mode: FilePickerMode
    public let allowedContentTypes: Array<String>
    public let suggestedName: String

    public init(
        mode: FilePickerMode,
        allowedContentTypes!: Array<String> = [],
        suggestedName!: String = ""
    ) {
        this.mode = mode
        this.allowedContentTypes = allowedContentTypes
        this.suggestedName = suggestedName
    }
}

public enum FilePickerResult {
    | Selected(Array<PlatformResourceRef>)
    | Cancelled
    | Failed(String)
}

public struct LocalNotificationRequest {
    public let id: String
    public let title: String
    public let body: String

    public init(id: String, title: String, body: String) {
        if (id.isEmpty() || title.isEmpty()) {
            throw IllegalArgumentException("notification id and title must not be empty")
        }
        this.id = id
        this.title = title
        this.body = body
    }
}

public interface HostLifecycleService {
    func currentState(): AppLifecycleState
    func observe(handler: (AppLifecycleState) -> Unit): Unit
}

public interface HostViewportService {
    func currentMetrics(): HostViewportMetrics
    func observe(handler: (HostViewportMetrics) -> Unit): Unit
}

public interface HostTouchService {
    func observe(handler: (TouchEvent) -> Unit): Unit
}

public interface HostFilePickerService {
    func pick(request: FilePickerRequest, completion: (FilePickerResult) -> Unit): Unit
}

public interface HostApplicationStorage {
    func dataDirectory(): String
    func cacheDirectory(): String
    func temporaryDirectory(): String
}

public interface HostSecureStorage {
    func read(namespace: String, key: String): ?Array<Byte>
    func write(namespace: String, key: String, value: Array<Byte>): Unit
    func remove(namespace: String, key: String): Unit
}

public interface HostSystemThemeService {
    func currentPreference(): SystemThemePreference
    func observe(handler: (SystemThemePreference) -> Unit): Unit
}

public interface HostNotificationService {
    func requestAuthorization(completion: (Bool) -> Unit): Unit
    func schedule(request: LocalNotificationRequest): Unit
    func cancel(id: String): Unit
}

public interface HostBackgroundTaskService {
    func begin(name: String, expirationHandler: () -> Unit): ?String
    func end(taskId: String): Unit
}
