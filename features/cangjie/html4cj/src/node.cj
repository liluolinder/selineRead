/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * The base, abstract Node model. Elements, Documents, Comments etc are all Node instances.
 */
public abstract class Node <: Hashable & Equatable<Node> & ToString {
    static let EmptyNodes: ArrayList<Node> = ArrayList<Node>()

    static let EmptyString: String = ""

    // Nodes don't always have parents
    var parentNodeAll: ?Node = Option<Node>.None

    var siblingIndexInt: Int64 = 0

    /*
     * Default constructor. Doesn't set up base uri, children, or attributes; use with caution.
     */
    protected init() {}

    /*
     * Get the node name of this node.
     *
     * @return node name
     */
    public func nodeName(): String

    /*
     * Get the node name of this node.
     *
     * @return node name
     */
    public open func normalName(): String {
        return nodeName()
    }

    /*
     * Check if this Node has an actual Attributes object.
     *
     * @return Whether there are attributes
     */
    protected func hasAttributes(): Bool

    /*
     * Checks if this node has a parent.
     *
     * @return normalized node name
     */
    public func hasParent(): Bool {
        return parentNodeAll != None
    }

    /*
     * Get an attribute's value by its key.
     *
     * @param attributeKey The attribute key.
     * @return The attribute, or empty string if not present (to avoid nulls).
     */
    public open func attr(attributeKey: String): String {
        if (!hasAttributes()) {
            return EmptyString
        }
        var valStr: String = attributes().getIgnoreCase(attributeKey)
        if (valStr.size > 0) {
            return valStr
        } else if (attributeKey.startsWith("abs:")) {
            return absUrl(attributeKey["abs:".size..])
        } else {
            return ""
        }
    }

    /*
     * Get each of the element's attributes.
     *
     * @return attributes (which implements iterable, in same order as presented in original HTML).
     */
    public func attributes(): Attributes

    /*
     * Get the number of attributes that this Node has.
     *
     * @return the number of attributes
     */
    public func attributesSize(): Int64 {
        // added so that we can test how many attributes exist without implicitly creating the Attributes object
        if (hasAttributes()) {
            return attributes().size
        } else {
            return 0
        }
    }

    /*
     * Set an attribute (key=value). If the attribute already exists, it is replaced. The attribute key comparison is.
     * The key will be set with case sensitivity as set in the parser settings.
     *
     * @param attributeKey The attribute key.
     * @param attributeValue The attribute value.
     * @return this (for chaining)
     */
    public open func attr(attributeKey: String, attributeValue: String): Node {
        var attributeKeyNew: String = NodeUtils.parser(this).settings().normalizeAttribute(attributeKey)
        attributes().putIgnoreCase(attributeKeyNew, attributeValue)
        return this
    }

    /*
     * Test if this Node has an attribute.
     *
     * @param attributeKey The attribute key to check.
     * @return true if the attribute exists, false if not.
     */
    public open func hasAttr(attributeKey: String): Bool {
        if (!hasAttributes()) {
            return false
        }
        if (attributeKey.startsWith("abs:")) {
            var key: String = attributeKey["abs:".size..]
            if (attributes().hasKeyIgnoreCase(key)) {
                if (!absUrl(key).isEmpty()) {
                    return true
                }
            }
        }
        return attributes().hasKeyIgnoreCase(attributeKey)
    }

    /*
     * Remove an attribute from this node.
     *
     * @param attributeKey The attribute to remove.
     * @return this (for chaining)
     */
    public open func removeAttr(attributeKey: String): Node {
        if (hasAttributes()) {
            attributes().removeIgnoreCase(attributeKey)
        }
        return this
    }

    /*
     * Clear (remove) each of the attributes in this node.
     *
     * @return this, for chaining
     */
    public open func clearAttributes(): Node {
        if (hasAttributes()) {
            attributes().clear()
        }
        return this
    }

    /*
     * Get the base URI that applies to this node. Will return an empty string if not defined. Used to make relative links absolute.
     *
     * @return base URI
     */
    public func baseUri(): String

    /*
     * Set the baseUri for just this node (not its descendants), if this Node tracks base URIs.
     *
     * @param baseUri new URI
     */
    protected func doSetBaseUri(baseUri: String): Unit

    /*
     * Update the base URI of this node and all of its descendants.
     *
     * @param baseUri base URI to set
     */
    public open func setBaseUri(baseUri: String): Unit {
        doSetBaseUri(baseUri)
    }

    /*
     * Get an absolute URL from a URL attribute that may be relative
     *
     * @param attributeKey The attribute key
     * @return An absolute URL if one could be made, or an empty string (not null) if the attribute was missing or could not be made successfully into a URL.
     */
    public open func absUrl(attributeKey: String): String {
        Validate.notEmpty(attributeKey)

        // not using hasAttr, so that we don't recurse down hasAttr->absUrl
        if (!hasAttributes()) {
            return ""
        } else if (!attributes().hasKeyIgnoreCase(attributeKey)) {
            return ""
        }
        return StringUtil.resolve(baseUri(), attributes().getIgnoreCase(attributeKey))
    }

    protected func ensureChildNodes(): ArrayList<Node>

    /*
     * Get a child node by its 0-based index.
     *
     * @param index index of child node
     * @return the child node at this index. Throws a IndexOutOfBoundsException if the index is out of bounds.
     */
    public func childNode(index: Int64): Node {
        return ensureChildNodes()[index]
    }

    /*
     * Get this node's children. Presented as an unmodifiable list: new children can not be added, but the child nodes themselves can be manipulated.
     *
     * @return list of children. If no children, returns an empty list.
     */
    public func childNodes(): ArrayList<Node> {
        if (childNodeSize() == 0) {
            return EmptyNodes
        }
        var children: ArrayList<Node> = ensureChildNodes()

        // wrapped so that looping and moving will not throw a CME as the source changes
        var rewrap: ArrayList<Node> = ArrayList<Node>(children.size)
        rewrap.add(all: children)
        return rewrap
    }

    /*
     * Returns a deep copy of this node's children. Changes made to these nodes will not be reflected in the original nodes
     *
     * @return a deep copy of this node's children
     */
    public func childNodesCopy(): ArrayList<Node> {
        var nodes: ArrayList<Node> = ensureChildNodes()
        var children: ArrayList<Node> = ArrayList<Node>(nodes.size)
        for (node in nodes) {
            children.add(node.clone())
        }
        return children
    }

    /*
     * Get the number of child nodes that this node holds.
     *
     * @return the number of child nodes that this node holds.
     */
    public func childNodeSize(): Int64

    protected func childNodesAsArray(): Array<Node> {
        return ensureChildNodes().toArray()
    }

    /*
     * Delete all this node's children.
     *
     * @return this node, for chaining
     */
    public func empty(): Node

    /*
     * Gets this node's parent node.
     *
     * @return parent node; or null if no parent.
     */
    public open func parent(): ?Node {
        return parentNodeAll
    }

    /*
     * Gets this node's parent node. Not overridable by extending classes, so useful if you really just need the Node type.
     *
     * @return parent node; or null if no parent.
     */
    public func parentNode(): ?Node {
        return parentNodeAll
    }

    /*
     * Get this node's root node; that is, its topmost ancestor. If this node is the top ancestor, returns this.
     *
     * @return topmost ancestor.
     */
    public open func root(): Node {
        var node: Node = this
        while (node.parentNodeAll != None) {
            node = node.parentNodeAll()
        }
        return node
    }

    /*
     * Gets the Document associated with this Node.
     *
     * @return the Document associated with this Node, or null if there is no such Document.
     */
    public func ownerDocument(): ?Document {
        var root: Node = root()
        match (root) {
            case v: Document => return v
            case _ => None
        }
    }

    /*
     * Remove (delete) this node from the DOM tree. If this node has children, they are also removed.
     */
    public func remove(): Unit {
        Validate.notNull(parentNodeAll)
        parentNodeAll().removeChild(this)
    }

    /*
     * Insert the specified HTML into the DOM before this node (as a preceding sibling).
     *
     * @param html HTML to add before this node
     * @return this node, for chaining
     */
    public open func before(html: String): Node {
        addSiblingHtml(siblingIndexInt, html)
        return this
    }

    /*
     * Insert the specified node into the DOM before this node (as a preceding sibling).
     *
     * @param node to add before this node
     * @return this node, for chaining
     * @see #after(Node)
     */
    public open func before(node: Node): Node {
        Validate.notNull(parentNodeAll)
        parentNodeAll().addChildren(siblingIndexInt, node)
        return this
    }

    /*
     * Insert the specified HTML into the DOM after this node (as a following sibling).
     *
     * @param html HTML to add after this node
     * @return this node, for chaining
     */
    public open func after(html: String): Node {
        addSiblingHtml(siblingIndexInt + 1, html)
        return this
    }

    /*
     * Insert the specified node into the DOM after this node (as a following sibling).
     *
     * @param node to add after this node
     * @return this node, for chaining
     */
    public open func after(node: Node): Node {
        Validate.notNull(parentNodeAll)
        parentNodeAll().addChildren(siblingIndexInt + 1, node)
        return this
    }

    private func addSiblingHtml(index: Int64, html: String): Unit {
        Validate.notNull(parentNodeAll)
        var context: ?Element = match (parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        var nodes: ArrayList<Node> = NodeUtils.parser(this).parseFragmentInput(html, context, baseUri())
        parentNodeAll().addChildren(index, nodes.toArray())
    }

    /*
     * Wrap the supplied HTML around this node.
     *
     * @param html HTML to wrap around this node. Can be arbitrarily deep. If the input HTML does not parse to a result starting with an Element, this will be a no-op.
     * @return this node, for chaining.
     */
    public open func wrap(html: String): Node {
        Validate.notEmpty(html)
        var context: ?Element = match (parentNodeAll) {
            case Some(v: Element) => v
            case _ =>
                if (this is Element) {
                    (this as Element)()
                } else {
                    None
                }
        }
        var wrapChildren: ArrayList<Node> = NodeUtils.parser(this).parseFragmentInput(html, context, baseUri())
        var wrapNode: Node = wrapChildren[0]
        if (!(wrapNode is Element)) {
            // nothing to wrap with; noop
            return this
        }
        var wrap: Element = (wrapNode as Element)()
        var deepest: Element = getDeepChild(wrap)
        if (parentNodeAll != None) {
            parentNodeAll().replaceChild(this, wrap)
        }

        // side effect of tricking wrapChildren to lose first
        deepest.addChildren(this)

        // remainder (unbalanced wrap, like <div></div><p></p> -- The <p> is remainder
        if (wrapChildren.size > 0) {
            //noinspection ForLoopReplaceableByForEach (beacause it allocates an Iterator which is wasteful here)
            for (i in 0..wrapChildren.size) {
                var remainder: Node = wrapChildren[i]

                // if no parent, this could be the wrap node, so skip
                if (wrap == remainder) {
                    continue
                }
                if (remainder.parentNodeAll != None) {
                    remainder.parentNodeAll().removeChild(remainder)
                }
                wrap.after(remainder)
            }
        }
        return this
    }

    /*
     * Removes this node from the DOM, and moves its children up into the node's parent. This has the effect of dropping the node but keeping its children.
     *
     * @return the first child of this node, after the node has been unwrapped. @{code Null} if the node had no children.
     */
    public func unwrap(): ?Node {
        Validate.notNull(parentNodeAll)
        var firstChild: ?Node = firstChild()
        parentNodeAll().addChildren(siblingIndexInt, this.childNodesAsArray())
        this.remove()
        return firstChild
    }

    private func getDeepChild(el: Element): Element {
        var elNew = el
        while (elNew.childrenSize() > 0) {
            elNew = elNew.childElementsList()[0]
        }
        return elNew
    }

    /*
     * Replace this node in the DOM with the supplied node.
     *
     * @param in the node that will replace the existing node.
     */
    public func replaceWith(nodeIn: Node): Unit {
        Validate.notNull(parentNodeAll)
        parentNodeAll().replaceChild(this, nodeIn)
    }

    protected func setParentNode(parentNode: Node): Unit {
        if (this.parentNodeAll != None) {
            this.parentNodeAll().removeChild(this)
        }
        this.parentNodeAll = parentNode
    }

    protected func replaceChild(out: Node, nodeIn: Node): Unit {
        Validate.isTrue(out.parentNodeAll == this)
        if (out == nodeIn) {
            // no-op self replacement
            return
        }
        if (nodeIn.parentNodeAll != None) {
            nodeIn.parentNodeAll().removeChild(nodeIn)
        }
        let index: Int64 = out.siblingIndexInt
        ensureChildNodes()[index] = nodeIn
        nodeIn.parentNodeAll = this
        nodeIn.setSiblingIndex(index)
        out.parentNodeAll = None
    }

    protected open func removeChild(out: Node): Unit {
        Validate.isTrue(out.parentNodeAll == this)
        let index = out.siblingIndexInt
        ensureChildNodes().remove(at: index)
        reindexChildren(index)
        out.parentNodeAll = None
    }

    protected open func addChildren(children: Array<Node>): Unit {
        //most used. short circuit addChildren(int), which hits reindex children and array copy
        var nodes: ArrayList<Node> = ensureChildNodes()
        for (child in children) {
            reparentChild(child)
            nodes.add(child)
            child.setSiblingIndex(nodes.size - 1)
        }
    }

    protected open func addChildren(index: Int64, children: Array<Node>): Unit {
        if (children.size == 0) {
            return
        }
        let nodes: ArrayList<Node> = ensureChildNodes()

        // fast path - if used as a wrap (index=0, children = child[0].parent.children - do inplace
        let firstParent: ?Node = children[0].parent()
        if (firstParent != None && firstParent().childNodeSize() == children.size) {
            var sameList: Bool = true
            let firstParentNodes: ArrayList<Node> = firstParent().ensureChildNodes()
            var i: Int64 = children.size

            for (i in i - 1..=0 : -1) {
                if (children[i] != firstParentNodes[i]) {
                    sameList = false
                    break
                }
            }
            if (sameList) {
                // moving, so OK to empty firstParent and short-circuit
                var wasEmpty: Bool = childNodeSize() == 0
                firstParent().empty()
                nodes.add(all: children, at: index)
                i = children.size

                for (i in i - 1..=0 : -1) {
                    children[i].parentNodeAll = this
                }

                if (!(wasEmpty && children[0].siblingIndexInt == 0)) {
                    // skip reindexing if we just moved
                    reindexChildren(index)
                }
                return
            }
        }
        for (child in children) {
            reparentChild(child)
        }
        nodes.add(all: children, at: index)
        reindexChildren(index)
    }

    protected func reparentChild(child: Node): Unit {
        child.setParentNode(this)
    }

    private func reindexChildren(start: Int64): Unit {
        let size: Int64 = childNodeSize()
        if (size == 0) {
            return
        }
        let childNodes: ArrayList<Node> = ensureChildNodes()
        for (i in start..size) {
            childNodes[i].setSiblingIndex(i)
        }
    }

    /*
     * Retrieves this node's sibling nodes.
     *
     * @return node siblings. If the node has no parent, returns an empty list.
     */
    public func siblingNodes(): ArrayList<Node> {
        if (parentNodeAll == None) {
            return ArrayList<Node>()
        }
        var nodes: ArrayList<Node> = parentNodeAll().ensureChildNodes()
        var siblings: ArrayList<Node> = ArrayList<Node>(nodes.size - 1)
        for (node in nodes) {
            if (node != this) {
                siblings.add(node)
            }
        }
        return siblings
    }

    /*
     * Get this node's next sibling.
     *
     * @return next sibling, or null if this is the last sibling
     */
    public func nextSibling(): ?Node {
        if (parentNodeAll == None) {
            // root
            return None
        }
        let siblings: ArrayList<Node> = parentNodeAll().ensureChildNodes()
        let index: Int64 = siblingIndexInt + 1
        if (siblings.size > index) {
            return siblings[index]
        } else {
            return None
        }
    }

    /*
     * Get this node's previous sibling.
     *
     * @return the previous sibling, or  null if this is the first sibling
     */
    public func previousSibling(): ?Node {
        if (parentNodeAll == None) {
            // root
            return None
        }
        if (siblingIndexInt > 0) {
            return parentNodeAll().ensureChildNodes()[siblingIndexInt - 1]
        } else {
            return None
        }
    }

    /*
     * Get the list index of this node in its node sibling list. E.g. if this is the first node sibling, returns 0.
     *
     * @return position in node sibling list
     */
    public func siblingIndex(): Int64 {
        return siblingIndexInt
    }

    protected func setSiblingIndex(siblingIndex: Int64): Unit {
        this.siblingIndexInt = siblingIndex
    }

    /*
     * Gets the first child node of this node, or null if there is none. This could be any Node type, such as an
     * Element, TextNode, Comment, etc. Use Element.firstElementChild() to get the first Element child.
     *
     * @return the first child node, or null if there are no children.
     */
    public func firstChild(): ?Node {
        if (childNodeSize() == 0) {
            return None
        }
        return ensureChildNodes()[0]
    }

    /*
     * Gets the last child node of this node, or null if there is none.
     *
     * @return the last child node, or null if there are no children.
     */
    public func lastChild(): ?Node {
        let size: Int64 = childNodeSize()
        if (size == 0) {
            return None
        }
        var children: ArrayList<Node> = ensureChildNodes()
        return children[size - 1]
    }

    /*
     * Perform a depth-first traversal through this node and its descendants.
     *
     * @param nodeVisitor the visitor callbacks to perform on each node
     * @return this node, for chaining
     */
    public open func traverse(nodeVisitor: NodeVisitor): Node {
        NodeTraversor.traverse(nodeVisitor, this)
        return this
    }

    /*
     * Perform a depth-first filtering through this node and its descendants.
     *
     * @param nodeFilter the filter callbacks to perform on each node
     * @return this node, for chaining
     */
    public open func filter(nodeFilter: NodeFilter): Node {
        NodeTraversor.filter(nodeFilter, this)
        return this
    }

    /*
     * Get the outer HTML of this node. For example, on a element, may return Para.
     *
     * @return outer HTML
     */
    public open func outerHtml(): String {
        var accum: StringBuilder = StringUtil.borrowBuilder()
        outerHtml(accum)
        return StringUtil.releaseBuilder(accum)
    }

    protected func outerHtml(accum: StringBuilder): Unit {
        NodeTraversor.traverse(OuterHtmlVisitor(accum, NodeUtils.outputSettings(this)), this)
    }

    /*
     * Get the outer HTML of this node.
     *
     * @param accum accumulator to place HTML into
     */
    protected func outerHtmlHead(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit

    protected func outerHtmlTail(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit

    /*
     * Write this node and its children to the given Appendable.
     *
     * @param appendable the Appendable to write to.
     * @return the supplied  Appendable, for chaining.
     */
    public open func html(appendable: StringBuilder): StringBuilder {
        outerHtml(appendable)
        return appendable
    }

    /*
     * Get the source range (start and end positions) in the original input source that this node was parsed from. Position
     * tracking must be enabled prior to parsing the content. For an Element, this will be the positions of the start tag.
     *
     * @return the range for the start of the node.
     */
    public func sourceRange(): SrcRange {
        return SrcRange.of(this, true)
    }

    /*
     * Test if this node is not null and has the supplied normal name.
     */
    static func isNode(node: ?Node, normalName: String): Bool {
        return node != None && node().normalName().equals(normalName)
    }

    /*
     * Test if this node has the supplied normal name.
     */
    func isNodeNew(normalNameStr: String): Bool {
        return normalName().equals(normalNameStr)
    }

    /*
     * Gets this node's outer HTML.
     *
     * @return outer HTML.
     */
    public open func toString(): String {
        return outerHtml()
    }

    protected func indent(accum: StringBuilder, depth: Int64, out: DocumentOutputSettings): Unit {
        accum.append(r'\n')
        accum.append(StringUtil.padding(depth * out.indentAmount(), out.maxPaddingWidth()))
    }

    /*
     * Provides a hashCode for this Node, based on its object identity. Changes to the Node's content will not impact the result.
     *
     * @return an object identity based hashcode for this Node
     */
    @OverflowWrapping
    public open func hashCode(): Int64 {
        var hashcode: Int64 = 1
        var thisNode: ?Node = this
        while (thisNode().parentNodeAll != Option<Node>.None) {
            hashcode = calcHash(hashcode, thisNode().siblingIndexInt)
            thisNode = thisNode().parentNodeAll
        }
        return hashcode
    }

    /*
     * Check if this node has the same content as another node. A node is considered the same if its name, attributes and content match the
     * other node; particularly its position in the tree does not influence its similarity.
     *
     * @param o other object to compare to
     * @return true if the content of this node is the same as the other
     */
    public func hasSameValue(o: ?Object): Bool {
        match (o) {
            case Some(v: Node) =>
                if (refEq(this, v)) {
                    return true
                }
                return this.outerHtml().equals(v.outerHtml())
            case _ => return false
        }
    }

    /*
     * Create a stand-alone, deep copy of this node, and all of its children. The cloned node will have no siblings or
     * parent node. As a stand-alone object, any changes made to the clone or any of its children will not impact
     * the original node.
     *
     * @return a stand-alone cloned node, including clones of any children
     */
    public open func clone(): Node {
        // splits for orphan
        var thisClone: Node = doClone(None)

        // Queue up nodes that need their children cloned (BFS).
        var nodesToProcess: LinkedList<Node> = LinkedList<Node>()
        nodesToProcess.append(thisClone)
        while (!nodesToProcess.isEmpty()) {
            var currParent: Node = nodesToProcess.get(0)
            nodesToProcess.remove(0)
            let size: Int64 = currParent.childNodeSize()
            for (i in 0..size) {
                let childNodes: ArrayList<Node> = currParent.ensureChildNodes()
                var childClone: Node = childNodes[i].doClone(currParent)
                childNodes[i] = childClone
                nodesToProcess.append(childClone)
            }
        }
        return thisClone
    }

    /*
     * Create a stand-alone, shallow copy of this node. None of its children (if any) will be cloned, and it will have no parent or sibling nodes.
     *
     * @return a single independent copy of this node
     */
    public open func shallowClone(): Node {
        return doClone(None)
    }

    private func leafToNode(leafNode: LeafNode, clone: LeafNode): Node {
        match (leafNode.value) {
            case str: String => clone.value = str
            case attr: Attributes => clone.value = attr.clone()
            case _ => ()
        }
        return clone
    }

    /*
     * Return a clone of the node using the given parent (which can be null).Not a deep copy of children.
     *
     * @return Node
     */
    protected open func doClone(parent: ?Node): Node {
        let clone: Node = match (this) {
            case v: CDataNode => leafToNode(v, CDataNode(""))
            case v: TextNode => leafToNode(v, TextNode(""))
            case v: XmlDeclaration => leafToNode(v, XmlDeclaration("", v.isProcessingInstruction))
            case v: DocumentType => leafToNode(v, DocumentType("", v.publicIdValue, v.systemIdValue))
            case v: DataNode => leafToNode(v, DataNode(""))
            case v: Comment => leafToNode(v, Comment(""))
            case v: PseudoTextElement => PseudoTextElement(v.tagValue, baseUri(), v.attributesValue().clone())
            case v: FormElement => match (v.attributesValue) {
                case None => FormElement(v.tagValue, baseUri(), None)
                case Some(s) => FormElement(v.tagValue, baseUri(), s.clone())
            }
            case v: Document => Document(v.baseUri())
            case v: Element => match (v.attributesValue) {
                case None => Element(v.tagValue, baseUri(), None)
                case Some(s) => Element(v.tagValue, baseUri(), s.clone())
            }
            case _ => this
        }

        // can be null, to create an orphan split
        clone.parentNodeAll = parent
        if (parent == None) {
            clone.siblingIndexInt = 0
        } else {
            clone.siblingIndexInt = siblingIndexInt
        }

        // if not keeping the parent, shallowClone the ownerDocument to preserve its settings
        if (parent == None && !(this is Document)) {
            var doc: ?Document = ownerDocument()
            if (doc != None) {
                var docClone: Document = doc().shallowClone()
                clone.parentNodeAll = docClone
                docClone.ensureChildNodes().add(clone)
            }
        }
        return clone
    }

    public operator func !=(that: Node): Bool {
        return !(this == that)
    }

    public operator func ==(that: Node): Bool {
        return refEq(this, that)
    }
}

class OuterHtmlVisitor <: NodeVisitor {
    private let accum: StringBuilder

    private let out: DocumentOutputSettings

    init(accum: StringBuilder, out: DocumentOutputSettings) {
        this.accum = accum
        this.out = out
    }

    public func head(node: Node, depth: Int64): Unit {
        try {
            node.outerHtmlHead(accum, depth, out)
        } catch (exception: IOException) {
            throw SerializationException(exception)
        }
    }

    public func tail(node: Node, depth: Int64): Unit {
        if (!node.nodeName().equals("#text")) {
            // saves a void hit.
            try {
                node.outerHtmlTail(accum, depth, out)
            } catch (exception: IOException) {
                throw SerializationException(exception)
            }
        }
    }
}
