package chui.controls


/*
 * The Table's retained sort state, persisted across the per-frame rebuild via localState. It holds
 * the last computed display order together with the inputs it was computed from — the sort column,
 * direction, and the raw cells of that column — plus a cached identity order for the unsorted case.
 * displayOrder reuses `order` when the freshly extracted cells and the sort column/direction still
 * match, so a stable sorted table is neither re-parsed nor re-sorted every frame.
 */
internal class TableSortCache {
    var rowCount: Int64 = -1
    var identity: Array<Int64> = Array<Int64>()
    var valid: Bool = false
    var col: Int64 = -1
    var asc: Bool = true
    var cells: Array<String> = Array<String>()
    var order: Array<Int64> = Array<Int64>()
}

// Element-wise value equality of two string key arrays, short-circuiting on the first difference.
internal func stringKeysEqual(a: Array<String>, b: Array<String>): Bool {
    if (a.size != b.size) {
        return false
    }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) {
            return false
        }
        i += 1
    }
    true
}

// Bottom-up stable merge sort on a copy of the indices — O(n log n), keeps equal elements in
// their original order (a stable sort is what makes re-sorting a table feel predictable).
internal func stableSort(input: Array<Int64>, less: (Int64, Int64) -> Bool): Array<Int64> {
    let n = input.size
    let a = Array<Int64>(n, {i => input[i]})
    if (n <= 1) {
        return a
    }
    let buffer = Array<Int64>(n, {_ => 0})
    var width = 1
    while (width < n) {
        var lo = 0
        while (lo < n) {
            mergeRuns(a, buffer, lo, min(lo + width, n), min(lo + width * 2, n), less)
            lo += width * 2
        }
        var k = 0
        while (k < n) {
            a[k] = buffer[k]
            k += 1
        }
        width *= 2
    }
    a
}

internal func mergeRuns(
    a: Array<Int64>,
    buffer: Array<Int64>,
    lo: Int64,
    mid: Int64,
    hi: Int64,
    less: (Int64, Int64) -> Bool
): Unit {
    var i = lo
    var j = mid
    var k = lo
    while (i < mid && j < hi) {
        // Take the left run unless the right element is strictly smaller — this preserves the
        // relative order of equal elements (stability).
        if (less(a[j], a[i])) {
            buffer[k] = a[j]
            j += 1
        } else {
            buffer[k] = a[i]
            i += 1
        }
        k += 1
    }
    while (i < mid) {
        buffer[k] = a[i]
        i += 1
        k += 1
    }
    while (j < hi) {
        buffer[k] = a[j]
        j += 1
        k += 1
    }
}

internal func compareFloat(x: Float64, y: Float64): Int64 {
    if (x < y) {
        -1
    } else if (x > y) {
        1
    } else {
        0
    }
}

// Lexical comparison over UTF-8 bytes: alphabetical for ASCII and a stable, consistent order
// for other scripts.
internal func compareBytes(a: String, b: String): Int64 {
    var i = 0
    while (i < a.size && i < b.size) {
        if (a[i] < b[i]) {
            return -1
        }
        if (a[i] > b[i]) {
            return 1
        }
        i += 1
    }
    if (a.size < b.size) {
        -1
    } else if (a.size > b.size) {
        1
    } else {
        0
    }
}

// Parses a leading signed decimal from a cell for numeric sorting, tolerating surrounding text
// (leading spaces, a trailing unit like "%"): "87%" -> 87, " 3.5" -> 3.5, "-12" -> -12.
internal func numericKey(text: String): Float64 {
    let n = text.size
    var i = 0
    while (i < n && text[i] == UInt8(32)) {
        i += 1
    }
    var sign = 1.0
    if (i < n && (text[i] == UInt8(45) || text[i] == UInt8(43))) {
        if (text[i] == UInt8(45)) {
            sign = -1.0
        }
        i += 1
    }
    var intPart = 0.0
    var sawDigit = false
    while (i < n && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
        intPart = intPart * 10.0 + Float64(Int64(text[i]) - 48)
        sawDigit = true
        i += 1
    }
    var fraction = 0.0
    var divisor = 1.0
    if (i < n && text[i] == UInt8(46)) {
        i += 1
        while (i < n && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
            divisor *= 10.0
            fraction += Float64(Int64(text[i]) - 48) / divisor
            sawDigit = true
            i += 1
        }
    }
    if (!sawDigit) {
        return 0.0
    }
    sign * (intPart + fraction)
}
