package seajson

// ============================================================================
// JSONPath - Query JSON documents with path expressions
// ============================================================================
//
// Implementation based on Stefan Goessner's JSONPath specification:
// https://goessner.net/articles/JsonPath/
//
// Supported syntax:
//   $                  - root element
//   .field             - object field access
//   [index]            - array index access
//   [start:end]        - array slice
//   [*]                - wildcard (all elements/fields)
//   ..field            - recursive descent (all matching fields at any depth)
//   ..*                - recursive wildcard (all values at any depth)
//   [?(@.expr)]        - filter expression (basic support)
//
// Examples:
//   $.store.book[0].title       - get first book's title
//   $.store.book[*].author      - get all book authors
//   $..author                   - get all authors at any depth
//   $.store.book[0:2]           - get first two books
//   $..*                        - get all values at any depth
//   $..[?(@.price < 10)]        - filter items with price < 10
//
// ============================================================================

import std.collection.ArrayList

// ── Character constants (UInt8) ──────────────────────────────────────
let PATH_DOLLAR: UInt8 = 36      // '$'
let PATH_DOT: UInt8 = 46         // '.'
let PATH_LBRACKET: UInt8 = 91    // '['
let PATH_RBRACKET: UInt8 = 93    // ']'
let PATH_STAR: UInt8 = 42        // '*'
let PATH_COLON: UInt8 = 58       // ':'
let PATH_MINUS: UInt8 = 45       // '-'
let PATH_SINGLE_QUOTE: UInt8 = 39 // '\''
let PATH_DOUBLE_QUOTE: UInt8 = 34 // '"'
let PATH_QUESTION: UInt8 = 63    // '?'
let PATH_SPACE: UInt8 = 32       // ' '
let PATH_TAB: UInt8 = 9          // '\t'
let PATH_NL: UInt8 = 10          // '\n'
let PATH_CR: UInt8 = 13          // '\r'
let PATH_0: UInt8 = 48           // '0'
let PATH_9: UInt8 = 57           // '9'
let PATH_AT: UInt8 = 64          // '@'
let PATH_LPAREN: UInt8 = 40      // '('
let PATH_RPAREN: UInt8 = 41      // ')'
let PATH_LT: UInt8 = 60          // '<'
let PATH_GT: UInt8 = 62          // '>'
let PATH_EQ: UInt8 = 61          // '='
let PATH_BANG: UInt8 = 33        // '!'
let PATH_AND: UInt8 = 38         // '&'
let PATH_OR: UInt8 = 124         // '|'
let PATH_UNDERSCORE: UInt8 = 95  // '_'
let PATH_A: UInt8 = 65           // 'A'
let PATH_Z: UInt8 = 90           // 'Z'
let PATH_a: UInt8 = 97           // 'a'
let PATH_z: UInt8 = 122          // 'z'

/// Comparison operators for filter expressions
public enum FilterOp {
    | Lt      // <
    | Gt      // >
    | Eq      // ==
    | Ne      // !=
    | Le      // <=
    | Ge      // >=
}

/// Filter expression: compares a field value to a literal
public class FilterExpr {
    public var fieldPath: ArrayList<String>  // e.g., ["price"] for @.price
    public var op: FilterOp
    public var compareValue: JsonValue       // value to compare against

    public init() {
        this.fieldPath = ArrayList<String>()
        this.op = FilterOp.Eq
        this.compareValue = JsonNull
    }
}

/// JSONPath query result - can be a single value or multiple values
public enum JsonPathResult {
    | Single(JsonValue)
    | Multiple(ArrayList<JsonValue>)
    | None
}

/// JSONPath parser and executor
public class JsonPath {
    private let src: ArrayList<UInt8>
    private var pos: Int64 = 0

    public init(path: String) {
        this.src = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < path.size) {
            this.src.add(path[i])
            i += 1
        }
    }

    /// Execute the JSONPath query on a JsonValue
    public func execute(root: JsonValue): JsonPathResult {
        pos = 0
        if (src.size == 0) {
            return Single(root)
        }

        // Must start with $
        if (src[0] != PATH_DOLLAR) {
            return None
        }
        pos = 1

        var current = root
        while (pos < src.size) {
            let ch = src[pos]

            if (ch == PATH_DOT) {
                pos += 1
                if (pos < src.size && src[pos] == PATH_DOT) {
                    // Recursive descent ..
                    pos += 1
                    let results = ArrayList<JsonValue>()

                    // Check if next is * (recursive wildcard)
                    if (pos < src.size && src[pos] == PATH_STAR) {
                        pos += 1
                        // ..* - collect all values at any depth
                        collectAllRecursive(root, results)
                        if (results.size == 0) {
                            return None
                        }
                        return Multiple(results)
                    }

                    // ..field - collect specific field at any depth
                    let fieldName = parseFieldName()
                    collectRecursive(root, fieldName, results)
                    if (results.size == 0) {
                        return None
                    } else if (results.size == 1) {
                        return Single(results[0])
                    }
                    return Multiple(results)
                } else {
                    // Field access
                    let fieldName = parseFieldName()
                    match (jsonField(current, fieldName)) {
                        case Some(v) => current = v
                        case None => return None
                    }
                }
            } else if (ch == PATH_LBRACKET) {
                pos += 1
                let bracketResult = parseBracket(current)
                match (bracketResult) {
                    case Some(v) => current = v
                    case None => return None
                }
            } else {
                break
            }
        }

        Single(current)
    }

    private func parseFieldName(): String {
        var name = ""
        while (pos < src.size) {
            let ch = src[pos]
            if (ch == PATH_DOT || ch == PATH_LBRACKET) {
                break
            }
            name += String.fromUtf8(Array<UInt8>(1, repeat: ch))
            pos += 1
        }
        name
    }

    private func parseBracket(current: JsonValue): ?JsonValue {
        skipWhitespace()

        if (pos >= src.size) {
            return None
        }

        let ch = src[pos]

        if (ch == PATH_STAR) {
            // [*] - wildcard (return current as-is)
            pos += 1
            skipWhitespace()
            if (pos < src.size && src[pos] == PATH_RBRACKET) {
                pos += 1
            }
            return Some(current)
        } else if (ch == PATH_SINGLE_QUOTE || ch == PATH_DOUBLE_QUOTE) {
            // ['field'] or ["field"] - quoted field name
            let quoteChar = ch
            pos += 1
            var name = ""
            while (pos < src.size && src[pos] != quoteChar) {
                name += String.fromUtf8(Array<UInt8>(1, repeat: src[pos]))
                pos += 1
            }
            if (pos < src.size) {
                pos += 1 // skip closing quote
            }
            skipWhitespace()
            if (pos < src.size && src[pos] == PATH_RBRACKET) {
                pos += 1
            }
            return jsonField(current, name)
        } else if ((ch >= PATH_0 && ch <= PATH_9) || ch == PATH_MINUS || ch == PATH_COLON) {
            // [index] or [start:end] - array index or slice
            let num1: Int64
            let hasNum1: Bool

            if (ch == PATH_COLON) {
                // [:end] - slice from start
                num1 = 0
                hasNum1 = false
            } else {
                num1 = parseNumber()
                hasNum1 = true
            }
            skipWhitespace()

            if (pos < src.size && src[pos] == PATH_COLON) {
                // Slice [start:end] or [:end]
                pos += 1
                skipWhitespace()

                let num2: Int64
                if (pos < src.size && ((src[pos] >= PATH_0 && src[pos] <= PATH_9) || src[pos] == PATH_MINUS)) {
                    num2 = parseNumber()
                } else {
                    // [start:] - slice to end
                    num2 = -1 // sentinel for "to end"
                }

                skipWhitespace()
                if (pos < src.size && src[pos] == PATH_RBRACKET) {
                    pos += 1
                }
                return getSlice(current, num1, num2, hasNum1, num2 != -1 || !hasNum1)
            } else {
                // Single index (may be negative)
                if (pos < src.size && src[pos] == PATH_RBRACKET) {
                    pos += 1
                }
                return getIndexWithNegative(current, num1)
            }
        } else if (ch == PATH_QUESTION) {
            // Filter expression [?(...)]
            pos += 1
            skipWhitespace()
            if (pos < src.size && src[pos] == PATH_LPAREN) {
                pos += 1  // skip '('
                let filterExpr = parseFilterExpression()
                skipWhitespace()
                if (pos < src.size && src[pos] == PATH_RPAREN) {
                    pos += 1  // skip ')'
                }
                skipWhitespace()
                if (pos < src.size && src[pos] == PATH_RBRACKET) {
                    pos += 1
                }
                return applyFilter(current, filterExpr)
            }
            // Invalid filter syntax, skip to closing bracket
            while (pos < src.size && src[pos] != PATH_RBRACKET) {
                pos += 1
            }
            if (pos < src.size) {
                pos += 1
            }
            return None
        }

        // Skip to closing bracket
        while (pos < src.size && src[pos] != PATH_RBRACKET) {
            pos += 1
        }
        if (pos < src.size) {
            pos += 1
        }
        None
    }

    private func parseNumber(): Int64 {
        var negative = false
        if (pos < src.size && src[pos] == PATH_MINUS) {
            negative = true
            pos += 1
        }

        var num: Int64 = 0
        while (pos < src.size) {
            let ch = src[pos]
            if (ch >= PATH_0 && ch <= PATH_9) {
                num = num * 10 + (Int64(ch) - Int64(PATH_0))
                pos += 1
            } else {
                break
            }
        }

        if (negative) { -num } else { num }
    }

    private func skipWhitespace(): Unit {
        while (pos < src.size) {
            let ch = src[pos]
            if (ch == PATH_SPACE || ch == PATH_TAB || ch == PATH_NL || ch == PATH_CR) {
                pos += 1
            } else {
                break
            }
        }
    }

    private func getIndexWithNegative(v: JsonValue, index: Int64): ?JsonValue {
        match (v) {
            case JsonArrVal(items) =>
                let actualIndex = if (index < 0) {
                    items.size + index
                } else {
                    index
                }
                if (actualIndex >= 0 && actualIndex < items.size) {
                    Some(items[actualIndex])
                } else {
                    None
                }
            case _ => None
        }
    }

    private func getSlice(v: JsonValue, start: Int64, end: Int64, hasStart: Bool, hasEnd: Bool): ?JsonValue {
        match (v) {
            case JsonArrVal(items) =>
                let s: Int64 = if (!hasStart) {
                    0
                } else if (start < 0) {
                    items.size + start
                } else {
                    start
                }

                let e: Int64 = if (!hasEnd) {
                    items.size
                } else if (end < 0) {
                    items.size + end
                } else {
                    end
                }

                let clampedStart = if (s < 0) { 0 } else if (s > items.size) { items.size } else { s }
                let clampedEnd = if (e < 0) { 0 } else if (e > items.size) { items.size } else { e }

                if (clampedStart >= clampedEnd) {
                    Some(jsonEmptyArray())
                } else {
                    let result = ArrayList<JsonValue>()
                    var i = clampedStart
                    while (i < clampedEnd) {
                        result.add(items[i])
                        i += 1
                    }
                    Some(JsonArrVal(result))
                }
            case _ => None
        }
    }

    private func collectRecursive(v: JsonValue, fieldName: String, results: ArrayList<JsonValue>): Unit {
        match (v) {
            case JsonObjVal(entries) =>
                var i: Int64 = 0
                while (i < entries.size) {
                    let (k, val) = entries[i]
                    if (k == fieldName) {
                        results.add(val)
                    }
                    collectRecursive(val, fieldName, results)
                    i += 1
                }
            case JsonArrVal(items) =>
                var i: Int64 = 0
                while (i < items.size) {
                    collectRecursive(items[i], fieldName, results)
                    i += 1
                }
            case _ => ()
        }
    }

    private func collectAllRecursive(v: JsonValue, results: ArrayList<JsonValue>): Unit {
        results.add(v)
        match (v) {
            case JsonObjVal(entries) =>
                var i: Int64 = 0
                while (i < entries.size) {
                    let (_, val) = entries[i]
                    collectAllRecursive(val, results)
                    i += 1
                }
            case JsonArrVal(items) =>
                var i: Int64 = 0
                while (i < items.size) {
                    collectAllRecursive(items[i], results)
                    i += 1
                }
            case _ => ()
        }
    }

    // ── Filter Expression Parsing ───────────────────────────────────────

    private func parseFilterExpression(): FilterExpr {
        let expr = FilterExpr()
        skipWhitespace()

        // Expect @.field
        if (pos < src.size && src[pos] == PATH_AT) {
            pos += 1  // skip '@'
        }
        skipWhitespace()

        // Parse field path (e.g., .price or .nested.field)
        while (pos < src.size && src[pos] == PATH_DOT) {
            pos += 1  // skip '.'
            let fieldName = parseFilterFieldName()
            expr.fieldPath.add(fieldName)
            skipWhitespace()
        }

        // Parse operator
        if (pos < src.size) {
            let ch = src[pos]
            if (ch == PATH_LT) {
                pos += 1
                if (pos < src.size && src[pos] == PATH_EQ) {
                    pos += 1
                    expr.op = FilterOp.Le
                } else {
                    expr.op = FilterOp.Lt
                }
            } else if (ch == PATH_GT) {
                pos += 1
                if (pos < src.size && src[pos] == PATH_EQ) {
                    pos += 1
                    expr.op = FilterOp.Ge
                } else {
                    expr.op = FilterOp.Gt
                }
            } else if (ch == PATH_EQ) {
                pos += 1
                if (pos < src.size && src[pos] == PATH_EQ) {
                    pos += 1
                    expr.op = FilterOp.Eq
                }
            } else if (ch == PATH_BANG) {
                pos += 1
                if (pos < src.size && src[pos] == PATH_EQ) {
                    pos += 1
                    expr.op = FilterOp.Ne
                }
            }
        }

        skipWhitespace()

        // Parse comparison value
        expr.compareValue = parseFilterValue()

        expr
    }

    private func parseFilterFieldName(): String {
        var name = ""
        while (pos < src.size) {
            let ch = src[pos]
            // Allow alphanumeric and underscore
            if ((ch >= PATH_0 && ch <= PATH_9) ||
                (ch >= PATH_A && ch <= PATH_Z) ||
                (ch >= PATH_a && ch <= PATH_z) ||
                ch == PATH_UNDERSCORE) {
                name += String.fromUtf8(Array<UInt8>(1, repeat: ch))
                pos += 1
            } else {
                break
            }
        }
        name
    }

    private func parseFilterValue(): JsonValue {
        skipWhitespace()
        if (pos >= src.size) {
            return JsonNull
        }

        let ch = src[pos]

        // String literal
        if (ch == PATH_SINGLE_QUOTE || ch == PATH_DOUBLE_QUOTE) {
            let quoteChar = ch
            pos += 1
            var s = ""
            while (pos < src.size && src[pos] != quoteChar) {
                s += String.fromUtf8(Array<UInt8>(1, repeat: src[pos]))
                pos += 1
            }
            if (pos < src.size) {
                pos += 1  // skip closing quote
            }
            return JsonStrVal(s)
        }

        // Number (integer or float)
        if ((ch >= PATH_0 && ch <= PATH_9) || ch == PATH_MINUS) {
            return parseFilterNumber()
        }

        // Boolean literals - use UInt8 constants
        let PATH_t: UInt8 = 116  // 't'
        let PATH_f: UInt8 = 102  // 'f'
        let PATH_n: UInt8 = 110  // 'n'

        if (ch == PATH_t) {
            if (matchKeyword("true")) {
                return JsonBoolVal(true)
            }
        } else if (ch == PATH_f) {
            if (matchKeyword("false")) {
                return JsonBoolVal(false)
            }
        } else if (ch == PATH_n) {
            if (matchKeyword("null")) {
                return JsonNull
            }
        }

        JsonNull
    }

    private func parseFilterNumber(): JsonValue {
        var negative = false
        if (pos < src.size && src[pos] == PATH_MINUS) {
            negative = true
            pos += 1
        }

        var intPart: Int64 = 0
        var hasFloat = false
        var floatPart: Float64 = 0.0
        var floatDivisor: Float64 = 10.0

        while (pos < src.size) {
            let ch = src[pos]
            if (ch >= PATH_0 && ch <= PATH_9) {
                if (hasFloat) {
                    floatPart = floatPart + (Float64(ch - PATH_0) / floatDivisor)
                    floatDivisor *= 10.0
                } else {
                    intPart = intPart * 10 + Int64(ch - PATH_0)
                }
                pos += 1
            } else if (ch == PATH_DOT && !hasFloat) {
                hasFloat = true
                pos += 1
            } else {
                break
            }
        }

        if (hasFloat) {
            var result = Float64(intPart) + floatPart
            if (negative) {
                result = -result
            }
            JsonFloatVal(result)
        } else {
            if (negative) {
                JsonIntVal(-intPart)
            } else {
                JsonIntVal(intPart)
            }
        }
    }

    private func matchKeyword(keyword: String): Bool {
        let startPos = pos
        var i: Int64 = 0
        while (i < keyword.size && pos < src.size) {
            if (src[pos] != keyword[i]) {
                pos = startPos
                return false
            }
            pos += 1
            i += 1
        }
        if (i < keyword.size) {
            pos = startPos
            return false
        }
        true
    }

    // ── Filter Expression Evaluation ─────────────────────────────────────

    private func applyFilter(current: JsonValue, expr: FilterExpr): ?JsonValue {
        // Filter only works on arrays
        match (current) {
            case JsonArrVal(items) =>
                let results = ArrayList<JsonValue>()
                var i: Int64 = 0
                while (i < items.size) {
                    if (evaluateFilter(items[i], expr)) {
                        results.add(items[i])
                    }
                    i += 1
                }
                if (results.size == 0) {
                    None
                } else {
                    Some(JsonArrVal(results))
                }
            case _ => None
        }
    }

    private func evaluateFilter(item: JsonValue, expr: FilterExpr): Bool {
        // Navigate to the field
        var current = item
        var i: Int64 = 0
        while (i < expr.fieldPath.size) {
            match (jsonField(current, expr.fieldPath[i])) {
                case Some(v) => current = v
                case None => return false
            }
            i += 1
        }

        // Compare values
        compareValues(current, expr.compareValue, expr.op)
    }

    private func compareValues(actual: JsonValue, expected: JsonValue, op: FilterOp): Bool {
        // Get numeric values for comparison
        let actualNum = getNumericValue(actual)
        let expectedNum = getNumericValue(expected)

        // Numeric comparison
        if (actualNum.isSome() && expectedNum.isSome()) {
            let a: Float64 = match (actualNum) {
                case Some(v) => v
                case None => 0.0
            }
            let e: Float64 = match (expectedNum) {
                case Some(v) => v
                case None => 0.0
            }
            match (op) {
                case FilterOp.Lt => a < e
                case FilterOp.Gt => a > e
                case FilterOp.Eq => a == e
                case FilterOp.Ne => a != e
                case FilterOp.Le => a <= e
                case FilterOp.Ge => a >= e
            }
        } else {
            // String comparison
            let actualStr = getStringValue(actual)
            let expectedStr = getStringValue(expected)
            match (op) {
                case FilterOp.Eq => actualStr == expectedStr
                case FilterOp.Ne => actualStr != expectedStr
                case _ => false  // <, > not supported for non-numeric strings
            }
        }
    }

    private func getNumericValue(v: JsonValue): ?Float64 {
        match (v) {
            case JsonIntVal(n) => Some(Float64(n))
            case JsonInt32Val(n) => Some(Float64(n))
            case JsonFloatVal(n) => Some(n)
            case _ => None
        }
    }

    private func getStringValue(v: JsonValue): String {
        match (v) {
            case JsonStrVal(s) => s
            case JsonNull => "null"
            case JsonBoolVal(b) => if (b) { "true" } else { "false" }
            case JsonIntVal(n) => n.toString()
            case JsonInt32Val(n) => n.toString()
            case JsonFloatVal(n) => n.toString()
            case _ => ""
        }
    }
}

/// Execute a JSONPath query and return a single result or None
public func jsonPathOne(root: JsonValue, path: String): ?JsonValue {
    let jp = JsonPath(path)
    match (jp.execute(root)) {
        case Single(v) => Some(v)
        case Multiple(items) =>
            if (items.size > 0) { Some(items[0]) } else { None }
        case None => None
    }
}

/// Execute a JSONPath query and return all matching values
public func jsonPathAll(root: JsonValue, path: String): ArrayList<JsonValue> {
    let jp = JsonPath(path)
    let result = ArrayList<JsonValue>()
    match (jp.execute(root)) {
        case Single(v) => result.add(v)
        case Multiple(items) =>
            var i: Int64 = 0
            while (i < items.size) {
                result.add(items[i])
                i += 1
            }
        case None => ()
    }
    result
}
