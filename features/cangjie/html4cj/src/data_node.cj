/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A data node, for contents of style, script tags etc, where contents should not show in text().
 */
public class DataNode <: LeafNode {
    /*
     * Create a new DataNode.
     *
     * @param data data contents
     */
    public init(data: String) {
        super(data)
    }

    public override func nodeName(): String {
        return "#data"
    }

    /*
     * Get the data contents of this node. Will be unescaped and with original new lines, space etc.
     *
     * @return data
     */
    public func getWholeData(): String {
        return coreValue()
    }

    /*
     * Set the data contents of this node.
     *
     * @param data unencoded data
     * @return this node, for chaining
     */
    public func setWholeData(data: String): DataNode {
        coreValue(data)
        return this
    }

    protected override func outerHtmlHead(accum: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {
        // data is not escaped in return from data nodes, so " in script, style is plain
        accum.append(getWholeData())
    }

    protected override func outerHtmlTail(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {}

    public func toString(): String {
        return outerHtml()
    }

    public override func clone(): DataNode {
        return (super.clone() as DataNode)()
    }
}
