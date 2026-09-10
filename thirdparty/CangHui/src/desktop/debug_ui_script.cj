package chui.desktop

@When[debug]
import std.collection.ArrayList
@When[debug]
import std.convert.*
@When[debug]
import sdl.{Key, MouseButton}
import sdl.UiEvent
import chui.core.{UiContext, Widget}
@When[debug]
import std.env.getVariable
@When[debug]
import chui.kmode.decodeKModeText

@When[debug]
private let DEBUG_UI_SCRIPT_LIMIT: Int64 = 128
@When[debug]
private let DEBUG_UI_SCRIPT_BYTES: Int64 = 65536

/** A one-shot, compiler-debug-only UI automation script. It never opens a listener. */
@When[debug]
class DebugUiScriptRunner {
    private let commands: Array<String>
    private var index: Int64 = 0
    private var finishing = false
    private var completed = false
    private var revision: UInt64 = 0
    private var previous: ?DebugUiObservation = None
    private var current: ?DebugUiObservation = None

    init() {
        commands = parseDebugUiScript(debugUiScriptText())
    }

    func active(): Bool {
        !commands.isEmpty() && !completed
    }

    func observe(widget: Widget, ctx: UiContext, width: Int32, height: Int32): Unit {
        if (!active()) { return }
        revision += 1
        previous = current
        current = Some(DebugUiObservation(
            revision,
            width,
            height,
            ctx.focusId,
            widget.focusableIds(),
            widget.interactionOwnerIds()
        ))
    }

    /** Runs at most one whitelisted command per rendered frame. */
    func executeNext(ctx: UiContext, dispatch: (UiEvent) -> Unit): Unit {
        if (!active() || current.isNone()) { return }
        if (finishing) {
            emitDebugUiResult("complete", true, current.getOrThrow().snapshotJson(), 0, "")
            completed = true
            ctx.requestClose()
            return
        }

        let line = commands[index]
        index += 1
        try {
            executeDebugUiCommand(line, ctx, dispatch)
        } catch (error: Exception) {
            emitDebugUiResult("command-error", false, "", 2, error.message)
            index = commands.size
        }
        if (index >= commands.size) {
            finishing = true
        }
        ctx.requestFrame()
    }

    private func executeDebugUiCommand(line: String, ctx: UiContext, dispatch: (UiEvent) -> Unit): Unit {
        let parts = line.split(" ")
        if (parts.isEmpty()) { return }
        let operation = parts[0]
        if (operation == "click" || operation == "touch") {
            requireDebugUiArity(parts, 3, operation)
            let x = Float32.parse(parts[1])
            let y = Float32.parse(parts[2])
            dispatch(UiEvent.MouseDown(MouseButton.Left, x, y))
            dispatch(UiEvent.MouseUp(MouseButton.Left, x, y))
            emitDebugUiResult(operation, true, "", 0, "")
            return
        }
        if (operation == "down" || operation == "press" || operation == "move" ||
            operation == "up" || operation == "release") {
            requireDebugUiArity(parts, 3, operation)
            let x = Float32.parse(parts[1])
            let y = Float32.parse(parts[2])
            if (operation == "down" || operation == "press") {
                dispatch(UiEvent.MouseDown(MouseButton.Left, x, y))
            } else if (operation == "move") {
                dispatch(UiEvent.MouseMove(x, y))
            } else {
                dispatch(UiEvent.MouseUp(MouseButton.Left, x, y))
            }
            emitDebugUiResult(operation, true, "", 0, "")
            return
        }
        if (operation == "focus") {
            requireDebugUiArity(parts, 2, operation)
            let id = parts[1]
            let observation = current.getOrThrow()
            if (!containsDebugUiId(observation.focusableIds, id)) {
                throw IllegalArgumentException("focus target is not in the current focus ring: ${id}")
            }
            ctx.focus(id, viaKeyboard: true)
            emitDebugUiResult(operation, true, debugUiJsonQuote(id), 0, "")
            return
        }
        if (operation == "key") {
            requireDebugUiArity(parts, 2, operation)
            let key = parseDebugUiKey(parts[1])
            dispatch(UiEvent.KeyDown(key, false))
            dispatch(UiEvent.KeyUp(key))
            emitDebugUiResult(operation, true, "", 0, "")
            return
        }
        if (operation == "text") {
            let payload = debugUiCommandRemainder(line)
            if (payload.isEmpty()) { throw IllegalArgumentException("text requires a non-empty value") }
            dispatch(UiEvent.TextInput(payload))
            emitDebugUiResult(operation, true, "", 0, "")
            return
        }
        if (operation == "snapshot") {
            requireDebugUiArity(parts, 1, operation)
            emitDebugUiResult(operation, true, current.getOrThrow().snapshotJson(), 0, "")
            return
        }
        if (operation == "diff") {
            requireDebugUiArity(parts, 1, operation)
            let payload = match (previous) {
                case Some(value) => current.getOrThrow().diffJson(value)
                case None => "{\"changed\":false,\"reason\":\"first-observation\"}"
            }
            emitDebugUiResult(operation, true, payload, 0, "")
            return
        }
        throw IllegalArgumentException("unsupported debug UI command: ${operation}")
    }
}

@When[debug]
class DebugUiObservation {
    let revision: UInt64
    let width: Int32
    let height: Int32
    let focusId: String
    let focusableIds: Array<String>
    let interactionIds: Array<String>

    init(revision: UInt64, width: Int32, height: Int32, focusId: String,
        focusableIds: Array<String>, interactionIds: Array<String>) {
        this.revision = revision
        this.width = width
        this.height = height
        this.focusId = focusId
        this.focusableIds = focusableIds
        this.interactionIds = interactionIds
    }

    func snapshotJson(): String {
        "{\"protocol\":\"canghui.ui-observation.v0\",\"revision\":${revision}," +
            "\"viewport\":{\"width\":${width},\"height\":${height}}," +
            "\"focus\":" + debugUiJsonQuote(focusId) + "," +
            "\"focusable\":" + debugUiJsonArray(focusableIds) + "," +
            "\"interactive\":" + debugUiJsonArray(interactionIds) + "}"
    }

    func diffJson(before: DebugUiObservation): String {
        let focusAdded = debugUiDifference(focusableIds, before.focusableIds)
        let focusRemoved = debugUiDifference(before.focusableIds, focusableIds)
        let interactionAdded = debugUiDifference(interactionIds, before.interactionIds)
        let interactionRemoved = debugUiDifference(before.interactionIds, interactionIds)
        let changed = focusId != before.focusId || width != before.width || height != before.height ||
            !focusAdded.isEmpty() || !focusRemoved.isEmpty() ||
            !interactionAdded.isEmpty() || !interactionRemoved.isEmpty()
        "{\"protocol\":\"canghui.ui-diff.v0\",\"from\":${before.revision},\"to\":${revision}," +
            "\"changed\":${changed},\"focus\":{\"from\":" + debugUiJsonQuote(before.focusId) +
            ",\"to\":" + debugUiJsonQuote(focusId) + "}," +
            "\"focusable\":{\"added\":" + debugUiJsonArray(focusAdded) +
            ",\"removed\":" + debugUiJsonArray(focusRemoved) + "}," +
            "\"interactive\":{\"added\":" + debugUiJsonArray(interactionAdded) +
            ",\"removed\":" + debugUiJsonArray(interactionRemoved) + "}}"
    }
}

@When[debug]
func debugUiScriptText(): String {
    match (getVariable("CANGHUI_DEBUG_UI_SCRIPT_HEX")) {
        case Some(value) where value.size > 0 => decodeKModeText(value)
        case _ => ""
    }
}

@When[debug]
func parseDebugUiScript(script: String): Array<String> {
    if (script.toArray().size > DEBUG_UI_SCRIPT_BYTES) {
        throw IllegalArgumentException("debug UI script exceeds 64 KiB")
    }
    let commands = ArrayList<String>()
    for (line in script.split("\n")) {
        let value = line.trimAscii()
        if (!value.isEmpty()) {
            commands.add(value)
            if (commands.size > DEBUG_UI_SCRIPT_LIMIT) {
                throw IllegalArgumentException("debug UI script exceeds 128 commands")
            }
        }
    }
    commands.toArray()
}

@When[debug]
func requireDebugUiArity(parts: Array<String>, expected: Int64, operation: String): Unit {
    if (parts.size != expected) {
        throw IllegalArgumentException("${operation} has invalid argument count")
    }
}

@When[debug]
func parseDebugUiKey(value: String): Key {
    if (value == "escape") { return Key.Escape }
    if (value == "backspace") { return Key.Backspace }
    if (value == "enter") { return Key.Enter }
    if (value == "tab") { return Key.Tab }
    if (value == "delete") { return Key.Delete }
    if (value == "space") { return Key.Space }
    if (value == "home") { return Key.Home }
    if (value == "end") { return Key.End }
    if (value == "left") { return Key.Left }
    if (value == "right") { return Key.Right }
    if (value == "up") { return Key.Up }
    if (value == "down") { return Key.Down }
    let bytes = value.toArray()
    if (bytes.size == 1 && ((bytes[0] >= UInt8(65) && bytes[0] <= UInt8(90)) ||
        (bytes[0] >= UInt8(97) && bytes[0] <= UInt8(122)))) {
        return Key.Letter(bytes[0])
    }
    if (bytes.size == 1 && bytes[0] >= UInt8(48) && bytes[0] <= UInt8(57)) {
        return Key.Digit(bytes[0])
    }
    throw IllegalArgumentException("unsupported key: ${value}")
}

@When[debug]
func debugUiCommandRemainder(line: String): String {
    let runes = line.toRuneArray()
    var index: Int64 = 0
    while (index < runes.size && runes[index] != r' ') { index += 1 }
    while (index < runes.size && runes[index] == r' ') { index += 1 }
    String(runes[index..runes.size])
}

@When[debug]
func containsDebugUiId(values: Array<String>, id: String): Bool {
    for (value in values) { if (value == id) { return true } }
    false
}

@When[debug]
func debugUiDifference(values: Array<String>, baseline: Array<String>): Array<String> {
    let result = ArrayList<String>()
    for (value in values) {
        if (!containsDebugUiId(baseline, value)) { result.add(value) }
    }
    result.toArray()
}

@When[debug]
func debugUiJsonArray(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(debugUiJsonQuote(value))
    }
    out.append("]")
    out.toString()
}

@When[debug]
func debugUiJsonQuote(value: String): String {
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

@When[debug]
func emitDebugUiResult(status: String, ok: Bool, payload: String, code: Int64, message: String): Unit {
    println("CANGHUI_DEBUG_UI_RESULT " +
        "{\"status\":" + debugUiJsonQuote(status) + ",\"ok\":${ok},\"payload\":" +
        (if (payload.isEmpty()) { "null" } else { payload }) +
        ",\"errorCode\":${code},\"errorMessage\":" + debugUiJsonQuote(message) + "}")
}

@When[!debug]
class DebugUiScriptRunner {
    init() {}

    func active(): Bool { false }

    func observe(_: Widget, _: UiContext, _: Int32, _: Int32): Unit {}

    func executeNext(_: UiContext, _: (UiEvent) -> Unit): Unit {}
}
