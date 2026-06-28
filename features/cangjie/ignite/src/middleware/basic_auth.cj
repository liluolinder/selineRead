package ignite.middleware

import ignite.{Handler, Ctx}

public class BasicAuthConfig {
    public var realm: String = "Restricted"
    public var validator: (String, String) -> Bool

    public init(validator: (String, String) -> Bool, realm!: String = "Restricted") {
        this.validator = validator
        this.realm = realm
    }
}

public func basicAuthMiddleware(config: BasicAuthConfig): Handler {
    { ctx: Ctx =>
        let authHeader = ctx.header("authorization") ?? ""
        if (!strStartsWith(authHeader, "Basic ")) {
            ctx.setHeader("WWW-Authenticate", "Basic realm=\"${config.realm}\"")
            ctx.status(401).sendString("Unauthorized")
            return
        }

        let encoded = substringFrom(authHeader, 6)
        let decoded = String.fromUtf8(base64Decode(encoded))
        let sepIdx = findChar(decoded, r':')
        if (sepIdx < 0) {
            ctx.setHeader("WWW-Authenticate", "Basic realm=\"${config.realm}\"")
            ctx.status(401).sendString("Unauthorized")
            return
        }

        let runes = decoded.toRuneArray()
        var username = ""
        for (i in 0..sepIdx) {
            username += runes[i].toString()
        }
        var credentialPart = ""
        for (i in (sepIdx + 1)..runes.size) {
            credentialPart += runes[i].toString()
        }

        if (config.validator(username, credentialPart)) {
            ctx.setLocal("username", username)
            ctx.next()
        } else {
            ctx.setHeader("WWW-Authenticate", "Basic realm=\"${config.realm}\"")
            ctx.status(401).sendString("Unauthorized")
        }
    }
}

func findChar(s: String, ch: Rune): Int64 {
    let runes = s.toRuneArray()
    for (i in 0..runes.size) {
        if (runes[i] == ch) { return i }
    }
    -1
}
