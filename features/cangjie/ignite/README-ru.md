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
  <strong>Веб-фреймворк для Cangjie, рассчитанный на реальную поставку сервисов</strong><br>
  <sub>Эргономика в духе Fiber · Производственная управляемость · Совместная эволюция Server/Client</sub>
</p>

<p align="center">
  <a href="#быстрый-старт">Быстрый старт</a> ·
  <a href="#основные-возможности">Возможности</a> ·
  <a href="#обзор-api">Обзор API</a> ·
  <a href="#промежуточное-по-middleware">Промежуточное ПО</a> ·
  <a href="#расширенное-использование">Расширенное использование</a> ·
  <a href="#проекты">Проекты</a> ·
  <a href="#лицензия">Лицензия</a>
</p>

<p align="center">
  <a href="https://atomgit.com/Cinexus/ignite-cangjie">Репозиторий</a> ·
  <a href="https://pkg.cangjie-lang.cn/package/ignite">Реестр пакетов</a>
</p>

---

## Почему Ignite?

> **«Зажги первый огонь веб-разработки на Cangjie.»**

Cangjie — язык программирования от Huawei. **Ignite** — веб-фреймворк для экосистемы Cangjie, вдохновлённый минималистичной философией [Fiber](https://gofiber.io/) и ориентированный на более непрерывный путь от первого endpoint до production governance. Вместо погоней за одной лишь benchmark-риторикой Ignite делает ставку на **лёгкую эргономику, встроенные операционные возможности по умолчанию и долгосрочную сопровождимость** для команд на Cangjie.

Мы считаем, что хороший фреймворк должен быть лёгким, как лист, и высекать искру, как кремень. **«叶» (лист)** — за подвижность, **«燧» (кремень)** — за воспламенение; так родилось имя **叶燧 (Ignite)**.

## Текущее состояние (0.7.7)

- `0700` теперь является активной публичной и governance-линией: задача уже не только в добавлении возможностей, но и в том, чтобы текущий набор возможностей было легче передавать, аудировать и восстанавливать в облачных прогонах.
- `H1` сейчас является ready-now intake-направлением: `hello / api / client / files` уже покрывают наиболее практичный first-run и основные payload/stream/client-сценарии.
- `H2` по-прежнему остаётся guarded intake-направлением: есть smoke, guard и честно описанная writer/sendStream семантика, но Ignite не заявляет полное commodity-grade closure.
- self-hosted `server-socket` runway уже получил более длинную parser/session/body/writer/runtime-experiment ladder, но это всё ещё runway/experiment truth, а не обещание немедленного default engine switch.
- Для актуальной публичной базовой точки и шкалы версий используйте `manual/docs-md/README.md`, `CHANGELOG.MD` и `CHANGELOG-en.MD`.

```
                ┌─────────────────────────────────────────┐
                │            Ignite Architecture          │
                │                                         │
                │   Request ──► Router (Trie) ──► Match   │
                │                                   │     │
                │              Middleware Chain ◄───┘     │
                │              │     │     │              │
                │              ▼     ▼     ▼              │
                │          Logger   CORS   Recover         │
                │            │                            │
                │            ▼                            │
                │       Handler ──► Ctx ──► Response      │
                │                    │                    │
                │           ┌────────┼────────┐           │
                │           ▼        ▼        ▼           │
                │         JSON     SSE    WebSocket       │
                └─────────────────────────────────────────┘
```

## Быстрый старт

### Требования

- Cangjie SDK [`cangjie-sdk`](https://cangjie-lang.cn/download) v1.1.0+
- Стандартная библиотека расширений [`cangjie-stdx`](https://gitcode.com/Cangjie/cangjie_stdx/releases/v1.1.0-beta.24.1)
  - При необходимости: [Cangjie nightly (со stdx)](https://gitcode.com/Cangjie/nightly_build)
- Платформы: точная матрица ОС и платформ приведена ниже в разделе поддержки.

### Подключение зависимостей

#### Добавление зависимости в `cangjie.toml`

```toml
[package]
..... # В группе зависимостей в [package] добавьте:
[dependencies]
    Ignite = { git = "https://gitcode.com/Cinyu/Ignite-cangjie" }
```

#### Использование реестра пакетов

Создайте и настройте локально `cangjie-repo.toml` по образцу `cangjie-repo.toml.example`.

> **Важно:** При использовании приватного или защищённого реестра **не коммитьте `cangjie-repo.toml`** в репозиторий (файл в .gitignore).

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

Всего **6 строк кода** — и HTTP-сервер запущен.

Для первого запуска из корня репозитория (`Ignite/`) используйте:

```bash
cjpm build
./manual/samples/hello/run.sh
```

Если же вы используете Ignite в своём прикладном репозитории, а не проверяете sample внутри самого репозитория фреймворка, `cjpm run` подходит только после того, как у вашего приложения появится собственная исполняемая точка входа.

## Основные возможности

| Возможность | Описание |
|:---|:---|
| **Маршрутизация Trie** | Эффективный префиксный роутинг с параметрами пути `:id` и маской `*` |
| **Цепочка API** | Удобные вызовы: `app.get(...).post(...).use(...)` |
| **Промежуточное ПО** | Глобальное и групповое; поток задаётся через `ctx.next()` |
| **Группы маршрутов** | `app.group("/api")` с вложенными группами и авто-префиксом |
| **WebSocket** | Апгрейд до WebSocket в одну строку |
| **SSE** | Встроенная поддержка Server-Sent Events |
| **Потоковая отдача** | `ctx.writer()` и `ctx.sendStream(...)` для поэтапного ответа; в HTTP/1.1 это может быть chunked, а в HTTP/2 нужно опираться на нижележащий writer-контракт, а не на `Transfer-Encoding` |
| **Swagger** | OpenAPI 3.0 и Swagger UI с кэшем (`enableSwaggerCache`), `?refresh=1` для принудительного обновления |
| **TLS/HTTP2** | Нативный TLS и HTTP/2 по ALPN |
| **HTTP-клиент** | Встроенный `RestClient` в стиле builder |
| **JSON** | `ctx.jsonSerialize` / `ctx.jsonEncode`, опционально `Config.jsonEncoder`; `ignite.serializeJson` / `deserializeJson` |
| **Файлы и Range** | `ctx.sendFile`, `ctx.download` (имя вложения), `ctx.sendFileRange` (HTTP Range 206/416) |
| **Путь для больших тел** | `ctx.saveBodyToFile(path)` может сразу складывать большой request body на диск, не заставляя сначала прогонять его через полный in-memory кэш |
| **static / staticSpa** | `app.static(prefix, root)` — только статика; `app.staticSpa(prefix, root, indexFile)` — статика + откат на index для SPA |
| **Корректное завершение** | Хук `onShutdown` для освобождения ресурсов |

## Обзор API

### Регистрация маршрутов

```cangjie
let app = App()

// Базовые маршруты
app.get("/users", listUsers)
app.post("/users", createUser)
app.put("/users/:id", updateUser)
app.delete("/users/:id", deleteUser)

// Все HTTP-методы
app.all("/health", healthCheck)
```

Методы маршрутов у `App` и `Group` теперь также принимают `Array<Handler>`, если нужен явный per-route handler chain без вложенных wrapper helper:

```cangjie
let userReadChain: Array<Handler> = [
    requireAuth,
    auditUserRead,
    listUsers
]

app.get("/users", userReadChain)
app.post("/users", [requireAuth, createUser])
```

На уровне `App` теперь можно заменить и стандартные тела для `404 / 405`:

```cangjie
app.notFound({ ctx =>
    let _ = ctx.status(404).json(#"{"error":"route_not_found"}"#)
})

app.methodNotAllowed({ ctx =>
    let _ = ctx.status(405).json(#"{"error":"method_not_allowed"}"#)
})
```

При этом fallback по-прежнему проходит через глобальную цепочку middleware, а `405` сохраняет `Allow` и текущую семантику `OPTIONS`.

### Параметры пути и запроса

```cangjie
app.get("/users/:id", { ctx =>
    let userId = ctx.params("id")
    let fields = ctx.queryDefault("fields", "all")
    ctx.json(#"{"id": "${userId}", "fields": "${fields}"}"#)
})
```

### Контекст запроса (Ctx)

`Ctx` — основной объект жизненного цикла запроса:

```cangjie
app.post("/upload", { ctx =>
    // Информация о запросе
    let method   = ctx.method       // "POST"
    let path     = ctx.path         // "/upload"
    let clientIp = ctx.ip           // "127.0.0.1"
    let token    = ctx.header("Authorization")

    // Тело запроса
    let body = ctx.bodyString()
    let saved = ctx.saveBodyToFile("/tmp/upload.bin")

    // Ответ
    ctx.status(201).json(#"{"status": "created", "saved": ${saved}}"#)
})
```

**Методы ответа:**

```cangjie
ctx.json(body)                   // application/json
ctx.jsonSerialize(obj)           // сериализация при реализации StdxJsonSerializable
ctx.jsonEncode(obj)              // JsonEncodable или Config.jsonEncoder
ctx.sendString(body)             // text/plain
ctx.html(body)                   // text/html
ctx.send(byteArray)              // сырые байты
ctx.sendStatus(404)              // код + сообщение по умолчанию
ctx.redirect("/login")           // редирект 302
ctx.noContent()                  // 204 No Content
ctx.sendFile(path)               // отдача файла по пути
ctx.download(path, filename)     // вложение (filename опционален)
ctx.sendFileRange(path)          // HTTP Range → 206/416
ctx.sendStream(stream, ...)      // потоковая отдача InputStream как тела ответа
ctx.setCookie("token", value,    // Set-Cookie
    maxAge: 3600,
    httpOnly: true,
    secure: true
)
```

Для больших загрузок стоит предпочитать `ctx.saveBodyToFile(path)`, чтобы тело запроса сразу шло на диск, а не через `ctx.bodyBytes()`. Для больших ответов `ctx.sendStream(...)` уже покрыт реальными HTTP/1.1-регрессиями для `known-length`, `unknown-length` и `HEAD`; поведение многократной записи в HTTP/2 по-прежнему зависит от нижнего writer/TLS-маршрута, и README не должен выдавать это за уже закрытый вопрос.

Для request-scoped состояния можно по-прежнему использовать строковые `ctx.setLocal(...)` / `ctx.getLocal(...)`, а если middleware или route нужен typed value, теперь доступны `ctx.setLocalValue(...)` / `ctx.getLocalValue<T>(...)`.

### Группы маршрутов

```cangjie
let api = app.group("/api/v1")

api.use(authMiddleware)

api.get("/users", listUsers)
api.post("/users", createUser)

// Вложенная группа
let admin = api.group("/admin")
admin.use(adminOnlyMiddleware)
admin.get("/stats", getStats)
// Путь: GET /api/v1/admin/stats
```

### Конфигурация

```cangjie
let app = App(config: Config(
    appName:             "MyService",
    appVersion:          "1.0.0",   // опционально; в заголовке баннера; пусто = версия фреймворка
    serverHeader:        "Ignite/0.4",
    bodyLimit:           10 * 1024 * 1024,   // 10MB
    readTimeout:         std.time.Duration.second * 30,
    writeTimeout:        std.time.Duration.second * 30,
    enableSwagger:       true,
    swaggerPath:         "/swagger",
    enableSwaggerCache:  true,   // кэш Swagger JSON/UI; ?refresh=1 для обновления
    enablePrintSwaggerUrl: true, // управляет только строкой запуска Swagger UI
    enablePrintRoutes:   false,  // при true — печать таблицы маршрутов при старте; баннер всегда показывается
    enableBannerSignature: true, // подпись баннера в правом нижнем углу
    kmode:               false,  // режим отладки: печатает дополнительную строку версии Ignite
    kmodePanicHandler:   None,   // опциональный App-level panic hook; true = ошибка уже обработана
    enableTlsPrecheck:   true,   // переключатель TLS precheck: по умолчанию сначала precheck через jinguissl, затем текущий путь сборки stdx TLS
    jsonEncoder:         None   // опционально: свой энкодер JsonEncodable
))
```

#### KeyMode (kMode) Суперпользователь
- Зарезервировано для определений компонентов, доступных только разработчикам

## Промежуточное ПО (Middleware)

### Встроенное промежуточное ПО

Подключение: `import ignite.middleware.*`:

| Категория | Middleware | Описание |
|------|--------|------|
| **Безопасность** | `securityMiddleware` | Заголовки X-Content-Type-Options, X-Frame-Options, HSTS, CSP и др. |
| | `corsMiddleware` | CORS |
| | `csrfMiddleware` | CSRF, двойная отправка cookie |
| | `basicAuthMiddleware` | HTTP Basic-аутентификация |
| | `keyAuthMiddleware` | API Key (Header/Query/Cookie) |
| | `jwtMiddleware` | JWT-аутентификация (baseline: HS256; Header/Query/Cookie + claims в `ctx locals`) |
| | `encryptCookieMiddleware` | Шифрование/расшифровка cookie (AEAD v1 с миграцией dual-read для legacy XOR) |
| **Логирование** | `loggerMiddleware` | Метод, путь, длительность; интерфейс Logger, DefaultLogger, своя реализация; `enableEntityLog` для структурированных логов |
| | `auditMiddleware` | Унифицированный аудит (eventId/requestId/actor/ip/action/result/riskLevel + securityEvent/securityCode/securitySource) |
| | `accessLogMiddleware` | IP, задержка, User-Agent |
| | `requestIdMiddleware` | X-Request-ID |
| | `recoverMiddleware` | Восстановление после panic |
| **Поток** | `rateLimitMiddleware` | Ограничение по IP или своему ключу |
| | `bodyLimitMiddleware` | Ограничение размера тела запроса |
| | `timeoutMiddleware` | Таймаут запроса |
| **Кэш** | `cacheMiddleware` | Кэш GET-ответов в памяти |
| | `compressMiddleware` | Сжатие ответов (gzip/deflate, согласование по `Accept-Encoding`, настраиваемый порог размера) |
| | `etagMiddleware` | ETag + If-None-Match 304 |
| **Сессии** | `sessionMiddleware` | Cookie с ID сессии + SessionStore |
| **Прочее** | `redirectMiddleware` | Правила редиректа URL |
| | `rewriteMiddleware` | Перезапись URL (ctx locals) |
| | `staticFileMiddleware` | Статические файлы |
| | `faviconMiddleware` | favicon.ico |
| | `healthCheckMiddleware` | Эндпоинт проверки здоровья |
| | `idempotencyMiddleware` | X-Idempotency-Key |
| | `proxyMiddleware` | Обратный прокси (с опциональным X509 verify entry) |
| **Отладка** | `kmodeMiddleware` | Режим kmode: устанавливает ctx local `kmode`; перегрузка с `Bool` теперь оставлена как loopback-only legacy-open совместимый режим с предупреждением при старте, а `KModePolicy` остаётся явной scoped-формой |

Пример:

```cangjie
import ignite.middleware.*

// Совместимый debug-режим (loopback-only legacyOpen; печатает предупреждение при старте)
app.use(kmodeMiddleware(app.config.kmode))

// Логирование
app.use(loggerMiddleware())

// JWT (HS256)
app.use(jwtMiddleware(JwtConfig(
    secret: "replace-me"
)))

// Сжатие ответов (рекомендуется ставить перед cache/etag)
app.use(compressMiddleware())

// CORS
app.use(corsMiddleware(config: CorsConfig(
    allowOrigins: "https://example.com",
    allowCredentials: true,
    maxAge: 86400
)))

// Заголовки безопасности
app.use(securityMiddleware(config: SecurityConfig(hstsMaxAge: 31536000)))

// Request ID
app.use(requestIdMiddleware())
```

### Своё промежуточное ПО

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

Промежуточное ПО выполняется по принципу «луковицы»; `ctx.next()` передаёт управление:

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
    queryName: "access_token",   // опционально: query
    cookieName: "access_token"   // опционально: cookie
)))
```

- Поддерживаемый алгоритм: `HS256`
- Проверки по умолчанию: `exp` / `nbf` / `iat` (`clockSkewSec` можно настроить)
- После успешной проверки в `ctx locals`: `jwt_claims`, `jwt_sub`, `jwt_token`
- Практика безопасности: HTTPS, короткий TTL токена, регулярная ротация секрета

### Аварийный kMode failover (Recover + Client Probe)

Если panic в `ig/app` перехватывается `recoverMiddleware`, в `kmode=true` можно запустить аварийный probe:

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

- Ответ совпал с `expectedResponse`: по умолчанию `503` + `app.shutdown()` (перезапуск делает внешний supervisor).
- Ответ не совпал после лимитов: `503` + `app.shutdown()`.
- Для кастомной логики используйте hooks `onKModeRestart` / `onKModeTerminate`.

Если `recoverMiddleware` не используется, аналогичный fallback можно подключить через `Config.kmodePanicHandler` (верхний catch App).

### Наблюдаемость Безопасности (0.5.04)

`ignite.security` предоставляет структурированные счётчики: `decryptFailures`, `signatureFailures`, `certRejects`.

```cangjie
import ignite.security.*

let snap = securityMetricsSnapshot()
println("decrypt=${snap.decryptFailures}, sign=${snap.signatureFailures}, cert=${snap.certRejects}")
```

## Расширенное использование

### Переопределение поведения

Использование middleware с опциональной конфигурацией (например LoggerConfig: свой logger, enableEntityLog для структурированных логов):

```cangjie
app.use(loggerMiddleware())
app.use(recoverMiddleware())
```

**Своя реализация Logger:** реализуйте интерфейс `Logger` (`log(msg: String): Unit`) для управления форматом и местом вывода (файл, удалённый сервис и т.д.). Подключение через `LoggerConfig(logger: ...)`:

```cangjie
public class MyLogger: Logger {
    public func log(msg: String) {
        println("[MyLogger] " + msg)
    }
}
let loggerConfig = LoggerConfig(logger: MyLogger())
app.use(loggerMiddleware(config: loggerConfig))
```

Либо настройка вывода через `LoggerConfig.output`:

```cangjie
app.use(loggerMiddleware(config: LoggerConfig(output: { msg => 
    writeFile("/var/log/myapp.log", msg + "\n", append: true)
})))
```

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

### Потоковый ответ

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

`ctx.sendStream(...)` — более безопасный публичный путь, когда у вас уже есть `InputStream` и нужно не держать большой ответ целиком в heap. `ctx.writer()` — это более низкоуровневый интерфейс поэтапной записи тела ответа. В HTTP/1.1 это может соответствовать chunked-семантике; в HTTP/2 заголовок `Transfer-Encoding` отправлять нельзя, и повторные `write(...)` должны опираться на контракт нижележащего `stdx.net.http.HttpResponseWriter`.

### Статические файлы и откат для SPA (static / staticSpa)

**Только статика:** `app.static(prefix, root)` сопоставляет URL с файлами в `root`; ответ отдаётся только при существовании файла, иначе запрос уходит дальше по маршрутам или в 404.

**Статика в приоритете + откат для SPA:** для Next.js static export, Vite/React и других SPA часто нужно «отдать файл, если есть, иначе вернуть index.html для клиентского роутинга». Используйте `app.staticSpa(prefix, root, indexFile)`:

```cangjie
// Для /: сначала файл из frontend/out; при отсутствии — frontend/out/index.html
app.staticSpa("/", "frontend/out", "index.html")
```

- `prefix`: префикс URL (например `"/"`); для корня регистрируются GET/HEAD `/` и `/*`.
- `root`: корень статики (например `out` у Next.js, `dist` у Vite).
- `indexFile`: файл по умолчанию при отсутствии совпадения; по умолчанию `"index.html"`.
- Безопасность пути: запросы с `..` отклоняются и откатываются к index-файлу.

Сначала регистрируйте API-маршруты, затем в конце — `staticSpa`, чтобы API не перекрывалось общим обработчиком.

### IgniteKit: лёгкая сборка динамических HTML/CSS

Когда не хочется смешивать генерацию HTML/CSS с основными API-роутами, используйте `IgniteKit` и подключайте ресурсы одним `mount`:

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

Подходит для admin-страниц, диагностических endpoint-страниц и быстрых шаблонов до выделения отдельного frontend-проекта.

#### Нужна только SPA?

Маршруты в Ignite обрабатываются **сверху вниз**. Из соображений **безопасности** при необходимости «жадной» статики **регистрируйте её последней**:

```cangjie
app.static("/app", "frontend/out")
app.static("/", "frontend/out")
app.static("/*", "frontend/out")
```

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

// /docs — Swagger UI, /docs/json — OpenAPI JSON
```

- `enableSwagger` — главный переключатель Swagger / OpenAPI: без него UI и JSON-маршруты не регистрируются.
- `enablePrintSwaggerUrl` управляет только строкой запуска `Swagger UI: ...` и не отключает сами маршруты.
- `swaggerPath` задаёт и путь UI, и путь `${swaggerPath}/json` для OpenAPI JSON.

### TLS / HTTPS

```cangjie
let app = App(config: Config(
    tlsCertFile: "./cert.pem",
    tlsKeyFile:  "./key.pem",
    enableTlsPrecheck: true // по умолчанию: precheck jinguissl перед текущей сборкой stdx TLS config
))

// TLS + HTTP/2 ALPN (h2, http/1.1)
app.listen("0.0.0.0", 443)
```

**HTTP/2:** при включённом TLS сервер согласует `h2`. Проверка: `curl -sI --http2 https://localhost:3443/`.

`enableTlsPrecheck` можно отключить (`false`) для отката на текущий путь "только default TLS build". Рекомендуется только для аварийной диагностики.

Текущая публичная основная линия по-прежнему считает **Ignite + сборку stdx TLS config** маршрутом HTTPS по умолчанию; `jinguissl` сейчас выступает как слой precheck и параллельной эволюции, а не как прямую замену стандартной HTTPS listener chain.  
Для production-развёртывания сейчас безопаснее сохранять текущий путь по умолчанию или завершать TLS на reverse proxy.

Матрица диагностики старта TLS (поля в логах: `tls_stage` / `tls_error_code` / `hint`):

| `tls_error_code` | Типичная причина | Что проверить |
|------|------|------|
| `BAD_INPUT` | Пустой PEM или некорректный ALPN | Проверить cert/key и ALPN (`h2,http/1.1`) |
| `VERIFY_FAILED` | Несовпадение цепочки сертификатов и ключа | Перепроверить пару cert/key и порядок цепочки |
| `INTERNAL_ERROR` | Сбой на этапе сборки stdx TLS config | Проверить runtime-зависимости, парсинг cert и пути к файлам |

### HTTP-клиент

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
        // Подключите здесь вашу проверку цепочки сертификатов / pin-сверку
        true
    }
))

client.close()
```

**API клиента:**

| Возможность | API |
|------|-----|
| Методы | `get`, `post`, `put`, `patch`, `delete`, `head`, `options` |
| JSON | `postJson(url, json)` |
| Шифрованный JSON | `useCrypto(config)` + `postEncryptedJson(url, json, aad?)` + `request().encryptedBodyJson(json, aad?, config?)` |
| Форма | `postForm(url, ArrayList<(String,String)>)` |
| Multipart | `postMultipart(url, fields, files)`, `MultipartFile(name, filename, contentType, data)` |
| Retry/Backoff | `useRetry(config)`, по умолчанию ретраи только для идемпотентных методов; `request().retry(config)` / `request().disableRetry()` |
| X509 verify entry | `useX509Verify(option)`; `request().x509Verify(option)` / `request().disableX509Verify()` |
| Hook-конвейер | `onRequest`, `onResponse`, `onError` (и в `RestClient`, и в `RequestBuilder`) |
| Builder | `request().method().url().query(k,v).header()/addHeader().basicAuth().bearerToken().form()/multipart().send()` |
| Base URL | `baseUrl("https://api.example.com")` |
| Заголовки по умолчанию | `defaultHeader(name, value)` |
| Cookie | `useCookies()` или `useCookies(store)`; поддерживает `domain/path/max-age/secure/httpOnly/sameSite` и несколько `set-cookie` |
| Наблюдаемость | Успешные ответы несут `x-ignite-observe-duration-ms/retry-count/error-class/fields`; `ClientResponse.observeSnapshot()` и `transportTouchpoint()` восстанавливают view на стороне ответа; `lastClientObserveSnapshot()` / `lastClientTransportTouchpoint()` удерживают последнее client-side recovery состояние; `clearRecoverySnapshots()` сбрасывает его между волнами probe; error hook по-прежнему получает текст вида `[ignite.client.observe] ...` |
| Ответ | `status`, `body()`/`bodyBytes()`/`bodyStream()`, `json()`, `header(name)`, `headerValues(name)`, `observeSnapshot()`, `transportTouchpoint()`, `isOk()`/`isSuccess()`, `discard()` |

### Обработка ошибок и корректное завершение

```cangjie
app.onError({ ctx, err =>
    println("[Error] ${err.message}")
    ctx.status(500).json(#"{"error": "${err.message}"}"#)
})

app.onShutdown({
    println("Releasing resources...")
    // Закрытие БД, очистка кэшей и т.д.
})
```

## Структура проекта

```
ignite/
├── src/
│   ├── app.cj            # Ядро приложения: создание, маршруты, запуск, жизненный цикл
│   ├── config.cj         # Конфигурация: таймауты, лимиты, TLS, Swagger и т.д.
│   ├── ctx.cj            # Контекст запроса: API запроса/ответа
│   ├── route.cj          # Метаданные маршрута и результат сопоставления
│   ├── router.cj        # Маршрутизатор Trie
│   ├── handler.cj       # Типы Handler / ErrorHandler
│   ├── group.cj          # Группы маршрутов: префикс и групповое middleware
│   ├── stream.cj         # ResponseWriter / SseWriter
│   ├── websocket.cj      # Подключение WebSocket
│   ├── swagger.cj        # Генератор OpenAPI 3.0
│   ├── middleware/
│   │   ├── logger.cj, cors.cj, recover.cj   # Базовые
│   │   ├── security.cj, csrf.cj, basic_auth.cj, key_auth.cj, encrypt_cookie.cj
│   │   ├── access_log.cj, request_id.cj, rate_limit.cj, body_limit.cj, timeout.cj
│   │   ├── cache.cj, etag.cj, session.cj
│   │   ├── proxy.cj, redirect.cj, rewrite.cj, static_file.cj, favicon.cj
│   │   ├── health_check.cj, idempotency.cj, utils.cj
│   └── client/
│       └── client.cj     # HTTP-клиент (RestClient)
└── cjpm.toml             # Конфигурация пакета
```

## Поддерживаемые платформы

| ОС / Платформа | Архитектура / линия | Статус | Примечание |
|:---|:---|:---:|:---|
| macOS | aarch64 (Apple Silicon) | ✅ | Одна из основных линий разработки |
| macOS | x86_64 (Intel) | ✅ | Поддерживается |
| Linux | x86_64 | ✅ | Общая линия GNU/Linux |
| Linux | aarch64 | ✅ | Общая линия GNU/Linux |
| EulerOS | Taishan | ✅ | Ведётся отдельно от общей Linux ARM линии |
| EulerOS | x86_64 | ✅ | Отдельная линия дистрибутива |
| Windows | x86_64 | ✅ | Базовая линия совместимости Windows |
| OpenHarmony | aarch64 | ✅ | Публичная линия совместимости OHOS |
| OpenHarmony | x86_64 | ✅ | Прошёл сертификацию |
| HarmonyOS | arm64 | ✅ | Линия развёртывания на устройствах |
| LoongArch | LoongArch64 | Планируется | Резерв для следующего этапа расширения |

> Примечание: `cjpm.toml` отражает базовые target'ы, объявленные в репозитории; матрица также фиксирует линии проектной валидации и сертификации.

## Проекты (叶燧星火)

> Командам, которые двигаются со скоростью света.

<a href="https://gitcode.com/copur/lanlu">兰鹿 (Lanlu)</a> — Система управления архивом манги на Cangjie

### Примеры Ignite

- `manual/samples/hello` — минимальный серверный пример (`GET /` + `GET /health`)
- `manual/samples/api` — in-memory Todo CRUD (path/query параметры + `ctx.jsonEncode`)
- `manual/samples/swagger` — Swagger / OpenAPI + sample самопроверки (`InterfaceSpec`, `TestOption`, `x-ignite-test`, `kmode`)
- `manual/samples/client` — встроенный client round-trip demo (`demo_server.cj` + `demo_client.cj`)
- `manual/samples/ignitekit` — пример IgniteKit для динамических HTML/CSS (`kit.html` / `kit.css` / `kit.dynamicHtml`)

### С чего начать в текущем выпуске

- Начните с `manual/samples/hello`, если хотите пройти первый запуск примерно за 10 секунд.
- Затем откройте `manual/samples/api`, чтобы посмотреть маршрутизацию, JSON, CRUD-поток и `bindJsonOr400`.
- После этого откройте `manual/samples/swagger`, чтобы увидеть Swagger-метаданные, семантику первой проверки и `kmode` в одной связке.
- После этого попробуйте `manual/samples/client`, если нужен полный Server/Client round trip с encrypted JSON, multipart и builder-style запросами.

Если вы только оцениваете Ignite, самый быстрый путь сейчас: `hello -> api -> swagger -> client`.

## Как подключиться дальше

- Сейчас Ignite в первую очередь ориентирован на пробное использование и принятие в проектах; сценарии внешнего участия мы подготавливаем параллельно.
- Для публичного участия лучше начинать с `manual/samples/`, правок README и низкорисковых регрессий.

### Другие проекты экосистемы

- <a href="https://atomgit.com/cinyu/ignite-benchmark">Ignite-Benchmark</a> — Рекомендуемые практики
- <a href="https://gitcode.com/cinyu/easyTODO-core">easyTODO-core</a> — Бэкенд TODO на чистом Cangjie + HTML
- <a href="https://atomgit.com/cinyu/igMessanging">igMessanging</a> — Бэкенд чата на чистом Cangjie + HTML

## Документация и входные точки

- `manual/README.md` — текущий публичный manual и порядок чтения.
- `manual/samples/README.md` — матрица примеров и порядок первого запуска.
- `manual/samples/client/README.md` — примеры end-to-end client usage.
- `CHANGELOG.MD` и `CHANGELOG-en.MD` — временная шкала версий.
- `manual/docs-md/` и `manual/docs-web/` зарезервированы под следующий публичный docs merge.

## Заметка для сопровождающих

- **Версия:** Единственный источник истины — `[package].version` в `cjpm.toml` (версия в баннере читается из метаданных пакета на этапе компиляции).

## Лицензия

Открытый код под [Apache License 2.0](LICENSE).

---

<p align="center">
  <sub>Собери на Cangjie. Зажги возможное.</sub><br>
  <strong>Built with Cangjie. Ignited by passion.</strong>
</p>
