package jinguissl.tests

import jinguissl.live.*

// --- Test: runtime-backed profile catalog aligns with live contract profiles ---
// This test proves the runtime catalog (exposed through the old-live wrapper)
// matches the count and labels of contractListHttpSshStartupProfiles().
// live.cj remains untouched.
// No dependency on jinguissl_core or contract types.

@Test
public class ContractRuntimeStartupProfileCatalogTestSuite {
    private let EXPECTED_COUNT: Int64 = 6
    private let EXPECTED_LABELS: Array<String> = [
        "library-default",
        "http-client-library",
        "http-server-library",
        "ssh-client-library",
        "ssh-server-library",
        "production-accelerated"
    ]

    @TestCase
    public func testRuntimeCatalogHasExpectedCount(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        @Assert(catalog.size, EXPECTED_COUNT)
    }

    @TestCase
    public func testRuntimeCatalogLabelsMatchExpected(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        @Assert(catalog.size, EXPECTED_LABELS.size)
        for (i in 0..catalog.size) {
            @Assert(catalog[i].label, EXPECTED_LABELS[i])
        }
    }

    @TestCase
    public func testRuntimeCatalogAlignsWithContractProfiles(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        let contractProfiles = contractListHttpSshStartupProfiles()
        @Assert(catalog.size, contractProfiles.size)

        // Each runtime catalog label must match the corresponding contract profile label
        for (i in 0..catalog.size) {
            @Assert(catalog[i].label, contractProfiles[i].label)
        }
    }

    @TestCase
    public func testRuntimeCatalogEntriesHaveNonEmptyLabels(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (entry in catalog) {
            @Assert(entry.label.size > 0, true)
        }
    }

    @TestCase
    public func testRuntimeCatalogEntriesHaveNotes(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (entry in catalog) {
            @Assert(entry.notes.size > 0, true)
        }
    }

    @TestCase
    public func testProductionAcceleratedRequiresAcceleration(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        let prod = catalog[5]
        @Assert(prod.label, "production-accelerated")
        @Assert(prod.requiresHttpTls, true)
        @Assert(prod.requiresSsh, true)
        @Assert(prod.requiresX509, true)
        @Assert(prod.requiresAcceleration, true)
    }

    @TestCase
    public func testSshClientLibraryDoesNotRequireHttpTls(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        let sshClient = catalog[3]
        @Assert(sshClient.label, "ssh-client-library")
        @Assert(sshClient.requiresHttpTls, false)
        @Assert(sshClient.requiresSsh, true)
        @Assert(sshClient.requiresX509, false)
        @Assert(sshClient.requiresAcceleration, false)
    }

    @TestCase
    public func testHttpServerLibraryDoesNotRequireSsh(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        let httpServer = catalog[2]
        @Assert(httpServer.label, "http-server-library")
        @Assert(httpServer.requiresHttpTls, true)
        @Assert(httpServer.requiresSsh, false)
        @Assert(httpServer.requiresX509, true)
        @Assert(httpServer.requiresAcceleration, false)
    }

    @TestCase
    public func testAllProfilesRequireRandom(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (entry in catalog) {
            @Assert(entry.requireRandom, true)
        }
    }

    @TestCase
    public func testAllProfilesNoTlsServerConfigBridge(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (entry in catalog) {
            @Assert(entry.requireDirectStdxTlsServerConfigBridge, false)
        }
    }

    @TestCase
    public func testProductionAcceleratedFullPolicy(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        let prod = catalog[5]
        @Assert(prod.label, "production-accelerated")
        @Assert(prod.requireCurrentReleasePrimaryBackend, true)
        @Assert(prod.defaultAesEngineKind, 2)
        @Assert(prod.defaultAesBackendHint, "armv8-ce")
    }

    @TestCase
    public func testNonProductionDefaultAesEngine(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (i in 0..5) {
            @Assert(catalog[i].defaultAesEngineKind, 0)
        }
    }

    @TestCase
    public func testNonProductionNoPrimaryBackend(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (i in 0..5) {
            @Assert(catalog[i].requireCurrentReleasePrimaryBackend, false)
        }
    }

    @TestCase
    public func testNonProductionEmptyAesBackendHint(): Unit {
        let catalog = contractLiveListStartupProfileCatalog()
        for (i in 0..5) {
            @Assert(catalog[i].defaultAesBackendHint, "")
        }
    }
}
