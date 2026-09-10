package canghui_scene3d_bgfx

import chui.scene3d.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func shaderDigestMatchesStandardSha256Vectors(): Unit {
    let emptyDigest = shaderSha256Digest([])
    let abcDigest = shaderSha256Digest("abc".toArray())
    @Expect(
        emptyDigest ==
        "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
    @Expect(
        abcDigest ==
        "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
}

@Test
func embeddedMetalShadersHaveStableValidatedDigests(): Unit {
    let program = debugMetalShaderProgram()
    @Expect(program.backend == Scene3DBackend.Metal)
    @Expect(
        program.vertex.digest ==
        "sha256:825bd94ee2f0a0e56ae29ea1ca45d55cd482effd17bb54845885071d7c2dfc3a"
    )
    @Expect(
        program.fragment.digest ==
        "sha256:8d7ba808b27bad9a3953b767a372e2ce8e4c75b6c249bfc68dc896ce2a650172"
    )
    @Expect(program.vertex.layoutSignature == "position3f-color4f-v1")
}

@Test
func shaderResourceRejectsDigestAndContainerDrift(): Unit {
    let resource = debugMetalShaderProgram().vertex
    @ExpectThrows[IllegalArgumentException](
        BgfxShaderResource(
            Scene3DBackend.Metal,
            BgfxShaderStage.Vertex,
            "sha256:0000000000000000000000000000000000000000000000000000000000000000",
            resource.layoutSignature,
            resource.payload()
        )
    )
    let malformed = resource.payload()
    malformed[0] = UInt8(0x46)
    @ExpectThrows[IllegalArgumentException](
        BgfxShaderResource(
            Scene3DBackend.Metal,
            BgfxShaderStage.Vertex,
            shaderSha256Digest(malformed),
            resource.layoutSignature,
            malformed
        )
    )
}

@Test
func shaderProgramRejectsBackendAndLayoutMismatch(): Unit {
    let program = debugMetalShaderProgram()
    let wrongBackend = BgfxShaderResource(
        Scene3DBackend.Vulkan,
        BgfxShaderStage.Fragment,
        program.fragment.digest,
        program.fragment.layoutSignature,
        program.fragment.payload()
    )
    @ExpectThrows[IllegalArgumentException](BgfxShaderProgramResource(program.vertex, wrongBackend))
    let wrongLayout = BgfxShaderResource(
        Scene3DBackend.Metal,
        BgfxShaderStage.Fragment,
        program.fragment.digest,
        "position3f-v1",
        program.fragment.payload()
    )
    @ExpectThrows[IllegalArgumentException](BgfxShaderProgramResource(program.vertex, wrongLayout))
}

@Test
func debugCubeOwnsValidIndexedPayload(): Unit {
    let cube = debugCubeGeometry()
    @Expect(cube.vertexCount == 24)
    @Expect(cube.indexCount == 36)
    let copy = cube.vertices()
    copy[0] = 99.0
    @Expect(cube.vertices()[0] == -1.0)
}

@Test
func geometryRejectsMalformedStrideAndIndices(): Unit {
    @ExpectThrows[IllegalArgumentException](
        BgfxGeometryResource("bad", "layout", 3, [0.0, 1.0], [UInt16(0), UInt16(1), UInt16(2)])
    )
    @ExpectThrows[IllegalArgumentException](
        BgfxGeometryResource(
            "bad", "layout", 3,
            [0.0, 0.0, 0.0, 1.0, 1.0, 1.0],
            [UInt16(0), UInt16(1), UInt16(2)]
        )
    )
}

@Test
func semanticEntityGeometryKeepsStableTopologyAndPalette(): Unit {
    let floor = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "floor", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Floor
    )))
    let route = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "route", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Route
    )))
    let vehicle = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "vehicle", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Vehicle
    )))
    let user = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "user", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.UserMarker
    )))
    let structure = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "structure", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Structure
    )))
    let track = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "track", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Track
    )))
    let facility = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "facility", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Facility
    )))
    let exit = debugEntityGeometry(projectScene3DEntity(Scene3DEntitySnapshot(
        "exit", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.ExitMarker
    )))

    @Expect(floor.id, "debug-floor")
    @Expect(route.id, "debug-route")
    @Expect(vehicle.id, "debug-vehicle")
    @Expect(user.id, "debug-user-marker")
    @Expect(structure.id, "debug-structure")
    @Expect(track.id, "debug-track")
    @Expect(facility.id, "debug-facility")
    @Expect(exit.id, "debug-exit-marker")
    @Expect(floor.vertexCount == 24 && route.vertexCount == 24 &&
        vehicle.vertexCount == 24 && user.vertexCount == 24)
    @Expect(floor.indexCount == 36 && route.indexCount == 36 &&
        vehicle.indexCount == 36 && user.indexCount == 36)
    @Expect(floor.vertices()[3] == 0.36)
    @Expect(route.vertices()[4] == 0.63)
    @Expect(vehicle.vertices()[5] == 0.26)
    @Expect(user.vertices()[3] == 0.18)
    @Expect(structure.vertices()[3] == 0.19)
    @Expect(track.vertices()[3] == 0.16)
    @Expect(facility.vertices()[4] == 0.77)
    @Expect(exit.vertices()[5] == 0.43)
}

@Test
func semanticPaletteCanThemeProviderGeometryWithoutChangingTopology(): Unit {
    let palette = BgfxSemanticPalette(
        floor: BgfxColor4f(0.10, 0.20, 0.30, alpha: 0.90),
        facility: BgfxColor4f(0.40, 0.50, 0.60)
    )
    let floorProjection = projectScene3DEntity(Scene3DEntitySnapshot(
        "floor", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Floor
    ))
    let floor = debugEntityGeometry(floorProjection, palette.color(Scene3DEntityKind.Floor))
    let facilityProjection = projectScene3DEntity(Scene3DEntitySnapshot(
        "facility", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Facility
    ))
    let facility = debugEntityGeometry(
        facilityProjection, palette.color(Scene3DEntityKind.Facility)
    )
    @Expect(floor.vertexCount, Int64(24))
    @Expect(floor.indexCount, Int64(36))
    @Expect(floor.vertices()[3], Float32(0.10))
    @Expect(floor.vertices()[4], Float32(0.20))
    @Expect(floor.vertices()[5], Float32(0.30))
    @Expect(floor.vertices()[6], Float32(0.90))
    @Expect(facility.vertices()[3], Float32(0.40))
    @Expect(facility.vertices()[4], Float32(0.50))
    @Expect(facility.vertices()[5], Float32(0.60))
}

@Test
func semanticPaletteRejectsOutOfRangeChannels(): Unit {
    @ExpectThrows[IllegalArgumentException](BgfxColor4f(-0.01, 0.0, 0.0))
    @ExpectThrows[IllegalArgumentException](BgfxColor4f(0.0, 1.01, 0.0))
    @ExpectThrows[IllegalArgumentException](BgfxColor4f(0.0, 0.0, 0.0, alpha: 1.01))
}
