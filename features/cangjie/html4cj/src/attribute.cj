/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A single key + value attribute. (Only used for presentation.)
 */
public class Attribute <: Hashable & Equatable<Attribute> & ToString {
    private static let booleanAttributes: Array<String> = [
        "allowfullscreen",
        "async",
        "autofocus",
        "checked",
        "compact",
        "declare",
        "default",
        "defer",
        "disabled",
        "formnovalidate",
        "hidden",
        "inert",
        "ismap",
        "itemscope",
        "multiple",
        "muted",
        "nohref",
        "noresize",
        "noshade",
        "novalidate",
        "nowrap",
        "open",
        "readonly",
        "required",
        "reversed",
        "seamless",
        "selected",
        "sortable",
        "truespeed",
        "typemustmatch"
    ]

    private static let xmlKeyValid: Regex = Regex("[a-zA-Z_:][-a-zA-Z0-9_:.]*")

    private static let xmlKeyReplace: Regex = Regex("[^-a-zA-Z0-9_:.]")

    private var key: String

    private var valValue: ?String

    // used to update the holding Attributes when the key / value is changed via this interface
    var parent: ?Attributes

    /*
     * Create a new attribute from unencoded (raw) key and value.
     *
     * @param key attribute key; case is preserved.
     * @param value attribute value (may be null)
     */
    public init(key: String, value: ?String) {
        this(key, value, None)
    }

    /*
     * Create a new attribute from unencoded (raw) key and value.
     *
     * @param key attribute key; case is preserved.
     * @param val attribute value (may be null)
     * @param parent the containing Attributes (this Attribute is not automatically added to said Attributes)
     */
    public init(key: String, val: ?String, parent: ?Attributes) {
        var keyTrim: String = key.strip()

        // trimming could potentially make empty, so validate here
        Validate.notEmpty(keyTrim)
        this.key = keyTrim
        this.valValue = val
        this.parent = parent
    }

    /*
     * Get the attribute key.
     *
     * @return the attribute key
     */
    public func getKey(): String {
        return key
    }

    /*
     * Get the attribute value. Will return an empty string if the value is not set.
     *
     * @return the attribute value
     */
    public func getValue(): String {
        return Attributes.checkNotNull(valValue)
    }

    /*
     * Set the attribute key; case is preserved.
     *
     * @param key the new key; must not be null
     */
    public func setKey(key: String): Unit {
        var keyTrim: String = key.strip()

        // trimming could potentially make empty, so validate here
        Validate.notEmpty(keyTrim)
        if (parent != None) {
            var i: Int64 = parent().indexOfKey(this.key)
            if (i != Attributes.NotFound) {
                parent().keys[i] = keyTrim
            }
        }
        this.key = keyTrim
    }

    /*
     * Set the attribute value.
     *
     * @param val the new attribute value; may be null (to set an enabled boolean attribute)
     * @return the previous value (if was null; an empty string)
     */
    public func setValue(val: ?String): String {
        var oldVal: ?String = this.valValue
        if (parent != None) {
            var i: Int64 = parent().indexOfKey(this.key)
            if (i != Attributes.NotFound) {
                // trust the container more
                oldVal = parent().get(this.key)
                match (val) {
                    case None => parent().vals[i] = None
                    case Some(v) => parent().vals[i] = v
                }
            }
        }
        this.valValue = val
        return Attributes.checkNotNull(oldVal)
    }

    /*
     * Check if this Attribute has a value. Set boolean attributes have no value.
     *
     * @return if this is a boolean attribute / attribute without a value
     */
    public func hasDeclaredValue(): Bool {
        return valValue != None
    }

    /*
     * Checks if this attribute name is defined as a boolean attribute in HTML5
     *
     * @param key attribute key
     */
    public static func isBooleanAttribute(key: String): Bool {
        for (i in 0..booleanAttributes.size) {
            if (booleanAttributes[i].equals(Normalizer.lowerCase(key))) {
                return true
            }
        }
        return false
    }

    /*
     * Get the HTML representation of this attribute
     *
     * @return HTML
     */
    public func html(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        html(sb, Document("").outputSettings())
        return StringUtil.releaseBuilder(sb)
    }

    protected func html(accum: StringBuilder, out: DocumentOutputSettings): Unit {
        htmlNew(key, valValue, accum, out)
    }

    protected static func htmlNew(key: String, val: ?String, accum: StringBuilder, out: DocumentOutputSettings): Unit {
        var keyNew: ?String = getValidKey(key, out.syntax())
        if (keyNew == None) {
            return
        }
        htmlNoValidate(key, val, accum, out)
    }

    static func htmlNoValidate(key: String, val: ?String, accum: StringBuilder, out: DocumentOutputSettings): Unit {
        // structured like this so that Attributes can check we can write first, so it can add whitespace correctly
        accum.append(key)
        if (!shouldCollapseAttributeNew(key, val, out)) {
            accum.append("=\"")
            Entities.escape(accum, Attributes.checkNotNull(val), out, true, false, false, false)
            accum.append(r'"')
        }
    }

    static func getValidKey(key: String, syntaxEnum: Syntax): ?String {
        // we consider HTML attributes to always be valid. XML checks key validity
        var keyNew: String = key.replace("\u{0}", "") // cangjie regex don't let \u{0} input
        if (syntaxEnum == Syntax.xmlSyntax && Matcher(xmlKeyValid, keyNew).fullMatch().isNone()) { /*cjlint-ignore !G.EXP.03 */
            keyNew = xmlKeyReplace.matcher(keyNew).replaceAll("")
            match (Matcher(xmlKeyValid, keyNew).fullMatch()) {
                case None => return None
                case _ => return keyNew
            }
        } else if (syntaxEnum == Syntax.htmlSyntax) {
            let charBool: (Rune) -> Bool = {
                c => !((r'\u{00}' <= c && c <= r'\u{1f}') || (r'\u{7f}' <= c && c <= r'\u{9f}') || c == r' ' || c == r'"' ||
                    c == r'\'' || c == r'/' || c == r'=')
            }
            let str: String = keyNew.toRuneArray() |> filter<Rune>(charBool) |> collectString<Rune>()
            return if (str.size == 0) {
                None
            } else {
                str
            }
        }
        return keyNew
    }

    public func toString(): String {
        return html()
    }

    protected func isDataAttribute(): Bool {
        return isDataAttribute(key)
    }

    protected func isDataAttribute(key: String): Bool {
        return key.startsWith(Attributes.dataPrefix) && key.size > Attributes.dataPrefix.size
    }

    /*
     * Collapsible if it's a boolean attribute and value is empty or same as name
     *
     * @param out output settings
     * @return  Returns whether collapsible or not
     */
    protected func shouldCollapseAttribute(out: DocumentOutputSettings): Bool {
        return shouldCollapseAttributeNew(key, valValue, out)
    }

    /*
     * collapse unknown foo=null, known checked=null, checked="", checked=checked; write out others
     */
    protected static func shouldCollapseAttributeNew(key: String, val: ?String, out: DocumentOutputSettings): Bool {
        return (out.syntax() == Syntax.htmlSyntax && (val == None || (val().isEmpty() || val().equalsIgnoreCase(key)) &&
            Attribute.isBooleanAttribute(key)))
    }

    public func clone(): Attribute {
        return match (this.parent) {
            case None => Attribute(this.key, this.valValue, None)
            case Some(v) => Attribute(this.key, this.valValue, v.clone())
        }
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        // note parent not considered
        return match (valValue) {
            case None => 31 * key.hashCode()
            case Some(v) => 31 * key.hashCode() + v.hashCode()
        }
    }

    public operator func !=(that: Attribute): Bool {
        return !(this == that)
    }

    public operator func ==(that: Attribute): Bool {
        if (refEq(this, that)) {
            return true
        }
        if (key != that.key) {
            return false
        }
        return valValue == that.valValue
    }
}
