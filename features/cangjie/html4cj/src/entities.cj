/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * HTML entities, and escape routines. Source: HTML named character references.
 */
class Entities {
    static let empty: Int64 = -1

    static let emptyName: String = ""

    // static let codepointRadix: Int64 = 36

    private static let codeDelims: Array<Rune> = [r',', r';']

    // name -> multiple character references
    private static let multipoints: HashMap<String, String> = HashMap<String, String>()

    private static let defaultOutput: DocumentOutputSettings = DocumentOutputSettings()

    static let xhtmlData = Entities.load(EntitiesData.xmlPoints, 4)

    static let baseData = Entities.load(EntitiesData.basePoints, 106)

    static let extendedData = Entities.load(EntitiesData.fullPoints, 2125)

    private init() {}

    /*
     * Check if the input is a known named entity
     *
     * @param name the possible entity name (e.g. "lt" or "amp")
     * @return true if a known named entity
     */
    public static func isNamedEntity(name: String): Bool {
        return EscapeMode.extended.codepointForName(name) != empty
    }

    /*
     * Check if the input is a known named entity in the base entity set.
     *
     * @param name the possible entity name (e.g. "lt" or "amp")
     * @return true if a known named entity in the base set
     */
    public static func isBaseNamedEntity(name: String): Bool {
        return EscapeMode.base.codepointForName(name) != empty
    }

    /*
     * Get the character(s) represented by the named entity
     *
     * @param name entity (e.g. "lt" or "amp")
     * @return the string value of the character(s) represented by this entity, or "" if not defined
     */
    public static func getByName(name: String): String {
        var val: ?String = multipoints.get(name)
        if (val != None) {
            return val()
        }
        var codepoint: Int64 = EscapeMode.extended.codepointForName(name)
        if (codepoint != empty) {
            return Rune.parse("'\\u{${codepoint.format("x")}}'").toString()
        }
        return emptyName
    }

    static func codepointsForName(name: String, codepoints: Array<Rune>): Int64 {
        var val: ?String = multipoints.get(name)
        if (let Some(v) <- val?.toRuneArray()) {
            codepoints[0] = v[0]
            codepoints[1] = v[1]
            return 2
        }
        var codepoint: Int64 = EscapeMode.extended.codepointForName(name)
        if (codepoint != empty) {
            codepoints[0] = Rune.parse("'\\u{${codepoint.format("x")}}'")
            return 1
        }
        return 0
    }

    /*
     * HTML escape an input string. That is: < is returned as &lt;
     *
     * @param string the un-escaped string to escape
     * @param out the output settings to use
     * @return the escaped string
     */
    public static func escape(string: String, out: DocumentOutputSettings): String {
        var accum: StringBuilder = StringUtil.borrowBuilder()
        escape(accum, string, out, false, false, false, false)
        return StringUtil.releaseBuilder(accum)
    }

    /*
     * HTML escape an input string, using the default settings (UTF-8, base entities).
     *
     * @param string the un-escaped string to escape
     * @return the escaped string
     */
    public static func escape(string: String): String {
        return escape(string, defaultOutput)
    }

    static func escape(
        accum: StringBuilder,
        string: String,
        out: DocumentOutputSettings,
        inAttribute: Bool,
        normaliseWhite: Bool,
        stripLeadingWhite: Bool,
        trimTrailing: Bool
    ): Unit {
        var lastWasWhite: Bool = false
        var reachedNonWhite: Bool = false
        let escapeMode: EscapeMode = out.escapeMode()

        // let encoder: CharsetEncoder = out.encoder()
        // let coreCharset: CoreCharset = out.coreCharset // init in out.prepareEncoder()
        // let length: Int64 = string.size

        var skipped: Bool = false
        for (c in string.toRuneArray()) {
            var codePoint: Int64 = c.hashCode()
            if (normaliseWhite) {
                if (StringUtil.isWhitespace(c)) {
                    if (stripLeadingWhite && !reachedNonWhite) {
                        continue
                    }
                    if (lastWasWhite) {
                        continue
                    }
                    if (trimTrailing) {
                        skipped = true
                        continue
                    }
                    accum.append(r' ')
                    lastWasWhite = true
                    continue
                } else {
                    lastWasWhite = false
                    reachedNonWhite = true
                    if (skipped) {
                        // wasn't the end, so need to place a normalized space
                        accum.append(r' ')
                        skipped = false
                    }
                }
            }
            matchChar(c, accum, escapeMode, inAttribute, out, codePoint)
        }
    }

    static func matchChar(
        c: Rune,
        accum: StringBuilder,
        escapeMode: EscapeMode,
        inAttribute: Bool,
        out: DocumentOutputSettings,
        codePoint: Int64
    ) {
        // surrogate pairs, split implementation for efficiency on single char common case (saves creating strings, char[]):
        match (c) {
            case r'&' => accum.append("&amp;")
            case r'\u{a0}' =>
                if (escapeMode != EscapeMode.xhtml) {
                    accum.append("&nbsp;")
                } else {
                    accum.append("&#xa0;")
                }
            case r'<' =>
                // escape when in character data or when in a xml attribute val or XML syntax; not needed in html attr val
                if (!inAttribute || escapeMode == EscapeMode.xhtml || out.syntax() == Syntax.xmlSyntax) {
                    accum.append("&lt;")
                } else {
                    accum.append(c)
                }
            case r'>' =>
                if (!inAttribute) {
                    accum.append("&gt;")
                } else {
                    accum.append(c)
                }
            case r'"' =>
                if (inAttribute) {
                    accum.append("&quot;")
                } else {
                    accum.append(c)
                }
            case r'\u{9}' | r'\u{a}' | r'\u{d}' => accum.append(c)
            case _ =>
                if (c < r'\u{20}' || !canEncode(out.coreCharset, c, None)) {
                    appendEncoded(accum, escapeMode, codePoint)
                } else {
                    accum.append(c)
                }
        }
    }

    private static func appendEncoded(accum: StringBuilder, escapeMode: EscapeMode, codePoint: Int64): Unit {
        var name: String = escapeMode.nameForCodepoint(codePoint)
        if (!emptyName.equals(name)) {
            // ok for identity check
            accum.append(r'&')
            accum.append(name)
            accum.append(r';')
        } else {
            accum.append("&#x")
            accum.append(codePoint.format("x"))
            accum.append(r';')
        }
    }

    /*
     * Un-escape an HTML escaped string.
     *
     * @param string the HTML string to un-escape
     * @return the unescaped string
     */
    public static func unescape(string: String): String {
        return unescape(string, false)
    }

    /*
     * Unescape the input string.
     *
     * @param string to un-HTML-escape
     * @param strict if "strict"
     * @return unescaped string
     */
    static func unescape(string: String, strict: Bool): String {
        return Parser.unescapeEntities(string, strict)
    }

    private static func canEncode(charset: CoreCharset, c: Rune, _: ?Any): Bool {
        return match (charset) {
            case ascii => c < r'\u{80}'
            case utf => true
            case _ => false
        }
    }

    static func load(pointsData: String, size: Int64): (Array<String>, Array<Int64>, Array<Int64>, Array<String>) {
        let nameKeys = Array<String>(size, repeat: "")
        let codeVals = Array<Int64>(size, repeat: 0)
        let codeKeys = Array<Int64>(size, repeat: 0)
        let nameVals = Array<String>(size, repeat: "")

        var i: Int64 = 0
        var reader: CharacterReader = CharacterReader(pointsData)
        while (!reader.isEmpty()) {
            var name: String = reader.consumeTo(r'=')
            reader.advance()
            var str: String = reader.consumeToAny(codeDelims)

            let cp1: Int64 = parseRadix36(str)

            var codeDelim: Rune = reader.current()
            reader.advance()
            var cp2: Int64
            if (codeDelim == r',') {
                var str1: String = reader.consumeTo(r';')
                cp2 = parseRadix36(str1)
                reader.advance()
            } else {
                cp2 = empty
            }
            var indexS: String = reader.consumeTo(r'&')

            let index: Int64 = parseRadix36(indexS)

            reader.advance()
            nameKeys[i] = name
            codeVals[i] = cp1
            codeKeys[index] = cp1
            nameVals[index] = name

            if (cp2 != empty) {
                multipoints.add(name, "${cp1.toUnicodeChar()}${cp2.toUnicodeChar()}")
            }
            i++
        }
        Validate.isTrue(i == size, "Unexpected count of entities loaded")
        return (nameKeys, codeVals, codeKeys, nameVals)
    }
}

public enum EscapeMode <: Equatable<EscapeMode> & ToString {
    /*
     * Restricted entities suitable for XHTML output: lt, gt, amp, and quot only.
     */
    | xhtml
    /*
     * Default HTML output entities.
     */
    | base
    /*
     * Complete HTML entities.
     */
    | extended

    // table of named references to their codepoints. sorted so we can binary search. built by BuildEntities.
    private prop nameKeys: Array<String> {
        get() {
            match (this) {
                case xhtml => Entities.xhtmlData[0]
                case base => Entities.baseData[0]
                case extended => Entities.extendedData[0]
            }
        }
    }

    // limitation is the few references with multiple characters; those go into multipoints.
    private prop codeVals: Array<Int64> {
        get() {
            match (this) {
                case xhtml => Entities.xhtmlData[1]
                case base => Entities.baseData[1]
                case extended => Entities.extendedData[1]
            }
        }
    }

    // table of codepoints to named entities.
    // we don't support multicodepoints to single named value currently
    private prop codeKeys: Array<Int64> {
        get() {
            match (this) {
                case xhtml => Entities.xhtmlData[2]
                case base => Entities.baseData[2]
                case extended => Entities.extendedData[2]
            }
        }
    }

    private prop nameVals: Array<String> {
        get() {
            match (this) {
                case xhtml => Entities.xhtmlData[3]
                case base => Entities.baseData[3]
                case extended => Entities.extendedData[3]
            }
        }
    }

    func codepointForName(name: String): Int64 {
        let index = binarySearch(nameKeys, name)
        return if (index >= 0) {
            codeVals[index]
        } else {
            Entities.empty
        }
    }

    func nameForCodepoint(codepoint: Int64): String {
        let index = binarySearch(codeKeys, codepoint)
        if (index >= 0) {
            // the results are ordered so lower case versions of same codepoint come after uppercase, and we prefer to emit lower
            // (and binary search for same item with multi results is undefined
            if ((index < nameVals.size - 1 && codeKeys[index + 1] == codepoint)) {
                return nameVals[index + 1]
            } else {
                return nameVals[index]
            }
        }
        return Entities.emptyName
    }

    public operator func !=(that: EscapeMode): Bool {
        return !(this == that)
    }

    public operator func ==(that: EscapeMode): Bool {
        return match ((this, that)) {
            case (xhtml, xhtml) | (base, base) | (extended, extended) => true
            case _ => false
        }
    }

    public func toString(): String {
        match (this) {
            case xhtml => return "xhtml"
            case base => return "base"
            case extended => return "extended"
        }
    }
}

enum CoreCharset {
    | ascii
    | utf
    | fallback

    static func byName(name: String): CoreCharset {
        let upname = name.toAsciiUpper()
        if (upname.toAsciiUpper().contains("ASCII")) {
            return CoreCharset.ascii
        }
        if (upname.startsWith("UTF-")) {
            // covers UTF-8, UTF-16, et al
            return CoreCharset.utf
        }
        return CoreCharset.fallback
    }
}
