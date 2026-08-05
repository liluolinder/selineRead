package gjson

func tonum(json: String): (String, Float64) {
    var i = 1
    while (i < json.size) {
        if (isWhitespaceOrControl(json[i]) || json[i] == b',' || json[i] == b']' || json[i] == b'}') {
            let raw = json[..i]
            match (Float64.tryParse(raw)) {
                case Some(num) => return (raw, num)
                case None => return (raw, 0.0)
            }
        }
        i++
    }
    match (Float64.tryParse(json)) {
        case Some(num) => return (json, num)
        case None => return (json, 0.0)
    }
}

func safeInt(f: Float64): ?Int64 {
    if (f < -9007199254740991.0 || f > 9007199254740991.0) {
        return None
    }
    Some(Int64(f))
}

