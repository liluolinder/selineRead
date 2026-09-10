package canghui_scene3d_bgfx

import chui.scene3d.*

private let DEBUG_GEOMETRY_LAYOUT = "position3f-color4f-v1"

/** Immutable indexed geometry accepted by the bgfx provider upload boundary. */
public class BgfxGeometryResource {
    public let id: String
    public let layoutSignature: String
    public let vertexStrideFloats: Int64
    private let vertexData: Array<Float32>
    private let indexData: Array<UInt16>

    public init(
        id: String,
        layoutSignature: String,
        vertexStrideFloats: Int64,
        vertices: Array<Float32>,
        indices: Array<UInt16>
    ) {
        if (id.isEmpty() || layoutSignature.isEmpty()) {
            throw IllegalArgumentException("geometry id and layout signature must not be empty")
        }
        if (vertexStrideFloats <= 0 || vertices.size == 0 || vertices.size % vertexStrideFloats != 0) {
            throw IllegalArgumentException("geometry vertex payload does not match its stride")
        }
        if (indices.size < 3 || indices.size % 3 != 0) {
            throw IllegalArgumentException("geometry index payload must contain complete triangles")
        }
        let count = vertices.size / vertexStrideFloats
        for (index in indices) {
            if (Int64(index) >= count) {
                throw IllegalArgumentException("geometry index is outside the vertex payload")
            }
        }
        this.id = id
        this.layoutSignature = layoutSignature
        this.vertexStrideFloats = vertexStrideFloats
        this.vertexData = vertices.clone()
        this.indexData = indices.clone()
    }

    public prop vertexCount: Int64 { get() { vertexData.size / vertexStrideFloats } }
    public prop indexCount: Int64 { get() { indexData.size } }
    public func vertices(): Array<Float32> { vertexData.clone() }
    public func indices(): Array<UInt16> { indexData.clone() }
}

/** Low-poly colored cube used by generic Scene3D bring-up and diagnostics. */
public func debugCubeGeometry(): BgfxGeometryResource {
    debugCubeGeometryWithColor("debug-cube", 0.53, 0.58, 0.69, 1.0)
}

/** Builds the provider-owned geometry and semantic palette for one projection. */
public func debugEntityGeometry(projection: Scene3DDebugEntityProjection): BgfxGeometryResource {
    debugCubeGeometryWithColor(
        "debug-" + scene3dEntityKindName(projection.kind),
        projection.red, projection.green, projection.blue, projection.alpha
    )
}

/** Builds the same bounded geometry with a driver-selected semantic color. */
public func debugEntityGeometry(
    projection: Scene3DDebugEntityProjection,
    color: BgfxColor4f
): BgfxGeometryResource {
    debugCubeGeometryWithColor(
        "debug-" + scene3dEntityKindName(projection.kind),
        color.red, color.green, color.blue, color.alpha
    )
}

private func debugCubeGeometryWithColor(
    id: String,
    red: Float32,
    green: Float32,
    blue: Float32,
    alpha: Float32
): BgfxGeometryResource {
    let frontRed = debugShade(red, 1.0)
    let frontGreen = debugShade(green, 1.0)
    let frontBlue = debugShade(blue, 1.0)
    let backRed = debugShade(red, 0.72)
    let backGreen = debugShade(green, 0.72)
    let backBlue = debugShade(blue, 0.72)
    let topRed = debugShade(red, 1.14)
    let topGreen = debugShade(green, 1.14)
    let topBlue = debugShade(blue, 1.14)
    let bottomRed = debugShade(red, 0.62)
    let bottomGreen = debugShade(green, 0.62)
    let bottomBlue = debugShade(blue, 0.62)
    let rightRed = debugShade(red, 0.90)
    let rightGreen = debugShade(green, 0.90)
    let rightBlue = debugShade(blue, 0.90)
    let leftRed = debugShade(red, 0.80)
    let leftGreen = debugShade(green, 0.80)
    let leftBlue = debugShade(blue, 0.80)
    let vertices: Array<Float32> = [
        -1.0, -1.0,  1.0, frontRed, frontGreen, frontBlue, alpha,
         1.0, -1.0,  1.0, frontRed, frontGreen, frontBlue, alpha,
         1.0,  1.0,  1.0, frontRed, frontGreen, frontBlue, alpha,
        -1.0,  1.0,  1.0, frontRed, frontGreen, frontBlue, alpha,
         1.0, -1.0, -1.0, backRed, backGreen, backBlue, alpha,
        -1.0, -1.0, -1.0, backRed, backGreen, backBlue, alpha,
        -1.0,  1.0, -1.0, backRed, backGreen, backBlue, alpha,
         1.0,  1.0, -1.0, backRed, backGreen, backBlue, alpha,
        -1.0,  1.0,  1.0, topRed, topGreen, topBlue, alpha,
         1.0,  1.0,  1.0, topRed, topGreen, topBlue, alpha,
         1.0,  1.0, -1.0, topRed, topGreen, topBlue, alpha,
        -1.0,  1.0, -1.0, topRed, topGreen, topBlue, alpha,
        -1.0, -1.0, -1.0, bottomRed, bottomGreen, bottomBlue, alpha,
         1.0, -1.0, -1.0, bottomRed, bottomGreen, bottomBlue, alpha,
         1.0, -1.0,  1.0, bottomRed, bottomGreen, bottomBlue, alpha,
        -1.0, -1.0,  1.0, bottomRed, bottomGreen, bottomBlue, alpha,
         1.0, -1.0,  1.0, rightRed, rightGreen, rightBlue, alpha,
         1.0, -1.0, -1.0, rightRed, rightGreen, rightBlue, alpha,
         1.0,  1.0, -1.0, rightRed, rightGreen, rightBlue, alpha,
         1.0,  1.0,  1.0, rightRed, rightGreen, rightBlue, alpha,
        -1.0, -1.0, -1.0, leftRed, leftGreen, leftBlue, alpha,
        -1.0, -1.0,  1.0, leftRed, leftGreen, leftBlue, alpha,
        -1.0,  1.0,  1.0, leftRed, leftGreen, leftBlue, alpha,
        -1.0,  1.0, -1.0, leftRed, leftGreen, leftBlue, alpha
    ]
    let indices: Array<UInt16> = [
         0,  1,  2,  0,  2,  3,
         4,  5,  6,  4,  6,  7,
         8,  9, 10,  8, 10, 11,
        12, 13, 14, 12, 14, 15,
        16, 17, 18, 16, 18, 19,
        20, 21, 22, 20, 22, 23
    ]
    BgfxGeometryResource(id, DEBUG_GEOMETRY_LAYOUT, 7, vertices, indices)
}

private func debugShade(value: Float32, factor: Float32): Float32 {
    let shaded = value * factor
    if (shaded > 1.0) { 1.0 } else if (shaded < 0.0) { 0.0 } else { shaded }
}
