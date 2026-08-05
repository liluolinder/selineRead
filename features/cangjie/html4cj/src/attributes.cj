/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * The attributes of an Element.
 */
public class Attributes <: Iterable<Attribute> & Hashable & Equatable<Attributes> & ToString {
    // The Attributes object is only created on the first use of an attribute; the Element will just have a null
    // Attribute slot otherwise
    protected static let dataPrefix: String = "data-"

    // Indicates a jsoup internal key. Can't be set via HTML. (It could be set via accessor, but not too worried about
    // that. Suppressed from list, iter.
    static let InternalPrefix: Rune = r'/'

    // sampling found mean count when attrs present = 1.49; 1.08 overall. 2.6:1 don't have any attrs.
    private static let InitialCapacity: Int64 = 3

    // manages the key/val arrays
    private static let GrowthFactor: Int64 = 2

    static let NotFound: Int64 = -1

    private static let EmptyString: String = ""

    // the number of instance fields is kept as low as possible giving an object size of 24 bytes
    // number of slots used (not total capacity, which is keys.length)
    private var length: Int64 = 0

    var keys: Array<String> = Array<String>(InitialCapacity, repeat: "")

    // Genericish: all non-internal attribute values must be Strings and are cast on access.
    var vals: Array<?Any> = Array<?Any>(InitialCapacity, repeat: Option<Any>.None)

    public prop size: Int64 {
        get() {
            return length
        }
    }

    public prop dataSize: Int64 {
        get() {
            var len: Int64 = 0
            for (i in 0..length) {
                if (keys[i].startsWith(dataPrefix)) {
                    len++
                }
            }
            return len
        }
    }

    /*
     * check there's room for more
     *
     * @param minNewSize min Size
     */
    private func checkCapacity(minNewSize: Int64): Unit {
        Validate.isTrue(minNewSize >= length)
        var curCap: Int64 = keys.size
        if (curCap >= minNewSize) {
            return
        }
        var newCap: Int64
        if (curCap >= InitialCapacity) {
            newCap = length * GrowthFactor
        } else {
            newCap = InitialCapacity
        }
        if (minNewSize > newCap) {
            newCap = minNewSize
        }
        var keysNew: Array<String> = Array<String>(newCap, repeat: "")
        var valsNew: Array<?Any> = Array<?Any>(newCap, repeat: Option<Any>.None)
        keys.copyTo(keysNew, 0, 0, keys.size)
        vals.copyTo(valsNew, 0, 0, keys.size)
        keys = keysNew
        vals = valsNew
    }

    func indexOfKey(key: String): Int64 {
        for (i in 0..length) {
            if (key.equals(keys[i])) {
                return i
            }
        }
        return NotFound
    }

    private func indexOfKeyIgnoreCase(key: String): Int64 {
        for (i in 0..length) {
            if (key.equalsIgnoreCase(keys[i])) {
                return i
            }
        }
        return NotFound
    }

    /*
     * we track boolean attributes as null in values - they're just keys. so returns empty for consumers
     * casts to String, so only for non-internal attributes
     *
     * @param obj obj
     * @return string
     */
    static func checkNotNull<T>(obj: ?T): String {
        return match (obj) {
            case Some(v: String) => v
            case _ => EmptyString
        }
    }

    /*
     * Get an attribute value by key.
     *
     * @param key the (case-sensitive) attribute key
     * @return the attribute value if set; or empty string if not set (or a boolean attribute).
     */
    public func get(key: String): String {
        var i: Int64 = indexOfKey(key)
        if (i == NotFound) {
            return EmptyString
        } else {
            return checkNotNull(vals[i])
        }
    }

    /*
     * Get an attribute's value by case-insensitive key
     *
     * @param key the attribute name
     * @return the first matching attribute value if set; or empty string if not set (ora boolean attribute).
     */
    public func getIgnoreCase(key: String): String {
        var i: Int64 = indexOfKeyIgnoreCase(key)
        if (i == NotFound) {
            return EmptyString
        } else {
            return checkNotNull(vals[i])
        }
    }

    public func getData(key: String): ?String {
        if (key.isEmpty()) {
            return None
        }
        var dataKeyValue: String = dataKey(key)
        var i: Int64 = indexOfKey(dataKeyValue)
        if (i == Attributes.NotFound) {
            return None
        } else {
            return match (vals[i]) {
                case Some(s: String) => s
                case _ => None
            }
        }
    }

    /*
     * Get an arbitrary user data object by key.
     *
     * @param key case sensitive key to the object.
     * @return the object associated to this key, or null if not found.
     */
    func getUserData(key: String): ?Any {
        var keyNew: String = key
        if (!isInternalKey(key)) {
            keyNew = internalKey(key)
        }
        var i: Int64 = indexOfKeyIgnoreCase(keyNew)
        if (i == NotFound) {
            return None
        } else {
            return vals[i]
        }
    }

    /*
     * Adds a new attribute. Will produce duplicates if the key already exists.
     *
     * @param key case sensitive attribute key (not null)
     * @param value attribute value (may be null, to set a boolean attribute)
     * @return these attributes, for chaining
     */
    public func add(key: String, value: ?String): Attributes {
        addObject(key, value)
        return this
    }

    private func addObject<T>(key: String, value: ?T): Unit {
        checkCapacity(length + 1)
        keys[length] = key
        match (value) {
            case None => vals[length] = None
            case Some(v) => vals[length] = v
        }
        length++
    }

    /*
     * Set a new attribute, or replace an existing one by key.
     *
     * @param key case sensitive attribute key (not null)
     * @param value attribute value (may be null, to set a boolean attribute)
     * @return these attributes, for chaining
     */
    public func put(key: String, value: ?String): Attributes {
        var i: Int64 = indexOfKey(key)
        if (i != NotFound) {
            match (value) {
                case None => vals[i] = None
                case Some(v) => vals[i] = v
            }
        } else {
            add(key, value)
        }
        return this
    }

    /*
     * Put an arbitrary user-data object by key. Will be treated as an internal attribute, so will not be emitted in HTML.
     *
     * @param key case sensitive key
     * @param value object value
     * @return these attributes
     */
    func putUserData(key: String, value: Any): Attributes {
        var keyNew: String = key
        if (!isInternalKey(key)) {
            keyNew = internalKey(key)
        }
        var i: Int64 = indexOfKey(keyNew)
        if (i != NotFound) {
            vals[i] = value
        } else {
            addObject(keyNew, value)
        }
        return this
    }

    func putIgnoreCase(key: String, value: ?String): Unit {
        var i: Int64 = indexOfKeyIgnoreCase(key)
        if (i != NotFound) {
            match (value) {
                case None => vals[i] = None
                case Some(v) => vals[i] = v
            }
            if (!keys[i].equals(key)) {
                // case changed, update
                keys[i] = key
            }
        } else {
            add(key, value)
        }
    }

    /*
     * Set a new boolean attribute, remove attribute if value is false.
     *
     * @param key case insensitive attribute key
     * @param value attribute value
     * @return these attributes, for chaining
     */
    public func put(key: String, value: Bool): Attributes {
        if (value) {
            putIgnoreCase(key, None)
        } else {
            remove(key)
        }
        return this
    }

    /*
     * Set a new attribute, or replace an existing one by key.
     *
     * @param attribute attribute with case sensitive key
     * @return these attributes, for chaining
     */
    public func put(attribute: Attribute): Attributes {
        put(attribute.getKey(), attribute.getValue())
        attribute.parent = this
        return this
    }

    /*
     * Add all the attributes from the incoming set to this set.
     *
     * @param incoming attributes to add to these attributes.
     */
    public func addAll(incoming: Attributes): Unit {
        if (incoming.size == 0) {
            return
        }
        checkCapacity(length + incoming.length)

        // if this set is empty, no need to check existing set, so can add() vs put()
        var needsPut: Bool = length != 0

        // (and save bashing on the indexOfKey()
        for (attr in incoming) {
            if (needsPut) {
                put(attr)
            } else {
                add(attr.getKey(), attr.getValue())
            }
        }
    }

    public func putData(key: String, value: ?String): ?String {
        var oldValue: ?String
        if (hasKey(dataKey(key))) {
            oldValue = get(dataKey(key))
        } else {
            oldValue = None
        }
        put(dataKey(key), value)
        return oldValue
    }

    /*
     * removes and shifts up
     */
    private func remove(index: Int64): Unit {
        Validate.isTrue(index < length)
        var shifted: Int64 = length - index - 1
        if (shifted > 0) {
            keys.copyTo(keys, index + 1, index, length - index - 1)
            vals.copyTo(vals, index + 1, index, length - index - 1)
        }
        length--
        keys[length] = "" // release hold
        vals[length] = None
    }

    /*
     * Remove an attribute by key.
     *
     * @param key attribute key to remove
     */
    public func remove(key: String): Unit {
        var i: Int64 = indexOfKey(key)
        if (i != NotFound) {
            remove(i)
        }
    }

    /*
     * Remove an attribute by key.
     *
     * @param key attribute key to remove
     */
    public func removeIgnoreCase(key: String): Unit {
        var i: Int64 = indexOfKeyIgnoreCase(key)
        if (i != NotFound) {
            remove(i)
        }
    }

    public func removeData(key: String): Unit {
        remove(dataKey(key))
    }

    /*
     * Tests if these attributes contain an attribute with this key.
     *
     * @param key case-sensitive key to check for
     * @return true if key exists, false otherwise
     */
    public func hasKey(key: String): Bool {
        return indexOfKey(key) != NotFound
    }

    /*
     * Tests if these attributes contain an attribute with this key.
     *
     * @param key key to check for
     * @return true if key exists, false otherwise
     */
    public func hasKeyIgnoreCase(key: String): Bool {
        return indexOfKeyIgnoreCase(key) != NotFound
    }

    /*
     * Check if these attributes contain an attribute with a value for this key.
     *
     * @param key key to check for
     * @return true if key exists, and it has a value
     */
    public func hasDeclaredValueForKey(key: String): Bool {
        var i: Int64 = indexOfKey(key)
        return i != NotFound && vals[i].isSome()
    }

    /*
     * Check if these attributes contain an attribute with a value for this key.
     *
     * @param key case-insensitive key to check for
     * @return true if key exists, and it has a value
     */
    public func hasDeclaredValueForKeyIgnoreCase(key: String): Bool {
        var i: Int64 = indexOfKeyIgnoreCase(key)
        return i != NotFound && vals[i].isSome()
    }

    /*
     * Test if this Attributes list is empty (length==0).
     */
    public func isEmpty(): Bool {
        return length == 0
    }

    public func iterator(): Iterator<Attribute> {
        return AttributesIterator(keys, vals, this, length)
    }

    /*
     * Get the attributes as a List, for iteration.
     *
     * @return a view of the attributes as an unmodifiable List.
     */
    public func asList(): ArrayList<Attribute> {
        return this |> collectArrayList
    }

    /*
     * Retrieves a filtered view of attributes that are HTML5 custom data attributes
     *
     * @return map of custom data attributes.
     */
    public func dataset(): Iterator<(String, ?String)> {
        return dataIterator()
    }

    /*
     * Get the HTML representation of these attributes.
     *
     * @return HTML
     */
    public func html(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()

        // output settings a bit funky, but this html() seldom used
        html(sb, Document("").outputSettings())
        return StringUtil.releaseBuilder(sb)
    }

    func html(accum: StringBuilder, out: DocumentOutputSettings): Unit {
        var sz: Int64 = length
        for (i in 0..sz) {
            if (isInternalKey(keys[i])) {
                continue
            }
            var key: ?String = Attribute.getValidKey(keys[i], out.syntax())
            if (key != None) {
                match (vals[i]) {
                    case None =>
                        accum.append(r' ');
                        Attribute.htmlNoValidate(key(), None, accum, out)
                    case Some(v: String) =>
                        accum.append(r' ');
                        Attribute.htmlNoValidate(key(), v, accum, out)
                    case _ =>
                        accum.append(r' ');
                        Attribute.htmlNoValidate(key(), EmptyString, accum, out)
                }
            }
        }
    }

    public func toString(): String {
        return html()
    }

    public func clone(): Attributes {
        var clone: Attributes = Attributes()
        clone.length = length
        var keysNew: Array<String> = Array<String>(length, repeat: "")
        var valsNew: Array<?Any> = Array<?Any>(length, repeat: Option<Any>.None)
        keys.copyTo(keysNew, 0, 0, length)
        vals.copyTo(valsNew, 0, 0, length)
        clone.keys = keysNew
        clone.vals = valsNew
        return clone
    }

    /*
     * add a backslash to the key
     *
     * @param key key to be added
     * @return return value after adding
     */
    public static func internalKey(key: String): String {
        return InternalPrefix.toString() + key
    }

    /*
     * Calculates the hashcode of these attributes, by iterating all attributes and summing their hashcodes.
     *
     * @return calculated hashcode
     */
    @OverflowWrapping
    public func hashCode(): Int64 {
        var result: Int64 = length
        result = 31 * result + hashCodeString(keys)
        result = 31 * result + hashCodeValue(vals)
        return result
    }

    @OverflowWrapping
    private func hashCodeString(code: Array<String>): Int64 {
        var result: Int64 = 1
        for (element in code) {
            result = 31 * result + element.hashCode()
        }
        return result
    }

    @OverflowWrapping
    private func hashCodeValue(code: Array<?Any>): Int64 {
        var result: Int64 = 1
        for (element in code) {
            result = 31 * result + match (element) {
                case Some(v: Hashable) => v.hashCode()
                case _ => 0
            }
        }
        return result
    }

    public operator func !=(that: Attributes): Bool {
        return !(this == that)
    }

    public operator func ==(that: Attributes): Bool {
        if (refEq(this, that)) {
            return true
        }
        if (length != that.length) {
            return false
        }
        for (i in 0..length) {
            var key: String = keys[i]
            var thatI: Int64 = that.indexOfKey(key)
            if (thatI == NotFound) {
                return false
            }
            match ((vals[i], that.vals[thatI])) {
                case (None, None) => ()
                case (Some(a: ToString), Some(b: ToString)) =>
                    if (a.toString() != b.toString()) {
                        return false
                    }
                case (Some(a: Object), Some(b: Object)) =>
                    if (!refEq(a, b)) {
                        return false
                    }
                case _ => return false
            }
        }
        return true
    }

    /*
     * Internal method. Lowercases all keys.
     */
    func normalize(): Unit {
        for (i in 0..length) {
            keys[i] = Normalizer.lowerCase(keys[i])
        }
    }

    /*
     * Internal method. Removes duplicate attribute by name. Settings for case sensitivity of key names.
     *
     * @param settings case sensitivity
     * @return number of removed dupes
     */
    func deduplicate(settings: ParseSettings): Int64 {
        if (isEmpty()) {
            return 0
        }
        var preserve: Bool = settings.preserveAttributeCase()
        var dupes: Int64 = 0
        for (i in 0..keys.size) {
            var j: Int64 = i + 1
            while (j < keys.size) {
                if (j >= length) {
                    break
                }
                var bool1: Bool = keys[i].equals(keys[j])
                var bool2: Bool = keys[i].toUpper().equals(keys[j].toUpper())
                if ((preserve && bool1) || (!preserve && bool2)) {
                    dupes++
                    remove(j)
                    j--
                }
                j++
            }
        }
        return dupes
    }

    private static func dataKey(key: String): String {
        return dataPrefix + key
    }

    func isInternalKey(key: String): Bool {
        return key.size > 1 && UInt32(key[0]) == UInt32(InternalPrefix)
    }

    func clear() {
        var intList: ArrayList<String> = ArrayList<String>()
        for (i in 0..length) {
            if (!this.isInternalKey(keys[i])) {
                intList.add(keys[i])
            }
        }
        for (i in 0..intList.size) {
            remove(intList[i])
        }
    }

    func dataIterator(): Iterator<(String, ?String)> {
        return 0..length |> filter {i: Int64 => keys[i].startsWith(dataPrefix)} |>
            map {i: Int64 => (keys[i], anyToString(vals[i]))}
    }

    func anyToString(any: ?Any): ?String {
        return match (any) {
            case Some(s: String) => s
            case _ => None
        }
    }
}

class AttributesIterator <: Iterator<Attribute> {
    var i: Int64 = 0
    var keys: Array<String>
    var vals: Array<?Any>
    var attrs: Attributes
    var length: Int64

    init(keys: Array<String>, vals: Array<?Any>, attrs: Attributes, length: Int64) {
        this.keys = keys
        this.vals = vals
        this.attrs = attrs
        this.length = length
    }

    private func hasNext(): Bool {
        while (i < length) {
            if (attrs.isInternalKey(keys[i])) {
                i++
            } else {
                break
            }
        }
        return i < length
    }

    public override func next(): Option<Attribute> {
        if (!hasNext()) {
            return None
        }
        var attr: Attribute = match (vals[i]) {
            case Some(v: String) => Attribute(keys[i], v, attrs)
            case _ => Attribute(keys[i], None, attrs)
        }
        i++
        return attr
    }
}
