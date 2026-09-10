package cuic

@When[debug]
import std.fs.{Directory, File, SymbolicLink, removeIfExists}

@When[debug]
@Test
func frameTraceParserKeepsOneProjectAndBoundedScenario(): Unit {
    let selection = parseFrameTraceSelection(
        ["cuic", "frame", "trace", "component-gallery", "--scenario", "FrameGraph.rev1-safe"],
        3
    )
    @Expect(selection.requested, "component-gallery")
    @Expect(selection.scenario, "FrameGraph.rev1-safe")
}

@When[debug]
@Test
func frameTraceParserRejectsMissingAndUnsafeScenarios(): Unit {
    var missing = false
    try {
        let _ = parseFrameTraceSelection(["cuic", "frame", "trace", "component-gallery"], 3)
    } catch (_: CuicError) {
        missing = true
    }
    @Expect(missing)

    for (scenario in ["../escape", "has space", "9starts-with-digit", "含中文"]) {
        var rejected = false
        try {
            validateFrameScenario(scenario)
        } catch (_: CuicError) {
            rejected = true
        }
        @Expect(rejected)
    }

    var tooLong = "A"
    while (tooLong.toArray().size <= FRAME_SCENARIO_MAX_BYTES) { tooLong += "a" }
    var lengthRejected = false
    try {
        validateFrameScenario(tooLong)
    } catch (_: CuicError) {
        lengthRejected = true
    }
    @Expect(lengthRejected)
}

@When[debug]
@Test
func frameReplayParserRequiresTheNullExecutor(): Unit {
    let selection = parseFrameReplaySelection(
        ["cuic", "frame", "replay", "trace.json", "--executor", "null"],
        3
    )
    @Expect(selection.tracePath, "trace.json")
    @Expect(selection.executor, "null")

    var rejected = false
    try {
        let _ = parseFrameReplaySelection(
            ["cuic", "frame", "replay", "trace.json", "--executor", "sdl"],
            3
        )
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
}

@When[debug]
@Test
func frameTraceOutputRemainsUnderTheExecutionTarget(): Unit {
    let context = ExecutionContext(
        "/tmp/frame-project",
        "/tmp/frame-framework",
        targetDir: "/tmp/frame-target",
        stagingRoot: "/tmp/frame-staging"
    )
    @Expect(
        frameTraceOutputPath(context, "gallery.rev1"),
        "/tmp/frame-target/cuic/frame-traces/gallery.rev1.json"
    )
}

@When[debug]
@Test
func frameTraceEnvironmentCarriesOnlyBoundedOneShotInputs(): Unit {
    let environment = frameTraceEnvironment("/tmp/framework", "/tmp/trace.json", "gallery.rev1")
    @Expect(environment.get("CANGHUI_FRAME_TRACE_PATH") ?? "", "/tmp/trace.json")
    @Expect(environment.get("CANGHUI_FRAME_TRACE_SCENARIO") ?? "", "gallery.rev1")
    @Expect(environment.get("CANGHUI_FRAME_TRACE_MAX_FRAMES") ?? "", "64")
}

@When[debug]
@Test
func frameTraceEnvelopeUsesTheStrictOfflineVerifier(): Unit {
    for (value in [
        "{}",
        "{\"protocol\":\"canghui.frame-trace.v0\",\"complete\":false," +
            "\"scenario\":\"x\",\"terminalCode\":\"accepted\"," +
            "\"frameCount\":0,\"frames\":[]}",
        "{\"protocol\":\"canghui.frame-trace.v0\",\"complete\":true," +
            "\"scenario\":\"x\",\"terminalCode\":\"accepted\"," +
            "\"frameCount\":0,\"frames\":[]}",
        "{\"protocol\":\"canghui.frame-trace.v0\",\"complete\":true"
    ]) {
        var rejected = false
        try {
            validateFrameTraceEnvelope(value)
        } catch (_: CuicError) {
            rejected = true
        }
        @Expect(rejected)
    }
}

@When[debug]
@Test
func frameReplayReaderEnforcesTheByteLimitBeforeDecoding(): Unit {
    let fixture = "/tmp/cuic-frame-reader-${currentPid()}"
    let trace = joinPath(fixture, "trace.json")
    let linked = joinPath(fixture, "linked.json")
    let oversized = joinPath(fixture, "oversized.json")
    _ = removeIfExists(fixture, recursive: true)
    try {
        Directory.create(fixture, recursive: true)
        let canonical = "{\"protocol\":\"canghui.frame-trace.v0\",\"scenario\":\"reader\"," +
            "\"complete\":true,\"terminalCode\":\"accepted\"," +
            "\"frameCount\":0,\"frames\":[]}"
        File.writeTo(trace, canonical.toArray())
        @Expect(readBoundedFrameTrace(trace), canonical)

        SymbolicLink.create(linked, to: trace)
        var symlinkRejected = false
        try {
            let _ = readBoundedFrameTrace(linked)
        } catch (error: CuicError) {
            symlinkRejected = containsText(error.message, "symbolic link")
        }
        @Expect(symlinkRejected)

        File.writeTo(oversized, Array<UInt8>(FRAME_TRACE_MAX_BYTES + 1, repeat: UInt8(65)))
        var rejected = false
        try {
            let _ = readBoundedFrameTrace(oversized)
        } catch (error: CuicError) {
            rejected = containsText(error.message, "exceeds")
        }
        @Expect(rejected)
    } finally {
        _ = removeIfExists(fixture, recursive: true)
    }
}

@When[debug]
@Test
func frameTraceOutputRejectsASymlinkedControlDirectory(): Unit {
    let fixture = "/tmp/cuic-frame-output-${currentPid()}"
    let target = joinPath(fixture, "target")
    let outside = joinPath(fixture, "outside")
    _ = removeIfExists(fixture, recursive: true)
    try {
        Directory.create(target, recursive: true)
        Directory.create(outside, recursive: true)
        SymbolicLink.create(joinPath(target, "cuic"), to: outside)
        let context = ExecutionContext(
            "/tmp/frame-project", "/tmp/frame-framework",
            targetDir: target, stagingRoot: "/tmp/frame-staging"
        )
        var rejected = false
        try {
            ensureFrameTraceOutputDirectory(context)
        } catch (error: CuicError) {
            rejected = containsText(error.message, "symbolic link")
        }
        @Expect(rejected)
    } finally {
        _ = removeIfExists(fixture, recursive: true)
    }
}

@When[debug]
@Test
func frameIsAReservedCommandAndAppearsInHelp(): Unit {
    @Expect(isReservedCuicCommand("frame"))
    @Expect(helpText().contains("cuic frame trace"))
    @Expect(helpText().contains("cuic frame replay"))
    @Expect(helpText().contains("upperLayerLegacyFallbackFrameCount"))
}

@When[!debug]
@Test
func releaseFrameCommandRefusesBeforeReadingAProjectOrTrace(): Unit {
    var refused = false
    try {
        let _ = frameCommand(
            ["cuic", "frame", "replay", "/path-that-must-not-be-read", "--executor", "null"],
            2
        )
    } catch (error: CuicError) {
        refused = containsText(error.message, "unavailable in release cuic")
    }
    @Expect(refused)
}
