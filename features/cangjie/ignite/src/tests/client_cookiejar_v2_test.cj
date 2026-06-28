package ignite.tests

import ignite.client.*
import std.time.MonoTime

@Test
public class ClientCookieJarV2TestSuite {
    func waitMs(ms: Int64): Unit {
        let start = MonoTime.now()
        while ((MonoTime.now() - start).toMilliseconds() < ms) {}
    }

    @TestCase
    public func testHostOnlyCookieDoesNotLeakToSubdomain(): Unit {
        let store = CookieStore()
        store.addSetCookie("https://api.ignite.invalid/v1/users", "sid=host; Path=/")

        let sameHost = store.getCookieHeader("https://api.ignite.invalid/v1/profile")
        @Assert(containsStr(sameHost, "sid=host"), true)

        let subHost = store.getCookieHeader("https://sub.api.ignite.invalid/v1/profile")
        @Assert(containsStr(subHost, "sid=host"), false)
    }

    @TestCase
    public func testDomainPathSecureAndSameSiteAttributes(): Unit {
        let store = CookieStore()
        store.addSetCookie(
            "https://api.ignite.invalid/v1/users",
            "token=abc; Domain=ignite.invalid; Path=/v1; Secure; HttpOnly; SameSite=Lax"
        )

        let httpsMatched = store.getCookieHeader("https://sub.ignite.invalid/v1/list")
        @Assert(containsStr(httpsMatched, "token=abc"), true)

        let httpRejected = store.getCookieHeader("http://sub.ignite.invalid/v1/list")
        @Assert(containsStr(httpRejected, "token=abc"), false)

        let pathRejected = store.getCookieHeader("https://sub.ignite.invalid/v2/list")
        @Assert(containsStr(pathRejected, "token=abc"), false)

        let domainRejected = store.getCookieHeader("https://other.invalid/v1/list")
        @Assert(containsStr(domainRejected, "token=abc"), false)
    }

    @TestCase
    public func testMaxAgeAndDeleteByMaxAgeZero(): Unit {
        let store = CookieStore()

        store.addSetCookie("https://a.invalid/", "a=1; Path=/; Max-Age=1")
        @Assert(containsStr(store.getCookieHeader("https://a.invalid/"), "a=1"), true)

        waitMs(1200)
        @Assert(containsStr(store.getCookieHeader("https://a.invalid/"), "a=1"), false)

        store.addSetCookie("https://a.invalid/", "a=2; Path=/")
        @Assert(containsStr(store.getCookieHeader("https://a.invalid/"), "a=2"), true)

        store.addSetCookie("https://a.invalid/", "a=x; Path=/; Max-Age=0")
        @Assert(containsStr(store.getCookieHeader("https://a.invalid/"), "a=2"), false)
    }

    @TestCase
    public func testMultipleSetCookieLinesCombinedInHeader(): Unit {
        let store = CookieStore()
        store.addSetCookie("https://api.ignite.invalid/", "k1=v1; Path=/")
        store.addSetCookie("https://api.ignite.invalid/", "k2=v2; Path=/")

        let header = store.getCookieHeader("https://api.ignite.invalid/x")
        @Assert(containsStr(header, "k1=v1"), true)
        @Assert(containsStr(header, "k2=v2"), true)
    }
}

func containsStr(hay: String, needle: String): Bool {
    let h = hay.toRuneArray()
    let n = needle.toRuneArray()
    if (n.size == 0) { return true }
    if (h.size < n.size) { return false }
    for (i in 0..=(h.size - n.size)) {
        var ok = true
        for (j in 0..n.size) {
            if (h[i + j] != n[j]) { ok = false; break }
        }
        if (ok) { return true }
    }
    false
}
