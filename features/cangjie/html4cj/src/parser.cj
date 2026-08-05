/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Parses HTML into a Document. Generally best to use one of the more convenient parse methods in Html4cj.
 */
public class Parser {
    private var treeBuilder: TreeBuilder
    private var errors: ParseErrorList
    private var _settings: ParseSettings
    private var trackPosition: Bool = false

    /*
     * Create a new Parser, using the specified TreeBuilder
     * @param treeBuilder to:TreeBuilder use to parse input into Documents.
     */
    init(treeBuilder: TreeBuilder) {
        this.treeBuilder = treeBuilder
        _settings = treeBuilder.defaultSettings()
        errors = ParseErrorList.noTracking()
    }

    private init(copy: Parser) {
        treeBuilder = copy.treeBuilder.newInstance() // because extended
        errors = ParseErrorList(copy.errors) // only copies size, not contents
        _settings = ParseSettings(copy._settings)
        trackPosition = copy.trackPosition
    }

    /*
       Creates a new Parser as a deep copy of this; including initializing a new TreeBuilder. Allows independent (multi-threaded) use.
       @return a copied parser
     */
    public func newInstance(): Parser {
        return Parser(this)
    }

    public func parseInput(html: String, baseUri: String): Document {
        return treeBuilder.parse(StringReader(html), baseUri, this)
    }

    public func parseFragmentInput(fragment: String, context: ?Element, baseUri: String): ArrayList<Node> {
        return treeBuilder.parseFragment(fragment, context, baseUri, this)
    }

    // gets & sets
    /*
     * Get the currently:TreeBuilder in use.
     * @return current TreeBuilder.
     */
    func getTreeBuilder(): TreeBuilder {
        return treeBuilder
    }

    /*
     * Check if parse error tracking is enabled.
     * @return current track error state.
     */
    public func isTrackErrors(): Bool {
        return errors.getMaxSize() > 0
    }

    /*
     * Enable or disable parse error tracking for the next parse.
     * @param maxErrors the maximum number of errors to track. Set to 0 to disable.
     * @return this, for chaining
     */
    public func setTrackErrors(maxErrors: Int64): Parser {
        errors = if (maxErrors > 0) {
            ParseErrorList.tracking(maxErrors)
        } else {
            ParseErrorList.noTracking()
        }
        return this
    }

    /*
     * Retrieve the parse errors, if any, from the last parse.
     * @return list of parse errors, up to the size of the maximum errors tracked.
     * @see #setTrackErrors(int)
     */
    public func getErrors(): ParseErrorList {
        return errors
    }

    /*
       Test if position tracking is enabled. If it is, Nodes will have a Position to track where in the original input
       source they were created from. By default, tracking is not enabled.
     * @return current track position setting
     */
    public func isTrackPosition(): Bool {
        return trackPosition
    }

    /*
       Enable or disable source position tracking. If enabled, Nodes will have a Position to track where in the original
       input source they were created from.
       @param trackPosition position tracking setting; true to enable
       @return this Parser, for chaining
     */
    public func setTrackPosition(trackPosition: Bool): Parser {
        this.trackPosition = trackPosition
        return this
    }

    /*
       Update the ParseSettings of this Parser, to control the case sensitivity of tags and attributes.
     * @param settings the new settings
     * @return this Parser
     */
    public func settings(settings: ParseSettings): Parser {
        this._settings = settings
        return this
    }

    /*
       Gets the current ParseSettings for this Parser
     * @return current ParseSettings
     */
    public func settings(): ParseSettings {
        return _settings
    }

    /*
       (An internal method, visible for Element. For HTML parse, signals that script and style text should be treated as
       Data Nodes).
     */
    func isContentForTagData(normalName: String): Bool {
        return getTreeBuilder().isContentForTagData(normalName)
    }

    // static parse functions below
    /*
     * Parse HTML into a Document.
     *
     * @param html HTML to parse
     * @param baseUri base URI of document (i.e. original fetch location), for resolving relative URLs.
     *
     * @return parsed Document
     */
    public static func parse(html: String, baseUri: String): Document {
        let treeBuilder: TreeBuilder = HtmlTreeBuilder()
        return treeBuilder.parse(StringReader(html), baseUri, Parser(treeBuilder))
    }

    /*
     * Parse a fragment of HTML into a list of nodes. The context element, if supplied, supplies parsing context.
     *
     * @param fragmentHtml the fragment of HTML to parse
     * @param context (optional) the element that this HTML fragment is being parsed for (i.e. for inner HTML). This
     * provides stack context (for implicit element creation).
     * @param baseUri base URI of document (i.e. original fetch location), for resolving relative URLs.
     *
     * @return list of nodes parsed from the input HTML. Note that the context element, if supplied, is not modified.
     */
    public static func parseFragment(fragmentHtml: String, context: ?Element, baseUri: String): ArrayList<Node> {
        let treeBuilder: HtmlTreeBuilder = HtmlTreeBuilder()
        return treeBuilder.parseFragment(fragmentHtml, context, baseUri, Parser(treeBuilder))
    }

    /*
     * Parse a fragment of HTML into a list of nodes. The context element, if supplied, supplies parsing context.
     *
     * @param fragmentHtml the fragment of HTML to parse
     * @param context (optional) the element that this HTML fragment is being parsed for (i.e. for inner HTML). This
     * provides stack context (for implicit element creation).
     * @param baseUri base URI of document (i.e. original fetch location), for resolving relative URLs.
     * @param errorList list to add errors to
     *
     * @return list of nodes parsed from the input HTML. Note that the context element, if supplied, is not modified.
     */
    public static func parseFragment(fragmentHtml: String, context: ?Element, baseUri: String, errorList: ParseErrorList): ArrayList<Node> {
        let treeBuilder: HtmlTreeBuilder = HtmlTreeBuilder()
        let parser: Parser = Parser(treeBuilder)
        parser.errors = errorList
        return treeBuilder.parseFragment(fragmentHtml, context, baseUri, parser)
    }

    /*
     * Parse a fragment of XML into a list of nodes.
     *
     * @param fragmentXml the fragment of XML to parse
     * @param baseUri base URI of document (i.e. original fetch location), for resolving relative URLs.
     * @return list of nodes parsed from the input XML.
     */
    public static func parseXmlFragment(fragmentXml: String, baseUri: String): ArrayList<Node> {
        let treeBuilder: XmlTreeBuilder = XmlTreeBuilder()
        return treeBuilder.parseFragment(fragmentXml, baseUri, Parser(treeBuilder))
    }

    /*
     * Parse a fragment of HTML into the body of a Document.
     *
     * @param bodyHtml fragment of HTML
     * @param baseUri base URI of document (i.e. original fetch location), for resolving relative URLs.
     * @return Document, with empty head, and HTML parsed into body
     */
    public static func parseBodyFragment(bodyHtml: String, baseUri: String): Document {
        let doc: Document = Document.createShell(baseUri)
        let body: Element = doc.body()
        let nodeList: ArrayList<Node> = parseFragment(bodyHtml, body, baseUri)
        let nodes: Array<Node> = nodeList |> collectArray // the node list gets modified when re-parented
        for (i in nodes.size - 1..=0 : -1) {
            nodes[i].remove()
        }
        for (node in nodes) {
            body.appendChild(node)
        }
        return doc
    }

    /*
     * Utility method to unescape HTML entities from a string
     * @param string HTML escaped string
     * @param inAttribute if the string is to be escaped in strict mode (as attributes are)
     * @return an unescaped string
     */
    public static func unescapeEntities(string: String, inAttribute: Bool): String {
        let tokeniser: Tokeniser = Tokeniser(CharacterReader(string), ParseErrorList.noTracking())
        return tokeniser.unescapeEntities(inAttribute)
    }

    /*
     * Create a new HTML parser. This parser treats input as HTML5, and enforces the creation of a normalised document,
     * based on a knowledge of the semantics of the incoming tags.
     * @return a new HTML parser.
     */
    public static func htmlParser(): Parser {
        return Parser(HtmlTreeBuilder())
    }

    /*
     * Create a new XML parser. This parser assumes no knowledge of the incoming tags and does not treat it as HTML,
     * rather creates a simple tree directly from the input.
     * @return a new simple XML parser.
     */
    public static func xmlParser(): Parser {
        return Parser(XmlTreeBuilder())
    }
}
