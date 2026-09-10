package chui.scene3d

import chui.host.{HostPresentationMode, NativeSurfaceDescriptor, NativeSurfaceEvent, NativeSurfaceRenderer}

/** Deterministic embedded host used by providers, examples and lifecycle tests. */
public class FakeScene3DViewHost <: Scene3DViewHost {
    private var surface: ?NativeSurfaceDescriptor = None
    private var renderer: ?NativeSurfaceRenderer = None
    private var observer: (NativeSurfaceEvent) -> Unit = { _ => () }
    private var placement: ?Scene3DViewPlacement = None
    private var placements: Int64 = 0
    private var frameRequests: Int64 = 0

    public func presentationMode(): HostPresentationMode { HostPresentationMode.EmbeddedSurface }
    public func current(): ?NativeSurfaceDescriptor { surface }

    public func observe(handler: (NativeSurfaceEvent) -> Unit): Unit { observer = handler }

    public func bind(value: NativeSurfaceRenderer): Unit {
        renderer = Some(value)
        match (surface) {
            case Some(currentSurface) => value.attach(currentSurface)
            case None => ()
        }
    }

    public func requestFrame(): Unit { frameRequests += 1 }

    public func place(value: Scene3DViewPlacement): Scene3DViewHostReceipt {
        placement = Some(value)
        placements += 1
        Scene3DViewHostReceipt(true, "place", "accepted", value.viewId, "fake host placement accepted")
    }

    public func remove(viewId: String): Scene3DViewHostReceipt {
        match (placement) {
            case Some(currentPlacement) =>
                if (currentPlacement.viewId != viewId) {
                    return Scene3DViewHostReceipt(false, "remove", "unknown-view", viewId,
                        "fake host has no matching placement")
                }
                placement = None
                Scene3DViewHostReceipt(true, "remove", "accepted", viewId, "fake host placement removed")
            case None => Scene3DViewHostReceipt(true, "remove", "already-removed", viewId,
                "fake host placement was already absent")
        }
    }

    /** Publishes the same callback ordering a platform adapter must preserve. */
    public func publish(event: NativeSurfaceEvent): Unit {
        match (event) {
            case NativeSurfaceEvent.Available(value) =>
                surface = Some(value)
                match (renderer) {
                    case Some(bound) => bound.attach(value)
                    case None => ()
                }
            case NativeSurfaceEvent.Changed(value) =>
                surface = Some(value)
                match (renderer) {
                    case Some(bound) => bound.resize(value)
                    case None => ()
                }
            case NativeSurfaceEvent.Frame(value) =>
                match (renderer) {
                    case Some(bound) => bound.draw(value)
                    case None => ()
                }
            case NativeSurfaceEvent.Unavailable(id, generation) =>
                match (renderer) {
                    case Some(bound) => bound.detach(id, generation)
                    case None => ()
                }
                match (surface) {
                    case Some(value) =>
                        if (value.id == id && value.generation == generation) { surface = None }
                    case None => ()
                }
        }
        observer(event)
    }

    public func placementCount(): Int64 { placements }
    public func frameRequestCount(): Int64 { frameRequests }
    public func currentPlacement(): ?Scene3DViewPlacement { placement }
}
