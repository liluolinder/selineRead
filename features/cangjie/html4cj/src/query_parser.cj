/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

class QueryParser <: ToString {
    private static let combinators: Array<Rune> = [r',', r'>', r'+', r'~', r' ']

    private static let AttributeEvals: Array<String> = ["=", "!=", "^=", "$=", "*=", "~="]

    private var tq: TokenQueue

    private var query: String

    private var evals: ArrayList<Evaluator> = ArrayList<Evaluator>()

    /*
     * Create a new QueryParser.
     *
     * @param query CSS query
     */
    private init(queryStr: String) {
        Validate.notEmpty(queryStr)
        this.query = queryStr.strip()
        this.tq = TokenQueue(this.query)
    }

    /*
     * Parse a CSS query into an Evaluator.
     *
     * @param query CSS query
     * @return Evaluator
     */
    public static func parse(query: String): Evaluator {
        try {
            let p: QueryParser = QueryParser(query)
            return p.doParse()
        } catch (e: ValidationException) {
            throw SelectorParseException(e.message)
        }
    }

    /*
     * Parse the query
     * @return Evaluator
     */
    func doParse(): Evaluator {
        tq.consumeWhitespace()

        if (tq.matchesAny(combinators)) { // if starts with a combinator, use root as elements
            evals.add(StructuralEvaluatorRoot())
            combinator(tq.consume())
        } else {
            findElements()
        }

        while (!tq.isEmpty()) {
            // hierarchy and extras
            let seenWhite: Bool = tq.consumeWhitespace()

            if (tq.matchesAny(combinators)) {
                combinator(tq.consume())
            } else if (seenWhite) {
                combinator(r' ')
            } else { // E.class, E#id, E[attr] etc. AND
                findElements() // take next el, #. etc off queue
            }
        }

        if (evals.size == 1) {
            return evals[0]
        }

        return CombiningEvaluatorAnd(evals)
    }

    private func combinator(combinator: Rune): Unit {
        tq.consumeWhitespace()
        let subQuery: String = consumeSubQuery() // support multi > childs

        var rootEval: ?Evaluator // the new topmost evaluator
        var currentEval: ?Evaluator // the let the:evaluator new eval will be combined to. could be root, or rightmost or.
        let newEval: Evaluator = parse(subQuery) // the evaluator to add into target evaluator
        var replaceRightMost: Bool = false

        if (evals.size == 1) {
            currentEval = evals[0]
            rootEval = currentEval

            // make sure OR (,) has precedence:
            if (rootEval.instanceof<CombiningEvaluatorOr>() && combinator != r',') {
                currentEval = currentEval.instanceget<CombiningEvaluatorOr>().rightMostEvaluator()

                // assert currentEval != null // rightMost signature can return null (if none set), but always will have one by this point
                replaceRightMost = true
            }
        } else {
            currentEval = CombiningEvaluatorAnd(evals)
            rootEval = currentEval
        }
        evals.clear()

        // for most combinators: change the current eval into an AND of the current eval and the new eval
        currentEval = match (combinator) {
            case r'>' => CombiningEvaluatorAnd([StructuralEvaluatorImmediateParent(currentEval()), newEval])
            case r' ' => CombiningEvaluatorAnd([StructuralEvaluatorParent(currentEval()), newEval])
            case r'+' => CombiningEvaluatorAnd([StructuralEvaluatorImmediatePreviousSibling(currentEval()), newEval])
            case r'~' => CombiningEvaluatorAnd([StructuralEvaluatorPreviousSibling(currentEval()), newEval])
            case r',' => match (currentEval) {
                case Some(v: CombiningEvaluatorOr) => v.add(newEval)
                case _ => CombiningEvaluatorOr().add(currentEval()).add(newEval)
            }
            case _ => throw SelectorParseException("Unknown combinator '${combinator}'")
        }

        if (replaceRightMost) {
            rootEval.instanceget<CombiningEvaluatorOr>().replaceRightMostEvaluator(currentEval())
        } else {
            rootEval = currentEval
        }
        evals.add(rootEval())
    }

    private func consumeSubQuery(): String {
        let sq = StringUtil.borrowBuilder()
        while (!tq.isEmpty()) {
            if (tq.matches("(")) {
                sq.append("(")
                sq.append(tq.chompBalanced(r'(', r')'))
                sq.append(")")
            } else if (tq.matches("[")) {
                sq.append("[")
                sq.append(tq.chompBalanced(r'[', r']'))
                sq.append("]")
            } else if (tq.matchesAny(combinators)) {
                if (sq.size > 0) {
                    break
                } else {
                    tq.consume()
                }
            } else {
                sq.append(tq.consume())
            }
        }
        return StringUtil.releaseBuilder(sq)
    }

    private func findElements(): Unit {
        if (tq.matchChomp("#")) {
            byId()
        } else if (tq.matchChomp(".")) {
            byClass()
        } else if (tq.matchesWord() || tq.matches("*|")) { /*cjlint-ignore !G.EXP.03 */
            byTag()
        } else if (tq.matches("[")) {
            byAttribute()
        } else if (tq.matchChomp("*")) {
            allElements()
        } else if (tq.matchChomp(":lt(")) {
            indexLessThan()
        } else if (tq.matchChomp(":gt(")) {
            indexGreaterThan()
        } else if (tq.matchChomp(":eq(")) {
            indexEquals()
        } else if (tq.matches(":has(")) {
            has()
        } else if (tq.matches(":contains(")) {
            contains(false)
        } else if (tq.matches(":containsOwn(")) {
            contains(true)
        } else if (tq.matches(":containsWholeText(")) {
            containsWholeText(false)
        } else if (tq.matches(":containsWholeOwnText(")) {
            containsWholeText(true)
        } else if (tq.matches(":containsData(")) {
            containsData()
        } else if (tq.matches(":matches(")) {
            matches(false)
        } else if (tq.matches(":matchesOwn(")) {
            matches(true)
        } else {
            findElementsElseif()
        }
    }
    private func findElementsElseif(): Unit {
        if (tq.matches(":matchesWholeText(")) {
            matchesWholeText(false)
        } else if (tq.matches(":matchesWholeOwnText(")) {
            matchesWholeText(true)
        } else if (tq.matches(":not(")) {
            not()
        } else if (tq.matchChomp(":nth-child(")) {
            cssNthChild(false, false)
        } else if (tq.matchChomp(":nth-last-child(")) {
            cssNthChild(true, false)
        } else if (tq.matchChomp(":nth-of-type(")) {
            cssNthChild(false, true)
        } else if (tq.matchChomp(":nth-last-of-type(")) {
            cssNthChild(true, true)
        } else if (tq.matchChomp(":first-child")) {
            evals.add(EvaluatorIsFirstChild())
        } else if (tq.matchChomp(":last-child")) {
            evals.add(EvaluatorIsLastChild())
        } else if (tq.matchChomp(":first-of-type")) {
            evals.add(EvaluatorIsFirstOfType())
        } else if (tq.matchChomp(":last-of-type")) {
            evals.add(EvaluatorIsLastOfType())
        } else if (tq.matchChomp(":only-child")) {
            evals.add(EvaluatorIsOnlyChild())
        } else if (tq.matchChomp(":only-of-type")) {
            evals.add(EvaluatorIsOnlyOfType())
        } else if (tq.matchChomp(":empty")) {
            evals.add(EvaluatorIsEmpty())
        } else if (tq.matchChomp(":root")) {
            evals.add(EvaluatorIsRoot())
        } else if (tq.matchChomp(":matchText")) {
            evals.add(EvaluatorMatchText())
        } else {
            // unhandled
            throw SelectorParseException("Could not parse query '${query}': unexpected token at '${tq.remainder()}'")
        }
    }

    private func byId(): Unit {
        let id: String = tq.consumeCssIdentifier()
        Validate.notEmpty(id)
        evals.add(EvaluatorId(id))
    }

    private func byClass(): Unit {
        let className: String = tq.consumeCssIdentifier()
        Validate.notEmpty(className)
        evals.add(EvaluatorClass(className.strip()))
    }

    private func byTag(): Unit {
        var tagName: String = Normalizer.normalize(tq.consumeElementSelector())
        Validate.notEmpty(tagName)

        // namespaces: wildcard match equals(tagName) or ending in ":"+tagName
        if (tagName.startsWith("*|")) {
            let plainTag: String = tagName[2..] // strip *|
            evals.add(CombiningEvaluatorOr([EvaluatorTag(plainTag), EvaluatorTagEndsWith(tagName.replace("*|", ":"))]))
        } else {
            // namespaces: if element name is "abc:def", selector must be "abc|def", so flip:
            if (tagName.contains("|")) {
                tagName = tagName.replace("|", ":")
            }

            evals.add(EvaluatorTag(tagName))
        }
    }

    private func byAttribute(): Unit {
        let cq: TokenQueue = TokenQueue(tq.chompBalanced(r'[', r']')) // content queue
        let key: String = cq.consumeToAny(AttributeEvals) // eq, not, start, end, contain, match, (no val)
        Validate.notEmpty(key)
        cq.consumeWhitespace()

        if (cq.isEmpty()) {
            if (key.startsWith("^")) {
                evals.add(EvaluatorAttributeStarting(key[1..]))
            } else {
                evals.add(EvaluatorAttribute(key))
            }
        } else {
            if (cq.matchChomp("=")) {
                evals.add(EvaluatorAttributeWithValue(key, cq.remainder()))
            } else if (cq.matchChomp("!=")) {
                evals.add(EvaluatorAttributeWithValueNot(key, cq.remainder()))
            } else if (cq.matchChomp("^=")) {
                evals.add(EvaluatorAttributeWithValueStarting(key, cq.remainder()))
            } else if (cq.matchChomp("$=")) {
                evals.add(EvaluatorAttributeWithValueEnding(key, cq.remainder()))
            } else if (cq.matchChomp("*=")) {
                evals.add(EvaluatorAttributeWithValueContaining(key, cq.remainder()))
            } else if (cq.matchChomp("~=")) {
                evals.add(EvaluatorAttributeWithValueMatching(key, Regex(cq.remainder())))
            } else {
                throw SelectorParseException(
                    "Could not parse attribute query '${query}': unexpected token at '${cq.remainder()}'")
            }
        }
    }

    private func allElements(): Unit {
        evals.add(EvaluatorAllElements())
    }

    // pseudo selectors :lt, :gt, :eq
    private func indexLessThan(): Unit {
        evals.add(EvaluatorIndexLessThan(consumeIndex()))
    }

    private func indexGreaterThan(): Unit {
        evals.add(EvaluatorIndexGreaterThan(consumeIndex()))
    }

    private func indexEquals(): Unit {
        evals.add(EvaluatorIndexEquals(consumeIndex()))
    }

    //pseudo selectors :first-child, :last-child, :nth-child, ...
    private static let NTH_AB = Regex("(([+]|[-])?(\\d+)?)n(\\s*([+]|[-])?\\s*\\d+)?", RegexOption().ignoreCase())
    private static let NTH_B = Regex("([+]|[-])?(\\d+)")
    private static let REPLACE = Regex("^\\+")

    private func cssNthChild(backwards: Bool, ofType: Bool): Unit {
        let argS: String = Normalizer.normalize(tq.chompTo(")"))
        let mAB: ?MatchData = NTH_AB.matcher(argS).find()
        let mB: ?MatchData = NTH_B.matcher(argS).find()
        let (a, b) = if ("odd" == argS) {
            (2, 1)
        } else if ("even" == argS) {
            (2, 0)
        } else if (mAB.isSome()) {
            let group = mAB()
            (if (group.groupNumber() >= 3) {
                    Int64.parse(REPLACE.matcher(group.matchString(1)).replace(""))
                } else {
                    1
                }, if (group.groupNumber() >= 4) {
                    Int64.parse(REPLACE.matcher(group.matchString(4)).replace(""))
                } else {
                    0
                })
        } else if (mB.isSome()) {
            let group = mB()
            (0, Int64.parse(REPLACE.matcher(group.matchString(0)).replace("")))
        } else {
            throw SelectorParseException("Could not parse nth-index '${argS}': unexpected format")
        }
        if (ofType) {
            if (backwards) {
                evals.add(EvaluatorIsNthLastOfType(a, b))
            } else {
                evals.add(EvaluatorIsNthOfType(a, b))
            }
        } else {
            if (backwards) {
                evals.add(EvaluatorIsNthLastChild(a, b))
            } else {
                evals.add(EvaluatorIsNthChild(a, b))
            }
        }
    }

    private func consumeIndex(): Int64 {
        let indexS: String = tq.chompTo(")").strip()
        Validate.isTrue(StringUtil.isNumeric(indexS), "Index must be numeric")
        return Int64.parse(indexS)
    }

    // pseudo selector :has(el)
    private func has(): Unit {
        tq.consume(":has")
        let subQuery: String = tq.chompBalanced(r'(', r')')
        Validate.notEmpty(subQuery, ":has(selector) sub-select must not be empty")
        evals.add(StructuralEvaluatorHas(parse(subQuery)))
    }

    // pseudo selector :contains(text), containsOwn(text)
    private func contains(own: Bool): Unit {
        let query: String = if (own) {
            ":containsOwn"
        } else {
            ":contains"
        }
        tq.consume(query)
        let searchText: String = TokenQueue.unescape(tq.chompBalanced(r'(', r')'))
        Validate.notEmpty(searchText, query + "(text) query must not be empty")
        evals.add(if (own) {
            EvaluatorContainsOwnText(searchText)
        } else {
            EvaluatorContainsText(searchText)
        })
    }

    private func containsWholeText(own: Bool): Unit {
        let query: String = if (own) {
            ":containsWholeOwnText"
        } else {
            ":containsWholeText"
        }
        tq.consume(query)
        let searchText: String = TokenQueue.unescape(tq.chompBalanced(r'(', r')'))
        Validate.notEmpty(searchText, query + "(text) query must not be empty")
        evals.add(if (own) {
            EvaluatorContainsWholeOwnText(searchText)
        } else {
            EvaluatorContainsWholeText(searchText)
        })
    }

    // pseudo selector :containsData(data)
    private func containsData(): Unit {
        tq.consume(":containsData")
        let searchText: String = TokenQueue.unescape(tq.chompBalanced(r'(', r')'))
        Validate.notEmpty(searchText, ":containsData(text) query must not be empty")
        evals.add(EvaluatorContainsData(searchText))
    }

    // :matches(regex), matchesOwn(regex)
    private func matches(own: Bool): Unit {
        let query: String = if (own) {
            ":matchesOwn"
        } else {
            ":matches"
        }
        tq.consume(query)
        let regex: String = tq.chompBalanced(r'(', r')') // don't unescape, as regex bits will be escaped
        Validate.notEmpty(regex, query + "(regex) query must not be empty")

        evals.add(if (own) {
            EvaluatorMatchesOwn(Regex(regex))
        } else {
            EvaluatorMatches(Regex(regex))
        })
    }

    // :matches(regex), matchesOwn(regex)
    private func matchesWholeText(own: Bool): Unit {
        let query: String = if (own) {
            ":matchesWholeOwnText"
        } else {
            ":matchesWholeText"
        }
        tq.consume(query)
        let regex: String = tq.chompBalanced(r'(', r')') // don't unescape, as regex bits will be escaped
        Validate.notEmpty(regex, query + "(regex) query must not be empty")

        evals.add(if (own) {
            EvaluatorMatchesWholeOwnText(Regex(regex))
        } else {
            EvaluatorMatchesWholeText(Regex(regex))
        })
    }

    // :not(selector)
    private func not(): Unit {
        tq.consume(":not")
        let subQuery: String = tq.chompBalanced(r'(', r')')
        Validate.notEmpty(subQuery, ":not(selector) subselect must not be empty")

        evals.add(StructuralEvaluatorNot(parse(subQuery)))
    }

    public func toString(): String {
        return query
    }
}
