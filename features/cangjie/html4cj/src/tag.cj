/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * HTML capabilities:Tag.
 */
public class Tag <: Equatable<Tag> & ToString & Hashable {
    // internal static initialisers
    private static let blockTags: Array<String> = [
        "html",
        "head",
        "body",
        "frameset",
        "script",
        "noscript",
        "style",
        "meta",
        "link",
        "title",
        "frame",
        "noframes",
        "section",
        "nav",
        "aside",
        "hgroup",
        "header",
        "footer",
        "p",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "ul",
        "ol",
        "pre",
        "div",
        "blockquote",
        "hr",
        "address",
        "figure",
        "figcaption",
        "form",
        "fieldset",
        "ins",
        "del",
        "dl",
        "dt",
        "dd",
        "li",
        "table",
        "caption",
        "thead",
        "tfoot",
        "tbody",
        "colgroup",
        "col",
        "tr",
        "th",
        "td",
        "video",
        "audio",
        "canvas",
        "details",
        "menu",
        "plaintext",
        "template",
        "article",
        "main",
        "svg",
        "math",
        "center",
        "template",
        "dir",
        "applet",
        "marquee",
        "listing" // deprecated but still known / special handling
    ]

    private static let inlineTags: Array<String> = [
        "object",
        "base",
        "font",
        "tt",
        "i",
        "b",
        "u",
        "big",
        "small",
        "em",
        "strong",
        "dfn",
        "code",
        "samp",
        "kbd",
        "var",
        "cite",
        "abbr",
        "time",
        "acronym",
        "mark",
        "ruby",
        "rt",
        "rp",
        "a",
        "img",
        "br",
        "wbr",
        "map",
        "q",
        "sub",
        "sup",
        "bdo",
        "iframe",
        "embed",
        "span",
        "input",
        "select",
        "textarea",
        "label",
        "button",
        "optgroup",
        "option",
        "legend",
        "datalist",
        "keygen",
        "output",
        "progress",
        "meter",
        "area",
        "param",
        "source",
        "track",
        "summary",
        "command",
        "device",
        "area",
        "basefont",
        "bgsound",
        "menuitem",
        "param",
        "source",
        "track",
        "data",
        "bdi",
        "s",
        "strike",
        "nobr"
    ]

    private static let emptyTags: Array<String> = [
        "meta",
        "link",
        "base",
        "frame",
        "img",
        "br",
        "wbr",
        "embed",
        "hr",
        "input",
        "keygen",
        "col",
        "command",
        "device",
        "area",
        "basefont",
        "bgsound",
        "menuitem",
        "param",
        "source",
        "track"
    ]

    // can rework this to format contents as inline; and update html emitter in Element. Same output, just neater.
    private static let formatAsInlineTags: Array<String> = [
        "title",
        "a",
        "p",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "pre",
        "address",
        "li",
        "th",
        "td",
        "script",
        "style",
        "ins",
        "del",
        "s"
    ]

    // script is not here as it is a data node, which always preserve whitespace
    private static let preserveWhitespaceTags: Array<String> = ["pre", "plaintext", "title", "textarea"]

    // can just need submit tags, and can scrub listed
    private static let formListedTags: Array<String> = [
        "button",
        "fieldset",
        "input",
        "keygen",
        "object",
        "output",
        "select",
        "textarea"
    ]

    private static let formSubmitTags: Array<String> = ["input", "keygen", "object", "select", "textarea"]

    // map of known tags
    private static let tags: HashMap<String, Tag> = initTags()

    private var tagName: String

    // always the lower case version of this tag, regardless of case preservation mode
    private var normalNameValue: String

    // block
    private var isBlockValue: Bool = true

    // should be formatted as a block
    private var formatAsBlockValue: Bool = true

    // can hold nothing; e.g. img
    private var empty: Bool = false

    // can self close (<foo />). used for unknown tags that self close, without forcing them as empty.
    private var selfClosing: Bool = false

    // for pre, textarea, script etc
    private var preserveWhitespaceValue: Bool = false

    // a control that appears in forms: input, textarea, output etc
    private var formList: Bool = false

    // a control that can be submitted in a form: input etc
    private var formSubmit: Bool = false

    private init(tagName: String) {
        this.tagName = tagName
        normalNameValue = Normalizer.lowerCase(tagName)
    }

    /*
     * Get this tag's name.
     *
     * @return the tag's name
     */
    public func getName(): String {
        return tagName
    }

    /*
     * Get this tag's normalized (lowercased) name.
     *
     * @return the tag's normal name.
     */
    public func normalName(): String {
        return normalNameValue
    }

    /*
     * Get a Tag by name. If not previously defined (unknown), returns a new generic tag, that can do anything.
     * Pre-defined tags (P, DIV etc) will be refEq, but unknown tags are not registered and will only ==.
     *
     * @param tagName Name of tag, e.g. "p". Case insensitive.
     * @param settings used to control tag name sensitivity
     * @return The tag, either defined or new generic.
     */
    public static func valueOf(tagName: String, settings: ParseSettings): Tag {
        var tag: Option<Tag> = tags.get(tagName)
        if (tag == None) {
            // the name we'll use
            let tagName = settings.normalizeTag(tagName)
            Validate.notEmpty(tagName)

            // the lower-case name to get tag settings off
            let normalName: String = Normalizer.lowerCase(tagName)
            tag = tags.get(normalName)

            if (tag == None) {
                // not defined: create default; go anywhere, do anything! (incl be inside a <p>)
                tag = Tag(tagName)
                tag?.isBlockValue = false
            } else if (settings.preserveTagCase() && !tagName.equals(normalName)) {
                // get a new version vs the static one, so name update doesn't reset all
                tag = tag?.clone()
                tag?.tagName = tagName
            }
        }
        return tag()
    }

    /*
     * Get a Tag by name. If not previously defined (unknown), returns a new generic tag, that can do anything.
     * Pre-defined tags (P, DIV etc) will be refEq, but unknown tags are not registered and will only ==.
     *
     * @param tagName Name of tag, e.g. "p". <b>Case sensitive</b>.
     * @return The tag, either defined or new generic.
     */
    public static func valueOf(tagName: String): Tag {
        return valueOf(tagName, ParseSettings.preserveCase)
    }

    /*
     * Gets if this is a block tag.
     *
     * @return if block tag
     */
    public func isBlock(): Bool {
        return isBlockValue
    }

    /*
     * Gets if this tag should be formatted as a block (or as inline)
     *
     * @return if should be formatted as block or inline
     */
    public func formatAsBlock(): Bool {
        return formatAsBlockValue
    }

    /*
     * Gets if this tag is an inline tag.
     *
     * @return if this tag is an inline tag.
     */
    public func isInline(): Bool {
        return !isBlockValue
    }

    /*
     * Get if this is an empty tag
     *
     * @return if this is an empty tag
     */
    public func isEmpty(): Bool {
        return empty
    }

    /*
     * Get if this tag is self closing.
     *
     * @return if this tag should be output as self closing.
     */
    public func isSelfClosing(): Bool {
        return empty || selfClosing
    }

    /*
     * Get if this is a pre-defined tag, or was auto created on parsing.
     *
     * @return if a known tag
     */
    public func isKnownTag(): Bool {
        return tags.contains(tagName)
    }

    /*
     * Check if this tagname is a known tag.
     *
     * @param tagName name of tag
     * @return if known HTML tag
     */
    public static func checkKnownTag(tagName: String): Bool {
        return tags.contains(tagName)
    }

    /*
     * Get if this tag should preserve whitespace within child text nodes.
     *
     * @return if preserve whitespace
     */
    public func preserveWhitespace(): Bool {
        return preserveWhitespaceValue
    }

    /*
     * Get if this tag represents a control associated with a form. E.g. input, textarea, output
     *
     * @return if associated with a form
     */
    public func isFormListed(): Bool {
        return formList
    }

    /*
     * Get if this tag represents an element that should be submitted with a form. E.g. input, option
     *
     * @return if submittable with a form
     */
    public func isFormSubmittable(): Bool {
        return formSubmit
    }

    func setSelfClosing(): Tag {
        selfClosing = true
        return this
    }

    public operator override func ==(tag: Tag): Bool {
        if (refEq(this, tag)) {
            return true
        } else if (tagName != tag.tagName) {
            return false
        } else if (empty != tag.empty) {
            return false
        } else if (formatAsBlockValue != tag.formatAsBlockValue) {
            return false
        } else if (isBlockValue != tag.isBlockValue) {
            return false
        } else if (preserveWhitespaceValue != tag.preserveWhitespaceValue) {
            return false
        } else if (selfClosing != tag.selfClosing) {
            return false
        } else if (formList != tag.formList) {
            return false
        }
        return formSubmit == tag.formSubmit
    }

    public operator override func !=(tag: Tag): Bool {
        !(this == tag)
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        var result = tagName.hashCode()
        result = 31 * result + isBlockValue.hashCode()
        result = 31 * result + formatAsBlockValue.hashCode()
        result = 31 * result + empty.hashCode()
        result = 31 * result + selfClosing.hashCode()
        result = 31 * result + preserveWhitespaceValue.hashCode()
        result = 31 * result + formList.hashCode()
        result = 31 * result + formSubmit.hashCode()
        return result
    }

    public func toString(): String {
        return tagName
    }

    protected func clone(): Tag {
        let tag = Tag(tagName)
        tag.normalNameValue = normalNameValue
        tag.isBlockValue = isBlockValue
        tag.formatAsBlockValue = formatAsBlockValue
        tag.empty = empty
        tag.selfClosing = selfClosing
        tag.preserveWhitespaceValue = preserveWhitespaceValue
        tag.formList = formList
        tag.formSubmit = formSubmit
        return tag
    }

    private static func initTags(): HashMap<String, Tag> {
        let tags = HashMap<String, Tag>()

        //  creates
        for (tagName in blockTags) {
            let tag: Tag = Tag(tagName)
            tags.add(tag.tagName, tag)
        }
        for (tagName in inlineTags) {
            let tag: Tag = Tag(tagName)
            tag.isBlockValue = false
            tag.formatAsBlockValue = false
            tags.add(tag.tagName, tag)
        }

        // mods:
        for (tagName in emptyTags) {
            tags.get(tagName)().empty = true
        }
        for (tagName in formatAsInlineTags) {
            tags.get(tagName)().formatAsBlockValue = false
        }
        for (tagName in preserveWhitespaceTags) {
            tags.get(tagName)().preserveWhitespaceValue = true
        }
        for (tagName in formListedTags) {
            tags.get(tagName)().formList = true
        }
        for (tagName in formSubmitTags) {
            tags.get(tagName)().formSubmit = true
        }
        return tags
    }
}
