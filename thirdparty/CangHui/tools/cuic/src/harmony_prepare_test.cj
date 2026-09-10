package cuic

import std.fs.{Directory, File, canonicalize, exists, removeIfExists}

@Test
func harmonyProjectionIsDeterministicAndRejectsGeneratedDrift(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-projection-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(joinPath(project, "src"), recursive: true)
    Directory.create(joinPath(project, "assets/data"), recursive: true)
    File.writeTo(joinPath(project, "src/main.cj"),
        "package demo\npublic func message(): String { \"desktop\" }\n".toArray())
    File.writeTo(joinPath(project, "assets/data/value.bin"),
        [UInt8(0), UInt8(1), UInt8(255)])
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\nresources = [\"assets/data\"]\n" +
        "[harmony]\nsource-roots = [\"src\"]\ntarget-package = \"dev.example.demo\"\n" +
        "output = \".canghui/harmony\"\n" +
        "transforms = [\"replace:package demo=>package demo_harmony\"]\n"
    )
    validateApplicationManifest(manifest, project)
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    let first = prepareHarmonyProjection(project, framework, manifest)
    let second = prepareHarmonyProjection(project, framework, manifest)
    @Expect(first, second)
    @Expect(first.contains("\"protocol\":\"canghui.harmony-projection/v1\""))
    @Expect(first.contains("\"outputDigest\":"))
    @Expect(String.fromUtf8(File.readFrom(
        joinPath(project, ".canghui/harmony/cangjie/src/main.cj")))
        .contains("package demo_harmony"))
    @Expect(exists(joinPath(project, ".canghui/harmony/host/CangHuiHost.ets")))
    @Expect(exists(joinPath(project,
        ".canghui/harmony/entry/src/main/resources/rawfile/assets/data/value.bin")))

    let generatedHost = joinPath(project, ".canghui/harmony/host/CangHuiHost.ets")
    let originalHost = File.readFrom(generatedHost)
    File.writeTo(generatedHost, "drift".toArray())
    var driftRejected = false
    try {
        let _ = prepareHarmonyProjection(project, framework, manifest)
    } catch (_: CuicError) {
        driftRejected = true
    }
    @Expect(driftRejected)
    File.writeTo(generatedHost, originalHost)

    File.writeTo(joinPath(project, "src/main.cj"),
        "package demo\npublic func message(): String { \"changed\" }\n".toArray())
    var sourceDriftRejected = false
    try {
        let _ = prepareHarmonyProjection(project, framework, manifest)
    } catch (_: CuicError) {
        sourceDriftRejected = true
    }
    @Expect(sourceDriftRejected)
}

@Test
func harmonyProjectionSupportsMultipleCanonicalSourceRoots(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-projection-multi-root-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(joinPath(project, "src/core"), recursive: true)
    Directory.create(joinPath(project, "feature"), recursive: true)
    Directory.create(joinPath(project, "desktop"), recursive: true)
    File.writeTo(joinPath(project, "src/core/model.cj"), "package model\n".toArray())
    File.writeTo(joinPath(project, "feature/page.cj"), "package page\n".toArray())
    File.writeTo(joinPath(project, "desktop/window.cj"), "package desktop\n".toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Multi\"\nidentifier = \"dev.example.multi\"\nversion = \"1.0.0\"\n" +
        "[harmony]\nsource-roots = [\"src\", \"feature\", \"desktop\"]\n" +
        "exclude = [\"desktop\"]\ntarget-package = \"dev.example.multi\"\n" +
        "output = \"generated/harmony\"\n"
    )
    validateApplicationManifest(manifest, project)
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    let receipt = prepareHarmonyProjection(project, framework, manifest)
    @Expect(receipt.contains("src/core/model.cj"))
    @Expect(receipt.contains("feature/page.cj"))
    @Expect(!receipt.contains("desktop/window.cj"))
    @Expect(prepareHarmonyProjection(project, framework, manifest), receipt)
}

@Test
func harmonyProjectionRefusesForeignOutputDirectory(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-projection-foreign-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(joinPath(project, "src"), recursive: true)
    Directory.create(joinPath(project, ".canghui/harmony"), recursive: true)
    File.writeTo(joinPath(project, "src/main.cj"), "package demo\n".toArray())
    File.writeTo(joinPath(project, ".canghui/harmony/foreign.txt"), "keep".toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[harmony]\nsource-roots = [\"src\"]\ntarget-package = \"dev.example.demo\"\n" +
        "output = \".canghui/harmony\"\n"
    )
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    var rejected = false
    try {
        let _ = prepareHarmonyProjection(project, framework, manifest)
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
    @Expect(String.fromUtf8(File.readFrom(
        joinPath(project, ".canghui/harmony/foreign.txt"))), "keep")
}
