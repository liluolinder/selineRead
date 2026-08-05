/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

public class Selector {
    /*
     * not instantiable
     */
    private init() {}

    /*
     * Find elements matching selector.
     *
     * @param query CSS selector
     * @param root  root element to descend into
     * @return matching elements, empty if none
     */
    public static func select(query: String, root: Element): Elements {
        Validate.notEmpty(query)
        return select(QueryParser.parse(query), root)
    }

    /*
     * Find elements matching selector.
     *
     * @param evaluator CSS selector
     * @param root root element to descend into
     * @return matching elements, empty if none
     */
    public static func select(evaluator: Evaluator, root: Element): Elements {
        return Collector.collect(evaluator, root)
    }

    /*
     * Find elements matching selector.
     *
     * @param query CSS selector
     * @param roots root elements to descend into
     * @return matching elements, empty if none
     */
    public static func select(query: String, roots: Iterable<Element>): Elements {
        Validate.notEmpty(query)
        var evaluator: Evaluator = QueryParser.parse(query)
        var elements: Elements = Elements()
        var seenElements: HashMap<Element, Bool> = HashMap<Element, Bool>()

        // dedupe elements by identity, not equality
        for (root in roots) {
            var found: Elements = select(evaluator, root)
            for (el in found.elementArr) {
                if (seenElements.add(el, true) == None) {
                    elements.elementArr.add(el)
                }
            }
        }
        return elements
    }

    /*
     * exclude set. package open so that Elements can implement .not() selector.
     */
    static func filterOut(elements: Collection<Element>, outs: Collection<Element>): Elements {
        var output: Elements = Elements()
        for (el in elements) {
            var found: Bool = false
            for (out in outs) {
                if (el == out) {
                    found = true
                    break
                }
            }
            if (!found) {
                output.elementArr.add(el)
            }
        }
        return output
    }

    /*
     * Find the first element that matches the query.
     *
     * @param cssQuery CSS selector
     * @param root root element to descend into
     * @return the matching element, or none
     */
    public static func selectFirst(cssQuery: String, root: Element): ?Element {
        Validate.notEmpty(cssQuery)
        return Collector.findFirst(QueryParser.parse(cssQuery), root)
    }
}
