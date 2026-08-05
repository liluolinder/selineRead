/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A Character Data node, to support CDATA sections.
 */
public class CDataNode <: TextNode {
    public init(text: String) {
        super(text)
    }

    public override func nodeName(): String {
        return "#cdata"
    }

    /*
     * Get the unencoded, non-normalized text content of this CDataNode.
     *
     * @return unencoded, non-normalized text
     */
    public override func text(): String {
        return getWholeText()
    }

    protected override func outerHtmlHead(accum: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {
        accum.append("<![CDATA[")
        accum.append(getWholeText())
    }

    protected override func outerHtmlTail(accum: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {
        accum.append("]]>")
    }

    public override func clone(): CDataNode {
        return (super.clone() as CDataNode)()
    }
}
