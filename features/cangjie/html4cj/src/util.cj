/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

extend<T> Option<T> {
    operator func ()(): T {
        this.getOrThrow()
    }
    operator func ()(t: T): T {
        this.getOrDefault {=> t}
    }

    func instanceof<R>(): Bool {
        this.isSome() && this.getOrThrow() is R
    }

    func instanceget<R>(): R {
        match (this) {
            case Some(v: R) => v
            case _ => throw NoneValueException()
        }
    }
}

extend Object {
    func refEq<T>(t: T): Bool where T <: Object {
        refEq(this, t)
    }

    func refEq<T>(t: ?T): Bool where T <: Object {
        match (t) {
            case Some(v) => refEq(v, this)
            case _ => false
        }
    }
}

extend<T> Option<T> where T <: Object {
    func refEq(other: Object): Bool {
        let a = this.isNone()
        if (a) {
            false
        } else {
            refEq(this.getOrThrow(), other)
        }
    }

    func refEq(other: ?Object): Bool {
        let a = this.isNone()
        let b = other.isNone()
        if (a && b) {
            true
        } else if (!a && !b) {
            refEq(this.getOrThrow(), other())
        } else {
            false
        }
    }
}

extend<T> Option<T> where T <: Equatable<T> {
    operator func ==(other: T): Bool {
        match (this) {
            case Some(v) => v == other
            case _ => false
        }
    }

    operator func !=(other: T): Bool {
        !(this == other)
    }
}

extend String {
    func equalsIgnoreCase(other: String) {
        this.toAsciiLower() == other.toAsciiLower()
    }
    func strip(): String {
        var (left, right) = (0, this.size - 1)
        while (left <= right && this[left] <= b' ') {
            left++
        }
        while (left <= right && this[right] <= b' ') {
            right--
        }
        return this[left..=right]
    }
    func equals(s: String): Bool {
        this == s
    }
}

extend Object {
    func apply<T>(block: (T) -> Unit): T {
        let t = (this as T).getOrThrow()
        block(t)
        return t
    }
}

extend<T> ArrayList<T> where T <: Object {
    func lastIndexOf(t: T): Int64 {
        for (i in size - 1..=0 : -1) {
            if (refEq(this[i], t)) {
                return i
            }
        }
        return -1
    }
}

func binarySearch<T>(array: Collection<T>, key: T): Int64 where T <: Comparable<T> {
    var arr: Array<T> = array.toArray()
    var low = 0
    var high = arr.size - 1
    while (low <= high) {
        var mid = (low + high) / 2
        let midVal = arr[mid]
        match (midVal.compare(key)) {
            case LT => low = mid + 1
            case GT => high = mid - 1
            case EQ => return mid // key found
        }
    }

    // key not found.
    return -(low + 1)
}

extend Int64 {
    operator func **(n: Int64): Int64 {
        var r = 1
        for (_ in 0..n) {
            r *= this
        }
        r
    }

    func toUnicodeChar(): Rune {
        Rune.parse("'\\u{${this.format("x")}}'")
    }
}

func parseRadix36(str: String) {
    let s = str.toRuneArray()
    var z = 0
    var sum = 0
    for (i in s.size - 1..=0 : -1) {
        let c = s[i].toAsciiUpperCase()
        let num = if (c > r'9') {
            c.hashCode() - 0x37
        } else {
            c.hashCode() - 0x30
        }
        sum += num * (36 ** z)
        z++
    }
    sum
}

@OverflowWrapping
func calcHash(hash: Int64, mask: Int64): Int64 {
    return 31 * hash + mask
}

extend Array<Rune> {
    func equalsIgnoreCase(other: Array<Rune>): Bool {
        if (this.size != other.size) {
            return false
        }
        for (i in 0..this.size where this[i].toAsciiLowerCase() != other[i].toAsciiLowerCase()) {
            return false
        }
        return true
    }
}
