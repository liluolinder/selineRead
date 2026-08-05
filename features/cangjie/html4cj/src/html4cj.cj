/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * The core public access point to the Html4cj functionality.
 */
public class Html4cj {
    private init() {}

    /*
     * Parse HTML into a Document. The parser will make a sensible, balanced document tree out of any HTML.
     *
     * @param html    HTML to parse
     * @param baseUri The URL where the HTML was retrieved from.
     * @return sane HTML
     */
    public static func parse(html: String, baseUri: String): Document {
        return Parser.parse(html, baseUri)
    }

    /*
     * Parse HTML into a Document, using the provided Parser.
     *
     * @param html    HTML to parse
     * @param baseUri The URL where the HTML was retrieved from.
     * @param parser alternate Parser.xmlParser().parser to use.
     * @return sane HTML
     */
    public static func parse(html: String, baseUri: String, parser: Parser): Document {
        return parser.parseInput(html, baseUri)
    }

    /*
     * Parse HTML into a Document, using the provided Parser
     *
     * @param html    HTML to parse
     * @param parser alternate Parser#xmlParser() parser to use.
     * @return sane HTML
     */
    public static func parse(html: String, parser: Parser): Document {
        return parser.parseInput(html, "")
    }

    /*
     * Parse HTML into a Document.
     *
     * @param html HTML to parse
     * @return sane HTML
     */
    public static func parse(html: String): Document {
        return Parser.parse(html, "")
    }

    /*
     * Parse a fragment of HTML, with the assumption that it forms the body of the HTML.
     *
     * @param bodyHtml body HTML fragment
     * @param baseUri  URL to resolve relative URLs against.
     * @return sane HTML document
     */
    public static func parseBodyFragment(bodyHtml: String, baseUri: String): Document {
        return Parser.parseBodyFragment(bodyHtml, baseUri)
    }

    /*
     * Parse a fragment of HTML, with the assumption that it forms the body of the HTML.
     *
     * @param bodyHtml body HTML fragment
     * @return sane HTML document
     */
    public static func parseBodyFragment(bodyHtml: String): Document {
        return Parser.parseBodyFragment(bodyHtml, "")
    }
}
