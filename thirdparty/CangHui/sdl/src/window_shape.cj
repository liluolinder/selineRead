package sdl

public enum WindowShapeApplyStatus <: Equatable<WindowShapeApplyStatus> {
    | NotRequested
    | Applied
    | Failed

    public operator func ==(other: WindowShapeApplyStatus): Bool {
        windowShapeApplyStatusName(this) == windowShapeApplyStatusName(other)
    }

    public operator func !=(other: WindowShapeApplyStatus): Bool { !(this == other) }
}

public func windowShapeApplyStatusName(status: WindowShapeApplyStatus): String {
    match (status) {
        case WindowShapeApplyStatus.NotRequested => "not-requested"
        case WindowShapeApplyStatus.Applied => "applied"
        case WindowShapeApplyStatus.Failed => "failed"
    }
}

/** Honest runtime receipt; host compositor behavior remains field proof pending. */
public struct WindowShapeReceipt {
    public let status: WindowShapeApplyStatus
    public let requestedRadius: Float32
    public let appliedRadius: Float32
    public let pixelWidth: Int32
    public let pixelHeight: Int32
    public let softwareConformanceComplete: Bool
    public let hostRuntimeComplete: Bool
    public let fieldProofPending: Bool
    public let detail: String

    public init(
        status: WindowShapeApplyStatus,
        requestedRadius: Float32,
        appliedRadius: Float32,
        pixelWidth: Int32,
        pixelHeight: Int32,
        detail!: String = ""
    ) {
        this.status = status
        this.requestedRadius = requestedRadius
        this.appliedRadius = appliedRadius
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        // Runtime application status is not a substitute for a conformance test result.
        this.softwareConformanceComplete = false
        this.hostRuntimeComplete = false
        this.fieldProofPending = true
        this.detail = detail
    }
}

protected struct WindowShapeCapabilityReceipt {
    public let platform: String
    public let contractAvailable: Bool
    public let softwareConformanceComplete: Bool
    public let hostRuntimeComplete: Bool
    public let fieldProofPending: Bool
    public let detail: String

    public init(platform: String) {
        if (platform != "windows" && platform != "linux-x11" && platform != "linux-wayland" &&
            platform != "macos") {
            throw IllegalArgumentException("unsupported window-shape receipt platform '${platform}'")
        }
        this.platform = platform
        this.contractAvailable = true
        // A static capability query is not a test result.
        this.softwareConformanceComplete = false
        this.hostRuntimeComplete = false
        this.fieldProofPending = true
        this.detail = "binary-mask contract available; software and compositor field proof pending"
    }
}

/**
 * Applies a binary alpha mask to the native window. SDL copies the surface, so the
 * temporary can be closed immediately. This must run on the window-owning thread.
 */
internal func applyRoundedWindowShape(
    window: CPointer<Unit>,
    pixelWidth: Int32,
    pixelHeight: Int32,
    requestedRadius: Float32
): WindowShapeReceipt {
    if (requestedRadius <= 0.0) {
        return WindowShapeReceipt(WindowShapeApplyStatus.NotRequested, requestedRadius, 0.0,
            pixelWidth, pixelHeight, detail: "shape not requested")
    }
    let radius = fittedCornerRadius(pixelWidth, pixelHeight, requestedRadius)
    if (window.isNull() || radius <= 0.0 || pixelWidth <= 0 || pixelHeight <= 0) {
        return WindowShapeReceipt(WindowShapeApplyStatus.Failed, requestedRadius, 0.0,
            pixelWidth, pixelHeight, detail: "shape request has no valid native surface")
    }

    let mask = Surface.create(pixelWidth, pixelHeight)
    try (resource = mask) {
        resource.clear(Color.rgba(255, 255, 255, 255))
        let edge = Int32(radius) + 1
        for (y in 0..edge) {
            for (x in 0..edge) {
                let alpha = roundedCornerAlpha(x, y, radius)
                if (alpha == UInt8(255)) {
                    continue
                }
                let color = Color(255, 255, 255, alpha)
                resource.writePixel(x, y, color)
                resource.writePixel(pixelWidth - 1 - x, y, color)
                resource.writePixel(x, pixelHeight - 1 - y, color)
                resource.writePixel(pixelWidth - 1 - x, pixelHeight - 1 - y, color)
            }
        }
        if (!unsafe { SDL_SetWindowShape(window, resource.ptr) }) {
            return WindowShapeReceipt(WindowShapeApplyStatus.Failed, requestedRadius, 0.0,
                pixelWidth, pixelHeight, detail: "SDL_SetWindowShape unavailable on current host")
        }
    }
    WindowShapeReceipt(WindowShapeApplyStatus.Applied, requestedRadius, radius, pixelWidth, pixelHeight)
}

internal func fittedCornerRadius(width: Int32, height: Int32, requested: Float32): Float32 {
    if (requested <= 0.0 || width <= 0 || height <= 0) {
        return 0.0
    }
    let shortest = if (width < height) { width } else { height }
    let maximum = Float32(shortest) / 2.0
    if (requested < maximum) { requested } else { maximum }
}

internal func roundedCornerAlpha(x: Int32, y: Int32, radius: Float32): UInt8 {
    if (radius <= 0.0) {
        return UInt8(255)
    }
    let dx = radius - (Float32(x) + 0.5)
    let dy = radius - (Float32(y) + 0.5)
    if (dx <= 0.0 || dy <= 0.0 || dx * dx + dy * dy <= radius * radius) {
        UInt8(255)
    } else {
        UInt8(0)
    }
}
