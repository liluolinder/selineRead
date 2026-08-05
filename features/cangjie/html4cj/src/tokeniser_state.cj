/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

abstract class TokeniserState <: ToString {
    static let nullChar: Rune = r'\u{0}'
    public static let attributeNameCharsSorted: Array<Rune> = [r'\t', r'\n', r'\f', r'\r', r' ', r'"', r'\'', r'/', r'<', r'=', r'>']
    public static let attributeValueUnquoted: Array<Rune> = [
        nullChar,
        r'\t',
        r'\n',
        r'\f',
        r'\r',
        r' ',
        r'"',
        r'&',
        r'\'',
        r'<',
        r'=',
        r'>',
        r'`'
    ]
    protected static let replacementChar: Rune = Tokeniser.replacementChar
    protected static let replacementStr: String = Tokeniser.replacementChar.toString()
    protected static let eof: Rune = CharacterReader.EOF

    static let Data = DataState()
    static let CharacterReferenceInData = CharacterReferenceInDataState()
    static let Rcdata = RcdataState()
    static let CharacterReferenceInRcdata = CharacterReferenceInRcdataState()
    static let Rawtext = RawtextState()
    static let ScriptData = ScriptDataState()
    static let PLAINTEXT = PLAINTEXTState()
    static let TagOpen = TagOpenState()
    static let EndTagOpen = EndTagOpenState()
    static let TagName = TagNameState()
    static let RcdataLessthanSign = RcdataLessthanSignState()
    static let RCDATAEndTagOpen = RCDATAEndTagOpenState()
    static let RCDATAEndTagName = RCDATAEndTagNameState()
    static let RawtextLessthanSign = RawtextLessthanSignState()
    static let RawtextEndTagOpen = RawtextEndTagOpenState()
    static let RawtextEndTagName = RawtextEndTagNameState()
    static let ScriptDataLessthanSign = ScriptDataLessthanSignState()
    static let ScriptDataEndTagOpen = ScriptDataEndTagOpenState()
    static let ScriptDataEndTagName = ScriptDataEndTagNameState()
    static let ScriptDataEscapeStart = ScriptDataEscapeStartState()
    static let ScriptDataEscapeStartDash = ScriptDataEscapeStartDashState()
    static let ScriptDataEscaped = ScriptDataEscapedState()
    static let ScriptDataEscapedDash = ScriptDataEscapedDashState()
    static let ScriptDataEscapedDashDash = ScriptDataEscapedDashDashState()
    static let ScriptDataEscapedLessthanSign = ScriptDataEscapedLessthanSignState()
    static let ScriptDataEscapedEndTagOpen = ScriptDataEscapedEndTagOpenState()
    static let ScriptDataEscapedEndTagName = ScriptDataEscapedEndTagNameState()
    static let ScriptDataDoubleEscapeStart = ScriptDataDoubleEscapeStartState()
    static let ScriptDataDoubleEscaped = ScriptDataDoubleEscapedState()
    static let ScriptDataDoubleEscapedDash = ScriptDataDoubleEscapedDashState()
    static let ScriptDataDoubleEscapedDashDash = ScriptDataDoubleEscapedDashDashState()
    static let ScriptDataDoubleEscapedLessthanSign = ScriptDataDoubleEscapedLessthanSignState()
    static let ScriptDataDoubleEscapeEnd = ScriptDataDoubleEscapeEndState()
    static let BeforeAttributeName = BeforeAttributeNameState()
    static let AttributeName = AttributeNameState()
    static let AfterAttributeName = AfterAttributeNameState()
    static let BeforeAttributeValue = BeforeAttributeValueState()
    static let AttributeValue_doubleQuoted = AttributeValue_doubleQuotedState()
    static let AttributeValue_singleQuoted = AttributeValue_singleQuotedState()
    static let AttributeValue_unquoted = AttributeValue_unquotedState()
    static let AfterAttributeValue_quoted = AfterAttributeValue_quotedState()
    static let SelfClosingStartTag = SelfClosingStartTagState()
    static let BogusComment = BogusCommentState()
    static let MarkupDeclarationOpen = MarkupDeclarationOpenState()
    static let CommentStart = CommentStartState()
    static let CommentStartDash = CommentStartDashState()
    static let CommentState = CommentStateState()
    static let CommentEndDash = CommentEndDashState()
    static let CommentEnd = CommentEndState()
    static let CommentEndBang = CommentEndBangState()
    static let Doctype = DoctypeStateState()
    static let BeforeDoctypeName = BeforeDoctypeNameState()
    static let DoctypeName = DoctypeNameState()
    static let AfterDoctypeName = AfterDoctypeNameState()
    static let AfterDoctypePublicKeyword = AfterDoctypePublicKeywordState()
    static let BeforeDoctypePublicIdentifier = BeforeDoctypePublicIdentifierState()
    static let DoctypePublicIdentifier_doubleQuoted = DoctypePublicIdentifier_doubleQuotedState()
    static let DoctypePublicIdentifier_singleQuoted = DoctypePublicIdentifier_singleQuotedState()
    static let AfterDoctypePublicIdentifier = AfterDoctypePublicIdentifierState()
    static let BetweenDoctypePublicAndSystemIdentifiers = BetweenDoctypePublicAndSystemIdentifiersState()
    static let AfterDoctypeSystemKeyword = AfterDoctypeSystemKeywordState()
    static let BeforeDoctypeSystemIdentifier = BeforeDoctypeSystemIdentifierState()
    static let DoctypeSystemIdentifier_doubleQuoted = DoctypeSystemIdentifier_doubleQuotedState()
    static let DoctypeSystemIdentifier_singleQuoted = DoctypeSystemIdentifier_singleQuotedState()
    static let AfterDoctypeSystemIdentifier = AfterDoctypeSystemIdentifierState()
    static let BogusDoctype = BogusDoctypeState()
    static let CdataSection = CdataSectionState()

    public func toString(): String {
        match {
            case this is DataState => "Data"
            case this is CharacterReferenceInDataState => "CharacterReferenceInData"
            case this is RcdataState => "Rcdata"
            case this is CharacterReferenceInRcdataState => "CharacterReferenceInRcdata"
            case this is RawtextState => "Rawtext"
            case this is ScriptDataState => "ScriptData"
            case this is PLAINTEXTState => "PLAINTEXT"
            case this is TagOpenState => "TagOpen"
            case this is EndTagOpenState => "EndTagOpen"
            case this is TagNameState => "TagName"
            case this is RcdataLessthanSignState => "RcdataLessthanSign"
            case this is RCDATAEndTagOpenState => "RCDATAEndTagOpen"
            case this is RCDATAEndTagNameState => "RCDATAEndTagName"
            case this is RawtextLessthanSignState => "RawtextLessthanSign"
            case this is RawtextEndTagOpenState => "RawtextEndTagOpen"
            case this is RawtextEndTagNameState => "RawtextEndTagName"
            case this is ScriptDataLessthanSignState => "ScriptDataLessthanSign"
            case this is ScriptDataEndTagOpenState => "ScriptDataEndTagOpen"
            case this is ScriptDataEndTagNameState => "ScriptDataEndTagName"
            case this is ScriptDataEscapeStartState => "ScriptDataEscapeStart"
            case this is ScriptDataEscapeStartDashState => "ScriptDataEscapeStartDash"
            case this is ScriptDataEscapedState => "ScriptDataEscaped"
            case this is ScriptDataEscapedDashState => "ScriptDataEscapedDash"
            case this is ScriptDataEscapedDashDashState => "ScriptDataEscapedDashDash"
            case this is ScriptDataEscapedLessthanSignState => "ScriptDataEscapedLessthanSign"
            case this is ScriptDataEscapedEndTagOpenState => "ScriptDataEscapedEndTagOpen"
            case this is ScriptDataEscapedEndTagNameState => "ScriptDataEscapedEndTagName"
            case this is ScriptDataDoubleEscapeStartState => "ScriptDataDoubleEscapeStart"
            case this is ScriptDataDoubleEscapedState => "ScriptDataDoubleEscaped"
            case this is ScriptDataDoubleEscapedDashState => "ScriptDataDoubleEscapedDash"
            case this is ScriptDataDoubleEscapedDashDashState => "ScriptDataDoubleEscapedDashDash"
            case this is ScriptDataDoubleEscapedLessthanSignState => "ScriptDataDoubleEscapedLessthanSign"
            case this is ScriptDataDoubleEscapeEndState => "ScriptDataDoubleEscapeEnd"
            case this is BeforeAttributeNameState => "BeforeAttributeName"
            case this is AttributeNameState => "AttributeName"
            case _ => toStringOtherCase()
        }
    }
    private func toStringOtherCase(): String {
        match {
            case this is AfterAttributeNameState => "AfterAttributeName"
            case this is BeforeAttributeValueState => "BeforeAttributeValue"
            case this is AttributeValue_doubleQuotedState => "AttributeValue_doubleQuoted"
            case this is AttributeValue_singleQuotedState => "AttributeValue_singleQuoted"
            case this is AttributeValue_unquotedState => "AttributeValue_unquoted"
            case this is AfterAttributeValue_quotedState => "AfterAttributeValue_quoted"
            case this is SelfClosingStartTagState => "SelfClosingStartTag"
            case this is BogusCommentState => "BogusComment"
            case this is MarkupDeclarationOpenState => "MarkupDeclarationOpen"
            case this is CommentStartState => "CommentStart"
            case this is CommentStartDashState => "CommentStartDash"
            case this is CommentStateState => "CommentState"
            case this is CommentEndDashState => "CommentEndDash"
            case this is CommentEndState => "CommentEnd"
            case this is CommentEndBangState => "CommentEndBang"
            case this is DoctypeStateState => "Doctype"
            case this is BeforeDoctypeNameState => "BeforeDoctypeName"
            case this is DoctypeNameState => "DoctypeName"
            case this is AfterDoctypeNameState => "AfterDoctypeName"
            case this is AfterDoctypePublicKeywordState => "AfterDoctypePublicKeyword"
            case this is BeforeDoctypePublicIdentifierState => "BeforeDoctypePublicIdentifier"
            case this is DoctypePublicIdentifier_doubleQuotedState => "DoctypePublicIdentifier_doubleQuoted"
            case this is DoctypePublicIdentifier_singleQuotedState => "DoctypePublicIdentifier_singleQuoted"
            case this is AfterDoctypePublicIdentifierState => "AfterDoctypePublicIdentifier"
            case this is BetweenDoctypePublicAndSystemIdentifiersState => "BetweenDoctypePublicAndSystemIdentifiers"
            case this is AfterDoctypeSystemKeywordState => "AfterDoctypeSystemKeyword"
            case this is BeforeDoctypeSystemIdentifierState => "BeforeDoctypeSystemIdentifier"
            case this is DoctypeSystemIdentifier_doubleQuotedState => "DoctypeSystemIdentifier_doubleQuoted"
            case this is DoctypeSystemIdentifier_singleQuotedState => "DoctypeSystemIdentifier_singleQuoted"
            case this is AfterDoctypeSystemIdentifierState => "AfterDoctypeSystemIdentifier"
            case this is BogusDoctypeState => "BogusDoctype"
            case this is CdataSectionState => "CdataSection"
            case _ => throw ParseException("Not supported type")
        }
    }

    protected open func read(tker: Tokeniser, r: CharacterReader): Unit

    /*
     * Handles RawtextEndTagName, ScriptDataEndTagName, and ScriptDataEscapedEndTagName. Same body impl, just
     * different else exit transitions.
     */
    protected static func handleDataEndTag(tker: Tokeniser, r: CharacterReader, elseTransition: TokeniserState): Unit {
        if (r.matchesLetter()) {
            let name: String = r.consumeLetterSequence()
            tker.tagPending.appendTagName(name)
            tker.dataBuffer.append(name)
            return
        }

        var needsExitTransition: Bool = false
        var doChar: Bool = false
        if (tker.isAppropriateEndTagToken()) {
            if (!r.isEmpty()) {
                doChar = true
            }
        }
        if (doChar) {
            let c: Rune = r.consume()
            match (c) {
                case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeAttributeName)
                case r'/' => tker.transition(SelfClosingStartTag)
                case r'>' =>
                    tker.emitTagPending()
                    tker.transition(Data)
                case _ =>
                    tker.dataBuffer.append(c)
                    needsExitTransition = true
            }
        } else {
            needsExitTransition = true
        }

        if (needsExitTransition) {
            tker.emit("</")
            tker.emit(tker.dataBuffer)
            tker.transition(elseTransition)
        }
    }

    protected static func readRawData(
        tker: Tokeniser,
        r: CharacterReader,
        current: TokeniserState,
        advance: TokeniserState
    ): Unit {
        match (r.current()) {
            case r'<' => tker.advanceTransition(advance)
            case v where v == nullChar =>
                tker.error(current)
                r.advance()
                tker.emit(replacementChar)
            case v where v == eof => tker.emit(EOFToken())
            case _ =>
                let data: String = r.consumeRawData()
                tker.emit(data)
        }
    }

    protected static func readCharRef(tker: Tokeniser, advance: TokeniserState): Unit {
        let c = tker.consumeCharacterReference(None, false)
        if (c == None) {
            tker.emit(r'&')
        } else {
            tker.emit(c())
        }
        tker.transition(advance)
    }

    protected static func readEndTag(tker: Tokeniser, r: CharacterReader, a: TokeniserState, b: TokeniserState): Unit {
        if (r.matchesAsciiAlpha()) {
            tker.createTagPending(false)
            tker.transition(a)
        } else {
            tker.emit("</")
            tker.transition(b)
        }
    }

    protected static func handleDataDoubleEscapeTag(
        tker: Tokeniser,
        r: CharacterReader,
        primary: TokeniserState,
        fallback: TokeniserState
    ): Unit {
        if (r.matchesLetter()) {
            let name: String = r.consumeLetterSequence()
            tker.dataBuffer.append(name)
            tker.emit(name)
            return
        }

        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' | r'/' | r'>' =>
                if (tker.dataBuffer.toString().equals("script")) {
                    tker.transition(primary)
                } else {
                    tker.transition(fallback)
                }
                tker.emit(c)
            case _ =>
                r.unconsume()
                tker.transition(fallback)
        }
    }
}

class DataState <: TokeniserState {
    // in data state, gather characters until a character reference or tag is found
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        match (r.current()) {
            case r'&' => tker.advanceTransition(CharacterReferenceInData)
            case r'<' => tker.advanceTransition(TagOpen)
            case v where v == nullChar =>
                tker.error(this) // NOT replacement character (oddly?)
                tker.emit(r.consume())
            case v where v == eof => tker.emit(EOFToken())
            case _ =>
                let data = r.consumeData()
                tker.emit(data)
        }
    }
}

class CharacterReferenceInDataState <: TokeniserState {
    // from & in data
    protected func read(tker: Tokeniser, _: CharacterReader): Unit {
        readCharRef(tker, Data)
    }
}

class RcdataState <: TokeniserState {
    // handles data in title, textarea etc
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        match (r.current()) {
            case r'&' => tker.advanceTransition(CharacterReferenceInRcdata)
            case r'<' => tker.advanceTransition(RcdataLessthanSign)
            case v where v == nullChar =>
                tker.error(this)
                r.advance()
                tker.emit(replacementChar)
            case v where v == eof => tker.emit(EOFToken())
            case _ =>
                let data = r.consumeData()
                tker.emit(data)
        }
    }
}

class CharacterReferenceInRcdataState <: TokeniserState {
    protected func read(tker: Tokeniser, _: CharacterReader): Unit {
        readCharRef(tker, Rcdata)
    }
}

class RawtextState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        readRawData(tker, r, this, RawtextLessthanSign)
    }
}

class ScriptDataState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        readRawData(tker, r, this, ScriptDataLessthanSign)
    }
}

class PLAINTEXTState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        match (r.current()) {
            case v where v == nullChar =>
                tker.error(this)
                r.advance()
                tker.emit(replacementChar)
            case v where v == eof => tker.emit(EOFToken())
            case _ =>
                let data = r.consumeTo(nullChar)
                tker.emit(data)
        }
    }
}

class TagOpenState <: TokeniserState {
    // from < in data
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        match (r.current()) {
            case r'!' => tker.advanceTransition(MarkupDeclarationOpen)
            case r'/' => tker.advanceTransition(EndTagOpen)
            case r'?' =>
                tker.createBogusCommentPending()
                tker.transition(BogusComment)
            case _ =>
                if (r.matchesAsciiAlpha()) {
                    tker.createTagPending(true)
                    tker.transition(TagName)
                } else {
                    tker.error(this)
                    tker.emit(r'<') // char that got us here
                    tker.transition(Data)
                }
        }
    }
}

class EndTagOpenState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.isEmpty()) {
            tker.eofError(this)
            tker.emit("</")
            tker.transition(Data)
        } else if (r.matchesAsciiAlpha()) {
            tker.createTagPending(false)
            tker.transition(TagName)
        } else if (r.matches(r'>')) {
            tker.error(this)
            tker.advanceTransition(Data)
        } else {
            tker.error(this)
            tker.createBogusCommentPending()
            tker.commentPending.append(r'/') // push the / back on that got us here
            tker.transition(BogusComment)
        }
    }
}

class TagNameState <: TokeniserState {
    // from < or </ in data, will have start or end tag pending
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        // previous TagOpen state did NOT consume, will have a letter char in current
        let tagName = r.consumeTagName()
        tker.tagPending.appendTagName(tagName)

        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeAttributeName)
            case r'/' => tker.transition(SelfClosingStartTag)
            case r'<' =>
                // NOTE=> out of spec, but clear author intent
                r.unconsume()
                tker.error(this)

                // intended fall through to next >
                tker.emitTagPending()
                tker.transition(Data)
            case r'>' =>
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == nullChar => // replacement
                tker.tagPending.appendTagName(replacementStr)
            case v where v == eof =>
                // should emit pending tag?
                tker.eofError(this)
                tker.transition(Data)
            case _ => // buffer underrun
                tker.tagPending.appendTagName(c)
        }
    }
}

class RcdataLessthanSignState <: TokeniserState {
    // from < in rcdata
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        var isEmit: Int64 = 0
        if (r.matches(r'/')) {
            tker.createTempBuffer()
            tker.advanceTransition(RCDATAEndTagOpen)
            isEmit = 1
        } else if (r.matchesAsciiAlpha()) {
            if (tker.appropriateEndTagName() != None) {
                if (!r.containsIgnoreCase(tker.appropriateEndTagSeq())) {
                    isEmit = 2
                }
            }
        }
        if (isEmit == 2) {
            // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), 
            // so rather than consuming to EOF break out here
            tker.tagPending = tker.createTagPending(false).name(tker.appropriateEndTagName()())
            tker.emitTagPending()
            tker.transition(TagOpen) // straight into TagOpen, as we came from < and looks like we're on a start tag
        } else if (isEmit == 0) {
            tker.emit("<")
            tker.transition(Rcdata)
        }
    }
}

class RCDATAEndTagOpenState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchesAsciiAlpha()) {
            tker.createTagPending(false)
            tker.tagPending.appendTagName(r.current())
            tker.dataBuffer.append(r.current())
            tker.advanceTransition(RCDATAEndTagName)
        } else {
            tker.emit("</")
            tker.transition(Rcdata)
        }
    }
}

class RCDATAEndTagNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchesAsciiAlpha()) {
            let name = r.consumeLetterSequence()
            tker.tagPending.appendTagName(name)
            tker.dataBuffer.append(name)
            return
        }

        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' =>
                if (tker.isAppropriateEndTagToken()) {
                    tker.transition(BeforeAttributeName)
                } else {
                    anythingElse(tker, r)
                }
            case r'/' =>
                if (tker.isAppropriateEndTagToken()) {
                    tker.transition(SelfClosingStartTag)
                } else {
                    anythingElse(tker, r)
                }
            case r'>' =>
                if (tker.isAppropriateEndTagToken()) {
                    tker.emitTagPending()
                    tker.transition(Data)
                } else {
                    anythingElse(tker, r)
                }
            case _ => anythingElse(tker, r)
        }
    }
    private func anythingElse(tker: Tokeniser, r: CharacterReader) {
        tker.emit("</")
        tker.emit(tker.dataBuffer)
        r.unconsume()
        tker.transition(Rcdata)
    }
}

class RawtextLessthanSignState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matches(r'/')) {
            tker.createTempBuffer()
            tker.advanceTransition(RawtextEndTagOpen)
        } else {
            tker.emit(r'<')
            tker.transition(Rawtext)
        }
    }
}

class RawtextEndTagOpenState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        readEndTag(tker, r, RawtextEndTagName, Rawtext)
    }
}

class RawtextEndTagNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        handleDataEndTag(tker, r, Rawtext)
    }
}

class ScriptDataLessthanSignState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'/' =>
                tker.createTempBuffer()
                tker.transition(ScriptDataEndTagOpen)
            case r'!' =>
                tker.emit("<!")
                tker.transition(ScriptDataEscapeStart)
            case v where v == eof =>
                tker.emit("<")
                tker.eofError(this)
                tker.transition(Data)
            case _ =>
                tker.emit("<")
                r.unconsume()
                tker.transition(ScriptData)
        }
    }
}

class ScriptDataEndTagOpenState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        readEndTag(tker, r, ScriptDataEndTagName, ScriptData)
    }
}

class ScriptDataEndTagNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        handleDataEndTag(tker, r, ScriptData)
    }
}

class ScriptDataEscapeStartState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matches(r'-')) {
            tker.emit(r'-')
            tker.advanceTransition(ScriptDataEscapeStartDash)
        } else {
            tker.transition(ScriptData)
        }
    }
}

class ScriptDataEscapeStartDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matches(r'-')) {
            tker.emit(r'-')
            tker.advanceTransition(ScriptDataEscapedDashDash)
        } else {
            tker.transition(ScriptData)
        }
    }
}

class ScriptDataEscapedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.isEmpty()) {
            tker.eofError(this)
            tker.transition(Data)
            return
        }
        let c = r.current()
        match (c) {
            case r'-' =>
                tker.emit(r'-')
                tker.advanceTransition(ScriptDataEscapedDash)
            case r'<' => tker.advanceTransition(ScriptDataEscapedLessthanSign)
            case v where v == nullChar =>
                tker.error(this)
                r.advance()
                tker.emit(replacementChar)
            case _ =>
                let data = r.consumeToAny(r'-', r'<', nullChar)
                tker.emit(data)
        }
    }
}

class ScriptDataEscapedDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.isEmpty()) {
            tker.eofError(this)
            tker.transition(Data)
            return
        }
        let c = r.consume()
        match (c) {
            case r'-' =>
                tker.emit(c)
                tker.transition(ScriptDataEscapedDashDash)
            case r'<' => tker.transition(ScriptDataEscapedLessthanSign)
            case v where v == nullChar =>
                tker.error(this)
                tker.emit(replacementChar)
                tker.transition(ScriptDataEscaped)
            case _ =>
                tker.emit(c)
                tker.transition(ScriptDataEscaped)
        }
    }
}

class ScriptDataEscapedDashDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.isEmpty()) {
            tker.eofError(this)
            tker.transition(Data)
            return
        }
        let c = r.consume()
        match (c) {
            case r'-' => tker.emit(c)
            case r'<' => tker.transition(ScriptDataEscapedLessthanSign)
            case r'>' =>
                tker.emit(c)
                tker.transition(ScriptData)
            case v where v == nullChar =>
                tker.error(this)
                tker.emit(replacementChar)
                tker.transition(ScriptDataEscaped)
            case _ =>
                tker.emit(c)
                tker.transition(ScriptDataEscaped)
        }
    }
}

class ScriptDataEscapedLessthanSignState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchesAsciiAlpha()) {
            tker.createTempBuffer()
            tker.dataBuffer.append(r.current())
            tker.emit("<")
            tker.emit(r.current())
            tker.advanceTransition(ScriptDataDoubleEscapeStart)
        } else if (r.matches(r'/')) {
            tker.createTempBuffer()
            tker.advanceTransition(ScriptDataEscapedEndTagOpen)
        } else {
            tker.emit(r'<')
            tker.transition(ScriptDataEscaped)
        }
    }
}

class ScriptDataEscapedEndTagOpenState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchesAsciiAlpha()) {
            tker.createTagPending(false)
            tker.tagPending.appendTagName(r.current())
            tker.dataBuffer.append(r.current())
            tker.advanceTransition(ScriptDataEscapedEndTagName)
        } else {
            tker.emit("</")
            tker.transition(ScriptDataEscaped)
        }
    }
}

class ScriptDataEscapedEndTagNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        handleDataEndTag(tker, r, ScriptDataEscaped)
    }
}

class ScriptDataDoubleEscapeStartState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        handleDataDoubleEscapeTag(tker, r, ScriptDataDoubleEscaped, ScriptDataEscaped)
    }
}

class ScriptDataDoubleEscapedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.current()
        match (c) {
            case r'-' =>
                tker.emit(c)
                tker.advanceTransition(ScriptDataDoubleEscapedDash)
            case r'<' =>
                tker.emit(c)
                tker.advanceTransition(ScriptDataDoubleEscapedLessthanSign)
            case v where v == nullChar =>
                tker.error(this)
                r.advance()
                tker.emit(replacementChar)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ =>
                let data = r.consumeToAny(r'-', r'<', nullChar)
                tker.emit(data)
        }
    }
}

class ScriptDataDoubleEscapedDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'-' =>
                tker.emit(c)
                tker.transition(ScriptDataDoubleEscapedDashDash)
            case r'<' =>
                tker.emit(c)
                tker.transition(ScriptDataDoubleEscapedLessthanSign)
            case v where v == nullChar =>
                tker.error(this)
                tker.emit(replacementChar)
                tker.transition(ScriptDataDoubleEscaped)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ =>
                tker.emit(c)
                tker.transition(ScriptDataDoubleEscaped)
        }
    }
}

class ScriptDataDoubleEscapedDashDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'-' => tker.emit(c)
            case r'<' =>
                tker.emit(c)
                tker.transition(ScriptDataDoubleEscapedLessthanSign)
            case r'>' =>
                tker.emit(c)
                tker.transition(ScriptData)
            case v where v == nullChar =>
                tker.error(this)
                tker.emit(replacementChar)
                tker.transition(ScriptDataDoubleEscaped)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ =>
                tker.emit(c)
                tker.transition(ScriptDataDoubleEscaped)
        }
    }
}

class ScriptDataDoubleEscapedLessthanSignState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matches(r'/')) {
            tker.emit(r'/')
            tker.createTempBuffer()
            tker.advanceTransition(ScriptDataDoubleEscapeEnd)
        } else {
            tker.transition(ScriptDataDoubleEscaped)
        }
    }
}

class ScriptDataDoubleEscapeEndState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        handleDataDoubleEscapeTag(tker, r, ScriptDataEscaped, ScriptDataDoubleEscaped)
    }
}

class BeforeAttributeNameState <: TokeniserState {
    // from tagname <xxx
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => () // ignore whitespace
            case r'/' => tker.transition(SelfClosingStartTag)
            case r'<' =>
                // NOTE=> out of spec, but clear (spec has this as a part of the attribute name)
                r.unconsume()
                tker.error(this)

                // intended fall through as if >
                tker.emitTagPending()
                tker.transition(Data)
            case r'>' =>
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == nullChar =>
                r.unconsume()
                tker.error(this)
                tker.tagPending.newAttribute()
                tker.transition(AttributeName)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case r'"' | r'\'' | r'=' =>
                tker.error(this)
                tker.tagPending.newAttribute()
                tker.tagPending.appendAttributeName(c)
                tker.transition(AttributeName)
            case _ =>
                // A-Z, anything else
                tker.tagPending.newAttribute()
                r.unconsume()
                tker.transition(AttributeName)
        }
    }
}

class AttributeNameState <: TokeniserState {
    // from before attribute name
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let name = r.consumeToAnySorted(attributeNameCharsSorted) // spec deviate - consume and emit nulls in one hit vs stepping
        tker.tagPending.appendAttributeName(name)

        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(AfterAttributeName)
            case r'/' => tker.transition(SelfClosingStartTag)
            case r'=' => tker.transition(BeforeAttributeValue)
            case r'>' =>
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case r'"' | r'\'' | r'<' =>
                tker.error(this)
                tker.tagPending.appendAttributeName(c)
            case _ => // buffer underrun
                tker.tagPending.appendAttributeName(c)
        }
    }
}

class AfterAttributeNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => () // ignore
            case r'/' => tker.transition(SelfClosingStartTag)
            case r'=' => tker.transition(BeforeAttributeValue)
            case r'>' =>
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == nullChar =>
                tker.error(this)
                tker.tagPending.appendAttributeName(replacementChar)
                tker.transition(AttributeName)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case r'"' | r'\'' | r'<' =>
                tker.error(this)
                tker.tagPending.newAttribute()
                tker.tagPending.appendAttributeName(c)
                tker.transition(AttributeName)
            case _ =>
                // A-Z, anything else
                tker.tagPending.newAttribute()
                r.unconsume()
                tker.transition(AttributeName)
        }
    }
}

class BeforeAttributeValueState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => () // ignore
            case r'"' => tker.transition(AttributeValue_doubleQuoted)
            case r'&' =>
                r.unconsume()
                tker.transition(AttributeValue_unquoted)
            case r'\'' => tker.transition(AttributeValue_singleQuoted)
            case v where v == nullChar =>
                tker.error(this)
                tker.tagPending.appendAttributeValue(replacementChar)
                tker.transition(AttributeValue_unquoted)
            case v where v == eof =>
                tker.eofError(this)
                tker.emitTagPending()
                tker.transition(Data)
            case r'>' =>
                tker.error(this)
                tker.emitTagPending()
                tker.transition(Data)
            case r'<' | r'=' | r'`' =>
                tker.error(this)
                tker.tagPending.appendAttributeValue(c)
                tker.transition(AttributeValue_unquoted)
            case _ =>
                r.unconsume()
                tker.transition(AttributeValue_unquoted)
        }
    }
}

class AttributeValue_doubleQuotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let value = r.consumeAttributeQuoted(false)
        if (value.size > 0) {
            tker.tagPending.appendAttributeValue(value)
        } else {
            tker.tagPending.setEmptyAttributeValue()
        }

        let c = r.consume()
        match (c) {
            case r'"' => tker.transition(AfterAttributeValue_quoted)
            case r'&' =>
                let ref = tker.consumeCharacterReference(r'"', true)
                if (ref != None) {
                    tker.tagPending.appendAttributeValue(ref())
                } else {
                    tker.tagPending.appendAttributeValue(r'&')
                }
            case v where v == nullChar =>
                tker.error(this)
                tker.tagPending.appendAttributeValue(replacementChar)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ => // hit end of buffer in first read, still in attribute
                tker.tagPending.appendAttributeValue(c)
        }
    }
}

class AttributeValue_singleQuotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let value = r.consumeAttributeQuoted(true)
        if (value.size > 0) {
            tker.tagPending.appendAttributeValue(value)
        } else {
            tker.tagPending.setEmptyAttributeValue()
        }

        let c = r.consume()
        match (c) {
            case r'\'' => tker.transition(AfterAttributeValue_quoted)
            case r'&' =>
                let ref = tker.consumeCharacterReference(r'\'', true)
                if (ref != None) {
                    tker.tagPending.appendAttributeValue(ref())
                } else {
                    tker.tagPending.appendAttributeValue(r'&')
                }
            case v where v == nullChar =>
                tker.error(this)
                tker.tagPending.appendAttributeValue(replacementChar)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ => // hit end of buffer in first read, still in attribute
                tker.tagPending.appendAttributeValue(c)
        }
    }
}

class AttributeValue_unquotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let value = r.consumeToAnySorted(attributeValueUnquoted)
        if (value.size > 0) {
            tker.tagPending.appendAttributeValue(value)
        }

        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeAttributeName)
            case r'&' =>
                let ref = tker.consumeCharacterReference(r'>', true)
                if (ref != None) {
                    tker.tagPending.appendAttributeValue(ref())
                } else {
                    tker.tagPending.appendAttributeValue(r'&')
                }
            case r'>' =>
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == nullChar =>
                tker.error(this)
                tker.tagPending.appendAttributeValue(replacementChar)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case r'"' | r'\'' | r'<' | r'=' | r'`' =>
                tker.error(this)
                tker.tagPending.appendAttributeValue(c)
            case _ => // hit end of buffer in first read, still in attribute
                tker.tagPending.appendAttributeValue(c)
        }
    }
}

// CharacterReferenceInAttributeValue state handled inline
class AfterAttributeValue_quotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeAttributeName)
            case r'/' => tker.transition(SelfClosingStartTag)
            case r'>' =>
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ =>
                r.unconsume()
                tker.error(this)
                tker.transition(BeforeAttributeName)
        }
    }
}

class SelfClosingStartTagState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'>' =>
                tker.tagPending.selfClosing = true
                tker.emitTagPending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.transition(Data)
            case _ =>
                r.unconsume()
                tker.error(this)
                tker.transition(BeforeAttributeName)
        }
    }
}

class BogusCommentState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        tker.commentPending.append(r.consumeTo(r'>'))
        let next = r.current()
        if (next == r'>' || next == eof) {
            r.consume()
            tker.emitCommentPending()
            tker.transition(Data)
        }
    }
}

class MarkupDeclarationOpenState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchConsume("--")) {
            tker.createCommentPending()
            tker.transition(CommentStart)
        } else if (r.matchConsumeIgnoreCase("DOCTYPE")) {
            tker.transition(Doctype)
        } else if (r.matchConsume("[CDATA[")) {
            tker.createTempBuffer()
            tker.transition(CdataSection)
        } else {
            tker.error(this)
            tker.createBogusCommentPending()
            tker.transition(BogusComment)
        }
    }
}

class CommentStartState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'-' => tker.transition(CommentStartDash)
            case v where v == nullChar =>
                tker.error(this)
                tker.commentPending.append(replacementChar)
                tker.transition(CommentState)
            case r'>' =>
                tker.error(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case _ =>
                r.unconsume()
                tker.transition(CommentState)
        }
    }
}

class CommentStartDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'-' => tker.transition(CommentEnd)
            case v where v == nullChar =>
                tker.error(this)
                tker.commentPending.append(replacementChar)
                tker.transition(CommentState)
            case r'>' =>
                tker.error(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case _ =>
                tker.commentPending.append(c)
                tker.transition(CommentState)
        }
    }
}

class CommentStateState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.current()
        match (c) {
            case r'-' => tker.advanceTransition(CommentEndDash)
            case v where v == nullChar =>
                tker.error(this)
                r.advance()
                tker.commentPending.append(replacementChar)
            case v where v == eof =>
                tker.eofError(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case _ => tker.commentPending.append(r.consumeToAny([r'-', nullChar]))
        }
    }
}

class CommentEndDashState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'-' => tker.transition(CommentEnd)
            case v where v == nullChar =>
                tker.error(this)
                tker.commentPending.append(r'-').append(replacementChar)
                tker.transition(CommentState)
            case v where v == eof =>
                tker.eofError(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case _ =>
                tker.commentPending.append(r'-').append(c)
                tker.transition(CommentState)
        }
    }
}

class CommentEndState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'>' =>
                tker.emitCommentPending()
                tker.transition(Data)
            case v where v == nullChar =>
                tker.error(this)
                tker.commentPending.append("--").append(replacementChar)
                tker.transition(CommentState)
            case r'!' => tker.transition(CommentEndBang)
            case r'-' => tker.commentPending.append(r'-')
            case v where v == eof =>
                tker.eofError(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case _ =>
                tker.commentPending.append("--").append(c)
                tker.transition(CommentState)
        }
    }
}

class CommentEndBangState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'-' =>
                tker.commentPending.append("--!")
                tker.transition(CommentEndDash)
            case r'>' =>
                tker.emitCommentPending()
                tker.transition(Data)
            case v where v == nullChar =>
                tker.error(this)
                tker.commentPending.append("--!").append(replacementChar)
                tker.transition(CommentState)
            case v where v == eof =>
                tker.eofError(this)
                tker.emitCommentPending()
                tker.transition(Data)
            case _ =>
                tker.commentPending.append("--!").append(c)
                tker.transition(CommentState)
        }
    }
}

class DoctypeStateState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeDoctypeName)
            case v where v == eof =>
                tker.eofError(this)

                // note: fall through to > case
                tker.error(this)
                tker.createDoctypePending()
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case r'>' =>
                // catch invalid <!DOCTYPE>
                tker.error(this)
                tker.createDoctypePending()
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.transition(BeforeDoctypeName)
        }
    }
}

class BeforeDoctypeNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchesAsciiAlpha()) {
            tker.createDoctypePending()
            tker.transition(DoctypeName)
            return
        }
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => () // ignore whitespace
            case v where v == nullChar =>
                tker.error(this)
                tker.createDoctypePending()
                tker.doctypePending.name.append(replacementChar)
                tker.transition(DoctypeName)
            case v where v == eof =>
                tker.eofError(this)
                tker.createDoctypePending()
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.createDoctypePending()
                tker.doctypePending.name.append(c)
                tker.transition(DoctypeName)
        }
    }
}

class DoctypeNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.matchesLetter()) {
            let name = r.consumeLetterSequence()
            tker.doctypePending.name.append(name)
            return
        }
        let c = r.consume()
        match (c) {
            case r'>' =>
                tker.emitDoctypePending()
                tker.transition(Data)
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(AfterDoctypeName)
            case v where v == nullChar =>
                tker.error(this)
                tker.doctypePending.name.append(replacementChar)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ => tker.doctypePending.name.append(c)
        }
    }
}

class AfterDoctypeNameState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        if (r.isEmpty()) {
            tker.eofError(this)
            tker.doctypePending.forceQuirks = true
            tker.emitDoctypePending()
            tker.transition(Data)
            return
        }
        if (r.matchesAny(r'\t', r'\n', r'\r', r'\f', r' ')) {
            r.advance() // ignore whitespace
        } else if (r.matches(r'>')) {
            tker.emitDoctypePending()
            tker.advanceTransition(Data)
        } else if (r.matchConsumeIgnoreCase(DocumentType.PUBLIC_KEY)) {
            tker.doctypePending.pubSysKey = DocumentType.PUBLIC_KEY
            tker.transition(AfterDoctypePublicKeyword)
        } else if (r.matchConsumeIgnoreCase(DocumentType.SYSTEM_KEY)) {
            tker.doctypePending.pubSysKey = DocumentType.SYSTEM_KEY
            tker.transition(AfterDoctypeSystemKeyword)
        } else {
            tker.error(this)
            tker.doctypePending.forceQuirks = true
            tker.advanceTransition(BogusDoctype)
        }
    }
}

class AfterDoctypePublicKeywordState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeDoctypePublicIdentifier)
            case r'"' =>
                tker.error(this)

                // set public id to empty string
                tker.transition(DoctypePublicIdentifier_doubleQuoted)
            case r'\'' =>
                tker.error(this)

                // set public id to empty string
                tker.transition(DoctypePublicIdentifier_singleQuoted)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.transition(BogusDoctype)
        }
    }
}

class BeforeDoctypePublicIdentifierState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => ()
            case r'"' => // set public id to empty string
                tker.transition(DoctypePublicIdentifier_doubleQuoted)
            case r'\'' => // set public id to empty string
                tker.transition(DoctypePublicIdentifier_singleQuoted)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.transition(BogusDoctype)
        }
    }
}

class DoctypePublicIdentifier_doubleQuotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'"' => tker.transition(AfterDoctypePublicIdentifier)
            case v where v == nullChar =>
                tker.error(this)
                tker.doctypePending.publicIdentifier.append(replacementChar)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ => tker.doctypePending.publicIdentifier.append(c)
        }
    }
}

class DoctypePublicIdentifier_singleQuotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\'' => tker.transition(AfterDoctypePublicIdentifier)
            case v where v == nullChar =>
                tker.error(this)
                tker.doctypePending.publicIdentifier.append(replacementChar)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ => tker.doctypePending.publicIdentifier.append(c)
        }
    }
}

class AfterDoctypePublicIdentifierState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BetweenDoctypePublicAndSystemIdentifiers)
            case r'>' =>
                tker.emitDoctypePending()
                tker.transition(Data)
            case r'"' =>
                tker.error(this)

                // system id empty
                tker.transition(DoctypeSystemIdentifier_doubleQuoted)
            case r'\'' =>
                tker.error(this)

                // system id empty
                tker.transition(DoctypeSystemIdentifier_singleQuoted)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.transition(BogusDoctype)
        }
    }
}

class BetweenDoctypePublicAndSystemIdentifiersState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => ()
            case r'>' =>
                tker.emitDoctypePending()
                tker.transition(Data)
            case r'"' =>
                tker.error(this)

                // system id empty
                tker.transition(DoctypeSystemIdentifier_doubleQuoted)
            case r'\'' =>
                tker.error(this)

                // system id empty
                tker.transition(DoctypeSystemIdentifier_singleQuoted)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.transition(BogusDoctype)
        }
    }
}

class AfterDoctypeSystemKeywordState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => tker.transition(BeforeDoctypeSystemIdentifier)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case r'"' =>
                tker.error(this)

                // system id empty
                tker.transition(DoctypeSystemIdentifier_doubleQuoted)
            case r'\'' =>
                tker.error(this)

                // system id empty
                tker.transition(DoctypeSystemIdentifier_singleQuoted)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
        }
    }
}

class BeforeDoctypeSystemIdentifierState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => ()
            case r'"' => // set system id to empty string
                tker.transition(DoctypeSystemIdentifier_doubleQuoted)
            case r'\'' => // set public id to empty string
                tker.transition(DoctypeSystemIdentifier_singleQuoted)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.transition(BogusDoctype)
        }
    }
}

class DoctypeSystemIdentifier_doubleQuotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'"' => tker.transition(AfterDoctypeSystemIdentifier)
            case v where v == nullChar =>
                tker.error(this)
                tker.doctypePending.systemIdentifier.append(replacementChar)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ => tker.doctypePending.systemIdentifier.append(c)
        }
    }
}

class DoctypeSystemIdentifier_singleQuotedState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\'' => tker.transition(AfterDoctypeSystemIdentifier)
            case v where v == nullChar =>
                tker.error(this)
                tker.doctypePending.systemIdentifier.append(replacementChar)
            case r'>' =>
                tker.error(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ => tker.doctypePending.systemIdentifier.append(c)
        }
    }
}

class AfterDoctypeSystemIdentifierState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'\t' | r'\n' | r'\r' | r'\f' | r' ' => ()
            case r'>' =>
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.eofError(this)
                tker.doctypePending.forceQuirks = true
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ =>
                // NOT force quirks
                tker.error(this)
                tker.transition(BogusDoctype)
        }
    }
}

class BogusDoctypeState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let c = r.consume()
        match (c) {
            case r'>' =>
                tker.emitDoctypePending()
                tker.transition(Data)
            case v where v == eof =>
                tker.emitDoctypePending()
                tker.transition(Data)
            case _ => () // ignore char
        }
    }
}

class CdataSectionState <: TokeniserState {
    protected func read(tker: Tokeniser, r: CharacterReader): Unit {
        let data = r.consumeTo("]]>")
        tker.dataBuffer.append(data)

        // otherwise, buffer underrun, stay in data section
        if (r.matchConsume("]]>")) {
            tker.emit(CDataToken(tker.dataBuffer.toString()))
            tker.transition(Data)
        } else if (r.isEmpty()) {
            tker.emit(CDataToken(tker.dataBuffer.toString()))
            tker.transition(Data)
        }
    }
}
