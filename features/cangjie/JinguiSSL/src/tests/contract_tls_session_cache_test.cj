package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractTlsSessionCacheTestSuite {
    @TestCase
    public func testContractTlsSessionCacheStaysLinkable(): Unit {
        let cache = ContractTlsSessionCache(maxEntries: 2, defaultTtlSeconds: 60)
        @Assert(cache.size, 0)

        let stats = cache.stats()
        @Assert(stats.size, 0)
        @Assert(stats.hits, 0)
        @Assert(stats.misses, 0)
        @Assert(stats.evictions, 0)
        @Assert(stats.expiredRemovals, 0)
    }

    @TestCase
    public func testContractTlsSessionCacheRejectsBadCapacity(): Unit {
        try {
            _ = ContractTlsSessionCache(maxEntries: 0, defaultTtlSeconds: 60)
            @Fail("session cache maxEntries=0 should fail through the contract facade")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }
}

