package sdl

/** One deterministic renderer command captured by a recording headless renderer. */
public class DrawIrCommand {
    public let kind: String
    public let scope: String
    /** Stable JSON object contents without the surrounding braces. */
    public let data: String

    public init(kind: String, scope: String, data!: String = "") {
        this.kind = kind
        this.scope = scope
        this.data = data
    }

    public func toJson(): String {
        let payload = if (data.isEmpty()) { "{}" } else { "{" + data + "}" }
        "{\"kind\":" + drawIrQuote(kind) + ",\"scope\":" + drawIrQuote(scope) +
            ",\"data\":" + payload + "}"
    }
}

internal func drawIrQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}

internal func drawIrRect(rect: Rect): String {
    "\"x\":" + rect.x.toString() + ",\"y\":" + rect.y.toString() +
        ",\"width\":" + rect.w.toString() + ",\"height\":" + rect.h.toString()
}

internal func drawIrColor(color: Color): String {
    "\"color\":{\"r\":" + color.r.toString() + ",\"g\":" + color.g.toString() +
        ",\"b\":" + color.b.toString() + ",\"a\":" + color.a.toString() + "}"
}

internal func drawIrPen(pen: Pen): String {
    "\"width\":" + pen.width.toString() + "," + drawIrColor(pen.color)
}
