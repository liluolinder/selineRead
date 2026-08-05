/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Evaluates that an element matches the selector.
 */
public abstract class Evaluator <: ToString {
    protected init() {}

    /*
     * Test if the element meets the evaluator's requirements.
     *
     * @param root    Root of the matching subtree
     * @param element tested element
     * @return Returns true if the requirements are met or false otherwise
     */
    public func matches(root: ?Element, element: Element): Bool
}

/*
 * Evaluator for tag name
 */
class EvaluatorTag <: Evaluator {
    private var tagName: String

    init(tagName: String) {
        this.tagName = tagName
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return (element.normalName().equals(tagName))
    }

    public func toString(): String {
        return tagName
    }
}

/*
 * Evaluator for tag name that ends with
 */
class EvaluatorTagEndsWith <: Evaluator {
    private var tagName: String

    init(tagName: String) {
        this.tagName = tagName
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return (element.normalName().endsWith(tagName))
    }

    public func toString(): String {
        return tagName
    }
}

/*
 * Evaluator for element id
 */
class EvaluatorId <: Evaluator {
    private var id: String

    init(id: String) {
        this.id = id
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return id.equals(element.id())
    }

    public func toString(): String {
        return "#${id}"
    }
}

/*
 * Evaluator for element class
 */
class EvaluatorClass <: Evaluator {
    private var className: String

    init(className: String) {
        this.className = className
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return element.hasClass(className)
    }

    public func toString(): String {
        return ".${className}"
    }
}

/*
 * Evaluator for attribute name matching
 */
class EvaluatorAttribute <: Evaluator {
    private var key: String

    init(key: String) {
        this.key = key
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return element.hasAttr(key)
    }

    public func toString(): String {
        return "[${key}]"
    }
}

/*
 * Evaluator for attribute name prefix matching
 */
class EvaluatorAttributeStarting <: Evaluator {
    private var keyPrefix: String

    init(keyPrefix: String) {
        Validate.notEmpty(keyPrefix)
        this.keyPrefix = Normalizer.lowerCase(keyPrefix)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        var values: ArrayList<Attribute> = element.attributes().asList()
        for (attribute in values) {
            if (Normalizer.lowerCase(attribute.getKey()).startsWith(keyPrefix)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return "[^${keyPrefix}]"
    }
}

/*
 * Evaluator for attribute name/value matching
 */
class EvaluatorAttributeWithValue <: EvaluatorAttributeKeyPair {
    init(key: String, value: String) {
        super(key, value)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        let v = element.attr(key).strip()
        return element.hasAttr(key) && value.equalsIgnoreCase(v)
    }

    public func toString(): String {
        return "[${key}=${value}]"
    }
}

/*
 * Evaluator for attribute name != value matching
 */
class EvaluatorAttributeWithValueNot <: EvaluatorAttributeKeyPair {
    init(key: String, value: String) {
        super(key, value)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return !value.equalsIgnoreCase(element.attr(key))
    }

    public func toString(): String {
        return "[${key}!=${value}]"
    }
}

/*
 * Evaluator for attribute name/value matching (value prefix)
 */
class EvaluatorAttributeWithValueStarting <: EvaluatorAttributeKeyPair {
    init(key: String, value: String) {
        super(key, value, false)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        // value is lower case already
        if (element.hasAttr(key)) {
            if (Normalizer.lowerCase(element.attr(key)).startsWith(value)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return "[${key}^=${value}]"
    }
}

/*
 * Evaluator for attribute name/value matching (value ending)
 */
class EvaluatorAttributeWithValueEnding <: EvaluatorAttributeKeyPair {
    init(key: String, value: String) {
        super(key, value, false)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        // value is lower case
        if (element.hasAttr(key)) {
            if (Normalizer.lowerCase(element.attr(key)).endsWith(value)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return "[${key}$=${value}]"
    }
}

/*
 * Evaluator for attribute name/value matching (value containing)
 */
class EvaluatorAttributeWithValueContaining <: EvaluatorAttributeKeyPair {
    init(key: String, value: String) {
        super(key, value)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        // value is lower case
        if (element.hasAttr(key)) {
            if (Normalizer.lowerCase(element.attr(key)).contains(value)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return "[${key}*=${value}]"
    }
}

/*
 * Evaluator for attribute name/value matching (value regex matching)
 */
class EvaluatorAttributeWithValueMatching <: Evaluator {
    var key: String
    var pattern: Regex

    init(key: String, pattern: Regex) {
        this.key = Normalizer.normalize(key)
        this.pattern = pattern
    }

    public override func matches(_: ?Element, element: Element): Bool {
        match (pattern.matcher(element.attr(key)).find()) {
            case None => return false
            case _ => return element.hasAttr(key)
        }
    }

    public func toString(): String {
        return "[${key}~=${pattern.string()}]"
    }
}

/*
 * Abstract evaluator for attribute name/value matching
 */
abstract class EvaluatorAttributeKeyPair <: Evaluator {
    public var key: String
    public var value: String
    init(key: String, value: String) {
        this(key, value, true)
    }

    init(key: String, value: String, trimValue: Bool) {
        Validate.notEmpty(key)
        Validate.notEmpty(value)
        this.key = Normalizer.normalize(key)
        var isStart: Bool = value.startsWith("'")
        var isEnd: Bool = value.endsWith("'")
        var isBackslashStart: Bool = value.startsWith("\"")
        var isBackslashEnd: Bool = value.endsWith("\"")
        var isStringLiteral: Bool = isStart && isEnd || isBackslashStart && isBackslashEnd
        var valueNew: String = value
        if (isStringLiteral) {
            valueNew = value[1..=value.size - 2]
        }
        if (trimValue) {
            this.value = Normalizer.normalize(valueNew)
        } else {
            this.value = Normalizer.normalize(valueNew, isStringLiteral)
        }
    }
}

/*
 * Evaluator for any / all element matching
 */
class EvaluatorAllElements <: Evaluator {
    public override func matches(_: ?Element, _: Element): Bool {
        return true
    }

    public func toString(): String {
        return "*"
    }
}

/*
 * Evaluator for matching by sibling index number (e < idx)
 */
class EvaluatorIndexLessThan <: EvaluatorIndexEvaluator {
    init(index: Int64) {
        super(index)
    }

    public override func matches(root: ?Element, element: Element): Bool {
        if (root != element) {
            if (element.elementSiblingIndex() < index) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        return ":lt(${index})"
    }
}

/*
 * Evaluator for matching by sibling index number (e > idx)
 */
class EvaluatorIndexGreaterThan <: EvaluatorIndexEvaluator {
    init(index: Int64) {
        super(index)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return element.elementSiblingIndex() > index
    }

    public func toString(): String {
        return ":gt(${index})"
    }
}

/*
 * Evaluator for matching by sibling index number (e = idx)
 */
class EvaluatorIndexEquals <: EvaluatorIndexEvaluator {
    init(index: Int64) {
        super(index)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return element.elementSiblingIndex() == index
    }

    public func toString(): String {
        return ":eq(${index})"
    }
}

/*
 * Evaluator for matching the last sibling (css :last-child)
 */
class EvaluatorIsLastChild <: Evaluator {
    public override func matches(_: ?Element, element: Element): Bool {
        var p: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        if (p != None) {
            if (!(p() is Document)) {
                if (element.elementSiblingIndex() == (p().children().elementArr.size - 1)) {
                    return true
                }
            }
        }
        return false
    }

    public func toString(): String {
        return ":last-child"
    }
}

class EvaluatorIsFirstOfType <: EvaluatorIsNthOfType {
    init() {
        super(0, 1)
    }

    public func toString(): String {
        return ":first-of-type"
    }
}

class EvaluatorIsLastOfType <: EvaluatorIsNthLastOfType {
    init() {
        super(0, 1)
    }

    public func toString(): String {
        return ":last-of-type"
    }
}

abstract class EvaluatorCssNthEvaluator <: Evaluator {
    let a: Int64
    let b: Int64

    init(a: Int64, b: Int64) {
        this.a = a
        this.b = b
    }

    init(b: Int64) {
        this(0, b)
    }

    public override func matches(root: ?Element, element: Element): Bool {
        let p: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        if (p == None || p.instanceof<Document>()) {
            return false
        }
        let pos: Int64 = calculatePosition(root(), element)
        if (a == 0) {
            return pos == b
        }
        return (pos - b) * a >= 0 && (pos - b) % a == 0
    }

    public open func toString(): String {
        if (a == 0) {
            return ":${getPseudoClass()}(${b})"
        }
        if (b == 0) {
            return ":${getPseudoClass()}(${a}n)"
        }
        return ":${getPseudoClass()}(${a}n${b.format("+")})"
    }

    protected func getPseudoClass(): String

    protected func calculatePosition(root: Element, element: Element): Int64
}

/*
 * css-compatible Evaluator for :eq (css :nth-child)
 */
class EvaluatorIsNthChild <: EvaluatorCssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }

    public override func calculatePosition(_: Element, element: Element): Int64 {
        return element.elementSiblingIndex() + 1
    }

    public override func getPseudoClass(): String {
        return "nth-child"
    }
}

/*
 * css pseudo class :nth-last-child)
 */
class EvaluatorIsNthLastChild <: EvaluatorCssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }

    public override func calculatePosition(_: Element, element: Element): Int64 {
        if (element.parent() == None) {
            return 0
        }
        return match (element.parent()) {
            case Some(v: Element) => v.children().elementArr.size - element.elementSiblingIndex()
            case _ => 0
        }
    }

    public override func getPseudoClass(): String {
        return "nth-last-child"
    }
}

/*
 * css pseudo class nth-of-type
 */
open class EvaluatorIsNthOfType <: EvaluatorCssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }

    public func calculatePosition(_: Element, element: Element): Int64 {
        var pos: Int64 = 0
        if (element.parent() == None) {
            return 0
        }
        var family: Elements = (element.parent()() as Element)().children()
        for (el in family.elementArr) {
            if (el.tag() == element.tag()) {
                pos++
            }
            if (el == element) {
                break
            }
        }
        return pos
    }

    public func getPseudoClass(): String {
        return "nth-of-type"
    }
}

open class EvaluatorIsNthLastOfType <: EvaluatorCssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }

    public override func calculatePosition(_: Element, element: Element): Int64 {
        var pos: Int64 = 0
        if (element.parent() == None) {
            return 0
        }
        var family: Elements = match (element.parent()) {
            case Some(v: Element) => v.children()
            case _ => return 0
        }
        for (i in element.elementSiblingIndex()..family.elementArr.size) {
            if (family.elementArr[i].tag() == element.tag()) {
                pos++
            }
        }
        return pos
    }

    public override func getPseudoClass(): String {
        return "nth-last-of-type"
    }
}

/*
 * Evaluator for matching the first sibling (css :first-child)
 */
class EvaluatorIsFirstChild <: Evaluator {
    public override func matches(_: ?Element, element: Element): Bool {
        var p: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        if (p != None) {
            if (!(p() is Document)) {
                if (element.elementSiblingIndex() == 0) {
                    return true
                }
            }
        }
        return false
    }

    public func toString(): String {
        return ":first-child"
    }
}

/*
 * css3 pseudo-class :root
 *
 */
class EvaluatorIsRoot <: Evaluator {
    public override func matches(root: ?Element, element: Element): Bool {
        var r: Element = match (root) {
            case Some(v: Document) => v.child(0)
            case None => return false
            case _ => root()
        }
        return element == r
    }

    public func toString(): String {
        return ":root"
    }
}

class EvaluatorIsOnlyChild <: Evaluator {
    public override func matches(_: ?Element, element: Element): Bool {
        var p: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        if (p != None) {
            if (!p.instanceof<Document>()) {
                if (element.siblingElements().elementArr.isEmpty()) {
                    return true
                }
            }
        }
        return false
    }

    public func toString(): String {
        return ":only-child"
    }
}

class EvaluatorIsOnlyOfType <: Evaluator {
    public override func matches(_: ?Element, element: Element): Bool {
        let p: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        if (p == None || p.instanceof<Document>()) {
            return false
        }
        var pos: Int64 = 0
        let family: Elements = p().children()
        for (el in family.elementArr) {
            if (el.tag() == element.tag()) {
                pos++
            }
        }
        return pos == 1
    }

    public func toString(): String {
        return ":only-of-type"
    }
}

class EvaluatorIsEmpty <: Evaluator {
    public override func matches(_: ?Element, element: Element): Bool {
        var family: ArrayList<Node> = element.childNodes()
        for (n in family) {
            if (!(n is Comment || n is XmlDeclaration || n is DocumentType)) {
                return false
            }
        }
        return true
    }

    public func toString(): String {
        return ":empty"
    }
}

/*
 * Abstract evaluator for sibling index matching
 */
abstract class EvaluatorIndexEvaluator <: Evaluator {
    var index: Int64
    init(index: Int64) {
        this.index = index
    }
}

/*
 * Evaluator for matching Element (and its descendants) text
 */
class EvaluatorContainsText <: Evaluator {
    var searchText: String

    init(searchText: String) {
        this.searchText = Normalizer.lowerCase(StringUtil.normaliseWhitespace(searchText))
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return Normalizer.lowerCase(element.text()).contains(searchText)
    }

    public func toString(): String {
        return ":contains(${searchText})"
    }
}

/*
 * Evaluator for matching Element (and its descendants) wholeText.
 */
class EvaluatorContainsWholeText <: Evaluator {
    var searchText: String

    init(searchText: String) {
        this.searchText = searchText
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return element.wholeText().contains(searchText)
    }

    public func toString(): String {
        return ":containsWholeText(${searchText})"
    }
}

/*
 * Evaluator for matching Element (but <b>not</b> its descendants) wholeText.
 */
class EvaluatorContainsWholeOwnText <: Evaluator {
    var searchText: String

    init(searchText: String) {
        this.searchText = searchText
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return element.wholeOwnText().contains(searchText)
    }

    public func toString(): String {
        return ":containsWholeOwnText(${searchText})"
    }
}

/*
 * Evaluator for matching Element (and its descendants) data
 */
class EvaluatorContainsData <: Evaluator {
    var searchText: String

    init(searchText: String) {
        this.searchText = Normalizer.lowerCase(searchText)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        // not whitespace normalized
        return Normalizer.lowerCase(element.data()).contains(searchText)
    }

    public func toString(): String {
        return ":containsData(${searchText})"
    }
}

/*
 * Evaluator for matching Element's own text
 */
class EvaluatorContainsOwnText <: Evaluator {
    var searchText: String

    init(searchText: String) {
        this.searchText = Normalizer.lowerCase(StringUtil.normaliseWhitespace(searchText))
    }

    public override func matches(_: ?Element, element: Element): Bool {
        return Normalizer.lowerCase(element.ownText()).contains(searchText)
    }

    public func toString(): String {
        return ":containsOwn(${searchText})"
    }
}

/*
 * Evaluator for matching Element (and its descendants) text with regex
 */
class EvaluatorMatches <: Evaluator {
    var pattern: Regex

    init(pattern: Regex) {
        this.pattern = pattern
    }

    public override func matches(_: ?Element, element: Element): Bool {
        var m: Matcher = pattern.matcher(element.text())
        return match (m.find()) {
            case None => false
            case _ => true
        }
    }

    public func toString(): String {
        return ":matches(${pattern.string()})"
    }
}

/*
 * Evaluator for matching Element's own text with regex
 */
class EvaluatorMatchesOwn <: Evaluator {
    var pattern: Regex

    init(pattern: Regex) {
        this.pattern = pattern
    }

    public override func matches(_: ?Element, element: Element): Bool {
        var m: Matcher = pattern.matcher(element.ownText())
        return match (m.find()) {
            case None => false
            case _ => true
        }
    }

    public func toString(): String {
        return ":matchesOwn(${pattern.string()})"
    }
}

/*
 * Evaluator for matching Element (and its descendants) whole text with regex.
 */
class EvaluatorMatchesWholeText <: Evaluator {
    var pattern: Regex

    init(pattern: Regex) {
        this.pattern = pattern
    }

    public override func matches(_: ?Element, element: Element): Bool {
        var m: Matcher = pattern.matcher(element.wholeText())
        return match (m.find()) {
            case None => false
            case _ => true
        }
    }

    public func toString(): String {
        return ":matchesWholeText(${pattern.string()})"
    }
}

/*
 * Evaluator for matching Element's own whole text with regex.
 */
class EvaluatorMatchesWholeOwnText <: Evaluator {
    var pattern: Regex

    init(pattern: Regex) {
        this.pattern = pattern
    }

    public override func matches(_: ?Element, element: Element): Bool {
        var m: Matcher = pattern.matcher(element.wholeOwnText())
        return match (m.find()) {
            case None => false
            case _ => true
        }
    }

    public func toString(): String {
        return ":matchesWholeOwnText(${pattern.string()})"
    }
}

class EvaluatorMatchText <: Evaluator {
    public override func matches(_: ?Element, element: Element): Bool {
        if (element is PseudoTextElement) {
            return true
        }
        var textNodes: ArrayList<TextNode> = element.textNodes()
        for (textNode in textNodes) {
            var pel: PseudoTextElement = PseudoTextElement(
                Tag.valueOf(element.tagName()),
                element.baseUri(),
                element.attributes()
            )
            textNode.replaceWith(pel)
            pel.appendChild(textNode)
        }
        return false
    }

    public func toString(): String {
        return ":matchText"
    }
}
