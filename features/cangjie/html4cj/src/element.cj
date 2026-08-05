/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * An HTML Element consists of a tag name, attributes, and child nodes (including text nodes and other elements).
 * From an Element, you can extract data, traverse the node graph, and manipulate the HTML.
 */
public open class Element <: Node & Equatable<Element> {
    private let EmptyChildren: ArrayList<Element> = ArrayList<Element>()

    private let classSplit: Regex = Regex("\\s+")

    private let BaseUriKey: String = Attributes.internalKey("baseUri")

    var tagValue: Tag

    var childNodesValue: ArrayList<Node>

    // field is nullable but all methods for attributes are non-null
    var attributesValue: ?Attributes

    /*
     * Create a new, standalone element.
     *
     * @param tag tag name
     */
    public init(tag: String) {
        this(Tag.valueOf(tag), "", None)
    }

    /*
     * Create a new, standalone Element. (Standalone in that it has no parent.)
     *
     * @param tag tag of this element
     * @param baseUri the base URI (optional, may be null to inherit from parent, or "" to clear parent's)
     * @param attributes initial attributes (optional, may be null)
     */
    public init(tag: Tag, baseUri: ?String, attributesValue: ?Attributes) {
        this.childNodesValue = EmptyNodes
        this.attributesValue = attributesValue
        this.tagValue = tag
        if (baseUri != None) {
            if (this.attributesValue == None) {
                // not using hasAttributes, as doesn't clear warning
                this.attributesValue = Attributes()
            }
            this.attributesValue().put(BaseUriKey, baseUri)
        }
    }

    /*
     * Create a new Element from a Tag and a base URI.
     *
     * @param tag element tag
     * @param baseUri the base URI of this element. Optional, and will inherit from its parent, if any.
     */
    public init(tag: Tag, baseUri: ?String) {
        this(tag, baseUri, None)
    }

    /*
     * Internal test to check if a nodelist object has been created.
     */
    protected func hasChildNodes(): Bool {
        return childNodesValue != EmptyNodes
    }

    protected func ensureChildNodes(): ArrayList<Node> {
        if (childNodesValue == EmptyNodes) {
            childNodesValue = ArrayList<Node>(4)
        }
        return childNodesValue
    }

    protected override func hasAttributes(): Bool {
        return attributesValue != None
    }

    public override func attributes(): Attributes {
        if (attributesValue == None) {
            // not using hasAttributes, as doesn't clear warning
            attributesValue = Attributes()
        }
        return attributesValue()
    }

    public override func baseUri(): String {
        return searchUpForAttribute(this, BaseUriKey)
    }

    private static func searchUpForAttribute(start: ?Element, key: String): String {
        var el: ?Element = start
        while (el != None) {
            if (el().attributesValue != None) {
                if (el().attributesValue().hasKey(key)) {
                    return el().attributesValue().get(key)
                }
            }
            el = el().parentElement()
        }
        return ""
    }

    protected override func doSetBaseUri(baseUri: String): Unit {
        attributes().put(BaseUriKey, baseUri)
    }

    public override func childNodeSize(): Int64 {
        return childNodesValue.size
    }

    public open override func nodeName(): String {
        return tagValue.getName()
    }

    /*
     * Get the name of the tag for this element.
     *
     * @return the tag name
     */
    public func tagName(): String {
        return tagValue.getName()
    }

    /*
     * Get the normalized name of this Element's tag. This will always be the lower-cased version of the tag, regardless
     * of the tag case preserving setting of the parser.
     *
     * @return normal name
     */
    public override func normalName(): String {
        return tagValue.normalName()
    }

    /*
     * Change (rename) the tag of this element.
     *
     * @param tagName new tag name for this element
     * @return this element, for chaining
     */
    public func tagName(tagName: String): Element {
        Validate.notEmptyParam(tagName, "tagName")

        // maintains the case option of the original parse
        tagValue = Tag.valueOf(tagName, NodeUtils.parser(this).settings())
        return this
    }

    /*
     * Get the Tag for this element.
     *
     * @return the tag object
     */
    public func tag(): Tag {
        return tagValue
    }

    /*
     * Test if this element is a block-level element.
     *
     * @return true if block, false if not (and thus inline)
     */
    public func isBlock(): Bool {
        return tagValue.isBlock()
    }

    /*
     * Get the id attribute of this element.
     *
     * @return The id attribute, if present, or an empty string if not.
     */
    public func id(): String {
        return match (attributesValue) {
            case None => ""
            case Some(v) => v.getIgnoreCase("id")
        }
    }

    /*
     * Set the id attribute of this element.
     *
     * @param id the ID value to use
     * @return this Element, for chaining
     */
    public func id(id: String): Element {
        attr("id", id)
        return this
    }

    /*
     * Set an attribute value on this element. If this element already has an attribute with the
     * key, its value is updated; otherwise, a new attribute is added.
     *
     * @return this element
     */
    public func attr(attributeKey: String, attributeValue: String): Element {
        super.attr(attributeKey, attributeValue)
        return this
    }

    /*
     * Set a boolean attribute value on this element.
     *
     * @param attributeKey the attribute key
     * @param attributeValue the attribute value
     * @return this element
     */
    public func attr(attributeKey: String, attributeValue: Bool): Element {
        attributes().put(attributeKey, attributeValue)
        return this
    }

    /*
     * Get this element's HTML5 custom data attributes. Each attribute in the element that has a key
     * starting with "data-" is included the dataset.
     *
     * @return a map of key=value custom data attributes.
     */
    public func dataset(): Iterator<(String, ?String)> {
        return attributes().dataset()
    }

    public func parentElement(): ?Element {
        match (parentNodeAll) {
            case Some(v: Element) => return v
            case _ => return None
        }
    }

    /*
     * Get this element's parent and ancestors, up to the document root.
     *
     * @return this element's stack of parents, starting with the closest first.
     */
    public func parents(): Elements {
        var parents: Elements = Elements()
        var parent: ?Element = this.parentElement()
        while (parent != None && !parent().isNodeNew("#root")) {
            parents.elementArr.add(parent())
            parent = parent().parentElement()
        }
        return parents
    }

    /*
     * Get a child element of this element, by its 0-based index number.
     *
     * @param index the index number of the element to retrieve
     * @return the child element
     */
    public func child(index: Int64): Element {
        return childElementsList()[index]
    }

    /*
     * Get the number of child nodes of this element that are elements.
     *
     * @return the number of child nodes that are elements
     */
    public func childrenSize(): Int64 {
        return childElementsList().size
    }

    /*
     * Get this element's child elements.
     *
     * @return child elements. If this element has no children, returns an empty list.
     */
    public func children(): Elements {
        return Elements(childElementsList())
    }

    /*
     * Maintains a shadow copy of this element's child elements. If the nodelist is changed, this cache is invalidated.
     *
     * @return a list of child elements
     */
    func childElementsList(): ArrayList<Element> {
        if (childNodeSize() == 0) {
            // short circuit creating empty
            return EmptyChildren
        }
        var children: ArrayList<Element>
        let size: Int64 = childNodesValue.size
        children = ArrayList<Element>(size)
        for (i in 0..size) {
            let node: Node = childNodesValue[i]
            match (node) {
                case v: Element => children.add(v)
                case _ => ()
            }
        }
        return children
    }

    /*
     * Get this element's child text nodes. The list is unmodifiable but the text nodes may be manipulated.
     *
     * @return child text nodes. If this element has no text nodes, returns an empty list.
     */
    public func textNodes(): ArrayList<TextNode> {
        var textNodes: ArrayList<TextNode> = ArrayList<TextNode>()
        for (node in childNodesValue) {
            match (node) {
                case v: TextNode => textNodes.add(v)
                case _ => ()
            }
        }
        return textNodes
    }

    /*
     * Get this element's child data nodes. The list is unmodifiable but the data nodes may be manipulated.
     *
     * @return child data nodes. If this element has no data nodes, returns an empty list.
     */
    public func dataNodes(): ArrayList<DataNode> {
        var dataNodes: ArrayList<DataNode> = ArrayList<DataNode>()
        for (node in childNodesValue) {
            match (node) {
                case v: DataNode => dataNodes.add(v)
                case _ => ()
            }
        }
        return dataNodes
    }

    /*
     * Find elements that match the Selector CSS query, with this element as the starting context. Matched elements may include this element, or any of its children.
     *
     * @param cssQuery a Selector CSS-like query
     * @return an Elements list containing elements that match the query (empty if none match)
     */
    public func select(cssQuery: String): Elements {
        return Selector.select(cssQuery, this)
    }

    /*
     * Find elements that match the supplied Evaluator. This has the same functionality as select(String), but
     * may be useful if you are running the same query many times (on many documents) and want to save the overhead of
     * repeatedly parsing the CSS query.
     *
     * @param evaluator an element evaluator
     * @return an Elements list containing elements that match the query (empty if none match)
     */
    public func select(evaluator: Evaluator): Elements {
        return Selector.select(evaluator, this)
    }

    /*
     * Find the first Element that matches the Selector CSS query, with this element as the starting context.
     *
     * @param cssQuery cssQuery a Selector CSS-like query
     * @return the first matching element, or null if there is no match.
     */
    public func selectFirst(cssQuery: String): ?Element {
        return Selector.selectFirst(cssQuery, this)
    }

    /*
     * Finds the first Element that matches the supplied Evaluator, with this element as the starting context, or null if none match.
     *
     * @param evaluator an element evaluator
     * @return the first matching element (walking down the tree, starting from this element), or null if none match.
     */
    public func selectFirst(evaluator: Evaluator): ?Element {
        return Collector.findFirst(evaluator, this)
    }

    /*
     * Just like selectFirst(String), but if there is no match, throws an IllegalArgumentException. This is useful if you want to simply abort processing on a failed match.
     *
     * @param cssQuery a Selector CSS-like query
     * @return the first matching element
     */
    public func expectFirst(cssQuery: String): Element {
        let message: String = match (parentElement()) {
            case None => "No elements matched the query '${cssQuery}' in the document."
            case _ => "No elements matched the query '${cssQuery}' on element '${this.tagName()}'."
        }
        return Validate.ensureNotNull(Selector.selectFirst(cssQuery, this), message)
    }

    /*
     * Checks if this element matches the given Selector CSS query. Also knows as matches() in the Web DOM.
     *
     * @param cssQuery a Selector CSS query
     * @return if this element matches the query
     */
    public func check(cssQuery: String): Bool {
        return check(QueryParser.parse(cssQuery))
    }

    /*
     * Check if this element matches the given evaluator.
     *
     * @param evaluator an element evaluator
     * @return if this element matches
     */
    public func check(evaluator: Evaluator): Bool {
        return evaluator.matches(this.root(), this)
    }

    /*
     * Find the closest element up the tree of parents that matches the specified CSS query. Will return itself, an
     * ancestor, or null if there is no such matching element.
     *
     * @param cssQuery a Selector CSS query
     * @return the closest ancestor element (possibly itself) that matches the provided evaluator. null if not found.
     */
    public func closest(cssQuery: String): ?Element {
        return closest(QueryParser.parse(cssQuery))
    }

    /*
     * Find the closest element up the tree of parents that matches the specified evaluator. Will return itself, an
     * ancestor, or null if there is no such matching element.
     *
     * @param evaluator a query evaluator
     * @return the closest ancestor element (possibly itself) that matches the provided evaluator. null if not found.
     */
    public func closest(evaluator: Evaluator): ?Element {
        var el: ?Element = this
        let root: Element = root()
        do {
            if (evaluator.matches(root, el())) {
                return el
            }
            el = el().parentElement()
        } while (el != None)
        return None
    }

    /*
     * Insert a node to the end of this Element's children. The incoming node will be re-parented.
     *
     * @param child node to add.
     * @return this Element, for chaining
     */
    public func appendChild(child: Node): Element {
        // was - Node#addChildren(child). short-circuits an array create and a loop.
        reparentChild(child)
        ensureChildNodes()
        childNodesValue.add(child)
        child.setSiblingIndex(childNodesValue.size - 1)
        return this
    }

    /*
     * Insert the given nodes to the end of this Element's children.
     *
     * @param children nodes to add
     * @return this Element, for chaining
     */
    public func appendChildren(children: Collection<Node>): Element {
        insertChildren(-1, children)
        return this
    }

    /*
     * Add this element to the supplied parent element, as its next child.
     *
     * @param parent element to which this element will be appended
     * @return this element, so that you can continue modifying the element
     */
    public func appendTo(parent: Element): Element {
        parent.appendChild(this)
        return this
    }

    /*
     * Add a node to the start of this element's children.
     *
     * @param child node to add.
     * @return this element, so that you can add more child nodes or elements.
     */
    public func prependChild(child: Node): Element {
        addChildren(0, child)
        return this
    }

    /*
     * Insert the given nodes to the start of this Element's children.
     *
     * @param children nodes to add
     * @return this Element, for chaining
     */
    public func prependChildren(children: Collection<Node>): Element {
        insertChildren(0, children)
        return this
    }

    /*
     * Inserts the given child nodes into this element at the specified index. Current nodes will be shifted to the
     * right. The inserted nodes will be moved from their current parent. To prevent moving, copy the nodes first.
     *
     * @param index 0-based index to insert children at. Specify 0 to insert at the start, -1 at the end
     * @param children child nodes to insert
     * @return this element, for chaining.
     */
    public func insertChildren(index: Int64, children: Collection<Node>): Element {
        var currentSize: Int64 = childNodeSize()
        var indexNew: Int64 = index

        // roll around
        if (indexNew < 0) {
            indexNew += currentSize + 1
        }
        Validate.isTrue(indexNew >= 0 && indexNew <= currentSize, "Insert position out of bounds.")
        var nodeArray: Array<Node> = children.toArray()
        addChildren(indexNew, nodeArray)
        return this
    }

    /*
     * Inserts the given child nodes into this element at the specified index. Current nodes will be shifted to the
     * right. The inserted nodes will be moved from their current parent. To prevent moving, copy the nodes first.
     *
     * @param index 0-based index to insert children at. Specify 0 to insert at the start, -1 at the end
     * @param children child nodes to insert
     * @return this element, for chaining.
     */
    public func insertChildren(index: Int64, children: Array<Node>): Element {
        var currentSize: Int64 = childNodeSize()
        var indexNew: Int64 = index

        // roll around
        if (indexNew < 0) {
            indexNew += currentSize + 1
        }
        Validate.isTrue(indexNew >= 0 && indexNew <= currentSize, "Insert position out of bounds.")

        addChildren(indexNew, children)
        return this
    }

    /*
     * Create a new element by tag name, and add it as the last child.
     *
     * @param tagName the name of the tag.
     * @return the new element, to allow you to add content to it,
     */
    public func appendElement(tagName: String): Element {
        var child: Element = Element(Tag.valueOf(tagName, NodeUtils.parser(this).settings()), baseUri())
        appendChild(child)
        return child
    }

    /*
     * Create a new element by tag name, and add it as the first child.
     *
     * @param tagName the name of the tag .
     * @return the new element, to allow you to add content to it
     */
    public func prependElement(tagName: String): Element {
        var child: Element = Element(Tag.valueOf(tagName, NodeUtils.parser(this).settings()), baseUri())
        prependChild(child)
        return child
    }

    /*
     * Create and append a new TextNode to this element.
     *
     * @param text the (un-encoded) text to add
     * @return this element
     */
    public func appendText(text: String): Element {
        var node: TextNode = TextNode(text)
        appendChild(node)
        return this
    }

    /*
     * Create and prepend a new TextNode to this element.
     *
     * @param text the decoded text to add
     * @return this element
     */
    public func prependText(text: String): Element {
        var node: TextNode = TextNode(text)
        prependChild(node)
        return this
    }

    /*
     * Add inner HTML to this element. The supplied HTML will be parsed, and each node appended to the end of the children.
     *
     * @param html HTML to add inside this element, after the existing HTML
     * @return this element
     */
    public func append(html: String): Element {
        var nodes: ArrayList<Node> = NodeUtils.parser(this).parseFragmentInput(html, this, baseUri())
        addChildren(nodes.toArray())
        return this
    }

    /*
     * Add inner HTML into this element. The supplied HTML will be parsed, and each node prepended to the start of the element's children.
     *
     * @param html HTML to add inside this element, before the existing HTML
     * @return this element
     */
    public func prepend(html: String): Element {
        var nodes: ArrayList<Node> = NodeUtils.parser(this).parseFragmentInput(html, this, baseUri())
        addChildren(0, nodes.toArray())
        return this
    }

    /*
     * Insert the specified HTML into the DOM before this element (as a preceding sibling).
     *
     * @param html HTML to add before this element
     * @return this element, for chaining
     */
    public override func before(html: String): Element {
        return (super.before(html) as Element)()
    }

    /*
     * Insert the specified node into the DOM before this node (as a preceding sibling).
     *
     * @param node to add before this element
     * @return this Element, for chaining
     */
    public override func before(node: Node): Element {
        return (super.before(node) as Element)()
    }

    /*
     * Insert the specified HTML into the DOM after this element (as a following sibling).
     *
     * @param html HTML to add after this element
     * @return this element, for chaining
     */
    public override func after(html: String): Element {
        return (super.after(html) as Element)()
    }

    /*
     * Insert the specified node into the DOM after this node (as a following sibling).
     * @param node to add after this element
     * @return this element, for chaining
     * @see #before(Node)
     */
    public override func after(node: Node): Element {
        return (super.after(node) as Element)()
    }

    /*
     * Remove all the element's child nodes. Any attributes are left as-is.
     *
     * @return this element
     */
    public override func empty(): Element {
        childNodesValue.clear()
        return this
    }

    /*
     * Wrap the supplied HTML around this element.
     *
     * @param html HTML to wrap around this element
     * @return this element, for chaining.
     */
    public override func wrap(html: String): Element {
        return (super.wrap(html) as Element)()
    }

    /*
     * Get a CSS selector that will uniquely select this element.
     *
     * @return the CSS Path that can be used to retrieve the element in a selector.
     */
    public func cssSelector(): String {
        if (id().size > 0) {
            // prefer to return the ID - but check that it's actually unique first!
            var idSel: String = "#" + TokenQueue.escapeCssIdentifier(id())
            var doc: ?Document = ownerDocument()
            match (doc) {
                case None => return idSel
                case Some(v) =>
                    var els: Elements = v.select(idSel)

                    // otherwise, continue to the nth-child impl
                    if (els.elementArr.size == 1) {
                        if (els.elementArr[0] == this) {
                            return idSel
                        }
                    }
            }
        }

        // Escape tagname, and translate HTML namespace ns:tag to CSS namespace syntax ns|tag
        var tagName: String = TokenQueue.escapeCssIdentifier(tagName()).replace("\\:", "|")
        var selector: StringBuilder = StringUtil.borrowBuilder()
        selector.append(tagName)
        var escapedClasses: StringJoiner = StringJoiner(".")
        for (name in classNames()) {
            escapedClasses.add(TokenQueue.escapeCssIdentifier(name))
        }
        var classes: String = escapedClasses.complete()
        if (classes.size > 0) {
            selector.append(r'.')
            selector.append(classes)
        }
        if (parent() == None) {
            // don't add Document to selector, as will always have a html node
            return StringUtil.releaseBuilder(selector)
        } else if (parentElement()() is Document) {
            // don't add Document to selector, as will always have a html node
            return StringUtil.releaseBuilder(selector)
        }
        if (parentElement()().select(selector.toString()).elementArr.size > 1) {
            selector.append(":nth-child(${elementSiblingIndex() + 1})")
        }
        return parentElement()().cssSelector() + " > " + StringUtil.releaseBuilder(selector)
    }

    /*
     * Get sibling elements. If the element has no sibling elements, returns an empty list. An element is not a sibling
     * of itself, so will not be included in the returned list.
     *
     * @return sibling elements
     */
    public func siblingElements(): Elements {
        if (parentNodeAll == None) {
            return Elements(0)
        }
        var elements: ArrayList<Element> = parentElement()().childElementsList()
        var siblings: Elements = Elements(elements.size - 1)
        for (el in elements) {
            if (el != this) {
                siblings.elementArr.add(el)
            }
        }
        return siblings
    }

    /*
     * Gets the next sibling element of this element.
     *
     * @return the next element, or null if there is no next element
     */
    public func nextElementSibling(): ?Element {
        if (parentNodeAll == None) {
            return None
        }
        var siblings: ArrayList<Element> = (parent()() as Element)().childElementsList()
        var index: Int64 = indexInList(this, siblings)
        if (siblings.size > index + 1) {
            return siblings[index + 1]
        } else {
            return None
        }
    }

    /*
     * Get each of the sibling elements that come after this element.
     *
     * @return each of the element siblings after this element, or an empty list if there are no next sibling elements
     */
    public func nextElementSiblings(): Elements {
        return nextElementSiblings(true)
    }

    /*
     * Gets the previous element sibling of this element.
     *
     * @return the previous element, or null if there is no previous element
     * @see #nextElementSibling()
     */
    public func previousElementSibling(): ?Element {
        if (parentNodeAll == None) {
            return None
        }
        var siblings: ArrayList<Element> = (parent()() as Element)().childElementsList()
        var index: Int64 = indexInList(this, siblings)
        if (index > 0) {
            return siblings[index - 1]
        } else {
            return None
        }
    }

    /*
     * Get each of the element siblings before this element.
     *
     * @return the previous element siblings, or an empty list if there are none.
     */
    public func previousElementSiblings(): Elements {
        return nextElementSiblings(false)
    }

    private func nextElementSiblings(next: Bool): Elements {
        var els: Elements = Elements()
        if (parentNodeAll == None) {
            return els
        }
        els.elementArr.add(this)
        if (next) {
            return els.nextAll()
        } else {
            return els.prevAll()
        }
    }

    /*
     * Gets the first Element sibling of this element. That may be this element.
     *
     * @return the first sibling that is an element (aka the parent's first element child)
     */
    public func firstElementSibling(): Element {
        if (parent() != None) {
            var siblings: ArrayList<Element> = parentElement()().childElementsList()
            if (siblings.size > 1) {
                return siblings[0]
            } else {
                return this
            }
        } else {
            // orphan is its own first sibling
            return this
        }
    }

    /*
     * Get the list index of this element in its element sibling list.
     *
     * @return position in element sibling list
     */
    public func elementSiblingIndex(): Int64 {
        if (parent() == None) {
            return 0
        }
        return indexInList(this, parentElement()().childElementsList())
    }

    /*
     * Gets the last element sibling of this element. That may be this element.
     *
     * @return the last sibling that is an element (aka the parent's last element child)
     */
    public func lastElementSibling(): Element {
        if (parent() != None) {
            var siblings: ArrayList<Element> = parentElement()().childElementsList()
            if (siblings.size > 1) {
                return siblings[siblings.size - 1]
            } else {
                return this
            }
        } else {
            return this
        }
    }

    private static func indexInList(search: Element, elements: ArrayList<Element>): Int64 {
        var size: Int64 = elements.size
        for (i in 0..size) {
            if (elements[i] == search) {
                return i
            }
        }
        return 0
    }

    /*
     * Gets the first child of this Element that is an Element, or code null if there is none.
     *
     * @return the first Element child node, or null.
     */
    public func firstElementChild(): ?Element {
        var size: Int64 = childNodeSize()
        if (size == 0) {
            return None
        }
        var children: ArrayList<Node> = ensureChildNodes()
        for (i in 0..size) {
            var node: Node = children[i]
            match (node) {
                case v: Element => return v
                case _ => ()
            }
        }
        return None
    }

    /*
     * Gets the last child of this Element that is an Element, or code null if there is none.
     *
     * @return the last Element child node, or null.
     */
    public func lastElementChild(): ?Element {
        let size: Int64 = childNodeSize()
        if (size == 0) {
            return None
        }
        var children: ArrayList<Node> = ensureChildNodes()
        for (i in (size - 1)..=0 : -1) {
            var node: Node = children[i]
            match (node) {
                case v: Element => return v
                case _ => ()
            }
        }
        return None
    }

    /*
     * Finds elements, including and recursively under this element, with the specified tag name.
     *
     * @param tagName The tag name to search for (case insensitively).
     * @return a matching unmodifiable list of elements. Will be empty if this element and none of its children match.
     */
    public func getElementsByTag(tagName: String): Elements {
        Validate.notEmpty(tagName)
        var tagNameNew = tagName
        tagNameNew = Normalizer.normalize(tagNameNew)
        return Collector.collect(EvaluatorTag(tagNameNew), this)
    }

    /*
     * Find an element by ID, including or under this element.
     *
     * @param id The ID to search for.
     * @return The first matching element by ID, starting with this element, or null if none found.
     */
    public func getElementById(id: String): ?Element {
        Validate.notEmpty(id)
        var elements: Elements = Collector.collect(EvaluatorId(id), this)
        if (elements.elementArr.size > 0) {
            return elements.elementArr[0]
        } else {
            return None
        }
    }

    /*
     * Find elements that have this class, including or under this element. Case-insensitive.
     *
     * @param className the name of the class to search for.
     * @return elements with the supplied class name, empty if none
     */
    public func getElementsByClass(className: String): Elements {
        Validate.notEmpty(className)
        return Collector.collect(EvaluatorClass(className), this)
    }

    /*
     * Find elements that have a named attribute set. Case-insensitive.
     *
     * @param key name of the attribute
     * @return elements that have this attribute, empty if none
     */
    public func getElementsByAttribute(key: String): Elements {
        Validate.notEmpty(key)
        var keyNew: String = key.strip()
        return Collector.collect(EvaluatorAttribute(keyNew), this)
    }

    /*
     * Find elements that have an attribute name starting with the supplied prefix.
     *
     * @param keyPrefix name prefix of the attribute
     * @return elements that have attribute names that start with the prefix, empty if none.
     */
    public func getElementsByAttributeStarting(keyPrefix: String): Elements {
        Validate.notEmpty(keyPrefix)
        var keyPrefixNew: String = keyPrefix.strip()
        return Collector.collect(EvaluatorAttributeStarting(keyPrefixNew), this)
    }

    /*
     * Find elements that have an attribute with the specific value. Case-insensitive.
     *
     * @param key name of the attribute
     * @param value value of the attribute
     * @return elements that have this attribute with this value, empty if none
     */
    public func getElementsByAttributeValue(key: String, value: String): Elements {
        return Collector.collect(EvaluatorAttributeWithValue(key, value), this)
    }

    /*
     * Find elements that either do not have this attribute, or have it with a different value. Case-insensitive.
     *
     * @param key name of the attribute
     * @param value value of the attribute
     * @return elements that do not have a matching attribute
     */
    public func getElementsByAttributeValueNot(key: String, value: String): Elements {
        return Collector.collect(EvaluatorAttributeWithValueNot(key, value), this)
    }

    /*
     * Find elements that have attributes that start with the value prefix. Case-insensitive.
     *
     * @param key name of the attribute
     * @param valuePrefix start of attribute value
     * @return elements that have attributes that start with the value prefix
     */
    public func getElementsByAttributeValueStarting(key: String, valuePrefix: String): Elements {
        return Collector.collect(EvaluatorAttributeWithValueStarting(key, valuePrefix), this)
    }

    /*
     * Find elements that have attributes that end with the value suffix. Case-insensitive.
     *
     * @param key name of the attribute
     * @param valueSuffix end of the attribute value
     * @return elements that have attributes that end with the value suffix
     */
    public func getElementsByAttributeValueEnding(key: String, valueSuffix: String): Elements {
        return Collector.collect(EvaluatorAttributeWithValueEnding(key, valueSuffix), this);
    }

    /*
     * Find elements that have attributes whose value contains the match string. Case-insensitive.
     *
     * @param key name of the attribute
     * @param match substring of value to search for
     * @return elements that have attributes containing this text
     */
    public func getElementsByAttributeValueContaining(key: String, matchValue: String): Elements {
        return Collector.collect(EvaluatorAttributeWithValueContaining(key, matchValue), this)
    }

    /*
     * Find elements that have an attribute whose value matches the supplied regular expression.
     *
     * @param key name of the attribute
     * @param pattern compiled regular expression to match against attribute values
     * @return elements that have attributes matching this regular expression
     */
    public func getElementsByAttributeValueMatching(key: String, pattern: Regex): Elements {
        return Collector.collect(EvaluatorAttributeWithValueMatching(key, pattern), this)
    }

    /*
     * Find elements that have attributes whose values match the supplied regular expression.
     *
     * @param key name of the attribute
     * @param regex regular expression to match against attribute values.
     * @return elements that have attributes matching this regular expression
     */
    public func getElementsByAttributeValueMatching(key: String, regex: String): Elements {
        try {
            var pattern: Regex = Regex(regex)
            return getElementsByAttributeValueMatching(key, pattern)
        } catch (e: IllegalArgumentException) {
            throw IllegalArgumentException("Pattern syntax error: ${regex}")
        }
    }

    /*
     * Find elements whose sibling index is less than the supplied index.
     *
     * @param index 0-based index
     * @return elements less than index
     */
    public func getElementsByIndexLessThan(index: Int64): Elements {
        return Collector.collect(EvaluatorIndexLessThan(index), this)
    }

    /*
     * Find elements whose sibling index is greater than the supplied index.
     *
     * @param index 0-based index
     * @return elements greater than index
     */
    public func getElementsByIndexGreaterThan(index: Int64): Elements {
        return Collector.collect(EvaluatorIndexGreaterThan(index), this)
    }

    /*
     * Find elements whose sibling index is equal to the supplied index.
     *
     * @param index 0-based index
     * @return elements equal to index
     */
    public func getElementsByIndexEquals(index: Int64): Elements {
        return Collector.collect(EvaluatorIndexEquals(index), this)
    }

    /*
     * Find elements that contain the specified string. The search is case-insensitive. The text may appear directly
     * in the element, or in any of its descendants.
     *
     * @param searchText to look for in the element's text
     * @return elements that contain the string, case-insensitive.
     */
    public func getElementsContainingText(searchText: String): Elements {
        return Collector.collect(EvaluatorContainsText(searchText), this)
    }

    /*
     * Find elements that directly contain the specified string. The search is case-insensitive. The text must appear directly
     * in the element, not in any of its descendants.
     *
     * @param searchText to look for in the element's own text
     * @return elements that contain the string, case-insensitive.
     */
    public func getElementsContainingOwnText(searchText: String): Elements {
        return Collector.collect(EvaluatorContainsOwnText(searchText), this)
    }

    /*
     * Find elements whose text matches the supplied regular expression.
     *
     * @param pattern regular expression to match text against
     * @return elements matching the supplied regular expression.
     */
    public func getElementsMatchingText(pattern: Regex): Elements {
        return Collector.collect(EvaluatorMatches(pattern), this)
    }

    /*
     * Find elements whose text matches the supplied regular expression.
     *
     * @param regex regular expression to match text against.
     * @return elements matching the supplied regular expression.
     */
    public func getElementsMatchingText(regex: String): Elements {
        try {
            var pattern: Regex = Regex(regex)
            return getElementsMatchingText(pattern)
        } catch (e: IllegalArgumentException) {
            throw IllegalArgumentException("Pattern syntax error: ${regex}")
        }
    }

    /*
     * Find elements whose own text matches the supplied regular expression.
     *
     * @param pattern regular expression to match text against
     * @return elements matching the supplied regular expression.
     */
    public func getElementsMatchingOwnText(pattern: Regex): Elements {
        return Collector.collect(EvaluatorMatchesOwn(pattern), this)
    }

    /*
     * Find elements whose own text matches the supplied regular expression.
     *
     * @param regex regular expression to match text against.
     * @return elements matching the supplied regular expression.
     */
    public func getElementsMatchingOwnText(regex: String): Elements {
        try {
            var pattern: Regex = Regex(regex)
            return getElementsMatchingOwnText(pattern)
        } catch (e: IllegalArgumentException) {
            throw IllegalArgumentException("Pattern syntax error: ${regex}")
        }
    }

    /*
     * Find all elements under this element (including self, and children of children).
     *
     * @return all elements
     */
    public func getAllElements(): Elements {
        return Collector.collect(EvaluatorAllElements(), this)
    }

    /*
     * Gets the normalized, combined text of this element and all its children. Whitespace is normalized and trimmed.
     *
     * @return decoded, normalized text, or empty string if none.
     */
    public func text(): String {
        var accum: StringBuilder = StringUtil.borrowBuilder()
        NodeTraversor.traverse(TextNodeVisitor(accum), this)
        return StringUtil.releaseBuilder(accum).strip()
    }

    /*
     * Get the non-normalized, decoded text of this element and its children, including only any newlines and spaces present in the original source.
     *
     * @return decoded, non-normalized text
     */
    public func wholeText(): String {
        var accum: StringBuilder = StringUtil.borrowBuilder()
        NodeTraversor.traverse(WholeTextNodeVisitor(this, accum), this)
        return StringUtil.releaseBuilder(accum)
    }

    static func appendWholeText(node: Node, accum: StringBuilder): Unit {
        match (node) {
            case v: TextNode => accum.append(v.getWholeText())
            case v where v.isNodeNew("br") => accum.append("\n")
            case _ => ()
        }
    }

    /*
     * Get the non-normalized, decoded text of this element, not including any child elements, including only any newlines and spaces present in the original source.
     *
     * @return decoded, non-normalized text that is a direct child of this Element
     */
    public func wholeOwnText(): String {
        var accum: StringBuilder = StringUtil.borrowBuilder()
        var size: Int64 = childNodeSize()
        for (i in 0..size) {
            var node: Node = childNodesValue[i]
            appendWholeText(node, accum)
        }
        return StringUtil.releaseBuilder(accum)
    }

    /*
     * Gets the (normalized) text owned by this element only; does not get the combined text of all children.
     *
     * @return decoded text, or empty string if none.
     */
    public func ownText(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        ownText(sb)
        return StringUtil.releaseBuilder(sb).strip()
    }

    private func ownText(accum: StringBuilder): Unit {
        for (i in 0..childNodeSize()) {
            var child: Node = childNodesValue[i]
            if (child is TextNode) {
                var textNode: TextNode = (child as TextNode)()
                appendNormalisedText(accum, textNode)
            } else if (child.isNodeNew("br") && !TextNode.lastCharIsWhitespace(accum)) {
                accum.append(" ")
            }
        }
    }

    static func appendNormalisedText(accum: StringBuilder, textNode: TextNode): Unit {
        var text: String = textNode.getWholeText()
        if (preserveWhitespace(textNode.parentNodeAll) || textNode is CDataNode) {
            accum.append(text)
        } else {
            StringUtil.appendNormalisedWhitespace(accum, text, TextNode.lastCharIsWhitespace(accum))
        }
    }

    static func preserveWhitespace(node: ?Node): Bool {
        // looks only at this element and five levels up, to prevent recursion & needless stack searches
        match (node) {
            case Some(v: Element) =>
                var el: ?Element = v
                var i: Int64 = 0
                do {
                    if (el().tagValue.preserveWhitespace()) {
                        return true
                    }
                    el = match (el().parent()) {
                        case Some(v: Element) => v
                        case _ => None
                    }
                    i++
                } while (i < 6 && el != None)
                return false
            case _ => return false
        }
    }

    /*
     * Set the text of this element. Any existing contents (text or elements) will be cleared.
     *
     * @param text decoded text
     * @return this element
     */
    public open func text(text: String): Element {
        empty()

        // special case for script/style in HTML: should be data node
        var owner: ?Document = ownerDocument()

        // an alternate impl would be to run through the parser
        if (owner != None && owner().parser().isContentForTagData(normalName())) {
            appendChild(DataNode(text))
        } else {
            appendChild(TextNode(text))
        }
        return this
    }

    /*
     * Checks if the current element or any of its child elements contain non-whitespace text.
     *
     * @return true if the element has non-blank text content, false otherwise.
     */
    public func hasText(): Bool {
        var hasText: AtomicBool = AtomicBool(false)
        filter(HasTextNodeFilter(hasText))
        return hasText.load()
    }

    /*
     * Get the combined data of this element.
     *
     * @return the data, or empty string if none
     */
    public func data(): String {
        var sb: StringBuilder = StringUtil.borrowBuilder()
        traverse(DataNodeVisitor(sb))
        return StringUtil.releaseBuilder(sb)
    }

    /*
     * Gets the literal value of this element's "class" attribute, which may include multiple class names, space separated.
     *
     * @return The literal class attribute, or <b>empty string</b> if no class attribute set.
     */
    public func className(): String {
        return attr("class").strip()
    }

    /*
     * Get each of the element's class names.
     *
     * @return set of classnames, empty if no class attribute
     */
    public func classNames(): Set<String> {
        var names: Array<String> = classSplit.matcher(className()).split()
        var classNames: Set<String> = HashSet<String>(names)

        // if classNames() was empty, would include an empty class
        classNames.remove("")
        return classNames
    }

    /*
     * Set the element's class attribute to the supplied class names.
     *
     * @param classNames set of classes
     * @return this element, for chaining
     */
    public func classNames(classNames: Set<String>): Element {
        if (classNames.isEmpty()) {
            attributes().remove("class")
        } else {
            attributes().put("class", StringUtil.join(classNames, " "))
        }
        return this
    }

    /*
     * Tests if this element has a class. Case-insensitive.(performance sensitive)
     *
     * @param className name of class to check for
     * @return true if it does, false if not
     */
    public func hasClass(className: String): Bool {
        if (attributesValue == None) {
            return false
        }
        var classAttr: String = attributesValue().getIgnoreCase("class")
        var lenInt: Int64 = classAttr.size
        var wantLenInt: Int64 = className.size
        if (lenInt == 0 || lenInt < wantLenInt) {
            return false
        }

        // if both lengths are equal, only need compare the className with the attribute
        if (lenInt == wantLenInt) {
            return className.equalsIgnoreCase(classAttr)
        }

        // otherwise, scan for whitespace and compare regions (with no string or arraylist allocations)
        var inClassBool: Bool = false
        var start: Int64 = 0
        for (i in 0..lenInt) {
            if (StringUtil.isWhitespace(classAttr[i])) {
                if (inClassBool) {
                    // white space ends a class name, compare it with the requested one, ignore case
                    if (i - start == wantLenInt && classAttr[start..start + wantLenInt]
                        .toLower()
                        .equals(className[..wantLenInt].toLower())) {
                        return true
                    }
                    inClassBool = false
                }
            } else {
                if (!inClassBool) {
                    inClassBool = true
                    start = i
                }
            }
        }
        if (inClassBool && lenInt - start == wantLenInt) {
            return classAttr[start..start + wantLenInt].toLower().equals(className[..wantLenInt].toLower())
        }
        return false
    }

    /*
     * Add a class name to this element's class attribute.
     *
     * @param className class name to add
     * @return this element
     */
    public func addClass(className: String): Element {
        var classes: Set<String> = classNames()
        classes.add(className)
        classNames(classes)
        return this
    }

    /*
     * Remove a class name from this element's class attribute.
     *
     * @param className class name to remove
     * @return this element
     */
    public func removeClass(className: String): Element {
        var classes: Set<String> = classNames()
        classes.remove(className)
        classNames(classes)
        return this
    }

    /*
     * Toggle a class name on this element's class attribute: if present, remove it; otherwise add it.
     *
     * @param className class name to toggle
     * @return this element
     */
    public func toggleClass(className: String): Element {
        var classes: Set<String> = classNames()
        if (classes.contains(className)) {
            classes.remove(className)
        } else {
            classes.add(className)
        }
        classNames(classes)
        return this
    }

    /*
     * Get the value of a form element (input, textarea, etc).
     *
     * @return the value of the form element, or empty string if not set.
     */
    public func val(): String {
        if (normalName().equals("textarea")) {
            return text()
        } else {
            return attr("value")
        }
    }

    /*
     * Set the value of a form element (input, textarea, etc).
     *
     * @param value value to set
     * @return this element (for chaining)
     */
    public func val(value: String): Element {
        if (normalName().equals("textarea")) {
            text(value)
        } else {
            attr("value", value)
        }
        return this
    }

    /*
     * Get the source range (start and end positions) of the end (closing) tag for this Element. Position tracking must be enabled prior to parsing the content.
     *
     * @return the range of the closing tag for this element, if it was explicitly closed in the source.
     */
    public func endSourceRange(): SrcRange {
        return SrcRange.of(this, false)
    }

    func shouldIndent(out: DocumentOutputSettings): Bool {
        if (out.prettyPrint()) {
            if (isFormatAsBlock(out)) {
                if (!isInlineable(out)) {
                    return true
                }
            }
        }
        return false
    }

    protected open override func outerHtmlHead(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit {
        if (shouldIndent(out)) {
            if (accum.size > 0) {
                indent(accum, depth, out)
            }
        }
        accum.append(r'<')
        accum.append(tagName())
        if (attributesValue != None) {
            attributesValue().html(accum, out)
        }

        // selfclosing includes unknown tags, isEmpty defines tags that are always empty
        if (childNodesValue.isEmpty() && tagValue.isSelfClosing()) {
            if (out.syntax() == Syntax.htmlSyntax && tagValue.isEmpty()) {
                accum.append(r'>')
            } else {
                // <img> in html, <img /> in xml
                accum.append(" />")
            }
        } else {
            accum.append(r'>')
        }
    }

    protected open override func outerHtmlTail(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit {
        if (!(childNodesValue.isEmpty() && tagValue.isSelfClosing())) {
            if (out.prettyPrint() && (!childNodesValue.isEmpty() && (tagValue.formatAsBlock() || (out.outline() && (childNodesValue
                .size > 1 || (childNodesValue.size == 1 && (childNodesValue[0] is Element))))))) {
                indent(accum, depth, out)
            }
            accum.append("</")
            accum.append(tagName())
            accum.append(r'>')
        }
    }

    /*
     * Retrieves the element's inner HTML.
     *
     * @return String of HTML.
     */
    public func html(): String {
        var accum: StringBuilder = StringUtil.borrowBuilder()
        html(accum)
        var htmlValue: String = StringUtil.releaseBuilder(accum)
        if (NodeUtils.outputSettings(this).prettyPrint()) {
            return htmlValue.strip()
        } else {
            return htmlValue
        }
    }

    public override func html(appendable: StringBuilder): StringBuilder {
        let size: Int64 = childNodesValue.size
        for (i in 0..size) {
            childNodesValue[i].outerHtml(appendable)
        }
        return appendable
    }

    /*
     * Set this element's inner HTML. Clears the existing HTML first.
     *
     * @param html HTML to parse and set into this element
     * @return this element
     */
    public func html(html: String): Element {
        empty()
        append(html)
        return this
    }

    public open override func clone(): Element {
        return (super.clone() as Element)()
    }

    public open override func shallowClone(): Element {
        // simpler than implementing a clone version with no child copy
        match (attributesValue) {
            case None => return Element(tagValue, baseUri(), None)
            case Some(v) => return Element(tagValue, baseUri(), v.clone())
        }
    }

    protected override func doClone(parent: ?Node): Element {
        var clone: Element = (super.doClone(parent) as Element)()
        if (attributesValue != None) {
            clone.attributesValue = attributesValue().clone()
        } else {
            clone.attributesValue = None
        }
        clone.childNodesValue = ArrayList<Node>(childNodesValue.size)
        clone.childNodesValue.add(all: childNodesValue)
        return clone
    }

    public override func clearAttributes(): Element {
        if (attributesValue != None) {
            super.clearAttributes()
            attributesValue = None
        }
        return this
    }

    public override func removeAttr(attributeKey: String): Element {
        var element: Element = (super.removeAttr(attributeKey) as Element)()
        return element
    }

    public override func root(): Element {
        // probably a document, but always at least an element 
        var element: Element = (super.root() as Element)()
        return element
    }

    public override func traverse(nodeVisitor: NodeVisitor): Element {
        var element: Element = (super.traverse(nodeVisitor) as Element)()
        return element
    }

    public override func filter(nodeFilter: NodeFilter): Element {
        var element: Element = (super.filter(nodeFilter) as Element)()
        return element
    }

    private func isFormatAsBlock(out: DocumentOutputSettings): Bool {
        return tagValue.formatAsBlock() || (parent() != None && (parent()() as Element)().tag().formatAsBlock()) ||
            out.outline()
    }

    private func isInlineable(out: DocumentOutputSettings): Bool {
        if (tag().isInline()) {
            if (parent() == None || (parent()() as Element)().isBlock()) {
                if (previousSibling() != None) {
                    if (!out.outline()) {
                        return true
                    }
                }
            }
        }
        return false
    }

    public operator func !=(that: Element): Bool {
        return !(this == that)
    }

    public operator func ==(that: Element): Bool {
        return refEq(this, that)
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        var result: Int64 = super.hashCode()
        result = calcHash(result, tagValue.hashCode())
        result = calcHash(result, hashCodeNodeList(childNodesValue))
        match (attributesValue) {
            case Some(v) => result = calcHash(result, v.hashCode())
            case None => result = calcHash(result, 0)
        }
        return result
    }

    @OverflowWrapping
    private func hashCodeNodeList(code: ArrayList<Node>): Int64 {
        var result: Int64 = 1
        for (node in code) {
            result = calcHash(result, node.hashCode())
        }
        return result
    }
}

class WholeTextNodeVisitor <: NodeVisitor {
    var el: Element
    var accum: StringBuilder

    init(el: Element, accum: StringBuilder) {
        this.el = el
        this.accum = accum
    }

    public override func head(node: Node, _: Int64): Unit {
        Element.appendWholeText(node, accum)
    }
}

class HasTextNodeFilter <: NodeFilter {
    var hasText: AtomicBool = AtomicBool(false)

    init(hasText: AtomicBool) {
        this.hasText = hasText
    }

    public override func head(node: Node, _: Int64): FilterResult {
        if (node is TextNode) {
            var textNode: TextNode = (node as TextNode)()
            if (!textNode.isBlank()) {
                hasText.store(true)
                return FilterResult.STOP
            }
        }
        return FilterResult.CONTINUE
    }
}

class DataNodeVisitor <: NodeVisitor {
    var sb: StringBuilder

    init(sb: StringBuilder) {
        this.sb = sb
    }

    public override func head(childNode: Node, _: Int64): Unit {
        if (childNode is DataNode) {
            var data: DataNode = (childNode as DataNode)()
            sb.append(data.getWholeData())
        } else if (childNode is Comment) {
            var comment: Comment = (childNode as Comment)()
            sb.append(comment.getData())
        } else if (childNode is CDataNode) {
            // this shouldn't really happen because the html parser won't see the cdata as anything special when parsing script.
            // but in case another type gets through.
            var cDataNode: CDataNode = (childNode as CDataNode)()
            sb.append(cDataNode.getWholeText())
        }
    }
}

class TextNodeVisitor <: NodeVisitor {
    var accum: StringBuilder = StringBuilder()

    init(accum: StringBuilder) {
        this.accum = accum
    }

    public override func head(node: Node, _: Int64): Unit {
        if (node is TextNode) {
            var textNode: TextNode = (node as TextNode)()
            Element.appendNormalisedText(accum, textNode)
        } else if (node is Element) {
            var element: Element = (node as Element)()
            if (accum.size > 0 && (element.isBlock() || element.isNodeNew("br")) &&
                !TextNode.lastCharIsWhitespace(accum)) {
                accum.append(r' ')
            }
        }
    }

    public override func tail(node: Node, _: Int64): Unit {
        // make sure there is a space between block tags and 
        // immediately following text nodes or inline elements <div>One</div>Two should be "One Two".
        if (node is Element) {
            var element: Element = (node as Element)()
            var next: ?Node = node.nextSibling()
            if (next == None) {
                return
            }
            var isBlock = element.isBlock()
            var isTextNode = next() is TextNode
            var isElement = next() is Element
            var isFormatAsBlock = false
            if (isElement) {
                isFormatAsBlock = (next() as Element)().tagValue.formatAsBlock()
            }
            var isLastCharIsWhitespace = !TextNode.lastCharIsWhitespace(accum)

            if (isBlock && (isTextNode || isElement && !isFormatAsBlock) && isLastCharIsWhitespace) {
                accum.append(r' ')
            }
        }
    }
}
