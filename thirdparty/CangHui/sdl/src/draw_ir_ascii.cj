package sdl

import std.collection.ArrayList
import std.convert.*

/** Bounded terminal projection dimensions for one recording-headless Draw IR frame. */
public struct DrawIrAsciiOptions {
    public let columns: Int64
    public let rows: Int64

    public init(columns!: Int64 = 96, rows!: Int64 = 32) {
        if (columns < 20 || columns > 240) {
            throw IllegalArgumentException("Draw IR ASCII columns must be between 20 and 240")
        }
        if (rows < 8 || rows > 100) {
            throw IllegalArgumentException("Draw IR ASCII rows must be between 8 and 100")
        }
        this.columns = columns
        this.rows = rows
    }
}

/** Semantic marker families layered over the structural Draw IR projection. */
public enum DrawIrAsciiAnnotationKind {
    | Interactive
    | Focus
    | Visual
}

public func drawIrAsciiAnnotationKindName(kind: DrawIrAsciiAnnotationKind): String {
    match (kind) {
        case DrawIrAsciiAnnotationKind.Interactive => "interactive"
        case DrawIrAsciiAnnotationKind.Focus => "focus"
        case DrawIrAsciiAnnotationKind.Visual => "visual"
    }
}

/** One agent-readable component or semantic subregion in logical viewport coordinates. */
public class DrawIrAsciiAnnotation {
    public let id: String
    public let kind: DrawIrAsciiAnnotationKind
    public let rect: Rect
    public let component: String
    public let role: String
    public let label: String
    public let icon: String
    public let action: String
    public let shortcut: String
    public let value: String
    public let state: String

    public init(
        id: String,
        kind: DrawIrAsciiAnnotationKind,
        rect: Rect,
        component!: String = "",
        role!: String = "",
        label!: String = "",
        icon!: String = "",
        action!: String = "",
        shortcut!: String = "",
        value!: String = "",
        state!: String = ""
    ) {
        if (id.isEmpty()) { throw IllegalArgumentException("Draw IR ASCII annotation id must not be empty") }
        this.id = id
        this.kind = kind
        this.rect = rect
        this.component = component
        this.role = role
        this.label = label
        this.icon = icon
        this.action = action
        this.shortcut = shortcut
        this.value = value
        this.state = state
    }
}

/**
 * Projects renderer commands into deterministic terminal cells. This is structural
 * evidence only: it does not model rasterization, antialiasing, shaping, or pixels.
 */
public func renderDrawIrAscii(
    commands: Array<DrawIrCommand>,
    logicalWidth: Float32,
    logicalHeight: Float32,
    options!: DrawIrAsciiOptions = DrawIrAsciiOptions(),
    annotations!: Array<DrawIrAsciiAnnotation> = []
): String {
    if (logicalWidth <= 0.0 || logicalHeight <= 0.0) {
        throw IllegalArgumentException("Draw IR ASCII viewport must be positive")
    }
    let canvas = DrawIrAsciiCanvas(logicalWidth, logicalHeight, options)
    for (command in commands) { canvas.apply(command) }
    let legend = canvas.annotate(annotations)
    canvas.render(commands.size, legend)
}

private struct DrawIrAsciiRect {
    let left: Int64
    let top: Int64
    let right: Int64
    let bottom: Int64

    init(left: Int64, top: Int64, right: Int64, bottom: Int64) {
        this.left = left
        this.top = top
        this.right = right
        this.bottom = bottom
    }

    func intersect(other: DrawIrAsciiRect): DrawIrAsciiRect {
        DrawIrAsciiRect(
            max(left, other.left),
            max(top, other.top),
            min(right, other.right),
            min(bottom, other.bottom)
        )
    }

    func contains(x: Int64, y: Int64): Bool {
        x >= left && x <= right && y >= top && y <= bottom
    }
}

private class DrawIrAsciiCanvas {
    let logicalWidth: Float32
    let logicalHeight: Float32
    let options: DrawIrAsciiOptions
    let cells = ArrayList<Array<Rune>>()
    let clips = ArrayList<DrawIrAsciiRect>()
    let markerCells = ArrayList<Array<Bool>>()

    init(logicalWidth: Float32, logicalHeight: Float32, options: DrawIrAsciiOptions) {
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.options = options
        var row: Int64 = 0
        while (row < options.rows) {
            cells.add(Array<Rune>(options.columns, repeat: r' '))
            markerCells.add(Array<Bool>(options.columns, repeat: false))
            row += 1
        }
    }

    func apply(command: DrawIrCommand): Unit {
        let kind = command.kind
        if (kind == "clip.push") {
            let rect = commandRect(command.data)
            clips.add(match (activeClip()) {
                case Some(parent) => parent.intersect(rect)
                case None => rect
            })
        } else if (kind == "clip.pop") {
            if (!clips.isEmpty()) { clips.remove(at: clips.size - 1) }
        } else if (kind == "paint.fill" || kind == "paint.fill-rounded-rect" ||
            kind == "paint.fill-rounded-gradient" || kind == "paint.fill-per-corner-rounded-rect" ||
            kind == "paint.fill-rounded-soft") {
            fillRect(commandRect(command.data), fillRune(command.data))
        } else if (kind == "paint.rect" || kind == "paint.stroke-rounded-rect" ||
            kind == "paint.stroke-rounded-rect-dashed") {
            strokeRect(commandRect(command.data))
        } else if (kind == "paint.line" || kind == "paint.stroke-line") {
            drawLine(
                column(number(command.data, "x1", 0.0)),
                row(number(command.data, "y1", 0.0)),
                column(number(command.data, "x2", 0.0)),
                row(number(command.data, "y2", 0.0)),
                lineRune(command.data)
            )
        } else if (kind == "paint.point") {
            put(column(number(command.data, "x", 0.0)), row(number(command.data, "y", 0.0)), r'.')
        } else if (kind == "paint.circle" || kind == "paint.stroke-circle" ||
            kind == "paint.fill-circle") {
            drawCircle(command.data, kind == "paint.fill-circle")
        } else if (kind == "paint.ripple") {
            fillRect(commandRect(command.data), r'~')
        } else if (kind == "paint.textured-circle") {
            drawCircle(command.data, true)
        } else if (kind == "text") {
            drawText(command.data)
        } else if (kind == "symbol") {
            drawSymbol(command.data)
        }
    }

    func annotate(annotations: Array<DrawIrAsciiAnnotation>): Array<DrawIrAsciiLegendEntry> {
        let entries = ArrayList<DrawIrAsciiLegendEntry>()
        var interactive: Int64 = 0
        var focus: Int64 = 0
        var visual: Int64 = 0
        for (annotation in annotations) {
            var ordinal: Int64 = 0
            let token = match (annotation.kind) {
                case DrawIrAsciiAnnotationKind.Interactive =>
                    interactive += 1
                    ordinal = interactive
                    "$i${interactive}"
                case DrawIrAsciiAnnotationKind.Focus =>
                    focus += 1
                    ordinal = focus
                    "$f${focus}"
                case DrawIrAsciiAnnotationKind.Visual =>
                    visual += 1
                    ordinal = visual
                    "$v${visual}"
            }
            let marker = annotationMarker(annotation.kind, token)
            let rect = annotationRect(annotation.rect)
            var placed = placeMarker(rect, marker)
            if (!placed) { placed = placeMarker(rect, compactAnnotationMarker(annotation.kind, ordinal)) }
            if (!placed) { placed = placeMarker(rect, token) }
            entries.add(DrawIrAsciiLegendEntry(annotation, token, placed))
        }
        entries.toArray()
    }

    func render(commandCount: Int64, legend: Array<DrawIrAsciiLegendEntry>): String {
        let out = StringBuilder()
        out.append("CangHui headless Draw IR ")
        out.append(logicalWidth)
        out.append("x")
        out.append(logicalHeight)
        out.append(" -> ")
        out.append(options.columns)
        out.append("x")
        out.append(options.rows)
        out.append(" (")
        out.append(commandCount)
        out.append(" commands)\n+")
        appendRepeated(out, r'-', options.columns)
        out.append("+\n")
        for (line in cells) {
            out.append("|")
            for (cell in line) { out.append(cell.toString()) }
            out.append("|\n")
        }
        out.append("+")
        appendRepeated(out, r'-', options.columns)
        out.append("+\nLegend: # solid  = bright  : translucent  . faint  o circle  - line  ~ ripple")
        if (!legend.isEmpty()) {
            out.append("\nSemantic map: [$iN] action  <$fN> focus/input  ($vN) visual")
            out.append("\nCompact markers: [$N] action  <$N> focus/input  ($N) visual\n")
            var first = true
            for (entry in legend) {
                if (!first) { out.append("\n") }
                first = false
                appendSemanticLegend(out, entry)
            }
        }
        out.toString()
    }

    private func annotationRect(rect: Rect): DrawIrAsciiRect {
        DrawIrAsciiRect(column(rect.x), row(rect.y), column(rect.right()), row(rect.bottom()))
    }

    private func placeMarker(rect: DrawIrAsciiRect, marker: String): Bool {
        let runes = marker.toRuneArray()
        if (runes.isEmpty()) { return false }
        let bounded = rect.intersect(DrawIrAsciiRect(0, 0, options.columns - 1, options.rows - 1))
        if (bounded.right < bounded.left || bounded.bottom < bounded.top ||
            bounded.right - bounded.left + 1 < runes.size) {
            return false
        }
        let preferredY = (bounded.top + bounded.bottom) / 2
        if (placeMarkerOnRow(bounded, preferredY, runes)) { return true }
        var y = bounded.top
        while (y <= bounded.bottom) {
            if (y != preferredY && placeMarkerOnRow(bounded, y, runes)) { return true }
            y += 1
        }
        false
    }

    private func placeMarkerOnRow(rect: DrawIrAsciiRect, y: Int64, runes: Array<Rune>): Bool {
        var x = rect.left
        while (x + runes.size - 1 <= rect.right) {
            var available = true
            var i: Int64 = 0
            while (i < runes.size) {
                if (markerCells[y][x + i]) { available = false; break }
                i += 1
            }
            if (available) {
                i = 0
                while (i < runes.size) {
                    cells[y][x + i] = runes[i]
                    markerCells[y][x + i] = true
                    i += 1
                }
                return true
            }
            x += 1
        }
        false
    }

    private func activeClip(): ?DrawIrAsciiRect {
        if (clips.isEmpty()) { None } else { Some(clips[clips.size - 1]) }
    }

    private func put(x: Int64, y: Int64, value: Rune): Unit {
        if (x < 0 || x >= options.columns || y < 0 || y >= options.rows) { return }
        match (activeClip()) {
            case Some(clip) => if (!clip.contains(x, y)) { return }
            case None => ()
        }
        cells[y][x] = value
    }

    private func fillRect(rect: DrawIrAsciiRect, value: Rune): Unit {
        let bounded = rect.intersect(DrawIrAsciiRect(0, 0, options.columns - 1, options.rows - 1))
        var y = bounded.top
        while (y <= bounded.bottom) {
            var x = bounded.left
            while (x <= bounded.right) { put(x, y, value); x += 1 }
            y += 1
        }
    }

    private func strokeRect(rect: DrawIrAsciiRect): Unit {
        if (rect.right < rect.left || rect.bottom < rect.top) { return }
        var x = rect.left
        while (x <= rect.right) {
            put(x, rect.top, if (x == rect.left || x == rect.right) {r'+'} else {r'-'})
            put(x, rect.bottom, if (x == rect.left || x == rect.right) {r'+'} else {r'-'})
            x += 1
        }
        var y = rect.top + 1
        while (y < rect.bottom) { put(rect.left, y, r'|'); put(rect.right, y, r'|'); y += 1 }
    }

    private func drawLine(x1: Int64, y1: Int64, x2: Int64, y2: Int64, value: Rune): Unit {
        let dx = x2 - x1
        let dy = y2 - y1
        let steps = max(absInt(dx), absInt(dy))
        if (steps == 0) { put(x1, y1, value); return }
        var i: Int64 = 0
        while (i <= steps) {
            let progress = Float32(i) / Float32(steps)
            let x = x1 + Int64(Float32(dx) * progress)
            let y = y1 + Int64(Float32(dy) * progress)
            put(x, y, value)
            i += 1
        }
    }

    private func drawCircle(data: String, filled: Bool): Unit {
        let cx = column(number(data, "cx", 0.0))
        let cy = row(number(data, "cy", 0.0))
        let rx = max(Int64(1), columnDistance(number(data, "radius", 1.0)))
        let ry = max(Int64(1), rowDistance(number(data, "radius", 1.0)))
        var y = cy - ry
        while (y <= cy + ry) {
            var x = cx - rx
            while (x <= cx + rx) {
                let nx = Float32(x - cx) / Float32(rx)
                let ny = Float32(y - cy) / Float32(ry)
                let distance = nx * nx + ny * ny
                if ((filled && distance <= 1.0) || (!filled && distance >= 0.58 && distance <= 1.35)) {
                    put(x, y, if (filled) {r'@'} else {r'o'})
                }
                x += 1
            }
            y += 1
        }
    }

    private func drawText(data: String): Unit {
        let value = stringField(data, "text")
        var x = column(number(data, "x", 0.0))
        let y = row(number(data, "y", 0.0))
        for (r in value.toRuneArray()) {
            if (x >= options.columns) { break }
            let safe = if (UInt32(r) >= UInt32(32) && UInt32(r) <= UInt32(126)) {r} else {r'?'}
            put(x, y, safe)
            x += 1
        }
    }

    private func drawSymbol(data: String): Unit {
        let rect = commandRect(data)
        let name = stringField(data, "name")
        let label = if (name.isEmpty()) {"symbol"} else {name}
        var x = rect.left
        let y = (rect.top + rect.bottom) / 2
        put(x, y, r'[')
        x += 1
        for (r in label.toRuneArray()) {
            if (x >= rect.right) { break }
            put(x, y, if (UInt32(r) <= UInt32(126)) {r} else {r'?'})
            x += 1
        }
        put(min(x, rect.right), y, r']')
    }

    private func commandRect(data: String): DrawIrAsciiRect {
        let x = number(data, "x", 0.0)
        let y = number(data, "y", 0.0)
        let width = number(data, "width", 0.0)
        let height = number(data, "height", 0.0)
        DrawIrAsciiRect(column(x), row(y), column(x + width), row(y + height))
    }

    private func column(value: Float32): Int64 {
        boundedCell(value, logicalWidth, options.columns)
    }

    private func row(value: Float32): Int64 {
        boundedCell(value, logicalHeight, options.rows)
    }

    private func columnDistance(value: Float32): Int64 {
        max(Int64(1), Int64(value / logicalWidth * Float32(options.columns)))
    }

    private func rowDistance(value: Float32): Int64 {
        max(Int64(1), Int64(value / logicalHeight * Float32(options.rows)))
    }
}

private class DrawIrAsciiLegendEntry {
    let annotation: DrawIrAsciiAnnotation
    let token: String
    let placed: Bool

    init(annotation: DrawIrAsciiAnnotation, token: String, placed: Bool) {
        this.annotation = annotation
        this.token = token
        this.placed = placed
    }
}

private func annotationMarker(kind: DrawIrAsciiAnnotationKind, token: String): String {
    match (kind) {
        case DrawIrAsciiAnnotationKind.Interactive => "[${token}]"
        case DrawIrAsciiAnnotationKind.Focus => "<${token}>"
        case DrawIrAsciiAnnotationKind.Visual => "(${token})"
    }
}

private func compactAnnotationMarker(kind: DrawIrAsciiAnnotationKind, ordinal: Int64): String {
    match (kind) {
        case DrawIrAsciiAnnotationKind.Interactive => "[$${ordinal}]"
        case DrawIrAsciiAnnotationKind.Focus => "<$${ordinal}>"
        case DrawIrAsciiAnnotationKind.Visual => "($${ordinal})"
    }
}

private func appendSemanticLegend(out: StringBuilder, entry: DrawIrAsciiLegendEntry): Unit {
    let annotation = entry.annotation
    out.append(entry.token)
    out.append(" - ")
    let identity = if (annotation.component.isEmpty()) {annotation.id}
        else {annotation.component + "#" + annotation.id}
    out.append(legendQuote(identity))
    appendLegendField(out, "role", annotation.role)
    appendLegendField(out, "icon", annotation.icon)
    appendLegendField(out, "label", annotation.label)
    appendLegendField(out, "action", annotation.action)
    appendLegendField(out, "shortcut", annotation.shortcut)
    appendLegendField(out, "value", annotation.value)
    appendLegendField(out, "state", annotation.state)
    out.append(" | rect=(")
    out.append(compactNumber(annotation.rect.x))
    out.append(",")
    out.append(compactNumber(annotation.rect.y))
    out.append(",")
    out.append(compactNumber(annotation.rect.w))
    out.append(",")
    out.append(compactNumber(annotation.rect.h))
    out.append(")")
    if (!entry.placed) { out.append(" | marker=legend-only") }
    match (annotation.kind) {
        case DrawIrAsciiAnnotationKind.Interactive =>
            let x = Int64(annotation.rect.centerX())
            let y = Int64(annotation.rect.centerY())
            appendLegendField(out, "probe", "press ${x} ${y}; release ${x} ${y}")
        case DrawIrAsciiAnnotationKind.Focus => appendLegendField(out, "probe", "focus " + annotation.id)
        case DrawIrAsciiAnnotationKind.Visual => ()
    }
}

private func appendLegendField(out: StringBuilder, name: String, value: String): Unit {
    if (value.isEmpty()) { return }
    out.append(" | ")
    out.append(name)
    out.append("=")
    out.append(legendQuote(value))
}

private func legendQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else if (UInt32(r) < UInt32(32)) { out.append("?") }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}

private func compactNumber(value: Float32): String {
    let integer = Int64(value)
    if (Float32(integer) == value) {integer.toString()} else {value.toString()}
}

private func boundedCell(value: Float32, extent: Float32, cells: Int64): Int64 {
    min(cells - 1, max(Int64(0), Int64(value / extent * Float32(cells))))
}

private func fillRune(data: String): Rune {
    let alpha = number(data, "a", 255.0)
    if (alpha < 64.0) { return r'.' }
    if (alpha < 180.0) { return r':' }
    let luminance = number(data, "r", 0.0) * 0.21 + number(data, "g", 0.0) * 0.72 +
        number(data, "b", 0.0) * 0.07
    if (luminance > 190.0) {r'='} else {r'#'}
}

private func lineRune(data: String): Rune {
    let x1 = number(data, "x1", 0.0)
    let y1 = number(data, "y1", 0.0)
    let x2 = number(data, "x2", 0.0)
    let y2 = number(data, "y2", 0.0)
    if (absFloat(y2 - y1) < absFloat(x2 - x1) * 0.35) {r'-'}
    else if (absFloat(x2 - x1) < absFloat(y2 - y1) * 0.35) {r'|'}
    else if ((x2 - x1) * (y2 - y1) >= 0.0) {r'\\'}
    else {r'/'}
}

private func number(data: String, key: String, fallback: Float32): Float32 {
    let source = data.toRuneArray()
    var index = fieldStart(source, key)
    if (index < 0) { return fallback }
    while (index < source.size && (source[index] == r' ' || source[index] == r'\t')) { index += 1 }
    let out = StringBuilder()
    while (index < source.size) {
        let r = source[index]
        let allowed = (r >= r'0' && r <= r'9') || r == r'-' || r == r'+' || r == r'.' ||
            r == r'e' || r == r'E'
        if (!allowed) { break }
        out.append(r.toString())
        index += 1
    }
    if (out.toString().isEmpty()) { return fallback }
    try { Float32.parse(out.toString()) } catch (_: Exception) { fallback }
}

private func stringField(data: String, key: String): String {
    let source = data.toRuneArray()
    var index = fieldStart(source, key)
    if (index < 0) { return "" }
    while (index < source.size && (source[index] == r' ' || source[index] == r'\t')) { index += 1 }
    if (index >= source.size || source[index] != r'\"') { return "" }
    index += 1
    let out = StringBuilder()
    while (index < source.size) {
        let r = source[index]
        if (r == r'\"') { break }
        if (r == r'\\' && index + 1 < source.size) {
            index += 1
            let escaped = source[index]
            if (escaped == r'n') { out.append("\n") }
            else if (escaped == r'r') { out.append("\r") }
            else if (escaped == r't') { out.append("\t") }
            else { out.append(escaped.toString()) }
        } else {
            out.append(r.toString())
        }
        index += 1
    }
    out.toString()
}

private func fieldStart(source: Array<Rune>, key: String): Int64 {
    let target = ("\"" + key + "\":").toRuneArray()
    if (target.size > source.size) { return -1 }
    var i: Int64 = 0
    while (i <= source.size - target.size) {
        var same = true
        var j: Int64 = 0
        while (j < target.size) {
            if (source[i + j] != target[j]) { same = false; break }
            j += 1
        }
        if (same) { return i + target.size }
        i += 1
    }
    -1
}

private func appendRepeated(out: StringBuilder, value: Rune, count: Int64): Unit {
    var i: Int64 = 0
    while (i < count) { out.append(value.toString()); i += 1 }
}

private func absInt(value: Int64): Int64 { if (value < 0) {-value} else {value} }
private func absFloat(value: Float32): Float32 { if (value < 0.0) {-value} else {value} }
