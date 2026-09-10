package chui.scene3d

private class SharedFrameReleaseCounter {
    var calls: Int64 = 0
    var lastReason = "none"
    func release(reason: Scene3DSharedFrameFinishReason): Bool {
        calls += 1
        lastReason = scene3DSharedFrameFinishReasonName(reason)
        true
    }
}

private class ReentrantSharedFrameReleaseCounter {
    var lease: ?Scene3DSharedFrameLease = None
    var calls: Int64 = 0
    var receiptVisible = false
    var observedCode = "none"
    var reentrantCode = "none"
    var reentrantReason = "none"

    func release(_: Scene3DSharedFrameFinishReason): Bool {
        calls += 1
        let current = lease.getOrThrow()
        match (current.releaseReceipt()) {
            case Some(receipt) =>
                receiptVisible = true
                observedCode = receipt.code
            case None => ()
        }
        let reentrant = current.finish(Scene3DSharedFrameFinishReason.Presented)
        reentrantCode = reentrant.code
        reentrantReason = scene3DSharedFrameFinishReasonName(reentrant.reason)
        true
    }
}

@Test
func scene3dNamesAndProtocolStayStable(): Unit {
    @Expect(CANGHUI_SCENE3D_PROTOCOL, "canghui.scene3d.v0")
    @Expect(CANGHUI_SCENE3D_SHARED_FRAME_PROTOCOL, "canghui.scene3d.shared-frame.v1")
    @Expect(scene3dBackendName(Scene3DBackend.Metal), "metal")
    @Expect(scene3dBackendName(Scene3DBackend.D3D12), "d3d12")
    @Expect(scene3dEntityKindName(Scene3DEntityKind.UserMarker), "user-marker")
    @Expect(scene3dEntityKindName(Scene3DEntityKind.ExitMarker), "exit-marker")
    @Expect(scene3dDebugGeometryFamilyName(Scene3DDebugGeometryFamily.Ribbon), "ribbon")
    @Expect(scene3dSemanticColorName(Scene3DSemanticColor.RouteAccent), "route-accent")
}

@Test
func scene3DSharedFrameLeaseCopiesPixelsAndReleasesExactlyOnce(): Unit {
    let releases = SharedFrameReleaseCounter()
    let request = Scene3DSharedFrameRequest(
        "surface", 2, 7, 1.0, 1.0, 1.0, 1, "portrait")
    let lease = Scene3DSharedFrameLease(
        "frame-1", request, 1, 1, 4,
        Scene3DSharedColorSpace.Srgb,
        Scene3DSharedAlphaMode.Premultiplied,
        Scene3DSharedDynamicRange.Sdr,
        Scene3DSharedAcquireSync(7),
        29,
        rgbaPixels: [UInt8(1), UInt8(2), UInt8(3), UInt8(4)],
        onFinish: {reason => releases.release(reason) }
    )
    let copied = lease.copyRgbaPixels()
    @Expect(copied.size, Int64(4))
    @Expect(copied[2], UInt8(3))
    let receipt = lease.finish(Scene3DSharedFrameFinishReason.ExecutorFailed)
    let duplicate = lease.finish(Scene3DSharedFrameFinishReason.Presented)
    @Expect(releases.calls, Int64(1))
    @Expect(releases.lastReason, "executor-failed")
    @Expect(receipt.code, "released")
    @Expect(scene3DSharedFrameFinishReasonName(duplicate.reason), "executor-failed")
    @Expect(lease.isClosed())
    @ExpectThrows[IllegalStateException](lease.copyRgbaPixels())
}

@Test
func scene3DSharedFrameLeasePublishesReceiptBeforeReentrantProviderCallback(): Unit {
    let releases = ReentrantSharedFrameReleaseCounter()
    let request = Scene3DSharedFrameRequest(
        "surface", 4, 12, 1.0, 1.0, 1.0, 9, "portrait")
    let lease = Scene3DSharedFrameLease(
        "frame-reentrant", request, 1, 1, 4,
        Scene3DSharedColorSpace.Srgb,
        Scene3DSharedAlphaMode.Opaque,
        Scene3DSharedDynamicRange.Sdr,
        Scene3DSharedAcquireSync(12),
        41,
        rgbaPixels: [UInt8(9), UInt8(8), UInt8(7), UInt8(255)],
        onFinish: {reason => releases.release(reason) })
    releases.lease = Some(lease)

    let terminal = lease.finish(Scene3DSharedFrameFinishReason.ExecutorFailed)

    @Expect(releases.calls, Int64(1))
    @Expect(releases.receiptVisible)
    @Expect(releases.observedCode, "release-in-progress")
    @Expect(releases.reentrantCode, "release-in-progress")
    @Expect(releases.reentrantReason, "executor-failed")
    @Expect(terminal.ok)
    @Expect(terminal.code, "released")
    @Expect(scene3DSharedFrameFinishReasonName(terminal.reason), "executor-failed")
    @Expect(lease.releaseReceipt().getOrThrow().code, "released")
    @Expect(lease.finish(Scene3DSharedFrameFinishReason.Presented).code, "released")
    @Expect(releases.calls, Int64(1))
}

@Test
func fakeScene3DSharedFrameRequiresPresentedCurrentFrame(): Unit {
    let provider = FakeScene3DProvider()
    let surface = Scene3DHostSurface(
        "shared", Scene3DBackend.Software, UInt64(1), 32.0, 16.0, 32, 16, 1.0, 1)
    @Expect(provider.attach(surface, Scene3DFrameClock(0, 0, 0)).ok)
    @Expect(provider.loadScene(Scene3DResource("scene", "memory://scene", "sha256:test", 0)).ok)
    let request = Scene3DSharedFrameRequest(
        "shared", 1, 1, 32.0, 16.0, 1.0, 1, "portrait")
    @Expect(provider.acquireSharedFrame(request).isNone())
    let snapshot = Scene3DFrameSnapshot("shared-scene")
    @Expect(provider.submit(snapshot, Scene3DFrameClock(1, 1, 2)).ok)
    @Expect(provider.present(Scene3DFrameClock(1, 1, 2)).ok)
    let lease = provider.acquireSharedFrame(request).getOrThrow()
    @Expect(lease.pixelWidth, Int64(32))
    @Expect(lease.pixelHeight, Int64(16))
    @Expect(provider.sharedAcquireCount(), Int64(1))
    lease.close()
    @Expect(provider.sharedReleaseCount(), Int64(1))
}

@Test
func scene3DSharedFrameRejectsOverflowAndKeepsPrivatePayloadOpaque(): Unit {
    let request = Scene3DSharedFrameRequest(
        "surface", 1, 0, 8.0, 8.0, 1.0, 1, "portrait")
    @ExpectThrows[IllegalArgumentException](Scene3DSharedFrameLease(
        "overflow", request, Int64.Max, 1, Int64.Max,
        Scene3DSharedColorSpace.Srgb,
        Scene3DSharedAlphaMode.Opaque,
        Scene3DSharedDynamicRange.Sdr,
        Scene3DSharedAcquireSync(0),
        1))
    let privateFrame = Scene3DSharedFrameLease(
        "native", request, 8, 8, 32,
        Scene3DSharedColorSpace.Srgb,
        Scene3DSharedAlphaMode.Opaque,
        Scene3DSharedDynamicRange.Sdr,
        Scene3DSharedAcquireSync(3, waitRequired: true),
        7,
        payloadKind: Scene3DSharedFramePayloadKind.ProviderPrivateTexture,
        providerPrivateToken: "provider-token")
    @ExpectThrows[IllegalStateException](privateFrame.copyRgbaPixels())
    @Expect(privateFrame.finish(Scene3DSharedFrameFinishReason.Fallback).ok)
}

@Test
func scene3dDebugProjectionMapsAllGenericEntityKinds(): Unit {
    let floor = projectScene3DEntity(Scene3DEntitySnapshot(
        "floor", 0.0, -1.0, 0.0, kind: Scene3DEntityKind.Floor
    ))
    let route = projectScene3DEntity(Scene3DEntitySnapshot(
        "route", 0.0, -0.8, 0.2, kind: Scene3DEntityKind.Route
    ))
    let vehicle = projectScene3DEntity(Scene3DEntitySnapshot(
        "vehicle", -0.8, -0.3, 0.0, kind: Scene3DEntityKind.Vehicle
    ))
    let user = projectScene3DEntity(Scene3DEntitySnapshot(
        "user", 1.0, -0.2, 0.0, visible: false, kind: Scene3DEntityKind.UserMarker
    ))
    let structure = projectScene3DEntity(Scene3DEntitySnapshot(
        "structure", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Structure,
        scaleX: 1.4, scaleY: 0.3, scaleZ: 0.5, rotationY: 0.25
    ))
    let track = projectScene3DEntity(Scene3DEntitySnapshot(
        "track", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Track
    ))
    let facility = projectScene3DEntity(Scene3DEntitySnapshot(
        "facility", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.Facility
    ))
    let exit = projectScene3DEntity(Scene3DEntitySnapshot(
        "exit", 0.0, 0.0, 0.0, kind: Scene3DEntityKind.ExitMarker
    ))

    @Expect(floor.geometryFamily == Scene3DDebugGeometryFamily.Slab)
    @Expect(floor.semanticColor == Scene3DSemanticColor.GroundNeutral)
    @Expect(floor.scaleX == 3.8)
    @Expect(route.geometryFamily == Scene3DDebugGeometryFamily.Ribbon)
    @Expect(route.semanticColor == Scene3DSemanticColor.RouteAccent)
    @Expect(route.green == 0.63)
    @Expect(vehicle.geometryFamily == Scene3DDebugGeometryFamily.Box)
    @Expect(vehicle.entityId, "vehicle")
    @Expect(vehicle.x == -0.8)
    @Expect(user.geometryFamily == Scene3DDebugGeometryFamily.Marker)
    @Expect(user.semanticColor == Scene3DSemanticColor.UserHighlight)
    @Expect(!user.visible)
    @Expect(structure.semanticColor == Scene3DSemanticColor.StructureNeutral)
    @Expect(structure.scaleX == 1.4)
    @Expect(structure.scaleY == 0.3)
    @Expect(structure.rotationY == 0.25)
    @Expect(track.semanticColor == Scene3DSemanticColor.TrackNeutral)
    @Expect(facility.semanticColor == Scene3DSemanticColor.FacilityAccent)
    @Expect(exit.semanticColor == Scene3DSemanticColor.ExitAccent)
}

@Test
func scene3dEntitySnapshotKeepsLegacyDefaultKind(): Unit {
    let entity = Scene3DEntitySnapshot("legacy", 1.0, 2.0, 3.0)
    @Expect(entity.kind == Scene3DEntityKind.Vehicle)
    @Expect(entity.visible)
    @Expect(entity.scaleX == 0.0)
    @Expect(entity.rotationY == 0.0)
}

@Test
func scene3dFrameCarriesValidatedOptionalCamera(): Unit {
    let camera = Scene3DCameraSnapshot(7.0, 5.0, 9.0, 0.0, -0.5, 0.0,
        fieldOfViewY: 48.0, nearPlane: 0.2, farPlane: 80.0)
    let frame = Scene3DFrameSnapshot("camera", camera: Some(camera))
    match (frame.camera) {
        case Some(value) =>
            @Expect(value.eyeX == 7.0)
            @Expect(value.fieldOfViewY == 48.0)
            @Expect(value.farPlane == 80.0)
        case None => @Fail("camera should be present")
    }
    @ExpectThrows[IllegalArgumentException](
        Scene3DCameraSnapshot(1.0, 1.0, 1.0, 0.0, 0.0, 0.0, nearPlane: 2.0, farPlane: 1.0)
    )
}

@Test
func fakeScene3dRunsValidatedLifecycle(): Unit {
    let provider = FakeScene3DProvider()
    let surface = Scene3DHostSurface(
        "station",
        Scene3DBackend.Metal,
        UInt64(7),
        640.0,
        480.0,
        1280,
        960,
        2.0,
        1
    )
    let clock = Scene3DFrameClock(1, 100, 200)
    let resource = Scene3DResource("station-pack", "station.pack", "sha256:fixture", 128)
    let snapshot = Scene3DFrameSnapshot("station-demo")
    snapshot.add(Scene3DEntitySnapshot("platform", 0.0, 0.0, 0.0))

    @Expect(provider.attach(surface, clock).ok)
    @Expect(provider.loadScene(resource).ok)
    @Expect(provider.submit(snapshot, Scene3DFrameClock(2, 200, 300)).ok)
    @Expect(provider.present(Scene3DFrameClock(2, 200, 300)).ok)
    @Expect(provider.currentSceneId(), "station-demo")
    @Expect(snapshot.isSealed())
    @Expect(snapshot.entityCount(), 1)
    @Expect(snapshot.entityAt(0).id, "platform")
    @Expect(provider.detach("station", 1).ok)
    @Expect(!provider.isAttached())
}

@Test
func fakeScene3dRejectsStaleSurfaceAndRegressedFrame(): Unit {
    let provider = FakeScene3DProvider()
    let surface = Scene3DHostSurface(
        "station",
        Scene3DBackend.Vulkan,
        UInt64(8),
        320.0,
        240.0,
        640,
        480,
        2.0,
        2
    )
    @Expect(provider.attach(surface, Scene3DFrameClock(4, 400, 500)).ok)
    @Expect(provider.resize(Scene3DHostSurface(
        "station", Scene3DBackend.Vulkan, UInt64(8), 320.0, 240.0, 640, 480, 2.0, 1
    )).code, "stale-generation")

    let resource = Scene3DResource("station-pack", "station.pack", "sha256:fixture", 128)
    let snapshot = Scene3DFrameSnapshot("station-demo")
    snapshot.add(Scene3DEntitySnapshot("gate", 1.0, 0.0, 0.0))
    @Expect(provider.loadScene(resource).ok)
    @Expect(provider.submit(snapshot, Scene3DFrameClock(3, 300, 350)).code, "frame-regressed")
}

@Test
func fakeScene3dReattachDropsPreviousSceneState(): Unit {
    let provider = FakeScene3DProvider()
    let first = Scene3DHostSurface(
        "station", Scene3DBackend.Metal, UInt64(8), 320.0, 240.0, 640, 480, 2.0, 1
    )
    @Expect(provider.attach(first, Scene3DFrameClock(1, 100, 200)).ok)
    @Expect(provider.loadScene(Scene3DResource("pack", "station.pack", "sha256:first", 1)).ok)

    let replacement = Scene3DHostSurface(
        "station", Scene3DBackend.Metal, UInt64(9), 320.0, 240.0, 640, 480, 2.0, 2
    )
    @Expect(provider.attach(replacement, Scene3DFrameClock(2, 200, 300)).ok)
    @Expect(provider.currentSceneId(), "")
    @Expect(provider.submit(Scene3DFrameSnapshot("stale-scene"), Scene3DFrameClock(3, 300, 400)).code,
        "scene-not-loaded")
}

@Test
func scene3dContractsRejectInvalidIdentity(): Unit {
    var surfaceRejected = false
    try {
        let _ = Scene3DHostSurface(
            "", Scene3DBackend.Software, UInt64(0), 1.0, 1.0, 1, 1, 1.0, 0
        )
    } catch (_: IllegalArgumentException) {
        surfaceRejected = true
    }
    @Expect(surfaceRejected)

    var resourceRejected = false
    try {
        let _ = Scene3DResource("pack", "pack", "", 1)
    } catch (_: IllegalArgumentException) {
        resourceRejected = true
    }
    @Expect(resourceRejected)
}
