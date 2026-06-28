package ignite.tests

import ignite.*

@Test
public class IgniteKitTestSuite {
    @TestCase
    public func testStaticAssetTemplateAndCssMapping(): Unit {
        let app = App(config: Config())
        let kit = IgniteKit(prefix: "/web")

        _ = kit.css("/app.css", "body{background:#f6f7f9;color:#222;}")
        _ = kit.html(
            "/index.html",
            "<!doctype html><html><head><title>{{title}}</title><link rel=\"stylesheet\" href=\"{{css}}\"></head><body><h1>{{title}}</h1></body></html>",
            vars: [
                ("title", "IgniteKit Demo"),
                ("css", kit.routePath("/app.css"))
            ]
        )
        _ = kit.mount(app)

        let htmlResp = app.handleForTest("GET", "/web/index.html")
        @Assert(htmlResp.status, UInt16(200))
        @Assert(contains(htmlResp.header("content-type") ?? "", "text/html"), true)
        @Assert(contains(htmlResp.body, "IgniteKit Demo"), true)
        @Assert(contains(htmlResp.body, "/web/app.css"), true)

        let cssResp = app.handleForTest("GET", "/web/app.css")
        @Assert(cssResp.status, UInt16(200))
        @Assert(contains(cssResp.header("content-type") ?? "", "text/css"), true)
        @Assert(contains(cssResp.body, "background"), true)
    }

    @TestCase
    public func testDynamicHtmlAndDefaultPrefixMapping(): Unit {
        let app = App(config: Config())
        let kit = IgniteKit()

        _ = kit.dynamicHtml("/hello.html", { ctx =>
            let rawName = (ctx.queryFromUrl("name") ?? "").trimAscii()
            let name = if (rawName.size > 0) { rawName } else { "ignite" }
            kit.renderTemplate("<h1>Hello, {{name}}</h1>", vars: [("name", name)])
        })
        _ = kit.mount(app)

        let resp1 = app.handleForTest("GET", "/kit/hello.html?name=ignite")
        @Assert(resp1.status, UInt16(200))
        @Assert(contains(resp1.body, "Hello, ignite"), true)

        let resp2 = app.handleForTest("GET", "/kit/hello.html")
        @Assert(resp2.status, UInt16(200))
        @Assert(contains(resp2.body, "Hello, ignite"), true)
    }

    func contains(text: String, sub: String): Bool {
        let t = text.toRuneArray()
        let p = sub.toRuneArray()
        if (p.size == 0) { return true }
        if (t.size < p.size) { return false }
        var i: Int64 = 0
        while (i <= t.size - p.size) {
            var ok = true
            var j: Int64 = 0
            while (j < p.size) {
                if (t[i + j] != p[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) { return true }
            i += 1
        }
        false
    }
}
