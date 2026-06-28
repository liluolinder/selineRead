package ignite.middleware

import ignite.{Handler, Ctx}
import ignite.binary.cloneBytes
import ignite.security
import std.collection.HashMap

public type LegacyDecryptWarnHook = (String) -> Unit

public class EncryptCookieConfig {
    public var key: String
    public var keyId: String
    public var keyRing: HashMap<String, Array<UInt8>>
    public var algorithm: String
    public var enableLegacyDecrypt: Bool
    public var legacyDecryptWarn: Bool
    public var legacyDecryptWarnHook: ?LegacyDecryptWarnHook
    public var providerKind: security.SecurityProviderKind
    public var exceptNames: Array<String>

    public init(
        key!: String = "",
        keyId!: String = "k1",
        keyRing!: HashMap<String, Array<UInt8>> = HashMap<String, Array<UInt8>>(),
        algorithm!: String = "AES-256-GCM",
        enableLegacyDecrypt!: Bool = false,
        legacyDecryptWarn!: Bool = false,
        legacyDecryptWarnHook!: ?LegacyDecryptWarnHook = None,
        providerKind!: security.SecurityProviderKind = security.SecurityProviderKind.jinguiSSL,
        exceptNames!: Array<String> = []
    ) {
        this.key = key
        this.keyId = keyId
        this.keyRing = HashMap<String, Array<UInt8>>()
        for ((kid, keyBytes) in keyRing) {
            this.keyRing.add(kid, cloneBytes(keyBytes))
        }
        this.algorithm = algorithm
        this.enableLegacyDecrypt = enableLegacyDecrypt
        this.legacyDecryptWarn = legacyDecryptWarn
        this.legacyDecryptWarnHook = legacyDecryptWarnHook
        this.providerKind = providerKind
        this.exceptNames = exceptNames
    }
}

public func encryptCookieMiddleware(config: EncryptCookieConfig): Handler {
    let secConfig = buildCookieSecurityConfig(config)
    let activeKeyHex = security.bytesToHex(secConfig.activeKey())
    let exceptCsv = joinExceptNames(config.exceptNames)
    let canLegacyDecrypt = config.enableLegacyDecrypt && config.key.size > 0

    { ctx: Ctx =>
        let cookieHeaderOpt = ctx.header("cookie")
        if (let Some(cookieHeader) <- cookieHeaderOpt) {
            let parts = cookieHeader.split(";")
            for (part in parts) {
                let trimmed = part.trimAscii()
                let kv = trimmed.split("=", 2)
                if (kv.size != 2) {
                    continue
                }
                let name = kv[0].trimAscii()
                let value = kv[1].trimAscii()
                if (value.size == 0 || isExceptCookie(config.exceptNames, name)) {
                    continue
                }

                var decrypted: ?String = None
                var usedLegacy = false
                if (security.isCookieEnvelopeV1(value)) {
                    try {
                        decrypted = Some(security.openCookieValueV1(secConfig, value, cookieName: name))
                    } catch (e: security.SecurityException) {
                        security.recordDecryptFailure()
                        markSecurityContext(ctx, "decrypt_failed", e.code.toString(), "encrypt_cookie", "cookie:${name}")
                        if (e.code == security.SecurityErrorCode.DecryptFailed) {
                            security.recordSignatureFailure()
                            markSecurityContext(ctx, "signature_failed", e.code.toString(), "encrypt_cookie", "cookie:${name}")
                        }
                        if (canLegacyDecrypt) {
                            try {
                                decrypted = Some(legacyDecryptValue(value, config.key))
                                usedLegacy = true
                            } catch (_: Exception) {}
                        }
                    }
                } else if (canLegacyDecrypt) {
                    try {
                        decrypted = Some(legacyDecryptValue(value, config.key))
                        usedLegacy = true
                    } catch (_: Exception) {}
                }

                if (let Some(plain) <- decrypted) {
                    if (usedLegacy) {
                        emitLegacyDecryptWarning(config, name)
                    }
                    ctx.setLocal("__ignite_cookie_dec_${name}", plain)
                }
            }
        }

        ctx.setLocal("__ignite_cookie_enc_enabled", "1")
        ctx.setLocal("__ignite_cookie_enc_except", exceptCsv)
        ctx.setLocal("__ignite_cookie_enc_kid", secConfig.activeKid)
        ctx.setLocal("__ignite_cookie_enc_alg", secConfig.aeadAlgorithm)
        ctx.setLocal("__ignite_cookie_enc_provider", secConfig.providerKind.toString())
        ctx.setLocal("__ignite_cookie_enc_key_hex", activeKeyHex)
        ctx.next()
    }
}

public func encryptValue(value: String, key: String): String {
    if (key.size == 0) {
        return value
    }
    let secConfig = buildCookieSecurityConfig(EncryptCookieConfig(key: key))
    try {
        security.sealCookieValueV1(secConfig, value)
    } catch (_: security.SecurityException) {
        legacyEncryptValue(value, key)
    }
}

public func decryptValue(encoded: String, key: String): String {
    if (key.size == 0) {
        return encoded
    }
    if (security.isCookieEnvelopeV1(encoded)) {
        let secConfig = buildCookieSecurityConfig(EncryptCookieConfig(key: key))
        try {
            return security.openCookieValueV1(secConfig, encoded)
        } catch (e: security.SecurityException) {
            security.recordDecryptFailure()
            if (e.code == security.SecurityErrorCode.DecryptFailed) {
                security.recordSignatureFailure()
            }
        }
    }
    legacyDecryptValue(encoded, key)
}

func buildCookieSecurityConfig(config: EncryptCookieConfig): security.SecurityConfig {
    let ring = HashMap<String, Array<UInt8>>()
    for ((kid, keyBytes) in config.keyRing) {
        ring.add(kid, cloneBytes(keyBytes))
    }

    var resolvedKeyId = config.keyId
    if (resolvedKeyId.size == 0) {
        resolvedKeyId = "k1"
    }
    if (config.key.size > 0 && !ring.contains(resolvedKeyId)) {
        ring.add(resolvedKeyId, security.deriveKey32FromString(config.key))
    }
    if (ring.size == 0) {
        ring.add(resolvedKeyId, security.deriveKey32FromString(config.key))
    }
    if (!ring.contains(resolvedKeyId)) {
        resolvedKeyId = firstKeyId(ring) ?? resolvedKeyId
    }

    security.SecurityConfig(
        providerKind: config.providerKind,
        activeKid: resolvedKeyId,
        keyRing: ring,
        aeadAlgorithm: config.algorithm
    )
}

func firstKeyId(ring: HashMap<String, Array<UInt8>>): ?String {
    for ((kid, _key) in ring) {
        return Some(kid)
    }
    None
}

func joinExceptNames(exceptNames: Array<String>): String {
    if (exceptNames.size == 0) {
        return ""
    }
    var first = true
    var out = ""
    for (name in exceptNames) {
        if (!first) {
            out += ","
        }
        first = false
        out += name.trimAscii()
    }
    out
}

func isExceptCookie(exceptNames: Array<String>, name: String): Bool {
    for (item in exceptNames) {
        if (item.trimAscii() == name) {
            return true
        }
    }
    false
}

func emitLegacyDecryptWarning(config: EncryptCookieConfig, cookieName: String): Unit {
    if (!config.legacyDecryptWarn) {
        return
    }
    let message = "[Ignite Security] legacy cookie decrypt path used for cookie=${cookieName}; dual-read migration active"
    if (let Some(hook) <- config.legacyDecryptWarnHook) {
        hook(message)
    } else {
        println(message)
    }
}

func legacyEncryptValue(value: String, key: String): String {
    let vBytes = value.toArray()
    let kBytes = key.toArray()
    let encrypted = xorBytes(vBytes, kBytes)
    base64Encode(encrypted)
}

func legacyDecryptValue(encoded: String, key: String): String {
    let encrypted = base64Decode(encoded)
    let kBytes = key.toArray()
    let decrypted = xorBytes(encrypted, kBytes)
    String.fromUtf8(decrypted)
}

func xorBytes(data: Array<UInt8>, key: Array<UInt8>): Array<UInt8> {
    if (key.size == 0) {
        return data
    }
    let result = Array<UInt8>(data.size, repeat: 0)
    for (i in 0..data.size) {
        result[i] = data[i] ^ key[i % key.size]
    }
    result
}
