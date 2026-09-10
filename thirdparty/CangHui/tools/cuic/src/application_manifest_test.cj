package cuic

import std.fs.{Directory, File, SymbolicLink, exists, removeIfExists}

@Test
func applicationManifestParsesIdentityAssetsSystemsAndScripts(): Unit {
    let manifest = parseApplicationManifest(
        "[application]\n" +
        "name = \"Demo\"\n" +
        "identifier = \"dev.example.demo\"\n" +
        "version = \"1.2.3\"\n" +
        "publisher = \"Celading\"\n\n" +
        "[assets]\n" +
        "application-icon = \"assets/app.png\"\n" +
        "resources = [\"assets/data\", \"assets/i18n\"]\n\n" +
        "[system]\n" +
        "single-instance = true\n" +
        "status-item = false\n" +
        "notifications = true\n" +
        "settings = true\n\n" +
        "[scripts]\n" +
        "check = [\"doctor\", \"test\"]\n"
    )
    @Expect(manifest.name, "Demo")
    @Expect(manifest.identifier, "dev.example.demo")
    @Expect(manifest.applicationIcon, "assets/app.png")
    @Expect(manifest.resources.size, Int64(2))
    @Expect(manifest.notifications)
    validateApplicationManifest(manifest, "")
}

@Test
func applicationManifestParsesReviewedHarmonyProjection(): Unit {
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[harmony]\nsource-roots = [\"src\"]\nexclude = [\"src/generated\"]\n" +
        "target-package = \"dev.example.demo\"\noutput = \".canghui/harmony\"\n" +
        "transforms = [\"replace:package demo=>package demo_harmony\"]\n"
    )
    @Expect(manifest.harmonySourceRoots, ["src"])
    @Expect(manifest.harmonyExclude, ["src/generated"])
    @Expect(manifest.harmonyTargetPackage, "dev.example.demo")
    @Expect(manifest.harmonyOutput, ".canghui/harmony")
    @Expect(manifest.harmonyTransforms.size, Int64(1))
    validateApplicationManifest(manifest, "")
}

@Test
func applicationManifestRejectsUnreviewedHarmonyTransform(): Unit {
    var rejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[harmony]\nsource-roots = [\"src\"]\ntarget-package = \"dev.example.demo\"\n" +
            "transforms = [\"regex:anything\"]\n"
        ), "")
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func applicationManifestRejectsMissingIdentityAndEscapingPaths(): Unit {
    var missingRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nversion = \"1.0.0\"\n"
        ), "")
    } catch (_: CuicError) {
        missingRejected = true
    }
    @Expect(missingRejected)

    var absoluteRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\napplication-icon = \"/tmp/app.png\"\n"
        ), "")
    } catch (_: CuicError) {
        absoluteRejected = true
    }
    @Expect(absoluteRejected)

    var traversalRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\nresources = [\"assets/../secret\"]\n"
        ), "")
    } catch (_: CuicError) {
        traversalRejected = true
    }
    @Expect(traversalRejected)

    var missingAssetRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\nresources = [\"definitely-missing-as-p1-resource\"]\n"
        ), currentDirectory())
    } catch (_: CuicError) {
        missingAssetRejected = true
    }
    @Expect(missingAssetRejected)

    var unsafeNameRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"../Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
        ), "")
    } catch (_: CuicError) {
        unsafeNameRejected = true
    }
    @Expect(unsafeNameRejected)

    for (name in ["Demo:Bad", "CON", "Demo.", " Demo"]) {
        var artifactNameRejected = false
        try {
            validateApplicationManifest(parseApplicationManifest(
                "[application]\nname = \"${name}\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
            ), "")
        } catch (_: CuicError) {
            artifactNameRejected = true
        }
        @Expect(artifactNameRejected)
    }
}

@Test
func applicationManifestRejectsDuplicateRolesAndResourcePaths(): Unit {
    var roleRejected = false
    try {
        let _ = parseApplicationManifest(
            "[application]\nname = \"Demo\"\nname = \"Other\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
        )
    } catch (_: CuicError) {
        roleRejected = true
    }
    @Expect(roleRejected)

    var resourceRejected = false
    try {
        let _ = parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\nresources = [\"assets/data\", \"assets/data\"]\n"
        )
    } catch (_: CuicError) {
        resourceRejected = true
    }
    @Expect(resourceRejected)
}

@Test
func packagingPlanIsDeterministicAndKeepsNativeGatesVisible(): Unit {
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\napplication-icon = \"assets/app.png\"\nresources = []\n" +
        "[system]\nstatus-item = true\nnotifications = true\n"
    )
    validateApplicationManifest(manifest, "")
    let first = renderApplicationPackagingPlanJson(
        applicationPackagingPlanForManifest("/work/demo", "macos", manifest)
    )
    let second = renderApplicationPackagingPlanJson(
        applicationPackagingPlanForManifest("/work/demo", "macos", manifest)
    )
    @Expect(first, second)
    @Expect(first.contains("\"schema\":\"canghui.packaging-plan.v0\""))
    @Expect(first.contains("Info.plist"))
    @Expect(first.contains("native-provider-pending"))
    @Expect(first.contains("status-item-icon-not-declared"))
    @Expect(first.contains("notification-icon-not-declared"))
}

@Test
func initializedManifestIsAValidMinimalApplicationDeclaration(): Unit {
    let manifest = parseApplicationManifest(defaultProjectManifest(packageName: "hello_app"))
    validateApplicationManifest(manifest, "")
    @Expect(manifest.identifier, "dev.canghui.hello_app")
    @Expect(manifest.resources.isEmpty())
}

@Test
func packagingArtifactPreservesMacResourcesAndIconType(): Unit {
    let fixture = joinPath(currentDirectory(), "target/application-packaging-mac-fixture")
    _ = removeIfExists(fixture, recursive: true)
    if (!exists(joinPath(fixture, "assets/data/nested"))) {
        Directory.create(joinPath(fixture, "assets/data/nested"), recursive: true)
    }
    File.writeTo(joinPath(fixture, "assets/app.icns"), [UInt8(1), UInt8(2), UInt8(3)])
    File.writeTo(joinPath(fixture, "assets/data/nested/value.txt"), "value".toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.2.3\"\n" +
        "publisher = \"CangHui\"\n[assets]\napplication-icon = \"assets/app.icns\"\n" +
        "resources = [\"assets/data\"]\n"
    )
    validateApplicationManifest(manifest, fixture)
    let output = joinPath(fixture, "mac-artifact")
    let receipt = writeApplicationPackagingArtifact(
        fixture, "macos", manifest, output, "", "metadata-only", ["unsigned-artifact"]
    )
    @Expect(receipt.artifactKind, "macos-unsigned-app-bundle")
    @Expect(!receipt.executableIncluded)
    @Expect(exists(joinPath(output, "Contents/Info.plist")))
    @Expect(exists(joinPath(output, "Contents/Resources/application.icns")))
    @Expect(exists(joinPath(output, "Contents/Resources/assets/assets/data/nested/value.txt")))
    @Expect(receipt.generatedFiles.contains("Contents/Resources/canghui-packaging-receipt.json"))
    @Expect(!receipt.generatedFiles.contains("canghui-packaging-receipt.json"))
    @Expect(String.fromUtf8(File.readFrom(joinPath(output, "Contents/Info.plist"))).contains("dev.example.demo"))
}

@Test
func packagingArtifactGeneratesWindowsAndLinuxInputTreesWithoutFakeExecutable(): Unit {
    let fixture = joinPath(currentDirectory(), "target/application-packaging-platform-fixture")
    _ = removeIfExists(fixture, recursive: true)
    if (!exists(joinPath(fixture, "assets"))) { Directory.create(joinPath(fixture, "assets"), recursive: true) }
    File.writeTo(joinPath(fixture, "assets/app.png"), [UInt8(4), UInt8(5), UInt8(6)])
    File.writeTo(joinPath(fixture, "assets/data.txt"), "data".toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.2.3\"\n" +
        "publisher = \"CangHui\"\n[assets]\napplication-icon = \"assets/app.png\"\n" +
        "resources = [\"assets/data.txt\"]\n"
    )
    validateApplicationManifest(manifest, fixture)
    let windows = joinPath(fixture, "windows-artifact")
    let windowsReceipt = writeApplicationPackagingArtifact(
        fixture, "windows", manifest, windows, "", "metadata-only", ["unsigned-artifact"]
    )
    @Expect(!windowsReceipt.executableIncluded)
    @Expect(exists(joinPath(windows, "Demo.icon.png")))
    @Expect(exists(joinPath(windows, "Demo.exe.manifest")))
    @Expect(String.fromUtf8(File.readFrom(joinPath(windows, "Demo.version.rc"))).contains("1.2.3"))
    let linux = joinPath(fixture, "linux-artifact")
    let linuxReceipt = writeApplicationPackagingArtifact(
        fixture, "linux", manifest, linux, "", "metadata-only", ["unsigned-artifact"]
    )
    @Expect(!linuxReceipt.executableIncluded)
    @Expect(exists(joinPath(linux, "Demo.desktop")))
    @Expect(exists(joinPath(linux, "share/applications/dev.example.demo.desktop")))
    @Expect(exists(joinPath(linux, "share/icons/hicolor/128x128/apps/dev.example.demo.png")))
    @Expect(String.fromUtf8(File.readFrom(joinPath(linux, "Demo.desktop"))).contains("Exec=\"Demo\""))
}

@Test
func packagingOutputRejectsTraversalAndNonEmptyOverwrite(): Unit {
    let project = joinPath(currentDirectory(), "target/application-packaging-output-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(project, recursive: true)
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
    )
    var traversalRejected = false
    try {
        let _ = resolvePackagingOutputRoot(project, "linux", manifest, "../outside")
    } catch (_: CuicError) {
        traversalRejected = true
    }
    @Expect(traversalRejected)
    let existing = joinPath(project, "non-empty-output")
    if (!exists(existing)) { Directory.create(existing, recursive: true) }
    File.writeTo(joinPath(existing, "keep.txt"), "keep".toArray())
    var overwriteRejected = false
    try {
        ensurePackagingDestinationAvailable(existing)
    } catch (_: CuicError) {
        overwriteRejected = true
    }
    @Expect(overwriteRejected)

    let recursiveResource = joinPath(project, "recursive-resource")
    if (!exists(recursiveResource)) { Directory.create(recursiveResource, recursive: true) }
    let recursiveManifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\nresources = [\"recursive-resource\"]\n"
    )
    var overlapRejected = false
    try {
        ensurePackagingOutputDoesNotOverlapInputs(
            project, joinPath(recursiveResource, "package-output"), recursiveManifest
        )
    } catch (_: CuicError) {
        overlapRejected = true
    }
    @Expect(overlapRejected)
}

@Test
func packagingRejectsSymlinkEscapeForOutputAndAssets(): Unit {
    let fixture = joinPath(currentDirectory(), "target/application-packaging-symlink-fixture")
    _ = removeIfExists(fixture, recursive: true)
    let outside = joinPath(currentDirectory(), "target/application-packaging-symlink-outside")
    _ = removeIfExists(outside, recursive: true)
    Directory.create(fixture, recursive: true)
    Directory.create(outside, recursive: true)

    let outputLink = joinPath(fixture, "linked-output")
    SymbolicLink.create(outputLink, to: outside)
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
    )
    var outputRejected = false
    try {
        let _ = resolvePackagingOutputRoot(fixture, "linux", manifest, "linked-output/result")
    } catch (_: CuicError) {
        outputRejected = true
    }
    @Expect(outputRejected)

    let assetLink = joinPath(fixture, "linked-asset.txt")
    File.writeTo(joinPath(outside, "secret.txt"), "outside".toArray())
    SymbolicLink.create(assetLink, to: joinPath(outside, "secret.txt"))
    let assetManifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\nresources = [\"linked-asset.txt\"]\n"
    )
    var assetRejected = false
    try {
        validateApplicationManifest(assetManifest, fixture)
    } catch (_: CuicError) {
        assetRejected = true
    }
    @Expect(assetRejected)

    let nestedDirectory = joinPath(fixture, "assets")
    Directory.create(nestedDirectory, recursive: true)
    SymbolicLink.create(joinPath(nestedDirectory, "linked-secret.txt"),
        to: joinPath(outside, "secret.txt"))
    let nestedManifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\nresources = [\"assets\"]\n"
    )
    var nestedAssetRejected = false
    try {
        validateApplicationManifest(nestedManifest, fixture)
    } catch (_: CuicError) {
        nestedAssetRejected = true
    }
    @Expect(nestedAssetRejected)

    var nestedCopyRejected = false
    try {
        copyPackagingTree(nestedDirectory, joinPath(fixture, "copy-output"))
    } catch (_: CuicError) {
        nestedCopyRejected = true
    }
    @Expect(nestedCopyRejected)
}
