/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * TreeBuilder
 */
abstract class TreeBuilder {
    protected var parser: ?Parser = None
    var reader: ?CharacterReader = None
    var tokeniser: ?Tokeniser = None
    protected var doc: ?Document = None // current doc we are building into
    protected var stack: ?ArrayList<Element> = None // the stack of open elements
    protected var baseUri: ?String = None // current base uri, for creatingelements
    protected var currentToken: ?Token = None // currentToken is used only for error tracking.
    protected var settings: ?ParseSettings = None
    var seenTags: ?HashMap<String, Tag> = None // tags we've used in this parse; saves tag GC for custom tags.

    private let start: StartTagToken = StartTagToken() // start tag to process
    private let end: EndTagToken = EndTagToken()

    protected func defaultSettings(): ParseSettings

    private var trackSourceRange: Bool = false // optionally tracks the source range of nodes

    protected open func initialiseParse(input: StringReader, baseUri: String, parser: Parser): Unit {
        doc = Document(baseUri)
        doc?.parser(parser)
        this.parser = parser
        settings = parser.settings()
        trackSourceRange = parser.isTrackPosition()
        reader = CharacterReader(input)
        reader?.trackNewlines(parser.isTrackErrors() || trackSourceRange) // when tracking errors or source ranges, enable newline tracking for better legibility
        currentToken = None
        tokeniser = Tokeniser(reader(), parser.getErrors())
        stack = ArrayList<Element>(32)
        seenTags = HashMap<String, Tag>()
        this.baseUri = baseUri
    }

    func parse(input: StringReader, baseUri: String, parser: Parser): Document {
        initialiseParse(input, baseUri, parser)
        runParser()

        // tidy up - as the Parser and Treebuilder are retained in document for settings / fragments
        reader?.close()
        reader = None
        tokeniser = None
        stack = None
        seenTags = None

        return doc()
    }

    /*
       Create acopy of this TreeBuilder
       @return copy, ready for aparse
     */
    protected func newInstance(): TreeBuilder

    protected func parseFragment(inputFragment: String, context: ?Element, baseUri: String, parser: Parser): ArrayList<Node>

    protected func runParser(): Unit {
        let tokeniser = this.tokeniser()
        let eof = TokenType.EOFType

        while (true) {
            let token = tokeniser.read()
            process(token)
            token.reset()

            if (token.typ == eof) {
                break
            }
        }
    }

    protected func process(token: Token): Bool

    protected func processStartTag(name: String): Bool {
        // these are "virtual" start tags (auto-created by the treebuilder), so not tracking the start position
        let start = this.start
        if (refEq(currentToken(), start)) { // don't recycle an in-use token
            return process(StartTagToken().name(name))
        }
        return process(start.reset().name(name))
    }

    func processStartTag(name: String, attrs: Attributes): Bool {
        let start = this.start
        if (refEq(currentToken(), start)) { // don't recycle an in-use token
            return process(StartTagToken().nameAttr(name, attrs))
        }
        start.reset()
        start.nameAttr(name, attrs)
        return process(start)
    }

    protected func processEndTag(name: String): Bool {
        if (refEq(currentToken(), end)) { // don't recycle an in-use token
            return process(EndTagToken().name(name))
        }
        return process(end.reset().name(name))
    }

    /*
       Get the current element (last on the stack). If all items have been removed, returns the document instead
       (which might not actually be on the stack; use stack.size() == 0 to test if required.
       @return the last element on the stack, if any; or the root document
     */
    protected func currentElement(): Element {
        let size = stack().size
        return if (size > 0) {
            stack()[size - 1]
        } else {
            doc()
        }
    }

    /*
       Checks if the Current Element's normal name equals the supplied name.
       @param normalName name to check
       @return true if there is a current element on the stack, and its name equals the supplied
     */
    protected func currentElementIs(normalName: String): Bool {
        if (stack().size == 0) {
            return false
        }
        let current = currentElement()
        return current.normalName().equals(normalName)
    }

    /*
     * If the parser is tracking errors, add an error at the current position.
     * @param msg error message template
     * @param args template arguments
     */
    protected func error(msg: String): Unit {
        let errors = parser().getErrors()
        if (errors.canAddError()) {
            errors.add(ParseError(reader(), msg))
        }
    }

    /*
       (An internal method, visible for Element. For HTML parse, signals that script and style text should be treated as
       Data Nodes).
     */
    protected open func isContentForTagData(_: String): Bool {
        return false
    }

    func tagFor(tagName: String, settings: ParseSettings): Tag {
        var tag = seenTags().get(tagName) // note that we don't normalize the cache key. But tag via valueOf may be normalized.
        if (tag == None) {
            tag = Tag.valueOf(tagName, settings)
            seenTags?.add(tagName, tag())
        }
        return tag()
    }

    /*
       Called by implementing TreeBuilders when a node has been inserted. This implementation includes optionally tracking
       the source range of the node.
     * @param node the node that was just inserted
     * @param token the (optional) token that created this node
     */
    protected func onNodeInserted(node: Node, token: ?Token) {
        trackNodePosition(node, token, true)
    }

    /*
       Called by implementing TreeBuilders when a node is explicitly closed. This implementation includes optionally
       tracking the closing source range of the node.
     * @param node the node being closed
     * @param token the end-tag token that closed this node
     */
    protected func onNodeClosed(node: Node, token: Token) {
        trackNodePosition(node, token, false)
    }

    private func trackNodePosition(node: Node, token: ?Token, start: Bool) {
        if (trackSourceRange && token != None) {
            let startPos = token().startPos()
            if (startPos == Token.Unset) {
                return
            } // untracked, virtual token

            let startRange = SrcPosition(startPos, reader().lineNumber(startPos), reader().columnNumber(startPos))
            let endPos = token().endPos()
            let endRange = SrcPosition(endPos, reader().lineNumber(endPos), reader().columnNumber(endPos))
            let range = SrcRange(startRange, endRange)
            range.track(node, start)
        }
    }
}
