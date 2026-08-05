/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A character queue with parsing helpers.
 */
class TokenQueue {
    private var queueStr: ?String = None
    private var queueRune: Array<Rune> = unsafe { zeroValue<Array<Rune>>() }
    private mut prop queue: String {
        get() {
            queueStr()
        }
        set(v) {
            this.queueStr = v
            this.queueRune = v.toRuneArray()
        }
    }
    private var pos: Int64 = 0

    private static let ESC: Rune = r'\\' // escape char for chomp balanced.

    /*
       Create a new TokenQueue.
       @param data string of data to back queue.
     */
    public init(data: String) {
        this.queue = data
    }

    /*
     * Is the queue empty?
     * @return true if no data left in queue.
     */
    public func isEmpty(): Bool {
        return remainingLength() == 0
    }

    private func remainingLength(): Int64 {
        return queueRune.size - pos
    }

    /*
       Add a string to the start of the queue.
       @param seq string to add.
     */
    public func addFirst(seq: String): Unit {
        // not very performant, but an edge case
        queue = seq + String(queueRune[pos..])
        pos = 0
    }

    /*
     * Tests if the next characters on the queue match the sequence. Case insensitive.
     * @param seq String to check queue for.
     * @return true if the next characters match.
     */
    func matches(seq: String): Bool {
        let to = pos + seq.toRuneArray().size
        if (to > queueRune.size) {
            false
        } else {
            String(queueRune[pos..to]).toLower() == seq.toLower()
        }
    }
    func matches(seq: Array<Rune>): Bool {
        let to = pos + seq.size
        if (to > queueRune.size) {
            false
        } else {
            queueRune[pos..to].equalsIgnoreCase(seq)
        }
    }

    /*
       Tests if the next characters match any of the sequences. Case insensitive.
       @param seq list of strings to case insensitively check for
       @return true of any matched, false if none did
     */
    func matchesAny(seq: Array<String>): Bool {
        for (s in seq) {
            if (matches(s)) {
                return true
            }
        }
        return false
    }

    func matchesAny(seq: Array<Rune>): Bool {
        if (isEmpty()) {
            return false
        }

        for (c in seq) {
            if (queueRune[pos] == c) {
                return true
            }
        }
        return false
    }

    /*
     * Tests if the queue matches the sequence (as with match), and if they do, removes the matched string from the
     * queue.
     * @param seq String to search for, and if found, remove from queue.
     * @return true if found and removed, false if not found.
     */
    func matchChomp(seqStr: String): Bool {
        let seq = seqStr.toRuneArray()
        if (matches(seq)) {
            pos += seq.size
            return true
        } else {
            return false
        }
    }

    /*
       Tests if queue starts with a whitespace character.
       @return if starts with whitespace
     */
    func matchesWhitespace(): Bool {
        return !isEmpty() && StringUtil.isWhitespace(queueRune[pos])
    }

    /*
       Test if the queue matches a word character (letter or digit).
       @return if matches a word character
     */
    func matchesWord(): Bool {
        if (isEmpty()) {
            return false
        }
        let c = queueRune[pos]
        return c.isLetter() || c.isNumber()
    }

    /*
     * Consume one character off queue.
     * @return first character on queue.
     */
    func consume(): Rune {
        let p = pos
        pos++
        return queueRune[p]
    }

    /*
     * Consumes the supplied sequence of the queue. If the queue does not start with the supplied sequence, will
     * throw an illegal state exception -- but you should be running match() against that condition.
     * Case insensitive.
     * @param seq sequence to remove from head of queue.
     */
    func consume(seqStr: String): Unit {
        let seq = seqStr.toRuneArray()
        if (!matches(seq)) {
            throw ParseException("Queue did not match expected sequence")
        }
        let len = seq.size
        if (len > remainingLength()) {
            throw ParseException("Queue not long enough to consume sequence")
        }

        pos += len
    }

    /*
     * Pulls a string off the queue, up to but exclusive of the match sequence, or to the queue running out.
     * @param seq String to end on (and not include in return, but leave on queue). <b>Case sensitive.</b>
     * @return The matched data consumed from queue.
     */
    public func consumeTo(seqStr: String): String {
        let seq = seqStr.toRuneArray()
        let offset = queueRune.indexOf(seq, pos)
        if (offset != None) {
            let consumed = queueRune[pos..offset()]
            pos += consumed.size
            return String(consumed)
        } else {
            return remainder()
        }
    }

    func consumeToIgnoreCase(seqStr: String): String {
        let seq = seqStr.toRuneArray()
        let start = pos
        let first = seq[0..1]
        let canScan = first[0].toAsciiLowerCase() == first[0].toAsciiUpperCase() // if first is not cased, use index of
        while (!isEmpty()) {
            if (matches(seq)) {
                break
            }

            if (canScan) {
                let skip = queueRune.indexOf(first, pos)(-1) - pos
                if (skip == 0) {
                    // this char is the skip char, but not match, so force advance of pos
                    pos++
                } else if (skip < 0) {
                    // no chance of finding, grab to end
                    pos = queueRune.size
                } else {
                    pos += skip
                }
            } else {
                pos++
            }
        }

        return String(queueRune[start..pos])
    }

    /*
     * Consumes to the first sequence provided, or to the end of the queue. Leaves the terminator on the queue.
     *
     * @param seq any number of terminators to consume to. <b>Case insensitive.</b>
     * @return consumed string
     */
    func consumeToAny(seq: Array<String>): String {
        let start = pos
        while (!isEmpty() && !matchesAny(seq)) { /*cjlint-ignore !G.EXP.03 */
            pos++
        }

        return String(queueRune[start..pos])
    }

    /*
     * Pulls a string off the queue (like consumeTo), and then pulls off the matched string (but does not return it).
     * If the queue runs out of characters before finding the seq, will return as much as it can (and queue will go
     * isEmpty() == true).
     *
     * @param seq String to match up to, and not include in return, and to pull off queue. <b>Case sensitive.</b>
     * @return Data matched from queue.
     */
    func chompTo(seq: String): String {
        let data: String = consumeTo(seq)
        matchChomp(seq)
        return data
    }

    public func chompToIgnoreCase(seq: String): String {
        let data: String = consumeToIgnoreCase(seq) // case insensitive scan
        matchChomp(seq)
        return data
    }

    /*
     * Pulls a balanced string off the queue. E.g. if queue is "(one (two) three) four", (,) will return "one (two) three",
     * and leave " four" on the queue. Unbalanced openers and closers can be quoted (with ' or ") or escaped (with \). Those escapes will be left
     * in the returned string, which is suitable for regexes (where we need to preserve the escape), but unsuitable for
     * contains text strings; use unescape for that.
     *
     * @param open opener
     * @param close closer
     * @return data matched from the queue
     */
    public func chompBalanced(openChar: Rune, close: Rune): String {
        var start = -1
        var end = -1
        var depth = 0
        var last: Rune = r'\u{0}'
        var inSingleQuote = false
        var inDoubleQuote = false
        var inRegexQE = false // regex \Q .. \E escapes from Pattern.quote()

        do {
            if (isEmpty()) {
                break
            }
            let c = consume()
            if (last != ESC) {
                if (c == r'\'' && c != openChar && !inDoubleQuote) {
                    inSingleQuote = !inSingleQuote
                } else if (c == r'"' && c != openChar && !inSingleQuote) {
                    inDoubleQuote = !inDoubleQuote
                }
                if (inSingleQuote || inDoubleQuote || inRegexQE) {
                    last = c
                    continue
                }

                if (c == openChar) {
                    depth++
                    if (start == -1) {
                        start = pos
                    }
                } else if (c == close) {
                    depth--
                }
            } else if (c == r'Q') {
                inRegexQE = true
            } else if (c == r'E') {
                inRegexQE = false
            }
            if (depth > 0 && last != r'\u{0}') {
                end = pos // don't include the outer match pair in the return
            }
            last = c
        } while (depth > 0)
        let out = if (end >= 0) {
            String(queueRune[start..end])
        } else {
            ""
        }
        if (depth > 0) { // ran out of queue before seeing enough )
            Validate.fail("Did not find balanced marker at '${out}'")
        }
        return out
    }

    /*
     * Unescape a \ escaped string.
     * @param inStr backslash escaped string
     * @return unescaped string
     */
    public static func unescape(inStr: String): String {
        let out = StringUtil.borrowBuilder()
        var last = r'\u{0}'
        for (ch in inStr.toRuneArray()) {
            var c = ch
            if (c == ESC) {
                if (last == ESC) {
                    out.append(c)
                    c = r'\u{0}'
                }
            } else {
                out.append(c)
            }
            last = c
        }
        return StringUtil.releaseBuilder(out)
    }

    /*
     * Given a CSS identifier (such as a tag, ID, or class), escape any CSS special characters that would otherwise not be
     * valid in a selector.
     */
    public static func escapeCssIdentifier(inStr: String): String {
        let out = StringUtil.borrowBuilder()
        let q = TokenQueue(inStr)
        while (!q.isEmpty()) {
            if (q.matchesCssIdentifier(ElementSelectorChars)) {
                out.append(q.consume())
            } else {
                out.append(ESC)
                out.append(q.consume())
            }
        }
        return StringUtil.releaseBuilder(out)
    }

    /*
     * Pulls the next run of whitespace characters of the queue.
     * @return Whether consuming whitespace or not
     */
    public func consumeWhitespace(): Bool {
        var seen = false
        while (matchesWhitespace()) {
            pos++
            seen = true
        }
        return seen
    }

    /*
     * Retrieves the next run of word type (letter or digit) off the queue.
     * @return String of word characters from queue, or empty string if none.
     */
    public func consumeWord(): String {
        let start = pos
        while (matchesWord()) {
            pos++
        }
        return String(queueRune[start..pos])
    }

    /*
     * Consume a CSS element selector (tag name, but | instead of : for namespaces (or *| for wildcard namespace), to not conflict with :pseudo selects).
     *
     * @return tag name
     */
    public func consumeElementSelector(): String {
        return consumeEscapedCssIdentifier(ElementSelectorChars)
    }
    private static let ElementSelectorChars: Array<String> = ["*|", "|", "_", "-"]

    /*
       Consume a CSS identifier (ID or class) off the queue (letter, digit, -, _)
       @return identifier
     */
    public func consumeCssIdentifier(): String {
        return consumeEscapedCssIdentifier(CssIdentifierChars)
    }
    private static let CssIdentifierChars: Array<String> = ["-", "_"]

    private func consumeEscapedCssIdentifier(matches: Array<String>): String {
        let start = pos
        var escaped = false
        while (!isEmpty()) {
            if (queueRune[pos] == ESC && remainingLength() > 1) {
                escaped = true
                pos += 2 // skip the escape and the escaped
            } else if (matchesCssIdentifier(matches)) {
                pos++
            } else {
                break
            }
        }

        let consumed = String(queueRune[start..pos])
        return if (escaped) {
            unescape(consumed)
        } else {
            consumed
        }
    }

    private func matchesCssIdentifier(matches: Array<String>): Bool {
        return matchesWord() || matchesAny(matches) /*cjlint-ignore !G.EXP.03 */
    }

    /*
       Consume and return whatever is left on the queue.
       @return remained of queue.
     */
    public func remainder(): String {
        let remainder = String(queueRune[pos..])
        pos = queueRune.size
        return remainder
    }
}
