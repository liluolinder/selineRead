<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-Ignite-ff6b35?style=for-the-badge&labelColor=1a1a2e" alt="Ignite" />
  <img src="https://img.shields.io/badge/version-0.7.7-blue?style=for-the-badge&labelColor=1a1a2e" alt="Version" />
  <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=for-the-badge&labelColor=1a1a2e" alt="License" />
</p>
<div align="center">
<pre style="background:#00000000">
┌─────────────────────────────────────────────────────┐
│                  <span style="color:#88C0D0;">Ignite v0.7.7</span>                     │
│  <span style="color:#6EB186;">http://127.0.0.1:8080</span><span style="color:#9AA0A6;"> || (bound on 0.0.0.0:8080)</span>   │
│                                                     │
│ Touchpoints <span style="color:#666666;">.........</span> 16  Processes <span style="color:#666666;">............</span> 1  │
│ Prefork <span style="color:#666666;">.......</span> Disabled  PID <span style="color:#666666;">..............</span> 67271  │
│                                      <span style="color:#8A8A8A;"><i>_Ignite 0.7.7</i></span> │
└─────────────────────────────────────────────────────┘
</pre>
</div>

<h1 align="center">Ignite (叶燧)</h1>

<p align="center">
  <strong>A web framework for the Cangjie language, built for real service delivery</strong><br>
  <sub>Express-style ergonomics · Production governance · Server/Client evolution</sub>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="#core-features">Core Features</a> ·
  <a href="#api-overview">API Overview</a> ·
  <a href="#middleware">Middleware</a> ·
  <a href="#advanced-usage">Advanced Usage</a> ·
  <a href="#showcase">Showcase</a> ·
  <a href="#license">License</a>
</p>

<p align="center">
  <a href="https://atomgit.com/Cinexus/ignite-cangjie">Repository</a> ·
  <a href="https://pkg.cangjie-lang.cn/package/ignite">Package registry</a>
</p>

---

## Why Ignite?

> **"Light the first fire of Cangjie web development."**

Cangjie is a programming language by Huawei. **Ignite** is a web framework built for the Cangjie ecosystem—inspired by [Fiber](https://gofiber.io/)'s minimal design philosophy and focused on a more continuous path from first endpoint to production governance. Rather than only chasing benchmark narratives, Ignite prioritizes **lightweight ergonomics, default operational capabilities, and long-term maintainability** for Cangjie teams.

We believe a good framework should be as light as a leaf and yet strike like flint. We took **“叶” (leaf)** for agility and **“燧” (flint)** for ignition, and named it **叶燧 (Ignite)**.

## Current Status (0.7.7)

- `0700` is now the active public/governance line: the goal is not only to add features, but to keep the current capability set easier to hand off, audit, and recover on cloud runs.
- `H1` is the current ready-now intake lane: `hello / api / client / files` already cover the most practical first-run and payload/stream/client paths.
- `H2` remains a guarded intake lane: there is smoke, guard, and honest writer/sendStream wording, but Ignite does not claim full commodity-grade closure yet.
- the self-hosted `server-socket` runway now has a deeper parser/session/body/writer/runtime-experiment ladder, but it is still runway/experiment truth rather than a default public engine switch.
- for the public baseline and milestone timeline, see `manual/docs-md/README.md`, `CHANGELOG.MD`, and `CHANGELOG-en.MD`.

```
                ┌─────────────────────────────────────────┐
                │            Ignite Architecture          │
                │                                         │
                │   Request ──► Router (Trie) ──► Match   │
                │                                   │     │
                │              Middleware Chain ◄───┘     │
                │              │     │     │              │
                │              ▼     ▼     ▼              │
                │          Logger   CORS   Recover        │
                │            │                            │
                │            ▼                            │
                │       Handler ──► Ctx ──► Response      │
                │                    │                    │
                │           ┌────────┼────────┐           │
                │           ▼        ▼        ▼           │
                │         JSON     SSE    WebSocket       │
                └─────────────────────────────────────────┘
```

## Quick Start

### Requirements

- Cangjie SDK [`cangjie-sdk`](https://cangjie-lang.cn/download) v1.1.0+
- Cangjie standard extension library [`cangjie-stdx`](https://gitcode.com/Cangjie/cangjie_stdx/releases/v1.1.0-beta.24.1)
  - For [Cangjie nightly (with stdx)](https://gitcode.com/Cangjie/nightly_build) if needed
- Platforms: see the support matrix below for the exact OS / platform lines.

### Adding dependencies

#### Add dependency in `cangjie.toml`

```toml
[package]
..... # In the dependency group under [package], add:
[dependencies]
    Ignite = { git = "https://gitcode.com/Cinyu/Ignite-cangjie" }
```

#### Using the package registry

Refer to `cangjie-repo.toml.example` to create and configure `cangjie-repo.toml` locally.

> **Note:** If you use a private or authenticated package registry, **do not commit `cangjie-repo.toml`** to the repo (it is listed in .gitignore).

### Hello, Ignite!

```cangjie
import ignite.*

main() {
    let app = App()

    app.get("/", { ctx =>
        ctx.json(#"{"message": "Hello, Ignite!"}"#)
    })

    app.listen("0.0.0.0", 3000)
}
```

Just **6 lines of code** to spin up an HTTP server.

For a runnable first path from the repository root (`Ignite/`), start with:

```bash
cjpm build
./manual/samples/hello/run.sh
```

If you are using Ignite inside your own application repository rather than validating samples inside the framework repository itself, `cjpm run` is the right command only after your app provides an executable entrypoint.

## Core Features

| Feature | Description |
|:---|:---|
| **Trie router** | Efficient prefix-tree routing with path params `:id` and wildcard `*` |
| **Chained API** | Fluent chaining: `app.get(...).post(...).use(...)` |
| **Middleware** | Global + route-group middleware; `ctx.next()` controls flow |
| **Route groups** | `app.group("/api")` with nested groups and auto-prefix |
| **WebSocket** | One-line WebSocket upgrade |
| **SSE** | Built-in Server-Sent Events |
| **Streaming** | `ctx.writer()` and `ctx.sendStream(...)` for incremental responses; HTTP/1.1 may use chunked framing, HTTP/2 must rely on the lower writer contract instead of `Transfer-Encoding` |
| **Swagger** | OpenAPI 3.0 + Swagger UI with cache (`enableSwaggerCache`), `?refresh=1` to force refresh |
| **TLS/HTTP2** | Native TLS with HTTP/2 ALPN |
| **HTTP client** | Built-in `RestClient` with builder-style API |
| **JSON** | `ctx.jsonSerialize` / `ctx.jsonEncode`, optional `Config.jsonEncoder`; `ignite.serializeJson` / `deserializeJson` |
| **Files & Range** | `ctx.sendFile`, `ctx.download` (attachment name), `ctx.sendFileRange` (HTTP Range 206/416) |
| **Large body path** | `ctx.saveBodyToFile(path)` can push large request bodies straight to disk without first forcing a full in-memory body cache |
| **static / staticSpa** | `app.static(prefix, root)` for static only; `app.staticSpa(prefix, root, indexFile)` for static-first + SPA fallback to index |
| **Graceful shutdown** | `onShutdown` hook for cleanup |

## API Overview

### Route registration

```cangjie
let app = App()

// Basic routes
app.get("/users", listUsers)
app.post("/users", createUser)
app.put("/users/:id", updateUser)
app.delete("/users/:id", deleteUser)

// All HTTP methods
app.all("/health", healthCheck)
```

Route methods on both `App` and `Group` also accept `Array<Handler>` when you want a clear per-route handler chain instead of nested wrapper helpers:

```cangjie
let userReadChain: Array<Handler> = [
    requireAuth,
    auditUserRead,
    listUsers
]

app.get("/users", userReadChain)
app.post("/users", [requireAuth, createUser])
```

You can also replace the default `404 / 405` bodies at the `App` layer:

```cangjie
app.notFound({ ctx =>
    let _ = ctx.status(404).json(#"{"error":"route_not_found"}"#)
})

app.methodNotAllowed({ ctx =>
    let _ = ctx.status(405).json(#"{"error":"method_not_allowed"}"#)
})
```

The fallback still flows through the global middleware chain, and `405` still keeps the `Allow` header plus the existing `OPTIONS` semantics.

### Path & query params

```cangjie
app.get("/users/:id", { ctx =>
    let userId = ctx.params("id")
    let fields = ctx.queryDefault("fields", "all")
    ctx.json(#"{"id": "${userId}", "fields": "${fields}"}"#)
})
```

### Request context (Ctx)

`Ctx` is the core object for the request lifecycle:

```cangjie
app.post("/upload", { ctx =>
    // Request info
    let method   = ctx.method       // "POST"
    let path     = ctx.path         // "/upload"
    let clientIp = ctx.ip           // "127.0.0.1"
    let token    = ctx.header("Authorization")

    // Body
    let body = ctx.bodyString()
    let saved = ctx.saveBodyToFile("/tmp/upload.bin")

    // Response
    ctx.status(201).json(#"{"status": "created", "saved": ${saved}}"#)
})
```

**Response helpers:**

```cangjie
ctx.json(body)                   // application/json
ctx.jsonSerialize(obj)           // Serialize when T implements StdxJsonSerializable
ctx.jsonEncode(obj)              // JsonEncodable or Config.jsonEncoder
ctx.sendString(body)             // text/plain
ctx.html(body)                   // text/html
ctx.send(byteArray)              // raw bytes
ctx.sendStatus(404)               // status + default message
ctx.redirect("/login")           // 302 redirect
ctx.noContent()                  // 204 No Content
ctx.sendFile(path)               // send file by path
ctx.download(path, filename)     // attachment (optional filename)
ctx.sendFileRange(path)          // HTTP Range → 206/416
ctx.sendStream(stream, ...)      // stream InputStream as the response body
ctx.setCookie("token", value,    // Set-Cookie
    maxAge: 3600,
    httpOnly: true,
    secure: true
)
```

For large uploads, prefer `ctx.saveBodyToFile(path)` so the request body can be pushed directly to disk instead of being forced through `ctx.bodyBytes()` first. For large response bodies, `ctx.sendStream(...)` now has real HTTP/1.1 regression coverage on known-length, unknown-length, and `HEAD` paths; HTTP/2 multi-write behavior still depends on the underlying writer/TLS route and is not claimed closed from README wording alone.

For per-request state, keep using `ctx.setLocal(...)` / `ctx.getLocal(...)` for string locals, or move to `ctx.setLocalValue(...)` / `ctx.getLocalValue<T>(...)` when a route or middleware needs typed request-scoped values.

### Route groups

```cangjie
let api = app.group("/api/v1")

api.use(authMiddleware)

api.get("/users", listUsers)
api.post("/users", createUser)

// Nested group
let admin = api.group("/admin")
admin.use(adminOnlyMiddleware)
admin.get("/stats", getStats)
// Path: GET /api/v1/admin/stats
```

### Config

```cangjie
let app = App(config: Config(
    appName:             "MyService",
    appVersion:          "1.0.0",   // optional; shown in banner title; empty = framework version
    serverHeader:        "Ignite/0.4",
    bodyLimit:           10 * 1024 * 1024,   // 10MB
    readTimeout:         std.time.Duration.second * 30,
    writeTimeout:        std.time.Duration.second * 30,
    enableSwagger:       true,
    swaggerPath:         "/swagger",
    enableSwaggerCache:  true,   // Cache Swagger JSON/UI; ?refresh=1 to refresh
    enablePrintSwaggerUrl: true, // Controls only the startup "Swagger UI" line
    enablePrintRoutes:   false,  // when true, print route table at startup; banner always shown
    enableBannerSignature: true, // Banner signature in the lower-right corner
    kmode:               false,  // debug mode: prints the extra Ignite version line
    kmodePanicHandler:   None,   // optional App-level panic fallback hook; return true when handled
    enableTlsPrecheck:   true,   // TLS precheck toggle: default = jinguissl precheck before the current stdx TLS build path
    jsonEncoder:         None   // Optional custom JsonEncodable encoder
))
```

#### KeyMode (kMode) Super user
- Currently reserved for developer-only component definitions

## Middleware

### Built-in middleware

Import with `import ignite.middleware.*`:

| Category | Middleware | Description |
|------|--------|------|
| **Security** | `securityMiddleware` | X-Content-Type-Options, X-Frame-Options, HSTS, CSP, etc. |
| | `corsMiddleware` | CORS |
| | `csrfMiddleware` | CSRF double-submit cookie |
| | `basicAuthMiddleware` | HTTP Basic auth |
| | `keyAuthMiddleware` | API Key (Header/Query/Cookie) |
| | `jwtMiddleware` | JWT auth middleware (currently HS256; Header/Query/Cookie extraction + claims injection) |
| | `encryptCookieMiddleware` | Cookie encrypt/decrypt (AEAD v1 with legacy XOR dual-read migration) |
| **Logging** | `loggerMiddleware` | Method, path, duration; Logger interface + DefaultLogger, custom impl; `enableEntityLog` for structured log, `jsonLine` for JSON line output |
| | `auditMiddleware` | Unified audit event (eventId/requestId/actor/ip/action/result/riskLevel + securityEvent/securityCode/securitySource) |
| | `accessLogMiddleware` | IP, latency, User-Agent |
| | `requestIdMiddleware` | X-Request-ID |
| | `recoverMiddleware` | Panic recovery |
| **Flow** | `rateLimitMiddleware` | Rate limit by IP or custom key |
| | `bodyLimitMiddleware` | Request body size limit |
| | `timeoutMiddleware` | Request timeout |
| **Cache** | `cacheMiddleware` | In-memory GET response cache |
| | `compressMiddleware` | Response compression (gzip/deflate, negotiated by `Accept-Encoding`, with size threshold config) |
| | `etagMiddleware` | ETag + If-None-Match 304 |
| **Session** | `sessionMiddleware` | Session ID cookie + SessionStore |
| **Other** | `redirectMiddleware` | URL redirect rules |
| | `rewriteMiddleware` | URL rewrite (ctx locals) |
| | `staticFileMiddleware` | Static files |
| | `faviconMiddleware` | favicon.ico |
| | `healthCheckMiddleware` | Health check endpoint |
| | `idempotencyMiddleware` | X-Idempotency-Key |
| | `proxyMiddleware` | Reverse proxy (with optional X509 verify entry) |
| **Debug** | `kmodeMiddleware` | kmode debug: sets ctx local `kmode`; the `Bool` overload is now a loopback-only legacy-open compatibility lane with a startup warning, while `KModePolicy` remains the explicit scoped form |

Example:

```cangjie
import ignite.middleware.*

// Debug mode compatibility lane (loopback-only legacyOpen; prints a startup warning)
app.use(kmodeMiddleware(app.config.kmode))

// Logging
app.use(loggerMiddleware())

// JWT (HS256)
app.use(jwtMiddleware(JwtConfig(
    secret: "replace-me"
)))

// Response compression (recommended before cache/etag)
app.use(compressMiddleware())

// CORS
app.use(corsMiddleware(config: CorsConfig(
    allowOrigins: "https://example.com",
    allowCredentials: true,
    maxAge: 86400
)))

// Security headers
app.use(securityMiddleware(config: SecurityConfig(hstsMaxAge: 31536000)))

// Request ID
app.use(requestIdMiddleware())
```

### Custom middleware

```cangjie
let authMiddleware: Handler = { ctx =>
    let token = ctx.header("Authorization")
    if (let Some(t) <- token) {
        ctx.setLocal("user", "authenticated")
        ctx.next()
    } else {
        ctx.status(401).json(#"{"error": "Unauthorized"}"#)
    }
}

app.use(authMiddleware)
```

Middleware runs in onion order; `ctx.next()` passes control:

```
Request ──► Logger ──► CORS ──► Auth ──► Handler
                                          │
Response ◄── Logger ◄── CORS ◄── Auth ◄───┘
```

### JWT middleware (0.5.21)

```cangjie
import ignite.middleware.*

app.use(jwtMiddleware(JwtConfig(
    secret: "replace-with-strong-secret",
    requiredIssuer: "ignite",
    requiredAudience: "web",
    queryName: "access_token",   // optional: query extraction
    cookieName: "access_token"   // optional: cookie extraction
)))
```

- Algorithm support: `HS256` (current baseline)
- Built-in checks: `exp` / `nbf` / `iat` (`clockSkewSec` configurable)
- Context locals on success: `jwt_claims`, `jwt_sub`, `jwt_token`
- Security model note: use HTTPS transport, short-lived tokens, and rotate secrets regularly

### kMode Emergency Failover (Recover + Client Probe)

When an `ig/app` panic is caught by `recoverMiddleware`, you can trigger an emergency probe in `kmode=true`:

```cangjie
import ignite.governance.*
import ignite.middleware.*

let failoverOption = KModeFailoverOption(
    enabled: true,
    probeUrl: "http://localhost:8828",
    probeMethod: "POST",
    probePayload: "ignite-emergency",
    expectedResponse: "RESTART",
    probeTimeoutSec: 2,
    maxAttempts: 5,
    intervalMs: 500,
    restartOnMatch: true,
    terminateOnMiss: true
)

app.use(recoverMiddleware(config: RecoverConfig(
    kmodeFailover: Some(failoverOption)
)))
```

- Response matches `expectedResponse`: returns `503` and calls `app.shutdown()` by default (supervisor restarts process).
- Response mismatch after thresholds: returns `503` and calls `app.shutdown()`.
- Override with `onKModeRestart` / `onKModeTerminate` hooks when custom behavior is needed.

If you do not use `recoverMiddleware`, use `Config.kmodePanicHandler` to attach a similar fallback at App top-level catch.

### Security Observability (0.5.04)

`ignite.security` exposes structured counters: `decryptFailures`, `signatureFailures`, `certRejects`.

```cangjie
import ignite.security.*

let snap = securityMetricsSnapshot()
println("decrypt=${snap.decryptFailures}, sign=${snap.signatureFailures}, cert=${snap.certRejects}")
```

## Advanced Usage

### Function override

Use middleware with optional config (e.g. LoggerConfig: custom logger, enableEntityLog for structured logs):

```cangjie
app.use(loggerMiddleware())
app.use(recoverMiddleware())
```

**Custom Logger implementation:** Implement the `Logger` interface (`log(msg: String): Unit`) to control log format and destination (file, remote, etc.). Inject via `LoggerConfig(logger: ...)`:

```cangjie
public class MyLogger: Logger {
    public func log(msg: String) {
        println("[MyLogger] " + msg)
    }
}
let loggerConfig = LoggerConfig(logger: MyLogger())
app.use(loggerMiddleware(config: loggerConfig))
```

Or customize output with `LoggerConfig.output`:

```cangjie
app.use(loggerMiddleware(config: LoggerConfig(output: { msg => 
    writeFile("/var/log/myapp.log", msg + "\n", append: true)
})))
```

For ELK/Loki ingestion, enable JSON-line output:

```cangjie
let cfg = LoggerConfig()
cfg.jsonLine = true
app.use(loggerMiddleware(config: cfg))
```

### Request bind & validate (`bindJsonOr400`)

Use `Ctx.bindJsonOr400<T>(decoder, validate?)` to centralize JSON decoding and readable `400` responses:

```cangjie
import stdx.encoding.json.{JsonValue, JsonObject}

public class CreateUserReq {
    public let name: String
    public let age: Int64
    public init(name: String, age: Int64) {
        this.name = name
        this.age = age
    }
}

func decodeCreateUserReq(v: JsonValue): CreateUserReq {
    let obj = v.asObject()
    let name = obj.get("name").orThrow().asString()
    let age = obj.get("age").orThrow().asInt64()
    CreateUserReq(name, age)
}

app.post("/users", { ctx =>
    if (let Some(req) <- ctx.bindJsonOr400<CreateUserReq>(
        decodeCreateUserReq,
        validate: { r =>
            if (r.name.trimAscii().size == 0) { return Some("name is required") }
            if (r.age <= 0) { return Some("age must be positive") }
            None
        }
    )) {
        _ = ctx.status(201).sendString("created:${req.name}:${req.age}")
    }
})
```

Failure responses return `400` JSON with reason:
- `invalid_json`
- `invalid_payload`
- `validation_failed`

### WebSocket

```cangjie
app.ws("/chat", { conn =>
    while (true) {
        let msg = conn.readMessage()
        if (msg.isClose) { break }
        if (msg.isText) {
            conn.writeText("Echo: ${msg.text()}")
        }
    }
    conn.close()
})
```

### Server-Sent Events (SSE)

```cangjie
app.get("/events", { ctx =>
    let sse = ctx.sse()
    sse.sendRetry(3000)
    for (i in 0..10) {
        sse.sendEvent(
            #"{"count": ${i}}"#,
            event: "counter",
            id: "${i}"
        )
    }
})
```

### Streaming response

```cangjie
app.get("/stream-file", { ctx =>
    let stream = File.openRead("large-report.txt")
    _ = ctx.sendStream(
        stream,
        contentType: "text/plain; charset=utf-8"
    )
})

app.get("/stream", { ctx =>
    let writer = ctx.writer()
    writer.writeString("chunk 1\n")
    writer.writeString("chunk 2\n")
    writer.writeString("chunk 3\n")
})
```

`ctx.sendStream(...)` is the safer public path when you already have an `InputStream` and want to keep a large response body off the heap. `ctx.writer()` is the lower-level incremental writer. Under HTTP/1.1 that may map to chunked semantics; under HTTP/2 it must not emit `Transfer-Encoding`, and repeated `write(...)` calls still depend on the lower `stdx.net.http.HttpResponseWriter` contract to package and send data.

### Static files & SPA fallback (static / staticSpa)

**Static directory only:** `app.static(prefix, root)` maps URL path to files under `root`; only responds when the file exists, otherwise the request is passed to later routes or 404.

**Static-first + SPA fallback:** For Next.js static export, Vite/React, or other SPAs, you often want “serve file if present, otherwise return index.html for client-side routing.” Use `app.staticSpa(prefix, root, indexFile)`:

```cangjie
// Under /: try file under frontend/out first; if missing, return frontend/out/index.html
app.staticSpa("/", "frontend/out", "index.html")
```

- `prefix`: URL prefix (e.g. `"/"`); root path registers both GET/HEAD `/` and `/*`.
- `root`: Static file root (e.g. Next.js `out`, Vite `dist`).
- `indexFile`: Fallback file when no file matches; default `"index.html"`.
- Path safety: Requests containing `..` are rejected and fall back to the index file.

Register API routes first, then `staticSpa` last, so APIs are not shadowed by the catch-all.

### IgniteKit: lightweight dynamic page/style composition

If you don't want HTML/CSS generation logic mixed into your main route file, use `IgniteKit` to group assets and mount once:

```cangjie
let kit = IgniteKit(prefix: "/web")
_ = kit.css("/app.css", "body{font-family:monospace;}")
_ = kit.html("/index.html", "<h1>{{title}}</h1>", vars: [("title", "IgniteKit")])
_ = kit.dynamicHtml("/hello.html", { ctx =>
    let name = (ctx.queryFromUrl("name") ?? "ignite").trimAscii()
    kit.renderTemplate("<h1>Hello, {{name}}</h1>", vars: [("name", name)])
})
_ = kit.mount(app)
```

Useful for admin mini-pages, diagnostics pages, quick templated views before a full frontend split.

#### What if I just want SPA?

Ignite matches routes **top to bottom**. For **security**, if you need greedy static matching, **register it last**:

```cangjie
app.static("/app", "frontend/out")
app.static("/", "frontend/out")
app.static("/*", "frontend/out")
```

### Route naming & reverse URL generation (`urlFor`)

You can name routes via:
- `RouteOption.withOperationId("name")`
- `app.nameRoute(method, path, name)`

```cangjie
app.get(
    "/users/:id/posts/:postId",
    getUserPost,
    option: RouteOption().withOperationId("user.post.detail")
)

let detailUrl = app.urlFor(
    "user.post.detail",
    params: [("id", "42"), ("postId", "7")],
    query: [("include", "meta data")]
) ?? "/fallback"
// /users/42/posts/7?include=meta+data

app.get("/assets/*", getAsset)
let _ = app.nameRoute("GET", "/assets/*", "asset.file")
let assetUrl = app.urlFor("asset.file", params: [("*", "img/logo.png")]) ?? "/assets/default.png"
```

If route name is missing or path params are incomplete, `urlFor` returns `None`.

### Swagger / OpenAPI

```cangjie
let app = App(config: Config(
    enableSwagger: true,
    swaggerPath: "/docs",
    enablePrintSwaggerUrl: true
))

app.swagger(SwaggerInfo(
    title: "My API",
    version: "1.0.0",
    description: "Powered by Ignite"
))

app.get("/users/:id", getUser, option: RouteOption()
    .withSummary("Get user")
    .withDescription("Get user by ID")
    .withTags(["Users"])
    .withParams([ParamSpec(
        name: "id",
        location: ParamLocation.Path,
        required: true,
        description: "User ID"
    )])
    .withResponses([
        ResponseSpec(status: 200, description: "Success"),
        ResponseSpec(status: 404, description: "Not found")
    ])
)

// Visit /docs for Swagger UI, /docs/json for OpenAPI JSON
```

- `enableSwagger` is the master switch for Swagger / OpenAPI routes and UI.
- `enablePrintSwaggerUrl` only controls the startup `Swagger UI: ...` line and does not remove the routes.
- `swaggerPath` defines both the UI path and the `${swaggerPath}/json` OpenAPI JSON path.

### TLS / HTTPS

```cangjie
let app = App(config: Config(
    tlsCertFile: "./cert.pem",
    tlsKeyFile:  "./key.pem",
    enableTlsPrecheck: true // default on: jinguissl precheck before the current stdx TLS config build
))

// TLS + HTTP/2 ALPN (h2, http/1.1)
app.listen("0.0.0.0", 443)
```

**HTTP/2**: With TLS, the server negotiates `h2`. Verify with `curl -sI --http2 https://localhost:3443/`.

`enableTlsPrecheck` can be set to `false` to fallback to the current "default TLS build only" path. Use this mainly for emergency troubleshooting windows.

The current public mainline still treats **Ignite + stdx TLS config build** as the default HTTPS path; `jinguissl` is currently a precheck and parallel-evolution layer, not a drop-in replacement for the default HTTPS listener chain.  
For production deployment, the safer recommendation today is to keep the current default path or terminate TLS at a reverse proxy.

TLS startup troubleshooting matrix (startup log fields: `tls_stage` / `tls_error_code` / `hint`):

| `tls_error_code` | Typical cause | Suggested action |
|------|------|------|
| `BAD_INPUT` | Empty PEM input or invalid ALPN config | Check certificate/key content and ALPN list (`h2,http/1.1`) |
| `VERIFY_FAILED` | Certificate chain and private key mismatch | Re-pair cert/key and verify chain order |
| `INTERNAL_ERROR` | Exception during stdx TLS config build | Check runtime dependencies, cert parsing and file paths |

### HTTP client

```cangjie
import ignite.client.*

let client = RestClient()

let resp = client.get("https://api.example.com/users")
println(resp.body())
resp.discard()

// POST JSON
let resp2 = client.postJson(
    "https://api.example.com/users",
    #"{"name": "Ignite"}"#
)
println(resp2.status)
resp2.discard()

// X509 verify entry (Client)
client.useX509Verify(X509VerifyOption(
    enabled: true,
    requireHttps: true,
    expectedServerName: "api.example.com",
    pinnedSha256: ["sha256:your-pin"],
    hook: { ctx =>
        // Plug in your certificate-chain / pin comparison logic here
        true
    }
))

client.close()
```

More end-to-end client examples (encrypted request / Retry+Hook+Cookie / observe fields / streaming download):
`manual/samples/client/README.md`

**Client API:**

| Capability | API |
|------|-----|
| Methods | `get`, `post`, `put`, `patch`, `delete`, `head`, `options` |
| JSON | `postJson(url, json)` |
| Encrypted JSON | `useCrypto(config)` + `postEncryptedJson(url, json, aad?)` + `request().encryptedBodyJson(json, aad?, config?)` |
| Form | `postForm(url, ArrayList<(String,String)>)` |
| Multipart | `postMultipart(url, fields, files)`, `MultipartFile(name, filename, contentType, data)` |
| Retry/backoff | `useRetry(config)`, idempotent methods retry by default; `request().retry(config)` / `request().disableRetry()` |
| X509 verify entry | `useX509Verify(option)`; `request().x509Verify(option)` / `request().disableX509Verify()` |
| Hook pipeline | `onRequest`, `onResponse`, `onError` (both `RestClient` and `RequestBuilder`) |
| Observability | Success responses include `x-ignite-observe-duration-ms/retry-count/error-class/fields`; `ClientResponse.observeSnapshot()` and `transportTouchpoint()` replay the response-side view; `lastClientObserveSnapshot()` / `lastClientTransportTouchpoint()` retain the latest client-side recovery surface; `clearRecoverySnapshots()` resets that retained state between probe waves; error hook receives `[ignite.client.observe] ...` wrapper text |
| Builder | `request().method().url().query(k,v).header()/addHeader().basicAuth().bearerToken().form()/multipart().send()` |
| Base URL | `baseUrl("https://api.example.com")` |
| Default headers | `defaultHeader(name, value)` |
| Cookies | `useCookies()` or `useCookies(store)`; supports `domain/path/max-age/secure/httpOnly/sameSite` and multi `set-cookie` |
| Response | `status`, `body()`/`bodyBytes()`/`bodyStream()`, `json()`, `header(name)`, `headerValues(name)`, `observeSnapshot()`, `transportTouchpoint()`, `isOk()`/`isSuccess()`, `discard()` (optimized for large payload paths) |

### In-proc test entry (`handleForTest`)

`App.handleForTest(...)` runs route + middleware assertions without manual `listen`:

```cangjie
let app = App(config: Config())
app.use({ ctx =>
    ctx.next()
    _ = ctx.setHeader("x-mw", "hit")
})
app.get("/ping", { ctx => _ = ctx.sendString("pong") })

let resp = app.handleForTest("GET", "/ping")
@Assert(resp.status, 200)
@Assert(resp.body, "pong")
@Assert(resp.header("x-mw") ?? "", "hit")
```

### Error handling & graceful shutdown

```cangjie
app.onError({ ctx, err =>
    println("[Error] ${err.message}")
    ctx.status(500).json(#"{"error": "${err.message}"}"#)
})

app.onShutdown({
    println("Releasing resources...")
    // Close DB, clear caches, etc.
})
```

## Project structure

```
ignite/
├── src/
│   ├── app.cj            # App core: create, routes, serve, lifecycle
│   ├── config.cj         # Config: timeouts, limits, TLS, Swagger, etc.
│   ├── ctx.cj            # Request context: request/response API
│   ├── route.cj          # Route metadata and match result
│   ├── router.cj         # Trie router
│   ├── handler.cj        # Handler / ErrorHandler types
│   ├── group.cj          # Route groups: prefix + group middleware
│   ├── stream.cj         # ResponseWriter / SseWriter
│   ├── websocket.cj      # WebSocket connection
│   ├── swagger.cj        # OpenAPI 3.0 generator
│   ├── middleware/
│   │   ├── logger.cj, cors.cj, recover.cj   # Base
│   │   ├── security.cj, csrf.cj, basic_auth.cj, key_auth.cj, encrypt_cookie.cj
│   │   ├── access_log.cj, request_id.cj, rate_limit.cj, body_limit.cj, timeout.cj
│   │   ├── cache.cj, etag.cj, session.cj
│   │   ├── proxy.cj, redirect.cj, rewrite.cj, static_file.cj, favicon.cj
│   │   ├── health_check.cj, idempotency.cj, utils.cj
│   └── client/
│       ├── client.cj          # Shared types/helpers (CookieStore/RetryConfig, etc.)
│       ├── rest_client.cj     # RestClient entry
│       ├── request_builder.cj # Request pipeline: Hook/Retry/Observe
│       └── client_response.cj # Response wrapper and large-body read path
└── cjpm.toml             # Package config
```

## Supported platforms

| OS / Platform | Arch / Line | Status | Notes |
|:---|:---|:---:|:---|
| macOS | aarch64 (Apple Silicon) | ✅ | Primary development line |
| macOS | x86_64 (Intel) | ✅ | Supported |
| Linux | x86_64 | ✅ | Generic GNU/Linux line |
| Linux | aarch64 | ✅ | Generic GNU/Linux line |
| EulerOS | Taishan | ✅ | Tracked separately from the generic Linux ARM line |
| EulerOS | x86_64 | ✅ | Distro-specific line |
| Windows | x86_64 | ✅ | Default Windows compatibility line |
| OpenHarmony | aarch64 | ✅ | Public OHOS compatibility line |
| OpenHarmony | x86_64 | ✅ | Certified |
| HarmonyOS | arm64 | ✅ | Device-side deployment line |
| LoongArch | LoongArch64 | Planned | Reserved for future platform expansion |

> Note: `cjpm.toml` records the default in-repo build targets; this matrix also keeps project validation and certification lines.

## Showcase (叶燧星火)

> Trusted by teams that move at the speed of light.

<a href="https://gitcode.com/copur/lanlu">兰鹿 (Lanlu)</a> — Manga archive management system built with Cangjie

### Ignite Samples

- `manual/samples/hello` — Minimal server sample (`GET /` + `GET /health`)
- `manual/samples/api` — In-memory Todo CRUD sample (path params + query params + `ctx.jsonEncode`)
- `manual/samples/swagger` — Swagger / OpenAPI + self-check sample (`InterfaceSpec`, `TestOption`, `x-ignite-test`, `kmode`)
- `manual/samples/client` — Built-in client round-trip demo (`demo_server.cj` + `demo_client.cj`, including encrypted JSON and multipart)
- `manual/samples/ignitekit` — IgniteKit dynamic HTML/CSS composition sample (`kit.html` / `kit.css` / `kit.dynamicHtml`)

### Quick start for this release

- Start with `manual/samples/hello` if you want a 10-second first run.
- Move to `manual/samples/api` if you want to see routing, JSON, middleware-friendly CRUD flow, and `bindJsonOr400`.
- Move to `manual/samples/swagger` if you want to understand Swagger metadata, first-run verification semantics, and `kmode` gating together.
- Try `manual/samples/client` when you want a full Server/Client round trip with encrypted JSON, multipart, and request-building flow.

Still evaluating Ignite? The fastest path is to try the samples in this order: `hello -> api -> swagger -> client`.

## Contribute Next

- Ignite is currently optimized for trial and adoption first; contribution paths are now being prepared behind that.
- For public-facing collaboration, start with `manual/samples/`, README fixes, and low-risk regressions.

### More ecosystem projects

- <a href="https://atomgit.com/cinyu/ignite-benchmark">Ignite-Benchmark</a> — Standard best practices
- <a href="https://gitcode.com/cinyu/easyTODO-core">easyTODO-core</a> — TODO backend with pure Cangjie + HTML
- <a href="https://atomgit.com/cinyu/igMessanging">igMessanging</a> — Chat backend with pure Cangjie + HTML

## Docs and entrypoints

- `manual/README.md` for the current public manual and reading order.
- `manual/samples/README.md` for sample entry order and runnable examples.
- `manual/samples/client/README.md` for end-to-end client usage.
- `CHANGELOG.MD` and `CHANGELOG-en.MD` for the milestone timeline.
- `manual/docs-md/` and `manual/docs-web/` are reserved for the next public docs merge.

## Maintainer note

- **Version**: The single source of truth is `[package].version` in `cjpm.toml` (banner version is read from package metadata at compile time).

## License

Open source under [Apache License 2.0](LICENSE).

---

<p align="center">
  <sub>Build with Cangjie. Ignite the possible.</sub><br>
  <strong>Built with Cangjie. Ignited by passion.</strong>
</p>
