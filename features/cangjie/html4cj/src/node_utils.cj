/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Internal helpers for Nodes, to keep the actual node APIs relatively clean. A jsoup internal class, so don't use it as there is no contract API).
 */
class NodeUtils {
    /*
     * Get the output setting for this node,  or if this node has no document (or parent), retrieve the default output settings
     *
     * @return DocumentOutputSettings
     */
    static func outputSettings(node: Node): DocumentOutputSettings {
        var owner: ?Document = node.ownerDocument()
        if (owner != None) {
            return owner().outputSettings()
        } else {
            return Document("").outputSettings()
        }
    }

    /*
     * Get the parser that was used to make this node, or the default HTML parser if it has no parent.
     *
     * @return Parser
     */
    static func parser(node: Node): Parser {
        var doc: ?Document = node.ownerDocument()
        return if (doc != None) {
            doc().parser()
        } else {
            Parser(HtmlTreeBuilder())
        }
    }
}
