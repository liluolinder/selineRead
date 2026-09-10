package chui.system

import std.fs.{Directory, File, SymbolicLink, canonicalize, exists, removeIfExists}
import sdl.Fonts

@Test
func applicationResourcesResolveDeclaredSourceAssetsWithProvenance(): Unit {
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("license", "LICENSE", role: ApplicationResourceRole.License),
        ApplicationResourceDeclaration("ui-font", "assets/fonts/HarmonyOS_Sans_SC.ttf",
            role: ApplicationResourceRole.TextFont, family: "CangHui Test Sans"),
        ApplicationResourceDeclaration("symbols", "packages/symbol-ant/symbols.catalog",
            role: ApplicationResourceRole.SymbolCatalog)
    ], [ApplicationResourceRoot.source(".")])

    let receipt = resources.resolve("license")
    @Expect(receipt.provenance(), "source:license")
    @Expect(receipt.path.endsWith("/LICENSE"))
    @Expect(resources.replay().size, 3)
    let fonts = resources.registerFonts()
    @Expect(fonts.size, 1)
    @Expect(Fonts.isRegistered("CangHui Test Sans"))
    Fonts.unregister("CangHui Test Sans")
}

@Test
func applicationResourcesRejectDuplicateTraversalUndeclaredAndStaleMobileInputs(): Unit {
    var duplicateRejected = false
    try {
        let _ = ApplicationResources([
            ApplicationResourceDeclaration("same", "LICENSE"),
            ApplicationResourceDeclaration("same", "README.md")
        ], [ApplicationResourceRoot.source(".")])
    } catch (_: IllegalArgumentException) { duplicateRejected = true }
    @Expect(duplicateRejected)

    var traversalRejected = false
    try {
        let _ = ApplicationResourceDeclaration("escape", "../LICENSE")
    } catch (_: IllegalArgumentException) { traversalRejected = true }
    @Expect(traversalRejected)

    let source = ApplicationResources([
        ApplicationResourceDeclaration("license", "LICENSE")
    ], [ApplicationResourceRoot.source(".")])
    var undeclaredRejected = false
    try { let _ = source.resolve("secret") } catch (_: IllegalArgumentException) {
        undeclaredRejected = true
    }
    @Expect(undeclaredRejected)

    let mobile = ApplicationResources([
        ApplicationResourceDeclaration("license", "LICENSE")
    ], [ApplicationResourceRoot.mobileRawfile(".", 3)], activeMobileGeneration: Some(4))
    var staleRejected = false
    try { let _ = mobile.resolve("license") } catch (_: IllegalStateException) {
        staleRejected = true
    }
    @Expect(staleRejected)
}

@Test
func applicationResourceRootHelpersMatchCuicPackageLayouts(): Unit {
    @Expect(ApplicationResourceRoot.macBundle("Demo.app").path,
        "Demo.app/Contents/Resources/assets")
    @Expect(ApplicationResourceRoot.windowsPackage("dist/windows").path,
        "dist/windows/assets")
    @Expect(ApplicationResourceRoot.linuxPackage("dist/linux", "dev.cureatex.demo").path,
        "dist/linux/share/dev.cureatex.demo/resources")
}

@Test
func applicationResourcesReplaySourceDesktopPackagesAndMobileRawfile(): Unit {
    let fixture = "target/application-resources-layout-fixture"
    _ = removeIfExists(fixture, recursive: true)
    let paths = [
        fixture + "/source/assets/data",
        fixture + "/Demo.app/Contents/Resources/assets/assets/data",
        fixture + "/windows/assets/assets/data",
        fixture + "/linux/share/dev.example.demo/resources/assets/data",
        fixture + "/mobile/assets/data"
    ]
    for (path in paths) {
        Directory.create(path, recursive: true)
        File.writeTo(path + "/config.bin", [UInt8(1), UInt8(2), UInt8(3)])
    }
    let declaration = ApplicationResourceDeclaration(
        "config", "assets/data/config.bin", role: ApplicationResourceRole.Data)
    let cases = [
        ApplicationResources([declaration], [
            ApplicationResourceRoot.source(fixture + "/source")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.macBundle(fixture + "/Demo.app")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.windowsPackage(fixture + "/windows")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.linuxPackage(fixture + "/linux", "dev.example.demo")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.mobileRawfile(fixture + "/mobile", 7)],
            activeMobileGeneration: Some(7))
    ]
    let expected = [
        "source:config", "macos-bundle:config", "windows-package:config",
        "linux-package:config", "mobile-rawfile:config"
    ]
    var i: Int64 = 0
    while (i < cases.size) {
        @Expect(cases[i].replay()[0].provenance(), expected[i])
        i += 1
    }
}

@Test
func applicationResourcesRejectSymbolicLinkInputs(): Unit {
    let fixture = "target/application-resources-symlink-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture + "/root", recursive: true)
    Directory.create(fixture + "/outside", recursive: true)
    File.writeTo(fixture + "/outside/value.txt", "secret".toArray())
    SymbolicLink.create(fixture + "/root/value.txt",
        to: canonicalize(fixture + "/outside/value.txt").toString())
    @Expect(exists(fixture + "/root/value.txt"))
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("value", "value.txt")
    ], [ApplicationResourceRoot.source(fixture + "/root")])
    var rejected = false
    try { let _ = resources.resolve("value") } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}
