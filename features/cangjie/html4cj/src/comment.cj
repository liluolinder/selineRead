/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A comment node.
 */
public class Comment <: LeafNode {
    /*
     * Create a new comment node.
     *
     * @param data The contents of the comment
     */
    public init(text: String) {
        super(text)
    }

    public override func nodeName(): String {
        return "#comment"
    }

    /*
     * Get the contents of the comment.
     *
     * @return comment content
     */
    public func getData(): String {
        return coreValue()
    }

    public func setData(data: String): Comment {
        coreValue(data)
        return this
    }

    protected override func outerHtmlHead(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit {
        if (out.prettyPrint()) {
            var doIndent: Bool = false
            if (siblingIndex() == 0) {
                if (parentNodeAll.instanceof<Element>()) {
                    if (parentNodeAll.instanceget<Element>().tag().formatAsBlock()) {
                        doIndent = true
                    }
                }
            }
            if (!doIndent) {
                if (out.outline()) {
                    doIndent = true
                }
            }
            if (doIndent) {
                indent(accum, depth, out)
            }
        }
        accum.append("<!--")
        accum.append(getData())
        accum.append("-->")
    }

    protected override func outerHtmlTail(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {
    }

    public func toString(): String {
        return outerHtml()
    }

    public override func clone(): Comment {
        return (super.clone() as Comment)()
    }

    /*
     * Check if this comment looks like an XML Declaration.
     *
     * @return true if it looks like, maybe, it's an XML Declaration.
     */
    public func isXmlDeclaration(): Bool {
        var data: String = getData()
        return isXmlDeclarationData(data)
    }

    private static func isXmlDeclarationData(data: String): Bool {
        return (data.size > 1 && (data.startsWith("!") || data.startsWith("?")))
    }

    /*
     * Attempt to cast this comment to an XML Declaration node.
     *
     * @return an XML declaration if it could be parsed as one, null otherwise.
     */
    public func asXmlDeclaration(): ?XmlDeclaration {
        var data: String = getData()
        var decl: ?XmlDeclaration = Option<XmlDeclaration>.None
        let runes = data.toRuneArray()
        var declContent: String = String(runes[1..runes.size - 1])

        // make sure this bogus comment is not immediately followed by another, treat as comment if so
        if (isXmlDeclarationData(declContent)) {
            return None
        }
        var fragment: String = "<" + declContent + ">"

        // use the HTML parser not XML, so we don't get into a recursive XML Declaration on contrived data
        var doc: Document = Parser.htmlParser().settings(ParseSettings.preserveCase).parseInput(fragment, baseUri())
        if (doc.body().children().elementArr.size > 0) {
            var el: Element = doc.body().child(0)
            decl = XmlDeclaration(NodeUtils.parser(doc).settings().normalizeTag(el.tagName()), data.startsWith("!"))
            decl().attributes().addAll(el.attributes())
        }
        return decl
    }
}
