/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Collects a list of elements that match the supplied criteria.
 */
class Collector {
    private init() {}

    /*
     * Build a list of elements, by visiting root and every descendant of root, and testing it against the evaluator.
     *
     * @param eval Evaluator to test elements against
     * @param root root of tree to descend
     * @return list of matches; empty if none
     */
    static func collect(eval: Evaluator, root: Element): Elements {
        var elements: Elements = Elements()
        NodeTraversor.traverse(CollectorNodeVisitor(eval, root, elements), root)
        return elements
    }

    /*
     * Finds the first Element that matches the Evaluator that descends from the root, and stops the query once that first
     * match is found.
     *
     * @param eval Evaluator to test elements against
     * @param root root of tree to descend
     * @return the first match; null if none
     */
    static func findFirst(eval: Evaluator, root: Element): ?Element {
        var finder: FirstFinder = FirstFinder(eval)
        return finder.find(root, root)
    }
}

class CollectorNodeVisitor <: NodeVisitor {
    var eval: Evaluator
    var root: Element
    var elements: Elements

    init(eval: Evaluator, root: Element, elements: Elements) {
        this.eval = eval
        this.root = root
        this.elements = elements
    }

    public override func head(node: Node, _: Int64): Unit {
        match (node) {
            case v: Element =>
                if (eval.matches(root, v)) {
                    elements.elementArr.add(v)
                }
            case _ => ()
        }
    }
}

class FirstFinder <: NodeFilter {
    private var evalRoot: ?Element = None
    private var matchElement: ?Element = None
    private var eval: Evaluator

    init(eval: Evaluator) {
        this.eval = eval
    }

    func find(root: Element, start: Element): ?Element {
        evalRoot = root
        matchElement = None
        NodeTraversor.filter(this, start)
        return matchElement
    }

    public override func head(node: Node, _: Int64): FilterResult {
        if (node is Element) {
            var el: Element = (node as Element)()
            if (eval.matches(evalRoot, el)) {
                matchElement = el
                return FilterResult.STOP
            }
        }
        return FilterResult.CONTINUE
    }

    public override func tail(_: Node, _: Int64): FilterResult {
        return FilterResult.CONTINUE
    }
}
