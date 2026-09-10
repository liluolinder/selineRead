package chui.controls

import chui.core.{SemanticActionKind, SemanticNode, SemanticRuntime, State, StateStore, Theme, UiContext,
    VStack, buildRoot, semanticActionName, withActiveSemanticRuntime}
import sdl.{Rect, Renderer}

@Test
func semanticStockCollectionsPublishOnlyRoutableAggregateActions(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let root = buildRoot({=>
        VStack {
            Pagination(8, State<Int64>(2), key: "stock.pagination")
            Breadcrumb(["Home", "Docs", "API"], onSelect: Some({ _ => () }),
                key: "stock.breadcrumb")
            StepIndicator(["One", "Two", "Three"], 1, onSelect: Some({ _ => () }),
                key: "stock.steps")
            ListView(["One", "Two"], State<Int64>(0), key: "stock.list")
            Table([TableColumn("Name", 120.0)], [["One"]], State<Int64>(0), key: "stock.table")
            TreeView([TreeNode("leaf", "Leaf")], State<String>("leaf"), key: "stock.tree")
        }
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 560.0, 720.0))

    let runtime = SemanticRuntime("stock-collections")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let tree = runtime.commitFrame()

    @Expect(tree.node("stock.pagination").getOrThrow().actions.isEmpty())
    @Expect(tree.node("stock.breadcrumb").getOrThrow().actions.isEmpty())
    @Expect(tree.node("stock.steps").getOrThrow().actions.isEmpty())
    expectFocusOnly(stockNode(tree.nodes, "ListView"))
    expectFocusOnly(stockNode(tree.nodes, "Table"))
    // A selected leaf cannot toggle, so TreeView must not advertise Activate for it.
    expectFocusOnly(stockNode(tree.nodes, "TreeView"))
}

private func stockNode(nodes: Array<SemanticNode>, widgetType: String): SemanticNode {
    for (node in nodes) {
        if (node.widgetType == widgetType) { return node }
    }
    throw IllegalStateException("missing semantic stock node ${widgetType}")
}

private func expectFocusOnly(node: SemanticNode): Unit {
    @Expect(node.actions.size, 1)
    @Expect(semanticActionName(node.actions[0]), semanticActionName(SemanticActionKind.Focus))
}
