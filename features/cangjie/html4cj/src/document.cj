/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A HTML Document.
 */
public class Document <: Element & Equatable<Document> {
    private static let titleEval: Evaluator = EvaluatorTag("title")

    private var documentOutputSettings: DocumentOutputSettings = DocumentOutputSettings()

    // the parser used to parse this document
    private var parserValue: Parser

    private var quirksModeValue: QuirksMode = QuirksMode.noQuirks

    private var locationVlaue: String

    private var updateMetaCharset: Bool = false

    /*
       Create a new, empty Document.
     *
     * @param baseUri base URI of document
     */
    public init(baseUri: String) {
        super(Tag.valueOf("#root", ParseSettings.htmlDefault), baseUri)
        this.locationVlaue = baseUri

        // default, but overridable
        this.parserValue = Parser.htmlParser()
    }

    /*
     * Create a valid, empty shell of a document, suitable for adding more elements to.
     *
     * @param baseUri baseUri of document
     * @return document with html, head, and body elements.
     */
    public static func createShell(baseUri: String): Document {
        var doc: Document = Document(baseUri)
        doc.parserValue = doc.parser()
        var html: Element = doc.appendElement("html")
        html.appendElement("head")
        html.appendElement("body")
        return doc
    }

    /*
     * Get the URL this Document was parsed from. If the starting URL is a redirect,
     * this will return the final URL from which the document was served from.
     *
     * @return location
     */
    public func location(): String {
        return locationVlaue
    }

    /*
     * Returns this Document's doctype.
     *
     * @return document type, or null if not set
     */
    public func documentType(): ?DocumentType {
        for (node in childNodesValue) {
            if (node is DocumentType) {
                return (node as DocumentType)()
            } else if (!(node is LeafNode)) {
                break
            }
        }
        return None
    }

    /*
     * Find the root HTML element, or create it if it doesn't exist.
     *
     * @return the root HTML element.
     */
    private func htmlEl(): Element {
        for (el in childElementsList()) {
            if (el.normalName().equals("html")) {
                return el
            }
        }
        return appendElement("html")
    }

    /*
     * Get this document's head element.
     *
     * @return head element.
     */
    public func head(): Element {
        var html: Element = htmlEl()
        for (el in html.childElementsList()) {
            if (el.normalName().equals("head")) {
                return el
            }
        }
        return html.prependElement("head")
    }

    /*
     * Get this document's body or frameset element.
     *
     * @return body element for documents with a body.
     */
    public func body(): Element {
        var html: Element = htmlEl()
        for (el in html.childElementsList()) {
            if ("body".equals(el.normalName()) || "frameset".equals(el.normalName())) {
                return el
            }
        }
        return html.appendElement("body")
    }

    /*
     * Get each of the form elements contained in this document.
     *
     * @return a List of FormElement objects, which will be empty if there are none.
     */
    public func forms(): ArrayList<FormElement> {
        return select("form").forms()
    }

    /*
     * Selects the first FormElement in this document that matches the query.
     *
     * @param cssQuery a Selector CSS query
     * @return the first matching form element
     */
    public func expectForm(cssQuery: String): ?FormElement {
        var els: Elements = select(cssQuery)
        for (el in els.elementArr) {
            match (el) {
                case v: FormElement => return v
                case _ => ()
            }
        }
        Validate.fail("No form elements matched the query '${cssQuery}' in the document.")
        return None
    }

    /*
     * Get the string contents of the document's title element.
     *
     * @return Trimmed title, or empty string if none set.
     */
    public func title(): String {
        // title is a preserve whitespace tag (for document output), but normalised here
        var titleEl: ?Element = head().selectFirst(titleEval)
        if (titleEl != None) {
            return StringUtil.normaliseWhitespace(titleEl().text()).strip()
        } else {
            return ""
        }
    }

    /*
     * Set the document's title element. Updates the existing element, or adds title to head if not present
     *
     * @param title string to set as title
     */
    public func title(title: String): Unit {
        var titleEl: ?Element = head().selectFirst(titleEval)
        if (titleEl == None) {
            // add to head
            titleEl = head().appendElement("title")
        }
        titleEl().text(title)
    }

    /*
     * Create a new Element, with this document's base uri. Does not make the new element a child of this document.
     *
     * @param tagName element tag name
     * @return new element
     */
    public func createElement(tagName: String): Element {
        return Element(Tag.valueOf(tagName, ParseSettings.preserveCase), this.baseUri())
    }

    public override func outerHtml(): String {
        // no outer wrapper tag
        return super.html()
    }

    /*
     * Set the text of the body of this document. Any existing nodes within the body will be cleared.
     *
     * @param text unencoded text
     * @return this document
     */
    public override func text(text: String): Element {
        // overridden to not nuke doc structure
        body().text(text)
        return this
    }

    public override func nodeName(): String {
        return "#document"
    }

    /*
     * Sets the charset used in this document.
     *
     * @param charset Charset
     */
    public func charset(charset: String): Unit {
        updateMetaCharsetElement(true)
        documentOutputSettings.charset(charset)
        ensureMetaCharsetElement()
    }

    /*
     * Returns the charset used in this document.
     *
     * @return Current Charset
     */
    public func charset(): String {
        return documentOutputSettings.charset()
    }

    /*
     * Sets whether the element with charset information in this document is updated on changes through or not.
     *
     * @param update If true the element updated on charset changes,false if not
     */
    public func updateMetaCharsetElement(update: Bool): Unit {
        this.updateMetaCharset = update
    }

    /*
     * Returns whether the element with charset information in this document is updated on changes through or not.
     *
     * @return Returns true if the element is updated on charset changes, false if not
     */
    public func updateMetaCharsetElement(): Bool {
        return updateMetaCharset
    }

    public override func clone(): Document {
        var clone: Document = Document(baseUri())
        clone.documentOutputSettings = this.documentOutputSettings.clone()
        clone.parserValue = this.parserValue
        clone.quirksModeValue = this.quirksModeValue
        clone.updateMetaCharset = this.updateMetaCharset
        clone.locationVlaue = this.locationVlaue
        clone.tagValue = this.tagValue
        var listNode: ArrayList<Node> = ArrayList<Node>()
        for (n in this.childNodesValue) {
            listNode.add(n.clone())
        }
        clone.childNodesValue = listNode
        clone.attributesValue = match (attributesValue) {
            case None => None
            case Some(v) => v.clone()
        }
        clone.siblingIndexInt = this.siblingIndexInt
        return clone
    }

    public override func shallowClone(): Document {
        var clone: Document = Document(baseUri())
        if (attributesValue != None) {
            clone.attributesValue = attributesValue().clone()
        }
        clone.documentOutputSettings = this.documentOutputSettings.clone()
        return clone
    }

    /*
     * Ensures a meta charset (html) or xml declaration (xml) with the current encoding used.
     */
    private func ensureMetaCharsetElement(): Unit {
        if (updateMetaCharset) {
            var syntax: Syntax = outputSettings().syntax()
            if (syntax == Syntax.htmlSyntax) {
                var metaCharset: ?Element = selectFirst("meta[charset]")
                if (metaCharset != None) {
                    metaCharset().attr("charset", charset())
                } else {
                    head().appendElement("meta").attr("charset", charset())
                }

                // Remove obsolete elements
                select("meta[name=charset]").remove()
            } else if (syntax == Syntax.xmlSyntax) {
                var node: Node = ensureChildNodes()[0]
                if (node is XmlDeclaration) {
                    var decl: XmlDeclaration = (node as XmlDeclaration)()
                    if (decl.name().equals("xml")) {
                        decl.attr("encoding", charset())
                        if (decl.hasAttr("version")) {
                            decl.attr("version", "1.0")
                        }
                    } else {
                        decl = XmlDeclaration("xml", false)
                        decl.attr("version", "1.0")
                        decl.attr("encoding", charset())
                        prependChild(decl)
                    }
                } else {
                    var decl: XmlDeclaration = XmlDeclaration("xml", false)
                    decl.attr("version", "1.0")
                    decl.attr("encoding", charset())
                    prependChild(decl)
                }
            }
        }
    }

    /*
     * Get the document's current output settings.
     *
     * @return the document's current output settings.
     */
    public func outputSettings(): DocumentOutputSettings {
        return documentOutputSettings
    }

    /*
     * Set the document's output settings.
     *
     * @param outputSettings new output settings.
     * @return this document, for chaining.
     */
    public func outputSettings(documentOutputSettings: DocumentOutputSettings): Document {
        this.documentOutputSettings = documentOutputSettings
        return this
    }

    public func quirksMode(): QuirksMode {
        return quirksModeValue
    }

    public func quirksMode(quirksModeValue: QuirksMode): Document {
        this.quirksModeValue = quirksModeValue
        return this
    }

    /*
     * Get the parser that was used to parse this document.
     *
     * @return the parser
     */
    public func parser(): Parser {
        return parserValue
    }

    /*
     * Set the parser used to create this document. This parser is then used when further parsing within this document is required.
     *
     * @param parser the configured parser to use when further parsing is required for this document.
     * @return this document, for chaining.
     */
    public func parser(parserValue: Parser): Document {
        this.parserValue = parserValue
        return this
    }

    public operator func !=(that: Document): Bool {
        return !(this == that)
    }

    public operator func ==(that: Document): Bool {
        return refEq(this, that)
    }
}

public enum QuirksMode <: Equatable<QuirksMode> & ToString {
    | noQuirks
    | quirks
    | limitedQuirks

    public operator func ==(that: QuirksMode): Bool {
        match ((this, that)) {
            case (noQuirks, noQuirks) => true
            case (quirks, quirks) => true
            case (limitedQuirks, limitedQuirks) => true
            case _ => false
        }
    }

    public operator func !=(that: QuirksMode): Bool {
        return !(this == that)
    }

    public func toString(): String {
        return match (this) {
            case noQuirks => "noQuirks"
            case quirks => "quirks"
            case limitedQuirks => "limitedQuirks"
        }
    }
}

public enum Syntax <: Equatable<Syntax> & ToString {
    | htmlSyntax
    | xmlSyntax

    public operator func ==(that: Syntax): Bool {
        match ((this, that)) {
            case (htmlSyntax, htmlSyntax) => true
            case (xmlSyntax, xmlSyntax) => true
            case _ => false
        }
    }

    public operator func !=(that: Syntax): Bool {
        return !(this == that)
    }

    public func toString(): String {
        return match (this) {
            case htmlSyntax => "htmlSyntax"
            case xmlSyntax => "xmlSyntax"
        }
    }
}

public class DocumentOutputSettings {
    private var escapeModeValue: EscapeMode = EscapeMode.base

    private var charsetValue: String = "UTF-8"

    // fast encoders for ascii and utf8
    var coreCharset: CoreCharset = CoreCharset.utf

    private var prettyPrintValue: Bool = true

    private var outlineValue: Bool = false

    private var indentAmountValue: Int64 = 1

    private var maxPaddingWidthValue: Int64 = 30

    private var syntaxValue: Syntax = Syntax.htmlSyntax

    public init() {}

    /*
     * Get the document's current HTML escape mode
     *
     * @return the document's current escape mode
     */
    public func escapeMode(): EscapeMode {
        return escapeModeValue
    }

    /*
     * Set the document's escape mode, which determines how characters are escaped when the output character set
     * does not support a given character:- using either a named or a numbered escape.
     *
     * @param escapeMode the new escape mode to use
     * @return the document's output settings, for chaining
     */
    public func escapeMode(escapeModeValue: EscapeMode): DocumentOutputSettings {
        this.escapeModeValue = escapeModeValue
        return this
    }

    /*
     * Get the document's current output charset
     *
     * @return the document's current charset.
     */
    public func charset(): String {
        return charsetValue
    }

    /*
     * Update the document's output charset.
     * just utf8 ascii
     *
     * @param charset the new charset (by name) to use.
     * @return the document's output settings, for chaining
     */
    public func charset(coreCharset: String): DocumentOutputSettings {
        this.coreCharset = CoreCharset.byName(coreCharset)
        this.charsetValue = match (coreCharset.toAsciiUpper()) {
            case "UTF-8" => "UTF-8"
            case "ASCII" => "ASCII"
            case _ => "UTF-8"
        }
        return this
    }

    /*
     * Get the document's current output syntax.
     *
     * @return current syntax
     */
    public func syntax(): Syntax {
        return syntaxValue
    }

    /*
     * Set the document's output syntax.
     *
     * @param syntax serialization syntax
     * @return the document's output settings, for chaining
     */
    public func syntax(syntaxValue: Syntax): DocumentOutputSettings {
        this.syntaxValue = syntaxValue
        return this
    }

    /*
     * Get if pretty printing is enabled. Default is true. If disabled, the HTML output methods will not re-format
     * the output, and the output will generally look like the input.
     *
     * @return if pretty printing is enabled.
     */
    public func prettyPrint(): Bool {
        return prettyPrintValue
    }

    /*
     * Enable or disable pretty printing.
     *
     * @param pretty new pretty print setting
     * @return this, for chaining
     */
    public func prettyPrint(prettyPrintValue: Bool): DocumentOutputSettings {
        this.prettyPrintValue = prettyPrintValue
        return this
    }

    /*
     * Get if outline mode is enabled. Default is false. If enabled, the HTML output methods will consider all tags as block.
     *
     * @return if outline mode is enabled.
     */
    public func outline(): Bool {
        return outlineValue
    }

    /*
     * Enable or disable HTML outline mode.
     *
     * @param outlineMode new outline setting
     * @return this, for chaining
     */
    public func outline(outlineMode: Bool): DocumentOutputSettings {
        outlineValue = outlineMode
        return this
    }

    /*
     * Get the current tag indent amount, used when pretty printing.
     *
     * @return the current indent amount
     */
    public func indentAmount(): Int64 {
        return indentAmountValue
    }

    /*
     * Set the indent amount for pretty printing
     *
     * @param indentAmount number of spaces to use for indenting each level.
     * @return this, for chaining
     */
    public func indentAmount(indentAmount: Int64): DocumentOutputSettings {
        Validate.isTrue(indentAmount >= 0)
        this.indentAmountValue = indentAmount
        return this
    }

    /*
     * Get the current max padding amount, used when pretty printing so very deeply nested nodes don't get insane padding amounts.
     *
     * @return the current indent amount
     */
    public func maxPaddingWidth(): Int64 {
        return maxPaddingWidthValue
    }

    /*
     * Set the max padding amount for pretty printing so very deeply nested nodes don't get insane padding amounts.
     *
     * @param maxPaddingWidth number of spaces to use for indenting each level of nested nodes.
     * @return this, for chaining
     */
    public func maxPaddingWidth(maxPaddingWidthValue: Int64): DocumentOutputSettings {
        Validate.isTrue(maxPaddingWidthValue >= -1)
        this.maxPaddingWidthValue = maxPaddingWidthValue
        return this
    }

    public func clone(): DocumentOutputSettings {
        var clone: DocumentOutputSettings = DocumentOutputSettings()

        // new charset and charset encoder
        clone.charsetValue = this.charsetValue
        clone.escapeModeValue = this.escapeModeValue
        clone.coreCharset = this.coreCharset
        clone.prettyPrintValue = this.prettyPrintValue
        clone.outlineValue = this.outlineValue
        clone.indentAmountValue = this.indentAmountValue
        clone.maxPaddingWidthValue = this.maxPaddingWidthValue
        clone.syntaxValue = this.syntaxValue

        // indentAmount, maxPaddingWidth, and prettyPrint are primitives so object.clone() will handle
        return clone
    }
}
