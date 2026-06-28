import ignite.client.*
import ignite.api2
import std.collection.{ArrayList, HashMap}
import std.io.*

// ════════════════════════════════════════════════════════════════════
// Ignite Client Demo — 渐进式 consumer story
//
// 这条 demo 按以下路径走完一个完整的 consumer 使用流程：
//   1. 快捷 GET  →  2. JSON POST  →  3. 响应读取（body / observe / touchpoint）
//   4. request() builder 路径  →  5. Hook 观察  →  6. body 读取方式对比
//   7. Retained recovery 快照  →  8. 单次请求重试覆盖  →  9. 清理
// ════════════════════════════════════════════════════════════════════

func buildCryptoConfig(): api2.ClientCryptoConfig {
    let ring = HashMap<String, Array<UInt8>>()
    ring.add("k1", "0123456789abcdef0123456789abcdef".toArray())
    api2.ClientCryptoConfig(
        providerKind: api2.ClientCryptoProviderKind.StdxFallback,
        activeKid: "k1",
        keyRing: ring,
        aeadAlgorithm: "AES-256-GCM"
    )
}

func printSection(title: String): Unit {
    println("\n=== ${title} ===")
}

func printObserve(label: String, resp: ClientResponse): Unit {
    let duration = resp.header("x-ignite-observe-duration-ms") ?? "-"
    let retryCount = resp.header("x-ignite-observe-retry-count") ?? "-"
    let errClass = resp.header("x-ignite-observe-error-class") ?? "-"
    let fields = resp.header("x-ignite-observe-fields") ?? "-"
    println("${label} observe => durationMs=${duration}, retryCount=${retryCount}, errorClass=${errClass}, fields=${fields}")
}

func printRecovery(label: String, resp: ClientResponse): Unit {
    let observe = resp.observeSnapshot()
    let touchpoint = resp.transportTouchpoint()
    let obsStr = match (observe) {
        case Some(s) => "outcome=${s.outcome},responseStatus=${s.responseStatus},backendId=${s.backendId}"
        case None => "no observeSnapshot"
    }
    let tpStr = match (touchpoint) {
        case Some(t) => "selectedBackend=${t.selectedBackend},reason=${t.selectedReason}"
        case None => "no transportTouchpoint"
    }
    println("${label} recovery => observe=[${obsStr}] touchpoint=[${tpStr}]")
}

func printRetainedRecovery(label: String, client: RestClient): Unit {
    let observe = client.lastClientObserveSnapshot()
    let touchpoint = client.lastClientTransportTouchpoint()
    let obsStr = match (observe) {
        case Some(s) => "outcome=${s.outcome},phase=${s.phase},backendId=${s.backendId}"
        case None => "no lastClientObserveSnapshot"
    }
    let tpStr = match (touchpoint) {
        case Some(t) => "selectedBackend=${t.selectedBackend},publicPath=${t.publicPath}"
        case None => "no lastClientTransportTouchpoint"
    }
    println("${label} retained => observe=[${obsStr}] touchpoint=[${tpStr}]")
}

main() {
    // ════════════════════════════════════════════════════════════════
    // Step 1: Create a RestClient with base URL and default headers
    // ════════════════════════════════════════════════════════════════
    printSection("Step 1: Setup — Create a RestClient")

    let client = RestClient(
            readTimeout: Duration.second * 15,
            writeTimeout: Duration.second * 15,
            poolSize: 10
        )
        .baseUrl("http://127.0.0.1:18080")
        .defaultHeader("x-service", "ignite-demo")
        .useCrypto(buildCryptoConfig())
        .useRetry(ClientRetryConfig(
            enabled: true,
            maxAttempts: 3,
            idempotentOnly: true,
            baseDelayMs: 20,
            maxDelayMs: 120,
            jitterMs: 0
        ))

    println("RestClient created with baseUrl=http://127.0.0.1:18080, retry=enabled")
    println("All relative paths will auto-resolve against baseUrl")

    // ════════════════════════════════════════════════════════════════
    // Step 2: Quick GET — the simplest possible request
    // ════════════════════════════════════════════════════════════════
    printSection("Step 2: Quick GET")

    let pingResp = client.get("/ping")
    println("GET /ping -> ${pingResp.status} ${pingResp.body()}")
    printObserve("GET /ping", pingResp)

    // ════════════════════════════════════════════════════════════════
    // Step 3: POST with JSON body (convenience method)
    // ════════════════════════════════════════════════════════════════
    printSection("Step 3: POST JSON (convenience method)")

    let payload = "{\"scope\":\"client-demo\",\"message\":\"hello ignite\"}"
    let echoResp = client.postJson("/echo-json", payload)
    println("POST /echo-json -> ${echoResp.status} ${echoResp.body()}")
    printObserve("POST /echo-json", echoResp)

    // ════════════════════════════════════════════════════════════════
    // Step 4: Response reading — body, observeSnapshot, transportTouchpoint
    // ════════════════════════════════════════════════════════════════
    printSection("Step 4: Response reading")

    // body() is cached — can be read multiple times
    let body1 = echoResp.body()
    let body2 = echoResp.body()
    println("body() first read:  ${body1}")
    println("body() second read: ${body2} (same cached result)")

    // observeSnapshot() / transportTouchpoint() — 基于响应头回放，不受 body 读取影响
    printRecovery("POST /echo-json", echoResp)

    // ════════════════════════════════════════════════════════════════
    // Step 5: request() builder path — 更精细的控制
    // ════════════════════════════════════════════════════════════════
    printSection("Step 5: request() builder path")

    let builderResp = client.request()
        .method("POST")
        .url("/echo-json")
        .header("content-type", "application/json")
        .header("x-request-source", "builder-demo")
        .bodyJson("{\"from\":\"builder\",\"value\":42}")
        .send()

    println("builder POST /echo-json -> ${builderResp.status} ${builderResp.body()}")
    printObserve("builder", builderResp)
    printRecovery("builder", builderResp)

    // ════════════════════════════════════════════════════════════════
    // Step 6: Hook demonstration — 在单次 builder 请求上挂 Hook
    // ════════════════════════════════════════════════════════════════
    printSection("Step 6: Request hooks")

    let hookedResp = client.request()
        .onRequest({ req =>
            println("  [hook:onRequest] adding x-trace-id header")
            req.header("x-trace-id", "demo-trace-001")
        })
        .onResponse({ resp =>
            let status = resp.status
            println("  [hook:onResponse] status=${status}")
        })
        .onError({ err =>
            println("  [hook:onError] ${err.message}")
        })
        .method("GET")
        .url("/ping")
        .send()

    println("hooked GET /ping -> ${hookedResp.status} ${hookedResp.body()}")

    // ════════════════════════════════════════════════════════════════
    // Step 7: body 读取方式对比 — bodyStream() vs bodyBytes() vs discard()
    // ════════════════════════════════════════════════════════════════
    printSection("Step 7: Body reading comparison")

    // bodyBytes() — 缓存模式，可重复读取
    let cacheableResp = client.get("/stream-response")
    let bb1 = cacheableResp.bodyBytes()
    let bb2 = cacheableResp.bodyBytes()
    println("bodyBytes() first read:  ${bb1.size} bytes")
    println("bodyBytes() second read: ${bb2.size} bytes (repeatable)")

    // bodyStream() — one-pass 流式读取，只能消费一次
    let streamResp = client.get("/stream-response")
    let streamIn = streamResp.bodyStream()
    let buf = Array<UInt8>(256, repeat: 0)
    let n = streamIn.read(buf)
    println("bodyStream() read once: ${n} bytes — stream is now consumed")

    // discard() — 不缓存，直接排空
    let discardResp = client.get("/stream-response")
    discardResp.discard()
    println("discard() called — no body cached")
    let discardText = String.fromUtf8(discardResp.bodyBytes())
    println("discardResp.bodyBytes() after discard: \"${discardText}\" (empty, not cached)")

    // ════════════════════════════════════════════════════════════════
    // Step 8: Retained recovery 快照
    // ════════════════════════════════════════════════════════════════
    printSection("Step 8: Retained recovery snapshots")

    // Client 侧 retained recovery 保留最近一次 send 的诊断快照
    printRetainedRecovery("after last request", client)

    // 再做一次请求，观察 retained 字段变化
    let anotherResp = client.get("/ping")
    println("GET /ping (another) -> ${anotherResp.status}")
    printRetainedRecovery("after GET /ping", client)

    // ════════════════════════════════════════════════════════════════
    // Step 9: 单次请求重试覆盖
    // ════════════════════════════════════════════════════════════════
    printSection("Step 9: Per-request retry override")

    // 使用 request() builder 对单次请求覆盖重试策略
    let retryOverrideResp = client.request()
        .method("GET")
        .url("/ping")
        .retry(ClientRetryConfig(
            enabled: true,
            maxAttempts: 5,        // 覆盖全局默认的 3 次
            idempotentOnly: true,
            baseDelayMs: 10,
            maxDelayMs: 50,
            jitterMs: 0
        ))
        .send()

    println("retry-override GET /ping -> ${retryOverrideResp.status} — used maxAttempts=5 instead of default 3")

    // 也可以用 disableRetry() 完全关闭重试
    let noRetryResp = client.request()
        .method("GET")
        .url("/ping")
        .disableRetry()
        .send()

    println("retry-disabled GET /ping -> ${noRetryResp.status} — no retry applied")

    // ════════════════════════════════════════════════════════════════
    // Step 10: 加密请求
    // ════════════════════════════════════════════════════════════════
    printSection("Step 10: Encrypted request")

    let securePayload = "{\"scope\":\"client-demo\",\"message\":\"hello secure\"}"
    let secureResp = client.postEncryptedJson(
        "/secure-echo",
        securePayload,
        aad: "route:/secure-echo"
    )
    println("POST /secure-echo -> ${secureResp.status} ${secureResp.body()}")

    // ════════════════════════════════════════════════════════════════
    // Step 11: clearRecoverySnapshots — 启动新 probe 窗口前清空
    // ════════════════════════════════════════════════════════════════
    printSection("Step 11: Clear and close")

    client.clearRecoverySnapshots()
    println("clearRecoverySnapshots() called — retained state reset for next probe wave")

    client.close()
    println("RestClient closed")
}
