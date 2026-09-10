package chui.scene3d

import chui.core.{SemanticActionKind, SemanticActionRequest, SemanticActionSource, SemanticRuntime, StateStore,
    Theme, UiContext, buildRoot, withActiveSemanticRuntime}
import sdl.{Rect, Renderer}

private class SemanticSceneFrameSource <: Scene3DViewFrameSource {
    public func snapshot(_: Scene3DFrameClock): Scene3DFrameSnapshot {
        Scene3DFrameSnapshot("semantic-scene")
    }
}

@Test
func semanticScene3DPublishesAndDispatchesOnlyRegisteredFocus(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let controller = Scene3DViewController(
        "stock.scene",
        FakeScene3DViewHost(),
        FakeScene3DProvider(),
        Scene3DResource("semantic", "memory://semantic", "sha256:semantic", 0),
        SemanticSceneFrameSource())
    let root = buildRoot({=> Scene3DView(controller, width: 240.0, height: 160.0)}, store)
    let focusRing = store.focusRing()
    let sceneId = focusRing[0]
    ctx.adoptFocusRing(focusRing)
    root.layout(ctx, Rect(0.0, 0.0, 240.0, 160.0))

    let runtime = SemanticRuntime("scene-window", handler: {request =>
        match (request.action) {
            case SemanticActionKind.Focus => ctx.focusRegistered(request.nodeId)
            case _ => false
        }
    })
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let tree = runtime.commitFrame()
    let node = tree.node(sceneId).getOrThrow()
    @Expect(node.actions.size, 1)

    @Expect(runtime.dispatch(SemanticActionRequest(
        "scene-window", tree.revision, sceneId, SemanticActionKind.Focus,
        SemanticActionSource.Accessibility)).ok)
    @Expect(ctx.hasFocus(sceneId))
    let activate = runtime.dispatch(SemanticActionRequest(
        "scene-window", tree.revision, sceneId, SemanticActionKind.Activate,
        SemanticActionSource.Accessibility))
    @Expect(!activate.ok)
    @Expect(activate.code, "action-not-supported")
}
