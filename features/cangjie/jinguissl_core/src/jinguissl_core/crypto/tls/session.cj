package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.compliance.{TlsVersion}
import jinguissl_core.crypto.digest.bytesToHexLower
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

public let TLS_SESSION_TICKET_VERSION: Int64 = 1
public let TLS_SESSION_DEFAULT_TTL_SECONDS: Int64 = 7200

public class TlsSessionIdentity {
    public let version: TlsVersion
    public let serverName: String
    public let alpnProtocol: String
    public let resumptionId: Array<Byte>

    public init(
        version: TlsVersion,
        resumptionId: Array<Byte>,
        serverName!: String = "",
        alpnProtocol!: String = ""
    ) {
        if (resumptionId.size == 0 || resumptionId.size > 65535) {
            throw CryptoException(InvalidArgument, "TLS session resumption id length is invalid")
        }
        let normalizedServerName = serverName.trimAscii().toAsciiLower()
        let normalizedAlpn = alpnProtocol.trimAscii().toAsciiLower()
        if (normalizedServerName.size > 65535) {
            throw CryptoException(OutOfBounds, "TLS session server_name is too long")
        }
        if (normalizedAlpn.size > 255) {
            throw CryptoException(OutOfBounds, "TLS session ALPN id is too long")
        }
        this.version = version
        this.serverName = normalizedServerName
        this.alpnProtocol = normalizedAlpn
        this.resumptionId = resumptionId.clone()
    }

    public func cacheKey(): String {
        let versionTag = match (version) {
            case TLS1_2 => "tls12"
            case TLS1_3 => "tls13"
        }
        "${versionTag}|${serverName}|${alpnProtocol}|${bytesToHexLower(resumptionId)}"
    }
}

public class TlsSessionTicket {
    public let version: Int64
    public let identity: TlsSessionIdentity
    public let secret: Array<Byte>
    public let nonce: Array<Byte>
    public let issuedAtUnixSeconds: Int64
    public let expiresAtUnixSeconds: Int64

    public init(
        identity: TlsSessionIdentity,
        secret: Array<Byte>,
        nonce: Array<Byte>,
        issuedAtUnixSeconds: Int64,
        expiresAtUnixSeconds: Int64,
        version!: Int64 = TLS_SESSION_TICKET_VERSION
    ) {
        if (version <= 0 || version > 255) {
            throw CryptoException(InvalidArgument, "TLS session ticket version is invalid")
        }
        if (secret.size == 0 || secret.size > 65535) {
            throw CryptoException(InvalidArgument, "TLS session ticket secret length is invalid")
        }
        if (nonce.size > 255) {
            throw CryptoException(OutOfBounds, "TLS session ticket nonce length is too large")
        }
        if (issuedAtUnixSeconds <= 0 || expiresAtUnixSeconds <= issuedAtUnixSeconds) {
            throw CryptoException(InvalidArgument, "TLS session ticket validity window is invalid")
        }
        this.version = version
        this.identity = identity
        this.secret = secret.clone()
        this.nonce = nonce.clone()
        this.issuedAtUnixSeconds = issuedAtUnixSeconds
        this.expiresAtUnixSeconds = expiresAtUnixSeconds
    }

    public func isExpired(nowUnixSeconds: Int64): Bool {
        nowUnixSeconds >= expiresAtUnixSeconds
    }
}

public class TlsSessionCacheStats {
    public let size: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let expiredRemovals: Int64

    public init(size: Int64, hits: Int64, misses: Int64, evictions: Int64, expiredRemovals: Int64) {
        this.size = size
        this.hits = hits
        this.misses = misses
        this.evictions = evictions
        this.expiredRemovals = expiredRemovals
    }
}

public class TlsPooledConnection {
    public let identity: TlsSessionIdentity
    public let recordLayer: TlsAeadRecordLayer
    public let reused: Bool
    public let lastTouchedUnixSeconds: Int64

    public init(
        identity: TlsSessionIdentity,
        recordLayer: TlsAeadRecordLayer,
        reused: Bool,
        lastTouchedUnixSeconds: Int64
    ) {
        this.identity = identity
        this.recordLayer = recordLayer
        this.reused = reused
        this.lastTouchedUnixSeconds = lastTouchedUnixSeconds
    }
}

public class TlsConnectionPoolStats {
    public let idleSize: Int64
    public let created: Int64
    public let reused: Int64
    public let evicted: Int64
    public let expiredPruned: Int64

    public init(idleSize: Int64, created: Int64, reused: Int64, evicted: Int64, expiredPruned: Int64) {
        this.idleSize = idleSize
        this.created = created
        this.reused = reused
        this.evicted = evicted
        this.expiredPruned = expiredPruned
    }
}

/**
 * tlsCreateSessionTicket.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsCreateSessionTicket(
    identity: TlsSessionIdentity,
    secret: Array<Byte>,
    nonce!: Array<Byte> = [],
    nowUnixSeconds!: Int64 = 0,
    ttlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS
): TlsSessionTicket {
    if (ttlSeconds <= 0) {
        throw CryptoException(InvalidArgument, "TLS session ticket TTL must be positive")
    }
    let now = resolveSessionUnixSeconds(nowUnixSeconds)
    TlsSessionTicket(identity, secret, nonce, now, now + ttlSeconds)
}

public func tlsIsSessionTicketExpired(ticket: TlsSessionTicket, nowUnixSeconds!: Int64 = 0): Bool {
    ticket.isExpired(resolveSessionUnixSeconds(nowUnixSeconds))
}

public func tlsEncodeSessionTicket(ticket: TlsSessionTicket): Array<Byte> {
    let serverNameBytes = ticket.identity.serverName.toArray()
    let alpnBytes = ticket.identity.alpnProtocol.toArray()
    let idBytes = ticket.identity.resumptionId
    let secret = ticket.secret
    let nonce = ticket.nonce
    let out = Array<Byte>(
        37 + serverNameBytes.size + alpnBytes.size + idBytes.size + secret.size + nonce.size,
        repeat: 0
    )

    out[0] = UInt8(ticket.version)
    out[1] = tlsEncodeSessionVersionTag(ticket.identity.version)
    encodeUInt16BE(out, 2, serverNameBytes.size)
    out[4] = UInt8(alpnBytes.size)
    encodeUInt16BE(out, 5, idBytes.size)
    encodeUInt16BE(out, 7, secret.size)
    out[9] = UInt8(nonce.size)
    encodeUInt64BE(out, 10, UInt64(ticket.issuedAtUnixSeconds))
    encodeUInt64BE(out, 18, UInt64(ticket.expiresAtUnixSeconds))

    let payloadSize = serverNameBytes.size + alpnBytes.size + idBytes.size + secret.size + nonce.size
    encodeUInt16BE(out, 26, payloadSize)
    out[28] = 0
    out[29] = 0
    out[30] = 0
    out[31] = 0
    out[32] = 0
    out[33] = 0
    out[34] = 0
    out[35] = 0
    out[36] = 0

    var offset = 37
    copyIntoUnchecked(serverNameBytes, out, offset)
    offset += serverNameBytes.size
    copyIntoUnchecked(alpnBytes, out, offset)
    offset += alpnBytes.size
    copyIntoUnchecked(idBytes, out, offset)
    offset += idBytes.size
    copyIntoUnchecked(secret, out, offset)
    offset += secret.size
    copyIntoUnchecked(nonce, out, offset)
    out
}

/**
 * tlsDecodeSessionTicket.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tlsDecodeSessionTicket(encoded: Array<Byte>): TlsSessionTicket {
    if (encoded.size < 37) {
        throw CryptoException(ParseError, "TLS session ticket is too short")
    }

    let ticketVersion = Int64(UInt8(encoded[0]))
    let version = tlsDecodeSessionVersionTag(UInt8(encoded[1]))
    let serverNameLen = decodeUInt16BE(encoded, 2, "TLS session ticket server_name length")
    let alpnLen = Int64(UInt8(encoded[4]))
    let idLen = decodeUInt16BE(encoded, 5, "TLS session ticket resumption_id length")
    let secretLen = decodeUInt16BE(encoded, 7, "TLS session ticket secret length")
    let nonceLen = Int64(UInt8(encoded[9]))
    let issuedAt = Int64(decodeUInt64BE(encoded, 10))
    let expiresAt = Int64(decodeUInt64BE(encoded, 18))
    let payloadLen = decodeUInt16BE(encoded, 26, "TLS session ticket payload length")

    if (
        UInt8(encoded[28]) != UInt8(0) ||
        UInt8(encoded[29]) != UInt8(0) ||
        UInt8(encoded[30]) != UInt8(0) ||
        UInt8(encoded[31]) != UInt8(0) ||
        UInt8(encoded[32]) != UInt8(0) ||
        UInt8(encoded[33]) != UInt8(0) ||
        UInt8(encoded[34]) != UInt8(0) ||
        UInt8(encoded[35]) != UInt8(0) ||
        UInt8(encoded[36]) != UInt8(0)
    ) {
        throw CryptoException(ParseError, "TLS session ticket reserved bytes must be zero")
    }

    let expectedPayloadLen = serverNameLen + alpnLen + idLen + secretLen + nonceLen
    if (payloadLen != expectedPayloadLen) {
        throw CryptoException(ParseError, "TLS session ticket payload length mismatch")
    }
    if (encoded.size != 37 + payloadLen) {
        throw CryptoException(ParseError, "TLS session ticket size mismatch")
    }

    var offset = 37
    let serverName = String.fromUtf8(encoded[offset..(offset + serverNameLen)])
    offset += serverNameLen
    let alpn = String.fromUtf8(encoded[offset..(offset + alpnLen)])
    offset += alpnLen
    let resumptionId = encoded[offset..(offset + idLen)]
    offset += idLen
    let secret = encoded[offset..(offset + secretLen)]
    offset += secretLen
    let nonce = encoded[offset..(offset + nonceLen)]

    let identity = TlsSessionIdentity(version, resumptionId, serverName: serverName, alpnProtocol: alpn)
    TlsSessionTicket(
        identity,
        secret,
        nonce,
        issuedAt,
        expiresAt,
        version: ticketVersion
    )
}

public class TlsSessionCache {
    let _maxEntries: Int64
    let _defaultTtlSeconds: Int64
    let _entries = ArrayList<TlsSessionTicket>()

    var _hits: Int64 = 0
    var _misses: Int64 = 0
    var _evictions: Int64 = 0
    var _expiredRemovals: Int64 = 0

    public init(maxEntries!: Int64 = 1024, defaultTtlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS) {
        if (maxEntries <= 0) {
            throw CryptoException(InvalidArgument, "TLS session cache maxEntries must be positive")
        }
        if (defaultTtlSeconds <= 0) {
            throw CryptoException(InvalidArgument, "TLS session cache default TTL must be positive")
        }
        this._maxEntries = maxEntries
        this._defaultTtlSeconds = defaultTtlSeconds
    }

    public prop size: Int64 {
        get() {
            _entries.size
        }
    }

    public func stats(): TlsSessionCacheStats {
        TlsSessionCacheStats(_entries.size, _hits, _misses, _evictions, _expiredRemovals)
    }

    public func store(ticket: TlsSessionTicket): TlsSessionTicket {
        let key = ticket.identity.cacheKey()
        let (existingIndex, _) = findEntryByKey(key)
        if (existingIndex >= 0) {
            _entries.remove(at: existingIndex)
        }
        _entries.add(ticket)
        trimToCapacity()
        ticket
    }

    public func storeFromSecret(
        identity: TlsSessionIdentity,
        secret: Array<Byte>,
        nonce!: Array<Byte> = [],
        nowUnixSeconds!: Int64 = 0,
        ttlSeconds!: Int64 = 0
    ): TlsSessionTicket {
        let effectiveTtl = if (ttlSeconds > 0) {
            ttlSeconds
        } else {
            _defaultTtlSeconds
        }
        let ticket = tlsCreateSessionTicket(
            identity,
            secret,
            nonce: nonce,
            nowUnixSeconds: nowUnixSeconds,
            ttlSeconds: effectiveTtl
        )
        store(ticket)
    }

    public func load(identity: TlsSessionIdentity, nowUnixSeconds!: Int64 = 0): ?TlsSessionTicket {
        let now = resolveSessionUnixSeconds(nowUnixSeconds)
        let key = identity.cacheKey()
        let (index, found) = findEntryByKey(key)
        if (index < 0) {
            _misses += 1
            return None
        }

        let ticket = match (found) {
            case Some(value) => value
            case None =>
                _misses += 1
                return None
        }
        if (ticket.isExpired(now)) {
            _entries.remove(at: index)
            _expiredRemovals += 1
            _misses += 1
            return None
        }

        _entries.remove(at: index)
        _entries.add(ticket)
        _hits += 1
        Some(ticket)
    }

    public func remove(identity: TlsSessionIdentity): Bool {
        let (index, _) = findEntryByKey(identity.cacheKey())
        if (index < 0) {
            return false
        }
        _entries.remove(at: index)
        true
    }

    public func clear(): Unit {
        while (_entries.size > 0) {
            _entries.remove(at: _entries.size - 1)
        }
    }

    public func purgeExpired(nowUnixSeconds!: Int64 = 0): Int64 {
        let now = resolveSessionUnixSeconds(nowUnixSeconds)
        var removed: Int64 = 0
        var i = _entries.size - 1
        while (i >= 0) {
            if (_entries[i].isExpired(now)) {
                _entries.remove(at: i)
                removed += 1
            }
            i -= 1
        }
        _expiredRemovals += removed
        removed
    }

    private func trimToCapacity(): Unit {
        while (_entries.size > _maxEntries) {
            _entries.remove(at: 0)
            _evictions += 1
        }
    }

    private func findEntryByKey(cacheKey: String): (Int64, ?TlsSessionTicket) {
        var idx: Int64 = 0
        for (entry in _entries) {
            if (entry.identity.cacheKey() == cacheKey) {
                return (idx, Some(entry))
            }
            idx += 1
        }
        (-1, None)
    }
}

private class TlsIdleConnection {
    public let identity: TlsSessionIdentity
    public let recordLayer: TlsAeadRecordLayer
    public let idleSinceUnixSeconds: Int64

    public init(identity: TlsSessionIdentity, recordLayer: TlsAeadRecordLayer, idleSinceUnixSeconds: Int64) {
        this.identity = identity
        this.recordLayer = recordLayer
        this.idleSinceUnixSeconds = idleSinceUnixSeconds
    }
}

public class TlsConnectionPool {
    let _maxIdle: Int64
    let _idleTtlSeconds: Int64
    private let _idleEntries = ArrayList<TlsIdleConnection>()

    var _created: Int64 = 0
    var _reused: Int64 = 0
    var _evicted: Int64 = 0
    var _expiredPruned: Int64 = 0

    public init(maxIdle!: Int64 = 128, idleTtlSeconds!: Int64 = 30) {
        if (maxIdle <= 0) {
            throw CryptoException(InvalidArgument, "TLS connection pool maxIdle must be positive")
        }
        if (idleTtlSeconds <= 0) {
            throw CryptoException(InvalidArgument, "TLS connection pool idle TTL must be positive")
        }
        this._maxIdle = maxIdle
        this._idleTtlSeconds = idleTtlSeconds
    }

    public prop idleSize: Int64 {
        get() {
            _idleEntries.size
        }
    }

    public func stats(): TlsConnectionPoolStats {
        TlsConnectionPoolStats(_idleEntries.size, _created, _reused, _evicted, _expiredPruned)
    }

    public func acquire(
        identity: TlsSessionIdentity,
        factory: () -> TlsAeadRecordLayer,
        nowUnixSeconds!: Int64 = 0
    ): TlsPooledConnection {
        let now = resolveSessionUnixSeconds(nowUnixSeconds)
        pruneIdle(nowUnixSeconds: now)
        let (index, found) = findIdleByKey(identity.cacheKey())
        if (index >= 0) {
            let entry = match (found) {
                case Some(value) => value
                case None =>
                    _created += 1
                    return TlsPooledConnection(identity, factory(), false, now)
            }
            _idleEntries.remove(at: index)
            _reused += 1
            entry.recordLayer.resetSequences()
            return TlsPooledConnection(entry.identity, entry.recordLayer, true, now)
        }

        _created += 1
        TlsPooledConnection(identity, factory(), false, now)
    }

    public func release(connection: TlsPooledConnection, nowUnixSeconds!: Int64 = 0): Unit {
        let now = resolveSessionUnixSeconds(nowUnixSeconds)
        let key = connection.identity.cacheKey()
        let (existingIndex, _) = findIdleByKey(key)
        if (existingIndex >= 0) {
            _idleEntries.remove(at: existingIndex)
        }
        connection.recordLayer.resetSequences()
        _idleEntries.add(TlsIdleConnection(connection.identity, connection.recordLayer, now))
        trimIdleToCapacity()
    }

    public func clear(): Unit {
        while (_idleEntries.size > 0) {
            _idleEntries.remove(at: _idleEntries.size - 1)
        }
    }

    public func pruneIdle(nowUnixSeconds!: Int64 = 0): Int64 {
        let now = resolveSessionUnixSeconds(nowUnixSeconds)
        var removed: Int64 = 0
        var i = _idleEntries.size - 1
        while (i >= 0) {
            if ((now - _idleEntries[i].idleSinceUnixSeconds) > _idleTtlSeconds) {
                _idleEntries.remove(at: i)
                removed += 1
            }
            i -= 1
        }
        _expiredPruned += removed
        removed
    }

    private func trimIdleToCapacity(): Unit {
        while (_idleEntries.size > _maxIdle) {
            _idleEntries.remove(at: 0)
            _evicted += 1
        }
    }

    private func findIdleByKey(cacheKey: String): (Int64, ?TlsIdleConnection) {
        var idx: Int64 = 0
        for (entry in _idleEntries) {
            if (entry.identity.cacheKey() == cacheKey) {
                return (idx, Some(entry))
            }
            idx += 1
        }
        (-1, None)
    }
}

private func resolveSessionUnixSeconds(nowUnixSeconds: Int64): Int64 {
    if (nowUnixSeconds > 0) {
        return nowUnixSeconds
    }
    1
}

private func tlsEncodeSessionVersionTag(version: TlsVersion): UInt8 {
    match (version) {
        case TLS1_2 => UInt8(0x12)
        case TLS1_3 => UInt8(0x13)
    }
}

private func tlsDecodeSessionVersionTag(tag: UInt8): TlsVersion {
    match (Int64(tag)) {
        case 0x12 => TLS1_2
        case 0x13 => TLS1_3
        case _ => throw CryptoException(ParseError, "TLS session ticket version tag is invalid")
    }
}

private func encodeUInt16BE(out: Array<Byte>, offset: Int64, value: Int64): Unit {
    if (value < 0 || value > 65535) {
        throw CryptoException(OutOfBounds, "TLS session uint16 value out of range")
    }
    out[offset] = UInt8((value >> 8) & Int64(0xff))
    out[offset + 1] = UInt8(value & Int64(0xff))
}

private func decodeUInt16BE(input: Array<Byte>, offset: Int64, label: String): Int64 {
    if (offset < 0 || offset + 2 > input.size) {
        throw CryptoException(ParseError, "${label} is out of bounds")
    }
    (Int64(UInt8(input[offset])) << 8) | Int64(UInt8(input[offset + 1]))
}

@OverflowWrapping
private func encodeUInt64BE(out: Array<Byte>, offset: Int64, value: UInt64): Unit {
    out[offset] = UInt8((value >> 56) & UInt64(0xff))
    out[offset + 1] = UInt8((value >> 48) & UInt64(0xff))
    out[offset + 2] = UInt8((value >> 40) & UInt64(0xff))
    out[offset + 3] = UInt8((value >> 32) & UInt64(0xff))
    out[offset + 4] = UInt8((value >> 24) & UInt64(0xff))
    out[offset + 5] = UInt8((value >> 16) & UInt64(0xff))
    out[offset + 6] = UInt8((value >> 8) & UInt64(0xff))
    out[offset + 7] = UInt8(value & UInt64(0xff))
}

@OverflowWrapping
private func decodeUInt64BE(input: Array<Byte>, offset: Int64): UInt64 {
    if (offset < 0 || offset + 8 > input.size) {
        throw CryptoException(ParseError, "TLS session uint64 decode is out of bounds")
    }
    (UInt64(UInt8(input[offset])) << 56) |
    (UInt64(UInt8(input[offset + 1])) << 48) |
    (UInt64(UInt8(input[offset + 2])) << 40) |
    (UInt64(UInt8(input[offset + 3])) << 32) |
    (UInt64(UInt8(input[offset + 4])) << 24) |
    (UInt64(UInt8(input[offset + 5])) << 16) |
    (UInt64(UInt8(input[offset + 6])) << 8) |
    UInt64(UInt8(input[offset + 7]))
}

private func copyIntoUnchecked(src: Array<Byte>, dst: Array<Byte>, offset: Int64): Unit {
    var i = 0
    while (i < src.size) {
        dst[offset + i] = src[i]
        i += 1
    }
}
