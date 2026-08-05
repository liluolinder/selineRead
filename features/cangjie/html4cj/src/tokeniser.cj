/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

class Tokeniser {
    static let replacementChar: Rune = r'\u{FFFD}' // replaces null Character
    private static let notCharRefCharsSorted: Array<Rune> = [r'\t', r'\n', r'\f', r'\r', r' ', r'&', r'<']

    // Some illegal Character escapes are parsed by browsers as windows-1252 instead.
    static let win1252ExtensionsStart = 0x80

    // we could build this manually, but Windows-1252 is not a standard Charset 
    // so that could break on some platforms 
    // this table is verified with a test
    static let win1252Extensions: Array<Int64> = [
        0x20AC,
        0x0081,
        0x201A,
        0x0192,
        0x201E,
        0x2026,
        0x2020,
        0x2021,
        0x02C6,
        0x2030,
        0x0160,
        0x2039,
        0x0152,
        0x008D,
        0x017D,
        0x008F,
        0x0090,
        0x2018,
        0x2019,
        0x201C,
        0x201D,
        0x2022,
        0x2013,
        0x2014,
        0x02DC,
        0x2122,
        0x0161,
        0x203A,
        0x0153,
        0x009D,
        0x017E,
        0x0178
    ]

    private let reader: CharacterReader // html input
    private let errors: ParseErrorList // errors found while tokenising

    private var state: TokeniserState = TokeniserState.Data // current tokenisation state
    private var emitPending: ?Token = None // the token we are about to emit on next read
    private var isEmitPending: Bool = false
    private var CharsString: ?String = None // Characters pending an emit. Will fall to CharsBuilder if more than one
    private let CharsBuilder: StringBuilder = StringBuilder() // buffers Characters to output as one token, if more than one emit per read
    let dataBuffer: StringBuilder = StringBuilder() // buffers data looking for </script>

    let startPending: StartTagToken = StartTagToken()
    let endPending: EndTagToken = EndTagToken()
    var tagPending: TagToken = startPending // tag we are building up: start or end pending
    let CharPending: CharacterToken = CharacterToken()
    let doctypePending: DoctypeToken = DoctypeToken() // doctype building up
    let commentPending: CommentToken = CommentToken() // comment building up
    private var lastStartTag: ?String = None // the last start tag emitted, to test appropriate end tag
    private var lastStartCloseSeq: ?String = None // "</" + lastStartTag, so we can quickly check for that in RCData

    private static let Unset: Int64 = -1
    private var markupStartPos: Int64 = Unset // reader pos at the start of markup / Characters. updated on state transition
    private var CharStartPos: Int64 = Unset

    init(reader: CharacterReader, errors: ParseErrorList) {
        this.reader = reader
        this.errors = errors
    }

    func read(): Token {
        while (!isEmitPending) {
            state.read(this, reader)
        }

        // if emit is pending, a non-Character token was found: return any Chars in buffer, and leave token for next read:
        let cb: StringBuilder = this.CharsBuilder
        if (cb.size != 0) {
            let str: String = cb.toString()
            cb.reset()
            let token: Token = CharPending.data(str)
            CharsString = None
            return token
        } else if (CharsString != None) {
            let token: Token = CharPending.data(CharsString())
            CharsString = None
            return token
        } else {
            isEmitPending = false
            Validate.notNull(emitPending)
            return emitPending()
        }
    }

    func emit(token: Token): Unit {
        Validate.isFalse(isEmitPending)

        emitPending = token
        isEmitPending = true
        token.startPos(markupStartPos)
        token.endPos(reader.pos())
        CharStartPos = Unset

        if (token.typ == TokenType.StartTagType) {
            let startTag: StartTagToken = token.asStartTag()
            lastStartTag = startTag.tagName
            lastStartCloseSeq = None // only lazy inits
        } else if (token.typ == TokenType.EndTagType) {
            let endTag: EndTagToken = token.asEndTag()
            if (endTag.hasAttributes()) {
                error("Attributes incorrectly present on end tag [/${endTag.normalName()}]")
            }
        }
    }

    func emit(str: String): Unit {
        // buffer strings up until last string token found, to emit only one token for a run of Character refs etc.
        // does not set isEmitPending read checks that
        if (CharsString == None) {
            CharsString = str
        } else {
            if (CharsBuilder.size == 0) { // matching to string builder as more than one emit before read
                CharsBuilder.append(CharsString())
            }
            CharsBuilder.append(str)
        }
        CharPending.startPos(CharStartPos)
        CharPending.endPos(reader.pos())
    }

    // variations to limit need to create temp strings
    func emit(str: StringBuilder): Unit {
        if (CharsString == None) {
            CharsString = str.toString()
        } else {
            if (CharsBuilder.size == 0) {
                CharsBuilder.append(CharsString())
            }
            CharsBuilder.append(str)
        }
        CharPending.startPos(CharStartPos)
        CharPending.endPos(reader.pos())
    }

    func emit(c: Rune): Unit {
        if (CharsString == None) {
            CharsString = c.toString()
        } else {
            if (CharsBuilder.size == 0) {
                CharsBuilder.append(CharsString())
            }
            CharsBuilder.append(c)
        }
        CharPending.startPos(CharStartPos)
        CharPending.endPos(reader.pos())
    }

    func emit(chars: Array<Rune>): Unit {
        emit(String(chars))
    }

    func transition(newState: TokeniserState): Unit {
        // track markup / data position on state transitions
        if (newState is TagOpenState) {
            markupStartPos = reader.pos()
        } else if (newState is DataState && CharStartPos == Unset) {
            // don't reset when we are jumping between e.g data -> Rune ref -> data
            CharStartPos = reader.pos()
        }

        this.state = newState
    }

    func advanceTransition(newState: TokeniserState): Unit {
        transition(newState)
        reader.advance()
    }

    private let codepointHolder: Array<Rune> = [TokeniserState.nullChar] // holder to not have to keep creating arrays
    private let multipointHolder: Array<Rune> = [TokeniserState.nullChar, TokeniserState.nullChar]

    func consumeCharacterReference(additionalAllowedCharacter: ?Rune, inAttribute: Bool): ?Array<Rune> {
        if (reader.isEmpty()) {
            return None
        }
        if (additionalAllowedCharacter != None) {
            if (additionalAllowedCharacter == reader.current()) {
                return None
            }
        }
        if (reader.matchesAnySorted(notCharRefCharsSorted)) {
            return None
        }

        let charHolder: Array<Rune> = codepointHolder
        reader.mark()
        if (reader.matchConsume("#")) { // numbered
            return consumeCharacterReferenceMatchSharp(charHolder)
        } else { // named
            return consumeCharacterReferenceElse(charHolder, inAttribute)
        }
    }
    private func consumeCharacterReferenceMatchSharp(charHolder: Array<Rune>): ?Array<Rune> {
        let isHexMode: Bool = reader.matchConsumeIgnoreCase("X")
        let numRef: String = if (isHexMode) {
            reader.consumeHexSequence()
        } else {
            reader.consumeDigitSequence()
        }
        if (numRef.size == 0) { // didn't match anything
            characterReferenceError("numeric reference with no numerals")
            reader.rewindToMark()
            return None
        }

        reader.unmark()
        if (!reader.matchConsume(";")) {
            characterReferenceError("missing semicolon on [&#${numRef}]") // missing semi
        }
        var charval: Int64 = try {
            Int64.parse(if (isHexMode) {
                "0x${numRef}"
            } else {
                numRef
            })
        } catch (ignored: IllegalArgumentException) {
            -1
        }
        if (charval == -1 || (charval >= 0xD800 && charval <= 0xDFFF) || charval > 0x10FFFF) {
            characterReferenceError("character [${charval}] outside of valid range")
            charHolder[0] = replacementChar
        } else {
            // fix illegal unicode Characters to match browser behavior
            if (charval >= win1252ExtensionsStart && charval < win1252ExtensionsStart + win1252Extensions.size) {
                characterReferenceError("Character [${charval}] is not a valid unicode code point")
                charval = win1252Extensions[charval - win1252ExtensionsStart]
            }

            let c = Rune.parse("'\\u{${charval.format("x")}}'")
            charHolder[0] = c
        }
        return charHolder
    }
    private func consumeCharacterReferenceElse(charHolder: Array<Rune>, inAttribute: Bool): ?Array<Rune> {
        // get as many letters as possible, and look for matching entities.
        let nameRef: String = reader.consumeLetterThenDigitSequence()
        let looksLegit: Bool = reader.matches(r';')

        // found if a base named entity without a , or an extended entity with the .
        let found: Bool = Entities.isBaseNamedEntity(nameRef) || (Entities.isNamedEntity(nameRef) && looksLegit)

        if (!found) {
            reader.rewindToMark()
            if (looksLegit) {
                // named with semicolon
                characterReferenceError("invalid named reference [${nameRef}]")
            }
            return None
        }
        if (inAttribute) {
            if (reader.matchesLetter()) {
                // don't want that to match
                reader.rewindToMark()
                return None
            } else if (reader.matchesDigit()) {
                // don't want that to match
                reader.rewindToMark()
                return None
            } else if (reader.matchesAny(r'=', r'-', r'_')) {
                // don't want that to match
                reader.rewindToMark()
                return None
            }
        }

        reader.unmark()
        if (!reader.matchConsume(";")) {
            characterReferenceError("missing semicolon on [&${nameRef}]") // missing semi
        }
        let numChars: Int64 = Entities.codepointsForName(nameRef, multipointHolder)
        if (numChars == 1) {
            charHolder[0] = multipointHolder[0]
            return charHolder
        } else if (numChars == 2) {
            return multipointHolder
        } else {
            Validate.fail("Unexpected Characters returned for ${nameRef}")
            return multipointHolder
        }
    }

    func createTagPending(start: Bool): TagToken {
        tagPending = if (start) {
            startPending.reset()
        } else {
            endPending.reset()
        }
        return tagPending
    }

    func emitTagPending(): Unit {
        tagPending.finaliseTag()
        emit(tagPending)
    }

    func createCommentPending(): Unit {
        commentPending.reset()
    }

    func emitCommentPending(): Unit {
        emit(commentPending)
    }

    func createBogusCommentPending(): Unit {
        commentPending.reset()
        commentPending.bogus = true
    }

    func createDoctypePending(): Unit {
        doctypePending.reset()
    }

    func emitDoctypePending(): Unit {
        emit(doctypePending)
    }

    func createTempBuffer(): Unit {
        dataBuffer.reset()
    }

    func isAppropriateEndTagToken(): Bool {
        if (lastStartTag != None) {
            if (tagPending.name().equalsIgnoreCase(lastStartTag())) {
                return true
            }
        }
        return false
    }

    func appropriateEndTagName(): ?String {
        // could be null
        return lastStartTag
    }

    /* Returns the closer sequence </lastStart */
    func appropriateEndTagSeq(): String {
        if (lastStartCloseSeq == None) {
            // reset on start tag emit
            lastStartCloseSeq = "</" + lastStartTag()
        }
        return lastStartCloseSeq()
    }
    func error(state: TokeniserState): Unit {
        if (errors.canAddError()) {
            errors.add(
                ParseError(reader, "Unexpected Character '${reader.current()}' in input state [${state.toString()}]"))
        }
    }

    func eofError(state: TokeniserState): Unit {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, "Unexpectedly reached end of file (EOF) in input state [${state}]"))
        }
    }

    private func characterReferenceError(message: String): Unit {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, "Invalid character reference: " + message))
        }
    }
    func error(errorMsg: String): Unit {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, errorMsg))
        }
    }

    // func currentNodeInHtmlNS(): Bool {
    //     return true
    // }

    /*
     * Utility method to consume reader and unescape entities found within.
     * @param inAttribute if the text to be unescaped is in an attribute
     * @return unescaped string from reader
     */
    func unescapeEntities(inAttribute: Bool): String {
        let builder: StringBuilder = StringUtil.borrowBuilder()
        while (!reader.isEmpty()) {
            builder.append(reader.consumeTo(r'&'))
            if (reader.matches(r'&')) {
                reader.consume()
                let c = consumeCharacterReference(Option<Rune>.None, inAttribute)
                if (c == None) {
                    builder.append(r'&')
                } else {
                    builder.append(c())
                }
            }
        }
        return StringUtil.releaseBuilder(builder)
    }
}
