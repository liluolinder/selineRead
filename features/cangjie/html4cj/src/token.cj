/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

enum TokenType <: Equatable<TokenType> & ToString {
    | DoctypeType
    | StartTagType
    | EndTagType
    | CommentType
    | CharacterType
    // note no CData - treated in builder as an extension of CharacterType
    | EOFType

    public func toString(): String {
        match (this) {
            case DoctypeType => "Doctype"
            case StartTagType => "StartTag"
            case EndTagType => "EndTag"
            case CommentType => "Comment"
            case CharacterType => "Character"
            case EOFType => "EOF"
        }
    }

    public operator func ==(other: TokenType) {
        this.toString() == other.toString()
    }

    public operator func !=(other: TokenType) {
        this.toString() != other.toString()
    }
}

func reset(sb: StringBuilder) {
    sb.reset()
}

abstract class Token <: Equatable<Token> & ToString {
    static let Unset: Int64 = -1

    var typ: ?TokenType = None

    var _startPos: Int64 = Unset

    // position in CharacterReader this token was read from
    var _endPos: Int64 = Unset

    func tokenType(): String {
        typ().toString()
    }

    public operator func ==(o: Token) {
        refEq(this, o)
    }

    public operator func !=(o: Token) {
        !refEq(this, o)
    }

    /*
     * Reset the data represent by this token, for reuse. Prevents the need to create transfer objects for every
     * piece of data, which immediately get GCed.
     */
    protected open func reset(): Token {
        _startPos = Unset
        _endPos = Unset
        return this
    }

    func startPos(): Int64 {
        return _startPos
    }

    func startPos(pos: Int64): Unit {
        _startPos = pos
    }

    func endPos(): Int64 {
        return _endPos
    }

    func endPos(pos: Int64): Unit {
        _endPos = pos
    }

    func isDoctype(): Bool {
        return typ == TokenType.DoctypeType
    }

    func asDoctype(): DoctypeToken {
        return (this as DoctypeToken).getOrThrow()
    }

    func isStartTag(): Bool {
        return typ == TokenType.StartTagType
    }

    func asStartTag(): StartTagToken {
        return (this as StartTagToken).getOrThrow()
    }

    func isEndTag(): Bool {
        return typ == TokenType.EndTagType
    }

    func asEndTag(): EndTagToken {
        return (this as EndTagToken).getOrThrow()
    }

    func isComment(): Bool {
        return typ == TokenType.CommentType
    }

    func asComment(): CommentToken {
        return (this as CommentToken).getOrThrow()
    }

    func isCharacter(): Bool {
        return typ == TokenType.CharacterType
    }

    func isCData(): Bool {
        return this is CDataToken
    }

    func asCharacter(): CharacterToken {
        return (this as CharacterToken).getOrThrow()
    }

    func isEOF(): Bool {
        return typ == TokenType.EOFType
    }
}

class DoctypeToken <: Token {
    let name: StringBuilder = StringBuilder()

    var pubSysKey: ?String = ""

    let publicIdentifier: StringBuilder = StringBuilder()

    let systemIdentifier: StringBuilder = StringBuilder()

    var forceQuirks: Bool = false

    init() {
        typ = TokenType.DoctypeType
    }

    protected override func reset(): Token {
        super.reset()
        name.reset()
        pubSysKey = None
        publicIdentifier.reset()
        systemIdentifier.reset()
        forceQuirks = false
        return this
    }

    func getName(): String {
        return name.toString()
    }

    func getPubSysKey(): ?String {
        return pubSysKey
    }

    func getPublicIdentifier(): String {
        return publicIdentifier.toString()
    }

    func getSystemIdentifier(): String {
        return systemIdentifier.toString()
    }

    func isForceQuirks(): Bool {
        return forceQuirks
    }

    public func toString(): String {
        return "<!doctype " + getName() + ">"
    }
}

abstract class TagToken <: Token {
    protected var tagName: ?String = None

    // lc version of tag name, for case insensitive tree build
    protected var _normalName: ?String = None

    // try to get attr names and vals in one shot, vs Builder
    private let attrName: StringBuilder = StringBuilder()

    private var attrNameS: ?String = None

    private var hasAttrName: Bool = false

    private let attrValue: StringBuilder = StringBuilder()

    private var attrValueS: ?String = None

    private var hasAttrValue: Bool = false

    // distinguish Bool attribute from empty string value
    private var hasEmptyAttrValue: Bool = false

    var selfClosing: Bool = false

    // start tags get attributes on construction. End tags get attributes on first attribute (but only for parser convenience, not used).
    var attributes: ?Attributes = None

    /* Limits runaway crafted HTML from spewing attributes and getting a little sluggish in ensureCapacity.
       Real-world HTML will P99 around 8 attributes, so plenty of headroom. Implemented here and not in the Attributes
       object so that API users can add more if ever required. */
    private static let MaxAttributes: Int64 = 512

    protected open func reset(): TagToken {
        super.reset()
        tagName = None
        _normalName = None
        attrName.reset()
        attrNameS = None
        hasAttrName = false
        attrValue.reset()
        attrValueS = None
        hasEmptyAttrValue = false
        hasAttrValue = false
        selfClosing = false
        attributes = None
        return this
    }

    func newAttribute(): Unit {
        if (attributes.isNone()) {
            attributes = Attributes()
        }

        if (hasAttrName && attributes().size < MaxAttributes) {
            // the tokeniser has skipped whitespace control Chars, but trimming could collapse to empty for other control codes, so verify here
            var name = if (attrName.size > 0) {
                attrName.toString()
            } else {
                attrNameS()
            }
            name = name.strip()
            if (name.size > 0) {
                var value: ?String
                if (hasAttrValue) {
                    value = if (attrValue.size > 0) {
                        attrValue.toString()
                    } else {
                        attrValueS()
                    }
                } else if (hasEmptyAttrValue) {
                    value = ""
                } else {
                    value = None
                }

                // note that we add, not put. So that the first is kept, and rest are deduped, once in a context where case sensitivity is known (the appropriate tree builder).
                attributes?.add(name, value)
            }
        }
        reset(attrName)
        attrNameS = None
        hasAttrName = false
        reset(attrValue)
        attrValueS = None
        hasAttrValue = false
        hasEmptyAttrValue = false
    }

    func hasAttributes(): Bool {
        return attributes != None
    }

    func hasAttribute(key: String): Bool {
        if (attributes != None) {
            if (attributes().hasKey(key)) {
                return true
            }
        }
        return false
    }

    func finaliseTag(): Unit {
        // finalises for emit
        if (hasAttrName) {
            newAttribute()
        }
    }

    /* Preserves case */
    func name(): String {
        // preserves case, for input into Tag.valueOf (which may drop case)
        Validate.isFalse(tagName == None || tagName().size == 0)
        return tagName()
    }

    /* Lower case */
    func normalName(): String {
        // lower case, used in tree building for working out where in tree it should go
        return _normalName()
    }

    func toStringName(): String {
        return if (tagName != None) {
            tagName()
        } else {
            "[unset]"
        }
    }

    func name(name: String): TagToken {
        tagName = name
        _normalName = ParseSettings.normalName(tagName())
        return this
    }

    func isSelfClosing(): Bool {
        return selfClosing
    }

    // these appenders are rarely hit in not None state-- caused by None Chars.
    func appendTagName(append: String): Unit {
        // might have None Chars - need to replace with None replacement Character
        let _append = append.replace(TokeniserState.nullChar.toString(), Tokeniser.replacementChar.toString())
        tagName = if (tagName == None) {
            _append
        } else {
            tagName() + _append
        }
        _normalName = ParseSettings.normalName(tagName())
    }

    func appendTagName(append: Rune): Unit {
        appendTagName(append.toString())
    }

    func appendAttributeName(append: String): Unit {
        // might have None Chars because we eat in one pass - need to replace with None replacement Character
        let appendSafe = append.replace(TokeniserState.nullChar.toString(), Tokeniser.replacementChar.toString())

        ensureAttrName()
        if (attrName.size == 0) {
            attrNameS = appendSafe
        } else {
            attrName.append(appendSafe)
        }
    }

    func appendAttributeName(append: Rune): Unit {
        ensureAttrName()
        attrName.append(append)
    }

    func appendAttributeValue(append: String): Unit {
        ensureAttrValue()
        if (attrValue.size == 0) {
            attrValueS = append
        } else {
            attrValue.append(append)
        }
    }

    func appendAttributeValue(append: Rune): Unit {
        ensureAttrValue()
        attrValue.append(append)
    }

    func appendAttributeValue(append: Array<Rune>): Unit {
        ensureAttrValue()
        attrValue.append(append)
    }

    func setEmptyAttributeValue(): Unit {
        hasEmptyAttrValue = true
    }

    private func ensureAttrName(): Unit {
        hasAttrName = true

        // if on second hit, we'll need to move to the builder
        if (attrNameS != None) {
            attrName.append(attrNameS())
            attrNameS = None
        }
    }

    private func ensureAttrValue(): Unit {
        hasAttrValue = true

        // if on second hit, we'll need to move to the builder
        if (attrValueS != None) {
            attrValue.append(attrValueS())
            attrValueS = None
        }
    }
}

class StartTagToken <: TagToken {
    init() {
        super()
        typ = TokenType.StartTagType
    }

    protected override func reset(): TagToken {
        super.reset()
        attributes = None
        return this
    }

    func nameAttr(name: String, attributes: Attributes): StartTagToken {
        this.tagName = name
        this.attributes = attributes
        _normalName = ParseSettings.normalName(tagName())
        return this
    }

    public func toString(): String {
        if (hasAttributes() && attributes().size > 0) {
            return "<" + toStringName() + " " + attributes().toString() + ">"
        } else {
            return "<" + toStringName() + ">"
        }
    }
}

class EndTagToken <: TagToken {
    init() {
        super()
        typ = TokenType.EndTagType
    }

    public func toString(): String {
        return "</" + toStringName() + ">"
    }
}

class CommentToken <: Token {
    private let data = StringBuilder()
    private var dataS: ?String = None // try to get in one shot
    var bogus: Bool = false

    init() {
        typ = TokenType.CommentType
    }

    protected override func reset(): Token {
        super.reset()
        reset(data)
        dataS = None
        bogus = false
        return this
    }

    func getData(): String {
        return if (dataS != None) {
            dataS()
        } else {
            data.toString()
        }
    }

    func append(append: String): CommentToken {
        ensureData()
        if (data.size == 0) {
            dataS = append
        } else {
            data.append(append)
        }
        return this
    }

    func append(append: Rune): CommentToken {
        ensureData()
        data.append(append)
        return this
    }

    private func ensureData(): Unit {
        // if on second hit, we'll need to move to the builder
        if (dataS != None) {
            data.append(dataS())
            dataS = None
        }
    }

    public func toString(): String {
        return "<!--" + getData() + "-->"
    }
}

open class CharacterToken <: Token {
    private var _data: ?String = None

    init() {
        super()
        super.typ = TokenType.CharacterType
    }

    protected override func reset(): Token {
        super.reset()
        _data = None
        return this
    }

    func data(data: String): CharacterToken {
        this._data = data
        return this
    }

    func getData(): String {
        return _data()
    }

    public open func toString(): String {
        return getData()
    }
}

class CDataToken <: CharacterToken {
    init(data: String) {
        super()
        this.data(data)
    }

    public func toString(): String {
        return "<![CDATA[" + getData() + "]]>"
    }
}

class EOFToken <: Token {
    init() {
        typ = TokenType.EOFType
    }

    protected override func reset(): Token {
        super.reset()
        return this
    }

    public func toString(): String {
        return ""
    }
}
