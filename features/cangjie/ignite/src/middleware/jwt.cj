package ignite.middleware

import ignite.{Handler, Ctx}
import ignite.binary.base64UrlDecode
import std.collection.ArrayList
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject}
import jinguissl.contract.{HashAlgorithm, contractHmac}

public class JwtConfig {
    public var secret: String
    public var headerName: String = "authorization"
    public var authScheme: String = "Bearer"
    public var queryName: String = ""
    public var cookieName: String = ""
    public var realm: String = "Restricted"
    public var claimsKey: String = "jwt_claims"
    public var subjectKey: String = "jwt_sub"
    public var tokenKey: String = "jwt_token"
    public var requiredIssuer: String = ""
    public var requiredAudience: String = ""
    public var clockSkewSec: Int64 = 30

    public init(
        secret!: String,
        headerName!: String = "authorization",
        authScheme!: String = "Bearer",
        queryName!: String = "",
        cookieName!: String = "",
        realm!: String = "Restricted",
        claimsKey!: String = "jwt_claims",
        subjectKey!: String = "jwt_sub",
        tokenKey!: String = "jwt_token",
        requiredIssuer!: String = "",
        requiredAudience!: String = "",
        clockSkewSec!: Int64 = 30
    ) {
        this.secret = secret
        this.headerName = headerName
        this.authScheme = authScheme
        this.queryName = queryName
        this.cookieName = cookieName
        this.realm = realm
        this.claimsKey = claimsKey
        this.subjectKey = subjectKey
        this.tokenKey = tokenKey
        this.requiredIssuer = requiredIssuer
        this.requiredAudience = requiredAudience
        this.clockSkewSec = clockSkewSec
    }
}

public func jwtMiddleware(config: JwtConfig): Handler {
    let secretBytes = config.secret.toArray()
    let skew = if (config.clockSkewSec < 0) { 0 } else { config.clockSkewSec }
    let issuer = config.requiredIssuer.trimAscii()
    let audience = config.requiredAudience.trimAscii()

    { ctx: Ctx =>
        if (secretBytes.size == 0) {
            rejectJwt(ctx, config.realm, "server_misconfigured", "Unauthorized")
            return
        }

        let token = extractJwtToken(ctx, config)
        if (token.size == 0) {
            rejectJwt(ctx, config.realm, "missing_token", "Unauthorized")
            return
        }

        let parts = splitJwtToken(token)
        if (let Some((headerSegment, payloadSegment, signatureSegment, signingInput)) <- parts) {
            let receivedSig = try {
                base64UrlDecode(signatureSegment)
            } catch (_: Exception) {
                rejectJwt(ctx, config.realm, "invalid_token", "Unauthorized")
                return
            }
            let expectedSig = contractHmac(HashAlgorithm.SHA256, secretBytes, signingInput.toArray())
            if (!constantTimeBytesEqual(expectedSig, receivedSig)) {
                rejectJwt(ctx, config.realm, "invalid_token", "Unauthorized")
                return
            }

            let headerObj = parseJwtObjectSegment(headerSegment)
            let payloadObj = parseJwtObjectSegment(payloadSegment)
            if (let Some(header) <- headerObj) {
                if (let Some(payload) <- payloadObj) {
                    let alg = readJwtString(header, "alg") ?? ""
                    if (alg.trimAscii().toAsciiUpper() != "HS256") {
                        rejectJwt(ctx, config.realm, "unsupported_alg", "Unauthorized")
                        return
                    }

                    let nowSec = nowUnixSeconds()
                    if (!validateTimeClaims(payload, nowSec, skew)) {
                        rejectJwt(ctx, config.realm, "token_expired", "Unauthorized")
                        return
                    }
                    if (issuer.size > 0) {
                        let iss = readJwtString(payload, "iss") ?? ""
                        if (iss != issuer) {
                            rejectJwt(ctx, config.realm, "invalid_issuer", "Unauthorized")
                            return
                        }
                    }
                    if (audience.size > 0) {
                        let aud = readJwtString(payload, "aud") ?? ""
                        if (aud != audience) {
                            rejectJwt(ctx, config.realm, "invalid_audience", "Unauthorized")
                            return
                        }
                    }

                    ctx.setLocal(config.claimsKey, decodeJwtPayloadAsString(payloadSegment) ?? "{}")
                    if (let Some(sub) <- readJwtString(payload, "sub")) {
                        ctx.setLocal(config.subjectKey, sub)
                    }
                    ctx.setLocal(config.tokenKey, token)
                    ctx.next()
                    return
                }
            }
        }

        rejectJwt(ctx, config.realm, "invalid_token", "Unauthorized")
    }
}

func rejectJwt(ctx: Ctx, realm: String, code: String, message: String): Unit {
    let authHeader = #"Bearer realm=""# + escapeJwtHeaderValue(realm) + #"", error=""# + escapeJwtHeaderValue(code) + #"""#
    let _ = ctx.setHeader("WWW-Authenticate", authHeader)
    let _ = ctx.status(401).sendString(message)
}

func escapeJwtHeaderValue(input: String): String {
    var out = ""
    for (r in input.toRuneArray()) {
        if (r == r'"' || r == r'\\') {
            out += "\\"
        }
        out += r.toString()
    }
    out
}

func extractJwtToken(ctx: Ctx, config: JwtConfig): String {
    let headerValue = ctx.header(config.headerName) ?? ""
    let tokenFromHeader = extractTokenFromAuthHeader(headerValue, config.authScheme)
    if (tokenFromHeader.size > 0) {
        return tokenFromHeader
    }
    if (config.queryName.size > 0) {
        let tokenFromQuery = ctx.queryFromUrl(config.queryName) ?? ""
        if (tokenFromQuery.trimAscii().size > 0) {
            return tokenFromQuery.trimAscii()
        }
    }
    if (config.cookieName.size > 0) {
        let tokenFromCookie = ctx.cookies(config.cookieName) ?? ""
        if (tokenFromCookie.trimAscii().size > 0) {
            return tokenFromCookie.trimAscii()
        }
    }
    ""
}

func extractTokenFromAuthHeader(headerValue: String, scheme: String): String {
    let trimmedHeader = headerValue.trimAscii()
    let trimmedScheme = scheme.trimAscii()
    if (trimmedHeader.size == 0 || trimmedScheme.size == 0) {
        return ""
    }
    let prefix = trimmedScheme + " "
    if (!startsWithIgnoreCase(trimmedHeader, prefix)) {
        return ""
    }
    substringByRuneRange(trimmedHeader, prefix.size, trimmedHeader.size).trimAscii()
}

func startsWithIgnoreCase(text: String, prefix: String): Bool {
    let t = text.toRuneArray()
    let p = prefix.toRuneArray()
    if (t.size < p.size) {
        return false
    }
    for (i in 0..p.size) {
        let a = t[i].toString().toAsciiLower()
        let b = p[i].toString().toAsciiLower()
        if (a != b) {
            return false
        }
    }
    true
}

func splitJwtToken(tokenRaw: String): ?(String, String, String, String) {
    let token = tokenRaw.trimAscii()
    if (token.size == 0) {
        return None
    }

    let chars = token.toRuneArray()
    var firstDot: Int64 = -1
    var secondDot: Int64 = -1
    var dotCount: Int64 = 0
    for (i in 0..chars.size) {
        if (chars[i] == r'.') {
            dotCount += 1
            if (firstDot < 0) {
                firstDot = i
            } else if (secondDot < 0) {
                secondDot = i
            }
        }
    }
    if (dotCount != 2 || firstDot <= 0 || secondDot <= firstDot + 1 || secondDot >= chars.size - 1) {
        return None
    }

    let headerSegment = substringByRuneRange(token, 0, firstDot)
    let payloadSegment = substringByRuneRange(token, firstDot + 1, secondDot)
    let signatureSegment = substringByRuneRange(token, secondDot + 1, chars.size)
    let signingInput = headerSegment + "." + payloadSegment
    Some((headerSegment, payloadSegment, signatureSegment, signingInput))
}

func parseJwtObjectSegment(segment: String): ?JsonObject {
    try {
        let decoded = String.fromUtf8(base64UrlDecode(segment))
        Some(JsonValue.fromStr(decoded).asObject())
    } catch (_: Exception) {
        None
    }
}

func decodeJwtPayloadAsString(payloadSegment: String): ?String {
    try {
        Some(String.fromUtf8(base64UrlDecode(payloadSegment)))
    } catch (_: Exception) {
        None
    }
}

func readJwtString(payload: JsonObject, key: String): ?String {
    if (let Some(v) <- payload.get(key)) {
        try {
            return Some(v.asString().getValue())
        } catch (_: Exception) { }
    }
    None
}

func readJwtInt(payload: JsonObject, key: String): ?Int64 {
    if (let Some(v) <- payload.get(key)) {
        try {
            return Some(v.asInt().getValue())
        } catch (_: Exception) { }
        try {
            let s = v.asString().getValue().trimAscii()
            if (let Some(parsed) <- parseInt64Strict(s)) {
                return Some(parsed)
            }
        } catch (_: Exception) { }
    }
    None
}

func validateTimeClaims(payload: JsonObject, nowSec: Int64, skewSec: Int64): Bool {
    if (let Some(exp) <- readJwtInt(payload, "exp")) {
        if (nowSec > exp + skewSec) {
            return false
        }
    }
    if (let Some(nbf) <- readJwtInt(payload, "nbf")) {
        if (nowSec + skewSec < nbf) {
            return false
        }
    }
    if (let Some(iat) <- readJwtInt(payload, "iat")) {
        if (nowSec + skewSec < iat) {
            return false
        }
    }
    true
}

func parseInt64Strict(text: String): ?Int64 {
    if (text.size == 0) {
        return None
    }
    let chars = text.toRuneArray()
    var i: Int64 = 0
    var sign: Int64 = 1
    if (chars[0] == r'-') {
        sign = -1
        i = 1
    } else if (chars[0] == r'+') {
        i = 1
    }
    if (i >= chars.size) {
        return None
    }
    var out: Int64 = 0
    while (i < chars.size) {
        let ch = chars[i]
        if (ch < r'0' || ch > r'9') {
            return None
        }
        out = out * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        i += 1
    }
    Some(out * sign)
}

func nowUnixSeconds(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds() / 1000
}

func constantTimeBytesEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) {
        return false
    }
    var diff: UInt8 = 0
    for (i in 0..a.size) {
        diff = diff | (a[i] ^ b[i])
    }
    diff == UInt8(0)
}

func substringByRuneRange(text: String, start: Int64, end: Int64): String {
    let chars = text.toRuneArray()
    var st = start
    var ed = end
    if (st < 0) { st = 0 }
    if (ed < st) { ed = st }
    if (ed > chars.size) { ed = chars.size }
    var out = ""
    for (i in st..ed) {
        out += chars[i].toString()
    }
    out
}
