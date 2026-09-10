package chui.scene3d

/** Result returned by one native driver operation before CangHui shapes a receipt. */
public struct Scene3DDriverResult {
    public let ok: Bool
    public let code: String
    public let detail: String

    public init(ok: Bool, code: String, detail: String) {
        this.ok = ok
        this.code = code
        this.detail = detail
    }

    public static func accepted(detail!: String = "accepted"): Scene3DDriverResult {
        Scene3DDriverResult(true, "accepted", detail)
    }

    public static func rejected(code: String, detail: String): Scene3DDriverResult {
        Scene3DDriverResult(false, code, detail)
    }
}

/**
 * Low-level renderer driver. Platform packages implement this interface and
 * keep native pointers, engine handles and FFI buffers outside product code.
 */
public interface Scene3DDriver {
    func driverName(): String
    func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DDriverResult
    func resize(surface: Scene3DHostSurface): Scene3DDriverResult
    func loadScene(resource: Scene3DResource): Scene3DDriverResult
    func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DDriverResult
    func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult
    func present(clock: Scene3DFrameClock): Scene3DDriverResult
    func detach(surfaceId: String, generation: Int64): Scene3DDriverResult
}

/**
 * Lifecycle gate shared by native engines. Driver calls only happen after
 * surface generation, frame ordering and scene readiness checks pass.
 */
public class DriverScene3DProvider <: Scene3DProvider {
    private let driver: Scene3DDriver
    private var attached = false
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var lastFrameId: Int64 = -1
    private var sceneLoaded = false
    private var lastSceneId = ""

    public init(driver: Scene3DDriver) {
        if (driver.driverName().isEmpty()) {
            throw IllegalArgumentException("scene3d driver name must be present")
        }
        this.driver = driver
    }

    public func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DReceipt {
        if (attached && (surface.id != surfaceId || surface.generation <= generation)) {
            return reject("attach", "stale-generation", surface.generation, clock.frameId)
        }
        let result = driver.attach(surface, clock)
        if (result.ok) {
            attached = true
            surfaceId = surface.id
            generation = surface.generation
            lastFrameId = clock.frameId
            sceneLoaded = false
            lastSceneId = ""
        }
        receipt("attach", result, surface.generation, clock.frameId)
    }

    public func resize(surface: Scene3DHostSurface): Scene3DReceipt {
        if (!matches(surface.id, surface.generation)) {
            return reject("resize", "stale-generation", surface.generation, lastFrameId)
        }
        receipt("resize", driver.resize(surface), generation, lastFrameId)
    }

    public func loadScene(resource: Scene3DResource): Scene3DReceipt {
        if (!attached) { return reject("load-scene", "not-attached", generation, lastFrameId) }
        let result = driver.loadScene(resource)
        if (result.ok) { sceneLoaded = true }
        receipt("load-scene", result, generation, lastFrameId)
    }

    public func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DReceipt {
        if (!attached) { return reject("submit", "not-attached", generation, clock.frameId) }
        if (!sceneLoaded) { return reject("submit", "scene-not-loaded", generation, clock.frameId) }
        if (clock.frameId < lastFrameId) {
            return reject("submit", "frame-regressed", generation, clock.frameId)
        }
        snapshot.seal()
        let result = driver.submit(snapshot, clock)
        if (result.ok) {
            lastFrameId = clock.frameId
            lastSceneId = snapshot.sceneId
        }
        receipt("submit", result, generation, clock.frameId)
    }

    public func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult {
        if (!matches(surfaceId, request.generation) || request.frameId != lastFrameId) {
            return Scene3DHitTestResult.none(request.generation, request.frameId)
        }
        driver.hitTest(request)
    }

    public func present(clock: Scene3DFrameClock): Scene3DReceipt {
        if (!attached) { return reject("present", "not-attached", generation, clock.frameId) }
        if (clock.frameId < lastFrameId) {
            return reject("present", "frame-regressed", generation, clock.frameId)
        }
        let result = driver.present(clock)
        if (result.ok) { lastFrameId = clock.frameId }
        receipt("present", result, generation, clock.frameId)
    }

    public func detach(surfaceId: String, generation: Int64): Scene3DReceipt {
        if (!matches(surfaceId, generation)) {
            return reject("detach", "stale-generation", generation, lastFrameId)
        }
        let result = driver.detach(surfaceId, generation)
        if (result.ok) {
            attached = false
            this.surfaceId = ""
            this.generation = 0
            sceneLoaded = false
            lastSceneId = ""
        }
        receipt("detach", result, generation, lastFrameId)
    }

    public func driverName(): String { driver.driverName() }
    public func isAttached(): Bool { attached }
    public func currentGeneration(): Int64 { generation }
    public func currentSceneId(): String { lastSceneId }

    private func matches(id: String, value: Int64): Bool {
        attached && id == surfaceId && value == generation
    }

    private func receipt(
        operation: String,
        result: Scene3DDriverResult,
        generation: Int64,
        frameId: Int64
    ): Scene3DReceipt {
        Scene3DReceipt(result.ok, operation, result.code, generation, frameId, result.detail)
    }

    private func reject(operation: String, code: String, generation: Int64, frameId: Int64): Scene3DReceipt {
        Scene3DReceipt(false, operation, code, generation, frameId, "request rejected before driver call")
    }
}
