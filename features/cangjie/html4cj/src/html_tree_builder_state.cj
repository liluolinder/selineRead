/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * The Tree Builder's current state. Each state embodies the processing for the state, and transitions to other states.
 */
abstract class HtmlTreeBuilderState <: ToString {
    protected static let nullString: String = "\u{0}"

    static let Initial = Initial()
    static let BeforeHtml = BeforeHtml()
    static let BeforeHead = BeforeHead()
    static let InHead = InHead()
    static let InHeadNoscript = InHeadNoscript()
    static let AfterHead = AfterHead()
    static let InBody = InBody()
    static let Text = Text()
    static let InTable = InTable()
    static let InTableText = InTableText()
    static let InCaption = InCaption()
    static let InColumnGroup = InColumnGroup()
    static let InTableBody = InTableBody()
    static let InRow = InRow()
    static let InCell = InCell()
    static let InSelect = InSelect()
    static let InSelectInTable = InSelectInTable()
    static let InTemplate = InTemplate()
    static let AfterBody = AfterBody()
    static let InFrameset = InFrameset()
    static let AfterFrameset = AfterFrameset()
    static let AfterAfterBody = AfterAfterBody()
    static let AfterAfterFrameset = AfterAfterFrameset()
    // static let ForeignContent = ForeignContent()

    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool

    protected static func isWhitespace(tk: Token): Bool {
        if (tk.isCharacter()) {
            let data = tk.asCharacter().getData()
            return StringUtil.isBlank(data)
        }
        return false
    }

    protected static func isWhitespace(data: String): Bool {
        return StringUtil.isBlank(data)
    }

    protected static func handleRcData(startTag: StartTagToken, builder: HtmlTreeBuilder): Unit {
        builder.tokeniser?.transition(TokeniserState.Rcdata)
        builder.markInsertionMode()
        builder.transition(Text)
        builder.insert(startTag)
    }

    protected static func handleRawtext(startTag: StartTagToken, builder: HtmlTreeBuilder): Unit {
        builder.tokeniser?.transition(TokeniserState.Rawtext)
        builder.markInsertionMode()
        builder.transition(Text)
        builder.insert(startTag)
    }
}

// lists of tags to search through
class Constants {
    static let InHeadEmpty: Array<String> = ["base", "basefont", "bgsound", "command", "link"]
    static let InHeadRaw: Array<String> = ["noframes", "style"]
    static let InHeadEnd: Array<String> = ["body", "br", "html"]
    static let AfterHeadBody: Array<String> = ["body", "br", "html"]
    static let BeforeHtmlToHead: Array<String> = ["body", "br", "head", "html"]
    static let InHeadNoScriptHead: Array<String> = ["basefont", "bgsound", "link", "meta", "noframes", "style"]
    static let InBodyStartToHead: Array<String> = [
        "base",
        "basefont",
        "bgsound",
        "command",
        "link",
        "meta",
        "noframes",
        "script",
        "style",
        "template",
        "title"
    ]
    static let InBodyStartPClosers: Array<String> = [
        "address",
        "article",
        "aside",
        "blockquote",
        "center",
        "details",
        "dir",
        "div",
        "dl",
        "fieldset",
        "figcaption",
        "figure",
        "footer",
        "header",
        "hgroup",
        "menu",
        "nav",
        "ol",
        "p",
        "section",
        "summary",
        "ul"
    ]
    static let Headings: Array<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
    static let InBodyStartLiBreakers: Array<String> = ["address", "div", "p"]
    static let DdDt: Array<String> = ["dd", "dt"]
    static let InBodyStartApplets: Array<String> = ["applet", "marquee", "object"]
    static let InBodyStartMedia: Array<String> = ["param", "source", "track"]
    static let InBodyStartInputAttribs: Array<String> = ["action", "name", "prompt"]
    static let InBodyStartDrop: Array<String> = [
        "caption",
        "col",
        "colgroup",
        "frame",
        "head",
        "tbody",
        "td",
        "tfoot",
        "th",
        "thead",
        "tr"
    ]
    static let InBodyEndClosers: Array<String> = [
        "address",
        "article",
        "aside",
        "blockquote",
        "button",
        "center",
        "details",
        "dir",
        "div",
        "dl",
        "fieldset",
        "figcaption",
        "figure",
        "footer",
        "header",
        "hgroup",
        "listing",
        "menu",
        "nav",
        "ol",
        "pre",
        "section",
        "summary",
        "ul"
    ]
    static let InBodyEndAdoptionFormatters: Array<String> = [
        "a",
        "b",
        "big",
        "code",
        "em",
        "font",
        "i",
        "nobr",
        "s",
        "small",
        "strike",
        "strong",
        "tt",
        "u"
    ]
    static let InBodyEndTableFosters: Array<String> = ["table", "tbody", "tfoot", "thead", "tr"]
    static let InTableToBody: Array<String> = ["tbody", "tfoot", "thead"]
    static let InTableAddBody: Array<String> = ["td", "th", "tr"]
    static let InTableToHead: Array<String> = ["script", "style", "template"]
    static let InCellNames: Array<String> = ["td", "th"]
    static let InCellBody: Array<String> = ["body", "caption", "col", "colgroup", "html"]
    static let InCellTable: Array<String> = ["table", "tbody", "tfoot", "thead", "tr"]
    static let InCellCol: Array<String> = ["caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr"]
    static let InTableEndErr: Array<String> = [
        "body",
        "caption",
        "col",
        "colgroup",
        "html",
        "tbody",
        "td",
        "tfoot",
        "th",
        "thead",
        "tr"
    ]
    static let InTableFoster: Array<String> = ["table", "tbody", "tfoot", "thead", "tr"]
    static let InTableBodyExit: Array<String> = ["caption", "col", "colgroup", "tbody", "tfoot", "thead"]
    static let InTableBodyEndIgnore: Array<String> = ["body", "caption", "col", "colgroup", "html", "td", "th", "tr"]
    static let InRowMissing: Array<String> = ["caption", "col", "colgroup", "tbody", "tfoot", "thead", "tr"]
    static let InRowIgnore: Array<String> = ["body", "caption", "col", "colgroup", "html", "td", "th"]
    static let InSelectEnd: Array<String> = ["input", "keygen", "textarea"]
    static let InSelectTableEnd: Array<String> = ["caption", "table", "tbody", "td", "tfoot", "th", "thead", "tr"]
    static let InTableEndIgnore: Array<String> = ["tbody", "tfoot", "thead"]
    static let InHeadNoscriptIgnore: Array<String> = ["head", "noscript"]
    static let InCaptionIgnore: Array<String> = [
        "body",
        "col",
        "colgroup",
        "html",
        "tbody",
        "td",
        "tfoot",
        "th",
        "thead",
        "tr"
    ]
    static let InTemplateToHead: Array<String> = [
        "base",
        "basefont",
        "bgsound",
        "link",
        "meta",
        "noframes",
        "script",
        "style",
        "template",
        "title"
    ]
    static let InTemplateToTable: Array<String> = ["caption", "colgroup", "tbody", "tfoot", "thead"]
}

let inSorted = StringUtil.inSorted

class Initial <: HtmlTreeBuilderState {
    public func toString(): String {
        "Initial"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            return true // ignore whitespace until we get the first content
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype()) {
            let d = tk.asDoctype()
            let doctype = DocumentType(
                builder.settings().normalizeTag(d.getName()),
                d.getPublicIdentifier(),
                d.getSystemIdentifier()
            )
            doctype.setPubSysKey(d.getPubSysKey())
            builder.getDocument().appendChild(doctype)
            builder.onNodeInserted(doctype, tk)
            if (d.isForceQuirks()) {
                builder.getDocument().quirksMode(QuirksMode.quirks)
            }
            builder.transition(BeforeHtml)
        } else {
            builder.transition(BeforeHtml)
            return builder.process(tk) // re-process token
        }
        return true
    }
}

class BeforeHtml <: HtmlTreeBuilderState {
    public func toString(): String {
        "BeforeHtml"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isDoctype()) {
            builder.error(this)
            return false
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter()) // out of spec - include whitespace
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("html")) {
            builder.insert(tk.asStartTag())
            builder.transition(BeforeHead)
        } else if (tk.isEndTag() && (inSorted(tk.asEndTag().normalName(), Constants.BeforeHtmlToHead))) {
            return anythingElse(tk, builder)
        } else if (tk.isEndTag()) {
            builder.error(this)
            return false
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        builder.insertStartTag("html")
        builder.transition(BeforeHead)
        return builder.process(tk)
    }
}

class BeforeHead <: HtmlTreeBuilderState {
    public func toString(): String {
        "BeforeHead"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter()) // out of spec - include whitespace
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype()) {
            builder.error(this)
            return false
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("html")) {
            return InBody.process(tk, builder) // does not transition
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("head")) {
            let head = builder.insert(tk.asStartTag())
            builder.setHeadElement(head)
            builder.transition(InHead)
        } else if (tk.isEndTag() && (inSorted(tk.asEndTag().normalName(), Constants.BeforeHtmlToHead))) {
            builder.processStartTag("head")
            return builder.process(tk)
        } else if (tk.isEndTag()) {
            builder.error(this)
            return false
        } else {
            builder.processStartTag("head")
            return builder.process(tk)
        }
        return true
    }
}

class InHead <: HtmlTreeBuilderState {
    public func toString(): String {
        "InHead"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter()) // out of spec - include whitespace
            return true
        }
        match (tk.typ) {
            case Some(CommentType) => builder.insert(tk.asComment())
            case Some(DoctypeType) =>
                builder.error(this)
                return false
            case Some(StartTagType) => return processStartTag(tk, builder)
            case Some(EndTagType) => return processEndTag(tk, builder)
            case _ => return anythingElse(tk, builder)
        }
        return true
    }
    private func processStartTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let start = tk.asStartTag()
        let name = start.normalName()
        if (name.equals("html")) {
            return InBody.process(tk, builder)
        } else if (inSorted(name, Constants.InHeadEmpty)) {
            let el = builder.insertEmpty(start)

            // jsoup special: update base the first time it is seen
            if (name.equals("base") && el.hasAttr("href")) { /*cjlint-ignore !G.EXP.03 */
                builder.maybeSetBaseUri(el)
            }
        } else if (name.equals("meta")) {
            builder.insertEmpty(start)
        } else if (name.equals("title")) {
            handleRcData(start, builder)
        } else if (inSorted(name, Constants.InHeadRaw)) {
            handleRawtext(start, builder)
        } else if (name.equals("noscript")) {
            // else if noscript && scripting flag = true: rawtext (jsoup doesn't run script, to handle as noscript)
            builder.insert(start)
            builder.transition(InHeadNoscript)
        } else if (name.equals("script")) {
            // skips some script rules as won't execute them
            builder.tokeniser?.transition(TokeniserState.ScriptData)
            builder.markInsertionMode()
            builder.transition(Text)
            builder.insert(start)
        } else if (name.equals("head")) {
            builder.error(this)
            return false
        } else if (name.equals("template")) {
            builder.insert(start)
            builder.insertMarkerToFormattingElements()
            builder.framesetOk(false)
            builder.transition(InTemplate)
            builder.pushTemplateMode(InTemplate)
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }
    private func processEndTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let end = tk.asEndTag()
        let name = end.normalName()
        if (name.equals("head")) {
            builder.pop()
            builder.transition(AfterHead)
        } else if (inSorted(name, Constants.InHeadEnd)) {
            return anythingElse(tk, builder)
        } else if (name.equals("template")) {
            if (!builder.onStack(name)) {
                builder.error(this)
            } else {
                builder.generateImpliedEndTags(true)
                if (!name.equals(builder.currentElement().normalName())) {
                    builder.error(this)
                }
                builder.popStackToClose(name)
                builder.clearFormattingElementsToLastMarker()
                builder.popTemplateMode()
                builder.resetInsertionMode()
            }
        } else {
            builder.error(this)
            return false
        }
        return true
    }

    private func anythingElse(tk: Token, builder: TreeBuilder): Bool {
        builder.processEndTag("head")
        return builder.process(tk)
    }
}

class InHeadNoscript <: HtmlTreeBuilderState {
    public func toString(): String {
        "InHeadNoscript"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isDoctype()) {
            builder.error(this)
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("html")) {
            return builder.process(tk, InBody)
        } else if (tk.isEndTag() && tk.asEndTag().normalName().equals("noscript")) {
            builder.pop()
            builder.transition(InHead)
        } else if (isWhitespace(tk) || tk.isComment() || (tk.isStartTag() && inSorted(
            tk.asStartTag().normalName(),
            Constants.InHeadNoScriptHead
        ))) {
            return builder.process(tk, InHead)
        } else if (tk.isEndTag() && tk.asEndTag().normalName().equals("br")) {
            return anythingElse(tk, builder)
        } else if ((tk.isStartTag() && inSorted(tk.asStartTag().normalName(), Constants.InHeadNoscriptIgnore)) ||
            tk.isEndTag()) {
            builder.error(this)
            return false
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        // note that this deviates from spec, which is to pop out of noscript and reprocess in head
        // allows content to be inserted as data
        builder.error(this)
        builder.insert(CharacterToken().data(tk.toString()))
        return true
    }
}

class AfterHead <: HtmlTreeBuilderState {
    public func toString(): String {
        "AfterHead"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter())
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype()) {
            builder.error(this)
        } else if (tk.isStartTag()) {
            let startTag = tk.asStartTag()
            let name = startTag.normalName()
            if (name.equals("html")) {
                return builder.process(tk, InBody)
            } else if (name.equals("body")) {
                builder.insert(startTag)
                builder.framesetOk(false)
                builder.transition(InBody)
            } else if (name.equals("frameset")) {
                builder.insert(startTag)
                builder.transition(InFrameset)
            } else if (inSorted(name, Constants.InBodyStartToHead)) {
                builder.error(this)
                let head = builder.getHeadElement()
                builder.push(head)
                builder.process(tk, InHead)
                builder.removeFromStack(head)
            } else if (name.equals("head")) {
                builder.error(this)
                return false
            } else {
                anythingElse(tk, builder)
            }
        } else if (tk.isEndTag()) {
            let name = tk.asEndTag().normalName()
            if (inSorted(name, Constants.AfterHeadBody)) {
                anythingElse(tk, builder)
            } else if (name.equals("template")) {
                builder.process(tk, InHead)
            } else {
                builder.error(this)
                return false
            }
        } else {
            anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        builder.processStartTag("body")
        builder.framesetOk(true)
        return builder.process(tk)
    }
}

class InBody <: HtmlTreeBuilderState {
    public func toString(): String {
        "InBody"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        match (tk.typ) {
            case Some(CharacterType) =>
                let c = tk.asCharacter()
                if (c.getData().equals(nullString)) {
                    builder.error(this)
                    return false
                } else if (builder.framesetOk() && isWhitespace(c)) { // don't check if whitespace if frames already closed
                    builder.reconstructFormattingElements()
                    builder.insert(c)
                } else {
                    builder.reconstructFormattingElements()
                    builder.insert(c)
                    builder.framesetOk(false)
                }
            case Some(CommentType) => builder.insert(tk.asComment())
            case Some(DoctypeType) =>
                builder.error(this)
                return false
            case Some(StartTagType) => return inBodyStartTag(tk, builder)
            case Some(EndTagType) => return inBodyEndTag(tk, builder)
            case Some(EOFType) =>
                if (builder.templateModeSize() > 0) {
                    return builder.process(tk, InTemplate)
                }
            case _ => () // stop parsing
        }
        return true
    }

    private func inBodyStartTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let startTag = tk.asStartTag()
        let name = startTag.normalName()
        match (name) {
            case "a" => return inBodyStartTagA(builder, startTag)
            case "span" => inBodyStartTagSpan(builder, startTag)
            case "li" => return inBodyStartTagLi(builder, startTag)
            case "html" => return inBodyStartTagHtml(builder, startTag)
            case "body" => return inBodyStartTagBody(builder, startTag)
            case "frameset" => return inBodyStartTagFrameset(builder, startTag)
            case "form" => return inBodyStartTagForm(builder, startTag)
            case "plaintext" => inBodyStartTagPlaintext(builder, startTag)
            case "button" => inBodyStartTagButton(builder, startTag)
            case "nobr" => inBodyStartTagNobr(builder, startTag)
            case "table" => inBodyStartTagTable(builder, startTag)
            case "input" => inBodyStartTagInput(builder, startTag)
            case "hr" => inBodyStartTagHr(builder, startTag)
            case "image" => return inBodyStartTagImage(builder, startTag)
            case "isindex" => return inBodyStartTagIsindex(builder, startTag)
            case "textarea" => inBodyStartTagTextarea(builder, startTag)
            case "xmp" => inBodyStartTagXmp(builder, startTag)
            case "iframe" => inBodyStartTagIframe(builder, startTag)
            case "noembed" => handleRawtext(startTag, builder) // also handle noscript if script enabled
            case "select" => return inBodyStartTagSelect(builder, startTag)
            case "math" => inBodyStartTagMath(builder, startTag)
            case "svg" => inBodyStartTagSvg(builder, startTag)
            case "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => inBodyStartTagH1H2H3H4H5H6(builder, startTag)
            case "pre" | "listing" => inBodyStartTagPreListing(builder, startTag)
            case "dd" | "dt" => return inBodyStartTagDddt(builder, startTag)
            case "optgroup" | "option" => inBodyStartTagOptgroupOption(builder, startTag)
            case "rp" | "rt" => return inBodyStartTagRprt(builder, startTag)
            case "area" | "br" | "embed" | "img" | "keygen" | "wbr" => inBodyStartTagAreaBrEmbedImgKeygenWbr(
                builder,
                startTag
            )
            case "b" | "big" | "code" | "em" | "font" | "i" | "s" | "small" | "strike" | "strong" | "tt" | "u" => inBodyStartTagBBigCodeEmFontISSmallStrikeStrongTtU(
                builder, startTag)
            case _ => return inBodyStartTagOther(tk, builder, startTag, name)
        }
        return true
    }
    private func inBodyStartTagA(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        var el: Element
        if (builder.getActiveFormattingElement("a").isSome()) {
            builder.error(this)
            builder.processEndTag("a")

            // still on stack?
            let remainingA = builder.getFromStack("a")
            if (remainingA.isSome()) {
                builder.removeFromActiveFormattingElements(remainingA())
                builder.removeFromStack(remainingA())
            }
        }
        builder.reconstructFormattingElements()
        el = builder.insert(startTag)
        builder.pushActiveFormattingElements(el)
        return true
    }
    private func inBodyStartTagSpan(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        // same as final else, but short circuits lots of checks
        builder.reconstructFormattingElements()
        builder.insert(startTag)
    }
    private func inBodyStartTagLi(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        var stack: ArrayList<Element>
        var el: Element
        builder.framesetOk(false)
        stack = builder.getStack()
        for (i in stack.size - 1..=0 : -1) {
            el = stack[i]
            if (el.normalName().equals("li")) {
                builder.processEndTag("li")
                break
            }
            if (builder.isSpecial(el) && !inSorted(el.normalName(), Constants.InBodyStartLiBreakers)) {
                break
            }
        }
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        builder.insert(startTag)
        return true
    }
    private func inBodyStartTagHtml(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        var stack: ArrayList<Element>
        builder.error(this)
        if (builder.onStack("template")) {
            return false
        } // ignore

        // otherwise, merge attributes onto real html (if present)
        stack = builder.getStack()
        if (stack.size > 0) {
            let html = builder.getStack()[0]
            if (startTag.hasAttributes()) {
                for (attribute in startTag.attributes()) {
                    if (!html.hasAttr(attribute.getKey())) {
                        html.attributes().put(attribute)
                    }
                }
            }
        }
        return true
    }
    private func inBodyStartTagBody(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        var stack: ArrayList<Element>
        builder.error(this)
        stack = builder.getStack()
        if (stack.size == 1 || (stack.size > 2 && !stack[1].normalName().equals("body")) || builder.onStack("template")) { /*cjlint-ignore !G.EXP.03 */
            // only in fragment case
            return false // ignore
        } else {
            builder.framesetOk(false)

            // will be on stack if this is a nested body. won't be if closed (which is a variance from spec, which leaves it on)
            var body: ?Element
            if (startTag.hasAttributes()) { // we only ever put one body on stack
                body = builder.getFromStack("body")
                if (body.isSome()) {
                    for (attribute in startTag.attributes()) {
                        if (!body().hasAttr(attribute.getKey())) {
                            body().attributes().put(attribute)
                        }
                    }
                }
            }
        }
        return true
    }
    private func inBodyStartTagFrameset(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        var stack: ArrayList<Element>
        builder.error(this)
        stack = builder.getStack()
        if (stack.size == 1 || (stack.size > 2 && !stack[1].normalName().equals("body"))) {
            // only in fragment case
            return false // ignore
        } else if (!builder.framesetOk()) {
            return false // ignore frameset
        } else {
            let second = stack[1]
            if (second.parent().isSome()) {
                second.remove()
            }

            // pop up to html element
            while (stack.size > 1) {
                stack.remove(at: stack.size - 1)
            }
            builder.insert(startTag)
            builder.transition(InFrameset)
        }
        return true
    }
    private func inBodyStartTagForm(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        if (builder.getFormElement().isSome() && !builder.onStack("template")) { /*cjlint-ignore !G.EXP.03 */
            builder.error(this)
            return false
        }
        if (builder.inButtonScope("p")) {
            builder.closeElement("p")
        }
        builder.insertForm(startTag, true, true) // won't associate to any template
        return true
    }
    private func inBodyStartTagPlaintext(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        builder.insert(startTag)
        builder.tokeniser?.transition(TokeniserState.PLAINTEXT) // once in, never gets out
    }
    private func inBodyStartTagButton(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.inButtonScope("button")) {
            // close and reprocess
            builder.error(this)
            builder.processEndTag("button")
            builder.process(startTag)
        } else {
            builder.reconstructFormattingElements()
            builder.insert(startTag)
            builder.framesetOk(false)
        }
    }
    private func inBodyStartTagNobr(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        builder.reconstructFormattingElements()
        if (builder.inScope("nobr")) {
            builder.error(this)
            builder.processEndTag("nobr")
            builder.reconstructFormattingElements()
        }
        let el = builder.insert(startTag)
        builder.pushActiveFormattingElements(el)
    }
    private func inBodyStartTagTable(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        let isquirks = match (builder.getDocument().quirksMode()) {
            case QuirksMode.quirks => true
            case _ => false
        }
        if (!isquirks) {
            if (builder.inButtonScope("p")) {
                builder.processEndTag("p")
            }
        }
        builder.insert(startTag)
        builder.framesetOk(false)
        builder.transition(InTable)
    }
    private func inBodyStartTagInput(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        builder.reconstructFormattingElements()
        let el = builder.insertEmpty(startTag)
        if (!el.attr("type").equalsIgnoreCase("hidden")) {
            builder.framesetOk(false)
        }
    }
    private func inBodyStartTagHr(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        builder.insertEmpty(startTag)
        builder.framesetOk(false)
    }
    private func inBodyStartTagImage(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        if (builder.getFromStack("svg").isNone()) {
            return builder.process(startTag.name("img")) // change <image> to <img>, unless in svg
        } else {
            builder.insert(startTag)
        }
        return true
    }
    private func inBodyStartTagIsindex(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        // how much do we care about the early 90s?
        builder.error(this)
        if (builder.getFormElement().isSome()) {
            return false
        }

        builder.processStartTag("form")
        if (startTag.hasAttribute("action")) {
            let form = builder.getFormElement()
            if (form.isSome()) {
                if (startTag.hasAttribute("action")) {
                    let action = startTag.attributes().get("action")
                    form().attributes().put("action", action) // always LC, so don't need to scan up for ownerdoc
                }
            }
        }
        builder.processStartTag("hr")
        builder.processStartTag("label")

        // hope you like english.
        let prompt = if (startTag.hasAttribute("prompt")) {
            startTag.attributes().get("prompt")
        } else {
            "This is a searchable index. Enter search keywords: "
        }

        builder.process(CharacterToken().data(prompt))

        // input
        let inputAttribs = Attributes()
        if (startTag.hasAttributes()) {
            for (attr in startTag.attributes()) {
                if (!inSorted(attr.getKey(), Constants.InBodyStartInputAttribs)) {
                    inputAttribs.put(attr)
                }
            }
        }
        inputAttribs.put("name", "isindex")
        builder.processStartTag("input", inputAttribs)
        builder.processEndTag("label")
        builder.processStartTag("hr")
        builder.processEndTag("form")
        return true
    }
    private func inBodyStartTagTextarea(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        builder.insert(startTag)
        if (!startTag.isSelfClosing()) {
            builder.tokeniser().transition(TokeniserState.Rcdata)
            builder.markInsertionMode()
            builder.framesetOk(false)
            builder.transition(Text)
        }
    }
    private func inBodyStartTagXmp(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        builder.reconstructFormattingElements()
        builder.framesetOk(false)
        handleRawtext(startTag, builder)
    }
    private func inBodyStartTagIframe(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        builder.framesetOk(false)
        handleRawtext(startTag, builder)
    }
    private func inBodyStartTagSelect(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        builder.reconstructFormattingElements()
        builder.insert(startTag)
        builder.framesetOk(false)

        // don't change states if not added to the stack
        if (!startTag.selfClosing) {
            let state = builder.state()
            if (state.refEq(InTable)) {
                builder.transition(InSelectInTable)
            } else if (state.refEq(InCaption)) {
                builder.transition(InSelectInTable)
            } else if (state.refEq(InTableBody)) {
                builder.transition(InSelectInTable)
            } else if (state.refEq(InRow)) {
                builder.transition(InSelectInTable)
            } else if (state.refEq(InCell)) {
                builder.transition(InSelectInTable)
            } else {
                builder.transition(InSelect)
            }
        }
        return true
    }
    private func inBodyStartTagMath(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        builder.reconstructFormattingElements()
        builder.insert(startTag)
    }
    private func inBodyStartTagSvg(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        builder.reconstructFormattingElements()
        builder.insert(startTag)
    }
    private func inBodyStartTagH1H2H3H4H5H6(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        if (inSorted(builder.currentElement().normalName(), Constants.Headings)) {
            builder.error(this)
            builder.pop()
        }
        builder.insert(startTag)
    }
    private func inBodyStartTagPreListing(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        builder.insert(startTag)
        builder.reader?.matchConsume("\n") // ignore LF if next token
        builder.framesetOk(false)
    }
    private func inBodyStartTagDddt(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        var stack: ArrayList<Element>
        var el: Element
        builder.framesetOk(false)
        stack = builder.getStack()
        let bottom = stack.size - 1
        let upper = if (bottom >= MaxStackScan) {
            bottom - MaxStackScan
        } else {
            0
        }
        for (i in bottom..=upper : -1) {
            el = stack[i]
            if (inSorted(el.normalName(), Constants.DdDt)) {
                builder.processEndTag(el.normalName())
                break
            }
            if (builder.isSpecial(el) && !inSorted(el.normalName(), Constants.InBodyStartLiBreakers)) {
                break
            }
        }
        if (builder.inButtonScope("p")) {
            builder.processEndTag("p")
        }
        builder.insert(startTag)
        return true
    }
    private func inBodyStartTagOptgroupOption(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        if (builder.currentElementIs("option")) {
            builder.processEndTag("option")
        }
        builder.reconstructFormattingElements()
        builder.insert(startTag)
    }
    private func inBodyStartTagRprt(builder: HtmlTreeBuilder, startTag: StartTagToken): Bool {
        if (builder.inScope("ruby")) {
            builder.generateImpliedEndTags()
            if (!builder.currentElementIs("ruby")) {
                builder.error(this)
                builder.popStackToBefore("ruby") // i.e. close up to but not include name
            }
            builder.insert(startTag)
        }
        return true
    }
    private func inBodyStartTagAreaBrEmbedImgKeygenWbr(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        // InBodyStartEmptyFormatters:
        builder.reconstructFormattingElements()
        builder.insertEmpty(startTag)
        builder.framesetOk(false)
    }
    private func inBodyStartTagBBigCodeEmFontISSmallStrikeStrongTtU(builder: HtmlTreeBuilder, startTag: StartTagToken): Unit {
        // Formatters:
        builder.reconstructFormattingElements()
        let el = builder.insert(startTag)
        builder.pushActiveFormattingElements(el)
    }
    private func inBodyStartTagOther(tk: Token, builder: HtmlTreeBuilder, startTag: StartTagToken, name: String): Bool {
        if (!Tag.checkKnownTag(name)) { // no special rules for custom tags
            builder.insert(startTag)
        } else if (inSorted(name, Constants.InBodyStartPClosers)) {
            if (builder.inButtonScope("p")) {
                builder.processEndTag("p")
            }
            builder.insert(startTag)
        } else if (inSorted(name, Constants.InBodyStartToHead)) {
            return builder.process(tk, InHead)
        } else if (inSorted(name, Constants.InBodyStartApplets)) {
            builder.reconstructFormattingElements()
            builder.insert(startTag)
            builder.insertMarkerToFormattingElements()
            builder.framesetOk(false)
        } else if (inSorted(name, Constants.InBodyStartMedia)) {
            builder.insertEmpty(startTag)
        } else if (inSorted(name, Constants.InBodyStartDrop)) {
            builder.error(this)
            return false
        } else {
            builder.reconstructFormattingElements()
            builder.insert(startTag)
        }
        return true
    }

    private static let MaxStackScan: Int64 = 24 // used for DD / DT scan, prevents runaway

    private func inBodyEndTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let endTag: EndTagToken = tk.asEndTag()
        let name = endTag.normalName()

        match (name) {
            case "template" => builder.process(tk, InHead)
            case "sarcasm" | "span" => return anyOtherEndTag(tk, builder) // same as final fall through, but saves short circuit
            case "li" => return inBodyEndTagLi(builder, name)
            case "body" => return inBodyEndTagBody(tk, builder)
            case "html" =>
                let notIgnored = builder.processEndTag("body")
                if (notIgnored) {
                    return builder.process(endTag)
                }
            case "form" => return inBodyEndTagForm(builder, name)
            case "p" => return inBodyEndTagP(builder, name, endTag)
            case "dd" | "dt" => return inBodyEndTagDdDt(builder, name)
            case "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => return inBodyEndTagH(builder, name)
            case "br" =>
                builder.error(this)
                builder.processStartTag("br")
                return false
            case _ => return inBodyEndTagOther(tk, builder, name)
        }
        return true
    }
    private func inBodyEndTagLi(builder: HtmlTreeBuilder, name: String): Bool {
        if (!builder.inListItemScope(name)) {
            builder.error(this)
            return false
        } else {
            builder.generateImpliedEndTags(name)
            if (!builder.currentElementIs(name)) {
                builder.error(this)
            }
            builder.popStackToClose(name)
        }
        return true
    }
    private func inBodyEndTagBody(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (!builder.inScope("body")) {
            builder.error(this)
            return false
        } else {
            anyOtherEndTag(tk, builder)
            builder.transition(AfterBody)
        }
        return true
    }
    private func inBodyEndTagP(builder: HtmlTreeBuilder, name: String, endTag: EndTagToken): Bool {
        if (!builder.inButtonScope(name)) {
            builder.error(this)
            builder.processStartTag(name) // if no p to close, creates an empty <p></p>
            return builder.process(endTag)
        } else {
            builder.generateImpliedEndTags(name)
            if (!builder.currentElementIs(name)) {
                builder.error(this)
            }
            builder.popStackToClose(name)
        }
        return true
    }
    private func inBodyEndTagDdDt(builder: HtmlTreeBuilder, name: String): Bool {
        if (!builder.inScope(name)) {
            builder.error(this)
            return false
        } else {
            builder.generateImpliedEndTags(name)
            if (!builder.currentElementIs(name)) {
                builder.error(this)
            }
            builder.popStackToClose(name)
        }
        return true
    }
    private func inBodyEndTagH(builder: HtmlTreeBuilder, name: String): Bool {
        if (!builder.inScope(Constants.Headings)) {
            builder.error(this)
            return false
        } else {
            builder.generateImpliedEndTags(name)
            if (!builder.currentElementIs(name)) {
                builder.error(this)
            }
            builder.popStackToClose(Constants.Headings)
        }
        return true
    }
    private func inBodyEndTagForm(builder: HtmlTreeBuilder, name: String): Bool {
        if (!builder.onStack("template")) {
            let currentForm = builder.getFormElement()
            builder.setFormElement(None)
            if (currentForm.isNone()) {
                builder.error(this)
                return false
            } else if (!builder.inScope(name)) {
                builder.error(this)
                return false
            }
            builder.generateImpliedEndTags()
            if (!builder.currentElementIs(name)) {
                builder.error(this)
            }

            // remove currentForm from stack. will shift anything under up.
            builder.removeFromStack(currentForm())
        } else { // template on stack
            if (!builder.inScope(name)) {
                builder.error(this)
                return false
            }
            builder.generateImpliedEndTags()
            if (!builder.currentElementIs(name)) {
                builder.error(this)
            }
            builder.popStackToClose(name)
        }
        return true
    }
    private func inBodyEndTagOther(tk: Token, builder: HtmlTreeBuilder, name: String): Bool {
        if (inSorted(name, Constants.InBodyEndAdoptionFormatters)) {
            return inBodyEndTagAdoption(tk, builder)
        } else if (inSorted(name, Constants.InBodyEndClosers)) {
            if (!builder.inScope(name)) {
                // nothing to close
                builder.error(this)
                return false
            } else {
                builder.generateImpliedEndTags()
                if (!builder.currentElementIs(name)) {
                    builder.error(this)
                }
                builder.popStackToClose(name)
            }
        } else if (inSorted(name, Constants.InBodyStartApplets)) {
            if (!builder.inScope("name")) {
                if (!builder.inScope(name)) {
                    builder.error(this)
                    return false
                }
                builder.generateImpliedEndTags()
                if (!builder.currentElementIs(name)) {
                    builder.error(this)
                }
                builder.popStackToClose(name)
                builder.clearFormattingElementsToLastMarker()
            }
        } else {
            return anyOtherEndTag(tk, builder)
        }
        return true
    }

    func anyOtherEndTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let name: String = tk.asEndTag().normalName() // case insensitive search - goal is to preserve output case, not for the parse to be case sensitive
        let stack: ArrayList<Element> = builder.getStack()

        // deviate from spec slightly to speed when super deeply nested
        let elFromStack = builder.getFromStack(name)
        if (elFromStack.isNone()) {
            builder.error(this)
            return false
        }

        for (pos in stack.size - 1..=0 : -1) {
            let node = stack[pos]
            if (node.normalName() == name) {
                builder.generateImpliedEndTags(name)
                if (!builder.currentElementIs(name)) {
                    builder.error(this)
                }
                builder.popStackToClose(name)
                break
            } else {
                if (builder.isSpecial(node)) {
                    builder.error(this)
                    return false
                }
            }
        }
        return true
    }

    // Adoption Agency Algorithm.
    private func inBodyEndTagAdoption(tk: Token, builder: HtmlTreeBuilder): Bool {
        let endTag = tk.asEndTag()
        let name = endTag.normalName()

        let stack: ArrayList<Element> = builder.getStack()
        var el: Element
        for (_ in 0..8) {
            let formatEl = builder.getActiveFormattingElement(name)
            if (formatEl.isNone()) {
                return anyOtherEndTag(tk, builder)
            } else if (!builder.onStack(formatEl())) {
                builder.error(this)
                builder.removeFromActiveFormattingElements(formatEl())
                return true
            } else if (!builder.inScope(formatEl().normalName())) {
                builder.error(this)
                return false
            } else if (!builder.currentElement().refEq(formatEl)) {
                builder.error(this)
            }
            var (furthestBlock, commonAncestor, seenFormattingElement): (?Element, ?Element, Bool) = (None, None, false)

            // the spec doesn't limit to < 64, but in degenerate cases (9000+ stack depth) this prevents run-aways
            let stackSize = stack.size
            var bookmark = -1
            for (si in 1..min(stackSize, 64)) {
                el = stack[si]
                if (el.refEq(formatEl)) {
                    commonAncestor = stack.get(si - 1)
                    seenFormattingElement = true

                    // Let a bookmark note the position of the formatting element in the list of active formatting elements relative to the elements on either side of it in the list.
                    bookmark = builder.positionOfElement(el)
                } else if (seenFormattingElement) {
                    if (builder.isSpecial(el)) {
                        furthestBlock = el
                        break
                    }
                }
            }
            if (furthestBlock.isNone()) {
                builder.popStackToClose(formatEl().normalName())
                builder.removeFromActiveFormattingElements(formatEl())
                return true
            }

            var (node, lastNode): (?Element, ?Element) = (furthestBlock, furthestBlock)
            (node, lastNode, bookmark) = loop3(builder, formatEl, furthestBlock, node, lastNode, bookmark)

            afterLoop3(builder, commonAncestor, lastNode, bookmark, formatEl, furthestBlock)
        }
        return true
    }
    private func loop3(
        builder: HtmlTreeBuilder,
        formatEl: ?Element,
        furthestBlock: ?Element,
        nodeTmp: ?Element,
        lastNodeTmp: ?Element,
        bookmarkTmp: Int64
    ): (?Element, ?Element, Int64) {
        var (node, lastNode, bookmark) = (nodeTmp, lastNodeTmp, bookmarkTmp)
        for (_ in 0..3) {
            if (builder.onStack(node())) {
                node = builder.aboveOnStack(node())
            }
            if (!builder.isInActiveFormattingElements(node())) { // note no bookmark check
                builder.removeFromStack(node())
                continue
            } else if (node == formatEl) {
                break
            }
            let replacement = Element(
                builder.tagFor(node().nodeName(), ParseSettings.preserveCase),
                builder.getBaseUri()
            )

            // case will follow the original node (so honours ParseSettings)
            builder.replaceActiveFormattingElement(node(), replacement)
            builder.replaceOnStack(node(), replacement)
            node = replacement

            if (lastNode == furthestBlock) {
                // move the aforementioned bookmark to be immediately after thenode in the list of active formatting elements.
                // not getting how this bookmark both straddles the element above, but is inbetween here...
                bookmark = builder.positionOfElement(node()) + 1
            }
            if (lastNode().parent().isSome()) {
                lastNode?.remove()
            }
            node?.appendChild(lastNode())

            lastNode = node
        }
        return (node, lastNode, bookmark)
    }
    private func afterLoop3(
        builder: HtmlTreeBuilder,
        commonAncestor: ?Element,
        lastNode: ?Element,
        bookmark: Int64,
        formatEl: ?Element,
        furthestBlock: ?Element
    ): Unit {
        if (commonAncestor.isSome()) { // safety check, but would be an error if null
            if (inSorted(commonAncestor().normalName(), Constants.InBodyEndTableFosters)) {
                if (lastNode().parent().isSome()) {
                    lastNode?.remove()
                }
                builder.insertInFosterParent(lastNode())
            } else {
                if (lastNode().parent().isSome()) {
                    lastNode?.remove()
                }
                commonAncestor?.appendChild(lastNode())
            }
        }

        let adopter: Element = Element(formatEl().tag(), builder.getBaseUri())
        adopter.attributes().addAll(formatEl().attributes())
        adopter.appendChildren(furthestBlock().childNodes())
        furthestBlock().appendChild(adopter)
        builder.removeFromActiveFormattingElements(formatEl())

        // insert theelement into the list of active formatting elements at the position of the aforementioned bookmark.
        builder.pushWithBookmark(adopter, bookmark)
        builder.removeFromStack(formatEl())
        builder.insertOnStackAfter(furthestBlock(), adopter)
    }
}

class Text <: HtmlTreeBuilderState {
    public func toString(): String {
        "Text"
    }

    // in script, style etc. normally treated as data tags
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isCharacter()) {
            builder.insert(tk.asCharacter())
        } else if (tk.isEOF()) {
            builder.error(this)

            // if current node is script: already started
            builder.pop()
            builder.transition(builder.originalState())
            return builder.process(tk)
        } else if (tk.isEndTag()) {
            // if: An end tag whose tag name is "script" -- scripting nesting level, if evaluating scripts
            builder.pop()
            builder.transition(builder.originalState())
        }
        return true
    }
}

class InTable <: HtmlTreeBuilderState {
    public func toString(): String {
        "InTable"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isCharacter() && inSorted(builder.currentElement().normalName(), Constants.InTableFoster)) {
            builder.newPendingTableCharacters()
            builder.markInsertionMode()
            builder.transition(InTableText)
            return builder.process(tk)
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
            return true
        } else if (tk.isDoctype()) {
            builder.error(this)
            return false
        } else if (tk.isStartTag()) {
            return processisStartTag(tk, builder)
        } else if (tk.isEndTag()) {
            let endTag = tk.asEndTag()
            let name = endTag.normalName()

            if (name.equals("table")) {
                if (!builder.inTableScope(name)) {
                    builder.error(this)
                    return false
                } else {
                    builder.popStackToClose("table")
                    builder.resetInsertionMode()
                }
            } else if (inSorted(name, Constants.InTableEndErr)) {
                builder.error(this)
                return false
            } else if (name.equals("template")) {
                builder.process(tk, InHead)
            } else {
                return anythingElse(tk, builder)
            }
            return true
        } else if (tk.isEOF()) {
            if (builder.currentElementIs("html")) {
                builder.error(this)
            }
            return true // stops parsing
        }
        return anythingElse(tk, builder)
    }
    private func processisStartTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let startTag = tk.asStartTag()
        let name = startTag.normalName()
        if (name.equals("caption")) {
            builder.clearStackToTableContext()
            builder.insertMarkerToFormattingElements()
            builder.insert(startTag)
            builder.transition(InCaption)
        } else if (name.equals("colgroup")) {
            builder.clearStackToTableContext()
            builder.insert(startTag)
            builder.transition(InColumnGroup)
        } else if (name.equals("col")) {
            builder.clearStackToTableContext()
            builder.processStartTag("colgroup")
            return builder.process(tk)
        } else if (inSorted(name, Constants.InTableToBody)) {
            builder.clearStackToTableContext()
            builder.insert(startTag)
            builder.transition(InTableBody)
        } else if (inSorted(name, Constants.InTableAddBody)) {
            builder.clearStackToTableContext()
            builder.processStartTag("tbody")
            return builder.process(tk)
        } else {
            return processisStartTagOther(tk, builder, startTag, name)
        }
        return true
    }
    private func processisStartTagOther(tk: Token, builder: HtmlTreeBuilder, startTag: StartTagToken, name: String): Bool {
        if (name.equals("table")) {
            builder.error(this)
            if (!builder.inTableScope(name)) { // ignore it
                return false
            } else {
                builder.popStackToClose(name)
                if (!builder.resetInsertionMode()) {
                    // not per spec - but haven't transitioned out of table. so try something else
                    builder.insert(startTag)
                    return true
                }
                return builder.process(tk)
            }
        } else if (inSorted(name, Constants.InTableToHead)) {
            return builder.process(tk, InHead)
        } else if (name.equals("input")) {
            if (!startTag.hasAttributes()) {
                return anythingElse(tk, builder)
            } else if (!startTag.attributes().get("type").equalsIgnoreCase("hidden")) {
                return anythingElse(tk, builder)
            } else {
                builder.insertEmpty(startTag)
            }
        } else if (name.equals("form")) {
            builder.error(this)
            if (builder.getFormElement().isSome() || builder.onStack("template")) { /*cjlint-ignore !G.EXP.03 */
                return false
            } else {
                builder.insertForm(startTag, false, false) // not added to stack. can associate to template
            }
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }

    func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        builder.error(this)
        builder.setFosterInserts(true)
        builder.process(tk, InBody)
        builder.setFosterInserts(false)
        return true
    }
}

class InTableText <: HtmlTreeBuilderState {
    public func toString(): String {
        "InTableText"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.typ == TokenType.CharacterType) {
            let c = tk.asCharacter()
            if (c.getData().equals(nullString)) {
                builder.error(this)
                return false
            } else {
                builder.getPendingTableCharacters().add(c.getData())
            }
        } else {
            if (builder.getPendingTableCharacters().size > 0) {
                for (character in builder.getPendingTableCharacters()) {
                    if (!isWhitespace(character)) {
                        // InTable anything else section:
                        builder.error(this)
                        if (inSorted(builder.currentElement().normalName(), Constants.InTableFoster)) {
                            builder.setFosterInserts(true)
                            builder.process(CharacterToken().data(character), InBody)
                            builder.setFosterInserts(false)
                        } else {
                            builder.process(CharacterToken().data(character), InBody)
                        }
                    } else {
                        builder.insert(CharacterToken().data(character))
                    }
                }
                builder.newPendingTableCharacters()
            }
            builder.transition(builder.originalState())
            return builder.process(tk)
        }
        return true
    }
}

class InCaption <: HtmlTreeBuilderState {
    public func toString(): String {
        "InCaption"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isEndTag() && tk.asEndTag().normalName().equals("caption")) {
            let endTag = tk.asEndTag()
            let name = endTag.normalName()
            if (!builder.inTableScope(name)) {
                builder.error(this)
                return false
            } else {
                builder.generateImpliedEndTags()
                if (!builder.currentElementIs("caption")) {
                    builder.error(this)
                }
                builder.popStackToClose("caption")
                builder.clearFormattingElementsToLastMarker()
                builder.transition(InTable)
            }
        } else if ((tk.isStartTag() && inSorted(tk.asStartTag().normalName(), Constants.InCellCol) || tk.isEndTag() &&
            tk.asEndTag().normalName().equals("table"))) {
            builder.error(this)
            let processed: Bool = builder.processEndTag("caption")
            if (processed) {
                return builder.process(tk)
            }
        } else if (tk.isEndTag() && inSorted(tk.asEndTag().normalName(), Constants.InCaptionIgnore)) {
            builder.error(this)
            return false
        } else {
            return builder.process(tk, InBody)
        }
        return true
    }
}

class InColumnGroup <: HtmlTreeBuilderState {
    public func toString(): String {
        "InColumnGroup"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter())
            return true
        }
        match (tk.typ) {
            case Some(CommentType) => builder.insert(tk.asComment())
            case Some(DoctypeType) => builder.error(this)
            case Some(StartTagType) =>
                let startTag = tk.asStartTag()
                match (startTag.normalName()) {
                    case "html" => return builder.process(tk, InBody)
                    case "col" => builder.insertEmpty(startTag)
                    case "template" => builder.process(tk, InHead)
                    case _ => return anythingElse(tk, builder)
                }
            case Some(EndTagType) =>
                let endTag = tk.asEndTag()
                let name = endTag.normalName()
                match (name) {
                    case "colgroup" =>
                        if (!builder.currentElementIs(name)) {
                            builder.error(this)
                            return false
                        } else {
                            builder.pop()
                            builder.transition(InTable)
                        }
                    case "template" => builder.process(tk, InHead)
                    case _ => return anythingElse(tk, builder)
                }
            case Some(EOFType) =>
                if (builder.currentElementIs("html")) {
                    return true // stop parsing; frag case
                } else {
                    return anythingElse(tk, builder)
                }
            case _ => return anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (!builder.currentElementIs("colgroup")) {
            builder.error(this)
            return false
        }
        builder.pop()
        builder.transition(InTable)
        builder.process(tk)
        return true
    }
}

class InTableBody <: HtmlTreeBuilderState {
    public func toString(): String {
        "InTableBody"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        match (tk.typ) {
            case Some(StartTagType) =>
                let startTag = tk.asStartTag()
                let name = startTag.normalName()
                if (name.equals("tr")) {
                    builder.clearStackToTableBodyContext()
                    builder.insert(startTag)
                    builder.transition(InRow)
                } else if (inSorted(name, Constants.InCellNames)) {
                    builder.error(this)
                    builder.processStartTag("tr")
                    return builder.process(startTag)
                } else if (inSorted(name, Constants.InTableBodyExit)) {
                    return exitTableBody(tk, builder)
                } else {
                    return anythingElse(tk, builder)
                }
            case Some(EndTagType) =>
                let endTag = tk.asEndTag()
                let name = endTag.normalName()
                if (inSorted(name, Constants.InTableEndIgnore)) {
                    if (!builder.inTableScope(name)) {
                        builder.error(this)
                        return false
                    } else {
                        builder.clearStackToTableBodyContext()
                        builder.pop()
                        builder.transition(InTable)
                    }
                } else if (name.equals("table")) {
                    return exitTableBody(tk, builder)
                } else if (inSorted(name, Constants.InTableBodyEndIgnore)) {
                    builder.error(this)
                    return false
                } else {
                    return anythingElse(tk, builder)
                }
            case _ => return anythingElse(tk, builder)
        }
        return true
    }

    private func exitTableBody(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (!builder.inTableScope("tbody")) {
            if (!builder.inTableScope("thead")) {
                if (!builder.inScope("tfoot")) {
                    // frag case
                    builder.error(this)
                    return false
                }
            }
        }
        builder.clearStackToTableBodyContext()
        builder.processEndTag(builder.currentElement().normalName()) // tbody, tfoot, thead
        return builder.process(tk)
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        return builder.process(tk, InTable)
    }
}

class InRow <: HtmlTreeBuilderState {
    public func toString(): String {
        "InRow"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isStartTag()) {
            let startTag = tk.asStartTag()
            let name = startTag.normalName()

            if (inSorted(name, Constants.InCellNames)) {
                builder.clearStackToTableRowContext()
                builder.insert(startTag)
                builder.transition(InCell)
                builder.insertMarkerToFormattingElements()
            } else if (inSorted(name, Constants.InRowMissing)) {
                return handleMissingTr(tk, builder)
            } else {
                return anythingElse(tk, builder)
            }
        } else if (tk.isEndTag()) {
            let endTag = tk.asEndTag()
            let name = endTag.normalName()

            if (name.equals("tr")) {
                if (!builder.inTableScope(name)) {
                    builder.error(this) // frag
                    return false
                }
                builder.clearStackToTableRowContext()
                builder.pop() // tr
                builder.transition(InTableBody)
            } else if (name.equals("table")) {
                return handleMissingTr(tk, builder)
            } else if (inSorted(name, Constants.InTableToBody)) {
                if (!builder.inTableScope(name)) {
                    builder.error(this)
                    return false
                } else if (!builder.inTableScope("tr")) {
                    builder.error(this)
                    return false
                }
                builder.clearStackToTableRowContext()
                builder.pop() // tr
                builder.transition(InTableBody)
            } else if (inSorted(name, Constants.InRowIgnore)) {
                builder.error(this)
                return false
            } else {
                return anythingElse(tk, builder)
            }
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        return builder.process(tk, InTable)
    }

    private func handleMissingTr(tk: Token, builder: TreeBuilder): Bool {
        let processed: Bool = builder.processEndTag("tr")
        if (processed) {
            return builder.process(tk)
        } else {
            return false
        }
    }
}

class InCell <: HtmlTreeBuilderState {
    public func toString(): String {
        "InCell"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isEndTag()) {
            let endTag = tk.asEndTag()
            let name = endTag.normalName()

            if (inSorted(name, Constants.InCellNames)) {
                if (!builder.inTableScope(name)) {
                    builder.error(this)
                    builder.transition(InRow) // might not be in scope if empty: <td /> and processing fake end tag
                    return false
                }
                builder.generateImpliedEndTags()
                if (!builder.currentElementIs(name)) {
                    builder.error(this)
                }
                builder.popStackToClose(name)
                builder.clearFormattingElementsToLastMarker()
                builder.transition(InRow)
            } else if (inSorted(name, Constants.InCellBody)) {
                builder.error(this)
                return false
            } else if (inSorted(name, Constants.InCellTable)) {
                if (!builder.inTableScope(name)) {
                    builder.error(this)
                    return false
                }
                closeCell(builder)
                return builder.process(tk)
            } else {
                return anythingElse(tk, builder)
            }
        } else if (tk.isStartTag() && inSorted(tk.asStartTag().normalName(), Constants.InCellCol)) {
            if (!builder.inTableScope("td")) {
                if (!builder.inTableScope("th")) {
                    builder.error(this)
                    return false
                }
            }
            closeCell(builder)
            return builder.process(tk)
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(tk: Token, builder: HtmlTreeBuilder): Bool {
        return builder.process(tk, InBody)
    }

    private func closeCell(builder: HtmlTreeBuilder): Unit {
        if (builder.inTableScope("td")) {
            builder.processEndTag("td")
        } else {
            builder.processEndTag("th") // only here if th or td in scope
        }
    }
}

class InSelect <: HtmlTreeBuilderState {
    public func toString(): String {
        "InSelect"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        match (tk.typ) {
            case Some(CharacterType) =>
                let c = tk.asCharacter()
                if (c.getData().equals(nullString)) {
                    builder.error(this)
                    return false
                } else {
                    builder.insert(c)
                }
            case Some(CommentType) => builder.insert(tk.asComment())
            case Some(DoctypeType) =>
                builder.error(this)
                return false
            case Some(StartTagType) => return processStartTag(tk, builder)
            case Some(EndTagType) => return processEndTag(tk, builder)
            case Some(EOFType) =>
                if (!builder.currentElementIs("html")) {
                    builder.error(this)
                }
            case _ => return anythingElse(tk, builder)
        }
        return true
    }
    private func processStartTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let start = tk.asStartTag()
        let name = start.normalName()
        if (name.equals("html")) {
            return builder.process(start, InBody)
        } else if (name.equals("option")) {
            if (builder.currentElementIs("option")) {
                builder.processEndTag("option")
            }
            builder.insert(start)
        } else if (name.equals("optgroup")) {
            if (builder.currentElementIs("option")) {
                builder.processEndTag("option") // pop option and flow to pop optgroup
            }
            if (builder.currentElementIs("optgroup")) {
                builder.processEndTag("optgroup")
            }
            builder.insert(start)
        } else if (name.equals("select")) {
            builder.error(this)
            return builder.processEndTag("select")
        } else if (inSorted(name, Constants.InSelectEnd)) {
            builder.error(this)
            if (!builder.inSelectScope("select")) {
                return false // frag
            }
            builder.processEndTag("select")
            return builder.process(start)
        } else if (name.equals("script") || name.equals("template")) {
            return builder.process(tk, InHead)
        } else {
            return anythingElse(tk, builder)
        }
        return true
    }
    private func processEndTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let end = tk.asEndTag()
        let name = end.normalName()
        match (name) {
            case "optgroup" =>
                if (builder.currentElementIs("option") && builder.aboveOnStack(builder.currentElement()).isSome() &&
                    builder.aboveOnStack(builder.currentElement())().normalName().equals("optgroup")) {
                    builder.processEndTag("option")
                }
                if (builder.currentElementIs("optgroup")) {
                    builder.pop()
                } else {
                    builder.error(this)
                }
            case "option" =>
                if (builder.currentElementIs("option")) {
                    builder.pop()
                } else {
                    builder.error(this)
                }
            case "select" =>
                if (!builder.inSelectScope(name)) {
                    builder.error(this)
                    return false
                } else {
                    builder.popStackToClose(name)
                    builder.resetInsertionMode()
                }
            case "template" => return builder.process(tk, InHead)
            case _ => return anythingElse(tk, builder)
        }
        return true
    }

    private func anythingElse(_: Token, builder: HtmlTreeBuilder): Bool {
        builder.error(this)
        return false
    }
}

class InSelectInTable <: HtmlTreeBuilderState {
    public func toString(): String {
        "InSelectInTable"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isStartTag() && inSorted(tk.asStartTag().normalName(), Constants.InSelectTableEnd)) {
            builder.error(this)
            builder.popStackToClose("select")
            builder.resetInsertionMode()
            return builder.process(tk)
        } else if (tk.isEndTag() && inSorted(tk.asEndTag().normalName(), Constants.InSelectTableEnd)) {
            builder.error(this)
            if (builder.inTableScope(tk.asEndTag().normalName())) {
                builder.popStackToClose("select")
                builder.resetInsertionMode()
                return (builder.process(tk))
            } else {
                return false
            }
        } else {
            return builder.process(tk, InSelect)
        }
    }
}

class InTemplate <: HtmlTreeBuilderState {
    public func toString(): String {
        "InTemplate"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        var name: String
        match (tk.typ) {
            case Some(CharacterType) | Some(CommentType) | Some(DoctypeType) => builder.process(tk, InBody)
            case Some(StartTagType) => return processStartTag(tk, builder)
            case Some(EndTagType) =>
                name = tk.asEndTag().normalName()
                if (name.equals("template")) {
                    builder.process(tk, InHead)
                } else {
                    builder.error(this)
                    return false
                }
            case Some(EOFType) =>
                if (!builder.onStack("template")) { // stop parsing
                    return true
                }
                builder.error(this)
                builder.popStackToClose("template")
                builder.clearFormattingElementsToLastMarker()
                builder.popTemplateMode()
                builder.resetInsertionMode()

                // spec deviation - if we did not break out of Template, stop processing, and don't worry about cleaning up ultra-deep template stacks
                // limited depth because this can recurse and will blow stack if too deep
                if (builder.state().refEq(InTemplate) && builder.templateModeSize() < 12) {
                    return builder.process(tk)
                } else {
                    return true
                }
            case _ => ()
        }
        return true
    }
    private func processStartTag(tk: Token, builder: HtmlTreeBuilder): Bool {
        let name = tk.asStartTag().normalName()
        if (inSorted(name, Constants.InTemplateToHead)) {
            builder.process(tk, InHead)
        } else if (inSorted(name, Constants.InTemplateToTable)) {
            builder.popTemplateMode()
            builder.pushTemplateMode(InTable)
            builder.transition(InTable)
            return builder.process(tk)
        } else if (name.equals("col")) {
            builder.popTemplateMode()
            builder.pushTemplateMode(InColumnGroup)
            builder.transition(InColumnGroup)
            return builder.process(tk)
        } else if (name.equals("tr")) {
            builder.popTemplateMode()
            builder.pushTemplateMode(InTableBody)
            builder.transition(InTableBody)
            return builder.process(tk)
        } else if (name.equals("td") || name.equals("th")) {
            builder.popTemplateMode()
            builder.pushTemplateMode(InRow)
            builder.transition(InRow)
            return builder.process(tk)
        } else {
            builder.popTemplateMode()
            builder.pushTemplateMode(InBody)
            builder.transition(InBody)
            return builder.process(tk)
        }
        return true
    }
}

class AfterBody <: HtmlTreeBuilderState {
    public func toString(): String {
        "AfterBody"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter()) // out of spec - include whitespace. spec would move into body
        } else if (tk.isComment()) {
            builder.insert(tk.asComment()) // into html node
        } else if (tk.isDoctype()) {
            builder.error(this)
            return false
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("html")) {
            return builder.process(tk, InBody)
        } else if (tk.isEndTag() && tk.asEndTag().normalName().equals("html")) {
            if (builder.isFragmentParsing()) {
                builder.error(this)
                return false
            } else {
                if (builder.onStack("html")) {
                    builder.popStackToClose("html")
                }
                builder.transition(AfterAfterBody)
            }
        } else if (tk.isEOF()) {
        // chillax! we're done
        } else {
            builder.error(this)
            builder.resetBody()
            return builder.process(tk)
        }
        return true
    }
}

class InFrameset <: HtmlTreeBuilderState {
    public func toString(): String {
        "InFrameset"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter())
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype()) {
            builder.error(this)
            return false
        } else if (tk.isStartTag()) {
            let start = tk.asStartTag()
            match (start.normalName()) {
                case "html" => return builder.process(start, InBody)
                case "frameset" => builder.insert(start)
                case "frame" => builder.insertEmpty(start)
                case "noframes" => return builder.process(start, InHead)
                case _ =>
                    builder.error(this)
                    return false
            }
        } else if (tk.isEndTag() && tk.asEndTag().normalName().equals("frameset")) {
            if (builder.currentElementIs("html")) { // frag
                builder.error(this)
                return false
            } else {
                builder.pop()
                if (!builder.isFragmentParsing() && !builder.currentElementIs("frameset")) {
                    builder.transition(AfterFrameset)
                }
            }
        } else if (tk.isEOF()) {
            if (!builder.currentElementIs("html")) {
                builder.error(this)
                return true
            }
        } else {
            builder.error(this)
            return false
        }
        return true
    }
}

class AfterFrameset <: HtmlTreeBuilderState {
    public func toString(): String {
        "AfterFrameset"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter())
        } else if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype()) {
            builder.error(this)
            return false
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("html")) {
            return builder.process(tk, InBody)
        } else if (tk.isEndTag() && tk.asEndTag().normalName().equals("html")) {
            builder.transition(AfterAfterFrameset)
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("noframes")) {
            return builder.process(tk, InHead)
        } else if (tk.isEOF()) {
        // cool your heels, we're complete
        } else {
            builder.error(this)
            return false
        }
        return true
    }
}

class AfterAfterBody <: HtmlTreeBuilderState {
    public func toString(): String {
        "AfterAfterBody"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype() || (tk.isStartTag() && tk.asStartTag().normalName().equals("html"))) {
            return builder.process(tk, InBody)
        } else if (isWhitespace(tk)) {
            builder.insert(tk.asCharacter())
        } else if (tk.isEOF()) {
        // nice work chuck
        } else {
            builder.error(this)
            builder.resetBody()
            return builder.process(tk)
        }
        return true
    }
}

class AfterAfterFrameset <: HtmlTreeBuilderState {
    public func toString(): String {
        "AfterAfterFrameset"
    }
    protected func process(tk: Token, builder: HtmlTreeBuilder): Bool {
        if (tk.isComment()) {
            builder.insert(tk.asComment())
        } else if (tk.isDoctype() || isWhitespace(tk) || (tk.isStartTag() && tk
            .asStartTag()
            .normalName()
            .equals("html"))) {
            return builder.process(tk, InBody)
        } else if (tk.isEOF()) {
        // nice work chuck
        } else if (tk.isStartTag() && tk.asStartTag().normalName().equals("noframes")) {
            return builder.process(tk, InHead)
        } else {
            builder.error(this)
            return false
        }
        return true
    }
}

class ForeignContent <: HtmlTreeBuilderState {
    public func toString(): String {
        "ForeignContent"
    }
    protected func process(_: Token, _: HtmlTreeBuilder): Bool {
        return true
    }
}
