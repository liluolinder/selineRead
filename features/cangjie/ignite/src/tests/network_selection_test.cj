package ignite.tests

import ignite.*
import ignite.api2

@Test
public class NetworkSelectionTestSuite {
    @TestCase
    public func testConfigStoresStartupNetworkOptions(): Unit {
        let config = Config(
            startupNetworkMode: api2.StartupNetworkMode.Named,
            startupNetworkInterface: "en7",
            enableNetworkChangeNotice: false
        )

        @Assert(config.startupNetworkMode.toString(), "named")
        @Assert(config.startupNetworkInterface, "en7")
        @Assert(config.enableNetworkChangeNotice, false)
    }

    @TestCase
    public func testAutoSinglePrefersPreferredInterface(): Unit {
        let selection = api2.selectStartupNetwork(buildNetworkInfo())

        @Assert(selection.primaryIP, "10.0.0.8")
        @Assert(selection.matchedInterface, "en7")
        @Assert(selection.displayInterfacePairs[0], "en7=10.0.0.8")
    }

    @TestCase
    public func testMultiIncludesAllVisibleInterfaces(): Unit {
        let selection = api2.selectStartupNetwork(
            buildNetworkInfo(),
            mode: api2.StartupNetworkMode.Multi
        )

        @Assert(selection.displayInterfacePairs.size, 2)
        @Assert(selection.displayInterfacePairs[0], "en7=10.0.0.8")
        @Assert(selection.displayInterfacePairs[1], "en0=192.168.1.20")
    }

    @TestCase
    public func testNamedMissingFallsBackWithWarning(): Unit {
        let selection = api2.selectStartupNetwork(
            buildNetworkInfo(),
            mode: api2.StartupNetworkMode.Named,
            interfaceName: "missing0"
        )

        @Assert(selection.primaryIP, "10.0.0.8")
        @Assert(selection.matchedInterface, "en7")
        @Assert(contains(selection.warning, "requested interface"), true)
    }

    @TestCase
    public func testDirectBindMissingReportsWarning(): Unit {
        let selection = api2.resolveBoundNetworkSelection(
            "192.168.1.55",
            info: buildNetworkInfo()
        )

        @Assert(selection.mode, "direct")
        @Assert(contains(selection.warning, "no longer present"), true)
    }

    func buildNetworkInfo(): api2.NetworkInfo {
        api2.NetworkInfo(
            ["192.168.1.20", "10.0.0.8"],
            None,
            [],
            interfaces: [
                api2.NetworkInterfaceInfo("en0", ["192.168.1.20"]),
                api2.NetworkInterfaceInfo("en7", ["10.0.0.8"])
            ],
            preferredIp: Some("10.0.0.8")
        )
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
