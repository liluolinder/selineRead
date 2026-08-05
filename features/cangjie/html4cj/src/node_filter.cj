/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Node filter interface. Provide an implementing class to NodeTraversor to iterate through nodes.
 */
public interface NodeFilter {
    /*
     * Callback for when a node is first visited.
     *
     * @param node the node being visited.
     * @param depth the depth of the node, relative to the root node.
     * @return Filter decision
     */
    func head(node: Node, depth: Int64): FilterResult

    /*
     * Callback for when a node is last visited, after all of its descendants have been visited.
     *
     * @param node the node being visited.
     * @param depth the depth of the node, relative to the root node.
     * @return Filter decision
     */
    func tail(_: Node, _: Int64): FilterResult {
        return FilterResult.CONTINUE
    }
}

/*
 * Filter decision.
 */
public enum FilterResult <: Equatable<FilterResult> & ToString {
    // Continue processing the tree
    | CONTINUE
    // Skip the child nodes, but do call NodeFilter.tail(Node, Int64)} next.
    | SKIP_CHILDREN
    // Skip the subtree, and do not call NodeFilter.tail(Node, Int64).
    | SKIP_ENTIRELY
    // Remove the node and its children 
    | REMOVE
    // Stop processing
    | STOP

    public func toString(): String {
        match (this) {
            case CONTINUE => "CONTINUE"
            case SKIP_CHILDREN => "SKIP_CHILDREN"
            case SKIP_ENTIRELY => "SKIP_ENTIRELY"
            case REMOVE => "REMOVE"
            case STOP => "STOP"
        }
    }

    public operator func ==(r: FilterResult): Bool {
        this.toString() == r.toString()
    }

    public operator func !=(r: FilterResult): Bool {
        !(this == r)
    }
}
