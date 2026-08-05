/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A text node.
 */
public open class TextNode <: LeafNode {
    /*
     * Create a new TextNode representing the supplied (unencoded) text).
     *
     * @param text raw text
     */
    public init(text: String) {
        super(text)
    }

    public open func nodeName(): String {
        return "#text"
    }

    /*
     * Get the text content of this text node.
     *
     * @return Unencoded, normalised text.
     */
    public open func text(): String {
        return StringUtil.normaliseWhitespace(getWholeText())
    }

    /*
     * Set the text content of this text node.
     *
     * @param text unencoded text
     * @return this, for chaining
     */
    public func text(text: String): TextNode {
        coreValue(text)
        return this
    }

    /*
     * Get the (unencoded) text of this text node, including any newlines and spaces present in the original.
     *
     * @return text
     */
    public func getWholeText(): String {
        return coreValue()
    }

    /*
     * Test if this text node is blank -- that is, empty or only whitespace (including newlines).
     *
     * @return true if this document is empty or only whitespace, false if it contains any text content.
     */
    public func isBlank(): Bool {
        return StringUtil.isBlank(coreValue())
    }

    /*
     * Split this text node into two nodes at the specified string offset. After splitting, this node will contain the
     * original text up to the offset, and will have a new text node sibling containing the text after the offset.
     *
     * @param offset string offset point to split node at.
     * @return the newly created text node containing the text after the offset.
     */
    public func splitText(offset: Int64): TextNode {
        var textStr: String = coreValue()
        Validate.isTrue(offset >= 0, "Split offset must be not be negative")
        Validate.isTrue(offset < textStr.size, "Split offset must not be greater than current text length")
        var head: String = textStr[..offset]
        var tail: String = textStr[offset..]
        text(head)
        var tailNode: TextNode = TextNode(tail)
        if (parentNodeAll != None) {
            parentNodeAll().addChildren(siblingIndex() + 1, tailNode)
        }
        return tailNode
    }

    protected open override func outerHtmlHead(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit {
        var prettyPrint: Bool = out.prettyPrint()
        var parentElement: ?Element = match (parentNodeAll) {
            case Some(v: Element) => v
            case _ => None
        }
        var normaliseWhite: Bool = prettyPrint && !Element.preserveWhitespace(parentNodeAll)
        var trimLikeBlock: Bool = parentElement != None && (parentElement().tag().isBlock() ||
            parentElement().tag().formatAsBlock())
        var isNextSib: Bool = nextSibling() == None
        var trimLeading: Bool = false
        var trimTrailing: Bool = false
        if (normaliseWhite) {
            trimLeading = (trimLikeBlock && siblingIndexInt == 0) || parentNodeAll.instanceof<Document>()
            trimTrailing = trimLikeBlock && isNextSib

            // if this text is just whitespace, and the next node will cause an indent, skip this text
            var next: ?Node = nextSibling()
            var prev: ?Node = previousSibling()
            var isBlank: Bool = isBlank()
            var isElement = outerHtmlHeadIf1(next, prev, out)[0]
            var isTextNode = outerHtmlHeadIf1(next, prev, out)[1]
            var isBlockElement = outerHtmlHeadIf1(next, prev, out)[2]
            var couldSkip: Bool = isElement || isTextNode || isBlockElement
            if (couldSkip && isBlank) {
                return
            }
            var doIndent: Bool = false
            if (siblingIndexInt == 0 && parentElement != None && parentElement().tag().formatAsBlock() && !isBlank) {
                doIndent = true
            }
            if (!doIndent) {
                if (out.outline()) {
                    if (siblingNodes().size > 0 && !isBlank) {
                        doIndent = true
                    }
                }
            }
            if (!doIndent && siblingIndexInt > 0) {
                if (isNode(prev, "br")) {
                    doIndent = true
                }
            }
            if (doIndent) {
                // special case wrap on inline <br> - doesn't make sense as a block tag) 
                indent(accum, depth, out)
            }
        }
        Entities.escape(accum, coreValue(), out, false, normaliseWhite, trimLeading, trimTrailing)
    }

    private func outerHtmlHeadIf1(next: ?Node, prev: ?Node, out: DocumentOutputSettings): (Bool, Bool, Bool) {
        var isElement = match (next) {
            case Some(v: Element) => v.shouldIndent(out)
            case _ => false
        }
        var isTextNode = match (next) {
            case Some(v: TextNode) => v.isBlank()
            case _ => false
        }
        var isBlockElement = match (prev) {
            case Some(v: Element) => v.isBlock() || v.isNodeNew("br")
            case _ => false
        }
        return (isElement, isTextNode, isBlockElement)
    }

    protected open override func outerHtmlTail(_: StringBuilder, _: Int64, _: DocumentOutputSettings): Unit {
    }

    public func toString(): String {
        return outerHtml()
    }

    public open override func clone(): TextNode {
        return (super.clone() as TextNode)()
    }

    /*
     * Create a new TextNode from HTML encoded (aka escaped) data.
     *
     * @param encodedText Text containing encoded HTML
     * @return TextNode containing unencoded data
     */
    public static func createFromEncoded(encodedText: String): TextNode {
        var text: String = Entities.unescape(encodedText)
        return TextNode(text)
    }

    static func lastCharIsWhitespace(sb: StringBuilder): Bool {
        return sb.size != 0 && sb.toString()[sb.size - 1] == b' '
    }
}
