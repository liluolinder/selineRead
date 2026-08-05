/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * HTML Tree Builder; creates a DOM from Tokens.
 */
class HtmlTreeBuilder <: TreeBuilder {
    static let InTableFoster = Constants.InTableFoster

    // tag searches. must be sorted, used in inSorted. HtmlTreeBuilderTest validates they're sorted.
    static let TagsSearchInScope: Array<String> = ["applet", "caption", "html", "marquee", "object", "table", "td", "th"]
    static let TagSearchList: Array<String> = ["ol", "ul"]
    static let TagSearchButton: Array<String> = ["button"]
    static let TagSearchTableScope: Array<String> = ["html", "table"]
    static let TagSearchSelectScope: Array<String> = ["optgroup", "option"]
    static let TagSearchEndTags: Array<String> = ["dd", "dt", "li", "optgroup", "option", "p", "rb", "rp", "rt", "rtc"]
    static let TagThoroughSearchEndTags: Array<String> = [
        "caption",
        "colgroup",
        "dd",
        "dt",
        "li",
        "optgroup",
        "option",
        "p",
        "rb",
        "rp",
        "rt",
        "rtc",
        "tbody",
        "td",
        "tfoot",
        "th",
        "thead",
        "tr"
    ]
    static let TagSearchSpecial: Array<String> = [
        "address",
        "applet",
        "area",
        "article",
        "aside",
        "base",
        "basefont",
        "bgsound",
        "blockquote",
        "body",
        "br",
        "button",
        "caption",
        "center",
        "col",
        "colgroup",
        "command",
        "dd",
        "details",
        "dir",
        "div",
        "dl",
        "dt",
        "embed",
        "fieldset",
        "figcaption",
        "figure",
        "footer",
        "form",
        "frame",
        "frameset",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "head",
        "header",
        "hgroup",
        "hr",
        "html",
        "iframe",
        "img",
        "input",
        "isindex",
        "li",
        "link",
        "listing",
        "marquee",
        "menu",
        "meta",
        "nav",
        "noembed",
        "noframes",
        "noscript",
        "object",
        "ol",
        "p",
        "param",
        "plaintext",
        "pre",
        "script",
        "section",
        "select",
        "style",
        "summary",
        "table",
        "tbody",
        "td",
        "textarea",
        "tfoot",
        "th",
        "thead",
        "title",
        "tr",
        "ul",
        "wbr",
        "xmp"
    ]

    public static let MaxScopeSearchDepth: Int = 100 // prevents the parser bogging down in exceptionally broken pages

    private var _state: ?HtmlTreeBuilderState = None // the current state
    private var _originalState: ?HtmlTreeBuilderState = None // original / marked state

    private var baseUriSetFromDoc = false
    private var headElement: ?Element = None // the current head element
    private var formElement: ?FormElement = None // the current form element
    private var contextElement: ?Element = None // fragment parse context -- could be None even if fragment parsing
    private var formattingElements: ArrayList<?Element> = ArrayList<?Element>() // active (open) formatting elements
    private var tmplInsertMode: ArrayList<HtmlTreeBuilderState> = ArrayList<HtmlTreeBuilderState>() // stack of Template Insertion modes
    private var pendingTableCharacters: ArrayList<String> = ArrayList<String>() // chars in table to be shifted out
    private var emptyEnd: ?EndTagToken = None // reused empty end tag

    private var _framesetOk = false // if ok to go into frameset
    private var fosterInserts = false // if next inserts should be fostered
    private var fragmentParsing = false // if parsing a fragment of html

    protected override func defaultSettings(): ParseSettings {
        return ParseSettings.htmlDefault
    }

    protected override func newInstance(): HtmlTreeBuilder {
        return HtmlTreeBuilder()
    }

    protected func initialiseParse(input: StringReader, baseUri: String, parser: Parser): Unit {
        super.initialiseParse(input, baseUri, parser)

        _state = HtmlTreeBuilderState.Initial
        _originalState = None
        baseUriSetFromDoc = false
        headElement = None
        formElement = None
        contextElement = None
        formattingElements.clear()
        tmplInsertMode.clear()
        pendingTableCharacters.clear()
        emptyEnd = EndTagToken()
        _framesetOk = true
        fosterInserts = false
        fragmentParsing = false
    }

    protected override func parseFragment(inputFragment: String, context: ?Element, baseUri: String, parser: Parser): ArrayList<Node> {
        // context may be None
        this._state = HtmlTreeBuilderState.Initial
        initialiseParse(StringReader(inputFragment), baseUri, parser)
        contextElement = context
        fragmentParsing = true
        var root: ?Element = None

        if (context.isSome()) {
            if (context().ownerDocument().isSome()) {
                // quirks setup:
                doc?.quirksMode(context().ownerDocument()().quirksMode())
            }

            // initialise the tokeniser state:
            let contextTag: String = context().normalName()
            match (contextTag) {
                case "title" | "textarea" => tokeniser?.transition(TokeniserState.Rcdata)

                case "iframe" | "noembed" | "noframes" | "style" | "xml" => tokeniser?.transition(
                    TokeniserState.Rawtext)

                case "script" => tokeniser?.transition(TokeniserState.ScriptData)

                case "noscript" => tokeniser?.transition(TokeniserState.Data) // if scripting enabled, rawtext

                case "plaintext" => tokeniser?.transition(TokeniserState.PLAINTEXT)

                case "template" =>
                    tokeniser?.transition(TokeniserState.Data)
                    pushTemplateMode(HtmlTreeBuilderState.InTemplate)

                case _ => tokeniser?.transition(TokeniserState.Data)
            }
            root = Element(tagFor(contextTag, settings()), baseUri)
            doc?.appendChild((root() as Node)())
            stack?.add(root())
            resetInsertionMode()

            // setup form element to nearest form on context (up ancestor chain). ensures form controls are associated
            // with form correctly
            var formSearch: ?Element = context
            while (formSearch.isSome()) {
                if (formSearch() is FormElement) {
                    formElement = (formSearch() as FormElement)()
                    break
                }
                formSearch = formSearch().parentElement()
            }
        }

        runParser()
        match (context) {
            case None => return doc().childNodes()
            case _ =>
                // depending on context and the input html, content may have been added outside of the root el
                // e.g. context=p, input=div, the div will have been pushed out.
                let nodes: ArrayList<Node> = root().siblingNodes()
                if (!nodes.isEmpty()) {
                    root?.insertChildren(-1, nodes)
                }
                return root().childNodes()
        }
    }

    protected func process(token: Token): Bool {
        currentToken = token
        return state().process(token, this)
    }

    func process(token: Token, state: HtmlTreeBuilderState): Bool {
        currentToken = token
        return state.process(token, this)
    }

    func transition(state: HtmlTreeBuilderState): Unit {
        this._state = state
    }

    func state(): HtmlTreeBuilderState {
        return this._state()
    }

    func markInsertionMode(): Unit {
        _originalState = _state
    }

    func originalState(): HtmlTreeBuilderState {
        return _originalState()
    }

    func framesetOk(framesetOk: Bool): Unit {
        this._framesetOk = framesetOk
    }

    func framesetOk(): Bool {
        return _framesetOk
    }

    func getDocument(): Document {
        return doc()
    }

    func getBaseUri(): String {
        return baseUri()
    }

    func maybeSetBaseUri(base: Element): Unit {
        if (baseUriSetFromDoc) {
            // only listen to the first <base href> in parse
            return
        }

        let href: String = base.absUrl("href")
        if (href.size != 0) { // ignore <base target> etc
            baseUri = href
            baseUriSetFromDoc = true
            doc?.setBaseUri(href) // set on the doc so doc.createElement(Tag) will get updated base, and to update all descendants
        }
    }

    func isFragmentParsing(): Bool {
        return fragmentParsing
    }

    func error(state: HtmlTreeBuilderState): Unit {
        if (parser().getErrors().canAddError()) {
            parser()
                .getErrors()
                .add(
                    ParseError(
                        reader(),
                        "Unexpected ${currentToken().tokenType()} token [${currentToken()}] when in state [${state}]"
                    )
                )
        }
    }

    func insert(startTag: StartTagToken): Element {
        // cleanup duplicate attributes:
        if (startTag.hasAttributes() && !startTag.attributes().isEmpty()) {
            let dupes: Int64 = startTag.attributes().deduplicate(settings())
            if (dupes > 0) {
                error("Dropped duplicate attribute(s) in tag [${startTag.normalName()}]")
            }
        }

        // handle empty unknown tags
        // when the spec expects an empty tag, will directly hit insertEmpty, so won't generate this fake end tag.
        if (startTag.isSelfClosing()) {
            let el: Element = insertEmpty(startTag)
            stack?.add(el)
            tokeniser?.transition(TokeniserState.Data) // handles <script />, otherwise needs breakout steps from script data
            tokeniser?.emit(emptyEnd().reset().name(el.tagName())) // ensure we get out of whatever state we are in. emitted for yielded processing
            return el
        }

        let el: Element = Element(
            tagFor(startTag.name(), settings()),
            None,
            settings().normalizeAttributes(startTag.attributes)
        )
        let token = (startTag as Token)
        insert(el, token)
        return el
    }

    func insertStartTag(startTagName: String): Element {
        let el: Element = Element(tagFor(startTagName, settings()), None)
        insert(el)
        return el
    }

    func insert(el: Element): Unit {
        insertNode(el, None)
        stack?.add(el)
    }

    private func insert(el: Element, token: ?Token): Unit {
        insertNode(el, token)
        stack?.add(el)
    }

    func insertEmpty(startTag: StartTagToken): Element {
        let tag: Tag = tagFor(startTag.name(), settings())
        let el: Element = Element(tag, None, settings().normalizeAttributes(startTag.attributes))
        insertNode(el, startTag)
        if (startTag.isSelfClosing()) {
            if (tag.isKnownTag()) {
                if (!tag.isEmpty()) {
                    tokeniser?.error("Tag [${tag.normalName()}] cannot be self closing; not a void tag")
                }
            } else {
                // unknown tag, remember this is self closing for output
                tag.setSelfClosing()
            }
        }
        return el
    }

    func insertForm(startTag: StartTagToken, onStackBool: Bool, checkTemplateStack: Bool): FormElement {
        let tag: Tag = tagFor(startTag.name(), settings())
        let el: FormElement = FormElement(tag, None, settings().normalizeAttributes(startTag.attributes))
        if (checkTemplateStack) {
            if (!onStack("template")) {
                setFormElement(el)
            }
        } else {
            setFormElement(el)
        }

        insertNode(el, startTag)
        if (onStackBool) {
            stack?.add(el)
        }
        return el
    }

    func insert(commentToken: CommentToken): Unit {
        let comment: Comment = Comment(commentToken.getData())
        insertNode(comment, commentToken)
    }

    func insert(characterToken: CharacterToken): Unit {
        let node: Node
        let el: Element = currentElement() // will be doc if no current element; allows for whitespace to be inserted into the doc root object (not on the stack)
        let tagName: String = el.normalName()
        let data: String = characterToken.getData()

        if (characterToken.isCData()) {
            node = CDataNode(data)
        } else if (isContentForTagData(tagName)) {
            node = DataNode(data)
        } else {
            node = TextNode(data)
        }
        el.appendChild(node) // doesn't use insertNode, because we don't foster these; and will always have a stack.
        onNodeInserted(node, characterToken)
    }

    private func insertNode(node: Node, token: ?Token): Unit {
        // if the stack hasn't been set up yet, elements (doctype, comments) go into the doc
        if (stack().isEmpty()) {
            doc().appendChild(node)
        } else if (isFosterInserts() && StringUtil.inSorted(currentElement().normalName(), InTableFoster)) {
            insertInFosterParent(node)
        } else {
            currentElement().appendChild(node)
        }

        // connect form controls to their form element
        if (node is Element && (node as Element)().tag().isFormListed()) {
            if (formElement.isSome()) {
                formElement?.addElement((node as Element)())
            }
        }
        onNodeInserted(node, token)
    }

    func pop(): Element {
        let size: Int64 = stack().size
        return stack().remove(at: size - 1)
    }

    func push(element: Element): Unit {
        stack?.add(element)
    }

    func getStack(): ArrayList<Element> {
        return stack()
    }

    func onStack(el: Element): Bool {
        return onStack(stack(), el)
    }

    func onStack(elName: String): Bool {
        return getFromStack(elName).isSome()
    }

    private static let maxQueueDepth: Int64 = 256 // an arbitrary tension poInt64 between real HTML and crafted pain
    private func onStack(queue: ArrayList<Element>, element: Element): Bool {
        let bottom = queue.size - 1
        let upper = if (bottom >= maxQueueDepth) {
            bottom - maxQueueDepth
        } else {
            0
        }
        for (pos in bottom..=upper : -1) {
            let next: Element = queue[pos]
            if (next == element) {
                return true
            }
        }
        return false
    }
    private func onStack(queue: ArrayList<?Element>, element: ?Element): Bool {
        let bottom = queue.size - 1
        let upper = if (bottom >= maxQueueDepth) {
            bottom - maxQueueDepth
        } else {
            0
        }
        for (pos in bottom..=upper : -1) {
            let next: ?Element = queue[pos]
            if (next == element) {
                return true
            }
        }
        return false
    }

    func getFromStack(elName: String): ?Element {
        let bottom = stack().size - 1
        let upper = if (bottom >= maxQueueDepth) {
            bottom - maxQueueDepth
        } else {
            0
        }
        for (pos in bottom..=upper : -1) {
            let next: Element = stack()[pos]
            if (next.normalName().equals(elName)) {
                return next
            }
        }
        return None
    }

    func removeFromStack(el: Element): Bool {
        for (pos in stack().size - 1..=0 : -1) {
            let next: Element = stack()[pos]
            if (next == el) {
                stack?.remove(at: pos)
                return true
            }
        }
        return false
    }

    func popStackToClose(elName: String): ?Element {
        for (pos in stack().size - 1..=0 : -1) {
            let el: Element = stack()[pos]
            stack?.remove(at: pos)
            if (el.normalName().equals(elName)) {
                match (currentToken) {
                    case Some(v: EndTagToken) => onNodeClosed(el, v)
                    case _ => ()
                }
                return el
            }
        }
        return None
    }

    // elnames is sorted, comes from Constants
    func popStackToClose(elNames: Array<String>): Unit {
        for (pos in stack().size - 1..=0 : -1) {
            let next: Element = stack()[pos]
            stack?.remove(at: pos)
            if (inSorted(next.normalName(), elNames)) {
                break
            }
        }
    }

    func popStackToBefore(elName: String): Unit {
        for (pos in stack().size - 1..=0 : -1) {
            let next: Element = stack()[pos]
            if (next.normalName().equals(elName)) {
                break
            } else {
                stack?.remove(at: pos)
            }
        }
    }

    func clearStackToTableContext(): Unit {
        clearStackToContext("table", "template")
    }

    func clearStackToTableBodyContext(): Unit {
        clearStackToContext("tbody", "tfoot", "thead", "template")
    }

    func clearStackToTableRowContext(): Unit {
        clearStackToContext("tr", "template")
    }

    private func clearStackToContext(nodeNames: Array<String>): Unit {
        for (pos in stack().size - 1..=0 : -1) {
            let next: Element = stack()[pos]
            if (nodeNames.contains(next.normalName()) || next.normalName().equals("html")) {
                break
            } else {
                stack?.remove(at: pos)
            }
        }
    }

    func aboveOnStack(el: Element): ?Element {
        // assert onStack(el)
        for (pos in stack().size - 1..=0 : -1) {
            let next: Element = stack()[pos]
            if (next == el) {
                return stack()[pos - 1]
            }
        }
        return None
    }

    func insertOnStackAfter(after: Element, inEle: Element): Unit {
        let i: Int64 = stack().lastIndexOf(after)
        Validate.isTrue(i != -1)
        stack?.add(inEle, at: i + 1)
    }

    func replaceOnStack(out: Element, inEle: Element): Unit {
        replaceInQueue(stack(), out, inEle)
    }

    private func replaceInQueue(queue: ArrayList<Element>, out: Element, inEle: Element): Unit {
        let i: Int64 = queue.lastIndexOf(out)
        Validate.isTrue(i != -1)
        queue[i] = inEle
    }
    private func replaceInQueue(queue: ArrayList<?Element>, out: Element, inEle: Element): Unit {
        for (i in queue.size - 1..=0 : -1) {
            if (queue[i] == out) {
                queue[i] = inEle
                return
            }
        }
    }

    /*
     * Reset the insertion mode, by searching up the stack for an appropriate insertion mode.
     * The stack search depth is limited to #maxQueueDepth.
     * @return true if the insertion mode was actually changed.
     */
    func resetInsertionMode(): Bool {
        var last = false
        let bottom = stack().size - 1
        let upper = if (bottom >= maxQueueDepth) {
            bottom - maxQueueDepth
        } else {
            0
        }
        let origState: HtmlTreeBuilderState = this.state()

        if (stack().size == 0) { // nothing left of stack, just get to body
            transition(HtmlTreeBuilderState.InBody)
        }

        for (pos in bottom..=upper : -1) {
            var node: ?Element = stack?[pos]
            if (pos == upper) {
                last = true
                if (fragmentParsing) {
                    node = contextElement
                }
            }
            let name: String = match (node) {
                case Some(v) => v.normalName()
                case _ => ""
            }
            if (resetInsertionModeMatchName(name, last)) {
                break
            }
            if (last) {
                transition(HtmlTreeBuilderState.InBody)
                break
            }
        }
        return !refEq(state(), origState)
    }
    private func resetInsertionModeMatchName(name: String, last: Bool): Bool {
        var needBreakLoop = true
        match (name) {
            case "select" => transition(HtmlTreeBuilderState.InSelect)
            case "td" | "th" =>
                if (!last) {
                    transition(HtmlTreeBuilderState.InCell)
                } else {
                    needBreakLoop = false
                }
            case "tr" => transition(HtmlTreeBuilderState.InRow)
            case "tbody" | "thead" | "tfoot" => transition(HtmlTreeBuilderState.InTableBody)
            case "caption" => transition(HtmlTreeBuilderState.InCaption)
            case "colgroup" => transition(HtmlTreeBuilderState.InColumnGroup)
            case "table" => transition(HtmlTreeBuilderState.InTable)
            case "template" =>
                let tmplState: ?HtmlTreeBuilderState = currentTemplateMode()
                Validate.notNull(tmplState, "Bug: no template insertion mode on stack!")
                transition(tmplState())
            case "head" =>
                if (!last) {
                    transition(HtmlTreeBuilderState.InHead)
                } else {
                    needBreakLoop = false
                }
            case "body" => transition(HtmlTreeBuilderState.InBody)
            case "frameset" => transition(HtmlTreeBuilderState.InFrameset)
            case "html" => transition(
                match (headElement) {
                    case None => HtmlTreeBuilderState.BeforeHead
                    case _ => HtmlTreeBuilderState.AfterHead
                })
            case _ => needBreakLoop = false
        }
        return needBreakLoop
    }

    /* Places the body back onto the stack and moves to InBody, for cases in AfterBody / AfterAfterBody when more content comes */
    func resetBody(): Unit {
        if (!onStack("body")) {
            stack?.add(doc().body())
        }
        transition(HtmlTreeBuilderState.InBody)
    }

    private let specificScopeTarget: Array<String> = [""]

    private func inSpecificScope(targetName: String, baseTypes: Array<String>, extraTypes: ?Array<String>): Bool {
        specificScopeTarget[0] = targetName
        return inSpecificScope(specificScopeTarget, baseTypes, extraTypes)
    }

    private func inSpecificScope(targetNames: Array<String>, baseTypes: Array<String>, extraTypes: ?Array<String>): Bool {
        let bottom: Int64 = stack().size - 1
        let top: Int64 = if (bottom > MaxScopeSearchDepth) {
            bottom - MaxScopeSearchDepth
        } else {
            0
        }

        // don't walk too far up the tree
        for (pos in bottom..=top : -1) {
            let elName: String = stack()[pos].normalName()
            if (inSorted(elName, targetNames)) {
                return true
            }
            if (inSorted(elName, baseTypes)) {
                return false
            }
            if (extraTypes.isSome() && inSorted(elName, extraTypes())) {
                return false
            }
        }

        //Validate.fail("Should not be reachable") // would end up false because hitting 'html' at root (basetypes)
        return false
    }

    func inScope(targetNames: Array<String>): Bool {
        return inSpecificScope(targetNames, TagsSearchInScope, None)
    }

    func inScope(targetName: String): Bool {
        return inScope(targetName, None)
    }

    func inScope(targetName: String, extras: ?Array<String>): Bool {
        return inSpecificScope(targetName, TagsSearchInScope, extras)
    }

    func inListItemScope(targetName: String): Bool {
        return inScope(targetName, TagSearchList)
    }

    func inButtonScope(targetName: String): Bool {
        return inScope(targetName, TagSearchButton)
    }

    func inTableScope(targetName: String): Bool {
        return inSpecificScope(targetName, TagSearchTableScope, None)
    }

    func inSelectScope(targetName: String): Bool {
        for (pos in stack().size - 1..=0 : -1) {
            let el: Element = stack()[pos]
            let elName: String = el.normalName()
            if (elName.equals(targetName)) {
                return true
            }
            if (!inSorted(elName, TagSearchSelectScope)) {
                // all elements except
                return false
            }
        }
        Validate.fail("Should not be reachable")
        return false
    }

    func setHeadElement(headElement: Element): Unit {
        this.headElement = headElement
    }

    func getHeadElement(): Element {
        return headElement()
    }

    func isFosterInserts(): Bool {
        return fosterInserts
    }

    func setFosterInserts(fosterInserts: Bool): Unit {
        this.fosterInserts = fosterInserts
    }

    func getFormElement(): ?FormElement {
        return formElement
    }

    func setFormElement(formElement: ?FormElement): Unit {
        this.formElement = formElement
    }

    func newPendingTableCharacters(): Unit {
        pendingTableCharacters = ArrayList<String>()
    }

    func getPendingTableCharacters(): ArrayList<String> {
        return pendingTableCharacters
    }

    /*
       Closing elements that have implied end tags
       When the steps below require the UA to generate implied end tags, then, while the current node is a dd element, a dt element, an li element, an optgroup element, an option element, a p element, an rb element, an rp element, an rt element, or an rtc element, the UA must pop the current node off the stack of open elements.

       If a step requires the UA to generate implied end tags but lists an element to exclude from the process, then the UA must perform the above steps as if that element was not in the above list.

       When the steps below require the UA to generate all implied end tags thoroughly, then, while the current node is a caption element, a colgroup element, a dd element, a dt element, an li element, an optgroup element, an option element, a p element, an rb element, an rp element, an rt element, an rtc element, a tbody element, a td element, a tfoot element, a th element, a thead element, or a tr element, the UA must pop the current node off the stack of open elements.

       @param excludeIf:Tag a step requires the UA to generate implied end tags but lists an element to exclude from the
       process, then the UA must perform the above steps as if that element was not in the above list.
     */
    func generateImpliedEndTags(excludeTag: String): Unit {
        while (inSorted(currentElement().normalName(), TagSearchEndTags)) {
            if (currentElementIs(excludeTag)) {
                break
            }
            pop()
        }
    }

    func generateImpliedEndTags(): Unit {
        generateImpliedEndTags(false)
    }

    /*
       Pops elements off the stack according to the implied end tag rules
       @param thorough if we are thorough (includes table elements etc) or not
     */
    func generateImpliedEndTags(thorough: Bool): Unit {
        let search: Array<String> = if (thorough) {
            TagThoroughSearchEndTags
        } else {
            TagSearchEndTags
        }
        while (inSorted(currentElement().normalName(), search)) {
            pop()
        }
    }

    func closeElement(name: String): Unit {
        generateImpliedEndTags(name)
        if (!name.equals(currentElement().normalName())) {
            error(state())
        }
        popStackToClose(name)
    }

    func isSpecial(el: Element): Bool {
        let name: String = el.normalName()
        return inSorted(name, TagSearchSpecial)
    }

    func lastFormattingElement(): ?Element {
        return if (formattingElements.size > 0) {
            formattingElements[formattingElements.size - 1]
        } else {
            None
        }
    }

    func positionOfElement(el: Element): Int64 {
        for (i in 0..formattingElements.size) {
            if (formattingElements[i].refEq(el)) {
                return i
            }
        }
        return -1
    }

    func removeLastFormattingElement(): ?Element {
        let size: Int64 = formattingElements.size
        if (size > 0) {
            return formattingElements.remove(at: size - 1)
        } else {
            return None
        }
    }

    // active formatting elements
    func pushActiveFormattingElements(inEle: Element): Unit {
        checkActiveFormattingElements(inEle)
        formattingElements.add(inEle)
    }

    func pushWithBookmark(inEle: Element, bookmark: Int64): Unit {
        checkActiveFormattingElements(inEle)

        // catch any range errors and assume bookmark is incorrect - saves a redundant range check.
        try {
            formattingElements.add(inEle, at: bookmark)
        } catch (e: IndexOutOfBoundsException) {
            formattingElements.add(inEle)
        }
    }

    func checkActiveFormattingElements(inEle: Element): Unit {
        var numSeen: Int64 = 0
        let size: Int64 = formattingElements.size - 1
        var ceil: Int64 = size - maxUsedFormattingElements
        if (ceil < 0) {
            ceil = 0
        }

        for (pos in size..=ceil : -1) {
            let el = formattingElements[pos]
            if (el.isNone()) {
                // marker
                break
            }

            if (isSameFormattingElement(inEle, el())) {
                numSeen++
            }

            if (numSeen == 3) {
                formattingElements.remove(at: pos)
                break
            }
        }
    }

    private func isSameFormattingElement(a: Element, b: Element): Bool {
        // same if: same namespace, tag, and attributes. Element.equals only checks tag, might in future check children
        if (a.normalName().equals(b.normalName())) {
            if (a.attributes() == b.attributes()) {
                return true
            }
        }
        return false
    }

    func reconstructFormattingElements(): Unit {
        if (stack().size > maxQueueDepth) {
            return
        }
        let last: ?Element = lastFormattingElement()
        if (last.isNone() || onStack(last())) {
            return
        }

        var entry: ?Element = last
        let size: Int64 = formattingElements.size
        var ceil: Int64 = size - maxUsedFormattingElements
        if (ceil < 0) {
            ceil = 0
        }
        var pos: Int64 = size - 1
        var skip: Bool = false
        while (true) {
            if (pos == ceil) { // step 4. if none before, skip to 8
                skip = true
                break
            }
            pos--
            entry = formattingElements[pos] // step 5. one earlier than entry
            if (entry.isNone() || onStack(entry())) {
                // step 6 - neither marker nor on stack
                break
                // jump to 8, else continue back to 4
            }
        }
        while (true) {
            if (!skip) {
                // step 7: on later than entry
                pos++
                entry = formattingElements[pos]
            }
            Validate.notNull(entry) // should not occur, as we break at last element

            // 8. createelement from element, 9 insert into current node, onto stack
            skip = false // can only skip increment from 4.
            let newEl: Element = Element(tagFor(entry().normalName(), settings()), None, entry().attributes().clone())
            insert(newEl)

            // 10. replace entry withentry
            formattingElements[pos] = newEl

            // 11
            if (pos == size - 1) {
                // if not last entry in list, jump to 7
                break
            }
        }
    }
    private static let maxUsedFormattingElements: Int64 = 12 // limit how many elements get recreated

    func clearFormattingElementsToLastMarker(): Unit {
        while (!formattingElements.isEmpty()) {
            let el: ?Element = removeLastFormattingElement()
            if (el.isNone()) {
                break
            }
        }
    }

    func removeFromActiveFormattingElements(el: Element): Unit {
        for (pos in formattingElements.size - 1..=0 : -1) {
            let next: ?Element = formattingElements[pos]
            if (el.refEq(next)) {
                formattingElements.remove(at: pos)
                break
            }
        }
    }

    func isInActiveFormattingElements(el: Element): Bool {
        return onStack(formattingElements, el)
    }

    func getActiveFormattingElement(nodeName: String): ?Element {
        for (pos in formattingElements.size - 1..=0 : -1) {
            let next: ?Element = formattingElements[pos]
            if (next.isNone()) {
                // scope marker
                break
            } else if (next().normalName().equals(nodeName)) {
                return next
            }
        }
        return None
    }

    func replaceActiveFormattingElement(out: Element, inEle: Element): Unit {
        replaceInQueue(formattingElements, out, inEle)
    }

    func insertMarkerToFormattingElements(): Unit {
        formattingElements.add(None)
    }

    func insertInFosterParent(inNode: Node): Unit {
        var fosterParent: ?Element
        let lastTable: ?Element = getFromStack("table")
        var isLastTableParent: Bool = false
        if (lastTable.isSome()) {
            if (lastTable().parent().isSome()) {
                fosterParent = (lastTable().parent() as Element)
                isLastTableParent = true
            } else {
                fosterParent = aboveOnStack(lastTable())
            }
        } else { // no table == frag
            fosterParent = stack?[0]
        }

        if (isLastTableParent) {
            Validate.notNull(lastTable) // last table cannot be None by this point.
            lastTable?.before(inNode)
        } else {
            fosterParent?.appendChild(inNode)
        }
    }

    // Template Insertion Mode stack
    func pushTemplateMode(state: HtmlTreeBuilderState): Unit {
        tmplInsertMode.add(state)
    }

    func popTemplateMode(): ?HtmlTreeBuilderState {
        if (tmplInsertMode.size > 0) {
            return tmplInsertMode.remove(at: tmplInsertMode.size - 1)
        } else {
            return None
        }
    }

    func templateModeSize(): Int64 {
        return tmplInsertMode.size
    }

    func currentTemplateMode(): ?HtmlTreeBuilderState {
        return if (tmplInsertMode.size > 0) {
            tmplInsertMode[tmplInsertMode.size - 1]
        } else {
            None
        }
    }

    public func toString(): String {
        return "TreeBuilder{currentToken=${currentToken()}, state=${state()}, currentElement=${currentElement()}}"
    }

    protected func isContentForTagData(normalName: String): Bool {
        return (normalName.equals("script") || normalName.equals("style"))
    }
}
