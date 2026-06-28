# Ignite Client Demo — 渐进式 Consumer Story

本 demo 带你完整走一遍 Ignite `RestClient` 的消费者使用路径。

## 路径概览

执行 `demo_client.cj` 会依次展示：

| 步骤 | 内容 | 演示目标 |
|---|---|---|
| 1 | Setup | 创建 `RestClient`，配置 `baseUrl`、`defaultHeader`、`useRetry` |
| 2 | Quick GET | 最简 GET 请求，响应体读取 |
| 3 | POST JSON | 快捷方法 `postJson()`，观测响应 Observe 头 |
| 4 | Response reading | `body()` 缓存可重复读、`observeSnapshot()` / `transportTouchpoint()` 基于响应头重放 |
| 5 | `request()` builder | 链式调用：method / url / header / bodyJson / send |
| 6 | Request hooks | `onRequest` / `onResponse` / `onError` 单次请求挂 Hook |
| 7 | Body 读取对比 | `bodyBytes()` 缓存 vs `bodyStream()` one-pass vs `discard()` 排空 |
| 8 | Retained recovery | `lastClientObserveSnapshot()` / `lastClientTransportTouchpoint()` |
| 9 | Per-request retry | `request().retry(...)` 覆盖 / `disableRetry()` |
| 10 | Encrypted request | `postEncryptedJson()` 加密 JSON 请求 |
| 11 | Clean up | `clearRecoverySnapshots()` → `close()` |

## 运行方法

### 前置要求

- Cangjie 工具链（`cjpm`、`cjc`）
- stdx 静态库路径已定位

### 一键运行

```bash
./manual/samples/client/run_demo.sh
```

脚本会：编译 server → 启动 server → 编译 client → 运行 client → 停止 server。

### 期望输出

各步骤的预期输出：

```
=== Step 1: Setup — Create a RestClient ===
RestClient created with baseUrl=http://127.0.0.1:18080, retry=enabled

=== Step 2: Quick GET ===
GET /ping -> 200 {"ok":true,"pong":"ignite"}
GET /ping observe => durationMs=..., retryCount=0, errorClass=, fields=...

=== Step 3: POST JSON (convenience method) ===
POST /echo-json -> 200 {"ok":true,"echo":...}
POST /echo-json observe => ...

=== Step 4: Response reading ===
body() first read:  {"ok":true,"echo":...}
body() second read: {"ok":true,"echo":...} (same cached result)
POST /echo-json recovery => observe=[...] touchpoint=[...]

=== Step 5: request() builder path ===
builder POST /echo-json -> 200 {"ok":true,"echo":...}

=== Step 6: Request hooks ===
  [hook:onRequest] adding x-trace-id header
  [hook:onResponse] status=200
hooked GET /ping -> 200 {"ok":true,"pong":"ignite"}

=== Step 7: Body reading comparison ===
bodyBytes() first read:  ... bytes
bodyBytes() second read: ... bytes (repeatable)
bodyStream() read once: ... bytes — stream is now consumed
discard() called — no body cached
discardResp.bodyBytes() after discard: "" (empty, not cached)

=== Step 8: Retained recovery snapshots ===
after last request retained => observe=[...] touchpoint=[...]
after GET /ping retained => observe=[...] touchpoint=[...]

=== Step 9: Per-request retry override ===
retry-override GET /ping -> 200 — used maxAttempts=5 instead of default 3
retry-disabled GET /ping -> 200 — no retry applied

=== Step 10: Encrypted request ===
POST /secure-echo -> 200 {"ok":true,"decrypted":...}

=== Step 11: Clear and close ===
clearRecoverySnapshots() called — retained state reset for next probe wave
RestClient closed
```

## 代码走读要点

### 渐进式结构

每个步骤独立成节，后一步依赖前一步创建的 `client` 实例：
- Step 1-3: 创建→简单请求→JSON 请求（核心模式完形）
- Step 4-6: 响应读取→Builder→Hook（精细控制）
- Step 7-9: Body 读取→Recovery→Retry（进阶能力）
- Step 10: 加密请求（专项场景）
- Step 11: 清理（好习惯）

### 设计原则

- **chain-first**：`RestClient().baseUrl().defaultHeader().useRetry()` 链式调用
- **body 语义明确**：`bodyBytes()` 缓存 → `bodyStream()` one-pass → `discard()` 排空 — 三种模式互不干扰
- **诊断方式分离**：Observe 头从响应头重放，不受 body 读取影响
- **recovery 分离**：响应侧 `observeSnapshot()` 是当前请求级；client 侧 `lastClient*` 是最近一次 send 共享槽

## 注意事项

- demo 使用 `StdxFallback` 加密，兼容本地运行
- server 和 client 都用 `aad = "route:/secure-echo"` 验证加密 endpoint
- 单台机器运行多个 Cangjie 工具链时，设 `IGNITE_CANGJIE_HOME` 指定路径
- 本 demo 不参与 `cjpm test`
