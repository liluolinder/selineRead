package chui.native_scene

import std.collection.ArrayList

public let CANGHUI_NATIVE_SCENE_PROTOCOL = "canghui.native-scene.v0"

public struct NativeColor {
    public let r: Int64
    public let g: Int64
    public let b: Int64
    public let a: Int64

    public init(r: Int64, g: Int64, b: Int64, a!: Int64 = 255) {
        this.r = nativeColorChannel(r)
        this.g = nativeColorChannel(g)
        this.b = nativeColorChannel(b)
        this.a = nativeColorChannel(a)
    }

    public static func rgb(r: Int64, g: Int64, b: Int64): NativeColor {
        NativeColor(r, g, b)
    }

    public static func rgba(r: Int64, g: Int64, b: Int64, a: Int64): NativeColor {
        NativeColor(r, g, b, a: a)
    }

    func toJson(): String {
        "{\"r\":" + r.toString() + ",\"g\":" + g.toString() +
            ",\"b\":" + b.toString() + ",\"a\":" + a.toString() + "}"
    }
}

public struct NativeRect {
    public let x: Float32
    public let y: Float32
    public let width: Float32
    public let height: Float32

    public init(x: Float32, y: Float32, width: Float32, height: Float32) {
        this.x = x
        this.y = y
        this.width = max(0.0, width)
        this.height = max(0.0, height)
    }

    public func contains(px: Float32, py: Float32): Bool {
        px >= x && py >= y && px <= x + width && py <= y + height
    }

    func toJsonFields(): String {
        "\"x\":" + x.toString() + ",\"y\":" + y.toString() +
            ",\"width\":" + width.toString() + ",\"height\":" + height.toString()
    }
}

class NativeSceneAction {
    let id: String
    let rect: NativeRect

    init(id: String, rect: NativeRect) {
        this.id = id
        this.rect = rect
    }
}

/**
 * An SDL-free display list for embedded mobile surfaces.
 *
 * Product code owns state and labels. CangHui owns the stable command shape,
 * bounded hit regions and pointer cancellation semantics.
 */
public class NativeScene {
    public let name: String
    public let width: Float32
    public let height: Float32
    private let commands = ArrayList<String>()
    private let actions = ArrayList<NativeSceneAction>()

    public init(name: String, width: Float32, height: Float32, background: NativeColor) {
        if (name.isEmpty()) { throw IllegalArgumentException("native scene name must not be empty") }
        if (width <= 0.0 || height <= 0.0) {
            throw IllegalArgumentException("native scene dimensions must be positive")
        }
        this.name = name
        this.width = width
        this.height = height
        command("scene.begin", "\"width\":" + width.toString() +
            ",\"height\":" + height.toString() + ",\"color\":" + background.toJson())
    }

    public func fill(rect: NativeRect, color: NativeColor): Unit {
        command("paint.fill", rect.toJsonFields() + ",\"color\":" + color.toJson())
    }

    public func fillRounded(rect: NativeRect, radius: Float32, color: NativeColor): Unit {
        command("paint.fill-rounded-rect", rect.toJsonFields() +
            ",\"radius\":" + max(0.0, radius).toString() + ",\"color\":" + color.toJson())
    }

    public func strokeRounded(
        rect: NativeRect,
        radius: Float32,
        color: NativeColor,
        width!: Float32 = 1.0
    ): Unit {
        command("paint.stroke-rounded-rect", rect.toJsonFields() +
            ",\"radius\":" + max(0.0, radius).toString() +
            ",\"strokeWidth\":" + max(0.0, width).toString() +
            ",\"color\":" + color.toJson())
    }

    public func line(
        x1: Float32,
        y1: Float32,
        x2: Float32,
        y2: Float32,
        color: NativeColor,
        width!: Float32 = 1.0
    ): Unit {
        command("paint.line", "\"x1\":" + x1.toString() + ",\"y1\":" + y1.toString() +
            ",\"x2\":" + x2.toString() + ",\"y2\":" + y2.toString() +
            ",\"width\":" + max(0.0, width).toString() + ",\"color\":" + color.toJson())
    }

    public func fillCircle(cx: Float32, cy: Float32, radius: Float32, color: NativeColor): Unit {
        command("paint.fill-circle", "\"cx\":" + cx.toString() + ",\"cy\":" + cy.toString() +
            ",\"radius\":" + max(0.0, radius).toString() + ",\"color\":" + color.toJson())
    }

    public func text(
        value: String,
        x: Float32,
        y: Float32,
        color: NativeColor,
        pointSize!: Float32 = 15.0,
        bold!: Bool = false
    ): Unit {
        command("text", "\"text\":" + nativeSceneQuote(value) +
            ",\"x\":" + x.toString() + ",\"y\":" + y.toString() +
            ",\"pointSize\":" + max(1.0, pointSize).toString() +
            ",\"bold\":" + bold.toString() + ",\"color\":" + color.toJson())
    }

    public func symbol(
        provider: String,
        name: String,
        rect: NativeRect,
        color: NativeColor
    ): Unit {
        command("symbol", rect.toJsonFields() + ",\"provider\":" + nativeSceneQuote(provider) +
            ",\"name\":" + nativeSceneQuote(name) + ",\"color\":" + color.toJson())
    }

    public func pushClip(rect: NativeRect): Unit {
        command("clip.push", rect.toJsonFields())
    }

    public func popClip(): Unit {
        command("clip.pop", "")
    }

    public func panel(
        rect: NativeRect,
        fill: NativeColor,
        edge!: NativeColor = NativeColor.rgba(0, 0, 0, 0),
        radius!: Float32 = 8.0
    ): Unit {
        fillRounded(rect, radius, fill)
        if (edge.a > 0) { strokeRounded(rect, radius, edge) }
    }

    public func button(
        id: String,
        title: String,
        rect: NativeRect,
        fill: NativeColor,
        textColor: NativeColor,
        edge!: NativeColor = NativeColor.rgba(0, 0, 0, 0),
        radius!: Float32 = 7.0
    ): Unit {
        requireActionId(id)
        panel(rect, fill, edge: edge, radius: radius)
        text(title, rect.x + 12.0, rect.y + max(6.0, (rect.height - 16.0) / 2.0), textColor,
            pointSize: 15.0, bold: true)
        actions.add(NativeSceneAction(id, rect))
    }

    public func progress(
        rect: NativeRect,
        value: Float32,
        track: NativeColor,
        fill: NativeColor,
        labelColor: NativeColor
    ): Unit {
        let amount = nativeSceneClamp(value, 0.0, 1.0)
        fillRounded(rect, rect.height / 2.0, track)
        fillRounded(NativeRect(rect.x, rect.y, rect.width * amount, rect.height),
            rect.height / 2.0, fill)
        text("${Int64(amount * 100.0)}%", rect.x + rect.width / 2.0 - 15.0,
            rect.y + max(1.0, (rect.height - 13.0) / 2.0), labelColor,
            pointSize: 12.0, bold: true)
    }

    public func actionAt(x: Float32, y: Float32): ?String {
        var index: Int64 = actions.size - 1
        while (index >= 0) {
            let action = actions[index]
            if (action.rect.contains(x, y)) { return Some(action.id) }
            index -= 1
        }
        None
    }

    public func actionContains(id: String, x: Float32, y: Float32): Bool {
        for (action in actions) {
            if (action.id == id) { return action.rect.contains(x, y) }
        }
        false
    }

    public func report(inputCount!: Int64 = 0, selectedAction!: String = ""): String {
        let out = StringBuilder()
        out.append("{\"protocol\":")
        out.append(nativeSceneQuote(CANGHUI_NATIVE_SCENE_PROTOCOL))
        out.append(",\"name\":")
        out.append(nativeSceneQuote(name))
        out.append(",\"ok\":true,\"frames\":[{\"width\":")
        out.append(width.toString())
        out.append(",\"height\":")
        out.append(height.toString())
        out.append(",\"inputCount\":")
        out.append(inputCount.toString())
        out.append(",\"selectedAction\":")
        out.append(nativeSceneQuote(selectedAction))
        out.append(",\"drawIr\":[")
        appendJoined(out, commands)
        out.append("],\"actions\":[")
        var index: Int64 = 0
        while (index < actions.size) {
            if (index > 0) { out.append(",") }
            let action = actions[index]
            out.append("{\"id\":")
            out.append(nativeSceneQuote(action.id))
            out.append(",")
            out.append(action.rect.toJsonFields())
            out.append("}")
            index += 1
        }
        out.append("]}]}")
        out.toString()
    }

    private func command(kind: String, data: String): Unit {
        commands.add("{\"kind\":" + nativeSceneQuote(kind) + ",\"scope\":" +
            nativeSceneQuote(name) + ",\"data\":{" + data + "}}")
    }
}

/** Stateful pointer gate shared by native-scene consumers across frame rebuilds. */
public class NativeScenePointer {
    private var pressed: ?String = None
    private var cancelled = false

    public func dispatch(
        scene: NativeScene,
        eventKind: Int64,
        x: Float32,
        y: Float32
    ): ?String {
        match (eventKind) {
            case 1 =>
                pressed = scene.actionAt(x, y)
                cancelled = false
                None
            case 2 =>
                match (pressed) {
                    case Some(id) => if (!scene.actionContains(id, x, y)) { cancelled = true }
                    case None => ()
                }
                None
            case 3 => release(scene, x, y)
            case 4 =>
                clear()
                None
            case 5 =>
                pressed = scene.actionAt(x, y)
                cancelled = false
                release(scene, x, y)
            case _ => None
        }
    }

    public func isPressed(id: String): Bool {
        match (pressed) {
            case Some(value) => value == id && !cancelled
            case None => false
        }
    }

    private func release(scene: NativeScene, x: Float32, y: Float32): ?String {
        let result: ?String = match (pressed) {
            case Some(id) => if (!cancelled && scene.actionContains(id, x, y)) { Some(id) } else { None }
            case None => None
        }
        clear()
        result
    }

    private func clear(): Unit {
        pressed = None
        cancelled = false
    }
}

/** Copies a UTF-8 string into a caller-owned C buffer using a two-pass size contract. */
public func copyNativeSceneUtf8ToCaller(
    value: String,
    output: CPointer<UInt8>,
    outputCapacity: Int64,
    outputLength: CPointer<Int64>
): Int32 {
    unsafe {
        if (outputCapacity < 0 || outputLength.isNull()) { return -1 }
        let bytes = value.toArray()
        let required = Int64(bytes.size)
        outputLength.write(required)
        if (output.isNull() || outputCapacity < required) { return -2 }
        for (i in 0..bytes.size) { output.write(i, UInt8(bytes[i])) }
        0
    }
}

private func appendJoined(out: StringBuilder, values: ArrayList<String>): Unit {
    var index: Int64 = 0
    while (index < values.size) {
        if (index > 0) { out.append(",") }
        out.append(values[index])
        index += 1
    }
}

private func nativeSceneQuote(value: String): String {
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

private func nativeColorChannel(value: Int64): Int64 {
    max(0, min(255, value))
}

private func nativeSceneClamp(value: Float32, lower: Float32, upper: Float32): Float32 {
    max(lower, min(upper, value))
}

private func requireActionId(id: String): Unit {
    if (id.isEmpty()) { throw IllegalArgumentException("native scene action id must not be empty") }
}
