/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Depth-first node traversor. Use to iterate through all nodes under and including the specified root node.
 */
class NodeTraversor {
    /*
     * Start a depth-first traverse of the root and all of its descendants.
     *
     * @param visitor Node visitor.
     * @param root the root node point to traverse.
     */
    public static func traverse(visitor: NodeVisitor, root: Node): Unit {
        var node: ?Node = root
        var depth: Int64 = 0

        while (node != None) {
            // let tmp = node().nodeName()
            // remember parent to find nodes that get replaced in .head
            var parent: ?Node = node().parentNode()
            var origSize: Int64 = if (parent != None) {
                parent().childNodeSize()
            } else {
                0
            }
            var next: ?Node = node().nextSibling()

            visitor.head(node(), depth) // visit current node
            if (parent != None && !node().hasParent()) {
                // removed or replaced
                if (origSize == parent().childNodeSize()) {
                    // replace ditches parent but keeps sibling index
                    node = parent().childNode(node().siblingIndex())
                } else {
                    // removed
                    node = next
                    if (node == None) {
                        // last one, go up
                        node = parent
                        depth--
                    }
                    continue
                }
            }
            if (node().childNodeSize() > 0) {
                // descend
                node = node().childNode(0)
                depth++
            } else {
                while (true) {
                    if (!(node().nextSibling() == None && depth > 0)) {
                        break
                    }
                    visitor.tail(node(), depth) // when no more siblings, ascend
                    node = node().parentNode()
                    depth--
                }
                visitor.tail(node(), depth)
                if (node == root) {
                    break
                }
                node = node().nextSibling()
            }
        }
    }

    /*
     * Start a depth-first traverse of all elements.
     *
     * @param visitor Node visitor.
     * @param elements Elements to filter.
     */
    public static func traverse(visitor: NodeVisitor, elements: Elements): Unit {
        for (el in elements.elementArr) {
            traverse(visitor, el)
        }
    }

    /*
     * Start a depth-first filtering of the root and all of its descendants.
     *
     * @param filter Node visitor.
     * @param root the root node point to traverse.
     * @return The filter result of the root node
     */
    public static func filter(filter: NodeFilter, root: Node): FilterResult {
        var node: ?Node = root
        var depth = 0

        while (node != None) {
            var result: FilterResult = filter.head(node(), depth)
            if (result == FilterResult.STOP) {
                return result
            }

            // Descend into child nodes:
            if (result == FilterResult.CONTINUE && node().childNodeSize() > 0) {
                node = node().childNode(0)
                depth++
                continue
            }

            // No siblings, move upwards:
            while (true) {
                // assert node != None // depth > 0, so has parent
                if (!(node().nextSibling() == None && depth > 0)) {
                    break
                }

                // 'tail' current node:
                if (result == FilterResult.CONTINUE || result == FilterResult.SKIP_CHILDREN) {
                    result = filter.tail(node(), depth)
                    if (result == FilterResult.STOP) {
                        return result
                    }
                }
                let prev: ?Node = node // In case we need to remove it below.
                node = node().parentNode()
                depth--
                if (result == FilterResult.REMOVE) {
                    prev?.remove() // Remove AFTER finding parent.
                }
                result = FilterResult.CONTINUE // Parent was not pruned.
            }

            // 'tail' current node, then proceed with siblings:
            if (result == FilterResult.CONTINUE || result == FilterResult.SKIP_CHILDREN) {
                result = filter.tail(node(), depth)
                if (result == FilterResult.STOP) {
                    return result
                }
            }
            if (node == root) {
                return result
            }
            let prev: ?Node = node // In case we need to remove it below.
            node = node().nextSibling()
            if (result == FilterResult.REMOVE) {
                prev?.remove() // Remove AFTER finding sibling.
            }
        }

        // root == null?
        return FilterResult.CONTINUE
    }

    /*
     * Start a depth-first filtering of all elements.
     *
     * @param filter Node filter.
     * @param elements Elements to filter.
     */
    public static func filter(nodeFilter: NodeFilter, elements: Elements): Unit {
        for (el in elements.elementArr) {
            if (filter(nodeFilter, el) == FilterResult.STOP) {
                break
            }
        }
    }
}
