package canghui_scene3d_bgfx

import chui.scene3d.Scene3DEntityKind

/** Normalized provider color used to theme semantic debug geometry. */
public struct BgfxColor4f {
    public let red: Float32
    public let green: Float32
    public let blue: Float32
    public let alpha: Float32

    public init(red: Float32, green: Float32, blue: Float32, alpha!: Float32 = 1.0) {
        if (!bgfxColorChannelIsValid(red) || !bgfxColorChannelIsValid(green) ||
            !bgfxColorChannelIsValid(blue) || !bgfxColorChannelIsValid(alpha)) {
            throw IllegalArgumentException("bgfx semantic palette channels must be normalized")
        }
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }
}

/**
 * Product-supplied palette for the provider's eight renderer-neutral semantic kinds.
 *
 * Geometry, identity and scene ownership stay inside the existing Scene3D contract;
 * this value only selects provider colors at driver construction time.
 */
public class BgfxSemanticPalette {
    public let floor: BgfxColor4f
    public let route: BgfxColor4f
    public let vehicle: BgfxColor4f
    public let userMarker: BgfxColor4f
    public let structure: BgfxColor4f
    public let track: BgfxColor4f
    public let facility: BgfxColor4f
    public let exitMarker: BgfxColor4f

    public init(
        floor!: BgfxColor4f = BgfxColor4f(0.36, 0.43, 0.46),
        route!: BgfxColor4f = BgfxColor4f(0.95, 0.63, 0.23),
        vehicle!: BgfxColor4f = BgfxColor4f(0.83, 0.32, 0.26),
        userMarker!: BgfxColor4f = BgfxColor4f(0.18, 0.64, 0.96),
        structure!: BgfxColor4f = BgfxColor4f(0.19, 0.38, 0.39),
        track!: BgfxColor4f = BgfxColor4f(0.16, 0.20, 0.22),
        facility!: BgfxColor4f = BgfxColor4f(0.96, 0.77, 0.25),
        exitMarker!: BgfxColor4f = BgfxColor4f(0.21, 0.72, 0.43)
    ) {
        this.floor = floor
        this.route = route
        this.vehicle = vehicle
        this.userMarker = userMarker
        this.structure = structure
        this.track = track
        this.facility = facility
        this.exitMarker = exitMarker
    }

    public func color(kind: Scene3DEntityKind): BgfxColor4f {
        match (kind) {
            case Scene3DEntityKind.Floor => floor
            case Scene3DEntityKind.Route => route
            case Scene3DEntityKind.Vehicle => vehicle
            case Scene3DEntityKind.UserMarker => userMarker
            case Scene3DEntityKind.Structure => structure
            case Scene3DEntityKind.Track => track
            case Scene3DEntityKind.Facility => facility
            case Scene3DEntityKind.ExitMarker => exitMarker
        }
    }
}

private func bgfxColorChannelIsValid(value: Float32): Bool {
    value >= 0.0 && value <= 1.0
}
