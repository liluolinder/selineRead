package jinguissl_core.tests

import jinguissl_core.crypto.tls.*

@Test
public class TlsSessionTestSuite {
    @TestCase
    public func testSessionTicketEncodeDecodeRoundTrip(): Unit {
        let identity = TlsSessionIdentity(
            TLS1_3,
            "ticket-001".toArray(),
            serverName: TEST_HOST_API,
            alpnProtocol: "h2"
        )
        let ticket = tlsCreateSessionTicket(
            identity,
            "shared-secret-material".toArray(),
            nonce: "nonce-v1".toArray(),
            nowUnixSeconds: 1000,
            ttlSeconds: 120
        )

        let encoded = tlsEncodeSessionTicket(ticket)
        let decoded = tlsDecodeSessionTicket(encoded)
        @Assert(decoded.version, TLS_SESSION_TICKET_VERSION)
        @Assert(decoded.identity.version.toString(), "TLS1.3")
        @Assert(decoded.identity.serverName, TEST_HOST_API)
        @Assert(decoded.identity.alpnProtocol, "h2")
        @Assert(decoded.identity.resumptionId, "ticket-001".toArray())
        @Assert(decoded.secret, "shared-secret-material".toArray())
        @Assert(decoded.nonce, "nonce-v1".toArray())
        @Assert(decoded.issuedAtUnixSeconds, 1000)
        @Assert(decoded.expiresAtUnixSeconds, 1120)
        @Assert(tlsIsSessionTicketExpired(decoded, nowUnixSeconds: 1119), false)
        @Assert(tlsIsSessionTicketExpired(decoded, nowUnixSeconds: 1120), true)
    }

    @TestCase
    public func testSessionCacheStoreLoadAndEviction(): Unit {
        let cache = TlsSessionCache(maxEntries: 2, defaultTtlSeconds: 60)
        let id1 = TlsSessionIdentity(TLS1_3, "id-1".toArray(), serverName: "a.example", alpnProtocol: "h2")
        let id2 = TlsSessionIdentity(TLS1_3, "id-2".toArray(), serverName: "a.example", alpnProtocol: "h2")
        let id3 = TlsSessionIdentity(TLS1_3, "id-3".toArray(), serverName: "a.example", alpnProtocol: "h2")

        _ = cache.storeFromSecret(id1, "secret-1".toArray(), nowUnixSeconds: 10)
        _ = cache.storeFromSecret(id2, "secret-2".toArray(), nowUnixSeconds: 10)
        if (let Some(hit1) <- cache.load(id1, nowUnixSeconds: 11)) {
            @Assert(hit1.secret, "secret-1".toArray())
        } else {
            @Fail("id1 should be loaded from session cache")
        }

        _ = cache.storeFromSecret(id3, "secret-3".toArray(), nowUnixSeconds: 12)
        @Assert(cache.size, 2)

        if (let Some(_) <- cache.load(id2, nowUnixSeconds: 13)) {
            @Fail("id2 should be evicted as least recently used entry")
        }
        if (let Some(hit3) <- cache.load(id3, nowUnixSeconds: 13)) {
            @Assert(hit3.secret, "secret-3".toArray())
        } else {
            @Fail("id3 should be present in session cache")
        }
        if (let Some(hit1Again) <- cache.load(id1, nowUnixSeconds: 13)) {
            @Assert(hit1Again.secret, "secret-1".toArray())
        } else {
            @Fail("id1 should still be present after LRU eviction")
        }

        let stats = cache.stats()
        @Assert(stats.size, 2)
        @Assert(stats.hits >= 3, true)
        @Assert(stats.evictions >= 1, true)
    }

    @TestCase
    public func testSessionCacheExpiryAndPurge(): Unit {
        let cache = TlsSessionCache(maxEntries: 4, defaultTtlSeconds: 5)
        let id = TlsSessionIdentity(TLS1_2, "exp-1".toArray(), serverName: "b.example", alpnProtocol: "http/1.1")
        _ = cache.storeFromSecret(id, "master-secret".toArray(), nowUnixSeconds: 100)

        if (let Some(hit) <- cache.load(id, nowUnixSeconds: 104)) {
            @Assert(hit.identity.version.toString(), "TLS1.2")
        } else {
            @Fail("session should not expire before TTL boundary")
        }

        if (let Some(_) <- cache.load(id, nowUnixSeconds: 106)) {
            @Fail("session should expire after TTL boundary")
        }
        @Assert(cache.size, 0)

        let id2 = TlsSessionIdentity(TLS1_3, "exp-2".toArray(), serverName: "b.example", alpnProtocol: "h2")
        let id3 = TlsSessionIdentity(TLS1_3, "exp-3".toArray(), serverName: "b.example", alpnProtocol: "h2")
        _ = cache.storeFromSecret(id2, "secret-2".toArray(), nowUnixSeconds: 200, ttlSeconds: 3)
        _ = cache.storeFromSecret(id3, "secret-3".toArray(), nowUnixSeconds: 200, ttlSeconds: 12)
        let purged = cache.purgeExpired(nowUnixSeconds: 205)
        @Assert(purged, 1)
        @Assert(cache.size, 1)
    }

    @TestCase
    public func testConnectionPoolAcquireReleaseAndReuse(): Unit {
        let pool = TlsConnectionPool(maxIdle: 2, idleTtlSeconds: 30)
        let id = TlsSessionIdentity(TLS1_3, "conn-1".toArray(), serverName: "api.example", alpnProtocol: "h2")

        let first = pool.acquire(
            id,
            { =>
                TlsAeadRecordLayer(sequenceBytes(16), sequenceBytes(12), version: TLS1_3)
            },
            nowUnixSeconds: 100
        )
        @Assert(first.reused, false)
        @Assert(pool.stats().created, 1)
        pool.release(first, nowUnixSeconds: 101)
        @Assert(pool.idleSize, 1)

        let second = pool.acquire(
            id,
            { =>
                TlsAeadRecordLayer(sequenceBytes(16), sequenceBytes(12), version: TLS1_3)
            },
            nowUnixSeconds: 102
        )
        @Assert(second.reused, true)
        @Assert(pool.stats().created, 1)
        pool.release(second, nowUnixSeconds: 103)
        @Assert(pool.idleSize, 1)

        let stats = pool.stats()
        @Assert(stats.reused >= 1, true)
        @Assert(stats.created, 1)
    }

    @TestCase
    public func testConnectionPoolEvictionAndPrune(): Unit {
        let pool = TlsConnectionPool(maxIdle: 1, idleTtlSeconds: 5)
        let id1 = TlsSessionIdentity(TLS1_3, "pool-a".toArray(), serverName: "api.example", alpnProtocol: "h2")
        let id2 = TlsSessionIdentity(TLS1_3, "pool-b".toArray(), serverName: "api.example", alpnProtocol: "h2")

        let conn1 = pool.acquire(
            id1,
            { =>
                TlsAeadRecordLayer(sequenceBytes(16), sequenceBytes(12), version: TLS1_3)
            },
            nowUnixSeconds: 100
        )
        pool.release(conn1, nowUnixSeconds: 101)
        @Assert(pool.idleSize, 1)

        let conn2 = pool.acquire(
            id2,
            { =>
                TlsAeadRecordLayer(sequenceBytes(16), sequenceBytes(12), version: TLS1_3)
            },
            nowUnixSeconds: 102
        )
        pool.release(conn2, nowUnixSeconds: 103)
        @Assert(pool.idleSize, 1)

        let removed = pool.pruneIdle(nowUnixSeconds: 110)
        @Assert(removed, 1)
        @Assert(pool.idleSize, 0)
        let stats = pool.stats()
        @Assert(stats.evicted >= 1, true)
        @Assert(stats.expiredPruned >= 1, true)
    }
}

private func sequenceBytes(size: Int64): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8(i & 0xff)
        i += 1
    }
    out
}
