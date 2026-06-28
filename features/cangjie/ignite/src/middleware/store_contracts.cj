package ignite.middleware

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.sync.Mutex
import std.time.MonoTime
import std.time.DateTime

public interface SessionStoreBackend {
    func get(sessionId: String, key: String): ?String
    func set(sessionId: String, key: String, value: String): Unit
    func delete(sessionId: String, key: String): Unit
    func touch(sessionId: String, nowMs: Int64): Unit
    func cleanupExpired(ttlMs: Int64, nowMs: Int64): Unit
}

public class SessionStore <: SessionStoreBackend {
    let data = ConcurrentHashMap<String, String>()
    let touchedAt = ConcurrentHashMap<String, Int64>()

    public init() {}

    public override func get(sessionId: String, key: String): ?String {
        data.get("${sessionId}:${key}")
    }

    public override func set(sessionId: String, key: String, value: String): Unit {
        data.add("${sessionId}:${key}", value)
        touch(sessionId, sessionNowMsForStore())
    }

    public override func delete(sessionId: String, key: String): Unit {
        data.remove("${sessionId}:${key}")
    }

    public override func touch(sessionId: String, nowMs: Int64): Unit {
        touchedAt.add(sessionId, nowMs)
    }

    public override func cleanupExpired(ttlMs: Int64, nowMs: Int64): Unit {
        if (ttlMs <= 0) {
            return
        }
        let staleSessions = ArrayList<String>()
        for ((sessionId, touchedMs) in touchedAt) {
            if ((nowMs - touchedMs) >= ttlMs) {
                staleSessions.add(sessionId)
            }
        }
        for (sessionId in staleSessions) {
            touchedAt.remove(sessionId)
            removeSessionData(sessionId)
        }
    }

    func removeSessionData(sessionId: String): Unit {
        let prefix = "${sessionId}:"
        let staleKeys = ArrayList<String>()
        for ((entryKey, _value) in data) {
            if (entryKey.startsWith(prefix)) {
                staleKeys.add(entryKey)
            }
        }
        for (entryKey in staleKeys) {
            data.remove(entryKey)
        }
    }
}

public interface CsrfTokenStore {
    func issue(token: String, issuedAtMs: Int64): Unit
    func consume(token: String, nowMs: Int64, ttlMs: Int64): Bool
    func cleanupExpired(nowMs: Int64, ttlMs: Int64): Unit
}

public class MemoryCsrfTokenStore <: CsrfTokenStore {
    let tokens = ConcurrentHashMap<String, Int64>()

    public init() {}

    public override func issue(token: String, issuedAtMs: Int64): Unit {
        tokens.add(token, issuedAtMs)
    }

    public override func consume(token: String, nowMs: Int64, ttlMs: Int64): Bool {
        if (let Some(issuedAtMs) <- tokens.get(token)) {
            if (csrfTokenExpiredForStore(issuedAtMs, nowMs, ttlMs)) {
                tokens.remove(token)
                return false
            }
            tokens.remove(token)
            return true
        }
        false
    }

    public override func cleanupExpired(nowMs: Int64, ttlMs: Int64): Unit {
        if (ttlMs <= 0) {
            return
        }
        let staleTokens = ArrayList<String>()
        for ((token, issuedAtMs) in tokens) {
            if (csrfTokenExpiredForStore(issuedAtMs, nowMs, ttlMs)) {
                staleTokens.add(token)
            }
        }
        for (token in staleTokens) {
            tokens.remove(token)
        }
    }
}

public class RateLimitStoreResult {
    public let count: Int64
    public let resetInMs: Int64
    public let allowed: Bool

    public init(count: Int64, resetInMs: Int64, allowed: Bool) {
        this.count = count
        this.resetInMs = resetInMs
        this.allowed = allowed
    }
}

public interface RateLimitStore {
    func consumeWindowPermit(key: String, now: MonoTime, max: Int64, windowMs: Int64): RateLimitStoreResult
    func cleanupExpired(now: MonoTime, windowMs: Int64): Unit
}

class MemoryRateLimitEntry {
    var count: Int64 = 0
    var resetAt: MonoTime

    init() {
        this.resetAt = MonoTime.now()
    }
}

public class MemoryRateLimitStore <: RateLimitStore {
    let entries = ConcurrentHashMap<String, MemoryRateLimitEntry>()
    let mtx = Mutex()

    public init() {}

    public override func consumeWindowPermit(
        key: String,
        now: MonoTime,
        max: Int64,
        windowMs: Int64
    ): RateLimitStoreResult {
        var count: Int64 = 0
        var resetInMs = windowMs
        var allowed = true
        synchronized(mtx) {
            let entry = if (let Some(existing) <- entries.get(key)) {
                let elapsed = (now - existing.resetAt).toMilliseconds()
                if (elapsed >= windowMs) {
                    existing.count = 0
                    existing.resetAt = now
                }
                existing
            } else {
                let created = MemoryRateLimitEntry()
                created.resetAt = now
                entries.add(key, created)
                created
            }
            entry.count += 1
            count = entry.count
            allowed = entry.count <= max
            let elapsedSinceReset = (now - entry.resetAt).toMilliseconds()
            resetInMs = windowMs - elapsedSinceReset
            if (resetInMs < 0) {
                resetInMs = 0
            }
        }
        RateLimitStoreResult(count, resetInMs, allowed)
    }

    public override func cleanupExpired(now: MonoTime, windowMs: Int64): Unit {
        synchronized(mtx) {
            let staleKeys = ArrayList<String>()
            for ((entryKey, entry) in entries) {
                let elapsed = (now - entry.resetAt).toMilliseconds()
                if (elapsed >= windowMs) {
                    staleKeys.add(entryKey)
                }
            }
            for (entryKey in staleKeys) {
                entries.remove(entryKey)
            }
        }
    }
}

public class ResponseCacheValue {
    public let body: String
    public let contentType: String

    public init(body: String, contentType: String) {
        this.body = body
        this.contentType = contentType
    }
}

public interface ResponseCacheStore {
    func getFresh(key: String, now: MonoTime, expiration: Duration): ?ResponseCacheValue
    func put(key: String, body: String, contentType: String, now: MonoTime): Unit
    func cleanupExpired(now: MonoTime, expiration: Duration): Unit
}

class MemoryResponseCacheEntry {
    let body: String
    let contentType: String
    let createdAt: MonoTime

    init(body: String, contentType: String, createdAt: MonoTime) {
        this.body = body
        this.contentType = contentType
        this.createdAt = createdAt
    }
}

public class MemoryResponseCacheStore <: ResponseCacheStore {
    let entries = ConcurrentHashMap<String, MemoryResponseCacheEntry>()
    let mtx = Mutex()

    public init() {}

    public override func getFresh(
        key: String,
        now: MonoTime,
        expiration: Duration
    ): ?ResponseCacheValue {
        var output: ?ResponseCacheValue = None
        synchronized(mtx) {
            if (let Some(entry) <- entries.get(key)) {
                if ((now - entry.createdAt) < expiration) {
                    output = Some(ResponseCacheValue(entry.body, entry.contentType))
                } else {
                    entries.remove(key)
                }
            }
        }
        output
    }

    public override func put(
        key: String,
        body: String,
        contentType: String,
        now: MonoTime
    ): Unit {
        synchronized(mtx) {
            entries.add(key, MemoryResponseCacheEntry(body, contentType, now))
        }
    }

    public override func cleanupExpired(now: MonoTime, expiration: Duration): Unit {
        synchronized(mtx) {
            let staleKeys = ArrayList<String>()
            for ((entryKey, entry) in entries) {
                if ((now - entry.createdAt) >= expiration) {
                    staleKeys.add(entryKey)
                }
            }
            for (entryKey in staleKeys) {
                entries.remove(entryKey)
            }
        }
    }
}

public class IdempotencyValue {
    public let body: String

    public init(body: String) {
        this.body = body
    }
}

public interface IdempotencyStore {
    func getFresh(key: String, now: MonoTime, lifetime: Duration): ?IdempotencyValue
    func put(key: String, body: String, now: MonoTime): Unit
    func cleanupExpired(now: MonoTime, lifetime: Duration): Unit
}

class MemoryIdempotencyEntry {
    let body: String
    let createdAt: MonoTime

    init(body: String, createdAt: MonoTime) {
        this.body = body
        this.createdAt = createdAt
    }
}

public class MemoryIdempotencyStore <: IdempotencyStore {
    let entries = ConcurrentHashMap<String, MemoryIdempotencyEntry>()
    let mtx = Mutex()

    public init() {}

    public override func getFresh(
        key: String,
        now: MonoTime,
        lifetime: Duration
    ): ?IdempotencyValue {
        var output: ?IdempotencyValue = None
        synchronized(mtx) {
            if (let Some(entry) <- entries.get(key)) {
                if ((now - entry.createdAt) < lifetime) {
                    output = Some(IdempotencyValue(entry.body))
                } else {
                    entries.remove(key)
                }
            }
        }
        output
    }

    public override func put(key: String, body: String, now: MonoTime): Unit {
        synchronized(mtx) {
            entries.add(key, MemoryIdempotencyEntry(body, now))
        }
    }

    public override func cleanupExpired(now: MonoTime, lifetime: Duration): Unit {
        synchronized(mtx) {
            let staleKeys = ArrayList<String>()
            for ((entryKey, entry) in entries) {
                if ((now - entry.createdAt) >= lifetime) {
                    staleKeys.add(entryKey)
                }
            }
            for (entryKey in staleKeys) {
                entries.remove(entryKey)
            }
        }
    }
}

func resolveCsrfTokenStore(store: ?CsrfTokenStore): CsrfTokenStore {
    if (let Some(value) <- store) {
        return value
    }
    MemoryCsrfTokenStore()
}

func resolveRateLimitStore(store: ?RateLimitStore): RateLimitStore {
    if (let Some(value) <- store) {
        return value
    }
    MemoryRateLimitStore()
}

func resolveResponseCacheStore(store: ?ResponseCacheStore): ResponseCacheStore {
    if (let Some(value) <- store) {
        return value
    }
    MemoryResponseCacheStore()
}

func resolveIdempotencyStore(store: ?IdempotencyStore): IdempotencyStore {
    if (let Some(value) <- store) {
        return value
    }
    MemoryIdempotencyStore()
}

func sessionNowMsForStore(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

func csrfTokenExpiredForStore(issuedAtMs: Int64, nowMs: Int64, ttlMs: Int64): Bool {
    if (ttlMs <= 0) {
        return false
    }
    (nowMs - issuedAtMs) >= ttlMs
}
