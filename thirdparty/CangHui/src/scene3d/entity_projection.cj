package chui.scene3d

/** Generic entity classes understood by debug Scene3D providers. */
public enum Scene3DEntityKind <: Equatable<Scene3DEntityKind> {
    | Floor
    | Route
    | Vehicle
    | UserMarker
    | Structure
    | Track
    | Facility
    | ExitMarker

    public operator func ==(other: Scene3DEntityKind): Bool {
        scene3dEntityKindName(this) == scene3dEntityKindName(other)
    }

    public operator func !=(other: Scene3DEntityKind): Bool { !(this == other) }
}

public func scene3dEntityKindName(kind: Scene3DEntityKind): String {
    match (kind) {
        case Scene3DEntityKind.Floor => "floor"
        case Scene3DEntityKind.Route => "route"
        case Scene3DEntityKind.Vehicle => "vehicle"
        case Scene3DEntityKind.UserMarker => "user-marker"
        case Scene3DEntityKind.Structure => "structure"
        case Scene3DEntityKind.Track => "track"
        case Scene3DEntityKind.Facility => "facility"
        case Scene3DEntityKind.ExitMarker => "exit-marker"
    }
}

/** Low-detail geometry families used for provider-neutral diagnostics. */
public enum Scene3DDebugGeometryFamily <: Equatable<Scene3DDebugGeometryFamily> {
    | Slab
    | Ribbon
    | Box
    | Marker

    public operator func ==(other: Scene3DDebugGeometryFamily): Bool {
        scene3dDebugGeometryFamilyName(this) == scene3dDebugGeometryFamilyName(other)
    }

    public operator func !=(other: Scene3DDebugGeometryFamily): Bool { !(this == other) }
}

public func scene3dDebugGeometryFamilyName(family: Scene3DDebugGeometryFamily): String {
    match (family) {
        case Scene3DDebugGeometryFamily.Slab => "slab"
        case Scene3DDebugGeometryFamily.Ribbon => "ribbon"
        case Scene3DDebugGeometryFamily.Box => "box"
        case Scene3DDebugGeometryFamily.Marker => "marker"
    }
}

/** Stable semantic palette roles; product styling stays outside this contract. */
public enum Scene3DSemanticColor <: Equatable<Scene3DSemanticColor> {
    | GroundNeutral
    | RouteAccent
    | VehicleAccent
    | UserHighlight
    | StructureNeutral
    | TrackNeutral
    | FacilityAccent
    | ExitAccent

    public operator func ==(other: Scene3DSemanticColor): Bool {
        scene3dSemanticColorName(this) == scene3dSemanticColorName(other)
    }

    public operator func !=(other: Scene3DSemanticColor): Bool { !(this == other) }
}

public func scene3dSemanticColorName(color: Scene3DSemanticColor): String {
    match (color) {
        case Scene3DSemanticColor.GroundNeutral => "ground-neutral"
        case Scene3DSemanticColor.RouteAccent => "route-accent"
        case Scene3DSemanticColor.VehicleAccent => "vehicle-accent"
        case Scene3DSemanticColor.UserHighlight => "user-highlight"
        case Scene3DSemanticColor.StructureNeutral => "structure-neutral"
        case Scene3DSemanticColor.TrackNeutral => "track-neutral"
        case Scene3DSemanticColor.FacilityAccent => "facility-accent"
        case Scene3DSemanticColor.ExitAccent => "exit-accent"
    }
}

/**
 * Immutable debug projection consumed by optional providers. It binds a public
 * entity id and position to one bounded geometry family, scale and semantic
 * color without exposing renderer handles or product model types.
 */
public struct Scene3DDebugEntityProjection {
    public let entityId: String
    public let kind: Scene3DEntityKind
    public let geometryFamily: Scene3DDebugGeometryFamily
    public let semanticColor: Scene3DSemanticColor
    public let x: Float32
    public let y: Float32
    public let z: Float32
    public let scaleX: Float32
    public let scaleY: Float32
    public let scaleZ: Float32
    public let rotationX: Float32
    public let rotationY: Float32
    public let rotationZ: Float32
    public let red: Float32
    public let green: Float32
    public let blue: Float32
    public let alpha: Float32
    public let visible: Bool

    public init(
        entityId: String,
        kind: Scene3DEntityKind,
        geometryFamily: Scene3DDebugGeometryFamily,
        semanticColor: Scene3DSemanticColor,
        x: Float32,
        y: Float32,
        z: Float32,
        scaleX: Float32,
        scaleY: Float32,
        scaleZ: Float32,
        rotationX: Float32,
        rotationY: Float32,
        rotationZ: Float32,
        red: Float32,
        green: Float32,
        blue: Float32,
        alpha: Float32,
        visible: Bool
    ) {
        if (entityId.isEmpty()) {
            throw IllegalArgumentException("scene3d debug projection entity id must be present")
        }
        if (scaleX <= 0.0 || scaleY <= 0.0 || scaleZ <= 0.0) {
            throw IllegalArgumentException("scene3d debug projection scale must be positive")
        }
        if (!scene3dColorChannelIsValid(red) || !scene3dColorChannelIsValid(green) ||
            !scene3dColorChannelIsValid(blue) || !scene3dColorChannelIsValid(alpha)) {
            throw IllegalArgumentException("scene3d debug projection color must be normalized")
        }
        this.entityId = entityId
        this.kind = kind
        this.geometryFamily = geometryFamily
        this.semanticColor = semanticColor
        this.x = x
        this.y = y
        this.z = z
        this.scaleX = scaleX
        this.scaleY = scaleY
        this.scaleZ = scaleZ
        this.rotationX = rotationX
        this.rotationY = rotationY
        this.rotationZ = rotationZ
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
        this.visible = visible
    }
}

/** Maps one product-neutral snapshot into the bounded debug vocabulary. */
public func projectScene3DEntity(entity: Scene3DEntitySnapshot): Scene3DDebugEntityProjection {
    match (entity.kind) {
        case Scene3DEntityKind.Floor => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Slab,
            Scene3DSemanticColor.GroundNeutral, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 3.8), scene3dScale(entity.scaleY, 0.12),
            scene3dScale(entity.scaleZ, 2.8), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.36, 0.43, 0.46, 1.0, entity.visible
        )
        case Scene3DEntityKind.Route => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Ribbon,
            Scene3DSemanticColor.RouteAccent, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 2.8), scene3dScale(entity.scaleY, 0.08),
            scene3dScale(entity.scaleZ, 0.22), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.95, 0.63, 0.23, 1.0, entity.visible
        )
        case Scene3DEntityKind.Vehicle => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Box,
            Scene3DSemanticColor.VehicleAccent, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 0.72), scene3dScale(entity.scaleY, 0.42),
            scene3dScale(entity.scaleZ, 0.46), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.83, 0.32, 0.26, 1.0, entity.visible
        )
        case Scene3DEntityKind.UserMarker => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Marker,
            Scene3DSemanticColor.UserHighlight, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 0.20), scene3dScale(entity.scaleY, 0.72),
            scene3dScale(entity.scaleZ, 0.20), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.18, 0.64, 0.96, 1.0, entity.visible
        )
        case Scene3DEntityKind.Structure => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Box,
            Scene3DSemanticColor.StructureNeutral, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 0.9), scene3dScale(entity.scaleY, 0.42),
            scene3dScale(entity.scaleZ, 0.9), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.19, 0.38, 0.39, 1.0, entity.visible
        )
        case Scene3DEntityKind.Track => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Ribbon,
            Scene3DSemanticColor.TrackNeutral, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 3.2), scene3dScale(entity.scaleY, 0.06),
            scene3dScale(entity.scaleZ, 0.12), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.16, 0.20, 0.22, 1.0, entity.visible
        )
        case Scene3DEntityKind.Facility => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Marker,
            Scene3DSemanticColor.FacilityAccent, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 0.24), scene3dScale(entity.scaleY, 0.42),
            scene3dScale(entity.scaleZ, 0.24), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.96, 0.77, 0.25, 1.0, entity.visible
        )
        case Scene3DEntityKind.ExitMarker => Scene3DDebugEntityProjection(
            entity.id, entity.kind, Scene3DDebugGeometryFamily.Marker,
            Scene3DSemanticColor.ExitAccent, entity.x, entity.y, entity.z,
            scene3dScale(entity.scaleX, 0.28), scene3dScale(entity.scaleY, 0.68),
            scene3dScale(entity.scaleZ, 0.28), entity.rotationX, entity.rotationY, entity.rotationZ,
            0.21, 0.72, 0.43, 1.0, entity.visible
        )
    }
}

private func scene3dScale(value: Float32, fallback: Float32): Float32 {
    if (value > 0.0) { value } else { fallback }
}

private func scene3dColorChannelIsValid(value: Float32): Bool {
    value >= 0.0 && value <= 1.0
}
