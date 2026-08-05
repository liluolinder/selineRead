/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

abstract class CombiningEvaluator <: Evaluator {
    var evaluators: ArrayList<Evaluator>
    var num: Int64 = 0

    init() {
        super()
        evaluators = ArrayList<Evaluator>()
    }

    init(evaluators: Collection<Evaluator>) {
        this()
        this.evaluators.add(all: evaluators)
        num = evaluators.size
    }

    func rightMostEvaluator(): ?Evaluator {
        if (num > 0) {
            return evaluators.get(num - 1)
        } else {
            return None
        }
    }

    func replaceRightMostEvaluator(replacement: Evaluator): Unit {
        evaluators[num - 1] = replacement
    }

    func updateNumEvaluators(): Unit {
        // used so we don't need to bash on size() for every match test
        num = evaluators.size
    }
}

class CombiningEvaluatorAnd <: CombiningEvaluator {
    init(evaluators: Collection<Evaluator>) {
        super(evaluators)
    }

    init(evaluators: Array<Evaluator>) {
        this(ArrayList<Evaluator>(evaluators))
    }

    public override func matches(root: ?Element, element: Element): Bool {
        for (i in num - 1..=0 : -1) {
            // process backwards so that :matchText is evaled earlier, to catch parent query. todo - should redo matchText to virtually expand during match, not pre-match (see SelectorTest#findBetweenSpan)
            var s: Evaluator = evaluators.get(i)()
            if (!s.matches(root, element)) {
                return false
            }
        }
        return true
    }

    public func toString(): String {
        let arr = evaluators |> map<Evaluator, String> {v => v.toString()}
        return StringUtil.join(arr, "")
    }
}

class CombiningEvaluatorOr <: CombiningEvaluator {
    /*
     * Create a new Or evaluator. The initial evaluators are ANDed together and used as the first clause of the OR.
     * @param evaluators initial OR clause (these are wrapped into an AND evaluator).
     */
    init(evaluators: Collection<Evaluator>) {
        super()
        if (num > 1) {
            this.evaluators.add(CombiningEvaluatorAnd(evaluators))
        } else {
            // 0 or 1
            this.evaluators.add(all: evaluators)
        }
        updateNumEvaluators()
    }

    init(evaluators: Array<Evaluator>) {
        this(ArrayList(evaluators))
    }

    init() {
        super()
    }

    public func add(e: Evaluator): CombiningEvaluatorOr {
        evaluators.add(e)
        updateNumEvaluators()
        this
    }

    public override func matches(root: ?Element, node: Element): Bool {
        for (s in evaluators) {
            if (s.matches(root, node)) {
                return true
            }
        }
        return false
    }

    public func toString(): String {
        let arr = evaluators |> map<Evaluator, String> {v => v.toString()}
        return StringUtil.join(arr, ", ")
    }
}
