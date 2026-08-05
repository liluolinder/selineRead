package gjson

import std.time.DateTime

// Result 类型扩展方法
extend Result {
    public func string(): String {
        match (this.kind) {
            case Null => "false"
            case Number =>
                if (this.raw.size == 0) {
                    "${this.num}"
                } else {
                    var i = 0
                    if (this.raw[0] == b'-') {
                        i++
                    }
                    for (ii in i..this.raw.size) {
                        let r = this.raw[ii]
                        if (r < b'0' || r > b'9') {
                            return "${this.num}"
                        }
                    }
                    this.raw
                }
            case String => this.str
            case JSON => this.raw
            case True => "true"
            case False => "false"
        }
    }

    public func bool(): Bool {
        match (this.kind) {
            case True => true
            case String => Bool.tryParse(this.str.toAsciiLower()) ?? false
            case Number => this.num != 0.0
            case _ => false
        }
    }

    public func int(): Int64 {
        match (this.kind) {
            case True => 1
            case String => Int64.tryParse(this.str) ?? 0
            case Number =>
                if (let Some(v) <- safeInt(this.num)) {
                    return v
                }
                if (let Some(v) <- Int64.tryParse(this.raw)) {
                    return v
                }
                Int64(this.num)
            case _ => 0
        }
    }

    public func uint(): UInt64 {
        match (this.kind) {
            case True => 1
            case String => UInt64.tryParse(this.str) ?? 0
            case Number =>
                if (let Some(v) <- safeInt(this.num)) {
                    return UInt64(v)
                }
                if (let Some(v) <- Int64.tryParse(this.raw)) {
                    return UInt64(v)
                }
                UInt64(this.num)
            case _ => 0
        }
    }

    public func float(): Float64 {
        match (this.kind) {
            case True => 1.0
            case String => Float64.tryParse(this.str) ?? 0.0
            case Number => this.num
            case _ => 0.0
        }
    }

    public func time(): DateTime {
        DateTime.parse(this.string())
    }

    @Deprecated["use time() instead"]
    public func Time(): DateTime {
        return this.time()
    }
    
    // Result类型的函数式操作扩展
    public func mapString(mapper: Mapper<String, String>): Result {
        createStringResult(this.raw, mapper(this.str))
    }
    
    public func mapNumber(mapper: Mapper<Float64, Float64>): Result {
        createNumberResult(this.raw, mapper(this.num))
    }
}
