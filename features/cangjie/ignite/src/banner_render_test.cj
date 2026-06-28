package ignite

import ignite.api2

@Test
public class BannerRenderTestSuite {
    @TestCase
    public func testClassicBannerIncludesNetworkLineAndTags(): Unit {
        let config = Config(
            bannerStyle: BannerStyle.Classic,
            bannerColorMode: BannerColorMode.Plain,
            bannerExtraTags: ["Ignite-Core"],
            bannerMaxTagLines: 2
        )

        @Assert(config.bannerStyle.toString(), "classic")
        @Assert(config.bannerColorMode.toString(), "plain")
        @Assert(config.bannerExtraTags[0], "Ignite-Core")

        let lines = renderBannerLines(
            "Ignite-Core 0700 series",
            "0.7.7",
            "http",
            "0.0.0.0",
            UInt16(8080),
            16,
            "16162",
            true,
            true,
            "/swagger",
            true,
            true,
            true,
            api2.StartupNetworkSelection(
                "named",
                "en0",
                "en0",
                "192.168.1.20",
                ["192.168.1.20"],
                ["en0=192.168.1.20"],
                "named:en0"
            ),
            BannerStyle.Classic,
            BannerColorMode.Plain,
            ["Ignite-Core"],
            2
        )

        @Assert(containsLine(lines, "NIC: en0=192.168.1.20"), true)
        @Assert(containsLine(lines, "TLS"), true)
        @Assert(containsLine(lines, "Swagger"), true)
        @Assert(containsLine(lines, "Ignite-Core"), true)
    }

    @TestCase
    public func testRenaissanceBannerPlainLayout(): Unit {
        let lines = renderBannerLines(
            "Ignite Demo",
            "0.7.7",
            "http",
            "0.0.0.0",
            UInt16(8080),
            8,
            "42",
            false,
            false,
            "/swagger",
            false,
            false,
            true,
            api2.StartupNetworkSelection(
                "multi",
                "",
                "en7,en0",
                "10.0.0.8",
                ["10.0.0.8", "192.168.1.20"],
                ["en7=10.0.0.8", "en0=192.168.1.20"],
                "multi"
            ),
            BannerStyle.Renaissance,
            BannerColorMode.Plain,
            [],
            2
        )

        @Assert(lines[0], "Ignite Demo v0.7.7")
        @Assert(containsLine(lines, "(bound on 0.0.0.0:8080)"), true)
        @Assert(containsLine(lines, "NICs: en7=10.0.0.8 | en0=192.168.1.20"), true)
        @Assert(containsLine(lines, "touchpoints: 8   pid: 42"), true)
    }

    func containsLine(lines: Array<String>, target: String): Bool {
        for (line in lines) {
            if (contains(line, target)) {
                return true
            }
        }
        false
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
