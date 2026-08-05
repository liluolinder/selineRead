/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A minimal String utility class. Designed for <b>internal</b> jsoup use only - the API and outcome may change withoutnotice.
 */
class StringUtil {
    // memoised padding up to 21 (blocks 0 to 20 spaces)
    public static let paddingList: Array<String> = [
        "",
        " ",
        "  ",
        "   ",
        "    ",
        "     ",
        "      ",
        "       ",
        "        ",
        "         ",
        "          ",
        "           ",
        "            ",
        "             ",
        "              ",
        "               ",
        "                ",
        "                 ",
        "                  ",
        "                   ",
        "                    "
    ]

    // private static let extraDotSegmentsPattern: Regex = Regex("^/((\\.{1,2}/)+)")

    private static let validUriScheme: Regex = Regex("^[a-zA-Z][a-zA-Z0-9+-.]*:")

    // matches ascii 0 - 31, to strip from url
    // private static let controlChars: Regex = Regex("[\\x00-\\x1f]*")

    private static var sbLinkedList: LinkedList<StringBuilder> = LinkedList<StringBuilder>()

    // private static let MaxCachedBuilderSize: Int64 = 8 * 1024

    private static let MaxIdleBuilders: Int64 = 8

    static let numberRegex: Regex = Regex("^[0-9]")

    private static let mtx: ReentrantMutex = ReentrantMutex()

    /*
     * Join a collection of strings by a separator
     *
     * @param strings collection of string objects
     * @param sep string to place between strings
     * @return joined string
     */
    public static func join(strings: Collection<String>, sep: String): String {
        return join(strings.iterator(), sep)
    }

    /*
     * Join a collection of strings by a separator
     *
     * @param strings iterator of string objects
     * @param sep string to place between strings
     * @return joined string
     */
    public static func join(strings: Iterator<String>, sep: String): String {
        var start: ?String = strings.next()
        if (start == None) {
            return ""
        }
        var second: ?String = strings.next()
        if (second == None) {
            return start()
        }
        var j: StringJoiner = StringJoiner(sep)
        j.add(start())
        j.add(second())
        while (true) {
            var str: ?String = strings.next()
            if (str != None) {
                j.add(str())
            } else {
                break
            }
        }
        return j.complete()
    }

    /*
     * Join an array of strings by a separator
     *
     * @param strings collection of string objects
     * @param sep string to place between strings
     * @return joined string
     */
    public static func join(strings: Array<String>, sep: String): String {
        return join(strings.iterator(), sep)
    }

    /*
     * Returns space padding (up to the default max of 30). Use #padding(int, int) to specify a different limit.
     * @param width amount of padding desired
     * @return string of spaces * width
     * @see #padding(int, int)
     */
    public static func padding(width: Int64): String {
        return padding(width, 30)
    }

    /*
     * Returns space padding, up to a max of maxPaddingWidth.
     *
     * @param width amount of padding desired
     * @param maxPaddingWidth maximum padding to apply. Set to -1 for unlimited.
     * @return string of spaces * width
     */
    public static func padding(width: Int64, maxPaddingWidth: Int64): String {
        Validate.isTrue(width >= 0, "width must be >= 0")
        Validate.isTrue(maxPaddingWidth >= -1)
        var widthNew: Int64 = width
        if (maxPaddingWidth != -1) {
            widthNew = min(width, maxPaddingWidth)
        }
        if (widthNew < paddingList.size) {
            return paddingList[widthNew]
        }
        var out: Array<Rune> = Array<Rune>(widthNew, repeat: r' ')
        for (i in 0..widthNew) {
            out[i] = r' '
        }
        return String(out)
    }

    /*
     * Tests if a string is blank: null, empty, or only whitespace (" ", \r\n, \t, etc)
     *
     * @param string string to test
     * @return if string is blank
     */
    public static func isBlank(stringStr: String): Bool {
        let string = stringStr.toRuneArray()
        if (string.size == 0) {
            return true
        }
        var l: Int64 = string.size
        for (i in 0..l) {
            if (!StringUtil.isWhitespace(string[i])) {
                return false
            }
        }
        return true
    }

    /*
     * Tests if a string starts with a newline character
     *
     * @param string string to test
     * @return if its first character is a newline
     */
    public static func startsWithNewline(string: String): Bool {
        if (string.size == 0) {
            return false
        }
        return string[0] == b'\n'
    }

    /*
     * Tests if a string is numeric, i.e. contains only digit characters
     *
     * @param string string to test
     * @return true if only digit chars, false if empty or null or contains non-digit chars
     */
    public static func isNumeric(string: String): Bool {
        if (string.size == 0) {
            return false
        }
        var chars: Array<Rune> = string.toRuneArray()
        for (i in 0..chars.size) {
            var char: Rune = chars[i]
            if (numberRegex.matcher(char.toString()).find().isNone()) {
                return false
            }
        }
        return true
    }

    /*
     * Tests if a code point is "whitespace" as defined in the HTML spec. Used for output HTML.
     *
     * @param c code point to test
     * @return true if code point is whitespace, false otherwise
     * @see #isActuallyWhitespace(int)
     */
    public static func isWhitespace(c: Rune): Bool {
        return c == r' ' || c == r'\t' || c == r'\n' || c == r'\f' || c == r'\r'
    }
    public static func isWhitespace(c: Byte): Bool {
        return c == b' ' || c == b'\t' || c == b'\n' || c == b'\f' || c == b'\r'
    }

    /*
     * Tests if a code point is "whitespace" as defined by what it looks like. Used for Element.text etc.
     *
     * @param c code point to test
     * @return true if code point is whitespace, false otherwise
     */
    public static func isActuallyWhitespace(c: Rune): Bool {
        return c == r' ' || c == r'\t' || c == r'\n' || c == r'\f' || c == r'\r' || c == r'\u{A0}'
        // 160 is &nbsp; (non-breaking space). Not in the spec but expected.
    }

    public static func isInvisibleChar(c: Rune): Bool {
        // zero width sp, soft hyphen
        return c == r'\u{200B}' || c == r'\u{AD}'
        // previously also included zw non join, zw join - but removing those breaks semantic meaning of text
    }

    /*
     * Normalise the whitespace within this string; multiple spaces collapse to a single, and all whitespace characters convert to a simple space
     *
     * @param string content to normalise
     * @return normalised string
     */
    public static func normaliseWhitespace(string: String): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        appendNormalisedWhitespace(sb, string, false)
        return StringUtil.releaseBuilder(sb)
    }

    /*
     * After normalizing the whitespace within a string, appends it to a string builder.
     *
     * @param accum builder to append to
     * @param string string to normalize whitespace within
     * @param stripLeading set to true if you wish to remove any leading whitespace
     */
    public static func appendNormalisedWhitespace(accum: StringBuilder, string: String, stripLeading: Bool): Unit {
        var lastWasWhite: Bool = false
        var reachedNonWhite: Bool = false
        var chars: Array<Rune> = string.toRuneArray()
        for (i in 0..chars.size) {
            if (isActuallyWhitespace(chars[i])) {
                if ((stripLeading && !reachedNonWhite) || lastWasWhite) {
                    continue
                }
                accum.append(r' ')
                lastWasWhite = true
            } else if (!isInvisibleChar(chars[i])) {
                accum.append(chars[i])
                lastWasWhite = false
                reachedNonWhite = true
            }
        }
    }

    public static func inSorted(needle: String, haystack: Array<String>): Bool {
        for (i in 0..haystack.size) {
            if (haystack[i].equals(needle)) {
                return true
            }
        }
        return false
    }

    /*
     * Tests that a String contains only ASCII characters.
     *
     * @param string scanned string
     * @return true if all characters are in range 0 - 127
     */
    public static func isAscii(stringStr: String): Bool {
        let string = stringStr.toRuneArray()
        for (i in 0..string.size) {
            var c: Rune = string[i]
            if (!c.isAscii()) {
                // ascii range
                return false
            }
        }
        return true
    }

    static func matcherUrl(relUrl: String): String {
        return match (validUriScheme.matcher(relUrl).find()) {
            case None => ""
            case _ => relUrl
        }
    }

    static func tryCatchUrl(relUrl: String) {
        try {
            var abs: URL = URL.parse(relUrl)
            if (abs.isAbsoluteURL()) {
                return abs.toString()
            } else {
                return matcherUrl(relUrl)
            }
        } catch (e: UrlSyntaxException | IllegalArgumentException) {
            return matcherUrl(relUrl)
        }
    }

    /*
     * Create a new absolute URL, from a provided existing absolute URL and a relative URL component.
     *
     * @param baseUrl the existing absolute base URL
     * @param relUrl the relative URL to resolve. (If it's already absolute, it will be returned)
     * @return an absolute URL if one was able to be generated, or the empty string if not
     */
    public static func resolve(baseUrl: String, relUrl: String): String {
        var baseUrlNew: String = stripControlChars(baseUrl).replace(" ", "%20")
        var relUrlNew: String = stripControlChars(relUrl).replace(" ", "%20")
        try {
            var base: URL = URL.parse(baseUrlNew)
            var rel: URL = URL.parse(relUrlNew)
            if (base.isAbsoluteURL()) {
                return base.resolveURL(rel).toString()
            } else {
                return tryCatchUrl(relUrlNew)
            }
        } catch (e: UrlSyntaxException | IllegalArgumentException) {
            return tryCatchUrl(relUrlNew)
        }
    }

    private static func stripControlChars(input: String): String {
        let charBool: (Rune) -> Bool = {
            c => !(r'\u{00}' <= c && c <= r'\u{1f}')
        }
        return input.toRuneArray() |> filter<Rune>(charBool) |> collectString<Rune>()
    }

    /*
     * Maintains cached StringBuilders in a flyweight pattern, to minimize new StringBuilder GCs. The StringBuilder is prevented from growing too large.
     *
     * @return an empty StringBuilder
     */
    public static func borrowBuilder(): StringBuilder {
        synchronized(mtx) {
            if (sbLinkedList.isEmpty()) {
                return StringBuilder()
            } else {
                return sbLinkedList.removeFirst()
            }
        }
    }

    /*
     * Release a borrowed builder. Care must be taken not to use the builder after it has been returned, as its
     * contents may be changed by this method, or by a concurrent thread.
     *
     * @param sb the StringBuilder to release.
     * @return the string value of the released String Builder (as an incentive to release it!).
     */
    public static func releaseBuilder(stringBuilder: StringBuilder): String {
        var string: String = stringBuilder.toString()
        stringBuilder.reset()
        synchronized(mtx) {
            sbLinkedList.insert(0, stringBuilder)
            while (sbLinkedList.size > MaxIdleBuilders) {
                sbLinkedList.removeFirst()
            }
        }
        return string
    }
}

/*
   A StringJoiner allows incremental / filtered joining of a set of stringable objects.
 */
class StringJoiner {
    // sets null on builder release so can't accidentally be reused
    var sb: ?StringBuilder = StringUtil.borrowBuilder()

    var separator: String

    var first: Bool = true

    /*
     * Create a new joiner, that uses the specified separator. MUST call #complete() or will leak a thread
     * local string builder.
     *
     * @param separator the token to insert between strings
     */
    init(separator: String) {
        this.separator = separator
    }

    /*
     * Add another item to the joiner, will be separated
     */
    func add(stringy: String): StringJoiner {
        // don't reuse
        Validate.notNull(sb)
        if (!first) {
            sb().append(separator)
        }
        sb().append(stringy)
        first = false
        return this
    }

    /*
     * Return the joined string, and release the builder back to the pool. This joiner cannot be reused.
     */
    func complete(): String {
        var string: String = StringUtil.releaseBuilder(sb())
        sb = None
        return string
    }
}
