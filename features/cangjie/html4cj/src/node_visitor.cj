/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Node visitor interface. Provide an implementing class to NodeTraversor to iterate through nodes.
 */
public interface NodeVisitor {
    /*
     * Callback for when a node is first visited.
     *
     * @param node the node being visited.
     * @param depth the depth of the node, relative to the root node.
     */
    func head(node: Node, depth: Int64): Unit

    /*
     * Callback for when a node is last visited, after all of its descendants have been visited.
     *
     * @param node the node being visited.
     * @param depth the depth of the node, relative to the root node.
     */
    func tail(_: Node, _: Int64): Unit {
        // no-op by default, to allow just specifying the head() method
    }
}
