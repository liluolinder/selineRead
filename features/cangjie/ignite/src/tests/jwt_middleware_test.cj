package ignite.tests

import ignite.*
import ignite.binary.base64UrlEncode
import ignite.middleware.{JwtConfig, jwtMiddleware}
import jinguissl.contract.{HashAlgorithm, contractHmac}
import std.time.DateTime

@Test
public class JwtMiddlewareTestSuite {
    @TestCase
    public func testJwtMiddlewareAcceptsValidBearerHs256(): Unit {
        let app = App(config: Config())
        app.use(jwtMiddleware(JwtConfig(
            secret: "ignite-secret",
            requiredIssuer: "ignite",
            requiredAudience: "web"
        )))
        app.get("/secure", { ctx =>
            let sub = ctx.getLocal("jwt_sub") ?? ""
            let claims = ctx.getLocal("jwt_claims") ?? ""
            _ = ctx.sendString("ok:${sub}:${contains(claims, #""role":"admin""#)}")
        })

        let payload = #"{"sub":"u1","iss":"ignite","aud":"web","role":"admin","exp":"# + (nowUnixSeconds() + 300).toString() + #"}"#
        let token = signHs256("ignite-secret", payload)
        let resp = app.handleForTest(
            "GET",
            "/secure",
            headers: [("Authorization", "Bearer " + token)]
        )
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "ok:u1:true")
    }

    @TestCase
    public func testJwtMiddlewareRejectsInvalidSignature(): Unit {
        let app = App(config: Config())
        app.use(jwtMiddleware(JwtConfig(secret: "ignite-secret")))
        app.get("/secure", { ctx => _ = ctx.sendString("ok") })

        let payload = #"{"sub":"u1","exp":"# + (nowUnixSeconds() + 300).toString() + #"}"#
        let badToken = signHs256("wrong-secret", payload)
        let resp = app.handleForTest(
            "GET",
            "/secure",
            headers: [("Authorization", "Bearer " + badToken)]
        )
        @Assert(resp.status, UInt16(401))
        @Assert(contains(resp.header("www-authenticate") ?? "", #""invalid_token""#), true)
    }

    @TestCase
    public func testJwtMiddlewareRejectsExpiredToken(): Unit {
        let app = App(config: Config())
        app.use(jwtMiddleware(JwtConfig(secret: "ignite-secret", clockSkewSec: 0)))
        app.get("/secure", { ctx => _ = ctx.sendString("ok") })

        let payload = #"{"sub":"u1","exp":"# + (nowUnixSeconds() - 10).toString() + #"}"#
        let token = signHs256("ignite-secret", payload)
        let resp = app.handleForTest(
            "GET",
            "/secure",
            headers: [("Authorization", "Bearer " + token)]
        )
        @Assert(resp.status, UInt16(401))
        @Assert(contains(resp.header("www-authenticate") ?? "", #""token_expired""#), true)
    }

    @TestCase
    public func testJwtMiddlewareSupportsQueryToken(): Unit {
        let app = App(config: Config())
        app.use(jwtMiddleware(JwtConfig(
            secret: "ignite-secret",
            queryName: "access_token"
        )))
        app.get("/secure", { ctx =>
            let sub = ctx.getLocal("jwt_sub") ?? ""
            _ = ctx.sendString("ok:${sub}")
        })

        let payload = #"{"sub":"q-user","exp":"# + (nowUnixSeconds() + 120).toString() + #"}"#
        let token = signHs256("ignite-secret", payload)
        let resp = app.handleForTest("GET", "/secure?access_token=${token}")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.body, "ok:q-user")
    }

    func signHs256(secret: String, payloadJson: String): String {
        let headerJson = #"{"alg":"HS256","typ":"JWT"}"#
        let header = base64UrlEncode(headerJson.toArray())
        let payload = base64UrlEncode(payloadJson.toArray())
        let signingInput = header + "." + payload
        let signature = base64UrlEncode(contractHmac(HashAlgorithm.SHA256, secret.toArray(), signingInput.toArray()))
        signingInput + "." + signature
    }

    func nowUnixSeconds(): Int64 {
        DateTime.now().toUnixTimeStamp().toMilliseconds() / 1000
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
