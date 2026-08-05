/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Use the XmlTreeBuilder when you want to parse XML without any of the HTML DOM rules being applied to the document.
 * Usage example: let xmlDoc:Document = Html4cj.parse(html, baseUrl, Parser.xmlParser())
 */
class XmlTreeBuilder <: TreeBuilder {
    protected override func defaultSettings(): ParseSettings {
        return ParseSettings.preserveCase
    }

    protected override func initialiseParse(input: StringReader, baseUri: String, parser: Parser): Unit {
        super.initialiseParse(input, baseUri, parser)
        stack?.add(doc()) // place the document onto the stack. differs from HtmlTreeBuilder (not on stack)
        doc().outputSettings().syntax(Syntax.xmlSyntax).escapeMode(EscapeMode.xhtml).prettyPrint(false) // as XML, we don't understand what whitespace is significant or not
    }

    protected override func newInstance(): XmlTreeBuilder {
        return XmlTreeBuilder()
    }

    protected override func process(token: Token): Bool {
        // start tag, end tag, doctype, comment, character, eof
        match (token.typ) {
            case Some(StartTagType) => insert(token.asStartTag())
            case Some(EndTagType) => popStackToClose(token.asEndTag())
            case Some(CommentType) => insert(token.asComment())
            case Some(CharacterType) => insert(token.asCharacter())
            case Some(DoctypeType) => insert(token.asDoctype())
            case Some(EOFType) => () // could put some normalisation here if desired
            case _ => Validate.fail("Unexpected token type: ${token.typ()}")
        }
        return true
    }

    // protected func insertNode(node: Node): Unit {
    //     currentElement().appendChild(node)
    //     onNodeInserted(node, None)
    // }

    protected func insertNode(node: Node, token: Token): Unit {
        currentElement().appendChild(node)
        onNodeInserted(node, token)
    }

    func insert(startTag: StartTagToken): Element {
        let tag: Tag = tagFor(startTag.name(), settings())
        if (startTag.hasAttributes()) {
            startTag.attributes?.deduplicate(settings())
        }

        let el: Element = Element(tag, None, settings().normalizeAttributes(startTag.attributes))
        insertNode(el, startTag)
        if (startTag.isSelfClosing()) {
            if (!tag.isKnownTag()) {
                // unknown tag, remember this is self closing for output. see above.
                tag.setSelfClosing()
            }
        } else {
            stack?.add(el)
        }
        return el
    }

    func insert(commentToken: CommentToken): Unit {
        let comment: Comment = Comment(commentToken.getData())
        var insert: Node = comment
        if (commentToken.bogus && comment.isXmlDeclaration()) {
            // xml declarations are emitted as bogus comments (which is right for html, but not xml)
            // so we do a bit of a hack and parse the data as an element to pull the attributes out
            let decl: ?XmlDeclaration = comment.asXmlDeclaration() // else, we couldn't parse it as a decl, so leave as a comment
            if (decl.isSome()) {
                insert = decl()
            }
        }
        insertNode(insert, commentToken)
    }

    func insert(token: CharacterToken): Unit {
        let data: String = token.getData()
        let node = if (token.isCData()) {
            CDataNode(data)
        } else {
            TextNode(data)
        }
        insertNode(node, token)
    }

    func insert(d: DoctypeToken): Unit {
        let doctypeNode: DocumentType = DocumentType(
            settings().normalizeTag(d.getName()),
            d.getPublicIdentifier(),
            d.getSystemIdentifier()
        )
        doctypeNode.setPubSysKey(d.getPubSysKey())
        insertNode(doctypeNode, d)
    }

    /*
     * If the stack contains an element with this tag's name, pop up the stack to remove the first occurrence.
     * If not found, skips.
     *
     * @param endTag tag to close
     */
    protected func popStackToClose(endTag: EndTagToken): Unit {
        // like in HtmlTreeBuilder - don't scan up forever for very (artificially) deeply nested stacks
        let elName: String = settings().normalizeTag(endTag.tagName())
        var firstFound: ?Element = None

        let bottom: Int64 = stack().size - 1
        let upper: Int64 = if (bottom >= maxQueueDepth) {
            bottom - maxQueueDepth
        } else {
            0
        }

        for (pos in stack().size - 1..=upper : -1) {
            let next: Element = stack()[pos]
            if (next.nodeName() == elName) {
                firstFound = next
                break
            }
        }
        if (firstFound == None) {
            // not found, skip
            return
        }

        for (pos in stack().size - 1..=0 : -1) {
            let next: Element = stack()[pos]
            stack?.remove(at: pos)
            if (firstFound != None) {
                if (next == firstFound()) {
                    onNodeClosed(next, endTag)
                    break
                }
            }
        }
    }
    private static let maxQueueDepth: Int64 = 256 // an arbitrary tension point between real XML and crafted pain

    func parseFragment(inputFragment: String, baseUri: String, parser: Parser): ArrayList<Node> {
        initialiseParse(StringReader(inputFragment), baseUri, parser)
        runParser()
        return doc().childNodes()
    }

    protected override func parseFragment(inputFragment: String, _: ?Element, baseUri: String, parser: Parser): ArrayList<Node> {
        return parseFragment(inputFragment, baseUri, parser)
    }
}
