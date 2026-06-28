package ignite.tests

import ignite.api2

@Test
public class ServerStartupFailureSnapshotTestSuite {
    @TestCase
    public func testAddressInUseSnapshot(): Unit {
        let snapshot = api2.serverStartupFailureSnapshot("bind failed: address already in use")

        @Assert(snapshot.stage, "listen_startup")
        @Assert(snapshot.listenErrorCode, "ADDRESS_IN_USE")
        @Assert(snapshot.igniteErrorCode, "LISTEN_ADDRESS_IN_USE")
        @Assert(
            contains(snapshot.hint, "port is already occupied"),
            true
        )
    }

    @TestCase
    public func testPermissionDeniedSnapshot(): Unit {
        let snapshot = api2.serverStartupFailureSnapshot("socket listen failed: permission denied")

        @Assert(snapshot.listenErrorCode, "PERMISSION_DENIED")
        @Assert(snapshot.igniteErrorCode, "LISTEN_PERMISSION_DENIED")
    }

    @TestCase
    public func testAddressUnavailableSnapshot(): Unit {
        let snapshot = api2.serverStartupFailureSnapshot("bind failed: cannot assign requested address")

        @Assert(snapshot.listenErrorCode, "ADDRESS_UNAVAILABLE")
        @Assert(snapshot.igniteErrorCode, "LISTEN_ADDRESS_UNAVAILABLE")
        @Assert(contains(snapshot.hint, "IP changes"), true)
        @Assert(contains(snapshot.hint, "0.0.0.0"), true)
    }

    @TestCase
    public func testBadInputSnapshot(): Unit {
        let snapshot = api2.serverStartupFailureSnapshot("invalid argument: bad address format")

        @Assert(snapshot.listenErrorCode, "BAD_INPUT")
        @Assert(snapshot.igniteErrorCode, "LISTEN_BAD_INPUT")
    }

    @TestCase
    public func testUnknownSnapshotFallsBackToInternalError(): Unit {
        let snapshot = api2.serverStartupFailureSnapshot("unexpected server engine panic")

        @Assert(snapshot.listenErrorCode, "INTERNAL_ERROR")
        @Assert(snapshot.igniteErrorCode, "LISTEN_INTERNAL_ERROR")
    }

    func contains(text: String, target: String): Bool {
        let t = text.toRuneArray()
        let p = target.toRuneArray()
        if (p.size == 0) {
            return true
        }
        if (t.size < p.size) {
            return false
        }
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
            if (ok) {
                return true
            }
            i += 1
        }
        false
    }
}
