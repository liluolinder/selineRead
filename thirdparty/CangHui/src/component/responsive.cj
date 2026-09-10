package chui.component

public enum ViewportClass <: Equatable<ViewportClass> {
    | Compact
    | Medium
    | Expanded

    public operator func ==(other: ViewportClass): Bool {
        match ((this, other)) {
            case (ViewportClass.Compact, ViewportClass.Compact) => true
            case (ViewportClass.Medium, ViewportClass.Medium) => true
            case (ViewportClass.Expanded, ViewportClass.Expanded) => true
            case _ => false
        }
    }

    public operator func !=(other: ViewportClass): Bool {
        !(this == other)
    }
}

/** Logical common-layout viewport supplied by a real host or desktop preview. */
public struct ViewportSpec {
    public let id: String
    public let label: String
    public let width: Float32
    public let height: Float32
    public let scale: Float32

    public init(id: String, label: String, width: Float32, height: Float32, scale!: Float32 = 1.0) {
        if (id.isEmpty() || label.isEmpty()) {
            throw IllegalArgumentException("viewport id and label must not be empty")
        }
        if (width <= 0.0 || height <= 0.0 || scale <= 0.0) {
            throw IllegalArgumentException("viewport dimensions and scale must be positive")
        }
        this.id = id
        this.label = label
        this.width = width
        this.height = height
        this.scale = scale
    }

    public func widthClass(): ViewportClass {
        classifyViewport(width)
    }
}

public func classifyViewport(width: Float32): ViewportClass {
    if (width < 600.0) {
        ViewportClass.Compact
    } else if (width < 1024.0) {
        ViewportClass.Medium
    } else {
        ViewportClass.Expanded
    }
}
