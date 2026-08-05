package gjson


func validpayload(data: Array<Byte>, i: Int64): (Int64, Bool) {
    var j = i
    while (j < data.size) {
        match (data[j]) {
            case b' ' | b'\t' | b'\n' | b'\r' => j++
            case _ =>
                let (outi, ok) = validany(data, j)
                if (!ok) {
                    return (outi, false)
                }
                j = outi
                while (j < data.size) {
                    match (data[j]) {
                        case b' ' | b'\t' | b'\n' | b'\r' => j++
                        case _ => return (j, false)
                    }
                }
                return (j, true)
        }
    }
    return (j, false)
}

func validany(data: Array<Byte>, i: Int64): (Int64, Bool) {
    var j = i
    while (j < data.size) {
        match (data[j]) {
            case b' ' | b'\t' | b'\n' | b'\r' => j++
            case b'{' => return validobject(data, j + 1)
            case b'[' => return validarray(data, j + 1)
            case b'"' => return validstring(data, j + 1)
            case b'-' | b'0' | b'1' | b'2' | b'3' | b'4' | b'5' | b'6' | b'7' | b'8' | b'9' => return validnumber(data,
                j + 1)
            case b't' => return validtrue(data, j + 1)
            case b'f' => return validfalse(data, j + 1)
            case b'n' => return validnull(data, j + 1)
            case _ => return (j, false)
        }
    }
    return (j, false)
}

func validobject(data: Array<Byte>, ii: Int64): (Int64, Bool) {
    var j = ii
    while (j < data.size) {
        match (data[j]) {
            case b' ' | b'\t' | b'\n' | b'\r' => j++
            case b'}' => return (j + 1, true)
            case b'"' =>
                let (outi, ok) = validstring(data, j + 1)
                if (!ok) {
                    return (outi, false)
                }
                j = outi
                let (outi2, ok2) = validcolon(data, j)
                if (!ok2) {
                    return (outi2, false)
                }
                j = outi2
                let (outi3, ok3) = validany(data, j)
                if (!ok3) {
                    return (outi3, false)
                }
                j = outi3
                let (outi4, ok4) = validcomma(data, j, b'}')
                if (!ok4) {
                    return (outi4, false)
                }
                j = outi4
                if (data[j] == b'}') {
                    return (j + 1, true)
                }
                j++
                while (j < data.size) {
                    match (data[j]) {
                        case b' ' | b'\t' | b'\n' | b'\r' => j++
                        case b'"' => break
                        case _ => return (j, false)
                    }
                }
            case _ => return (j, false)
        }
    }
    return (j, false)
}

func validcolon(data: Array<Byte>, i: Int64): (Int64, Bool) {
    var j = i
    while (j < data.size) {
        match (data[j]) {
            case b' ' | b'\t' | b'\n' | b'\r' => j++
            case b':' => return (j + 1, true)
            case _ => return (j, false)
        }
    }
    return (j, false)
}

func validcomma(data: Array<Byte>, i: Int64, end: Byte): (Int64, Bool) {
    var j = i
    while (j < data.size) {
        match (data[j]) {
            case b' ' | b'\t' | b'\n' | b'\r' => j++
            case b',' => return (j, true)
            case ch where ch == end => return (j, true)
            case _ => return (j, false)
        }
    }
    return (j, false)
}

func validarray(data: Array<Byte>, i: Int64): (Int64, Bool) {
    var j = i
    while (j < data.size) {
        match (data[j]) {
            case b' ' | b'\t' | b'\n' | b'\r' => j++
            case b']' => return (j + 1, true)
            case _ =>
                let (outi, ok) = validany(data, j)
                if (!ok) {
                    return (outi, false)
                }
                j = outi
                let (outi2, ok2) = validcomma(data, j, b']')
                if (!ok2) {
                    return (outi2, false)
                }
                j = outi2
                if (data[j] == b']') {
                    return (j + 1, true)
                }
        }
    }
    return (j, false)
}

func validstring(data: Array<Byte>, ii: Int64): (Int64, Bool) {
    var i = ii
    while (i < data.size) {
        if (data[i] < b' ') {
            return (i, false)
        } else if (data[i] == b'\\') {
            i++
            if (i == data.size) {
                return (i, false)
            }
            match (data[i]) {
                case b'"' | b'\\' | b'/' | b'b' | b'f' | b'n' | b'r' | b't' => i++
                case b'u' => for (_ in 0..4) {
                    i++
                    if (i >= data.size) {
                        return (i, false)
                    }
                    if (!((data[i] >= b'0' && data[i] <= b'9') || (data[i] >= b'a' && data[i] <= b'f') || (data[i] >=
                        b'A' && data[i] <= b'F'))) {
                        return (i, false)
                    }
                }
                case _ => return (i, false)
            }
        } else if (data[i] == b'"') {
            return (i + 1, true)
        } else {
            i++
        }
    }
    return (i, false)
}

func validnumber(data: Array<Byte>, i: Int64): (Int64, Bool) {
    var j = i - 1
    // sign
    if (data[j] == b'-') {
        j++
        if (j == data.size) {
            return (j, false)
        }
        if (data[j] < b'0' || data[j] > b'9') {
            return (j, false)
        }
    }
    // int
    if (j == data.size) {
        return (j, false)
    }
    if (data[j] == b'0') {
        j++
    } else {
        while (j < data.size) {
            if (data[j] >= b'0' && data[j] <= b'9') {
                j++
                continue
            }
            break
        }
    }
    // frac
    if (j == data.size) {
        return (j, true)
    }
    if (data[j] == b'.') {
        j++
        if (j == data.size) {
            return (j, false)
        }
        if (data[j] < b'0' || data[j] > b'9') {
            return (j, false)
        }
        j++
        while (j < data.size) {
            if (data[j] >= b'0' && data[j] <= b'9') {
                j++
                continue
            }
            break
        }
    }
    // exp
    if (j == data.size) {
        return (j, true)
    }
    if (data[j] == b'e' || data[j] == b'E') {
        j++
        if (j == data.size) {
            return (j, false)
        }
        if (data[j] == b'+' || data[j] == b'-') {
            j++
        }
        if (j == data.size) {
            return (j, false)
        }
        if (data[j] < b'0' || data[j] > b'9') {
            return (j, false)
        }
        j++
        while (j < data.size) {
            if (data[j] >= b'0' && data[j] <= b'9') {
                j++
                continue
            }
            break
        }
    }
    return (j, true)
}

func validtrue(data: Array<Byte>, i: Int64): (Int64, Bool) {
    if (i + 3 <= data.size && data[i] == b'r' && data[i + 1] == b'u' && data[i + 2] == b'e') {
        return (i + 3, true)
    }
    return (i, false)
}

func validfalse(data: Array<Byte>, i: Int64): (Int64, Bool) {
    if (i + 4 <= data.size && data[i] == b'a' && data[i + 1] == b'l' && data[i + 2] == b's' && data[i + 3] == b'e') {
        return (i + 4, true)
    }
    return (i, false)
}

func validnull(data: Array<Byte>, i: Int64): (Int64, Bool) {
    if (i + 3 <= data.size && data[i] == b'u' && data[i + 1] == b'l' && data[i + 2] == b'l') {
        return (i + 3, true)
    }
    return (i, false)
}

public func valid(json: String): Bool {
    let (_, ok) = validpayload(json.toArray(), 0)
    return ok
}

public func validBytes(json: Array<Byte>): Bool {
    let (_, ok) = validpayload(json, 0)
    return ok
}

@Deprecated["use valid() instead"]
public func Valid(json: String): Bool {
    return valid(json)
}

@Deprecated["use validBytes() instead"]
public func ValidBytes(json: Array<Byte>): Bool {
    return validBytes(json)
}


