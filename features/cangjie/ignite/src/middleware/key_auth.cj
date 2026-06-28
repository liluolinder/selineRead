package ignite.middleware

import ignite.{Handler, Ctx}

public enum KeyLookup {
    | Header
    | Query
    | Cookie
}

public class KeyAuthConfig {
    public var keyLookup: KeyLookup = Header
    public var keyName: String = "X-API-Key"
    public var validator: (String) -> Bool
    public var contextKey: String = "api_key"

    public init(
        validator: (String) -> Bool,
        keyLookup!: KeyLookup = Header,
        keyName!: String = "X-API-Key",
        contextKey!: String = "api_key"
    ) {
        this.validator = validator
        this.keyLookup = keyLookup
        this.keyName = keyName
        this.contextKey = contextKey
    }
}

public func keyAuthMiddleware(config: KeyAuthConfig): Handler {
    { ctx: Ctx =>
        let key = match (config.keyLookup) {
            case Header => ctx.header(config.keyName) ?? ""
            case Query => ctx.query(config.keyName) ?? ""
            case Cookie => ctx.cookies(config.keyName) ?? ""
        }

        if (key.size == 0) {
            ctx.status(401).sendString("Unauthorized - API key missing")
            return
        }

        if (config.validator(key)) {
            ctx.setLocal(config.contextKey, key)
            ctx.next()
        } else {
            ctx.status(401).sendString("Unauthorized - Invalid API key")
        }
    }
}
