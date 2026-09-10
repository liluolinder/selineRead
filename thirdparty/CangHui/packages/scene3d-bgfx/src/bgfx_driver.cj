package canghui_scene3d_bgfx

import chui.scene3d.*
import bgfx4cj.bgfx.*
import bgfx4cj.bx.*

/**
 * Minimal bgfx4cj driver. The platform host injects the native window pointer;
 * CangHui surface ids and generations remain serializable protocol data.
 */
public class Bgfx4cjDriver <: Scene3DDriver {
    private let nativeWindow: CPointer<Unit>
    private let nativeWindowIdentity: UInt64
    private var initialized = false
    private var metadataOnly = false
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var resourceId = ""
    private var sceneId = ""
    private var lastFrameId: Int64 = -1
    private var pixelWidth: Int64 = 0
    private var pixelHeight: Int64 = 0
    private let clearColor: UInt32
    private let palette: BgfxSemanticPalette
    private let geometry: BgfxGeometryResource
    private let shaders: BgfxShaderProgramResource
    private var vertexLayout = VertexLayoutHandle()
    private var floorVertexBuffer = VertexBufferHandle()
    private var routeVertexBuffer = VertexBufferHandle()
    private var vehicleVertexBuffer = VertexBufferHandle()
    private var userMarkerVertexBuffer = VertexBufferHandle()
    private var structureVertexBuffer = VertexBufferHandle()
    private var trackVertexBuffer = VertexBufferHandle()
    private var facilityVertexBuffer = VertexBufferHandle()
    private var exitMarkerVertexBuffer = VertexBufferHandle()
    private var indexBuffer = IndexBufferHandle()
    private var program = ProgramHandle()
    private var viewMatrix = CPointer<Float32>()
    private var projectionMatrix = CPointer<Float32>()
    private var modelMatrix = CPointer<Float32>()

    public init(
        nativeWindow: CPointer<Unit>,
        nativeWindowIdentity: UInt64,
        clearColor!: UInt32 = 0x20242AFF,
        palette!: BgfxSemanticPalette = BgfxSemanticPalette(),
        geometry!: BgfxGeometryResource = debugCubeGeometry(),
        shaders!: BgfxShaderProgramResource = debugMetalShaderProgram()
    ) {
        if (nativeWindow.isNull() || nativeWindowIdentity == UInt64(0)) {
            throw IllegalArgumentException("bgfx4cj native window pointer and identity must be present")
        }
        this.nativeWindow = nativeWindow
        this.nativeWindowIdentity = nativeWindowIdentity
        this.clearColor = clearColor
        this.palette = palette
        if (geometry.layoutSignature != shaders.layoutSignature) {
            throw IllegalArgumentException("bgfx geometry and shader layout signatures do not match")
        }
        this.geometry = geometry
        this.shaders = shaders
    }

    public func driverName(): String { "bgfx4cj" }

    public func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DDriverResult {
        if (initialized) {
            return Scene3DDriverResult.rejected("already-attached", "bgfx is already initialized")
        }
        if (surface.opaqueHandle != nativeWindowIdentity) {
            return Scene3DDriverResult.rejected(
                "surface-handle-mismatch", "injected native window does not match the host surface identity"
            )
        }
        metadataOnly = surface.backend == Scene3DBackend.Software
        if (!metadataOnly && surface.backend != shaders.backend) {
            return Scene3DDriverResult.rejected(
                "shader-backend-mismatch", "shader resources do not support the requested backend"
            )
        }
        let initPtr = unsafe { LibC.malloc<Init>() }
        unsafe { initPtr.write(Init()) }
        bgfx_init_ctor_cj(initPtr)

        var params = unsafe { initPtr.read() }
        params.`type` = rendererFor(surface.backend).value()
        params.platformData.nwh = nativeWindow
        params.resolution.width = UInt32(surface.pixelWidth)
        params.resolution.height = UInt32(surface.pixelHeight)
        params.resolution.reset = RESET_VSYNC
        params.resolution.numBackBuffers = 2
        params.resolution.maxFrameLatency = 2
        params.resolution.debugTextScale = 1
        unsafe { initPtr.write(params) }

        if (surface.backend == Scene3DBackend.Metal) {
            let _ = bgfx_render_frame_cj(0)
        }
        let ok = bgfx_init_cj(initPtr)
        unsafe { LibC.free(initPtr) }
        if (!ok) {
            return Scene3DDriverResult.rejected("bgfx-init-failed", "bgfx_init returned false")
        }
        initialized = true
        surfaceId = surface.id
        generation = surface.generation
        pixelWidth = surface.pixelWidth
        pixelHeight = surface.pixelHeight
        resourceId = ""
        sceneId = ""
        lastFrameId = clock.frameId
        bgfx_set_view_clear_cj(0, CLEAR_COLOR | CLEAR_DEPTH, clearColor, 1.0, 0)
        setViewRect()
        allocateMatrices()
        Scene3DDriverResult.accepted(detail: "bgfx initialized for depth-tested geometry")
    }

    public func resize(surface: Scene3DHostSurface): Scene3DDriverResult {
        if (!matches(surface.generation)) {
            return Scene3DDriverResult.rejected("stale-generation", "bgfx resize generation mismatch")
        }
        bgfx_reset_cj(UInt32(surface.pixelWidth), UInt32(surface.pixelHeight), RESET_VSYNC, 0)
        pixelWidth = surface.pixelWidth
        pixelHeight = surface.pixelHeight
        setViewRect()
        Scene3DDriverResult.accepted(detail: "bgfx backbuffer reset")
    }

    public func loadScene(resource: Scene3DResource): Scene3DDriverResult {
        if (!initialized) {
            return Scene3DDriverResult.rejected("not-attached", "bgfx is not initialized")
        }
        if (metadataOnly) {
            resourceId = resource.id
            return Scene3DDriverResult(true, "metadata-staged", "software backend keeps scene metadata only")
        }
        if (isGeometryReady()) {
            return Scene3DDriverResult.rejected("scene-already-loaded", "bgfx geometry is already uploaded")
        }
        let upload = uploadResources()
        if (!upload.ok) { return upload }
        resourceId = resource.id
        Scene3DDriverResult.accepted(detail: "vertex, index and shader resources uploaded")
    }

    public func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DDriverResult {
        if (!initialized || resourceId.isEmpty()) {
            return Scene3DDriverResult.rejected("scene-not-ready", "bgfx scene metadata is not ready")
        }
        sceneId = snapshot.sceneId
        lastFrameId = clock.frameId
        setViewRect()
        if (metadataOnly) {
            bgfx_touch_cj(0)
            return Scene3DDriverResult(true, "clear-frame-only",
                "software backend accepted sealed metadata without shader geometry")
        }
        setCamera(snapshot.camera)
        var submitted: Int64 = 0
        for (i in 0..snapshot.entityCount()) {
            let projection = projectScene3DEntity(snapshot.entityAt(i))
            if (!projection.visible) { continue }
            setModel(projection)
            bgfx_set_state_cj(
                STATE_WRITE_RGB | STATE_WRITE_A | STATE_WRITE_Z | STATE_DEPTH_TEST_LESS | STATE_MSAA,
                UInt32(0)
            )
            bgfx_set_vertex_buffer_cj(
                0, vertexBufferFor(projection.kind), 0, UInt32(geometry.vertexCount)
            )
            bgfx_set_index_buffer_cj(indexBuffer, 0, UInt32(geometry.indexCount))
            bgfx_submit_cj(0, program, 0, UInt8(0xff))
            submitted += 1
        }
        if (submitted == 0) { bgfx_touch_cj(0) }
        Scene3DDriverResult.accepted(detail: "${submitted} semantic debug entities submitted")
    }

    public func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult {
        Scene3DHitTestResult.none(request.generation, request.frameId)
    }

    public func present(clock: Scene3DFrameClock): Scene3DDriverResult {
        if (!initialized) {
            return Scene3DDriverResult.rejected("not-attached", "bgfx is not initialized")
        }
        lastFrameId = clock.frameId
        let _ = bgfx_frame_cj(false)
        Scene3DDriverResult.accepted(detail: "bgfx frame advanced")
    }

    /** Requests the current backbuffer. bgfx writes a TGA beside the requested path. */
    public func requestBackbufferCapture(path: String): Scene3DDriverResult {
        if (!initialized) {
            return Scene3DDriverResult.rejected("not-attached", "bgfx is not initialized")
        }
        if (path.isEmpty()) {
            return Scene3DDriverResult.rejected("capture-path-missing", "capture path must not be empty")
        }
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            bgfx_request_screen_shot_cj(FrameBufferHandle(), pathResource.value)
        }
        Scene3DDriverResult.accepted(detail: "bgfx backbuffer capture requested")
    }

    public func detach(surfaceId: String, generation: Int64): Scene3DDriverResult {
        if (surfaceId != this.surfaceId || !matches(generation)) {
            return Scene3DDriverResult.rejected("stale-generation", "bgfx detach generation mismatch")
        }
        destroyResources()
        freeMatrices()
        bgfx_shutdown_cj()
        initialized = false
        metadataOnly = false
        this.surfaceId = ""
        this.generation = 0
        resourceId = ""
        sceneId = ""
        lastFrameId = -1
        pixelWidth = 0
        pixelHeight = 0
        Scene3DDriverResult.accepted(detail: "bgfx shut down")
    }

    public func isInitialized(): Bool { initialized }

    private func matches(value: Int64): Bool {
        initialized && value == generation
    }

    private func rendererFor(backend: Scene3DBackend): RendererType {
        match (backend) {
            case Scene3DBackend.Metal => RendererType.Metal
            case Scene3DBackend.Vulkan => RendererType.Vulkan
            case Scene3DBackend.OpenGLES => RendererType.OpenGLES
            case Scene3DBackend.D3D11 => RendererType.Direct3D11
            case Scene3DBackend.D3D12 => RendererType.Direct3D12
            case Scene3DBackend.Software => RendererType.Noop
        }
    }

    private func setViewRect(): Unit {
        bgfx_set_view_rect_cj(0, 0, 0, UInt16(pixelWidth), UInt16(pixelHeight))
    }

    private func isGeometryReady(): Bool {
        floorVertexBuffer.idx != UInt16(0xffff) &&
        routeVertexBuffer.idx != UInt16(0xffff) &&
        vehicleVertexBuffer.idx != UInt16(0xffff) &&
        userMarkerVertexBuffer.idx != UInt16(0xffff) &&
        structureVertexBuffer.idx != UInt16(0xffff) &&
        trackVertexBuffer.idx != UInt16(0xffff) &&
        facilityVertexBuffer.idx != UInt16(0xffff) &&
        exitMarkerVertexBuffer.idx != UInt16(0xffff) &&
        indexBuffer.idx != UInt16(0xffff) && program.idx != UInt16(0xffff)
    }

    private func uploadResources(): Scene3DDriverResult {
        let layout = unsafe { LibC.malloc<VertexLayout>() }
        unsafe { layout.write(VertexLayout()) }
        bgfx_vertex_layout_begin_cj(layout, RendererType.Metal.value())
        bgfx_vertex_layout_add_cj(
            layout, Attrib.Position.value(), UInt8(3), AttribType.Float.value(), false, false
        )
        bgfx_vertex_layout_add_cj(
            layout, Attrib.Color0.value(), UInt8(4), AttribType.Float.value(), false, false
        )
        bgfx_vertex_layout_end_cj(layout)
        if (bgfx_vertex_layout_get_stride_cj(layout) != UInt16(28)) {
            unsafe { LibC.free(layout) }
            return Scene3DDriverResult.rejected("vertex-layout-invalid", "bgfx vertex stride is not 28 bytes")
        }

        vertexLayout = bgfx_create_vertex_layout_cj(layout)
        floorVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.Floor, layout)
        routeVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.Route, layout)
        vehicleVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.Vehicle, layout)
        userMarkerVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.UserMarker, layout)
        structureVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.Structure, layout)
        trackVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.Track, layout)
        facilityVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.Facility, layout)
        exitMarkerVertexBuffer = createSemanticVertexBuffer(Scene3DEntityKind.ExitMarker, layout)
        unsafe { LibC.free(layout) }

        let indices = geometry.indices()
        indexBuffer = bgfx_create_index_buffer_cj(copyUInt16Memory(indices), BUFFER_NONE)

        let vertexShader = createShader(shaders.vertex)
        let fragmentShader = createShader(shaders.fragment)
        if (vertexShader.idx == UInt16(0xffff) || fragmentShader.idx == UInt16(0xffff)) {
            if (vertexShader.idx != UInt16(0xffff)) { bgfx_destroy_shader_cj(vertexShader) }
            if (fragmentShader.idx != UInt16(0xffff)) { bgfx_destroy_shader_cj(fragmentShader) }
            destroyResources()
            return Scene3DDriverResult.rejected("shader-create-failed", "bgfx rejected a validated shader resource")
        }
        program = bgfx_create_program_cj(vertexShader, fragmentShader, true)
        if (!isGeometryReady()) {
            destroyResources()
            return Scene3DDriverResult.rejected("geometry-upload-failed", "bgfx rejected geometry or program resources")
        }
        Scene3DDriverResult.accepted(detail: "bgfx resources uploaded")
    }

    private func createShader(resource: BgfxShaderResource): ShaderHandle {
        let payload = resource.payload()
        let bytes = unsafe { LibC.malloc<UInt8>(count: payload.size) }
        unsafe {
            for (i in 0..payload.size) { (bytes + i).write(UInt8(payload[i])) }
            let memory = bgfx_copy_cj(CPointer<Unit>(bytes), UInt32(payload.size))
            LibC.free(bytes)
            bgfx_create_shader_cj(memory)
        }
    }

    private func copyFloat32Memory(values: Array<Float32>): CPointer<Memory> {
        let bytes = unsafe { LibC.malloc<Float32>(count: values.size) }
        unsafe {
            for (i in 0..values.size) { (bytes + i).write(values[i]) }
            let memory = bgfx_copy_cj(CPointer<Unit>(bytes), UInt32(values.size * 4))
            LibC.free(bytes)
            memory
        }
    }

    private func createSemanticVertexBuffer(
        kind: Scene3DEntityKind,
        layout: CPointer<VertexLayout>
    ): VertexBufferHandle {
        let entity = Scene3DEntitySnapshot(
            scene3dEntityKindName(kind), 0.0, 0.0, 0.0, kind: kind
        )
        let semanticGeometry = debugEntityGeometry(
            projectScene3DEntity(entity), palette.color(kind)
        )
        if (semanticGeometry.layoutSignature != geometry.layoutSignature ||
            semanticGeometry.vertexCount != geometry.vertexCount ||
            semanticGeometry.indexCount != geometry.indexCount) {
            return VertexBufferHandle()
        }
        bgfx_create_vertex_buffer_cj(
            copyFloat32Memory(semanticGeometry.vertices()), layout, BUFFER_NONE
        )
    }

    private func copyUInt16Memory(values: Array<UInt16>): CPointer<Memory> {
        let bytes = unsafe { LibC.malloc<UInt16>(count: values.size) }
        unsafe {
            for (i in 0..values.size) { (bytes + i).write(values[i]) }
            let memory = bgfx_copy_cj(CPointer<Unit>(bytes), UInt32(values.size * 2))
            LibC.free(bytes)
            memory
        }
    }

    private func allocateMatrices(): Unit {
        viewMatrix = unsafe { LibC.malloc<Float32>(count: Int64(16)) }
        projectionMatrix = unsafe { LibC.malloc<Float32>(count: Int64(16)) }
        modelMatrix = unsafe { LibC.malloc<Float32>(count: Int64(16)) }
    }

    private func setCamera(camera: ?Scene3DCameraSnapshot): Unit {
        let resolved = match (camera) {
            case Some(value) => value
            case None => Scene3DCameraSnapshot(6.8, 5.0, 8.0, 0.0, -0.5, 0.0)
        }
        let view = Array<Float32>(16, repeat: 0.0)
        mtxLookAt(
            view,
            Vec3(resolved.eyeX, resolved.eyeY, resolved.eyeZ),
            Vec3(resolved.targetX, resolved.targetY, resolved.targetZ),
            up: Vec3(resolved.upX, resolved.upY, resolved.upZ),
            handedness: Handedness.Left
        )
        let projection = Array<Float32>(16, repeat: 0.0)
        let aspect = Float32(pixelWidth) / Float32(pixelHeight)
        mtxProj(projection, resolved.fieldOfViewY, aspect, resolved.nearPlane, resolved.farPlane,
            true, handedness: Handedness.Left)
        unsafe {
            for (i in 0..16) {
                (viewMatrix + i).write(view[i])
                (projectionMatrix + i).write(projection[i])
            }
        }
        bgfx_set_view_transform_cj(0, CPointer<Unit>(viewMatrix), CPointer<Unit>(projectionMatrix))
    }

    private func setModel(projection: Scene3DDebugEntityProjection): Unit {
        let model = Array<Float32>(16, repeat: 0.0)
        mtxSRT(
            model,
            projection.scaleX, projection.scaleY, projection.scaleZ,
            projection.rotationX, projection.rotationY, projection.rotationZ,
            projection.x, projection.y, projection.z
        )
        unsafe {
            for (i in 0..16) { (modelMatrix + i).write(model[i]) }
        }
        bgfx_set_transform_cj(CPointer<Unit>(modelMatrix), UInt16(1))
    }

    private func vertexBufferFor(kind: Scene3DEntityKind): VertexBufferHandle {
        match (kind) {
            case Scene3DEntityKind.Floor => floorVertexBuffer
            case Scene3DEntityKind.Route => routeVertexBuffer
            case Scene3DEntityKind.Vehicle => vehicleVertexBuffer
            case Scene3DEntityKind.UserMarker => userMarkerVertexBuffer
            case Scene3DEntityKind.Structure => structureVertexBuffer
            case Scene3DEntityKind.Track => trackVertexBuffer
            case Scene3DEntityKind.Facility => facilityVertexBuffer
            case Scene3DEntityKind.ExitMarker => exitMarkerVertexBuffer
        }
    }

    private func destroyResources(): Unit {
        if (program.idx != UInt16(0xffff)) { bgfx_destroy_program_cj(program) }
        if (indexBuffer.idx != UInt16(0xffff)) { bgfx_destroy_index_buffer_cj(indexBuffer) }
        if (floorVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(floorVertexBuffer)
        }
        if (routeVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(routeVertexBuffer)
        }
        if (vehicleVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(vehicleVertexBuffer)
        }
        if (userMarkerVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(userMarkerVertexBuffer)
        }
        if (structureVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(structureVertexBuffer)
        }
        if (trackVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(trackVertexBuffer)
        }
        if (facilityVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(facilityVertexBuffer)
        }
        if (exitMarkerVertexBuffer.idx != UInt16(0xffff)) {
            bgfx_destroy_vertex_buffer_cj(exitMarkerVertexBuffer)
        }
        if (vertexLayout.idx != UInt16(0xffff)) { bgfx_destroy_vertex_layout_cj(vertexLayout) }
        program = ProgramHandle()
        indexBuffer = IndexBufferHandle()
        floorVertexBuffer = VertexBufferHandle()
        routeVertexBuffer = VertexBufferHandle()
        vehicleVertexBuffer = VertexBufferHandle()
        userMarkerVertexBuffer = VertexBufferHandle()
        structureVertexBuffer = VertexBufferHandle()
        trackVertexBuffer = VertexBufferHandle()
        facilityVertexBuffer = VertexBufferHandle()
        exitMarkerVertexBuffer = VertexBufferHandle()
        vertexLayout = VertexLayoutHandle()
    }

    private func freeMatrices(): Unit {
        unsafe {
            if (!viewMatrix.isNull()) { LibC.free(viewMatrix) }
            if (!projectionMatrix.isNull()) { LibC.free(projectionMatrix) }
            if (!modelMatrix.isNull()) { LibC.free(modelMatrix) }
        }
        viewMatrix = CPointer<Float32>()
        projectionMatrix = CPointer<Float32>()
        modelMatrix = CPointer<Float32>()
    }
}

public func createBgfxScene3DProvider(
    nativeWindow: CPointer<Unit>,
    nativeWindowIdentity: UInt64,
    clearColor!: UInt32 = 0x20242AFF
): DriverScene3DProvider {
    DriverScene3DProvider(Bgfx4cjDriver(nativeWindow, nativeWindowIdentity, clearColor: clearColor))
}
