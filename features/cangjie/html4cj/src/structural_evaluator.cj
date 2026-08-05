/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

abstract class StructuralEvaluator <: Evaluator {
    var evaluator: Evaluator

    init(evaluator: Evaluator) {
        this.evaluator = evaluator
    }
}

class StructuralEvaluatorRoot <: Evaluator {
    public override func matches(root: ?Element, element: Element): Bool {
        return root == element
    }

    public func toString(): String {
        return "root"
    }
}

class StructuralEvaluatorHas <: StructuralEvaluator {
    var finder: FirstFinder

    init(evaluator: Evaluator) {
        super(evaluator)
        this.evaluator = evaluator
        finder = FirstFinder(evaluator)
    }

    public override func matches(_: ?Element, element: Element): Bool {
        // for :has, we only want to match children (or below), not the input element. And we want to minimize GCs
        for (i in 0..element.childNodeSize()) {
            var node: Node = element.childNode(i)
            if (node is Element) {
                var el: ?Element = finder.find(element, (node as Element)())
                if (el != None) {
                    return true
                }
            }
        }
        return false
    }

    public func toString(): String {
        return ":has(${evaluator})"
    }
}

class StructuralEvaluatorNot <: StructuralEvaluator {
    init(evaluator: Evaluator) {
        super(evaluator)
        this.evaluator = evaluator
    }

    public override func matches(root: ?Element, element: Element): Bool {
        return !evaluator.matches(root, element)
    }

    public func toString(): String {
        return ":not(${evaluator})"
    }
}

class StructuralEvaluatorParent <: StructuralEvaluator {
    init(evaluator: Evaluator) {
        super(evaluator)
        this.evaluator = evaluator
    }

    public override func matches(root: ?Element, element: Element): Bool {
        if (root == element) {
            return false
        }
        var parent: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        while (parent != None) {
            if (evaluator.matches(root, parent())) {
                return true
            }
            if (parent == root) {
                break
            }
            parent = match (parent().parent()) {
                case Some(v: Element) => v
                case _ => None
            }
        }
        return false
    }

    public func toString(): String {
        return "${evaluator} "
    }
}

class StructuralEvaluatorImmediateParent <: StructuralEvaluator {
    init(evaluator: Evaluator) {
        super(evaluator)
        this.evaluator = evaluator
    }

    public override func matches(root: ?Element, element: Element): Bool {
        if (root == element) {
            return false
        }
        var parent: ?Element = match (element.parent()) {
            case Some(v: Element) => v
            case _ => None
        }
        return parent != None && evaluator.matches(root, parent())
    }

    public func toString(): String {
        return "${evaluator} > "
    }
}

class StructuralEvaluatorPreviousSibling <: StructuralEvaluator {
    init(evaluator: Evaluator) {
        super(evaluator)
        this.evaluator = evaluator
    }

    public override func matches(root: ?Element, element: Element): Bool {
        if (root == element) {
            return false
        }
        var prev: ?Element = element.previousElementSibling()
        while (prev != None) {
            if (evaluator.matches(root, prev())) {
                return true
            }
            prev = prev().previousElementSibling()
        }
        return false
    }

    public func toString(): String {
        return "${evaluator} ~ "
    }
}

class StructuralEvaluatorImmediatePreviousSibling <: StructuralEvaluator {
    init(evaluator: Evaluator) {
        super(evaluator)
        this.evaluator = evaluator
    }

    public override func matches(root: ?Element, element: Element): Bool {
        if (root == element) {
            return false
        }
        var prev: ?Element = element.previousElementSibling()
        return prev != None && evaluator.matches(root, prev())
    }

    public func toString(): String {
        return "${evaluator} + "
    }
}
