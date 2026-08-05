/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A list of Elements, with methods that act on every element in the list.
 */
public class Elements <: ToString & Iterable<Element> & Equatable<Elements> {
    private var elementsValue: ArrayList<Element>

    public prop elementArr: ArrayList<Element> {
        get() {
            elementsValue
        }
    }

    public prop size: Int64 {
        get() {
            elementsValue.size
        }
    }

    public operator func [](i: Int64): Element {
        elementsValue[i]
    }

    public init() {
        elementsValue = ArrayList<Element>()
    }

    public init(initialCapacity: Int64) {
        elementsValue = ArrayList<Element>(initialCapacity)
    }

    public init(elements: Collection<Element>) {
        elementsValue = ArrayList<Element>(elements)
    }

    public init(elements: Array<Element>) {
        elementsValue = ArrayList<Element>(elements)
    }

    /*
     * Creates a deep copy of these elements.
     *
     * @return a deep copy
     */
    public func clone(): Elements {
        let clone: Elements = Elements(elementsValue.size)
        for (e in elementsValue) {
            clone.elementsValue.add(e.clone())
        }
        return clone
    }

    /*
     * Get an attribute value from the first matched element that has the attribute.
     *
     * @param attributeKey The attribute key.
     * @return The attribute value from the first matched element that has the attribute.. If no elements were matched (isEmpty() == true),
     * or if the no elements have the attribute, returns empty string.
     */
    public func attr(attributeKey: String): String {
        for (element in elementsValue) {
            if (element.hasAttr(attributeKey)) {
                return element.attr(attributeKey)
            }
        }
        return ""
    }

    /*
     * Checks if any of the matched elements have this attribute defined.
     *
     * @param attributeKey attribute key
     * @return true if any of the elements have the attribute; false if none do.
     */
    public func hasAttr(attributeKey: String): Bool {
        for (element in elementsValue) {
            if (element.hasAttr(attributeKey)) {
                return true
            }
        }
        return false
    }

    /*
     * Get the attribute value for each of the matched elements. If an element does not have this attribute, no value is
     * included in the result set for that element.
     *
     * @param attributeKey the attribute name to return values for. You can add the abs: prefix to the key to get absolute URLs from relative URLs, e.g.: doc.select("a").eachAttr("abs:href") .
     * @return a list of each element's attribute value for the attribute
     */
    public func eachAttr(attributeKey: String): ArrayList<String> {
        var attrs: ArrayList<String> = ArrayList<String>(elementsValue.size)
        for (element in elementsValue) {
            if (element.hasAttr(attributeKey)) {
                attrs.add(element.attr(attributeKey))
            }
        }
        return attrs
    }

    /*
     * Set an attribute on all matched elements.
     *
     * @param attributeKey attribute key
     * @param attributeValue attribute value
     * @return this
     */
    public func attr(attributeKey: String, attributeValue: String): Elements {
        for (element in elementsValue) {
            element.attr(attributeKey, attributeValue)
        }
        return this
    }

    /*
     * Remove an attribute from every matched element.
     *
     * @param attributeKey The attribute to remove.
     * @return this (for chaining)
     */
    public func removeAttr(attributeKey: String): Elements {
        for (element in elementsValue) {
            element.removeAttr(attributeKey)
        }
        return this
    }

    /*
     * Add the class name to every matched element's class attribute.
     *
     * @param className class name to add
     * @return this
     */
    public func addClass(className: String): Elements {
        for (element in elementsValue) {
            element.addClass(className)
        }
        return this
    }

    /*
     * Remove the class name from every matched element's class attribute, if present.
     *
     * @param className class name to remove
     * @return this
     */
    public func removeClass(className: String): Elements {
        for (element in elementsValue) {
            element.removeClass(className)
        }
        return this
    }

    /*
     * Toggle the class name on every matched element's class attribute.
     *
     * @param className class name to add if missing, or remove if present, from every element.
     * @return this
     */
    public func toggleClass(className: String): Elements {
        for (element in elementsValue) {
            element.toggleClass(className)
        }
        return this
    }

    /*
     * Determine if any of the matched elements have this class name set in their class attribute.
     *
     * @param className class name to check for
     * @return true if any do, false if none do
     */
    public func hasClass(className: String): Bool {
        for (element in elementsValue) {
            if (element.hasClass(className)) {
                return true
            }
        }
        return false
    }

    /*
     * Get the form element's value of the first matched element.
     *
     * @return The form element's value, or empty if not set.
     */
    public func val(): String {
        if (elementsValue.size > 0) {
            //noinspection ConstantConditions
            return first()().val()
        } else {
            return ""
        }
    }

    /*
     * Set the form element's value in each of the matched elements.
     *
     * @param value The value to set into each matched element
     * @return this (for chaining)
     */
    public func val(value: String): Elements {
        for (element in elementsValue) {
            element.val(value)
        }
        return this
    }

    /*
     * Get the combined text of all the matched elements.
     *
     * @return string of all text: unescaped and no HTML.
     */
    public func text(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        for (element in elementsValue) {
            if (sb.size != 0) {
                sb.append(" ")
            }
            sb.append(element.text())
        }
        return StringUtil.releaseBuilder(sb)
    }

    /*
     * Test if any matched Element has any text content, that is not just whitespace.
     *
     * @return true if any element has non-blank text content.
     */
    public func hasText(): Bool {
        for (element in elementsValue) {
            if (element.hasText()) {
                return true
            }
        }
        return false
    }

    /*
     * Get the text content of each of the matched elements. If an element has no text, then it is not included in the result.
     *
     * @return A list of each matched element's text content.
     */
    public func eachText(): ArrayList<String> {
        var texts: ArrayList<String> = ArrayList<String>(elementsValue.size)
        for (el in elementsValue) {
            if (el.hasText()) {
                texts.add(el.text())
            }
        }
        return texts
    }

    /*
     * Get the combined inner HTML of all matched elements.
     *
     * @return string of all element's inner HTML.
     */
    public func html(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        for (element in elementsValue) {
            if (sb.size != 0) {
                sb.append("\n")
            }
            sb.append(element.html())
        }
        return StringUtil.releaseBuilder(sb)
    }

    /*
     * Get the combined outer HTML of all matched elements.
     *
     * @return string of all element's outer HTML.
     */
    public func outerHtml(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        for (element in elementsValue) {
            if (sb.size != 0) {
                sb.append("\n")
            }
            sb.append(element.outerHtml())
        }
        return StringUtil.releaseBuilder(sb)
    }

    /*
     * Get the combined outer HTML of all matched elements. Alias of outerHtml().
     *
     * @return string of all element's outer HTML.
     */
    public func toString(): String {
        return outerHtml()
    }

    /*
     * Update (rename) the tag name of each matched element.
     * For example, to change each <i> to a <em>, do doc.select("i").tagName("em");
     *
     * @param tagName the new tag name
     * @return this, for chaining
     */
    public func tagName(tagName: String): Elements {
        for (element in elementsValue) {
            element.tagName(tagName)
        }
        return this
    }

    /*
     * Set the inner HTML of each matched element.
     *
     * @param html HTML to parse and set into each matched element.
     * @return this, for chaining
     */
    public func html(html: String): Elements {
        for (element in elementsValue) {
            element.html(html)
        }
        return this
    }

    /*
     * Add the supplied HTML to the start of each matched element's inner HTML.
     *
     * @param html HTML to add inside each element, before the existing HTML
     * @return this, for chaining
     */
    public func prepend(html: String): Elements {
        for (element in elementsValue) {
            element.prepend(html)
        }
        return this
    }

    /*
     * Add the supplied HTML to the end of each matched element's inner HTML.
     *
     * @param html HTML to add inside each element, after the existing HTML
     * @return this, for chaining
     */
    public func append(html: String): Elements {
        for (element in elementsValue) {
            element.append(html)
        }
        return this
    }

    /*
     * Insert the supplied HTML before each matched element's outer HTML.
     *
     * @param html HTML to insert before each element
     * @return this, for chaining
     */
    public func before(html: String): Elements {
        for (element in elementsValue) {
            element.before(html)
        }
        return this
    }

    /*
     * Insert the supplied HTML after each matched element's outer HTML.
     *
     * @param html HTML to insert after each element
     * @return this, for chaining
     */
    public func after(html: String): Elements {
        for (element in elementsValue) {
            element.after(html)
        }
        return this
    }

    /*
     * Wrap the supplied HTML around each matched elements.
     * For example, with HTML <p><b>This</b> is <b>Jsoup</b></p>,
     * doc.select("b").wrap("<i></i>");
     * becomes <p><i><b>This</b></i> is <i><b>jsoup</b></i></p>
     *
     * @param html HTML to wrap around each element, e.g. <div class="head"></div>. Can be arbitrarily deep.
     * @return this (for chaining)
     */
    public func wrap(html: String): Elements {
        Validate.notEmpty(html)
        for (element in elementsValue) {
            element.wrap(html)
        }
        return this
    }

    /*
     * Removes the matched elements from the DOM, and moves their children up into their parents.
     * This has the effect of dropping the elements but keeping their children.
     * E.g. with HTML:
     * <div><font>One</font> <font><a href="/">Two</a></font></div>
     * doc.select("font").unwrap();
     * HTML = <div>One <a href="/">Two</a></div>
     *
     * @return this (for chaining)
     */
    public func unwrap(): Elements {
        for (element in elementsValue) {
            element.unwrap()
        }
        return this
    }

    /*
     * Empty (remove all child nodes from) each matched element.
     * E.g. HTML: <div><p>Hello <b>there</b></p> <p>now</p></div>
     * doc.select("p").empty();
     * HTML = <div><p></p> <p></p></div>
     *
     * @return this, for chaining
     */
    public func empty(): Elements {
        for (element in elementsValue) {
            element.empty()
        }
        return this
    }

    /*
     * Remove each matched element from the DOM. This is similar to setting the outer HTML of each element to nothing.
     * E.g. HTML: <div><p>Hello</p> <p>there</p> <img /></div>
     * doc.select("p").remove();
     * HTML = <div> <img /></div>
     *
     * @return this, for chaining
     */
    public func remove(): Elements {
        for (element in elementsValue) {
            element.remove()
        }
        return this
    }

    /*
     * Find matching elements within this element list.
     *
     * @param query A Selector query
     * @return the filtered list of elements, or an empty list if none match.
     */
    public func select(query: String): Elements {
        return Selector.select(query, this.elementsValue)
    }

    /*
     * Remove elements from this list that match the Selector query.
     * E.g. HTML: <div class=logo>One</div> <div>Two</div>
     * let divs = doc.select("div").not(".logo")
     * Result: divs: [<div>Two</div>]
     *
     * @param query the selector query whose results should be removed from these elements
     * @return a new elements list that contains only the filtered results
     */
    public func not(query: String): Elements {
        var out: Elements = Selector.select(query, this.elementsValue)
        return Selector.filterOut(this.elementsValue, out.elementsValue)
    }

    /*
     * Get the nth matched element as an Elements object.
     *
     * @param index the (zero-based) index of the element in the list to retain
     * @return Elements containing only the specified element, or, if that element did not exist, an empty list.
     */
    public func eq(index: Int64): Elements {
        return if (elementsValue.size > index) {
            Elements(elementsValue[index])
        } else {
            Elements()
        }
    }

    /*
     * Test if any of the matched elements match the supplied query.
     *
     * @param query A selector
     * @return true if at least one element in the list matches the query.
     */
    public func check(query: String): Bool {
        var eval: Evaluator = QueryParser.parse(query)
        for (el in elementsValue) {
            if (el.check(eval)) {
                return true
            }
        }
        return false
    }

    /*
     * Get the immediate next element sibling of each element in this list.
     *
     * @return next element siblings.
     */
    public func next(): Elements {
        return siblings(None, true, false)
    }

    /*
     * Get the immediate next element sibling of each element in this list, filtered by the query.
     *
     * @param query CSS query to match siblings against
     * @return next element siblings.
     */
    public func next(query: String): Elements {
        return siblings(query, true, false)
    }

    /*
     * Get each of the following element siblings of each element in this list.
     *
     * @return all following element siblings.
     */
    public func nextAll(): Elements {
        return siblings(None, true, true)
    }

    /*
     * Get each of the following element siblings of each element in this list, that match the query.
     *
     * @param query CSS query to match siblings against
     * @return all following element siblings.
     */
    public func nextAll(query: String): Elements {
        return siblings(query, true, true)
    }

    /*
     * Get the immediate previous element sibling of each element in this list.
     *
     * @return previous element siblings.
     */
    public func prev(): Elements {
        return siblings(None, false, false)
    }

    /*
     * Get the immediate previous element sibling of each element in this list, filtered by the query.
     *
     * @param query CSS query to match siblings against
     * @return previous element siblings.
     */
    public func prev(query: String): Elements {
        return siblings(query, false, false)
    }

    /*
     * Get each of the previous element siblings of each element in this list.
     *
     * @return all previous element siblings.
     */
    public func prevAll(): Elements {
        return siblings(None, false, true)
    }

    /*
     * Get each of the previous element siblings of each element in this list, that match the query.
     *
     * @param query CSS query to match siblings against
     * @return all previous element siblings.
     */
    public func prevAll(query: String): Elements {
        return siblings(query, false, true)
    }

    private func siblings(query: ?String, next: Bool, all: Bool): Elements {
        let els: Elements = Elements()
        let eval: ?Evaluator = if (query != None) {
            QueryParser.parse(query())
        } else {
            None
        }
        for (i in 0..elementsValue.size) {
            var e = elementsValue[i]
            do {
                let sib: ?Element = if (next) {
                    e.nextElementSibling()
                } else {
                    e.previousElementSibling()
                }
                if (sib == None) {
                    break
                }
                if (eval.isNone()) {
                    els.elementsValue.add(sib())
                } else if (sib().check(eval())) {
                    els.elementsValue.add(sib())
                }
                e = sib()
            } while (all)
        }
        return els
    }

    /*
     * Get all of the parents and ancestor elements of the matched elements.
     *
     * @return all of the parents and ancestor elements of the matched elements
     */
    public func parents(): Elements {
        let combo: ArraySet<Element> = ArraySet<Element>()
        for (el in elementsValue) {
            combo.putAll(el.parents().elementsValue)
        }
        return Elements(combo.set)
    }

    /*
     * Get the first matched element.
     *
     * @return The first matched element, or none if contents is empty.
     */
    public func first(): ?Element {
        if (elementsValue.isEmpty()) {
            return None
        } else {
            return elementsValue[0]
        }
    }

    /*
     * Get the last matched element.
     *
     * @return The last matched element, or none if contents is empty.
     */
    public func last(): ?Element {
        return if (elementsValue.isEmpty()) {
            None
        } else {
            elementsValue[elementsValue.size - 1]
        }
    }

    /*
     * Perform a depth-first traversal on each of the selected elements.
     *
     * @param nodeVisitor the visitor callbacks to perform on each node
     * @return this, for chaining
     */
    public func traverse(nodeVisitor: NodeVisitor): Elements {
        NodeTraversor.traverse(nodeVisitor, this)
        return this
    }

    /*
     * Perform a depth-first filtering on each of the selected elements.
     *
     * @param nodeFilter the filter callbacks to perform on each node
     * @return this, for chaining
     */
    public func filter(nodeFilter: NodeFilter): Elements {
        NodeTraversor.filter(nodeFilter, this)
        return this
    }

    /*
     * Get the FormElement forms from the selected elements, if any.
     *
     * @return a list of FormElements pulled from the matched elements. The list will be empty if the elements contain no forms.
     */
    public func forms(): ArrayList<FormElement> {
        var forms: ArrayList<FormElement> = ArrayList<FormElement>()
        for (el in elementsValue) {
            if (el is FormElement) {
                forms.add((el as FormElement)())
            }
        }
        return forms
    }

    /*
     * Get Comment nodes that are direct child nodes of the selected elements.
     *
     * @return Comment nodes, or an empty list if none.
     */
    public func comments(): ArrayList<Comment> {
        return childNodesOfType<Comment>()
    }

    /*
     * Get TextNode nodes that are direct child nodes of the selected elements.
     *
     * @return TextNode nodes, or an empty list if none.
     */
    public func textNodes(): ArrayList<TextNode> {
        return childNodesOfType<TextNode>()
    }

    /*
     * Get DataNode nodes that are direct child nodes of the selected elements. DataNode nodes contain the
     * content of tags such as script, style etc and are distinct from TextNodes.
     *
     * @return Data nodes, or an empty list if none.
     */
    public func dataNodes(): ArrayList<DataNode> {
        return childNodesOfType<DataNode>()
    }

    func childNodesOfType<T>(): ArrayList<T> {
        var nodes: ArrayList<T> = ArrayList<T>()
        for (el in elementsValue) {
            for (i in 0..el.childNodeSize()) {
                var node: Node = el.childNode(i)
                if (node is T) {
                    var comment: T = (node as T)()
                    nodes.add(comment)
                }
            }
        }
        return nodes
    }

    public func iterator(): Iterator<Element> {
        return elementArr.iterator()
    }

    public operator func !=(that: Elements): Bool {
        return !(this == that)
    }

    public operator func ==(that: Elements): Bool {
        if (this.elementArr.size != that.elementArr.size) {
            return false
        }
        for (i in 0..this.elementArr.size) {
            if (this.elementArr[i] != that.elementArr[i]) {
                return false
            }
        }
        return true
    }
}

class ArraySet<T> where T <: Hashable & Equatable<T> {
    let set: HashSet<T> = HashSet<T>()
    let arr: ArrayList<T> = ArrayList<T>()
    func put(e: T): Bool {
        if (set.add(e)) {
            arr.add(e)
            return true
        }
        return false
    }
    func putAll(eles: Collection<T>): Unit {
        for (e in eles) {
            put(e)
        }
    }
}
