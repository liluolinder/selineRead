import ignite.*
import std.time.DateTime

main() {
    let app = App(config: Config(appName: "ignite-sample-ignitekit"))
    let kit = IgniteKit(prefix: "/web")

    let cssPath = kit.routePath("/app.css")
    let generatedAt = DateTime.now().toString()
    let homeTemplate =
        "<!doctype html><html><head><meta charset=\"utf-8\">" +
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" +
        "<title>{{title}}</title><link rel=\"stylesheet\" href=\"{{css}}\"></head>" +
        "<body><main><h1>{{title}}</h1><p>generated at: {{time}}</p>" +
        "<p><a href=\"/web/hello.html?name=Ignite\">open dynamic hello page</a></p></main></body></html>"

    _ = kit.css(
        "/app.css",
        "body{margin:0;background:#f5f7fb;color:#1b1f23;font-family:monospace;}" +
        "main{max-width:720px;margin:48px auto;padding:24px;background:#fff;border:1px solid #e5e7eb;border-radius:12px;}" +
        "a{color:#0f766e;text-decoration:none;}a:hover{text-decoration:underline;}"
    )
    _ = kit.html(
        "/index.html",
        homeTemplate,
        vars: [
            ("title", "IgniteKit Sample"),
            ("css", cssPath),
            ("time", generatedAt)
        ]
    )
    _ = kit.dynamicHtml("/hello.html", { ctx =>
        let rawName = (ctx.queryFromUrl("name") ?? "").trimAscii()
        let name = if (rawName.size > 0) { rawName } else { "ignite" }
        kit.renderTemplate(
            "<!doctype html><html><head><meta charset=\"utf-8\"><title>Hello</title>" +
            "<link rel=\"stylesheet\" href=\"{{css}}\"></head><body><main><h1>Hello, {{name}}</h1>" +
            "<p><a href=\"/web/index.html\">back</a></p></main></body></html>",
            vars: [("name", name), ("css", cssPath)]
        )
    })
    _ = kit.mount(app)

    app.get("/", { ctx =>
        _ = ctx.redirect("/web/index.html")
    })

    println("[sample/ignitekit] listening on http://127.0.0.1:18810")
    println("[sample/ignitekit] open /web/index.html and /web/hello.html?name=your-name")
    app.listen("127.0.0.1", 18810)
}
