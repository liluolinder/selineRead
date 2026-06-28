import ignite.*
import std.collection.ArrayList

public class Todo <: JsonEncodable {
    public var id: Int64
    public var title: String
    public var done: Bool

    public init(id: Int64, title: String, done: Bool) {
        this.id = id
        this.title = title
        this.done = done
    }

    public func toJsonString(): String {
        #"{"id":${id},"title":"${escapeJson(title)}","done":${boolToJson(done)}}"#
    }
}

public class TodoListResponse <: JsonEncodable {
    public let items: Array<Todo>

    public init(items: Array<Todo>) {
        this.items = items
    }

    public func toJsonString(): String {
        var out = "{\"items\":["
        for (i in 0..items.size) {
            if (i > 0) {
                out += ","
            }
            out += items[i].toJsonString()
        }
        out += "]}"
        out
    }
}

main() {
    let app = App(config: Config(appName: "ignite-sample-api"))
    let store = TodoStore()

    app.get("/todos", { ctx =>
        let (doneFilter, parseErr) = parseDoneFilter((ctx.queryFromUrl("done") ?? "").trimAscii())
        if (let Some(message) <- parseErr) {
            _ = ctx.status(400).json(errorJson(message))
            return
        }
        if (let Some(done) <- doneFilter) {
            _ = ctx.jsonEncode(TodoListResponse(store.list(Some(done))))
            return
        }
        _ = ctx.jsonEncode(TodoListResponse(store.list(None)))
    })

    app.post("/todos", { ctx =>
        let title = (ctx.queryFromUrl("title") ?? "").trimAscii()
        if (title.size == 0) {
            _ = ctx.status(400).json(errorJson("missing title query parameter"))
            return
        }
        let todo = store.create(title)
        _ = ctx.status(201).jsonEncode(todo)
    })

    app.get("/todos/:id", { ctx =>
        if (let Some(id) <- parseId(ctx.params("id"))) {
            if (let Some(todo) <- store.find(id)) {
                _ = ctx.jsonEncode(todo)
            } else {
                _ = ctx.status(404).json(errorJson("todo not found"))
            }
            return
        }
        _ = ctx.status(400).json(errorJson("invalid id"))
    })

    app.patch("/todos/:id", { ctx =>
        let parsedId = parseId(ctx.params("id"))
        if (let None <- parsedId) {
            _ = ctx.status(400).json(errorJson("invalid id"))
            return
        }
        var id: Int64 = -1
        if (let Some(v) <- parsedId) {
            id = v
        }
        let doneRaw = (ctx.queryFromUrl("done") ?? "").trimAscii().toAsciiLower()
        if (doneRaw != "true" && doneRaw != "false") {
            _ = ctx.status(400).json(errorJson("done must be true or false"))
            return
        }
        let targetDone = doneRaw == "true"
        if (let Some(updated) <- store.setDone(id, targetDone)) {
            _ = ctx.jsonEncode(updated)
        } else {
            _ = ctx.status(404).json(errorJson("todo not found"))
        }
    })

    app.delete("/todos/:id", { ctx =>
        if (let Some(id) <- parseId(ctx.params("id"))) {
            if (store.remove(id)) {
                _ = ctx.sendStatus(204)
            } else {
                _ = ctx.status(404).json(errorJson("todo not found"))
            }
            return
        }
        _ = ctx.status(400).json(errorJson("invalid id"))
    })

    println("[sample/api] listening on http://127.0.0.1:18809")
    println("[sample/api] routes: GET/POST /todos, GET/PATCH/DELETE /todos/:id")
    app.listen("127.0.0.1", 18809)
}

func parseDoneFilter(raw: String): (?Bool, ?String) {
    if (raw.size == 0) {
        return (None, None)
    }
    let normalized = raw.toAsciiLower()
    if (normalized == "true") {
        return (Some(true), None)
    }
    if (normalized == "false") {
        return (Some(false), None)
    }
    (None, Some("done must be true or false"))
}

public class TodoStore {
    var todos: ArrayList<Todo> = ArrayList<Todo>()
    var nextId: Int64 = 1

    public func create(title: String): Todo {
        let todo = Todo(nextId, title, false)
        todos.add(todo)
        nextId += 1
        todo
    }

    public func list(doneFilter: ?Bool): Array<Todo> {
        if (let None <- doneFilter) {
            return todos.toArray()
        }
        let out = ArrayList<Todo>()
        var done = false
        if (let Some(v) <- doneFilter) {
            done = v
        }
        for (todo in todos) {
            if (todo.done == done) {
                out.add(todo)
            }
        }
        out.toArray()
    }

    public func find(id: Int64): ?Todo {
        for (todo in todos) {
            if (todo.id == id) {
                return Some(todo)
            }
        }
        None
    }

    public func setDone(id: Int64, done: Bool): ?Todo {
        for (todo in todos) {
            if (todo.id == id) {
                todo.done = done
                return Some(todo)
            }
        }
        None
    }

    public func remove(id: Int64): Bool {
        let kept = ArrayList<Todo>()
        var removed = false
        for (todo in todos) {
            if (todo.id == id) {
                removed = true
            } else {
                kept.add(todo)
            }
        }
        todos = kept
        removed
    }
}

func parseId(raw: String): ?Int64 {
    parseInt64Strict(raw.trimAscii())
}

func parseInt64Strict(text: String): ?Int64 {
    if (text.size == 0) {
        return None
    }
    let chars = text.toRuneArray()
    var i: Int64 = 0
    var sign: Int64 = 1
    if (chars[0] == r'-') {
        sign = -1
        i = 1
    } else if (chars[0] == r'+') {
        i = 1
    }
    if (i >= chars.size) {
        return None
    }
    var out: Int64 = 0
    while (i < chars.size) {
        let ch = chars[i]
        if (ch < r'0' || ch > r'9') {
            return None
        }
        out = out * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        i += 1
    }
    Some(out * sign)
}

func errorJson(message: String): String {
    #"{"error":"bad_request","message":""# + escapeJson(message) + #""}"#
}

func boolToJson(v: Bool): String {
    if (v) { "true" } else { "false" }
}

func escapeJson(input: String): String {
    var out = ""
    for (r in input.toRuneArray()) {
        if (r == r'"') {
            out += "\\\""
        } else if (r == r'\\') {
            out += "\\\\"
        } else if (r == r'\n') {
            out += "\\n"
        } else if (r == r'\r') {
            out += "\\r"
        } else if (r == r'\t') {
            out += "\\t"
        } else {
            out += r.toString()
        }
    }
    out
}
