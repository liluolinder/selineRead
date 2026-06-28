import ignite.*

main() {
    let app = App(config: Config(appName: "ignite-sample-hello"))

    app.get("/", { ctx =>
        _ = ctx.sendString("Hello Ignite 0.5.x")
    })

    app.get("/health", { ctx =>
        _ = ctx.json(#"{"ok":true,"service":"hello"}"#)
    })

    println("[sample/hello] listening on http://127.0.0.1:18808")
    app.listen("127.0.0.1", 18808)
}
