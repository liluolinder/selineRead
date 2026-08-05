/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * An XML Declaration.
 */
public class XmlDeclaration <: LeafNode {
    protected var isProcessingInstruction: Bool

    /*
     * Create a new XML declaration
     *
     * @param name of declaration
     * @param isProcessingInstruction is processing instruction
     */
    public init(name: String, isProcessingInstruction: Bool) {
        super(name)
        this.isProcessingInstruction = isProcessingInstruction
    }

    public override func nodeName(): String {
        return "#declaration"
    }

    /*
     * Get the name of this declaration.
     *
     * @return name of this declaration.
     */
    public func name(): String {
        return coreValue()
    }

    /*
     * Get the unencoded XML declaration.
     *
     * @return XML declaration
     */
    public func getWholeDeclaration(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        getWholeDeclaration(sb, DocumentOutputSettings())
        return StringUtil.releaseBuilder(sb).strip()
    }

    private func getWholeDeclaration(accum: StringBuilder, out: DocumentOutputSettings): Unit {
        for (attribute in attributes()) {
            var key: String = attribute.getKey()
            var valStr: String = attribute.getValue()
            if (!key.equals(nodeName())) {
                // skips coreValue (name)
                accum.append(r' ')

                // basically like Attribute, but skip empty vals in XML
                accum.append(key)
                if (!valStr.isEmpty()) {
                    accum.append("=\"")
                    Entities.escape(accum, valStr, out, true, false, false, false)
                    accum.append(r'"')
                }
            }
        }
    }

    protected override func outerHtmlHead(accum: StringBuilder, _: Int64, out: DocumentOutputSettings): Unit {
        var str1: String
        if (isProcessingInstruction) {
            str1 = "!"
        } else {
            str1 = "?"
        }
        accum.append("<")
        accum.append(str1)
        accum.append(coreValue())
        getWholeDeclaration(accum, out)
        accum.append(str1)
        accum.append(">")
    }

    protected override func outerHtmlTail(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {}

    public func toString(): String {
        return outerHtml()
    }

    public override func clone(): XmlDeclaration {
        return (super.clone() as XmlDeclaration)()
    }
}
