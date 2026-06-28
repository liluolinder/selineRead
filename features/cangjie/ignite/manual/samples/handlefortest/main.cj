import ignite.*
import std.env.getVariable

let HANDLE_FOR_TEST_BODY = buildHandleForTestBody()

main() {
    let workerId = readHandleForTestStringEnv("IGNITE_HANDLE_FOR_TEST_STRESS_ID", "worker-standalone")
    let iterations = readHandleForTestPositiveInt64Env("IGNITE_HANDLE_FOR_TEST_STRESS_ITERATIONS", 8)
    let app = App(config: Config(appName: "ignite-sample-handlefortest"))

    app.get("/ping", { ctx =>
        let queryWorker = ctx.queryFromUrl("worker") ?? ""
        let round = ctx.queryFromUrl("round") ?? ""
        sleep(Duration.millisecond * 15)
        _ = ctx.sendString("pong:${queryWorker}:${round}")
    })

    app.post("/echo", { ctx =>
        let bytes = ctx.bodyBytes().size
        sleep(Duration.millisecond * 15)
        _ = ctx.status(201).sendString("echo:${bytes}")
    })

    var round: Int64 = 0
    var calls: Int64 = 0
    while (round < iterations) {
        let getResp = app.handleForTest("GET", "/ping?worker=${workerId}&round=${round}")
        if (getResp.status != UInt16(200)) {
            throw Exception("unexpected ping status=${getResp.status} worker=${workerId} round=${round}")
        }
        if (getResp.body != "pong:${workerId}:${round}") {
            throw Exception("unexpected ping body=${getResp.body} worker=${workerId} round=${round}")
        }
        calls += 1

        let postResp = app.handleForTest(
            "POST",
            "/echo",
            body: HANDLE_FOR_TEST_BODY,
            headers: [("content-type", "text/plain; charset=utf-8")]
        )
        if (postResp.status != UInt16(201)) {
            throw Exception("unexpected echo status=${postResp.status} worker=${workerId} round=${round}")
        }
        if (postResp.body != "echo:${HANDLE_FOR_TEST_BODY.size}") {
            throw Exception("unexpected echo body=${postResp.body} worker=${workerId} round=${round}")
        }
        calls += 1
        round += 1
    }

    println("[sample/handlefortest] worker=${workerId} iterations=${iterations} calls=${calls} ok")
}

func buildHandleForTestBody(): String {
    let block = "ignite-handlefortest-stress-body-0123456789abcdef\n"
    var out = ""
    var i: Int64 = 0
    while (i < 64) {
        out += block
        i += 1
    }
    out
}

func readHandleForTestStringEnv(name: String, fallback: String): String {
    if (let Some(value) <- getVariable(name)) {
        let trimmed = value.trimAscii()
        if (trimmed.size > 0) {
            return trimmed
        }
    }
    fallback
}

func readHandleForTestPositiveInt64Env(name: String, fallback: Int64): Int64 {
    if (let Some(raw) <- getVariable(name)) {
        if (let Some(parsed) <- parseHandleForTestInt64(raw)) {
            if (parsed > 0) {
                return parsed
            }
        }
    }
    fallback
}

func parseHandleForTestInt64(raw: String): ?Int64 {
    let text = raw.trimAscii()
    if (text.size == 0) {
        return None
    }
    let runes = text.toRuneArray()
    var value: Int64 = 0
    var i: Int64 = 0
    while (i < runes.size) {
        let ch = runes[i]
        if (ch < r'0' || ch > r'9') {
            return None
        }
        value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        i += 1
    }
    Some(value)
}
