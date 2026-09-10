package chui.scene3d

private class RecordingScene3DDriver <: Scene3DDriver {
    var calls = ""
    var failPresent = false
    var observedSurfaceId = ""
    var observedResourceId = ""
    var observedSceneId = ""
    var observedFrameId: Int64 = -1
    var observedGeneration: Int64 = 0
    var observedProjectionSummary = ""

    public func driverName(): String { "recording" }

    public func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DDriverResult {
        calls += "attach|"
        observedSurfaceId = surface.id
        observedGeneration = surface.generation
        observedFrameId = clock.frameId
        Scene3DDriverResult.accepted()
    }

    public func resize(surface: Scene3DHostSurface): Scene3DDriverResult {
        calls += "resize|"
        observedGeneration = surface.generation
        Scene3DDriverResult.accepted()
    }

    public func loadScene(resource: Scene3DResource): Scene3DDriverResult {
        calls += "load|"
        observedResourceId = resource.id
        Scene3DDriverResult.accepted()
    }

    public func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DDriverResult {
        calls += "submit|"
        observedSceneId = snapshot.sceneId
        observedFrameId = clock.frameId
        observedProjectionSummary = ""
        for (i in 0..snapshot.entityCount()) {
            let projection = projectScene3DEntity(snapshot.entityAt(i))
            if (!observedProjectionSummary.isEmpty()) { observedProjectionSummary += "|" }
            observedProjectionSummary += projection.entityId + ":" +
                scene3dEntityKindName(projection.kind) + ":" +
                scene3dDebugGeometryFamilyName(projection.geometryFamily) + ":" +
                scene3dSemanticColorName(projection.semanticColor) + ":" +
                "${projection.visible}"
        }
        Scene3DDriverResult.accepted()
    }

    public func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult {
        calls += "hit|"
        Scene3DHitTestResult(true, "platform", request.generation, request.frameId)
    }

    public func present(clock: Scene3DFrameClock): Scene3DDriverResult {
        calls += "present|"
        observedFrameId = clock.frameId
        if (failPresent) {
            Scene3DDriverResult.rejected("native-present-failed", "injected failure")
        } else {
            Scene3DDriverResult.accepted()
        }
    }

    public func detach(surfaceId: String, generation: Int64): Scene3DDriverResult {
        calls += "detach|"
        observedSurfaceId = surfaceId
        observedGeneration = generation
        Scene3DDriverResult.accepted()
    }
}

@Test
func driverProviderPreservesGenericSemanticEntityProjection(): Unit {
    let driver = RecordingScene3DDriver()
    let provider = DriverScene3DProvider(driver)
    let snapshot = Scene3DFrameSnapshot("semantic-debug-scene")
    snapshot.add(Scene3DEntitySnapshot(
        "floor-1", 0.0, -1.0, 0.0, kind: Scene3DEntityKind.Floor
    ))
    snapshot.add(Scene3DEntitySnapshot(
        "route-1", 0.0, -0.8, 0.0, kind: Scene3DEntityKind.Route
    ))
    snapshot.add(Scene3DEntitySnapshot(
        "vehicle-1", -0.8, -0.3, 0.0, kind: Scene3DEntityKind.Vehicle
    ))
    snapshot.add(Scene3DEntitySnapshot(
        "user-1", 1.0, -0.2, 0.0, visible: false, kind: Scene3DEntityKind.UserMarker
    ))

    @Expect(provider.attach(driverSurface(), Scene3DFrameClock(1, 10, 20)).ok)
    @Expect(provider.loadScene(Scene3DResource("pack", "pack", "sha256:test", 1)).ok)
    @Expect(provider.submit(snapshot, Scene3DFrameClock(2, 20, 30)).ok)
    @Expect(driver.observedProjectionSummary,
        "floor-1:floor:slab:ground-neutral:true|" +
        "route-1:route:ribbon:route-accent:true|" +
        "vehicle-1:vehicle:box:vehicle-accent:true|" +
        "user-1:user-marker:marker:user-highlight:false")
}

private func driverSurface(generation!: Int64 = 1): Scene3DHostSurface {
    Scene3DHostSurface(
        "station", Scene3DBackend.Metal, UInt64(9), 400.0, 300.0, 800, 600, 2.0, generation
    )
}

@Test
func driverProviderGatesLifecycleBeforeCallingNativeDriver(): Unit {
    let driver = RecordingScene3DDriver()
    let provider = DriverScene3DProvider(driver)
    let snapshot = Scene3DFrameSnapshot("station")
    snapshot.add(Scene3DEntitySnapshot("platform", 0.0, 0.0, 0.0))

    @Expect(provider.submit(snapshot, Scene3DFrameClock(0, 0, 0)).code, "not-attached")
    @Expect(driver.calls, "")
    @Expect(provider.attach(driverSurface(), Scene3DFrameClock(1, 10, 20)).ok)
    @Expect(provider.loadScene(Scene3DResource("pack", "pack", "sha256:test", 1)).ok)
    @Expect(provider.submit(snapshot, Scene3DFrameClock(2, 20, 30)).ok)
    @Expect(provider.hitTest(Scene3DHitTestRequest(1.0, 1.0, 1, 2)).entityId, "platform")
    @Expect(!provider.hitTest(Scene3DHitTestRequest(1.0, 1.0, 1, 3)).hit)
    @Expect(driver.calls, "attach|load|submit|hit|")
    @Expect(provider.present(Scene3DFrameClock(2, 20, 30)).ok)
    @Expect(provider.detach("station", 1).ok)
    @Expect(driver.calls, "attach|load|submit|hit|present|detach|")
    @Expect(driver.observedSurfaceId, "station")
    @Expect(driver.observedResourceId, "pack")
    @Expect(driver.observedSceneId, "station")
    @Expect(driver.observedFrameId, 2)
    @Expect(driver.observedGeneration, 1)
}

@Test
func driverProviderDoesNotCommitFailedNativeTransitions(): Unit {
    let driver = RecordingScene3DDriver()
    let provider = DriverScene3DProvider(driver)
    @Expect(provider.attach(driverSurface(), Scene3DFrameClock(3, 30, 40)).ok)
    driver.failPresent = true
    @Expect(provider.present(Scene3DFrameClock(4, 40, 50)).code, "native-present-failed")
    @Expect(provider.currentGeneration(), 1)
    @Expect(provider.resize(driverSurface(generation: 2)).code, "stale-generation")
    @Expect(!driver.calls.contains("resize|"))
}
