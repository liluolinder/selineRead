package ignite.tests

import ignite.{App, Config, resolveStaticAssetPath}

@Test
public class StaticSecurityRegressionTestSuite {
    @TestCase
    public func testAppStaticRejectsPathTraversal(): Unit {
        let app = App(config: Config())
        app.`static`("/public", "./manual")

        let ok = app.handleForTest("GET", "/public/README.md")
        @Assert(ok.status, UInt16(200))
        @Assert(contains(ok.body, "Ignite"), true)

        let escaped = app.handleForTest("GET", "/public/../README.md")
        @Assert(escaped.status, UInt16(404))
        @Assert(contains(escaped.body, "File not found"), false)
    }

    @TestCase
    public func testStaticPathResolverRejectsTraversalForMiddlewareUse(): Unit {
        let ok = resolveStaticAssetPath("./manual", "/README.md") ?? ""
        @Assert(ok, "./manual/README.md")

        let escaped = resolveStaticAssetPath("./manual", "/../README.md")
        if (let None <- escaped) {
            @Assert(true)
        } else {
            @Fail("path traversal should be rejected by shared static path resolver")
        }
    }

    func contains(text: String, sub: String): Bool {
        let t = text.toRuneArray()
        let p = sub.toRuneArray()
        if (p.size == 0) {
            return true
        }
        if (t.size < p.size) {
            return false
        }
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
            if (ok) {
                return true
            }
            i += 1
        }
        false
    }
}
