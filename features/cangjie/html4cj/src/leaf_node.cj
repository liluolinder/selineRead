/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

public abstract class LeafNode <: Node {
    // either a string value, or an attribute map (in the rare case multiple attributes are set)
    var value: Any

    init(value: Any) {
        this.value = value
    }

    protected func hasAttributes(): Bool {
        return value is Attributes
    }

    public override func attributes(): Attributes {
        ensureAttributes()
        return (value as Attributes)()
    }

    private func ensureAttributes(): Unit {
        if (!hasAttributes()) {
            var coreValue: Any = value
            var attributes: Attributes = Attributes()
            value = attributes
            attributes.put(nodeName(), (coreValue as String))
        }
    }

    func coreValue(): String {
        return attr(nodeName())
    }

    func coreValue(value: String): Unit {
        attr(nodeName(), value)
    }

    public override func attr(key: String): String {
        if (!hasAttributes()) {
            if (nodeName().equals(key)) {
                return (value as String)()
            } else {
                return EmptyString
            }
        }
        return super.attr(key)
    }

    public override func attr(key: String, value: String): Node {
        if (!hasAttributes() && key.equals(nodeName())) {
            this.value = (value as Any)()
        } else {
            ensureAttributes()
            super.attr(key, value)
        }
        return this
    }

    public override func hasAttr(key: String): Bool {
        ensureAttributes()
        return super.hasAttr(key)
    }

    public override func removeAttr(key: String): Node {
        ensureAttributes()
        return super.removeAttr(key)
    }

    public override func absUrl(key: String): String {
        ensureAttributes()
        return super.absUrl(key)
    }

    public override func baseUri(): String {
        if (hasParent()) {
            return parent()().baseUri()
        } else {
            return ""
        }
    }

    protected override func doSetBaseUri(_: String): Unit {
        // noop
    }

    public override func childNodeSize(): Int64 {
        return 0
    }

    public override func empty(): Node {
        return this
    }

    protected override func ensureChildNodes(): ArrayList<Node> {
        return EmptyNodes
    }

    protected override func doClone(parent: ?Node): LeafNode {
        var clone: LeafNode = (super.doClone(parent) as LeafNode)()

        // Object value could be plain string or attributes - need to clone
        if (hasAttributes()) {
            clone.value = ((value as Attributes)()).clone()
        }
        return clone
    }
}
