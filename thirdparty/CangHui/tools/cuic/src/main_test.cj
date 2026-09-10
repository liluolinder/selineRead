package cuic

import std.fs.{Directory, File, removeIfExists}

@When[debug]
@Test
func debugTestBuildCarriesPrivilegedDebugGate(): Unit {
    @Expect(debugChannelBuildEnabled())
    @Expect(debugChannelBuildMarker(), "CANGHUI_PRIVILEGED_DEBUG_BUILD=1")
}

@When[!debug]
@Test
func releaseTestBuildRefusesPrivilegedDebugGate(): Unit {
    @Expect(!debugChannelBuildEnabled())
    @Expect(debugChannelBuildMarker(), "")
    var refused = false
    try {
        requireDebugChannelBuild("test operation")
    } catch (error: CuicError) {
        refused = containsText(error.message, "unavailable in release cuic")
    }
    @Expect(refused)
}

@Test
func versionCarriesAnHonestBuildIdentity(): Unit {
    @Expect(renderCuicVersion(), "cuic 0.6.0 (development@unembedded)")
}

@Test
func platformAliasesNormalize(): Unit {
    @Expect(normalizePlatform("mac"), "macos")
    @Expect(normalizePlatform("darwin"), "macos")
    @Expect(normalizePlatform("win"), "windows")
    @Expect(normalizePlatform("linux"), "linux")
}

@Test
func implicitRunPrefersCurrentProjectBeforeExampleFallback(): Unit {
    @Expect(implicitProjectRequest("notepad", true), "")
    @Expect(implicitProjectRequest("notepad", false), "notepad")
}

@Test
func pathHelpersKeepRootAndBasenameStable(): Unit {
    @Expect(joinPath("/tmp/root/", "/child"), "/tmp/root/child")
    @Expect(parentPath("/tmp/root/child"), "/tmp/root")
    @Expect(basename("/tmp/root/child/"), "child")
}

@Test
func prntResolvesTheBuiltExecutableWithoutCjpmRunArgumentForwarding(): Unit {
    @Expect(builtExecutablePath("/tmp/demo/target", "release"), "/tmp/demo/target/release/bin/main")
    @Expect(builtExecutablePath("/tmp/demo/target", "debug"), "/tmp/demo/target/debug/bin/main")
    @Expect(builtExecutableCandidates("C:\\demo/target", "release")[1],
        "C:\\demo/target/release/bin/main.exe")
}

@Test
func prntCaptureFramesRequireAPositiveInteger(): Unit {
    @Expect(parseCaptureFrames("12"), UInt64(12))
    var rejected = false
    try {
        let _ = parseCaptureFrames("0")
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func prntResolvesTheMatchingCangjieRuntimeDirectory(): Unit {
    @Expect(cangjieRuntimeLibraryCandidate("/opt/cangjie", "macos", "arm64"),
        "/opt/cangjie/runtime/lib/darwin_aarch64_cjnative")
    @Expect(cangjieRuntimeLibraryCandidate("C:\\Cangjie", "windows", "AMD64"),
        "C:\\Cangjie/runtime/lib/windows_x86_64_cjnative")
    @Expect(cangjieRuntimeLibraryCandidate("/opt/cangjie", "linux", "aarch64"),
        "/opt/cangjie/runtime/lib/linux_aarch64_cjnative")
    @Expect(cangjieRuntimeLibraryName("macos"), "libcangjie-runtime.dylib")
    @Expect(cangjieRuntimeLibraryName("linux"), "libcangjie-runtime.so")
    @Expect(resolveCangjieHome("/sdk/cangjie/", "/ignored/bin/cjc"), "/sdk/cangjie")
    @Expect(resolveCangjieHome("", "/opt/cangjie/bin/cjc"), "/opt/cangjie")
}

@Test
func prntMacCapturePinsOneCangjieProcessorByDefault(): Unit {
    if (hostPlatform() != "macos") {
        return
    }
    let environment = applicationEnvironment("/tmp/canghui", "/tmp/capture.bmp", UInt64(2))
    @Expect(environment.get("cjProcessorNum") ?? "", "1")
    @Expect(shouldPinMacCaptureProcessor("macos", ""))
    @Expect(!shouldPinMacCaptureProcessor("macos", "2"))
    @Expect(!shouldPinMacCaptureProcessor("linux", ""))
}

@Test
func packageNamesAreCompilerFriendly(): Unit {
    @Expect(sanitizePackageName("Hello-CangUI"), "hello_cangui")
    @Expect(sanitizePackageName("2026 Demo"), "app_2026_demo")
}

@Test
func windowsAbsolutePathsAreRecognized(): Unit {
    @Expect(isWindowsAbsolute("C:\\work\\CangHui"))
    @Expect(!isWindowsAbsolute("examples/notepad"))
}

@Test
func windowsCjpmUsesLiteralArgvAndEnvironmentWithoutCmdExpansion(): Unit {
    let environment = windowsCjpmEnvironment(
        "C:\\sdk&echo injected\\sdl",
        "C:\\fonts\\Harmony%PATH%.ttf"
    )
    let pathValue = environment.get("PATH") ?? ""
    let fontValue = environment.get("CANGHUI_HARMONYOS_SANS") ?? ""
    @Expect(startsWithText(pathValue, "C:\\sdk&echo injected\\sdl;"))
    @Expect(fontValue, "C:\\fonts\\Harmony%PATH%.ttf")

    let args = cjpmArgsWithTarget(
        ["build", "--name", "demo & echo injected", "%UNTRUSTED%"],
        "C:\\target|next"
    )
    @Expect(args[2], "demo & echo injected")
    @Expect(args[3], "%UNTRUSTED%")
    @Expect(args[5], "C:\\target|next")
}

@Test
func harmonyFontCandidatesPreferInstalledMacFont(): Unit {
    let candidates = installedHarmonyFontCandidates("macos", "/Users/demo")
    @Expect(candidates[0], "/Users/demo/Library/Fonts/HarmonyOS_Sans_SC.ttf")
    @Expect(candidates[1], "/Users/demo/Library/Fonts/HarmonyOS Sans SC.ttf")
}

@Test
func bundledHarmonyFontIsTheDefaultCliResolution(): Unit {
    @Expect(resolveHarmonyFont("macos"), bundledHarmonyFont())
}

@Test
func kModeLinkScannerAcceptsOnlyCanonicalSingleLineForm(): Unit {
    @Expect(extractKModeLinkEndpoint("@KModeLink[\"app.echo\"]") ?? "", "app.echo")
    @Expect(extractKModeLinkEndpoint("  @KModeLink[\"app.version\"]  ") ?? "", "app.version")
    @Expect(extractKModeLinkEndpoint("@KModeLink [\"app.bad\"]").isNone())
    @Expect(extractKModeLinkEndpoint("// @KModeLink[\"app.comment\"]").isNone())
}

@Test
func probeScannerAcceptsOnlyCanonicalSingleLineForm(): Unit {
    @Expect(extractCuiProbeEndpoint("@CuiProbe[\"app.button\"]") ?? "", "app.button")
    @Expect(extractCuiProbeEndpoint("  @CuiProbe[\"app.version\"]  ") ?? "", "app.version")
    @Expect(extractCuiProbeEndpoint("@CuiProbe [\"app.bad\"]").isNone())
    @Expect(extractCuiProbeEndpoint("// @CuiProbe[\"app.comment\"]").isNone())
}

@Test
func kModeWireCodecPreservesUtf8AndPipes(): Unit {
    let encoded = encodeCuicKModeRequest(9, "invoke", "app.echo", "仓颉|ready")
    @Expect(containsText(encoded, "仓颉"), false)
    let response = decodeCuicKModeResponse(
        "canghui.kmode.v0|9|1|6f6b|" + encodeCuicKModeText("完成|ok") + "|0|"
    )
    @Expect(response.id, Int64(9))
    @Expect(response.payload, "完成|ok")
}

@Test
func kModeLauncherNoiseAllowsKnownCjpmPreambleOnly(): Unit {
    @Expect(isKModeLauncherNoise(""))
    @Expect(isKModeLauncherNoise("cjpm build success"))
    @Expect(isKModeLauncherNoise(
        "Warning: the functionality of 'CJPM_CONFIG' will be deprecated, please use cangjie-repo.toml"
    ))
    @Expect(isKModeLauncherNoise(
        "Warning: field 'profile.build.combined' in '/tmp/project/core/cjpm.toml' is experimental"
    ))
    @Expect(isKModeLauncherNoise(
        "Warning: field 'profile.build.combined' only supports 'Linux/OHOS/Windows'"
    ))
    @Expect(isKModeLauncherNoise(
        "Warning: there is no '.cj' file in directory '/tmp/project/datalog', and its subdirectories will not be scanned as source code"
    ))
    @Expect(!isKModeLauncherNoise(
        "Warning: there is no '.cj' file in directory '', and its subdirectories will not be scanned as source code"
    ))
    @Expect(!isKModeLauncherNoise(
        "Warning: there is no '.cj' file in directory '/tmp/project/datalog'"
    ))
    @Expect(!isKModeLauncherNoise(
        "Warning: there is no '.cj' file in directory '/tmp/project/datalog', and its subdirectories will not be scanned as source code; application output"
    ))
    @Expect(!isKModeLauncherNoise("application wrote unexpected stdout"))
}

@Test
func uiShellParsesBoundedOneShotActions(): Unit {
    let click = parseUiShellSelection(["cuic", "shell", "click", "12.5", "30"], 2)
    let focus = parseUiShellSelection(["cuic", "shell", "focus", "search-field"], 2)

    @Expect(click.script, "click 12.5 30")
    @Expect(focus.script, "focus search-field")
}

@Test
func kModeDependencyScannerStaysInsideDependencySections(): Unit {
    let paths = kModeLocalDependencyPaths(
        "[package]\n" +
        "description = \"path = not-a-dependency\"\n" +
        "[dependencies]\n" +
        "chui = { path = \"../CangHui\" }\n" +
        "[profile]\n" +
        "output-path = \"ignored\"\n"
    )
    @Expect(paths.size, 1)
    @Expect(paths[0], "../CangHui")
}

@Test
func integratedFrameworkRootWinsBeforeCompatibilityAliases(): Unit {
    let root = integratedFrameworkRoot()
    @Expect(root.size > 0)
    @Expect(frameworkRootCandidate(root))
}

@Test
func consumerDependencyRootWinsOverIntegratedCheckout(): Unit {
    let fixture = "/tmp/cuic-consumer-root-${currentPid()}"
    let project = joinPath(fixture, "consumer")
    let framework = joinPath(fixture, "framework")
    _ = removeIfExists(fixture, recursive: true)
    try {
        Directory.create(joinPath(framework, "sdl"), recursive: true)
        Directory.create(joinPath(framework, "src"), recursive: true)
        Directory.create(project, recursive: true)
        File.writeTo(joinPath(framework, "cjpm.toml"), "[package]\nname = \"chui\"\n".toArray())
        File.writeTo(joinPath(framework, "src/chui.cj"), "package chui\n".toArray())
        File.writeTo(joinPath(project, "cjpm.toml"),
            ("[dependencies]\nchui = { path = \"${framework}\" }\n").toArray())
        @Expect(resolveFrameworkRoot(project), framework)
    } finally {
        _ = removeIfExists(fixture, recursive: true)
    }
}

@Test
func probeTargetParserPreservesScriptAndJsonMode(): Unit {
    let parsed = parseProbeTarget(
        ["cuic", "probe", "run", "component-gallery", "gallery.primary-button",
            "--events", "move-in 10 10\npress 10 10", "--json"],
        3,
        true
    )
    @Expect(parsed.name, "gallery.primary-button")
    @Expect(parsed.script, "move-in 10 10\npress 10 10")
    @Expect(parsed.json)
    @Expect(parsed.project.endsWith("/examples/component-gallery"))
}

@Test
func probeTargetParserAcceptsBoundedAsciiDimensions(): Unit {
    let parsed = parseProbeTarget(
        ["cuic", "probe", "ascii", "component-gallery", "gallery.primary-button",
            "--columns", "72", "--rows", "24", "--events", "draw"],
        3,
        true,
        allowAscii: true
    )
    @Expect(parsed.name, "gallery.primary-button")
    @Expect(parsed.columns, Int64(72))
    @Expect(parsed.rows, Int64(24))
    @Expect(parsed.script, "draw")
}

@Test
func remoteDependencyRenderingPinsPublicCommitWithoutLocalPath(): Unit {
    let rendered = renderFrameworkDependency(defaultFrameworkDependencySpec())
    @Expect(rendered.contains("git = \"https://github.com/Celading/CangHui.git\""))
    @Expect(rendered.contains("commitId = \"a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02\""))
    @Expect(rendered.contains("/Users/"), false)
}

@Test
func inlineDependencyParserSeparatesGitCommitAndPathFields(): Unit {
    let remote = "chui = { git = \"https://example/CangHui.git\", commitId = \"abc123\" }"
    @Expect(extractInlineTomlString(remote, "git"), "https://example/CangHui.git")
    @Expect(extractInlineTomlString(remote, "commitId"), "abc123")
    @Expect(extractInlineTomlString(remote, "path"), "")
    let local = "chui = { path = \"../CangHui\" }"
    @Expect(extractInlineTomlString(local, "path"), "../CangHui")
}

@Test
func dependencyLockPolicyRejectsMissingAndMismatchedGitLocks(): Unit {
    let local = FrameworkDependencySpec("../CangHui", "", "")
    @Expect(frameworkDependencyLockProblem(local, ""), "")

    let remote = FrameworkDependencySpec("", "https://example/CangHui.git", "abc123")
    @Expect(frameworkDependencyLockProblem(remote, ""),
        "The CangHui dependency lock is missing.")
    @Expect(frameworkDependencyLockProblem(remote, "def456").contains("manifest abc123, lock def456"))
    @Expect(frameworkDependencyLockProblem(remote, "abc123"), "")

    let unpinned = FrameworkDependencySpec("", "https://example/CangHui.git", "")
    @Expect(frameworkDependencyLockProblem(unpinned, "abc123"),
        "The CangHui Git dependency must declare an exact commitId.")
}

@Test
func cjpmCachePathsExpandHomeForms(): Unit {
    @Expect(expandHomePath("$" + "{HOME}/cache", "/Users/demo"), "/Users/demo/cache")
    @Expect(expandHomePath("$HOME/cache", "/Users/demo"), "/Users/demo/cache")
    @Expect(expandHomePath("~/cache", "/Users/demo"), "/Users/demo/cache")
}

@Test
func repositoryCacheParserHonorsTheCjpmCacheSection(): Unit {
    let configured = repositoryCachePathFromText(
        "[repository.home]\n" +
        "registry = \"https://example.invalid\"\n" +
        "[repository.cache]\n" +
        "path = \"$" + "{HOME}/project-cache\"\n",
        "/Users/demo"
    )
    @Expect(configured, "/Users/demo/project-cache")
}

@Test
func projectScriptManifestParsesPortablePipelines(): Unit {
    let scripts = parseProjectScripts(
        "[application]\nname = \"demo\"\n\n" +
        "[scripts]\n" +
        "check = [\"doctor --verbose\", \"test\", \"build\"]\n" +
        "snapshot-ui = [\"prnt --output \\\"dist/ui preview.png\\\"\"] # portable\n"
    )
    @Expect(scripts.size, 2)
    @Expect(scripts[0].name, "check")
    @Expect(scripts[0].steps.size, 3)
    @Expect(scripts[1].steps[0], "prnt --output \"dist/ui preview.png\"")
}

@Test
func projectScriptCommandsInjectOwningProject(): Unit {
    let doctor = scriptStepCommand("doctor macos --verbose", "/work/demo")
    @Expect(doctor[doctor.size - 2], "--project")
    @Expect(doctor[doctor.size - 1], "/work/demo")

    let snapshot = scriptStepCommand("prnt --output preview.png -- --preview desktop", "/work/demo")
    @Expect(snapshot[4], "/work/demo")
    @Expect(snapshot[5], "--")

    let windowsPath = splitScriptCommand("prnt --output \"C:\\work dir\\preview.png\"")
    @Expect(windowsPath[2], "C:\\work dir\\preview.png")
}

@Test
func projectScriptsRejectShellAndReservedCommands(): Unit {
    @Expect(isReservedCuicCommand("dependency"))

    var shellRejected = false
    try {
        let _ = parseProjectScripts("[scripts]\nbad = [\"sh scripts/build.sh\"]\n")
    } catch (_: CuicError) {
        shellRejected = true
    }
    @Expect(shellRejected)

    var reservedRejected = false
    try {
        let _ = parseProjectScripts("[scripts]\nbuild = [\"test\"]\n")
    } catch (_: CuicError) {
        reservedRejected = true
    }
    @Expect(reservedRejected)

    var duplicateRejected = false
    try {
        let _ = parseProjectScripts("[scripts]\nverify = [\"test\"]\nverify = [\"build\"]\n")
    } catch (_: CuicError) {
        duplicateRejected = true
    }
    @Expect(duplicateRejected)

    var overrideRejected = false
    try {
        let _ = parseProjectScripts("[scripts]\nverify = [\"doctor --project /tmp/other\"]\n")
    } catch (_: CuicError) {
        overrideRejected = true
    }
    @Expect(overrideRejected)

    var malformedRejected = false
    try {
        let _ = parseProjectScripts("[scripts]\nverify = \"test\"\n")
    } catch (_: CuicError) {
        malformedRejected = true
    }
    @Expect(malformedRejected)
}

@Test
func buildModeAcceptsReleaseAndDebug(): Unit {
    @Expect(normalizeBuildMode("release"), "release")
    @Expect(normalizeBuildMode("debug"), "debug")
    var rejected = false
    try {
        let _ = normalizeBuildMode("prod")
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func prntOptionsParseDeviceAppAndMode(): Unit {
    let args = ["cuic", "prnt", "harmony", "demo", "--device", "my-phone", "--app", "com.example.demo", "--mode", "debug", "--output", "/tmp/ui.bmp"]
    let options = parsePrntOptions(args, 2)
    @Expect(options.platform, "harmony")
    @Expect(options.requested, "demo")
    @Expect(options.device, "my-phone")
    @Expect(options.app, "com.example.demo")
    @Expect(options.mode, "debug")
    @Expect(options.output, "/tmp/ui.bmp")
}

@Test
func prntOptionsDefaultToRelease(): Unit {
    let args = ["cuic", "prnt", "macos", "notepad"]
    let options = parsePrntOptions(args, 2)
    @Expect(options.mode, "release")
    @Expect(options.device, "")
    @Expect(options.app, "")
}

@Test
func prntOptionsRejectMissingDeviceValue(): Unit {
    var rejected = false
    try {
        let _ = parsePrntOptions(["cuic", "prnt", "--device"], 2)
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func debugOptionsParseDeviceAppMode(): Unit {
    let args = ["cuic", "debug", "harmony", "demo", "--device", "phone-1", "--app", "com.example.demo", "--mode", "debug"]
    let options = parseDebugOptions(args, 2)
    @Expect(options.platform, "harmony")
    @Expect(options.requested, "demo")
    @Expect(options.device, "phone-1")
    @Expect(options.app, "com.example.demo")
    @Expect(options.mode, "debug")
}

@Test
func debugOptionsDefaultToDebugMode(): Unit {
    let args = ["cuic", "debug", "macos", "notepad"]
    let options = parseDebugOptions(args, 2)
    @Expect(options.mode, "debug")
    @Expect(options.device, "")
    @Expect(options.app, "")
}

@Test
func harmonyPlatformAliasesNormalize(): Unit {
    @Expect(normalizePlatform("harmony"), "harmony")
    @Expect(normalizePlatform("ohos"), "harmony")
    @Expect(isPlatform("ohos"))
    @Expect(!isPlatform("tvos"))
}

@Test
func hdcTargetsParseFiltersEmptyAndHeaderLines(): Unit {
    let output = "Empty\n192.168.0.108:5555\n\n127.0.0.1:5555  connected\n"
    let targets = parseHdcTargets(output)
    @Expect(targets.size, 2)
    @Expect(targets[0], "192.168.0.108:5555")
    @Expect(targets[1], "127.0.0.1:5555")
}

@Test
func hasHdcTargetMatchesExactAliasOnly(): Unit {
    let targets = ["192.168.0.108:5555", "local"]
    @Expect(hasHdcTarget(targets, "192.168.0.108:5555"))
    @Expect(hasHdcTarget(targets, "local"))
    @Expect(!hasHdcTarget(targets, "192.168.0.108"))
}

@Test
func joinStringsUsesSeparator(): Unit {
    @Expect(joinStrings(["a", "b", "c"], ", "), "a, b, c")
    @Expect(joinStrings([], ", "), "")
}

@Test
func helpTextListsPviewAndTutorial(): Unit {
    let help = helpText()
    @Expect(help.contains("cuic pview"))
    @Expect(help.contains("pview prints the current CangHui layout"))
    @Expect(help.contains("probe ascii"))
}

@Test
func pviewUsesSameAsciiTargetParser(): Unit {
    let parsed = parseProbeTarget(
        ["cuic", "pview", "component-gallery", "gallery.primary-button",
            "--columns", "100", "--rows", "30", "--events", "move-in 10 10"],
        2,
        true,
        allowAscii: true
    )
    @Expect(parsed.name, "gallery.primary-button")
    @Expect(parsed.columns, Int64(100))
    @Expect(parsed.rows, Int64(30))
    @Expect(parsed.script, "move-in 10 10")
}

@Test
func helpPublishesDesignSnapshotExport(): Unit {
    @Expect(helpText().contains("cuic design snapshot"))
}

@Test
func helpPublishesUiAuditAndParsesThreshold(): Unit {
    @Expect(helpText().contains("cuic ui audit"))
    let parsed = parseProbeTarget(
        ["cuic", "ui", "audit", "component-gallery", "gallery.primary-button",
            "--fail-on", "error"], 3, true, allowAudit: true)
    @Expect(parsed.name, "gallery.primary-button")
    @Expect(parsed.failOn, "error")
}

@Test
func helpPublishesHarmonyProjection(): Unit {
    @Expect(helpText().contains("cuic prepare harmony"))
}

@Test
func executionContextUsesExplicitTargetAndStagingRoots(): Unit {
    let context = ExecutionContext("/tmp/proj", "/tmp/fw", targetDir: "/tmp/out", stagingRoot: "/tmp/stage")
    @Expect(context.project, "/tmp/proj")
    @Expect(context.framework, "/tmp/fw")
    @Expect(context.targetDir, "/tmp/out")
    @Expect(context.stagingRoot, "/tmp/stage")
    @Expect(context.sdlDirectory(), "/tmp/stage/sdl/.sdl3")
}

@Test
func executionContextSanitizesPathKeys(): Unit {
    @Expect(sanitizePathKey("/a/b"), "_a_b")
    @Expect(sanitizePathKey("C:\\x:y"), "C__x_y")
}

@Test
func nativeLinkSearchPrependsTheCuicRuntimeDirectory(): Unit {
    @Expect(nativeLinkSearchAssignment("/tmp/stage/sdl/.sdl3", ""),
        "LIBRARY_PATH=/tmp/stage/sdl/.sdl3")
    @Expect(nativeLinkSearchAssignment("/tmp/stage/sdl/.sdl3", "/opt/native"),
        "LIBRARY_PATH=/tmp/stage/sdl/.sdl3:/opt/native")
}

@Test
func cjpmArgsWithTargetAppendsOnceAndPreservesExisting(): Unit {
    let appended = cjpmArgsWithTarget(["build"], "/tmp/out")
    @Expect(appended.size, 3)
    @Expect(appended[0], "build")
    @Expect(appended[1], "--target-dir")
    @Expect(appended[2], "/tmp/out")
    let existing = cjpmArgsWithTarget(["build", "--target-dir", "/keep"], "/tmp/out")
    @Expect(existing.size, 3)
    @Expect(existing[0], "build")
    @Expect(existing[2], "/keep")
}
