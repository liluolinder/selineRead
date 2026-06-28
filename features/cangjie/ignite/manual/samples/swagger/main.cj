import ignite.*

main() {
    let app = App(config: Config(
        appName: "ignite-sample-swagger",
        enableSwagger: true,
        kmode: true
    ))
    app.swagger(SwaggerInfo(
        title: "Ignite Swagger Sample",
        description: "RouteOption driven OpenAPI + self-check sample for Ignite 0.6.x",
        version: "0.6.1"
    ))

    let healthOption = RouteOption()
    healthOption.withSummary("Health check")
    healthOption.withDescription("Returns a minimal health payload.")
    healthOption.withTag("system")
    healthOption.withOperationId("sample.health")
    healthOption.withResponse(ResponseSpec(
        200,
        description: "Health payload",
        contentType: "application/json",
        schema: #"{"type":"object","properties":{"ok":{"type":"boolean"},"service":{"type":"string"}}}"#,
        example: #"{"ok":true,"service":"swagger-sample"}"#
    ))
    healthOption.withTestOption(TestOption(
        storage: "memory",
        report: "inline",
        versionTag: "0500"
    ))

    let todoOption = RouteOption()
    todoOption.withSummary("Get one todo")
    todoOption.withDescription("Shows a path parameter and a documented response.")
    todoOption.withTag("todos")
    todoOption.withOperationId("sample.todo.detail")
    todoOption.withParam(ParamSpec(
        "id",
        ParamLocation.Path,
        description: "Todo identifier",
        required: true,
        dataType: "string",
        example: "demo-1"
    ))
    todoOption.withResponse(ResponseSpec(
        200,
        description: "Todo detail",
        contentType: "application/json",
        schema: #"{"type":"object","properties":{"id":{"type":"string"},"title":{"type":"string"},"done":{"type":"boolean"}}}"#,
        example: #"{"id":"demo-1","title":"Swagger sample todo","done":false}"#
    ))

    let echoOption = RouteOption()
    echoOption.withSummary("Echo request payload")
    echoOption.withDescription("Shows requestBody, response example and debug-only self-check metadata.")
    echoOption.withTag("debug")
    echoOption.withOperationId("sample.echo")
    echoOption.withRequestBody(RequestBodySpec(
        contentType: "application/json",
        schema: #"{"type":"object","properties":{"name":{"type":"string"},"trace":{"type":"boolean"}},"required":["name"]}"#,
        example: #"{"name":"ignite","trace":true}"#,
        required: true
    ))
    echoOption.withResponse(ResponseSpec(
        200,
        description: "Echo payload",
        contentType: "application/json",
        schema: #"{"type":"object","properties":{"ok":{"type":"boolean"},"name":{"type":"string"}}}"#,
        example: #"{"ok":true,"name":"ignite"}"#
    ))
    echoOption.withTestOption(TestOption(
        storage: "memory",
        report: "inline",
        versionTag: "0500"
    ))

    app.get("/", { ctx =>
        _ = ctx.redirect("/swagger")
    })

    app.get("/health", { ctx =>
        _ = ctx.json("{\"ok\":true,\"service\":\"swagger-sample\"}")
    }, option: healthOption)

    app.get("/todos/:id", { ctx =>
        _ = ctx.json(todoJson(ctx.params("id")))
    }, option: todoOption)

    app.post("/echo", { ctx =>
        let raw = ctx.bodyString().trimAscii()
        let payload = if (raw.size > 0) {
            raw
        } else {
            #"{"name":"ignite"}"#
        }
        _ = ctx.json(#"{"ok":true,"payload":"# + payload + "}")
    }, option: echoOption)

    println("[sample/swagger] listening on http://127.0.0.1:18811")
    println("[sample/swagger] ui: http://127.0.0.1:18811/swagger")
    println("[sample/swagger] json: http://127.0.0.1:18811/swagger/json")
    println("[sample/swagger] self-check: curl -i -H 'x-ignite-test: mock' http://127.0.0.1:18811/health")
    println("[sample/swagger] echo live: curl -i -X POST http://127.0.0.1:18811/echo -H 'content-type: application/json' -d '{\"name\":\"ignite\"}'")
    app.listen("127.0.0.1", 18811)
}

func todoJson(id: String): String {
    "{\"id\":\"" + id + "\",\"title\":\"Swagger sample todo\",\"done\":false}"
}
