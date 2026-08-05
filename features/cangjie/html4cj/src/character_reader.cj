/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

let nullStringReader = StringReader("")

/*
 * CharacterReader consumes tokens off a string. Used internally by jsoup. API subject to changes.
 */
class CharacterReader {
    public static let EOF: Rune = r'\u{FFFF}'

    private static let maxStringCacheLen: Int64 = 12

    // the minimum mark length supported. No HTML entities can be larger than this.
    private static let minReadAheadLen: Int64 = 1024

    // visible for testing
    public static let maxBufferLen: Int64 = 1024 * 32

    // visible for testing
    public static let readAheadLimit: Int64 = Int64(Float64.parse(maxBufferLen.toString()) * 0.75)

    private var charBuf: Array<Rune>

    private var reader: StringReader

    private var bufLength: Int64 = 0

    private var bufSplitPoint: Int64 = 0

    private var bufPos: Int64 = 0

    private var readerPos: Int64 = 0

    private var bufMark: Int64 = -1

    private static let stringCacheSize: Int64 = 512

    // holds reused strings in this doc, to lessen garbage
    private var stringCache: Array<String> = Array(stringCacheSize, repeat: "")

    // optionally track the pos() position of newlines - scans during bufferUp()
    private var newlinePositions: ?ArrayList<Int64> = None

    // line numbers start at 1 += newlinePosition[indexof(pos)]
    private var lineNumberOffset: Int64 = 1

    // if the underlying stream has been completely read, no value in further buffering
    private var readFully: Bool = false

    init(input: StringReader, sz: Int64) {
        reader = input
        charBuf = Array<Rune>(min(sz, maxBufferLen), repeat: TokeniserState.nullChar)
        bufferUp()
    }

    init(input: StringReader) {
        this(input, maxBufferLen)
    }

    public init(input: String) {
        this(StringReader(input), input.size)
    }

    func close(): Unit {
        reader = nullStringReader
        charBuf = []
        stringCache = []
    }

    private func bufferUp() {
        if (readFully || bufPos < bufSplitPoint) {
            return
        }
        let (pos, offset) = if (bufMark == -1) {
            (bufPos, 0)
        } else {
            (bufMark, bufPos - bufMark)
        }
        try {
            let skipped: Int64 = reader.skip(pos)
            reader.mark()
            var read = 0
            while (read <= minReadAheadLen) {
                let thisRead = reader.read(charBuf, read, charBuf.size - read)
                if (thisRead == -1) {
                    readFully = true
                }
                if (thisRead <= 0) {
                    break
                }
                read += thisRead
            }
            reader.reset()
            if (read > 0) {
                // Previously asserted that there is room in buf to skip, so this will be a WTF
                Validate.isTrue(skipped == pos)
                bufLength = read
                readerPos += pos
                bufPos = offset
                if (bufMark != -1) {
                    bufMark = 0
                }
                bufSplitPoint = min(bufLength, readAheadLimit)
            }
        } catch (e: IOException) {
            throw e
        }

        // if enabled, we index newline positions for line number tracking
        scanBufferForNewlines()

        // cache for last containsIgnoreCase(seq)
        lastIcSeq = None
    }

    /*
     * Gets the position currently read to in the content. Starts at 0.
     *
     * @return current position
     */
    public func pos(): Int64 {
        return readerPos + bufPos
    }

    /*
       Enables or disables line number tracking. By default, will be <b>off</b>.Tracking line numbers improves the
       legibility of parser error messages, for example. Tracking should be enabled before any content is read to be of
       use.
       @param track set tracking on|off
     */
    public func trackNewlines(track: Bool): Unit {
        if (track && newlinePositions == None) {
            newlinePositions = ArrayList<Int64>(maxBufferLen / 80) // rough guess of likely count
            scanBufferForNewlines() // first pass when enabled subsequently called during bufferUp
        } else if (!track) {
            newlinePositions = None
        }
    }

    /*
       Check if the tracking of newlines is enabled.
       @return the current newline tracking state
     */
    public func isTrackNewlines(): Bool {
        return newlinePositions != None
    }

    /*
       Get the current line number (that the reader has consumed to). Starts at line #1.
       @return the current line number, or 1 if line tracking is not enabled.
       @see #trackNewlines(Bool)
     */
    public func lineNumber(): Int64 {
        return lineNumber(pos())
    }
    func lineNumber(pos: Int64): Int64 {
        // note that this impl needs to be called before the next buffer up or line numberoffset will be wrong. if that
        // causes issues, can remove the reset of newlinepositions during buffer, at the cost of a larger tracking array
        if (!isTrackNewlines()) {
            return 1
        }
        let i = lineNumIndex(pos)
        if (i == -1) {
            return lineNumberOffset
            // first line
        }
        return i + lineNumberOffset + 1
    }

    /*
       Get the current column number (that the reader has consumed to). Starts at column #1.
       @return the current column number
       @see #trackNewlines(Bool)
     */
    public func columnNumber(): Int64 {
        return columnNumber(pos())
    }

    func columnNumber(pos: Int64): Int64 {
        if (!isTrackNewlines()) {
            return pos + 1
        }
        let i = lineNumIndex(pos)
        if (i == -1) {
            return pos + 1
        }
        let a = newlinePositions?[i]
        let b = a.getOrThrow()
        return pos - b + 1
    }

    /*
       Get a formatted string representing the current line and cursor positions. E.g. <code>5:10</code> indicating line
       number 5 and column number 10.
       @return line:col position
       @see #trackNewlines(Bool)
     */
    public func cursorPos(): String {
        return "${lineNumber() }:${columnNumber()}"
    }

    private func lineNumIndex(pos: Int64): Int64 {
        if (!isTrackNewlines()) {
            return 0
        }

        var i = binarySearch(newlinePositions().toArray(), pos)
        if (i < -1) {
            i = abs(i) - 2
        }
        return i
    }

    /*
       Scans the buffer for newline position, and tracks their location in newlinePositions.
     */
    private func scanBufferForNewlines() {
        if (!isTrackNewlines()) {
            return
        }
        if (newlinePositions().size > 0) {
            // work out the line number that we have read up to (as we have likely scanned past this point)
            var index = lineNumIndex(readerPos)
            if (index == -1) {
                index = 0
            } // first line
            let linePos = newlinePositions()[index]
            lineNumberOffset += index // the num lines we've read up to
            newlinePositions().clear()
            newlinePositions().add(linePos) // roll the last read pos to first, for cursor num after buffer
        }

        for (i in bufPos..bufLength) {
            if (charBuf[i] == r'\n') {
                newlinePositions?.add(1 + readerPos + i)
            }
        }
    }

    /*
     * Tests if all the content has been read.
     * @return true if nothing left to read.
     */
    public func isEmpty(): Bool {
        bufferUp()
        return bufPos >= bufLength
    }

    private func isEmptyNoBufferUp(): Bool {
        return bufPos >= bufLength
    }

    /*
     * Get the Rune at the current position.
     * @return char
     */
    public func current(): Rune {
        bufferUp()
        if (isEmptyNoBufferUp()) {
            EOF
        } else {
            charBuf[bufPos]
        }
    }

    public func consume(): Rune {
        bufferUp()
        let val = if (isEmptyNoBufferUp()) {
            EOF
        } else {
            charBuf[bufPos]
        }
        bufPos++
        return val
    }

    /*
       Unconsume one character (bufPos--). MUST only be called directly after a consume(), and no chance of a bufferUp.
     */
    public func unconsume(): Unit {
        if (bufPos < 1) {
            throw UncheckedIOException("No buffer left to unconsume.") // a bug if this fires, need to trace it.
        }
        bufPos--
    }

    /*
     * Moves the current position by one.
     */
    public func advance(): Unit {
        bufPos++
    }

    public func mark(): Unit {
        // make sure there is enough look ahead capacity
        if (bufLength - bufPos < minReadAheadLen) {
            bufSplitPoint = 0
        }
        bufferUp()
        bufMark = bufPos
    }

    func unmark() {
        bufMark = -1
    }

    public func rewindToMark(): Unit {
        if (bufMark == -1) {
            throw UncheckedIOException(IOException("Mark invalid"))
        }
        bufPos = bufMark
        unmark()
    }

    /*
     * Returns the number of characters between the current position and the next instance of the input char
     * @param c scan target
     * @return offset between current position and next instance of target. -1 if not found.
     */
    public func nextIndexOf(c: Rune): Int64 {
        // doesn't handle scanning for surrogates
        bufferUp()
        for (i in bufPos..bufLength) {
            if (c == charBuf[i]) {
                return i - bufPos
            }
        }
        return -1
    }

    /*
     * Returns the number of characters between the current position and the next instance of the input sequence
     *
     * @param seq scan target
     * @return offset between current position and next instance of target. -1 if not found.
     */
    public func nextIndexOf(seqStr: String): Int64 {
        bufferUp()
        let seq = seqStr.toRuneArray()

        // doesn't handle scanning for surrogates
        let startChar = seq[0]
        var offset = bufPos
        while (offset < bufLength) {
            // scan to first instance of startchar:
            if (startChar != charBuf[offset]) {
                offset++
                while (offset < bufLength && startChar != charBuf[offset]) {
                    offset++
                }
            }
            var i = offset + 1
            let last = i + seq.size - 1
            if (offset < bufLength && last <= bufLength) {
                var j = 1
                while (i < last && seq[j] == charBuf[i]) {
                    i++
                    j++
                }
                if (i == last) {
                    // found full sequence
                    return offset - bufPos
                }
            }
            offset++
        }
        return -1
    }

    /*
     * Reads characters up to the specific char.
     * @param c the delimiter
     * @return the chars read
     */
    public func consumeTo(c: Rune): String {
        let offset = nextIndexOf(c)
        if (offset != -1) {
            let consumed = cacheString(charBuf, stringCache, bufPos, offset)
            bufPos += offset
            return consumed
        } else {
            return consumeToEnd()
        }
    }

    public func consumeTo(seqStr: String): String {
        let seq = seqStr.toRuneArray()
        let offset = nextIndexOf(seqStr)
        if (offset != -1) {
            let consumed = cacheString(charBuf, stringCache, bufPos, offset)
            bufPos += offset
            return consumed
        } else if (bufLength - bufPos < seq.size) {
            // nextIndexOf() did a bufferUp(), so if the buffer is shorter than the search string, we must be at EOF
            return consumeToEnd()
        } else {
            // the string we're looking for may be straddling a buffer boundary, so keep (length - 1) characters
            // unread in case they contain the beginning of the search string
            let endPos = bufLength - seq.size + 1
            let consumed = cacheString(charBuf, stringCache, bufPos, endPos - bufPos)
            bufPos = endPos
            return consumed
        }
    }

    /*
     * Read characters until the first of any delimiters is found.
     * @param chars delimiters to scan for
     * @return characters read up to the matched delimiter.
     */
    public func consumeToAny(chars: Array<Rune>): String {
        bufferUp()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let val = charBuf
        while (pos < remaining) {
            let has = chars |> contains<Rune>(val[pos])
            if (has) {
                break
            }
            pos++
        }
        bufPos = pos
        if (pos > start) {
            cacheString(val, stringCache, start, pos - start)
        } else {
            ""
        }
    }

    func consumeToAnySorted(chars: Array<Rune>): String {
        bufferUp()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let val = charBuf
        while (pos < remaining) {
            if (binarySearch(chars, val[pos]) >= 0) {
                break
            }
            pos++
        }
        bufPos = pos
        return if (bufPos > start) {
            cacheString(val, stringCache, start, pos - start)
        } else {
            ""
        }
    }

    func consumeData(): String {
        // &, <, None
        //bufferUp() // no need to bufferUp, just called consume()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let val = charBuf
        while (pos < remaining) {
            if ([r'&', r'<', TokeniserState.nullChar].contains(val[pos])) {
                break
            } else {
                pos++
            }
        }
        bufPos = pos
        return if (pos > start) {
            cacheString(val, stringCache, start, pos - start)
        } else {
            ""
        }
    }

    func consumeAttributeQuoted(_: Bool): String {
        // None, " or ', &
        //bufferUp() // no need to bufferUp, just called consume()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let val = charBuf
        while (pos < remaining) {
            if ([r'&', r'\'', r'"', TokeniserState.nullChar].contains(val[pos])) {
                break
            } else {
                pos++
            }
        }
        bufPos = pos
        return if (pos > start) {
            cacheString(val, stringCache, start, pos - start)
        } else {
            ""
        }
    }

    func consumeRawData(): String {
        // <, None
        //bufferUp() // no need to bufferUp, just called consume()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let val = charBuf
        while (pos < remaining) {
            if (val[pos] == r'<' || val[pos] == TokeniserState.nullChar) {
                break
            } else {
                pos++
            }
        }
        bufPos = pos
        return if (pos > start) {
            cacheString(val, stringCache, start, pos - start)
        } else {
            ""
        }
    }

    func consumeTagName(): String {
        // r'\t', r'\n', r'\r', r'\f', r' ', r'/', r'>'
        // NOTE: out of spec, added r'<' to fix common author bugs does not stop and append on nullChar but eats
        bufferUp()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let val = charBuf
        while (pos < remaining) {
            match (val[pos]) {
                case r'\t' | r'\n' | r'\r' | r'\f' | r' ' | r'/' | r'>' | r'<' => break
                case _ => ()
            }
            pos++
        }
        bufPos = pos
        return if (pos > start) {
            cacheString(val, stringCache, start, pos - start)
        } else {
            ""
        }
    }

    public func consumeToEnd(): String {
        bufferUp()
        let data = cacheString(charBuf, stringCache, bufPos, bufLength - bufPos)
        bufPos = bufLength
        return data
    }

    public func consumeLetterSequence(): String {
        bufferUp()
        let start = bufPos
        while (bufPos < bufLength) {
            let c = charBuf[bufPos]
            if ((c >= r'A' && c <= r'Z') || (c >= r'a' && c <= r'z') || c.isLetter()) {
                bufPos++
            } else {
                break
            }
        }
        return cacheString(charBuf, stringCache, start, bufPos - start)
    }

    public func consumeLetterThenDigitSequence(): String {
        bufferUp()
        let start = bufPos
        while (bufPos < bufLength) {
            let c = charBuf[bufPos]
            if ((c >= r'A' && c <= r'Z') || (c >= r'a' && c <= r'z') || c.isLetter()) {
                bufPos++
            } else {
                break
            }
        }
        while (!isEmptyNoBufferUp()) {
            let c = charBuf[bufPos]
            if (c >= r'0' && c <= r'9') {
                bufPos++
            } else {
                break
            }
        }
        return cacheString(charBuf, stringCache, start, bufPos - start)
    }

    func consumeHexSequence(): String {
        bufferUp()
        let start = bufPos
        while (bufPos < bufLength) {
            let c = charBuf[bufPos]
            if ((c >= r'0' && c <= r'9') || (c >= r'A' && c <= r'F') || (c >= r'a' && c <= r'f')) {
                bufPos++
            } else {
                break
            }
        }
        return cacheString(charBuf, stringCache, start, bufPos - start)
    }

    func consumeDigitSequence(): String {
        bufferUp()
        let start = bufPos
        while (bufPos < bufLength) {
            let c = charBuf[bufPos]
            if (c >= r'0' && c <= r'9') {
                bufPos++
            } else {
                break
            }
        }
        return cacheString(charBuf, stringCache, start, bufPos - start)
    }

    public func matches(c: Rune): Bool {
        return !isEmpty() && charBuf[bufPos] == c
    }

    public func matches(seqStr: String): Bool {
        bufferUp()
        let seq = seqStr.toRuneArray()
        let scanLength = seq.size
        if (scanLength > bufLength - bufPos) {
            return false
        }
        for (offset in 0..scanLength) {
            if (seq[offset] != charBuf[bufPos + offset]) {
                return false
            }
        }
        return true
    }

    public func matchesIgnoreCase(seqStr: String): Bool {
        bufferUp()
        let seq = seqStr.toRuneArray()
        let scanLength = seq.size
        if (scanLength > bufLength - bufPos) {
            return false
        }
        for (offset in 0..scanLength) {
            let upScan = seq[offset].toUpperCase()
            let upTarget = charBuf[bufPos + offset].toUpperCase()
            if (upScan != upTarget) {
                return false
            }
        }
        return true
    }

    public func matchesAny(seq: Array<Rune>): Bool {
        if (isEmpty()) {
            return false
        }
        bufferUp()
        let c = charBuf[bufPos]
        for (seek in seq) {
            if (seek == c) {
                return true
            }
        }
        return false
    }

    func matchesAnySorted(seq: Array<Rune>): Bool {
        bufferUp()
        let i = binarySearch(seq, charBuf[bufPos])
        return !isEmpty() && i >= 0
    }

    func matchesLetter(): Bool {
        if (isEmpty()) {
            return false
        }
        let c = charBuf[bufPos]
        return (c >= r'A' && c <= r'Z') || (c >= r'a' && c <= r'z') || c.isLetter()
    }

    /*
       Checks if the current pos matches an ascii alpha (A-Z a-z) per
       @return if it matches or not
     */
    func matchesAsciiAlpha(): Bool {
        if (isEmpty()) {
            return false
        }
        let c = charBuf[bufPos]
        return (c >= r'A' && c <= r'Z') || (c >= r'a' && c <= r'z')
    }

    func matchesDigit(): Bool {
        if (isEmpty()) {
            return false
        }
        let c = charBuf[bufPos]
        return (c >= r'0' && c <= r'9')
    }

    public func matchConsume(seq: String): Bool {
        bufferUp()
        if (matches(seq)) {
            bufPos += seq.size
            return true
        } else {
            return false
        }
    }

    func matchConsumeIgnoreCase(seq: String): Bool {
        if (matchesIgnoreCase(seq)) {
            bufPos += seq.size
            return true
        } else {
            return false
        }
    }

    // we maintain a cache of the previously scanned sequence, and return that if applicable on repeated scans.
    // that improves the situation where there is a sequence of <p<p<p<p<p<p<p...</title> and we're bashing on the <p
    // looking for the </title>. Resets in bufferUp()
    private var lastIcSeq: ?String = None // scan cache
    private var lastIcIndex: Int64 = 0 // nearest found indexOf

    /* Used to check presence of </title>, </style> when we're in RCData and see a <xxx. Only finds consistent case. */
    public func containsIgnoreCase(seq: String): Bool {
        if (lastIcSeq != None && seq.equals(lastIcSeq.getOrThrow())) {
            if (lastIcIndex == -1) {
                return false
            }
            if (lastIcIndex >= bufPos) {
                return true
            }
        }
        lastIcSeq = seq
        let loScan = seq.toLower()
        let lo = nextIndexOf(loScan)
        if (lo > -1) {
            lastIcIndex = bufPos + lo
            return true
        }
        let hiScan = seq.toUpper()
        let hi = nextIndexOf(hiScan)
        let found = hi > -1
        lastIcIndex = if (found) {
            bufPos + hi
        } else {
            -1
        } // we don't care about finding the nearest, just that buf contains
        return found
    }

    public func toString(): String {
        if (bufLength - bufPos < 0) {
            return ""
        }
        return String(charBuf[bufPos..bufLength])
    }

    /*
     * Caches short strings, as a flyweight pattern, to reduce GC load. Just for this doc, to prevent leaks.
     * Simplistic, and on hash collisions just falls back to creating a new string, vs a full HashMap with Entry list.
     * That saves both having to create objects as hash keys, and running through the entry list, at the expense of
     * some more duplicates.
     */
    @OverflowWrapping
    private static func cacheString(charBuf: Array<Rune>, stringCache: Array<String>, start: Int64, count: Int64): String {
        // limit (cache:no):
        if (count > maxStringCacheLen) {
            return String(charBuf[start..start + count])
        }
        if (count < 1) {
            return ""
        }

        // calculate hash:
        var hash = 0
        for (i in 0..count) {
            hash = 31 * hash + charBuf[start + i].hashCode()
        }

        // get from cache
        let index = hash & stringCacheSize - 1
        var cached = stringCache[index]

        // if (cached != None && rangeEquals(charBuf, start, count, cached)) // positive hit
        if (rangeEqualsNew(charBuf, start, count, cached)) {
            // positive hit
            return cached
        } else {
            cached = String(charBuf[start..start + count])
            stringCache[index] = cached // add or replace, assuming most recently used are most likely to recur next
        }
        return cached
    }

    /*
     * Check if the value of the provided range equals the string.
     */
    static func rangeEqualsNew(charBuf: Array<Rune>, start: Int64, count: Int64, cachedStr: String): Bool {
        let cached = cachedStr.toRuneArray()
        var countTmp = count
        if (countTmp == cached.size) {
            var i = start
            var j = 0
            while (countTmp != 0) {
                countTmp--
                if (charBuf[i] != cached[j]) {
                    return false
                }
                i++
                j++
            }
            return true
        }
        return false
    }

    // just used for testing
    public func rangeEquals(start: Int64, count: Int64, cached: String): Bool {
        return rangeEqualsNew(charBuf, start, count, cached)
    }
}

class StringReader {
    private let str: String

    private let arr: Array<Rune>

    private let size: Int64

    private var next: Int64 = 0

    private var markIndex: Int64 = 0

    init(str: String) {
        this.str = str
        this.arr = str.toRuneArray()
        this.size = arr.size
    }

    /*
     * Reads characters into a portion of an array.
     *
     * @param      cbuf Destination buffer
     * @param      off  Offset at which to start storing characters
     * @param      len  Maximum number of characters to read
     * @return     The number of characters read, or -1 if the end of the stream has been reached
     */
    func read(cbuf: Array<Rune>, off: Int64, len: Int64): Int64 {
        if (next >= size) {
            return -1
        }
        let canReadLen = min(size - next, len)
        arr.copyTo(cbuf, next, off, canReadLen)
        next += canReadLen
        return canReadLen
    }

    /*
     * Marks the present position in the stream. Subsequent calls to reset() will reposition the stream to this point.
     */
    func mark() {
        markIndex = next
    }

    /*
     * Resets the stream to the most recent mark, or to the beginning of the string if it has never been marked.
     */
    func reset() {
        next = markIndex
    }

    /*
     * Skips the specified number of characters in the stream. Returns the number of characters that were skipped.
     *
     * @param ns  The number of characters to skip
     * @return    The number of characters actually skipped
     */
    func skip(ns: Int64): Int64 {
        if (next >= size) {
            return 0
        }

        // Bound skip by beginning and end of the source
        var n = min(size - next, ns)
        n = max(-next, n)
        next += n
        return n
    }
}
